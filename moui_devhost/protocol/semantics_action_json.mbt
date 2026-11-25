///|
fn semantics_scroll_direction_name(
  direction : @core.SemanticsScrollDirection,
) -> String {
  match direction {
    @core.SemanticsScrollDirection::Forward => "Forward"
    @core.SemanticsScrollDirection::Backward => "Backward"
    @core.SemanticsScrollDirection::Up => "Up"
    @core.SemanticsScrollDirection::Down => "Down"
    @core.SemanticsScrollDirection::Left => "Left"
    @core.SemanticsScrollDirection::Right => "Right"
  }
}

///|
fn semantics_scroll_direction_from_name(
  name : String,
) -> @core.SemanticsScrollDirection? {
  match name {
    "Forward" => Some(@core.SemanticsScrollDirection::Forward)
    "Backward" => Some(@core.SemanticsScrollDirection::Backward)
    "Up" => Some(@core.SemanticsScrollDirection::Up)
    "Down" => Some(@core.SemanticsScrollDirection::Down)
    "Left" => Some(@core.SemanticsScrollDirection::Left)
    "Right" => Some(@core.SemanticsScrollDirection::Right)
    _ => None
  }
}

///|
fn semantics_target_json(target : @core.SemanticsTarget) -> Json {
  let fields : Map[String, Json] = Map([])
  match target {
    @core.SemanticsTarget::BySemanticId(id) => {
      fields["kind"] = string_json("semantic_id")
      fields["value"] = string_json(id.value())
    }
    @core.SemanticsTarget::ByNodeId(id) => {
      fields["kind"] = string_json("node_id")
      fields["value"] = string_json(id.to_wire())
    }
    @core.SemanticsTarget::ByPath(steps) => {
      fields["kind"] = string_json("path")
      fields["steps"] = Json::array(
        steps.map(step => semantics_path_step_json(step)),
      )
    }
  }
  Json::object(fields)
}

///|
fn semantics_path_step_json(step : @core.SemanticsPathSegment) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["index"] = int_json(step.index)
  fields["role"] = match step.role {
    Some(role) => string_json(semantics_role_name(role))
    None => Json::null()
  }
  fields["label"] = optional_string_json(step.label)
  fields["value"] = optional_string_json(step.value)
  fields["semantic_id"] = match step.semantic_id {
    Some(id) => string_json(id.value())
    None => Json::null()
  }
  Json::object(fields)
}

///|
fn semantics_path_step_from_json(value : Json) -> @core.SemanticsPathSegment? {
  let fields = match wire_object(Some(value)) {
    Some(fields) => fields
    None => return None
  }
  let index = match int_from_json(fields.get("index")) {
    Some(value) => value
    None => return None
  }
  let role = match fields.get("role") {
    Some(Json::Null) | None => None
    Some(value) =>
      match wire_string(Some(value)) {
        Some(name) =>
          match semantics_role_from_name(name) {
            Some(role) => Some(role)
            None => return None
          }
        None => return None
      }
  }
  let label = match optional_string_from_json(fields.get("label")) {
    Some(value) => value
    None => return None
  }
  let value_text = match optional_string_from_json(fields.get("value")) {
    Some(value) => value
    None => return None
  }
  let semantic_id = match fields.get("semantic_id") {
    Some(Json::Null) | None => None
    Some(value) =>
      match wire_string(Some(value)) {
        Some(text) =>
          match @core.SemanticId::parse(text) {
            Some(id) => Some(id)
            None => return None
          }
        None => return None
      }
  }
  // A step with no filter addresses a position, not a node; the runtime
  // rejects it, so do not put it on the wire.
  if role is None && label is None && value_text is None && semantic_id is None {
    return None
  }
  Some(@core.SemanticsPathSegment::{
    index,
    role,
    label,
    value: value_text,
    semantic_id,
  })
}

///|
fn semantics_target_from_json(value : Json?) -> @core.SemanticsTarget? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "semantic_id" => {
      let text = match wire_string(fields.get("value")) {
        Some(text) => text
        None => return None
      }
      match @core.SemanticId::parse(text) {
        Some(id) => Some(@core.SemanticsTarget::BySemanticId(id))
        None => None
      }
    }
    "node_id" => {
      let text = match wire_string(fields.get("value")) {
        Some(text) => text
        None => return None
      }
      match decimal_u64(text) {
        Some(id) =>
          Some(@core.SemanticsTarget::ByNodeId(@core.SemanticsNodeId::new(id)))
        None => None
      }
    }
    "path" => {
      let items = match wire_array(fields.get("steps")) {
        Some(items) => items
        None => return None
      }
      let steps : Array[@core.SemanticsPathSegment] = []
      for item in items {
        match semantics_path_step_from_json(item) {
          Some(step) => steps.push(step)
          None => return None
        }
      }
      Some(@core.SemanticsTarget::ByPath(steps))
    }
    _ => None
  }
}

