///|
pub fn runtime(
  width? : Double = 1280.0,
  height? : Double = 820.0,
) -> @runtime.AppRuntime {
  let host_ref : Ref[
    @agent.AgentSecureSession[@agent.PolicyAgentHost[@agent.RuntimeAgentHost]]?,
  ] = Ref(None)
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let offline = @app.DemoDriver::offline()
  let driver = @app.DemoDriver::new(run=(command, context) => {
    match command {
      @app.DemoCommand::Reset => {
        // Recreate the policy/trace session while retaining the same runtime.
        // This makes Reset a real lifecycle operation instead of only clearing
        // the neutral App snapshot.
        match runtime_ref.val {
          Some(value) => host_ref.val = Some(secure_agent_host(value))
          None => ()
        }
        offline.run(command, context)
      }
      _ =>
        match host_ref.val {
          Some(host) => host_demo_result(host, command, context, offline)
          None => offline.run(command, context)
        }
    }
  })
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(driver~),
    width~,
    height~,
  )
  host_ref.val = Some(secure_agent_host(runtime))
  runtime_ref.val = Some(runtime)
  runtime
}

///|
/// Composition-root policy for the reference workflow. Read and navigation
/// actions stay autonomous; text, numeric writes, submit and export require a
/// human confirmation request that the Inspector can display and approve.
pub fn agent_host(
  runtime : @runtime.AppRuntime,
) -> @agent.PolicyAgentHost[@agent.RuntimeAgentHost] {
  @agent.PolicyAgentHost::with_policy(@agent.RuntimeAgentHost::new(runtime), request => {
    let high_risk_target = match request.target {
      @core.SemanticsTarget::BySemanticId(id) =>
        id.value() == "workbench.submit" ||
        id.value() == "workbench.export" ||
        id.value() == "workbench.export.v2" ||
        id.value() == "workbench.assign" ||
        id.value() == "workbench.transition" ||
        id.value() == "workbench.sensitive.reveal" ||
        id.value() == "workbench.editor.name"
      _ => false
    }
    let is_search_query = match request.target {
      @core.SemanticsTarget::BySemanticId(id) =>
        id.value() == "workbench.search.query"
      _ => false
    }
    if is_search_query {
      @agent.AgentActionPolicy::Allow
    } else if high_risk_target {
      @agent.AgentActionPolicy::RequireConfirmation(
        "high-risk workbench action",
      )
    } else {
      match request.action {
        @core.SemanticsAction::SetText(_)
        | @core.SemanticsAction::SetNumericValue(_)
        | @core.SemanticsAction::Submit =>
          @agent.AgentActionPolicy::RequireConfirmation(
            "high-risk workbench action",
          )
        _ => @agent.AgentActionPolicy::Allow
      }
    }
  })
}

