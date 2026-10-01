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
pub extend AgentSemanticsIssue with Debug::{to_repr}

///|
pub extend AgentSemanticsIssue with Eq::{not_equal, equal}

///|
pub extend AgentSemanticsIssue with ToJson::{to_json}

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
pub extend AgentSemanticsSnapshot with Debug::{to_repr}

///|
pub extend AgentSemanticsSnapshot with Eq::{not_equal, equal}

///|
pub extend AgentSemanticsSnapshot with ToJson::{to_json}

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
pub extend AgentSemanticsDelta with Debug::{to_repr}

///|
pub extend AgentSemanticsDelta with Eq::{not_equal, equal}

///|
pub extend AgentSemanticsDelta with ToJson::{to_json}

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
pub extend AgentAccessibilityAnnouncement with Debug::{to_repr}

///|
pub extend AgentAccessibilityAnnouncement with Eq::{not_equal, equal}

///|
pub extend AgentAccessibilityAnnouncement with ToJson::{to_json}

///|
/// Result of reading committed semantics with an optional independent cursor.
pub(all) enum AgentSemanticsRead {
  Full(AgentSemanticsSnapshot)
  Delta(AgentSemanticsDelta)
  Unchanged(@core.SemanticsGeneration)
} derive(Eq, Debug, ToJson)

///|
pub extend AgentSemanticsRead with Debug::{to_repr}

///|
pub extend AgentSemanticsRead with Eq::{not_equal, equal}

///|
pub extend AgentSemanticsRead with ToJson::{to_json}

///|
pub(all) enum AgentReadError {
  HostClosed
} derive(Eq, Debug, ToJson)

///|
pub extend AgentReadError with Debug::{to_repr}

///|
pub extend AgentReadError with Eq::{not_equal, equal}

///|
pub extend AgentReadError with ToJson::{to_json}

///|
pub(all) enum AgentGenerationPrecondition {
  Exact(@core.SemanticsGeneration)
  Latest
} derive(Eq, Debug, ToJson)

///|
pub extend AgentGenerationPrecondition with Debug::{to_repr}

///|
pub extend AgentGenerationPrecondition with Eq::{not_equal, equal}

///|
pub extend AgentGenerationPrecondition with ToJson::{to_json}

///|
pub(all) struct AgentActionRequest {
  target : @core.SemanticsTarget
  action : @core.SemanticsAction
  precondition : AgentGenerationPrecondition
} derive(Eq, Debug, ToJson)

///|
pub extend AgentActionRequest with Debug::{to_repr}

///|
pub extend AgentActionRequest with Eq::{not_equal, equal}

///|
pub extend AgentActionRequest with ToJson::{to_json}

///|
pub(all) struct AgentActionReceipt {
  before : @core.SemanticsGeneration
  after : @core.SemanticsGeneration
  pending_work : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend AgentActionReceipt with Debug::{to_repr}

///|
pub extend AgentActionReceipt with Eq::{not_equal, equal}

///|
pub extend AgentActionReceipt with ToJson::{to_json}

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
} derive(Eq, Debug, ToJson)

///|
pub extend AgentActionError with Debug::{to_repr}

///|
pub extend AgentActionError with Eq::{not_equal, equal}

///|
pub extend AgentActionError with ToJson::{to_json}

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
  }
}

///|
fn agent_semantics_issue(
  issue : @runtime.SemanticsIssue,
) -> AgentSemanticsIssue {
  match issue {
    DuplicateSemanticId(id, nodes) => DuplicateSemanticId(id, nodes.copy())
    MissingRelationTarget(source, kind, id) =>
      MissingRelationTarget(source, kind, id)
    AmbiguousRelationTarget(source, kind, id, nodes) =>
      AmbiguousRelationTarget(source, kind, id, nodes.copy())
  }
}

///|
fn agent_semantics_read(read : @runtime.SemanticsRead) -> AgentSemanticsRead {
  match read {
    Full(snapshot) =>
      Full({
        generation: snapshot.generation(),
        root: snapshot.root(),
        focused: snapshot.focused(),
        nodes: snapshot.nodes(),
        issues: snapshot.issues().map(agent_semantics_issue),
      })
    Delta(delta) =>
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
    Unchanged(generation) => Unchanged(generation)
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
      Exact(generation) => Exact(generation)
      Latest => Latest
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
    RuntimeClosed => HostClosed
    StaleGeneration(expected, current) => StaleGeneration(expected, current)
    TargetNotFound(target) => TargetNotFound(target)
    TargetAmbiguous(id) => TargetAmbiguous(id)
    TargetDisabled(target) => TargetDisabled(target)
    ActionUnavailable(target, kind) => ActionUnavailable(target, kind)
    HandlerRejected(target, kind) => HandlerRejected(target, kind)
    ReentrantDispatch => ReentrantDispatch
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
pub extend RuntimeStateSnapshot with Debug::{to_repr}

///|
pub extend RuntimeStateSnapshot with Eq::{not_equal, equal}

///|
pub extend RuntimeStateSnapshot with ToJson::{to_json}

///|
pub(all) struct PaintSummary {
  texts : Array[String]
  draw_command_count : Int
} derive(Eq, Debug, ToJson)

///|
pub extend PaintSummary with Debug::{to_repr}

///|
pub extend PaintSummary with Eq::{not_equal, equal}

///|
pub extend PaintSummary with ToJson::{to_json}

///|
pub(all) struct DiagnosticsDispatchResult {
  accepted : Bool
  reason : String?
} derive(Eq, Debug, ToJson)

///|
pub extend DiagnosticsDispatchResult with Debug::{to_repr}

///|
pub extend DiagnosticsDispatchResult with Eq::{not_equal, equal}

///|
pub extend DiagnosticsDispatchResult with ToJson::{to_json}

///|
pub(all) enum AgentDiagnosticsError {
  HostClosed
} derive(Eq, Debug, ToJson)

///|
pub extend AgentDiagnosticsError with Debug::{to_repr}

///|
pub extend AgentDiagnosticsError with Eq::{not_equal, equal}

///|
pub extend AgentDiagnosticsError with ToJson::{to_json}

///|
pub fn AgentDiagnosticsError::code(self : AgentDiagnosticsError) -> String {
  match self {
    HostClosed => "host_closed"
  }
}
