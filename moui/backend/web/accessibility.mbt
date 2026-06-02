///|
pub(all) struct AriaNode {
  role : String
  label : String
  value : String
  description : String
  checked : Bool?
  selected : Bool
  expanded : Bool
  invalid : Bool
  required : Bool
  focused : Bool
  disabled : Bool
  actions : Array[String]
  frame : @core.Rect
  children : Array[AriaNode]
} derive(Eq, Debug, ToJson)

///|
pub fn semantics_to_aria(node : @core.SemanticsNode) -> AriaNode {
  {
    role: aria_role(node.role),
    label: node.label,
    value: node.value,
    description: node.description,
    checked: aria_checked(node),
    selected: node.state.selected,
    expanded: node.state.expanded,
    invalid: node.state.invalid,
    required: node.state.required,
    focused: node.state.focused,
    disabled: node.state.disabled,
    actions: node.actions.map(action => aria_action(action)),
    frame: node.frame,
    children: node.children.map(child => semantics_to_aria(child)),
  }
}

///|
fn aria_role(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::None => "presentation"
    @core.SemanticsRole::Text => "text"
    @core.SemanticsRole::Button => "button"
    @core.SemanticsRole::Checkbox => "checkbox"
    @core.SemanticsRole::TextField => "textbox"
    @core.SemanticsRole::List => "list"
    @core.SemanticsRole::ListItem => "listitem"
    @core.SemanticsRole::Grid => "grid"
    @core.SemanticsRole::ScrollView => "region"
    @core.SemanticsRole::Switch => "switch"
    @core.SemanticsRole::Radio => "radio"
    @core.SemanticsRole::Slider => "slider"
    @core.SemanticsRole::Progress => "progressbar"
    @core.SemanticsRole::Tab => "tab"
    @core.SemanticsRole::Dialog => "dialog"
    @core.SemanticsRole::Tooltip => "tooltip"
    @core.SemanticsRole::Menu => "menu"
    @core.SemanticsRole::ButtonGroup => "group"
    @core.SemanticsRole::Form => "form"
    @core.SemanticsRole::FormField => "group"
    @core.SemanticsRole::Tree => "tree"
    @core.SemanticsRole::TreeItem => "treeitem"
    @core.SemanticsRole::Group => "group"
  }
}

///|
fn aria_checked(node : @core.SemanticsNode) -> Bool? {
  if node.role == @core.SemanticsRole::Checkbox ||
    node.role == @core.SemanticsRole::Switch ||
    node.role == @core.SemanticsRole::Radio {
    Some(node.state.checked)
  } else {
    None
  }
}

///|
fn aria_action(action : @core.SemanticsAction) -> String {
  match action {
    @core.SemanticsAction::Activate => "activate"
    @core.SemanticsAction::Focus => "focus"
    @core.SemanticsAction::SetText => "set-text"
    @core.SemanticsAction::Submit => "submit"
    @core.SemanticsAction::Scroll => "scroll"
    @core.SemanticsAction::Select => "select"
    @core.SemanticsAction::Expand => "expand"
    @core.SemanticsAction::Collapse => "collapse"
    @core.SemanticsAction::Dismiss => "dismiss"
  }
}
