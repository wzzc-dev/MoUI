///|
pub(all) enum SemanticsRole {
  None
  Text
  Link
  Heading
  Navigation
  Main
  Button
  Checkbox
  TextField
  List
  ListItem
  Grid
  ScrollView
  Switch
  Radio
  Slider
  Progress
  Tab
  Dialog
  Tooltip
  Menu
  ButtonGroup
  Form
  FormField
  Tree
  TreeItem
  Group
  WebView
} derive(Eq, Debug, ToJson)

///|
/// A stable application-owned identifier for one effective semantic boundary.
///
/// Values are exact and case-sensitive. Parsing rejects empty values, values
/// longer than 255 UTF-8 bytes, and values containing Unicode whitespace or
/// control characters.
pub struct SemanticId {
  priv value : String
} derive(Eq, Compare, Hash, Debug)

///|
fn semantic_id_code_unit_is_forbidden(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value <= 0x1F ||
  (value >= 0x7F && value <= 0x9F) ||
  value == 0x20 ||
  value == 0xA0 ||
  value == 0x1680 ||
  (value >= 0x2000 && value <= 0x200A) ||
  value == 0x2028 ||
  value == 0x2029 ||
  value == 0x202F ||
  value == 0x205F ||
  value == 0x3000
}

///|
/// Parses and validates a stable semantic identifier.
pub fn SemanticId::parse(value : String) -> SemanticId? {
  let byte_length = @utf8.encode(value[:], bom=false).length()
  if byte_length == 0 || byte_length > 255 {
    return None
  }
  for code_unit in value.code_units() {
    if semantic_id_code_unit_is_forbidden(code_unit) {
      return None
    }
  }
  Some({ value, })
}

///|
/// Returns the exact, non-normalized identifier value.
pub fn SemanticId::value(self : SemanticId) -> String {
  self.value
}

///|
pub impl ToJson for SemanticId with fn to_json(self : SemanticId) -> Json {
  self.value.to_json()
}

///|
/// Runtime-session-local identity for one committed semantics node.
pub struct SemanticsNodeId {
  priv value : UInt64
} derive(Eq, Compare, Hash, Debug)

///|
pub fn SemanticsNodeId::new(value : UInt64) -> SemanticsNodeId {
  { value, }
}

///|
pub fn SemanticsNodeId::value(self : SemanticsNodeId) -> UInt64 {
  self.value
}

///|
/// Returns the lossless decimal wire representation.
pub fn SemanticsNodeId::to_wire(self : SemanticsNodeId) -> String {
  self.value.to_string(radix=10)
}

///|
pub impl ToJson for SemanticsNodeId with fn to_json(self : SemanticsNodeId) -> Json {
  self.to_wire().to_json()
}

///|
/// Version of one runtime's atomically committed public semantics snapshot.
pub struct SemanticsGeneration {
  priv value : UInt64
} derive(Eq, Compare, Hash, Debug)

///|
pub fn SemanticsGeneration::new(value : UInt64) -> SemanticsGeneration {
  { value, }
}

///|
pub fn SemanticsGeneration::value(self : SemanticsGeneration) -> UInt64 {
  self.value
}

///|
/// Returns the lossless decimal wire representation.
pub fn SemanticsGeneration::to_wire(self : SemanticsGeneration) -> String {
  self.value.to_string(radix=10)
}

///|
pub impl ToJson for SemanticsGeneration with fn to_json(
  self : SemanticsGeneration,
) -> Json {
  self.to_wire().to_json()
}

///|
/// A payload-free semantic capability advertised by a committed node.
pub(all) enum SemanticsActionKind {
  Activate
  Focus
  SetText
  Submit
  Scroll
  Select
  Expand
  Collapse
  Dismiss
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SemanticsScrollDirection {
  Forward
  Backward
  Up
  Down
  Left
  Right
} derive(Eq, Debug, ToJson)

///|
/// A typed semantic invocation. Payload requirements are encoded by the
/// constructor rather than represented by an optional side channel.
pub(all) enum SemanticsAction {
  Activate
  Focus
  SetText(String)
  Submit
  Scroll(SemanticsScrollDirection)
  Select
  Expand
  Collapse
  Dismiss
} derive(Eq, Debug, ToJson)

///|
pub fn SemanticsAction::kind(self : SemanticsAction) -> SemanticsActionKind {
  match self {
    Activate => SemanticsActionKind::Activate
    Focus => SemanticsActionKind::Focus
    SetText(_) => SemanticsActionKind::SetText
    Submit => SemanticsActionKind::Submit
    Scroll(_) => SemanticsActionKind::Scroll
    Select => SemanticsActionKind::Select
    Expand => SemanticsActionKind::Expand
    Collapse => SemanticsActionKind::Collapse
    Dismiss => SemanticsActionKind::Dismiss
  }
}

///|
/// Controls how one view declaration contributes to the effective semantics
/// tree.
pub(all) enum SemanticsComposition {
  Transparent
  Boundary
  MergeDescendants
  Hidden
} derive(Eq, Debug, ToJson)

///|
/// Selects either an application-owned stable ID or a session-local committed
/// node ID.
pub(all) enum SemanticsTarget {
  BySemanticId(SemanticId)
  ByNodeId(SemanticsNodeId)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SemanticsState {
  focused : Bool
  disabled : Bool
  selected : Bool
  pressed : Bool
  checked : Bool
  expanded : Bool
  invalid : Bool
  required : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SemanticsNode {
  node_id : SemanticsNodeId
  semantic_id : SemanticId?
  role : SemanticsRole
  level : Int?
  url : String
  label : String
  value : String
  description : String
  state : SemanticsState
  actions : Array[SemanticsActionKind]
  focus_order : Int?
  frame : Rect
  children : Array[SemanticsNodeId]
} derive(Eq, Debug, ToJson)

///|
pub fn SemanticsState::default() -> SemanticsState {
  {
    focused: false,
    disabled: false,
    selected: false,
    pressed: false,
    checked: false,
    expanded: false,
    invalid: false,
    required: false,
  }
}

///|
pub(all) enum ScrollAlignment {
  Start
  Center
  End
  Nearest
} derive(Eq, Debug, ToJson)
