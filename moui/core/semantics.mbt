///|
pub(all) enum SemanticsRole {
  None
  Text
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
pub(all) enum SemanticsAction {
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
  element_id : ElementId
  role : SemanticsRole
  label : String
  value : String
  description : String
  state : SemanticsState
  actions : Array[SemanticsAction]
  focus_order : Int?
  frame : Rect
  children : Array[SemanticsNode]
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
