///|
/// Visibility declaration for application-owned semantic IDs. The value is
/// kept outside `moui/core` because it is an Agent exposure decision, not a
/// UI-kernel property.
pub(all) enum AgentFieldVisibility {
  Public
  Protected(String)
  Hidden
} derive(Eq, Debug, ToJson)

///|
pub struct AgentVisibilityPolicy {
  protected_scopes : Map[String, String]
  hidden : Array[String]
}

///|
pub fn AgentVisibilityPolicy::new() -> AgentVisibilityPolicy {
  { protected_scopes: {}, hidden: [] }
}

///|
pub fn AgentVisibilityPolicy::protect(
  self : AgentVisibilityPolicy,
  semantic_id~ : String,
  scope~ : String,
) -> AgentVisibilityPolicy {
  self.protected_scopes[semantic_id] = scope
  self
}

///|
pub fn AgentVisibilityPolicy::hide(
  self : AgentVisibilityPolicy,
  semantic_id~ : String,
) -> AgentVisibilityPolicy {
  if !self.hidden.contains(semantic_id) {
    self.hidden.push(semantic_id)
  }
  self
}

///|
pub fn AgentVisibilityPolicy::visibility(
  self : AgentVisibilityPolicy,
  semantic_id : String,
) -> AgentFieldVisibility {
  if self.hidden.contains(semantic_id) {
    AgentFieldVisibility::Hidden
  } else {
    match self.protected_scopes.get(semantic_id) {
      Some(scope) => AgentFieldVisibility::Protected(scope)
      None => AgentFieldVisibility::Public
    }
  }
}

///|
fn has_scope(scopes : Array[String], required : String) -> Bool {
  scopes.contains(required)
}

///|
fn redact_node(
  node : @core.SemanticsNode,
  policy : AgentVisibilityPolicy,
  scopes : Array[String],
) -> @core.SemanticsNode {
  let redact_value = (replacement : String) => {
    ..node,
    label: "",
    value: replacement,
    description: "",
    url: "",
    numeric: None,
    text: None,
    collection: None,
    relations: @core.SemanticsRelations::empty(),
  }
  match node.semantic_id {
    None => node
    Some(id) =>
      match policy.visibility(id.value()) {
        AgentFieldVisibility::Public => node
        AgentFieldVisibility::Hidden => redact_value("")
        AgentFieldVisibility::Protected(scope) =>
          if has_scope(scopes, scope) {
            node
          } else {
            redact_value("<redacted>")
          }
      }
  }
}

///|
fn redact_snapshot(
  snapshot : AgentSemanticsSnapshot,
  policy : AgentVisibilityPolicy,
  scopes : Array[String],
) -> AgentSemanticsSnapshot {
  {
    ..snapshot,
    nodes: snapshot.nodes.map(node => redact_node(node, policy, scopes)),
  }
}

///|
fn redact_delta(
  delta : AgentSemanticsDelta,
  policy : AgentVisibilityPolicy,
  scopes : Array[String],
) -> AgentSemanticsDelta {
  {
    ..delta,
    upserted: delta.upserted.map(node => redact_node(node, policy, scopes)),
  }
}

///|
pub fn redact_semantics_read(
  read : AgentSemanticsRead,
  policy : AgentVisibilityPolicy,
  scopes? : Array[String] = [],
) -> AgentSemanticsRead {
  match read {
    AgentSemanticsRead::Full(snapshot) =>
      AgentSemanticsRead::Full(redact_snapshot(snapshot, policy, scopes))
    AgentSemanticsRead::Delta(delta) =>
      AgentSemanticsRead::Delta(redact_delta(delta, policy, scopes))
    AgentSemanticsRead::Unchanged(generation) =>
      AgentSemanticsRead::Unchanged(generation)
  }
}

///|
/// AgentHost wrapper that applies semantic visibility and target Scope checks
/// before delegating to the existing runtime host.
pub struct AgentSecureSession[Host] {
  inner : Host
  visibility : AgentVisibilityPolicy
  scopes : Array[String]
}

///|
pub fn[Host] AgentSecureSession::new(
  inner : Host,
  visibility : AgentVisibilityPolicy,
  scopes? : Array[String] = [],
) -> AgentSecureSession[Host] {
  { inner, visibility, scopes }
}

///|
pub fn[Host] AgentSecureSession::with_scopes(
  self : AgentSecureSession[Host],
  scopes : Array[String],
) -> AgentSecureSession[Host] {
  { ..self, scopes, }
}

///|
pub fn[Host] AgentSecureSession::inner(self : AgentSecureSession[Host]) -> Host {
  self.inner
}

///|
/// Execute a Skill with the scopes granted by that invocation. The scoped
/// session is a short-lived copy, so a Skill cannot widen the permissions of
/// later semantic reads or actions.
pub fn[Host : AgentHost] AgentSecureSession::execute_skill(
  self : AgentSecureSession[Host],
  registry : AgentSkillRegistry,
  call : AgentSkillCall,
) -> AgentSkillResult {
  registry.call(self.with_scopes(call.scopes()), call)
}

///|
fn[Host : AgentHost] AgentSecureSession::target_semantic_id(
  self : AgentSecureSession[Host],
  target : @core.SemanticsTarget,
) -> String? {
  match target {
    @core.SemanticsTarget::BySemanticId(id) => Some(id.value())
    @core.SemanticsTarget::ByNodeId(node_id) =>
      match self.inner.read_semantics(None) {
        Ok(AgentSemanticsRead::Full(snapshot)) =>
          for node in snapshot.nodes() {
            if node.node_id == node_id {
              return node.semantic_id.map(id => id.value())
            }
          } nobreak {
            None
          }
        _ => None
      }
  }
}

///|
fn[Host : AgentHost] AgentSecureSession::secure_target_error(
  self : AgentSecureSession[Host],
  request : AgentActionRequest,
) -> AgentActionError? {
  match self.target_semantic_id(request.target) {
    None => None
    Some(id) =>
      match self.visibility.visibility(id) {
        AgentFieldVisibility::Public => None
        AgentFieldVisibility::Hidden =>
          Some(AgentActionError::PolicyDenied("target is hidden"))
        AgentFieldVisibility::Protected(scope) =>
          if has_scope(self.scopes, scope) {
            None
          } else {
            Some(AgentActionError::PolicyDenied("missing scope: " + scope))
          }
      }
  }
}

///|
pub impl[Host : AgentHost] AgentHost for AgentSecureSession[Host] with fn read_semantics(
  self,
  since,
) {
  match self.inner.read_semantics(since) {
    Ok(read) =>
      Ok(redact_semantics_read(read, self.visibility, scopes=self.scopes))
    Err(error) => Err(error)
  }
}

///|
pub impl[Host : AgentHost] AgentHost for AgentSecureSession[Host] with fn perform_action(
  self,
  request,
) {
  match self.secure_target_error(request) {
    Some(error) => Err(error)
    None => self.inner.perform_action(request)
  }
}

///|
pub impl[Host : AgentTraceHost] AgentTraceHost for AgentSecureSession[Host] with fn read_trace(
  self,
  cursor,
) {
  self.inner.read_trace(cursor)
}

///|
pub impl[Host : AgentTraceHost] AgentTraceHost for AgentSecureSession[Host] with fn replay_trace(
  self,
  request,
) {
  self.inner.replay_trace(request)
}

///|
pub impl[Host : AgentTraceHost] AgentTraceHost for AgentSecureSession[Host] with fn read_policy_state(
  self,
) {
  self.inner.read_policy_state()
}
