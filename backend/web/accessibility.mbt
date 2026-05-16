///|
pub(all) struct AriaNode {
  role : String
  label : String
  value : String
  checked : Bool?
  focused : Bool
  frame : @core.Rect
  children : Array[AriaNode]
} derive(Eq, Debug, ToJson)

///|
pub fn semantics_to_aria(node : @core.SemanticsNode) -> AriaNode {
  {
    role: aria_role(node.role),
    label: node.label,
    value: node.value,
    checked: aria_checked(node),
    focused: node.state.focused,
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
    @core.SemanticsRole::Group => "group"
  }
}

///|
fn aria_checked(node : @core.SemanticsNode) -> Bool? {
  if node.role == @core.SemanticsRole::Checkbox {
    Some(node.state.checked)
  } else {
    None
  }
}