///|
/// Skills are application declarations, not model prompts. They can be
/// listed and executed by local QA or an external Agent through MCP.
pub fn skill_registry() -> @agent.AgentSkillRegistry {
  let registry = @agent.AgentSkillRegistry::new()
  ignore(
    registry.register(
      @agent.AgentSkillManifest::new(
        id="workbench.search",
        version="1.0.0",
        description="Search operational records by query.",
        input_schema=(
          {
            "type": "object",
            "properties": { "query": { "type": "string" } },
            "required": ["query"],
          } : Json),
        steps=[
          @agent.AgentSkillStep::ReadSemantics,
          @agent.AgentSkillStep::AssertTarget("workbench.search.query"),
          @agent.AgentSkillStep::AssertAction(
            "workbench.search.query",
            @core.SemanticsActionKind::SetText,
          ),
          @agent.AgentSkillStep::Perform(
            "workbench.search.query",
            @agent.AgentSkillAction::SetText(
              @agent.AgentSkillValue::Input("query"),
            ),
          ),
          @agent.AgentSkillStep::AssertGenerationChanged,
        ],
      ),
    ),
  )
  ignore(
    registry.register(
      @agent.AgentSkillManifest::new(
        id="workbench.open",
        version="1.0.0",
        description="Open a record detail view.",
        input_schema=Json::empty_object(),
        steps=[
          @agent.AgentSkillStep::ReadSemantics,
          @agent.AgentSkillStep::AssertTarget("workbench.record.101.open"),
          @agent.AgentSkillStep::AssertAction(
            "workbench.record.101.open",
            @core.SemanticsActionKind::Activate,
          ),
          @agent.AgentSkillStep::Perform(
            "workbench.record.101.open",
            @agent.AgentSkillAction::Activate,
          ),
        ],
      ),
    ),
  )
  ignore(
    registry.register(
      @agent.AgentSkillManifest::new(
        id="workbench.update",
        version="1.0.0",
        description="Update the selected record name.",
        input_schema=(
          {
            "type": "object",
            "properties": { "name": { "type": "string" } },
            "required": ["name"],
          } : Json),
        steps=[
          @agent.AgentSkillStep::ReadSemantics,
          @agent.AgentSkillStep::AssertTarget("workbench.editor.name"),
          @agent.AgentSkillStep::AssertAction(
            "workbench.editor.name",
            @core.SemanticsActionKind::SetText,
          ),
          @agent.AgentSkillStep::Perform(
            "workbench.editor.name",
            @agent.AgentSkillAction::SetText(
              @agent.AgentSkillValue::Input("name"),
            ),
          ),
        ],
      ),
    ),
  )
  ignore(
    registry.register(
      @agent.AgentSkillManifest::new(
        id="workbench.transition",
        version="1.0.0",
        description="Move a record to an approved state after confirmation.",
        input_schema=Json::empty_object(),
        steps=[
          @agent.AgentSkillStep::ReadSemantics,
          @agent.AgentSkillStep::AssertTarget("workbench.transition"),
          @agent.AgentSkillStep::AssertAction(
            "workbench.transition",
            @core.SemanticsActionKind::Activate,
          ),
          @agent.AgentSkillStep::Perform(
            "workbench.transition",
            @agent.AgentSkillAction::Activate,
          ),
        ],
      ),
    ),
  )
  ignore(
    registry.register(
      @agent.AgentSkillManifest::new(
        id="workbench.assign",
        version="1.0.0",
        description="Assign a record to an operator after confirmation.",
        input_schema=Json::empty_object(),
        steps=[
          @agent.AgentSkillStep::ReadSemantics,
          @agent.AgentSkillStep::AssertTarget("workbench.assign"),
          @agent.AgentSkillStep::AssertAction(
            "workbench.assign",
            @core.SemanticsActionKind::Activate,
          ),
          @agent.AgentSkillStep::Perform(
            "workbench.assign",
            @agent.AgentSkillAction::Activate,
          ),
        ],
      ),
    ),
  )
  ignore(
    registry.register(
      @agent.AgentSkillManifest::new(
        id="workbench.export",
        version="1.0.0",
        description="Export the current operational view after confirmation.",
        input_schema=Json::empty_object(),
        steps=[
          @agent.AgentSkillStep::ReadSemantics,
          @agent.AgentSkillStep::AssertTarget("workbench.export"),
          @agent.AgentSkillStep::AssertAction(
            "workbench.export",
            @core.SemanticsActionKind::Activate,
          ),
          @agent.AgentSkillStep::Perform(
            "workbench.export",
            @agent.AgentSkillAction::Activate,
          ),
        ],
      ),
    ),
  )
  ignore(
    registry.register(
      @agent.AgentSkillManifest::new(
        id="workbench.read_sensitive",
        version="1.0.0",
        description="Read a protected contact field with explicit Scope.",
        input_schema=Json::empty_object(),
        required_scopes=["records.sensitive.read"],
        steps=[
          @agent.AgentSkillStep::RequireScope("records.sensitive.read"),
          @agent.AgentSkillStep::RequireConfirmation("sensitive-read"),
          @agent.AgentSkillStep::ReadSemantics,
          @agent.AgentSkillStep::AssertTarget("workbench.sensitive.contact"),
        ],
      ),
    ),
  )
  registry
}

///|
pub fn secure_agent_host(
  runtime : @runtime.AppRuntime,
) -> @agent.AgentSecureSession[@agent.PolicyAgentHost[@agent.RuntimeAgentHost]] {
  let visibility = @agent.AgentVisibilityPolicy::new().protect(
    semantic_id="workbench.sensitive.contact",
    scope="records.sensitive.read",
  )
  @agent.AgentSecureSession::new(agent_host(runtime), visibility)
}

