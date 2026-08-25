///|
/// A stable issue emitted by the AI-Ready audit. The report intentionally
/// contains only diagnostics DTOs and Agent protocol values; it does not own a
/// runtime or call a model.
pub(all) enum AgentAuditIssue {
  MissingSemanticId(@core.SemanticsNodeId)
  DuplicateSemanticId(@core.SemanticId)
  MissingAction(@core.SemanticsNodeId, @core.SemanticsActionKind)
  DisabledTarget(@core.SemanticsNodeId)
  SensitiveActionWithoutPolicy(@core.SemanticsNodeId)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AgentInspectorWorkspace {
  Semantics
  Actions
  Trace
  Replay
  AIReadyAudit
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AgentAuditSummary {
  checked_nodes : Int
  issue_count : Int
  issues : Array[AgentAuditIssue]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AgentActionSummary {
  node_id : @core.SemanticsNodeId
  semantic_id : @core.SemanticId?
  actions : Array[@core.SemanticsActionKind]
  high_risk : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AgentInspectorReport {
  semantics : @agent.AgentSemanticsSnapshot?
  actions : Array[AgentActionSummary]
  policy : @agent.AgentPolicyState?
  trace : Array[@agent.AgentTraceEntry]
  replay : @agent.AgentReplayResult?
  mcp_result : String?
  audit : AgentAuditSummary
} derive(Eq, Debug, ToJson)

///|
fn audit_semantics(
  snapshot : @agent.AgentSemanticsSnapshot,
  has_policy : Bool,
) -> AgentAuditSummary {
  let issues : Array[AgentAuditIssue] = []
  let nodes = snapshot.nodes()
  let semantic_ids : Array[@core.SemanticId] = []
  for node in nodes {
    match node.semantic_id {
      None =>
        if node.role != @core.SemanticsRole::None {
          issues.push(AgentAuditIssue::MissingSemanticId(node.node_id))
        }
      Some(id) =>
        if semantic_ids.contains(id) {
          issues.push(AgentAuditIssue::DuplicateSemanticId(id))
        } else {
          semantic_ids.push(id)
        }
    }
    if node.role == @core.SemanticsRole::TextField &&
      !node.actions.contains(@core.SemanticsActionKind::SetText) {
      issues.push(
        AgentAuditIssue::MissingAction(
          node.node_id,
          @core.SemanticsActionKind::SetText,
        ),
      )
    }
    if node.role == @core.SemanticsRole::Button &&
      !node.actions.contains(@core.SemanticsActionKind::Activate) {
      issues.push(
        AgentAuditIssue::MissingAction(
          node.node_id,
          @core.SemanticsActionKind::Activate,
        ),
      )
    }
    if node.state.disabled {
      issues.push(AgentAuditIssue::DisabledTarget(node.node_id))
    }
    if !has_policy && node.actions.any(action_is_high_risk) {
      issues.push(AgentAuditIssue::SensitiveActionWithoutPolicy(node.node_id))
    }
  }
  { checked_nodes: nodes.length(), issue_count: issues.length(), issues }
}

///|
fn action_is_high_risk(kind : @core.SemanticsActionKind) -> Bool {
  kind == @core.SemanticsActionKind::SetText ||
  kind == @core.SemanticsActionKind::SetNumericValue ||
  kind == @core.SemanticsActionKind::Submit
}

///|
fn action_summaries(
  semantics : @agent.AgentSemanticsSnapshot?,
) -> Array[AgentActionSummary] {
  let summaries : Array[AgentActionSummary] = []
  match semantics {
    None => ()
    Some(snapshot) =>
      for node in snapshot.nodes() {
        summaries.push({
          node_id: node.node_id,
          semantic_id: node.semantic_id,
          actions: node.actions.copy(),
          high_risk: node.actions.any(action_is_high_risk),
        })
      }
  }
  summaries
}

///|
pub fn agent_inspector_report(
  semantics : @agent.AgentSemanticsSnapshot?,
  policy? : @agent.AgentPolicyState,
  trace? : Array[@agent.AgentTraceEntry] = [],
  replay? : @agent.AgentReplayResult,
  mcp_result? : String,
) -> AgentInspectorReport {
  let audit = match semantics {
    Some(snapshot) => audit_semantics(snapshot, policy is Some(_))
    None => { checked_nodes: 0, issue_count: 0, issues: [] }
  }
  {
    semantics,
    actions: action_summaries(semantics),
    policy,
    trace,
    replay,
    mcp_result,
    audit,
  }
}

///|
pub fn AgentInspectorReport::audit(
  self : AgentInspectorReport,
) -> AgentAuditSummary {
  self.audit
}

///|
pub fn AgentInspectorReport::semantics(
  self : AgentInspectorReport,
) -> @agent.AgentSemanticsSnapshot? {
  self.semantics
}

///|
pub fn AgentInspectorReport::trace(
  self : AgentInspectorReport,
) -> Array[@agent.AgentTraceEntry] {
  self.trace.copy()
}

///|
pub fn agent_inspector_report_text(report : AgentInspectorReport) -> String {
  let semantics = match report.semantics {
    None => "closed"
    Some(snapshot) =>
      "generation=" +
      snapshot.generation().to_wire() +
      "; nodes=" +
      snapshot.nodes().length().to_string()
  }
  let policy = match report.policy {
    None => "unavailable"
    Some(state) =>
      "pending=" +
      state.pending().length().to_string() +
      "; traces=" +
      state.trace_count().to_string()
  }
  let replay = match report.replay {
    None => "not_run"
    Some(value) =>
      "success=" +
      value.success().to_string() +
      "; completed=" +
      value.completed().to_string()
  }
  let mcp = report.mcp_result.unwrap_or("not_recorded")
  "[semantics] " +
  semantics +
  "\n[actions] nodes=" +
  report.actions.length().to_string() +
  "; trace_entries=" +
  report.trace.length().to_string() +
  "\n[policy] " +
  policy +
  "\n[replay] " +
  replay +
  "\n[mcp] " +
  mcp +
  "\n[audit] checked=" +
  report.audit.checked_nodes.to_string() +
  "; issues=" +
  report.audit.issue_count.to_string()
}

///|
pub fn agent_inspector_workspace_text(
  report : AgentInspectorReport,
  workspace : AgentInspectorWorkspace,
) -> String {
  match workspace {
    AgentInspectorWorkspace::Semantics =>
      match report.semantics {
        None => "No committed semantics snapshot"
        Some(snapshot) =>
          "Generation " +
          snapshot.generation().to_wire() +
          "; nodes " +
          snapshot.nodes().length().to_string()
      }
    AgentInspectorWorkspace::Actions =>
      "Action targets: " +
      report.actions.length().to_string() +
      "; high-risk targets: " +
      report.actions.filter(action => action.high_risk).length().to_string()
    AgentInspectorWorkspace::Trace =>
      "Trace entries: " + report.trace.length().to_string()
    AgentInspectorWorkspace::Replay =>
      match report.replay {
        None => "Replay has not run"
        Some(value) =>
          "Replay success=" +
          value.success().to_string() +
          "; completed=" +
          value.completed().to_string()
      }
    AgentInspectorWorkspace::AIReadyAudit =>
      "Audit issues: " + report.audit.issue_count.to_string()
  }
}

///|
pub fn agent_inspector_report_json(
  report : AgentInspectorReport,
  indent? : Int = 2,
) -> String {
  ToJson::to_json(report).stringify(indent~)
}
