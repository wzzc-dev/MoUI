///|
/// A value used by a declarative Skill action. Inputs are deliberately
/// string-based so a Skill cannot execute arbitrary application code.
pub(all) enum AgentSkillValue {
  Literal(String)
  Input(String)
} derive(Eq, Debug, ToJson)

///|
/// The bounded action vocabulary available to declarative Skills.
pub(all) enum AgentSkillAction {
  Activate
  Focus
  SetText(AgentSkillValue)
  Submit
} derive(Eq, Debug, ToJson)

///|
/// A Skill step is resolved against the committed semantics snapshot before
/// any typed action is dispatched.
pub(all) enum AgentSkillStep {
  ReadSemantics
  AssertTarget(String)
  AssertAction(String, @core.SemanticsActionKind)
  Perform(String, AgentSkillAction)
  AssertGenerationChanged
  RequireScope(String)
  RequireConfirmation(String)
} derive(Eq, Debug, ToJson)

///|
/// Application-owned, versioned declaration of one Agent capability.
pub(all) struct AgentSkillManifest {
  id : String
  version : String
  description : String
  input_schema : Json
  required_scopes : Array[String]
  steps : Array[AgentSkillStep]
} derive(Eq, Debug, ToJson)

///|
pub fn AgentSkillManifest::new(
  id~ : String,
  version~ : String,
  description~ : String,
  input_schema~ : Json,
  required_scopes? : Array[String] = [],
  steps~ : Array[AgentSkillStep],
) -> AgentSkillManifest {
  { id, version, description, input_schema, required_scopes, steps }
}

///|
pub fn AgentSkillManifest::id(self : AgentSkillManifest) -> String {
  self.id
}

///|
pub fn AgentSkillManifest::version(self : AgentSkillManifest) -> String {
  self.version
}

///|
pub fn AgentSkillManifest::description(self : AgentSkillManifest) -> String {
  self.description
}

///|
pub fn AgentSkillManifest::input_schema(self : AgentSkillManifest) -> Json {
  self.input_schema
}

///|
pub fn AgentSkillManifest::required_scopes(
  self : AgentSkillManifest,
) -> Array[String] {
  self.required_scopes.copy()
}

///|
pub fn AgentSkillManifest::steps(
  self : AgentSkillManifest,
) -> Array[AgentSkillStep] {
  self.steps.copy()
}

///|
/// A Skill invocation carries only declared inputs and granted scopes.
pub(all) struct AgentSkillCall {
  skill_id : String
  inputs : Map[String, String]
  scopes : Array[String]
  confirmation : String?
} derive(Eq, Debug, ToJson)

///|
pub fn AgentSkillCall::new(
  skill_id~ : String,
  inputs? : Map[String, String] = {},
  scopes? : Array[String] = [],
  confirmation? : String = "",
) -> AgentSkillCall {
  {
    skill_id,
    inputs,
    scopes,
    confirmation: if confirmation == "" {
      None
    } else {
      Some(confirmation)
    },
  }
}

///|
pub fn AgentSkillCall::skill_id(self : AgentSkillCall) -> String {
  self.skill_id
}

///|
pub fn AgentSkillCall::inputs(self : AgentSkillCall) -> Map[String, String] {
  self.inputs
}

///|
pub fn AgentSkillCall::scopes(self : AgentSkillCall) -> Array[String] {
  self.scopes.copy()
}

///|
pub fn AgentSkillCall::confirmation(self : AgentSkillCall) -> String? {
  self.confirmation
}

///|
pub(all) enum AgentSkillError {
  HostClosed
  UnknownSkill(String)
  InvalidManifest(String)
  MissingScope(String)
  ConfirmationRequired(String)
  TargetNotFound(String)
  ActionUnavailable(String, @core.SemanticsActionKind)
  GenerationUnchanged
  Action(AgentActionError)
} derive(Eq, Debug, ToJson)

///|
pub fn AgentSkillError::code(self : AgentSkillError) -> String {
  match self {
    HostClosed => "host_closed"
    UnknownSkill(_) => "unknown_skill"
    InvalidManifest(_) => "invalid_skill_manifest"
    MissingScope(_) => "missing_skill_scope"
    ConfirmationRequired(_) => "skill_confirmation_required"
    TargetNotFound(_) => "skill_target_not_found"
    ActionUnavailable(_, _) => "skill_action_unavailable"
    GenerationUnchanged => "skill_generation_unchanged"
    Action(error) => error.code()
  }
}