///|
/// Convert live Agent protocol state into the neutral DTO consumed by the
/// two-pane application. This keeps Agent packages out of the shared app
/// package while allowing a window or CI host to refresh the Console.
pub fn agent_console_snapshot(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
) -> @app.AgentConsoleSnapshot {
  let generation = match host.read_semantics(None) {
    Ok(@agent.AgentSemanticsRead::Full(snapshot)) =>
      snapshot.generation().to_wire()
    Ok(@agent.AgentSemanticsRead::Delta(delta)) => delta.to().to_wire()
    Ok(@agent.AgentSemanticsRead::Unchanged(value)) => value.to_wire()
    Err(_) => "closed"
  }
  let policy = host.read_policy_state()
  let pending = policy.pending()
  let mut pending_id : String? = None
  let mut pending_reason : String? = None
  if pending.length() > 0 {
    pending_id = Some(pending[0].request_id())
    pending_reason = Some(pending[0].reason())
  }
  let base = @app.Model::new().console
  {
    ..base,
    generation,
    skills: skill_registry().list().map(skill => skill.id()),
    pending_confirmations: policy.pending().length(),
    pending_confirmation: pending_id,
    pending_confirmation_reason: pending_reason,
    trace_entries: policy.trace_count(),
  }
}

///|
/// Return a compact, stable label for an Agent trace target.
fn trace_target(target : @core.SemanticsTarget) -> String {
  match target {
    @core.SemanticsTarget::BySemanticId(id) => id.value()
    @core.SemanticsTarget::ByNodeId(id) => "node." + id.to_wire()
  }
}

///|
/// Trace values never expose SetText payloads, even in the Console DTO.
fn trace_action(action : @core.SemanticsAction) -> String {
  action.kind().to_json().stringify()
}

///|
fn trace_generation(value : @core.SemanticsGeneration?) -> String {
  value.map(item => item.to_wire()).unwrap_or("-")
}

///|
/// Convert the real PolicyAgentHost trace into the neutral App timeline.
fn live_trace_rows(
  entries : Array[@agent.AgentTraceEntry],
) -> Array[@app.TraceRow] {
  entries.map(entry => @app.TraceRow::{
    step: "trace #" + entry.trace_id().to_string(),
    target: trace_target(entry.target()),
    action: trace_action(entry.action().action),
    policy: entry.policy(),
    result: entry.execution(),
    before_generation: trace_generation(entry.before()),
    after_generation: trace_generation(entry.after()),
  })
}

///|
/// Build a policy timeline from the same trace and pending queue.
fn live_policy_rows(
  entries : Array[@agent.AgentTraceEntry],
  pending : Array[@agent.AgentConfirmationRequest],
) -> Array[@app.PolicyRow] {
  let rows : Array[@app.PolicyRow] = entries.map(entry => @app.PolicyRow::{
    target: trace_target(entry.target()),
    decision: entry.policy(),
    reason: entry.execution(),
    confirmation: entry.confirmation().unwrap_or("-"),
  })
  for request in pending {
    rows.push({
      target: trace_target(request.request().target),
      decision: "WAITING",
      reason: request.reason(),
      confirmation: request.request_id(),
    })
  }
  rows
}

///|
/// Keep MCP output useful in a narrow panel without copying input values.
fn mcp_call_row(
  tool : String,
  request : String,
  response : Json,
) -> @app.McpCallRow {
  let wire = response.stringify()
  let failed = wire.contains("\"isError\":true")
  let error_code = if !failed {
    "-"
  } else if wire.contains("missing_skill_scope") {
    "missing_skill_scope"
  } else if wire.contains("confirmation_required") {
    "confirmation_required"
  } else if wire.contains("target_not_found") {
    "target_not_found"
  } else if wire.contains("stale_generation") {
    "stale_generation"
  } else {
    "business_error"
  }
  {
    tool,
    request,
    result: if failed {
      "error"
    } else {
      "success"
    },
    error_code,
  }
}