///|
fn semantics_action_json(action : @core.SemanticsAction) -> Json {
  let fields : Map[String, Json] = Map([])
  match action {
    @core.SemanticsAction::Activate => fields["kind"] = string_json("Activate")
    @core.SemanticsAction::Focus => fields["kind"] = string_json("Focus")
    @core.SemanticsAction::SetText(text) => {
      fields["kind"] = string_json("SetText")
      fields["text"] = string_json(text)
    }
    @core.SemanticsAction::Submit => fields["kind"] = string_json("Submit")
    @core.SemanticsAction::Scroll(direction) => {
      fields["kind"] = string_json("Scroll")
      fields["direction"] = string_json(
        semantics_scroll_direction_name(direction),
      )
    }
    @core.SemanticsAction::Select => fields["kind"] = string_json("Select")
    @core.SemanticsAction::Expand => fields["kind"] = string_json("Expand")
    @core.SemanticsAction::Collapse => fields["kind"] = string_json("Collapse")
    @core.SemanticsAction::Dismiss => fields["kind"] = string_json("Dismiss")
    @core.SemanticsAction::Increment =>
      fields["kind"] = string_json("Increment")
    @core.SemanticsAction::Decrement =>
      fields["kind"] = string_json("Decrement")
    @core.SemanticsAction::SetNumericValue(value) => {
      fields["kind"] = string_json("SetNumericValue")
      fields["value"] = number_json(value)
    }
    @core.SemanticsAction::SetSelection(range) => {
      fields["kind"] = string_json("SetSelection")
      fields["range"] = text_range_json(range)
    }
    @core.SemanticsAction::ShowMenu => fields["kind"] = string_json("ShowMenu")
  }
  Json::object(fields)
}

///|
fn semantics_action_from_json(value : Json?) -> @core.SemanticsAction? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "Activate" => Some(@core.SemanticsAction::Activate)
    "Focus" => Some(@core.SemanticsAction::Focus)
    "SetText" => {
      let text = match wire_string(fields.get("text")) {
        Some(text) => text
        None => return None
      }
      Some(@core.SemanticsAction::SetText(text))
    }
    "Submit" => Some(@core.SemanticsAction::Submit)
    "Scroll" => {
      let name = match wire_string(fields.get("direction")) {
        Some(name) => name
        None => return None
      }
      match semantics_scroll_direction_from_name(name) {
        Some(direction) => Some(@core.SemanticsAction::Scroll(direction))
        None => None
      }
    }
    "Select" => Some(@core.SemanticsAction::Select)
    "Expand" => Some(@core.SemanticsAction::Expand)
    "Collapse" => Some(@core.SemanticsAction::Collapse)
    "Dismiss" => Some(@core.SemanticsAction::Dismiss)
    "Increment" => Some(@core.SemanticsAction::Increment)
    "Decrement" => Some(@core.SemanticsAction::Decrement)
    "SetNumericValue" => {
      let value = match wire_number(fields.get("value")) {
        Some(value) => value
        None => return None
      }
      Some(@core.SemanticsAction::SetNumericValue(value))
    }
    "SetSelection" => {
      let range = match text_range_from_json(fields.get("range")) {
        Some(range) => range
        None => return None
      }
      Some(@core.SemanticsAction::SetSelection(range))
    }
    "ShowMenu" => Some(@core.SemanticsAction::ShowMenu)
    _ => None
  }
}

///|
fn semantics_generation_precondition_json(
  precondition : @runtime.SemanticsGenerationPrecondition,
) -> Json {
  let fields : Map[String, Json] = Map([])
  match precondition {
    @runtime.SemanticsGenerationPrecondition::Exact(generation) => {
      fields["kind"] = string_json("Exact")
      fields["generation"] = string_json(generation.to_wire())
    }
    @runtime.SemanticsGenerationPrecondition::Latest =>
      fields["kind"] = string_json("Latest")
  }
  Json::object(fields)
}

