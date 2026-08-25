///|
/// Agent-facing duplicate identity diagnostic from one committed snapshot.
pub(all) enum AgentSemanticsIssue {
  DuplicateSemanticId(@core.SemanticId, Array[@core.SemanticsNodeId])
  MissingRelationTarget(
    @core.SemanticsNodeId,
    @core.SemanticsRelationKind,
    @core.SemanticId
  )
  AmbiguousRelationTarget(
    @core.SemanticsNodeId,
    @core.SemanticsRelationKind,
    @core.SemanticId,
    Array[@core.SemanticsNodeId]
  )
} derive(Eq, Debug, ToJson)

///|
/// Immutable full semantics projection exposed by `AgentHost`.
pub(all) struct AgentSemanticsSnapshot {
  generation : @core.SemanticsGeneration
  root : @core.SemanticsNodeId?
  focused : @core.SemanticsNodeId?
  nodes : Array[@core.SemanticsNode]
  issues : Array[AgentSemanticsIssue]
} derive(Eq, Debug, ToJson)

///|
pub fn AgentSemanticsSnapshot::generation(
  self : AgentSemanticsSnapshot,
) -> @core.SemanticsGeneration {
  self.generation
}

///|
pub fn AgentSemanticsSnapshot::nodes(
  self : AgentSemanticsSnapshot,
) -> Array[@core.SemanticsNode] {
  self.nodes.copy()
}

///|
pub fn AgentSemanticsSnapshot::focused(
  self : AgentSemanticsSnapshot,
) -> @core.SemanticsNodeId? {
  self.focused
}

///|
/// Incremental semantics projection between two committed generations.
pub(all) struct AgentSemanticsDelta {
  from : @core.SemanticsGeneration
  to : @core.SemanticsGeneration
  root : @core.SemanticsNodeId?
  focused : @core.SemanticsNodeId?
  upserted : Array[@core.SemanticsNode]
  removed : Array[@core.SemanticsNodeId]
  issues : Array[AgentSemanticsIssue]
  announcements : Array[AgentAccessibilityAnnouncement]
} derive(Eq, Debug, ToJson)

///|
pub fn AgentSemanticsDelta::to(
  self : AgentSemanticsDelta,
) -> @core.SemanticsGeneration {
  self.to
}

///|
pub fn AgentSemanticsDelta::upserted(
  self : AgentSemanticsDelta,
) -> Array[@core.SemanticsNode] {
  self.upserted.copy()
}

///|
/// Agent-facing projection of one live-region change.
pub(all) struct AgentAccessibilityAnnouncement {
  node_id : @core.SemanticsNodeId
  generation : @core.SemanticsGeneration
  live : @core.SemanticsLive
  is_atomic : Bool
  text : String
} derive(Eq, Debug, ToJson)