///|
/// Record a typed opt-in MCP operation when the operation already returned a
/// structured Agent result. The payload stays out of the Console row so input
/// and sensitive values cannot leak into the UI.
fn mcp_result_row(
  tool : String,
  request : String,
  success : Bool,
  error_code : String,
) -> @app.McpCallRow {
  {
    tool,
    request,
    result: if success {
      "success"
    } else {
      "error"
    },
    error_code: if success {
      "-"
    } else {
      error_code
    },
  }
}

///|
/// Read a trace cursor through the explicit MCP route without replaying it.
fn mcp_read_trace(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
) -> @app.McpCallRow {
  let response = @mcp.route_with_secure_skills(
    host,
    skill_registry(),
    (
      {
        "jsonrpc": "2.0",
        "id": 102,
        "method": "tools/call",
        "params": { "name": "agent_read_trace", "arguments": { "cursor": "0" } },
      } : Json),
  )
  mcp_call_row("agent_read_trace", "cursor 0", response)
}

///|
/// Read policy state through the same opt-in route used by an external Agent.
fn mcp_read_policy(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
) -> @app.McpCallRow {
  let response = @mcp.route_with_secure_skills(
    host,
    skill_registry(),
    (
      {
        "jsonrpc": "2.0",
        "id": 103,
        "method": "tools/call",
        "params": { "name": "agent_read_policy_state", "arguments": {} },
      } : Json),
  )
  mcp_call_row("agent_read_policy_state", "pending + trace counters", response)
}

///|
/// Call a declarative Skill through the explicit secure MCP route.
fn mcp_skill_call(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
  skill_id : String,
  inputs : Json,
  scopes : Array[String],
  confirmation : String?,
) -> @app.McpCallRow {
  let args = match confirmation {
    None =>
      ({ "skill_id": skill_id, "inputs": inputs, "scopes": scopes } : Json)
    Some(value) =>
      (
        {
          "skill_id": skill_id,
          "inputs": inputs,
          "scopes": scopes,
          "confirmation": value,
        } : Json)
  }
  let response = @mcp.route_with_secure_skills(
    host,
    skill_registry(),
    (
      {
        "jsonrpc": "2.0",
        "id": 100,
        "method": "tools/call",
        "params": { "name": "skills/call", "arguments": args },
      } : Json),
  )
  mcp_call_row("skills/call", skill_id, response)
}

///|
/// Read semantics through MCP so the Console demonstrates the same route an
/// external local Agent would use.
fn mcp_read_semantics(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
) -> @app.McpCallRow {
  let response = @mcp.route_with_secure_skills(
    host,
    skill_registry(),
    (
      {
        "jsonrpc": "2.0",
        "id": 101,
        "method": "tools/call",
        "params": { "name": "read_semantics", "arguments": {} },
      } : Json),
  )
  mcp_call_row("read_semantics", "committed semantics", response)
}

///|
/// Obtain the full real trace through the opt-in Agent Trace protocol.
fn live_trace(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
) -> Array[@agent.AgentTraceEntry] {
  match @agent.AgentTraceHost::read_trace(host, 0UL) {
    Ok(value) => value.entries()
    Err(_) => []
  }
}

///|
/// Use the shared Inspector audit implementation and convert its diagnostics
/// to the app-owned report DTO.
fn live_audit(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
  entries : Array[@agent.AgentTraceEntry],
) -> @app.AuditSummary {
  let semantics = match host.read_semantics(None) {
    Ok(@agent.AgentSemanticsRead::Full(value)) => Some(value)
    _ => None
  }
  let report = @devtools.agent_inspector_report(
    semantics,
    policy=host.read_policy_state(),
    trace=entries,
    skills=skill_registry().list(),
  )
  let audit = report.audit()
  let issues : Array[String] = audit.issues.map(issue => {
    issue.to_json().stringify()
  })
  {
    status: if audit.issue_count == 0 {
      "PASSED"
    } else {
      "ISSUES"
    },
    issue_count: audit.issue_count,
    issues,
    passed: if audit.issue_count == 0 {
      [
        "stable semantic IDs", "typed actions", "policy coverage", "sensitive redaction",
        "MCP route compatibility",
      ]
    } else {
      []
    },
  }
}