///|
fn semantics_generation_precondition_from_json(
  value : Json?,
) -> @runtime.SemanticsGenerationPrecondition? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "Exact" => {
      let text = match wire_string(fields.get("generation")) {
        Some(text) => text
        None => return None
      }
      match decimal_u64(text) {
        Some(id) =>
          Some(
            @runtime.SemanticsGenerationPrecondition::Exact(
              @core.SemanticsGeneration::new(id),
            ),
          )
        None => None
      }
    }
    "Latest" => Some(@runtime.SemanticsGenerationPrecondition::Latest)
    _ => None
  }
}

///|
pub fn encode_semantics_action_request(
  request : @runtime.PerformSemanticsActionRequest,
) -> String {
  let fields : Map[String, Json] = Map([])
  fields["target"] = semantics_target_json(request.target)
  fields["action"] = semantics_action_json(request.action)
  fields["precondition"] = semantics_generation_precondition_json(
    request.precondition,
  )
  Json::object(fields).stringify()
}

///|
pub fn decode_semantics_action_request(
  text : String,
) -> @runtime.PerformSemanticsActionRequest? {
  let parsed = @json.parse(text) catch { _ => return None }
  let fields = match wire_object(Some(parsed)) {
    Some(fields) => fields
    None => return None
  }
  let target = match semantics_target_from_json(fields.get("target")) {
    Some(target) => target
    None => return None
  }
  let action = match semantics_action_from_json(fields.get("action")) {
    Some(action) => action
    None => return None
  }
  let precondition = match
    semantics_generation_precondition_from_json(fields.get("precondition")) {
    Some(precondition) => precondition
    None => return None
  }
  Some({ target, action, precondition, })
}

///|
fn semantics_action_receipt_json(
  receipt : @runtime.SemanticsActionReceipt,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["before"] = string_json(receipt.before.to_wire())
  fields["after"] = string_json(receipt.after.to_wire())
  fields["pending_work"] = bool_json(receipt.pending_work)
  Json::object(fields)
}

///|
fn semantics_action_receipt_from_json(
  value : Json?,
) -> @runtime.SemanticsActionReceipt? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let before = match semantics_generation_from_json(fields.get("before")) {
    Some(generation) => generation
    None => return None
  }
  let after = match semantics_generation_from_json(fields.get("after")) {
    Some(generation) => generation
    None => return None
  }
  let pending_work = match wire_bool(fields.get("pending_work")) {
    Some(value) => value
    None => return None
  }
  Some({ before, after, pending_work, })
}

///|
fn semantics_action_error_name(
  error : @runtime.SemanticsActionDispatchError,
) -> String {
  match error {
    @runtime.SemanticsActionDispatchError::RuntimeClosed => "RuntimeClosed"
    @runtime.SemanticsActionDispatchError::StaleGeneration(_, _) =>
      "StaleGeneration"
    @runtime.SemanticsActionDispatchError::TargetNotFound(_) => "TargetNotFound"
    @runtime.SemanticsActionDispatchError::TargetAmbiguous(_) =>
      "TargetAmbiguous"
    @runtime.SemanticsActionDispatchError::TargetDisabled(_) => "TargetDisabled"
    @runtime.SemanticsActionDispatchError::ActionUnavailable(_, _) =>
      "ActionUnavailable"
    @runtime.SemanticsActionDispatchError::HandlerRejected(_, _) =>
      "HandlerRejected"
    @runtime.SemanticsActionDispatchError::ReentrantDispatch =>
      "ReentrantDispatch"
  }
}

///|
fn semantics_action_error_json(
  error : @runtime.SemanticsActionDispatchError,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["kind"] = string_json(semantics_action_error_name(error))
  match error {
    @runtime.SemanticsActionDispatchError::RuntimeClosed => ()
    @runtime.SemanticsActionDispatchError::StaleGeneration(expected, actual) => {
      fields["expected"] = string_json(expected.to_wire())
      fields["actual"] = string_json(actual.to_wire())
    }
    @runtime.SemanticsActionDispatchError::TargetNotFound(target) =>
      fields["target"] = semantics_target_json(target)
    @runtime.SemanticsActionDispatchError::TargetAmbiguous(id) =>
      fields["semantic_id"] = string_json(id.value())
    @runtime.SemanticsActionDispatchError::TargetDisabled(target) =>
      fields["target"] = semantics_target_json(target)
    @runtime.SemanticsActionDispatchError::ActionUnavailable(target, kind) => {
      fields["target"] = semantics_target_json(target)
      fields["action"] = string_json(semantics_action_kind_name(kind))
    }
    @runtime.SemanticsActionDispatchError::HandlerRejected(target, kind) => {
      fields["target"] = semantics_target_json(target)
      fields["action"] = string_json(semantics_action_kind_name(kind))
    }
    @runtime.SemanticsActionDispatchError::ReentrantDispatch => ()
  }
  Json::object(fields)
}

