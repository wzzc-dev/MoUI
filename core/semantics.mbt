///|
pub(all) enum SemanticsRole {
  None
  Text
  Button
  TextField
  List
  ListItem
  Grid
  ScrollView
  Group
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SemanticsAction {
  Activate
  Focus
  SetText
  Submit
  Scroll
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SemanticsState {
  focused : Bool
  disabled : Bool
  selected : Bool
  expanded : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SemanticsNode {
  element_id : ElementId
  role : SemanticsRole
  label : String
  value : String
  state : SemanticsState
  actions : Array[SemanticsAction]
  focus_order : Int?
  frame : Rect
  children : Array[SemanticsNode]
} derive(Eq, Debug, ToJson)

///|
pub fn SemanticsState::default() -> SemanticsState {
  { focused: false, disabled: false, selected: false, expanded: false }
}

///|
pub fn ElementNode::semantics(
  self : ElementNode,
  render : RenderNode,
  focused~ : ElementId? = None,
) -> SemanticsNode {
  let next_order = Ref(0)
  self.build_semantics(render, focused, next_order, list_item=false)
}

///|
fn ElementNode::build_semantics(
  self : ElementNode,
  render : RenderNode,
  focused : ElementId?,
  next_order : Ref[Int],
  list_item~ : Bool,
) -> SemanticsNode {
  let info = self.semantics_info(list_item~)
  let focusable = info.actions.any(action => action == SemanticsAction::Focus)
  let focus_order = if focusable {
    let order = next_order.val
    next_order.val = next_order.val + 1
    Some(order)
  } else {
    None
  }
  let state = {
    focused: focused == Some(self.id),
    disabled: false,
    selected: false,
    expanded: false,
  }
  let children : Array[SemanticsNode] = []
  let child_is_list_item = self.spec is ListSpec(_)
  for index, child in self.children {
    if index < render.children.length() {
      children.push(
        child.build_semantics(
          render.children[index],
          focused,
          next_order,
          list_item=child_is_list_item,
        ),
      )
    }
  }
  {
    element_id: self.id,
    role: info.role,
    label: info.label,
    value: info.value,
    state,
    actions: info.actions,
    focus_order,
    frame: render.frame,
    children,
  }
}

///|
priv struct SemanticsInfo {
  role : SemanticsRole
  label : String
  value : String
  actions : Array[SemanticsAction]
}

///|
fn ElementNode::semantics_info(
  self : ElementNode,
  list_item~ : Bool,
) -> SemanticsInfo {
  match self.spec {
    TextSpec(data) =>
      {
        role: if list_item { ListItem } else { Text },
        label: data.text,
        value: data.text,
        actions: [],
      }
    ButtonSpec(data) =>
      {
        role: Button,
        label: data.text,
        value: "",
        actions: [Focus, Activate],
      }
    TextFieldSpec(data) =>
      {
        role: TextField,
        label: data.placeholder,
        value: data.value.get(),
        actions: [Focus, SetText, Submit],
      }
    ListSpec(_) =>
      { role: List, label: "", value: "", actions: [] }
    GridSpec(_) =>
      { role: Grid, label: "", value: "", actions: [] }
    ScrollSpec(_) =>
      { role: ScrollView, label: "", value: "", actions: [Scroll] }
    EmptySpec | SpacerSpec(_) =>
      { role: None, label: "", value: "", actions: [] }
    FlexSpec(_) | PaddingSpec(_) | ContainerSpec(_) | FrameSpec(_) | StackSpec(_) =>
      { role: Group, label: "", value: "", actions: [] }
  }
}