///|
pub(all) struct AgentSkillResult {
  skill_id : String
  success : Bool
  completed_steps : Int
  failed_step : Int?
  error : AgentSkillError?
  generation_before : @core.SemanticsGeneration?
  generation_after : @core.SemanticsGeneration?
  receipts : Array[AgentActionReceipt]
  output : Json
} derive(Eq, Debug, ToJson)

///|
pub fn AgentSkillResult::skill_id(self : AgentSkillResult) -> String {
  self.skill_id
}

///|
pub fn AgentSkillResult::success(self : AgentSkillResult) -> Bool {
  self.success
}

///|
pub fn AgentSkillResult::completed_steps(self : AgentSkillResult) -> Int {
  self.completed_steps
}

///|
pub fn AgentSkillResult::failed_step(self : AgentSkillResult) -> Int? {
  self.failed_step
}

///|
pub fn AgentSkillResult::error(self : AgentSkillResult) -> AgentSkillError? {
  self.error
}

///|
pub fn AgentSkillResult::receipts(
  self : AgentSkillResult,
) -> Array[AgentActionReceipt] {
  self.receipts.copy()
}

///|
pub fn AgentSkillResult::output(self : AgentSkillResult) -> Json {
  self.output
}

///|
/// Registry used by a composition root or a developer tool. Registration
/// rejects duplicate IDs and empty declarations before the Skill is exposed.
pub struct AgentSkillRegistry {
  skills : Array[AgentSkillManifest]
}

///|
pub fn AgentSkillRegistry::new() -> AgentSkillRegistry {
  { skills: [] }
}

///|
pub fn AgentSkillRegistry::register(
  self : AgentSkillRegistry,
  skill : AgentSkillManifest,
) -> Result[Unit, AgentSkillError] {
  if skill.id == "" || skill.version == "" {
    return Err(AgentSkillError::InvalidManifest("id and version are required"))
  }
  if skill.steps.length() == 0 {
    return Err(AgentSkillError::InvalidManifest("steps must not be empty"))
  }
  if self.skills.any(existing => existing.id == skill.id) {
    return Err(AgentSkillError::InvalidManifest("duplicate skill id"))
  }
  self.skills.push(skill)
  Ok(())
}

///|
pub fn AgentSkillRegistry::list(
  self : AgentSkillRegistry,
) -> Array[AgentSkillManifest] {
  self.skills.copy()
}

///|
pub fn AgentSkillRegistry::get(
  self : AgentSkillRegistry,
  id : String,
) -> AgentSkillManifest? {
  for skill in self.skills {
    if skill.id == id {
      return Some(skill)
    }
  }
  None
}

///|
fn resolve_skill_value(
  value : AgentSkillValue,
  inputs : Map[String, String],
) -> Result[String, AgentSkillError] {
  match value {
    AgentSkillValue::Literal(text) => Ok(text)
    AgentSkillValue::Input(name) =>
      match inputs.get(name) {
        Some(value) => Ok(value)
        None =>
          Err(AgentSkillError::InvalidManifest("missing Skill input: " + name))
      }
  }
}

///|
fn skill_action(
  action : AgentSkillAction,
  inputs : Map[String, String],
) -> Result[@core.SemanticsAction, AgentSkillError] {
  match action {
    AgentSkillAction::Activate => Ok(@core.SemanticsAction::Activate)
    AgentSkillAction::Focus => Ok(@core.SemanticsAction::Focus)
    AgentSkillAction::SetText(value) =>
      resolve_skill_value(value, inputs).map(value => {
        @core.SemanticsAction::SetText(value)
      })
    AgentSkillAction::Submit => Ok(@core.SemanticsAction::Submit)
  }
}

///|
fn skill_node(
  snapshot : AgentSemanticsSnapshot,
  id : String,
) -> @core.SemanticsNode? {
  for node in snapshot.nodes() {
    if node.semantic_id is Some(value) && value.value() == id {
      return Some(node)
    }
  }
  None
}

