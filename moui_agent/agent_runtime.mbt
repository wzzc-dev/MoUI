///|
/// Application-owned decision returned before a semantic action is dispatched.
/// The policy callback is deliberately synchronous and model-agnostic: an
/// application can inspect the target, action and current business state, then
/// decide whether a human confirmation is needed.
pub(all) enum AgentActionPolicy {
  Allow
  Deny(String)
  RequireConfirmation(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AgentConfirmationDecision {
  Approved
  Rejected(String)
  Expired
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AgentConfirmationRequest {
  request_id : String
  request : AgentActionRequest
  generation : @core.SemanticsGeneration?
  reason : String
} derive(Eq, Debug, ToJson)

///|
pub fn AgentConfirmationRequest::request_id(
  self : AgentConfirmationRequest,
) -> String {
  self.request_id
}

///|
pub fn AgentConfirmationRequest::request(
  self : AgentConfirmationRequest,
) -> AgentActionRequest {
  self.request
}

///|
pub fn AgentConfirmationRequest::reason(
  self : AgentConfirmationRequest,
) -> String {
  self.reason
}

///|
/// A trace record is safe to export by default. SetText payloads are retained
/// in memory for replay but are replaced with a marker by this type's JSON
/// representation. This keeps replay useful without leaking credentials into
/// Inspector reports or MCP logs.
pub(all) struct AgentTraceEntry {
  trace_id : UInt64
  target : @core.SemanticsTarget
  action : AgentActionRequest
  policy : String
  confirmation : String?
  execution : String
  before : @core.SemanticsGeneration?
  after : @core.SemanticsGeneration?
  sensitive : Bool
} derive(Eq, Debug)

///|
pub fn AgentTraceEntry::trace_id(self : AgentTraceEntry) -> UInt64 {
  self.trace_id
}

///|
pub fn AgentTraceEntry::target(self : AgentTraceEntry) -> @core.SemanticsTarget {
  self.target
}

///|
pub fn AgentTraceEntry::action(self : AgentTraceEntry) -> AgentActionRequest {
  self.action
}

///|
pub fn AgentTraceEntry::policy(self : AgentTraceEntry) -> String {
  self.policy
}

///|
pub fn AgentTraceEntry::confirmation(self : AgentTraceEntry) -> String? {
  self.confirmation
}

///|
pub fn AgentTraceEntry::execution(self : AgentTraceEntry) -> String {
  self.execution
}

///|
pub fn AgentTraceEntry::before(
  self : AgentTraceEntry,
) -> @core.SemanticsGeneration? {
  self.before
}

///|
pub fn AgentTraceEntry::after(
  self : AgentTraceEntry,
) -> @core.SemanticsGeneration? {
  self.after
}

///|
pub fn AgentTraceEntry::is_sensitive(self : AgentTraceEntry) -> Bool {
  self.sensitive
}

///|
fn trace_action_json(action : AgentActionRequest, sensitive : Bool) -> Json {
  match action.action {
    @core.SemanticsAction::Activate => ({ "kind": "activate" } : Json)
    @core.SemanticsAction::Focus => ({ "kind": "focus" } : Json)
    @core.SemanticsAction::SetText(value) =>
      (
        {
          "kind": "set_text",
          "value": if sensitive {
            "<redacted>"
          } else {
            value
          },
        } : Json)
    @core.SemanticsAction::Submit => ({ "kind": "submit" } : Json)
    @core.SemanticsAction::Scroll(direction) =>
      ({ "kind": "scroll", "direction": direction.to_json() } : Json)
    @core.SemanticsAction::Select => ({ "kind": "select" } : Json)
    @core.SemanticsAction::Expand => ({ "kind": "expand" } : Json)
    @core.SemanticsAction::Collapse => ({ "kind": "collapse" } : Json)
    @core.SemanticsAction::Dismiss => ({ "kind": "dismiss" } : Json)
    @core.SemanticsAction::Increment => ({ "kind": "increment" } : Json)
    @core.SemanticsAction::Decrement => ({ "kind": "decrement" } : Json)
    @core.SemanticsAction::SetNumericValue(value) =>
      ({ "kind": "set_numeric_value", "value": value } : Json)
    @core.SemanticsAction::SetSelection(range) =>
      (
        { "kind": "set_selection", "start": range.start, "end": range.end } :
        Json)
    @core.SemanticsAction::ShowMenu => ({ "kind": "show_menu" } : Json)
  }
}

///|
pub impl ToJson for AgentTraceEntry with fn to_json(self : AgentTraceEntry) -> Json {
  (
    {
      "trace_id": self.trace_id.to_string(radix=10),
      "target": self.target.to_json(),
      "action": trace_action_json(self.action, self.sensitive),
      "policy": self.policy,
      "confirmation": self.confirmation,
      "execution": self.execution,
      "before": self.before,
      "after": self.after,
      "sensitive": self.sensitive,
    } : Json)
}

///|
pub(all) struct AgentTraceRead {
  cursor : UInt64
  entries : Array[AgentTraceEntry]
} derive(Eq, Debug, ToJson)

///|
pub fn AgentTraceRead::new(
  cursor~ : UInt64,
  entries~ : Array[AgentTraceEntry],
) -> AgentTraceRead {
  { cursor, entries }
}

///|
pub fn AgentTraceRead::cursor(self : AgentTraceRead) -> UInt64 {
  self.cursor
}

///|
pub fn AgentTraceRead::entries(self : AgentTraceRead) -> Array[AgentTraceEntry] {
  self.entries.copy()
}

///|
pub(all) struct AgentReplayRequest {
  cursor : UInt64
  require_confirmation : Bool
} derive(Eq, Debug, ToJson)

///|
/// Namespace for replay helpers. Replay itself is stateless; mutable policy
/// and trace state stays owned by the host passed to `run`.
pub struct AgentReplay {}

///|
pub fn AgentReplay::new() -> AgentReplay {
  AgentReplay::{  }
}

///|
pub fn AgentReplayRequest::new(
  cursor? : UInt64 = 0UL,
  require_confirmation? : Bool = true,
) -> AgentReplayRequest {
  { cursor, require_confirmation }
}

///|
pub fn AgentReplayRequest::cursor(self : AgentReplayRequest) -> UInt64 {
  self.cursor
}

///|
pub fn AgentReplayRequest::require_confirmation(
  self : AgentReplayRequest,
) -> Bool {
  self.require_confirmation
}

///|
pub(all) struct AgentReplayResult {
  success : Bool
  completed : Int
  stopped_at : Int?
  failure : AgentActionError?
  receipts : Array[AgentActionReceipt]
} derive(Eq, Debug, ToJson)

///|
pub fn AgentReplayResult::success(self : AgentReplayResult) -> Bool {
  self.success
}

///|
pub fn AgentReplayResult::completed(self : AgentReplayResult) -> Int {
  self.completed
}

///|
pub fn AgentReplayResult::stopped_at(self : AgentReplayResult) -> Int? {
  self.stopped_at
}

///|
pub fn AgentReplayResult::failure(
  self : AgentReplayResult,
) -> AgentActionError? {
  self.failure
}

///|
pub fn AgentReplayResult::receipts(
  self : AgentReplayResult,
) -> Array[AgentActionReceipt] {
  self.receipts.copy()
}

///|
pub(all) enum AgentScenarioStep {
  ReadSemantics
  Perform(AgentActionRequest)
  AssertTarget(@core.SemanticId)
  AssertAction(@core.SemanticId, @core.SemanticsActionKind)
  AssertGenerationChanged
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AgentScenario {
  name : String
  steps : Array[AgentScenarioStep]
} derive(Eq, Debug, ToJson)

///|
pub fn AgentScenario::new(
  name~ : String,
  steps~ : Array[AgentScenarioStep],
) -> AgentScenario {
  { name, steps }
}

///|
pub fn AgentScenario::name(self : AgentScenario) -> String {
  self.name
}

///|
pub fn AgentScenario::steps(self : AgentScenario) -> Array[AgentScenarioStep] {
  self.steps.copy()
}

///|
pub(all) struct AgentScenarioResult {
  name : String
  passed : Bool
  completed_steps : Int
  failure : String?
  final_generation : @core.SemanticsGeneration?
} derive(Eq, Debug, ToJson)

///|
pub fn AgentScenarioResult::passed(self : AgentScenarioResult) -> Bool {
  self.passed
}

///|
pub fn AgentScenarioResult::completed_steps(self : AgentScenarioResult) -> Int {
  self.completed_steps
}

///|
pub fn AgentScenarioResult::failure(self : AgentScenarioResult) -> String? {
  self.failure
}

///|
pub(open) trait AgentTraceHost {
  fn read_trace(Self, cursor : UInt64) -> Result[AgentTraceRead, AgentReadError]
  fn replay_trace(Self, request : AgentReplayRequest) -> Result[
    AgentReplayResult,
    AgentActionError,
  ]
  fn read_policy_state(Self) -> AgentPolicyState
}

///|
pub(all) struct AgentPolicyState {
  pending : Array[AgentConfirmationRequest]
  trace_count : Int
} derive(Eq, Debug, ToJson)

///|
pub fn AgentPolicyState::new(
  pending? : Array[AgentConfirmationRequest] = [],
  trace_count? : Int = 0,
) -> AgentPolicyState {
  { pending, trace_count }
}

///|
pub fn AgentPolicyState::pending(
  self : AgentPolicyState,
) -> Array[AgentConfirmationRequest] {
  self.pending.copy()
}

///|
pub fn AgentPolicyState::trace_count(self : AgentPolicyState) -> Int {
  self.trace_count
}

///|
pub struct PolicyAgentHost[Host] {
  inner : Host
  policy : (AgentActionRequest) -> AgentActionPolicy
  pending : Array[AgentConfirmationRequest]
  trace : Array[AgentTraceEntry]
  mut next_request : UInt64
  mut next_trace : UInt64
}

///|
fn allow_all(_request : AgentActionRequest) -> AgentActionPolicy {
  AgentActionPolicy::Allow
}

///|
fn default_policy(request : AgentActionRequest) -> AgentActionPolicy {
  if is_high_risk_action(request.action) {
    AgentActionPolicy::RequireConfirmation("high-risk action")
  } else {
    AgentActionPolicy::Allow
  }
}

///|
pub fn[Host] PolicyAgentHost::new(inner : Host) -> PolicyAgentHost[Host] {
  PolicyAgentHost::with_policy(inner, allow_all)
}

///|
pub fn[Host] PolicyAgentHost::with_policy(
  inner : Host,
  policy : (AgentActionRequest) -> AgentActionPolicy,
) -> PolicyAgentHost[Host] {
  { inner, policy, pending: [], trace: [], next_request: 1UL, next_trace: 1UL }
}

///|
/// Safer composition-root default: text, numeric and submit actions require a
/// confirmation, while read/navigation actions remain autonomous.
pub fn[Host] PolicyAgentHost::with_default_policy(
  inner : Host,
) -> PolicyAgentHost[Host] {
  PolicyAgentHost::with_policy(inner, default_policy)
}

///|
pub fn[Host] PolicyAgentHost::inner(self : PolicyAgentHost[Host]) -> Host {
  self.inner
}

///|
fn action_is_sensitive(action : @core.SemanticsAction) -> Bool {
  match action {
    @core.SemanticsAction::SetText(_) => true
    _ => false
  }
}

///|
fn confirmation_code(decision : AgentConfirmationDecision) -> String {
  match decision {
    Approved => "approved"
    Rejected(_) => "rejected"
    Expired => "expired"
  }
}

///|
fn trace_execution(error : AgentActionError?) -> String {
  match error {
    None => "success"
    Some(value) => value.code()
  }
}

///|
fn[Host] PolicyAgentHost::record(
  self : PolicyAgentHost[Host],
  request : AgentActionRequest,
  policy : String,
  confirmation : String?,
  error : AgentActionError?,
  receipt : AgentActionReceipt?,
) -> Unit {
  self.trace.push({
    trace_id: self.next_trace,
    target: request.target,
    action: request,
    policy,
    confirmation,
    execution: trace_execution(error),
    before: receipt.map(value => value.before),
    after: receipt.map(value => value.after),
    sensitive: action_is_sensitive(request.action),
  })
  self.next_trace = self.next_trace + 1UL
}

///|
pub impl[Host : AgentHost] AgentHost for PolicyAgentHost[Host] with fn read_semantics(
  self,
  since,
) {
  self.inner.read_semantics(since)
}

///|
pub impl[Host : AgentHost] AgentHost for PolicyAgentHost[Host] with fn perform_action(
  self,
  request,
) {
  let decision = (self.policy)(request)
  match decision {
    AgentActionPolicy::Allow =>
      match self.inner.perform_action(request) {
        Ok(receipt) => {
          self.record(request, "allow", None, None, Some(receipt))
          Ok(receipt)
        }
        Err(error) => {
          self.record(request, "allow", None, Some(error), None)
          Err(error)
        }
      }
    AgentActionPolicy::Deny(reason) => {
      let error = AgentActionError::PolicyDenied(reason)
      self.record(request, "deny", None, Some(error), None)
      Err(error)
    }
    AgentActionPolicy::RequireConfirmation(reason) => {
      let request_id = "approval-" + self.next_request.to_string(radix=10)
      self.next_request = self.next_request + 1UL
      self.pending.push({
        request_id,
        request,
        generation: match request.precondition {
          AgentGenerationPrecondition::Exact(value) => Some(value)
          AgentGenerationPrecondition::Latest => None
        },
        reason,
      })
      let error = AgentActionError::ConfirmationRequired(request_id)
      self.record(
        request,
        "require_confirmation",
        Some("pending"),
        Some(error),
        None,
      )
      Err(error)
    }
  }
}

///|
/// Diagnostics remain an opt-in pass-through surface when the wrapped host
/// provides it. Policy decisions are recorded by the AgentHost methods above;
/// runtime counters and paint data are not duplicated here.
pub impl[Host : AgentDiagnosticsHost] AgentDiagnosticsHost for PolicyAgentHost[
  Host,
] with fn runtime_state(self) {
  self.inner.runtime_state()
}

///|
pub impl[Host : AgentDiagnosticsHost] AgentDiagnosticsHost for PolicyAgentHost[
  Host,
] with fn paint_summary(self) {
  self.inner.paint_summary()
}

///|
pub impl[Host : AgentDiagnosticsHost] AgentDiagnosticsHost for PolicyAgentHost[
  Host,
] with fn dispatch_event(self, event) {
  self.inner.dispatch_event(event)
}

///|
pub impl[Host : AgentDiagnosticsHost] AgentDiagnosticsHost for PolicyAgentHost[
  Host,
] with fn dispatch_command(self, intent) {
  self.inner.dispatch_command(intent)
}

///|
fn[Host] PolicyAgentHost::find_pending(
  self : PolicyAgentHost[Host],
  request_id : String,
) -> (Int, AgentConfirmationRequest)? {
  for index in 0..<self.pending.length() {
    if self.pending[index].request_id == request_id {
      return Some((index, self.pending[index]))
    }
  }
  None
}

///|
pub fn[Host : AgentHost] PolicyAgentHost::approve(
  self : PolicyAgentHost[Host],
  request_id : String,
) -> Result[AgentActionReceipt, AgentActionError] {
  match self.find_pending(request_id) {
    None => Err(AgentActionError::ConfirmationExpired(request_id))
    Some((index, pending)) => {
      ignore(self.pending.remove(index))
      match self.inner.perform_action(pending.request) {
        Ok(receipt) => {
          self.record(
            pending.request,
            "allow",
            Some(confirmation_code(AgentConfirmationDecision::Approved)),
            None,
            Some(receipt),
          )
          Ok(receipt)
        }
        Err(error) => {
          self.record(
            pending.request,
            "allow",
            Some(confirmation_code(AgentConfirmationDecision::Approved)),
            Some(error),
            None,
          )
          Err(error)
        }
      }
    }
  }
}

///|
pub fn[Host] PolicyAgentHost::reject(
  self : PolicyAgentHost[Host],
  request_id : String,
  reason? : String = "rejected by user",
) -> Result[Unit, AgentActionError] {
  match self.find_pending(request_id) {
    None => Err(AgentActionError::ConfirmationExpired(request_id))
    Some((index, pending)) => {
      ignore(self.pending.remove(index))
      let error = AgentActionError::ConfirmationRejected(reason)
      self.record(
        pending.request,
        "require_confirmation",
        Some(confirmation_code(AgentConfirmationDecision::Rejected(reason))),
        Some(error),
        None,
      )
      Err(error)
    }
  }
}

///|
pub fn[Host] PolicyAgentHost::clear_expired(
  self : PolicyAgentHost[Host],
) -> Int {
  let count = self.pending.length()
  for pending in self.pending.copy() {
    let error = AgentActionError::ConfirmationExpired(pending.request_id)
    self.record(
      pending.request,
      "require_confirmation",
      Some("expired"),
      Some(error),
      None,
    )
  }
  self.pending.clear()
  count
}

///|
pub fn[Host] PolicyAgentHost::expire(
  self : PolicyAgentHost[Host],
  request_id : String,
) -> Result[Unit, AgentActionError] {
  match self.find_pending(request_id) {
    None => Err(AgentActionError::ConfirmationExpired(request_id))
    Some((index, pending)) => {
      ignore(self.pending.remove(index))
      let error = AgentActionError::ConfirmationExpired(pending.request_id)
      self.record(
        pending.request,
        "require_confirmation",
        Some("expired"),
        Some(error),
        None,
      )
      Err(error)
    }
  }
}

///|
pub fn[Host] PolicyAgentHost::pending(
  self : PolicyAgentHost[Host],
) -> Array[AgentConfirmationRequest] {
  self.pending.copy()
}

///|
pub fn[Host] PolicyAgentHost::trace(
  self : PolicyAgentHost[Host],
) -> Array[AgentTraceEntry] {
  self.trace.copy()
}

///|
pub impl[Host : AgentHost] AgentTraceHost for PolicyAgentHost[Host] with fn read_trace(
  self,
  cursor,
) {
  let start = cursor.to_int()
  let entries : Array[AgentTraceEntry] = []
  if start < self.trace.length() {
    for index in start..<self.trace.length() {
      entries.push(self.trace[index])
    }
  }
  Ok({ cursor: self.trace.length().to_uint64(), entries })
}

///|
pub impl[Host : AgentHost] AgentTraceHost for PolicyAgentHost[Host] with fn replay_trace(
  self,
  request,
) {
  let read = AgentTraceHost::read_trace(self, request.cursor)
  match read {
    Err(_) => Err(AgentActionError::HostClosed)
    Ok(trace) =>
      Ok(
        AgentReplay::run(
          self,
          trace.entries,
          require_confirmation=request.require_confirmation,
        ),
      )
  }
}

///|
pub impl[Host : AgentHost] AgentTraceHost for PolicyAgentHost[Host] with fn read_policy_state(
  self,
) -> AgentPolicyState {
  { pending: self.pending.copy(), trace_count: self.trace.length() }
}

///|
pub fn[Host : AgentHost] AgentReplay::run(
  host : Host,
  entries : Array[AgentTraceEntry],
  require_confirmation? : Bool = true,
) -> AgentReplayResult {
  let receipts : Array[AgentActionReceipt] = []
  let mut completed = 0
  for index in 0..<entries.length() {
    let entry = entries[index]
    match replay_entry_request(entry) {
      None => ()
      Some(request) => {
        if require_confirmation && is_high_risk_action(request.action) {
          return {
            success: false,
            completed,
            stopped_at: Some(index),
            failure: Some(
              AgentActionError::ConfirmationRequired("replay-confirmation"),
            ),
            receipts,
          }
        }
        match host.perform_action(request) {
          Ok(receipt) => {
            receipts.push(receipt)
            completed = completed + 1
          }
          Err(error) =>
            return {
              success: false,
              completed,
              stopped_at: Some(index),
              failure: Some(error),
              receipts,
            }
        }
      }
    }
  }
  { success: true, completed, stopped_at: None, failure: None, receipts }
}

///|
/// Only successful trace entries are replayable. A policy rejection or a
/// pending confirmation describes an attempted action, not an action that
/// should be repeated. Replaying with the recorded `before` generation makes
/// stale UI versions fail closed even when the original request used Latest.
fn replay_entry_request(entry : AgentTraceEntry) -> AgentActionRequest? {
  if entry.execution != "success" {
    return None
  }
  Some({
    ..entry.action,
    precondition: match entry.before {
      Some(generation) => AgentGenerationPrecondition::Exact(generation)
      None => entry.action.precondition
    },
  })
}

///|
fn is_high_risk_action(action : @core.SemanticsAction) -> Bool {
  match action {
    @core.SemanticsAction::Submit
    | @core.SemanticsAction::SetText(_)
    | @core.SemanticsAction::SetNumericValue(_) => true
    _ => false
  }
}

///|
pub fn[Host : AgentHost] AgentScenario::run(
  self : AgentScenario,
  host : Host,
) -> AgentScenarioResult {
  let mut generation : @core.SemanticsGeneration? = None
  let mut generation_changed = false
  let mut completed = 0
  for step in self.steps {
    match step {
      AgentScenarioStep::ReadSemantics =>
        match host.read_semantics(None) {
          Ok(read) => {
            let next_generation = match read {
              AgentSemanticsRead::Full(snapshot) => Some(snapshot.generation)
              AgentSemanticsRead::Delta(delta) => Some(delta.to)
              AgentSemanticsRead::Unchanged(value) => Some(value)
            }
            match (generation, next_generation) {
              (Some(previous), Some(next)) if previous != next =>
                generation_changed = true
              _ => ()
            }
            generation = next_generation
            completed = completed + 1
          }
          Err(_) =>
            return {
              name: self.name,
              passed: false,
              completed_steps: completed,
              failure: Some("read_semantics failed"),
              final_generation: generation,
            }
        }
      AgentScenarioStep::Perform(request) =>
        match host.perform_action(request) {
          Ok(receipt) => {
            if receipt.before != receipt.after {
              generation_changed = true
            }
            match generation {
              Some(previous) if previous != receipt.after =>
                generation_changed = true
              _ => ()
            }
            generation = Some(receipt.after)
            completed = completed + 1
          }
          Err(error) =>
            return {
              name: self.name,
              passed: false,
              completed_steps: completed,
              failure: Some(error.code()),
              final_generation: generation,
            }
        }
      AgentScenarioStep::AssertTarget(id) =>
        match host.read_semantics(None) {
          Ok(AgentSemanticsRead::Full(snapshot)) if snapshot.nodes.any(node => {
              node.semantic_id == Some(id)
            }) => completed = completed + 1
          _ =>
            return {
              name: self.name,
              passed: false,
              completed_steps: completed,
              failure: Some("assert_target failed"),
              final_generation: generation,
            }
        }
      AgentScenarioStep::AssertAction(id, kind) =>
        match host.read_semantics(None) {
          Ok(AgentSemanticsRead::Full(snapshot)) if snapshot.nodes.any(node => {
              node.semantic_id == Some(id) && node.actions.contains(kind)
            }) => completed = completed + 1
          _ =>
            return {
              name: self.name,
              passed: false,
              completed_steps: completed,
              failure: Some("assert_action failed"),
              final_generation: generation,
            }
        }
      AgentScenarioStep::AssertGenerationChanged =>
        if generation_changed {
          generation_changed = false
          completed = completed + 1
        } else {
          return {
            name: self.name,
            passed: false,
            completed_steps: completed,
            failure: Some("generation did not change"),
            final_generation: generation,
          }
        }
    }
  }
  {
    name: self.name,
    passed: true,
    completed_steps: completed,
    failure: None,
    final_generation: generation,
  }
}
