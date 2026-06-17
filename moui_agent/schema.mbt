///|
// MoUI agent protocol schema.
//
// Output types (what an agent READS from a host) all derive(ToJson), reusing
// MoUI's existing JSON ecosystem. Input types (what an agent SENDS) need manual
// FromJson decoders because the codebase derives only ToJson, not FromJson
// (verified: zero derive(FromJson) across the repo).
//
// Conventions follow examples/pdf_workbench/pdflite_service_protocol:
//   - `@json.parse(line) catch { _ => return None }`
//   - `guard x is Json::Object(fields) else { ... }`
//   - small `_json_*` helpers for field extraction.

///|
/// A flattened, JSON-friendly projection of the semantics tree that an agent
/// reads as the app's "DOM". Wraps the existing @core.SemanticsNode.
pub(all) struct SemanticsSnapshot {
  /// Root of the semantics tree (role/label/value/state/actions/frame/children).
  root : @core.SemanticsNode
  /// Total node count in the tree (precomputed for cheap agent filtering).
  node_count : Int
  /// Max depth of the tree.
  depth : Int
} derive(Eq, Debug, ToJson)

///|
/// A JSON projection of runtime state that an agent inspects. Mirrors a subset
/// of @runtime.ProgramRuntimeSnapshot that is useful for agent decision-making.
pub(all) struct RuntimeStateSnapshot {
  dispatched_count : Int
  update_count : Int
  pending_message_count : Int
  active_subscription_count : Int
  active_effect_task_count : Int
  dirty_element_ids : Array[String]
} derive(Eq, Debug, ToJson)

///|
/// Where an observed event originated. Agents distinguish self-triggered
/// actions from user input and system ticks.
pub(all) enum EventSource {
  User
  Agent
  System
} derive(Eq, Debug, ToJson)

///|
/// A projection of what the compositor currently renders to the screen — i.e.
/// what the user SEES. Captures the text strings drawn in the latest frame
/// (the rendered output of `AppRuntime::draw_commands()`). This is the
/// "screen" surface an agent's action becomes visible on.
pub(all) struct FrameSnapshot {
  /// Every text string painted in the current frame, in paint order.
  texts : Array[String]
  /// Total draw command count (rects, text, shadows, ...) for completeness.
  draw_command_count : Int
} derive(Eq, Debug, ToJson)

///|
/// One event in the stream an agent subscribes to. `sequence` is a monotonic
/// per-host counter so agents can detect gaps; `source` is best-effort.
pub(all) struct AgentEvent {
  sequence : Int
  source : EventSource
  /// The raw AppEvent (Pointer/Keyboard/TextInput/...), ToJson via @core.AppEvent.
  event : @core.AppEvent
} derive(Eq, Debug, ToJson)

///|
/// Result of an agent-initiated dispatch. `accepted=false` means the host
/// rejected the input (unknown intent / malformed event) without throwing.
pub(all) struct DispatchResult {
  accepted : Bool
  reason : String?
} derive(Eq, Debug, ToJson)

///|
/// Declares one operation a host accepts from an agent, with an informal JSON
/// schema describing the expected payload. Used by `get_capabilities`.
pub(all) struct AgentCapability {
  kind : String
  /// Human-readable description of the operation.
  description : String
  /// JSON schema fragment describing the expected input shape.
  schema : Json
} derive(Debug, ToJson)

// ---------------------------------------------------------------------------
// Input decoders (manual FromJson, since the repo does not derive FromJson).
// ---------------------------------------------------------------------------

///|
/// Decode a CommandIntent from JSON. Accepts either `{"intent": "Activate"}`
/// or a bare string "Activate". Returns None on unknown intent / bad shape.
pub fn command_intent_from_json(value : Json) -> @core.CommandIntent? {
  let kind = moui_agent_json_string(value)
  guard kind is Some(name) else { return None }
  match name {
    "Activate" => Some(@core.CommandIntent::Activate)
    "Submit" => Some(@core.CommandIntent::Submit)
    "Cancel" => Some(@core.CommandIntent::Cancel)
    "Copy" => Some(@core.CommandIntent::Copy)
    "Cut" => Some(@core.CommandIntent::Cut)
    "Paste" => Some(@core.CommandIntent::Paste)
    "Undo" => Some(@core.CommandIntent::Undo)
    "Redo" => Some(@core.CommandIntent::Redo)
    "SelectAll" => Some(@core.CommandIntent::SelectAll)
    "OpenContextMenu" => Some(@core.CommandIntent::OpenContextMenu)
    _ => None
  }
}

// ---------------------------------------------------------------------------
// Small JSON extraction helpers (idiom: pdf_workbench protocol package).
// `Json::Object(fields)` carries a `Map[String, Json]`.
// ---------------------------------------------------------------------------

///|
/// Extract a string from a Json value. Matches a bare Json::String.
fn moui_agent_json_string(value : Json) -> String? {
  match value {
    Json::String(s) => Some(s)
    _ => None
  }
}

///|
/// Extract a named string field from a JSON object's field map.
fn moui_agent_json_object_string(
  fields : Map[String, Json],
  key : String,
) -> String? {
  match fields.get(key) {
    Some(Json::String(v)) => Some(v)
    _ => None
  }
}

///|
/// Extract a named double field from a JSON object's field map.
fn moui_agent_json_object_double(
  fields : Map[String, Json],
  key : String,
) -> Double? {
  match fields.get(key) {
    Some(Json::Number(n, repr=_)) => Some(n)
    _ => None
  }
}

///|
/// Extract a named object field from a JSON object's field map.
fn moui_agent_json_object_object(
  fields : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match fields.get(key) {
    Some(Json::Object(o)) => Some(o)
    _ => None
  }
}

///|
/// Decode an AppEvent from JSON. MVP supports the Pointer variant (enough to
/// drive buttons — Down+Up inside a button fires its on_click). Unknown kinds
/// or malformed payloads return None; the caller reports a JSON-RPC error.
///
/// Pointer shape: { "kind": "Pointer", "position": { "x": <n>, "y": <n> },
///                  "phase": "Down"|"Up"|"Move"|"Cancel" }
pub fn app_event_from_json(value : Json) -> @core.AppEvent? {
  guard value is Json::Object(fields) else { return None }
  guard moui_agent_json_object_string(fields, "kind") is Some(kind) else {
    return None
  }
  match kind {
    "Pointer" => decode_pointer_event(fields)
    _ => None
  }
}

///|
fn decode_pointer_event(fields : Map[String, Json]) -> @core.AppEvent? {
  guard moui_agent_json_object_object(fields, "position") is Some(pos) else {
    return None
  }
  guard moui_agent_json_object_double(pos, "x") is Some(x) else { return None }
  guard moui_agent_json_object_double(pos, "y") is Some(y) else { return None }
  guard moui_agent_json_object_string(fields, "phase") is Some(phase) else {
    return None
  }
  let resolved_phase = match phase {
    "Down" => @core.PointerPhase::Down
    "Up" => @core.PointerPhase::Up
    "Move" => @core.PointerPhase::Move
    "Cancel" => @core.PointerPhase::Cancel
    _ => return None
  }
  Some(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x~, y~),
        phase=resolved_phase,
      ),
    ),
  )
}