///|
/// Validate the small object-shaped input schema carried by a Skill manifest.
/// MCP decoding guarantees string values; this check enforces declared names
/// and required fields before any semantic read or action is attempted.
fn validate_skill_inputs(
  skill : AgentSkillManifest,
  inputs : Map[String, String],
) -> AgentSkillError? {
  match skill.input_schema {
    Json::Object(fields) => {
      let properties : Map[String, Json]? = match fields.get("properties") {
        None => None
        Some(Json::Object(value)) => Some(value)
        Some(_) =>
          return Some(
            AgentSkillError::InvalidManifest("properties must be an object"),
          )
      }
      for name, _ in inputs {
        match properties {
          Some(value) if value.get(name) is Some(_) => ()
          Some(_) =>
            return Some(
              AgentSkillError::InvalidManifest("unknown Skill input: " + name),
            )
          None => ()
        }
      }
      match fields.get("required") {
        None => ()
        Some(Json::Array(values)) =>
          for value in values {
            match value {
              Json::String(name) if inputs.get(name) is Some(_) => ()
              Json::String(name) =>
                return Some(
                  AgentSkillError::InvalidManifest(
                    "missing Skill input: " + name,
                  ),
                )
              _ =>
                return Some(
                  AgentSkillError::InvalidManifest(
                    "required input names must be strings",
                  ),
                )
            }
          }
        Some(_) =>
          return Some(
            AgentSkillError::InvalidManifest("required must be an array"),
          )
      }
      None
    }
    _ =>
      Some(AgentSkillError::InvalidManifest("input_schema must be an object"))
  }
}

///|
fn skill_result(
  skill_id : String,
  success : Bool,
  completed_steps : Int,
  failed_step : Int?,
  error : AgentSkillError?,
  generation_before : @core.SemanticsGeneration?,
  generation_after : @core.SemanticsGeneration?,
  receipts : Array[AgentActionReceipt],
  output : Json,
) -> AgentSkillResult {
  {
    skill_id,
    success,
    completed_steps,
    failed_step,
    error,
    generation_before,
    generation_after,
    receipts,
    output,
  }
}

///|
fn skill_failure(
  skill : AgentSkillManifest,
  completed : Int,
  failed : Int,
  error : AgentSkillError,
  before : @core.SemanticsGeneration?,
  after : @core.SemanticsGeneration?,
  receipts : Array[AgentActionReceipt],
) -> AgentSkillResult {
  skill_result(
    skill.id,
    false,
    completed,
    Some(failed),
    Some(error),
    before,
    after,
    receipts,
    Json::empty_object(),
  )
}

///|
/// Execute a fixed Skill program against any existing AgentHost.
pub fn[Host : AgentHost] AgentSkillRegistry::call(
  self : AgentSkillRegistry,
  host : Host,
  call : AgentSkillCall,
) -> AgentSkillResult {
  let skill = match self.get(call.skill_id) {
    None =>
      return skill_result(
        call.skill_id,
        false,
        0,
        Some(0),
        Some(AgentSkillError::UnknownSkill(call.skill_id)),
        None,
        None,
        [],
        Json::empty_object(),
      )
    Some(value) => value
  }
  self.execute(host, skill, call)
}

///|
/// A stateless entry point for composition roots that want to name the
/// execution dependency explicitly.
pub struct AgentSkillExecutor {}

///|
pub fn AgentSkillExecutor::new() -> AgentSkillExecutor {
  AgentSkillExecutor::{  }
}

///|
pub fn[Host : AgentHost] AgentSkillExecutor::execute(
  self : AgentSkillExecutor,
  registry : AgentSkillRegistry,
  host : Host,
  call : AgentSkillCall,
) -> AgentSkillResult {
  ignore(self)
  registry.call(host, call)
}

///|
/// Execute a selected Skill manifest only when it is the registered
/// declaration with the same ID and version. This prevents a caller from
/// supplying an ad-hoc manifest to bypass registry validation.
pub fn[Host : AgentHost] AgentSkillRegistry::execute(
  self : AgentSkillRegistry,
  host : Host,
  skill : AgentSkillManifest,
  call : AgentSkillCall,
) -> AgentSkillResult {
  let registered = match self.get(skill.id) {
    Some(value) if value.version == skill.version => value
    _ =>
      return skill_result(
        skill.id,
        false,
        0,
        Some(0),
        Some(AgentSkillError::UnknownSkill(skill.id)),
        None,
        None,
        [],
        Json::empty_object(),
      )
  }
  self.execute_registered(host, registered, call)
}

