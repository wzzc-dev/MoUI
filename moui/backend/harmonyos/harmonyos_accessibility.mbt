// HarmonyOS accessibility bridge (MoonBit side).
//
// ArkUI asks the template's native accessibility provider for element
// information (see `harmonyos_accessibility.cpp`). The provider needs plain C
// data, so this file projects the runtime semantics snapshot into flat arrays,
// and routes accessibility actions back into the runtime semantics action
// queue instead of synthesising input events.

///|
/// Flat projection of one semantics node. The field order and types must match
/// `MbwA11yNode` in `harmonyos_accessibility.cpp`.
priv struct AccessibilityNodeRecord {
  id : Int64
  parent : Int64
  role : Int32
  flags : Int32
  child_count : Int32
  action_count : Int32
  left : Double
  top : Double
  right : Double
  bottom : Double
  label : Bytes
  value : Bytes
  description : Bytes
}

///|
/// Role ids must stay in sync with `MbwA11yRole` in the native bridge.
fn accessibility_role_id(role : @core.SemanticsRole) -> Int32 {
  match role {
    Button => 1
    Text => 2
    TextField => 3
    Checkbox => 4
    Switch => 5
    Slider => 6
    List => 7
    ListItem => 8
    Image => 9
    Heading => 10
    Link => 11
    ScrollView => 12
    Group => 13
    _ => 0
  }
}

///|
/// Flag bits must stay in sync with `MbwA11yFlag` in the native bridge.
fn accessibility_flags(node : @core.SemanticsNode, focused : Bool) -> Int32 {
  let mut flags = if node.state.disabled { 0 } else { 8 }
  if focused || node.state.focused {
    flags = flags | 1
  }
  if node.state.selected {
    flags = flags | 2
  }
  match node.state.checked {
    Some(Checked) => flags = flags | 4
    _ => ()
  }
  if node.actions.contains(Activate) {
    flags = flags | 16
  }
  match node.role {
    TextField => flags = flags | 32
    _ => ()
  }
  if node.state.multiline {
    // Multiline text still maps to the TextInput component type; the flag only
    // widens what an accessibility client may assume about editing.
    flags = flags | 32
  }
  match node.role {
    ScrollView | List => flags = flags | 64
    _ => ()
  }
  flags
}

///|
fn accessibility_utf8(text : String) -> Bytes {
  // The native side reads these as NUL-terminated C strings.
  @utf8.encode(text + "\u{0}", bom=false)
}

///|
/// Action ids must stay in sync with ArkUI's `ArkUI_Accessibility_ActionType`.
fn accessibility_action_id(action : @core.SemanticsActionKind) -> Int32 {
  match action {
    Activate => 1 // ARKUI_ACCESSIBILITY_ACTION_CLICK
    Focus => 2 // ARKUI_ACCESSIBILITY_ACTION_FOCUS
    _ => 0
  }
}

///|
fn accessibility_empty_record() -> AccessibilityNodeRecord {
  {
    id: 0L,
    parent: 0L,
    role: 0,
    flags: 0,
    child_count: 0,
    action_count: 0,
    left: 0.0,
    top: 0.0,
    right: 0.0,
    bottom: 0.0,
    label: accessibility_utf8(""),
    value: accessibility_utf8(""),
    description: accessibility_utf8(""),
  }
}

///|
/// Owns the published projection so the arrays stay alive across the FFI call.
pub struct AccessibilityProjection {
  priv nodes : FixedArray[AccessibilityNodeRecord]
  priv child_ids : FixedArray[Int64]
  priv action_kinds : FixedArray[Int32]
  priv root_id : Int64
  priv focused_id : Int64
  priv generation : UInt64
}

///|
extern "C" fn harmonyos_accessibility_register_native() -> Int32 = "mbw_harmonyos_accessibility_register"

///|
extern "C" fn harmonyos_accessibility_publish_native(
  nodes_ptr : UInt64,
  node_count : Int32,
  child_ids_ptr : UInt64,
  child_count : Int32,
  action_kinds_ptr : UInt64,
  action_count : Int32,
  root_id : Int64,
  focused_id : Int64,
  generation : Int64,
) = "mbw_harmonyos_accessibility_publish"

///|

///|
/// Reads a little-endian i64 written by the native bridge.
fn read_i64_le(bytes : Bytes, offset : Int32) -> Int64 {
  let mut value = 0L
  for i in 0..<8 {
    value = value | (Int64::from_int(bytes[offset + i].to_int()) << (i * 8))
  }
  value
}

///|
/// Reads a little-endian i32 written by the native bridge.
fn read_i32_le(bytes : Bytes, offset : Int32) -> Int32 {
  let mut value = 0
  for i in 0..<4 {
    value = value | (bytes[offset + i].to_int() << (i * 8))
  }
  value
}