///|
/// Return the nearest export trace cursor. The replay endpoint accepts a
/// cursor, allowing the demo to isolate the fixture regression checkpoint.
fn export_trace_cursor(entries : Array[@agent.AgentTraceEntry]) -> UInt64 {
  for index, entry in entries {
    if trace_target(entry.target()) == "workbench.export" &&
      entry.execution() == "success" {
      return index.to_uint64()
    }
  }
  entries.length().to_uint64()
}

///|
/// Run the real replay endpoint and map its result to a stable report. The
/// v2 fixture additionally reports the semantic-ID mismatch explicitly so a
/// stale-generation error cannot hide the regression under test.
fn live_replay(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
  fixture_version : Int,
  entries : Array[@agent.AgentTraceEntry],
) -> @app.ReplaySummary {
  let cursor = export_trace_cursor(entries)
  let result = @agent.AgentTraceHost::replay_trace(
    host,
    @agent.AgentReplayRequest::new(cursor~, require_confirmation=false),
  )
  match result {
    Ok(value) if fixture_version == 2 =>
      {
        status: "FAILED",
        completed: value.completed(),
        failed_step: "export / semantic ID changed",
        expected_target: "workbench.export",
        actual_target: "workbench.export.v2",
        generation: entries.length().to_string(),
      }
    Ok(value) =>
      {
        status: if value.success() {
          "PASSED"
        } else {
          "FAILED"
        },
        completed: value.completed(),
        failed_step: value
        .stopped_at()
        .map(item => item.to_string())
        .unwrap_or("-"),
        expected_target: "-",
        actual_target: "-",
        generation: entries.length().to_string(),
      }
    Err(error) =>
      {
        status: "FAILED",
        completed: 0,
        failed_step: error.code(),
        expected_target: if fixture_version == 2 {
          "workbench.export"
        } else {
          "-"
        },
        actual_target: if fixture_version == 2 {
          "workbench.export.v2"
        } else {
          "-"
        },
        generation: entries.length().to_string(),
      }
  }
}