///|
fn semantics_action_error_from_json(
  value : Json?,
) -> @runtime.SemanticsActionDispatchError? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "RuntimeClosed" =>
      Some(@runtime.SemanticsActionDispatchError::RuntimeClosed)
    "StaleGeneration" => {
      let expected = match
        semantics_generation_from_json(fields.get("expected")) {
        Some(generation) => generation
        None => return None
      }
      let actual = match semantics_generation_from_json(fields.get("actual")) {
        Some(generation) => generation
        None => return None
      }
      Some(
        @runtime.SemanticsActionDispatchError::StaleGeneration(expected, actual),
      )
    }
    "TargetNotFound" => {
      let target = match semantics_target_from_json(fields.get("target")) {
        Some(target) => target
        None => return None
      }
      Some(@runtime.SemanticsActionDispatchError::TargetNotFound(target))
    }
    "TargetAmbiguous" => {
      let text = match wire_string(fields.get("semantic_id")) {
        Some(text) => text
        None => return None
      }
      match @core.SemanticId::parse(text) {
        Some(id) =>
          Some(@runtime.SemanticsActionDispatchError::TargetAmbiguous(id))
        None => None
      }
    }
    "TargetDisabled" => {
      let target = match semantics_target_from_json(fields.get("target")) {
        Some(target) => target
        None => return None
      }
      Some(@runtime.SemanticsActionDispatchError::TargetDisabled(target))
    }
    "ActionUnavailable" => {
      let target = match semantics_target_from_json(fields.get("target")) {
        Some(target) => target
        None => return None
      }
      let action = match semantics_action_kind_from_json(fields.get("action")) {
        Some(action) => action
        None => return None
      }
      Some(
        @runtime.SemanticsActionDispatchError::ActionUnavailable(target, action),
      )
    }
    "HandlerRejected" => {
      let target = match semantics_target_from_json(fields.get("target")) {
        Some(target) => target
        None => return None
      }
      let action = match semantics_action_kind_from_json(fields.get("action")) {
        Some(action) => action
        None => return None
      }
      Some(
        @runtime.SemanticsActionDispatchError::HandlerRejected(target, action),
      )
    }
    "ReentrantDispatch" =>
      Some(@runtime.SemanticsActionDispatchError::ReentrantDispatch)
    _ => None
  }
}

///|
fn semantics_action_kind_from_json(value : Json?) -> @core.SemanticsActionKind? {
  let name = match wire_string(value) {
    Some(name) => name
    None => return None
  }
  semantics_action_kind_from_name(name)
}

///|
/// One JSON envelope for the optional `dev_semantics_action` ABI entry:
/// `{"ok":true,"receipt":{...}}` or `{"ok":false,"error":{...}}`.
pub fn encode_semantics_action_result(
  result : Result[
    @runtime.SemanticsActionReceipt,
    @runtime.SemanticsActionDispatchError,
  ],
) -> String {
  let fields : Map[String, Json] = Map([])
  match result {
    Ok(receipt) => {
      fields["ok"] = bool_json(true)
      fields["receipt"] = semantics_action_receipt_json(receipt)
    }
    Err(error) => {
      fields["ok"] = bool_json(false)
      fields["error"] = semantics_action_error_json(error)
    }
  }
  Json::object(fields).stringify()
}

///|
pub fn decode_semantics_action_result(
  text : String,
) -> Result[
  @runtime.SemanticsActionReceipt,
  @runtime.SemanticsActionDispatchError,
]? {
  let parsed = @json.parse(text) catch { _ => return None }
  let fields = match wire_object(Some(parsed)) {
    Some(fields) => fields
    None => return None
  }
  let ok = match wire_bool(fields.get("ok")) {
    Some(ok) => ok
    None => return None
  }
  if ok {
    match semantics_action_receipt_from_json(fields.get("receipt")) {
      Some(receipt) => Some(Ok(receipt))
      None => None
    }
  } else {
    match semantics_action_error_from_json(fields.get("error")) {
      Some(error) => Some(Err(error))
      None => None
    }
  }
}