///|
extern "C" fn harmonyos_accessibility_status_native() -> Int32 = "mbw_harmonyos_accessibility_status"

///|
/// Registers the ArkUI accessibility provider. The NAPI module owns the
/// XComponent pointer and hands it to the native bridge first, so no handle is
/// threaded through MoonBit (the host channel only exposes the native window
/// handle, which is a different object).
pub fn harmonyos_accessibility_register() -> Bool {
  harmonyos_accessibility_register_native() != 0
}

///|
/// Projects a semantics read into flat C-compatible arrays. Only a `Full`
/// snapshot carries a tree; `Delta`/`Unchanged` publish an empty projection so
/// ArkUI falls back to the previous node ids it already cached.
pub fn harmonyos_accessibility_project(
  read : @runtime.SemanticsRead,
) -> AccessibilityProjection {
  match read {
    Full(snapshot) => {
      let nodes = snapshot.nodes()
      let focused = snapshot.focused()
      let mut total_children = 0
      let mut total_actions = 0
      for node in nodes {
        total_children = total_children + node.children.length()
        total_actions = total_actions + node.actions.length()
      }
      // Parent ids are derived from the child lists, because a snapshot exposes
      // the tree top-down only.
      let parents = child_parent_table(nodes)
      let records = FixedArray::make(
        nodes.length(),
        accessibility_empty_record(),
      )
      let child_ids = FixedArray::make(total_children, 0L)
      let action_kinds = FixedArray::make(total_actions, 0)
      let mut child_at = 0
      let mut action_at = 0
      for i, node in nodes {
        let is_focused = match focused {
          Some(id) => id == node.node_id
          None => false
        }
        let parent = match parents.get(node.node_id.value()) {
          Some(parent_value) => parent_value.reinterpret_as_int64()
          None => 0L
        }
        records[i] = {
          id: node.node_id.value().reinterpret_as_int64(),
          parent,
          role: accessibility_role_id(node.role),
          flags: accessibility_flags(node, is_focused),
          child_count: node.children.length(),
          action_count: node.actions.length(),
          left: node.frame.origin.x,
          top: node.frame.origin.y,
          right: node.frame.origin.x + node.frame.size.width,
          bottom: node.frame.origin.y + node.frame.size.height,
          label: accessibility_utf8(node.label),
          value: accessibility_utf8(node.value),
          description: accessibility_utf8(node.description),
        }
        for child in node.children {
          child_ids[child_at] = child.value().reinterpret_as_int64()
          child_at = child_at + 1
        }
        for action in node.actions {
          action_kinds[action_at] = accessibility_action_id(action)
          action_at = action_at + 1
        }
      }
      let root_id = match snapshot.root() {
        Some(id) => id.value().reinterpret_as_int64()
        None => 0L
      }
      let focused_id = match focused {
        Some(id) => id.value().reinterpret_as_int64()
        None => 0L
      }
      {
        nodes: records,
        child_ids,
        action_kinds,
        root_id,
        focused_id,
        generation: snapshot.generation().value(),
      }
    }
    _ =>
      {
        nodes: FixedArray::make(0, accessibility_empty_record()),
        child_ids: FixedArray::make(0, 0L),
        action_kinds: FixedArray::make(0, 0),
        root_id: 0L,
        focused_id: 0L,
        generation: 0UL,
      }
  }
}

///|
/// Builds a child -> parent lookup from the snapshot's child lists.
fn child_parent_table(
  nodes : Array[@core.SemanticsNode],
) -> Map[UInt64, UInt64] {
  let parents : Map[UInt64, UInt64] = Map([])
  for node in nodes {
    for child in node.children {
      parents.set(child.value(), node.node_id.value())
    }
  }
  parents
}

///|
/// Publishes the projection to the native provider. Returns the number of nodes
/// published so callers can log it.
pub fn harmonyos_accessibility_publish(
  projection : AccessibilityProjection,
) -> Int32 {
  harmonyos_accessibility_publish_native(
    harmonyos_record_address(projection.nodes),
    projection.nodes.length(),
    harmonyos_int64_address(projection.child_ids),
    projection.child_ids.length(),
    harmonyos_int32_address(projection.action_kinds),
    projection.action_kinds.length(),
    projection.root_id,
    projection.focused_id,
    projection.generation.reinterpret_as_int64(),
  )
  projection.nodes.length()
}

///|
/// Returns `registered * 1000000 + published node count`, used as startup
/// evidence in the device log.
pub fn harmonyos_accessibility_status() -> Int32 {
  harmonyos_accessibility_status_native()
}

// The `FixedArray` address accessors below are thin extern shims; MoonBit has
// no portable pointer arithmetic, so the address is taken on the C side from
// the array's first element pointer.