///|
/// Result of reading committed semantics with an optional independent cursor.
pub(all) enum AgentSemanticsRead {
  Full(AgentSemanticsSnapshot)
  Delta(AgentSemanticsDelta)
  Unchanged(@core.SemanticsGeneration)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AgentReadError {
  HostClosed
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AgentGenerationPrecondition {
  Exact(@core.SemanticsGeneration)
  Latest
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AgentActionRequest {
  target : @core.SemanticsTarget
  action : @core.SemanticsAction
  precondition : AgentGenerationPrecondition
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AgentActionReceipt {
  before : @core.SemanticsGeneration
  after : @core.SemanticsGeneration
  pending_work : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AgentActionError {
  HostClosed
  StaleGeneration(@core.SemanticsGeneration, @core.SemanticsGeneration)
  TargetNotFound(@core.SemanticsTarget)
  TargetAmbiguous(@core.SemanticId)
  TargetDisabled(@core.SemanticsTarget)
  ActionUnavailable(@core.SemanticsTarget, @core.SemanticsActionKind)
  HandlerRejected(@core.SemanticsTarget, @core.SemanticsActionKind)
  ReentrantDispatch
  PolicyDenied(String)
  ConfirmationRequired(String)
  ConfirmationRejected(String)
  ConfirmationExpired(String)
} derive(Eq, Debug, ToJson)

///|
pub fn AgentReadError::code(self : AgentReadError) -> String {
  match self {
    HostClosed => "host_closed"
  }
}

///|
pub fn AgentActionError::code(self : AgentActionError) -> String {
  match self {
    HostClosed => "host_closed"
    StaleGeneration(_, _) => "stale_generation"
    TargetNotFound(_) => "target_not_found"
    TargetAmbiguous(_) => "target_ambiguous"
    TargetDisabled(_) => "target_disabled"
    ActionUnavailable(_, _) => "action_unavailable"
    HandlerRejected(_, _) => "handler_rejected"
    ReentrantDispatch => "reentrant_dispatch"
    PolicyDenied(_) => "policy_denied"
    ConfirmationRequired(_) => "confirmation_required"
    ConfirmationRejected(_) => "confirmation_rejected"
    ConfirmationExpired(_) => "confirmation_expired"
  }
}

///|
fn agent_semantics_issue(
  issue : @runtime.SemanticsIssue,
) -> AgentSemanticsIssue {
  match issue {
    @runtime.SemanticsIssue::DuplicateSemanticId(id, nodes) =>
      DuplicateSemanticId(id, nodes.copy())
    @runtime.SemanticsIssue::MissingRelationTarget(source, kind, id) =>
      MissingRelationTarget(source, kind, id)
    @runtime.SemanticsIssue::AmbiguousRelationTarget(source, kind, id, nodes) =>
      AmbiguousRelationTarget(source, kind, id, nodes.copy())
  }
}

///|
fn agent_semantics_read(read : @runtime.SemanticsRead) -> AgentSemanticsRead {
  match read {
    @runtime.SemanticsRead::Full(snapshot) =>
      Full({
        generation: snapshot.generation(),
        root: snapshot.root(),
        focused: snapshot.focused(),
        nodes: snapshot.nodes(),
        issues: snapshot.issues().map(agent_semantics_issue),
      })
    @runtime.SemanticsRead::Delta(delta) =>
      Delta({
        from: delta.from(),
        to: delta.to(),
        root: delta.root(),
        focused: delta.focused(),
        upserted: delta.upserted(),
        removed: delta.removed(),
        issues: delta.issues().map(agent_semantics_issue),
        announcements: delta
        .announcements()
        .map(announcement => {
          node_id: announcement.node_id,
          generation: announcement.generation,
          live: announcement.live,
          is_atomic: announcement.is_atomic,
          text: announcement.text,
        }),
      })
    @runtime.SemanticsRead::Unchanged(generation) => Unchanged(generation)
  }
}

///|
fn runtime_action_request(
  request : AgentActionRequest,
) -> @runtime.PerformSemanticsActionRequest {
  {
    target: request.target,
    action: request.action,
    precondition: match request.precondition {
      Exact(generation) =>
        @runtime.SemanticsGenerationPrecondition::Exact(generation)
      Latest => @runtime.SemanticsGenerationPrecondition::Latest
    },
  }
}

///|
fn agent_action_receipt(
  receipt : @runtime.SemanticsActionReceipt,
) -> AgentActionReceipt {
  {
    before: receipt.before,
    after: receipt.after,
    pending_work: receipt.pending_work,
  }
}

///|
fn agent_action_error(
  error : @runtime.SemanticsActionDispatchError,
) -> AgentActionError {
  match error {
    @runtime.SemanticsActionDispatchError::RuntimeClosed => HostClosed
    @runtime.SemanticsActionDispatchError::StaleGeneration(expected, current) =>
      StaleGeneration(expected, current)
    @runtime.SemanticsActionDispatchError::TargetNotFound(target) =>
      TargetNotFound(target)
    @runtime.SemanticsActionDispatchError::TargetAmbiguous(id) =>
      TargetAmbiguous(id)
    @runtime.SemanticsActionDispatchError::TargetDisabled(target) =>
      TargetDisabled(target)
    @runtime.SemanticsActionDispatchError::ActionUnavailable(target, kind) =>
      ActionUnavailable(target, kind)
    @runtime.SemanticsActionDispatchError::HandlerRejected(target, kind) =>
      HandlerRejected(target, kind)
    @runtime.SemanticsActionDispatchError::ReentrantDispatch =>
      ReentrantDispatch
  }
}

///|
pub(all) struct RuntimeStateSnapshot {
  dispatched_count : Int
  update_count : Int
  pending_message_count : Int
  active_subscription_count : Int
  active_effect_task_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PaintSummary {
  texts : Array[String]
  draw_command_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DiagnosticsDispatchResult {
  accepted : Bool
  reason : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AgentDiagnosticsError {
  HostClosed
} derive(Eq, Debug, ToJson)

///|
pub fn AgentDiagnosticsError::code(self : AgentDiagnosticsError) -> String {
  match self {
    HostClosed => "host_closed"
  }
}