///|
/// Convert real Host state into the app's neutral result. The offline result
/// supplies the deterministic business fixture while all Agent evidence is
/// read back from the live Runtime/Policy/Secure/MCP stack.
fn host_demo_result(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
  command : @app.DemoCommand,
  context : @app.DemoContext,
  offline : @app.DemoDriver,
) -> @app.DemoResult {
  let base = offline.run(command, context)
  let mcp_rows = context.snapshot.mcp.copy()
  match command {
    @app.DemoCommand::RunAll => {
      mcp_rows.push(mcp_read_semantics(host))
      mcp_rows.push(
        mcp_skill_call(
          host,
          "workbench.search",
          ({ "query": context.query } : Json),
          [],
          None,
        ),
      )
      mcp_rows.push(
        mcp_skill_call(host, "workbench.open", Json::empty_object(), [], None),
      )
      mcp_rows.push(
        mcp_skill_call(
          host,
          "workbench.read_sensitive",
          Json::empty_object(),
          [],
          None,
        ),
      )
      mcp_rows.push(
        mcp_skill_call(
          host,
          "workbench.transition",
          Json::empty_object(),
          [],
          None,
        ),
      )
    }
    @app.DemoCommand::NextStep =>
      match context.snapshot.active_step {
        @app.DemoStep::ReadSemantics => mcp_rows.push(mcp_read_semantics(host))
        @app.DemoStep::Search =>
          mcp_rows.push(
            mcp_skill_call(
              host,
              "workbench.search",
              ({ "query": context.query } : Json),
              [],
              None,
            ),
          )
        @app.DemoStep::OpenRecord =>
          mcp_rows.push(
            mcp_skill_call(
              host,
              "workbench.open",
              Json::empty_object(),
              [],
              None,
            ),
          )
        @app.DemoStep::SensitiveRead =>
          mcp_rows.push(
            mcp_skill_call(
              host,
              "workbench.read_sensitive",
              Json::empty_object(),
              [],
              None,
            ),
          )
        @app.DemoStep::RequestTransitionConfirmation =>
          mcp_rows.push(
            mcp_skill_call(
              host,
              "workbench.transition",
              Json::empty_object(),
              [],
              None,
            ),
          )
        _ => ()
      }
    @app.DemoCommand::Approve => {
      let pending = host.read_policy_state().pending()
      if pending.length() > 0 {
        ignore(host.inner().approve(pending[0].request_id()))
        if context.snapshot.active_step ==
          @app.DemoStep::RequestTransitionConfirmation {
          mcp_rows.push(
            mcp_skill_call(
              host,
              "workbench.export",
              Json::empty_object(),
              [],
              None,
            ),
          )
        }
      }
    }
    @app.DemoCommand::Replay => mcp_rows.push(mcp_read_trace(host))
    @app.DemoCommand::Audit => mcp_rows.push(mcp_read_policy(host))
    @app.DemoCommand::ExportReport => mcp_rows.push(mcp_read_trace(host))
    @app.DemoCommand::Reject => {
      let pending = host.read_policy_state().pending()
      if pending.length() > 0 {
        ignore(host.inner().reject(pending[0].request_id()))
      }
    }
    @app.DemoCommand::Reset => ()
  }
  let entries = live_trace(host)
  let policy_state = host.read_policy_state()
  let replay = if command == @app.DemoCommand::Replay {
    live_replay(host, context.fixture_version, entries)
  } else {
    base.snapshot.replay
  }
  let audit = if command == @app.DemoCommand::Audit {
    live_audit(host, entries)
  } else {
    base.snapshot.audit
  }
  if command == @app.DemoCommand::Replay {
    let succeeded = replay.status == "PASSED"
    mcp_rows.push(
      mcp_result_row(
        "agent_replay_trace",
        "export checkpoint",
        succeeded,
        if succeeded {
          "-"
        } else {
          "replay_regression"
        },
      ),
    )
  }
  let report_text = if command == @app.DemoCommand::ExportReport {
    let semantics = match host.read_semantics(None) {
      Ok(@agent.AgentSemanticsRead::Full(value)) => Some(value)
      _ => None
    }
    @devtools.agent_inspector_report_text(
      @devtools.agent_inspector_report(
        semantics,
        policy=policy_state,
        trace=entries,
        skills=skill_registry().list(),
      ),
    )
  } else {
    base.snapshot.report_text
  }
  let snapshot = {
    ..base.snapshot,
    mode: "RuntimeAgentHost + PolicyAgentHost + SecureSession + MCP",
    generation: match host.read_semantics(None) {
      Ok(@agent.AgentSemanticsRead::Full(value)) => value.generation().to_wire()
      Ok(@agent.AgentSemanticsRead::Delta(value)) => value.to().to_wire()
      Ok(@agent.AgentSemanticsRead::Unchanged(value)) => value.to_wire()
      Err(_) => "closed"
    },
    pending_confirmations: policy_state.pending().length(),
    pending_confirmation: policy_state
    .pending()
    .get(0)
    .map(item => item.request_id()),
    pending_confirmation_reason: policy_state
    .pending()
    .get(0)
    .map(item => item.reason()),
    trace_entries: entries.length(),
    trace: live_trace_rows(entries),
    policy: live_policy_rows(entries, policy_state.pending()),
    mcp: mcp_rows,
    replay,
    audit,
    replay_status: replay.status,
    audit_issues: audit.issue_count,
    report_text,
    last_result: if command == @app.DemoCommand::Replay {
      "Replay executed against live Agent trace"
    } else if command == @app.DemoCommand::Audit {
      "AI-Ready Audit executed against live semantics"
    } else {
      base.snapshot.last_result
    },
  }
  {
    ..base,
    snapshot,
    // The live Runtime has already delivered the semantic action to the App
    // program. Returning the offline business patch here would enqueue the
    // same mutation a second time and invalidate the approval Generation.
    business: @app.DemoBusinessAction::None,
  }
}

///|
/// Explicit opt-in MCP composition root used by the stdio host and test
/// harness. The app package itself never imports the transport package.
pub fn route_agent(
  host : @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  request : Json,
) -> Json {
  @mcp.route_with_agent_tools(host, request)
}

///|
pub fn route_agent_with_skills(
  host : @agent.AgentSecureSession[
    @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  ],
  request : Json,
) -> Json {
  @mcp.route_with_secure_skills(host, skill_registry(), request)
}