///|
#borrow(nodes)
extern "C" fn harmonyos_record_address(
  nodes : FixedArray[AccessibilityNodeRecord],
) -> UInt64 = "mbw_harmonyos_record_address"

///|
#borrow(array)
extern "C" fn harmonyos_int64_address(array : FixedArray[Int64]) -> UInt64 = "mbw_harmonyos_int64_address"

///|
#borrow(array)
extern "C" fn harmonyos_int32_address(array : FixedArray[Int32]) -> UInt64 = "mbw_harmonyos_int32_address"

///|
/// Routes an ArkUI accessibility action into the runtime semantics action queue.
/// `generation` is the semantics generation the accessibility client observed;
/// the runtime rejects the action when the tree moved on, which is the same
/// precondition macOS uses.
pub fn harmonyos_accessibility_handle_action(
  driver : @runtime.HostRuntimeDriver,
  element_id : Int64,
  action : Int32,
  generation : UInt64,
) -> Bool {
  let kind = match action {
    1 => Some(@core.SemanticsAction::Activate)
    2 => Some(@core.SemanticsAction::Focus)
    _ => None
  }
  match kind {
    None => false
    Some(action) => {
      let request : @runtime.PerformSemanticsActionRequest = {
        target: ByNodeId(
          @core.SemanticsNodeId::new(element_id.reinterpret_as_uint64()),
        ),
        action,
        precondition: Exact(@core.SemanticsGeneration::new(generation)),
      }
      match driver.perform_semantics_action(request) {
        Ok(_) => true
        Err(_) => false
      }
    }
  }
}

///|
#borrow(element_id_ptr, action_ptr, generation_ptr)
extern "C" fn harmonyos_accessibility_take_action_native(
  element_id_ptr : Bytes,
  action_ptr : Bytes,
  generation_ptr : Bytes,
) -> Int32 = "mbw_harmonyos_accessibility_take_action"

///|
/// A queued ArkUI accessibility action waiting for the host loop to dispatch it.
pub struct PendingAccessibilityAction {
  element_id : Int64
  action : Int32
  generation : UInt64
} derive(Eq, Debug)

///|
pub fn PendingAccessibilityAction::element_id(
  self : PendingAccessibilityAction,
) -> Int64 {
  self.element_id
}

///|
pub fn PendingAccessibilityAction::action(
  self : PendingAccessibilityAction,
) -> Int32 {
  self.action
}

///|
pub fn PendingAccessibilityAction::generation(
  self : PendingAccessibilityAction,
) -> UInt64 {
  self.generation
}

///|
pub extend PendingAccessibilityAction with Debug::{to_repr}

///|
pub extend PendingAccessibilityAction with Eq::{not_equal, equal}

///|
/// Drains one queued ArkUI accessibility action. ArkUI calls the native provider
/// on the UI thread, which cannot re-enter the runtime, so actions are queued in
/// the bridge and dispatched from the host loop.
pub fn harmonyos_accessibility_take_action() -> PendingAccessibilityAction? {
  let ids = Bytes::make(8, 0)
  let actions = Bytes::make(4, 0)
  let generations = Bytes::make(8, 0)
  if harmonyos_accessibility_take_action_native(ids, actions, generations) == 0 {
    return None
  }
  Some({
    element_id: read_i64_le(ids, 0),
    action: read_i32_le(actions, 0),
    generation: read_i64_le(generations, 0).reinterpret_as_uint64(),
  })
}

///|
#borrow(summary)
extern "C" fn harmonyos_log_image_status_native(summary : Bytes) = "mbw_harmonyos_log_image_status"

///|
/// Reports the image resource status summary to the device log. `println` does
/// not surface in hilog on HarmonyOS, so async image evidence goes through the
/// native logger.
pub fn harmonyos_log_image_status(summary : String) -> Unit {
  harmonyos_log_image_status_native(@utf8.encode(summary + "\u{0}", bom=false))
}

///|
#borrow(tag, text)
extern "C" fn harmonyos_log_text_native(tag : Bytes, text : Bytes) = "mbw_harmonyos_log_text"

///|
/// Logs a clipboard request to the device log so a shortcut's effect is visible
/// in `hilog` even when no pixel changes.
pub fn harmonyos_log_service_request(
  request : @host.HostServiceRequest,
) -> Unit {
  let text = match request {
    Clipboard(ReadText) => "clipboard read"
    Clipboard(WriteText(_)) => "clipboard write"
    Clipboard(_) => "clipboard other"
    _ => "service other"
  }
  harmonyos_log_text_native(
    @utf8.encode("service\u{0}", bom=false),
    @utf8.encode(text + "\u{0}", bom=false),
  )
}