///|
fn[Host : AgentHost] AgentSkillRegistry::execute_registered(
  self : AgentSkillRegistry,
  host : Host,
  skill : AgentSkillManifest,
  call : AgentSkillCall,
) -> AgentSkillResult {
  ignore(self)
  match validate_skill_inputs(skill, call.inputs) {
    Some(error) => return skill_failure(skill, 0, 0, error, None, None, [])
    None => ()
  }
  for required in skill.required_scopes {
    if !call.scopes.contains(required) {
      return skill_failure(
        skill,
        0,
        0,
        AgentSkillError::MissingScope(required),
        None,
        None,
        [],
      )
    }
  }
  let mut snapshot : AgentSemanticsSnapshot? = None
  let mut before : @core.SemanticsGeneration? = None
  let mut after : @core.SemanticsGeneration? = None
  let mut output = Json::empty_object()
  let receipts : Array[AgentActionReceipt] = []
  let mut completed = 0
  for index, step in skill.steps {
    match step {
      AgentSkillStep::ReadSemantics =>
        match host.read_semantics(None) {
          Ok(AgentSemanticsRead::Full(value)) => {
            if before is None {
              before = Some(value.generation())
            }
            after = Some(value.generation())
            snapshot = Some(value)
            output = ({ "semantics": ToJson::to_json(value) } : Json)
          }
          Ok(AgentSemanticsRead::Delta(value)) => {
            after = Some(value.to())
            output = ({ "semantics_delta": ToJson::to_json(value) } : Json)
          }
          Ok(AgentSemanticsRead::Unchanged(generation)) => {
            after = Some(generation)
            output = ({ "generation": generation.to_json() } : Json)
          }
          Err(_) =>
            return skill_failure(
              skill,
              completed,
              index,
              AgentSkillError::HostClosed,
              before,
              after,
              receipts,
            )
        }
      AgentSkillStep::AssertTarget(id) =>
        match snapshot {
          Some(value) if skill_node(value, id) is Some(_) => ()
          _ =>
            return skill_failure(
              skill,
              completed,
              index,
              AgentSkillError::TargetNotFound(id),
              before,
              after,
              receipts,
            )
        }
      AgentSkillStep::AssertAction(id, kind) =>
        match snapshot {
          Some(value) =>
            match skill_node(value, id) {
              Some(node) if node.actions.contains(kind) => ()
              Some(_) =>
                return skill_failure(
                  skill,
                  completed,
                  index,
                  AgentSkillError::ActionUnavailable(id, kind),
                  before,
                  after,
                  receipts,
                )
              None =>
                return skill_failure(
                  skill,
                  completed,
                  index,
                  AgentSkillError::TargetNotFound(id),
                  before,
                  after,
                  receipts,
                )
            }
          None =>
            return skill_failure(
              skill,
              completed,
              index,
              AgentSkillError::TargetNotFound(id),
              before,
              after,
              receipts,
            )
        }
      AgentSkillStep::Perform(id, action) => {
        let target = match @core.SemanticId::parse(id) {
          Some(value) => @core.SemanticsTarget::BySemanticId(value)
          None =>
            return skill_failure(
              skill,
              completed,
              index,
              AgentSkillError::InvalidManifest("invalid semantic id"),
              before,
              after,
              receipts,
            )
        }
        let typed_action = match skill_action(action, call.inputs) {
          Ok(value) => value
          Err(error) =>
            return skill_failure(
              skill, completed, index, error, before, after, receipts,
            )
        }
        let request = {
          target,
          action: typed_action,
          // A Skill may pause at a confirmation boundary. The Inspector is
          // itself a MoUI view, so rendering the pending request can advance
          // the global semantics Generation before approval. Direct callers
          // can still require Exact(), while a bounded Skill revalidates the
          // target/action immediately and dispatches against the latest
          // committed tree after the human decision.
          precondition: AgentGenerationPrecondition::Latest,
        }
        match host.perform_action(request) {
          Ok(receipt) => {
            after = Some(receipt.after)
            receipts.push(receipt)
          }
          Err(error) =>
            return skill_failure(
              skill,
              completed,
              index,
              AgentSkillError::Action(error),
              before,
              after,
              receipts,
            )
        }
      }
      AgentSkillStep::AssertGenerationChanged =>
        match (before, after) {
          (Some(first), Some(last)) if first != last => ()
          _ =>
            return skill_failure(
              skill,
              completed,
              index,
              AgentSkillError::GenerationUnchanged,
              before,
              after,
              receipts,
            )
        }
      AgentSkillStep::RequireScope(scope) =>
        if !call.scopes.contains(scope) {
          return skill_failure(
            skill,
            completed,
            index,
            AgentSkillError::MissingScope(scope),
            before,
            after,
            receipts,
          )
        }
      AgentSkillStep::RequireConfirmation(request_id) =>
        if call.confirmation != Some(request_id) {
          return skill_failure(
            skill,
            completed,
            index,
            AgentSkillError::ConfirmationRequired(request_id),
            before,
            after,
            receipts,
          )
        }
    }
    completed = completed + 1
  }
  skill_result(
    skill.id,
    true,
    completed,
    None,
    None,
    before,
    after,
    receipts,
    ({ "completed_steps": completed, "result": output } : Json),
  )
}
