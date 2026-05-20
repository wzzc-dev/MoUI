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
  checked : Bool
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
  {
    focused: false,
    disabled: false,
    selected: false,
    checked: false,
    expanded: false,
  }
}

///|
pub fn ElementNode::semantics(
  self : ElementNode,
  render : RenderNode,
  focused? : ElementId? = None,
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
    disabled: self.is_semantics_disabled(),
    selected: false,
    checked: self.is_semantics_checked(),
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
        role: if list_item {
          ListItem
        } else {
          Text
        },
        label: data.text,
        value: data.text,
        actions: [],
      }
    ButtonSpec(data) =>
      { role: Button, label: data.text, value: "", actions: [Focus, Activate] }
    CheckboxSpec(data) =>
      {
        role: Checkbox,
        label: data.label,
        value: if data.checked.get() {
          "true"
        } else {
          "false"
        },
        actions: [Focus, Activate],
      }
    PickerSpec(data) =>
      {
        role: Menu,
        label: data.placeholder,
        value: data.selected.get(),
        actions: [Focus, Activate],
      }
    DatePickerSpec(data) =>
      {
        role: Menu,
        label: data.placeholder,
        value: data.selected.get().format(data.mode),
        actions: [Focus, Activate],
      }
    SearchBarSpec(data) =>
      {
        role: TextField,
        label: data.placeholder,
        value: data.query.get(),
        actions: [Focus, SetText, Submit],
      }
    SheetSpec(_data) =>
      {
        role: Dialog,
        label: "",
        value: "",
        actions: [],
      }
    TextFieldSpec(data) =>
      {
        role: TextField,
        label: data.placeholder,
        value: data.value.get(),
        actions: [Focus, SetText, Submit],
      }
    RichTextEditorSpec(data) =>
      {
        role: TextField,
        label: data.placeholder,
        value: data.value.get(),
        actions: [Focus, SetText],
      }
    ListSpec(_) => { role: List, label: "", value: "", actions: [] }
    GridSpec(_) => { role: Grid, label: "", value: "", actions: [] }
    ScrollSpec(_) =>
      { role: ScrollView, label: "", value: "", actions: [Scroll] }
    ImageSpec(data) =>
      { role: None, label: data.source, value: "", actions: [] }
    CustomSpec(data) =>
      {
        role: data.semantics_role,
        label: data.semantics_label,
        value: data.semantics_label,
        actions: [],
      }
    CustomLayoutSpec(data) =>
      {
        role: data.semantics_role,
        label: data.semantics_label,
        value: data.semantics_label,
        actions: [],
      }
    EmptySpec | SpacerSpec(_) =>
      { role: None, label: "", value: "", actions: [] }
    FlexSpec(_)
    | PaddingSpec(_)
    | ContainerSpec(_)
    | FrameSpec(_)
    | StackSpec(_)
    | ComponentSpec(_) => { role: Group, label: "", value: "", actions: [] }
    ModifiedSpec(data) => modified_semantics_info(data.modifier)
  }
}

///|
fn modified_semantics_info(modifier : ViewModifier) -> SemanticsInfo {
  match modifier {
    AccessibilityLabelModifier(label) =>
      { role: Group, label, value: label, actions: [] }
    SemanticsRoleModifier(role) => { role, label: "", value: "", actions: [] }
    FocusableModifier(focusable) =>
      {
        role: Group,
        label: "",
        value: "",
        actions: if focusable {
          [Focus]
        } else {
          []
        },
      }
    OnTapModifier(_) | KeyboardShortcutModifier(_) =>
      { role: Button, label: "", value: "", actions: [Focus, Activate] }
    DisabledModifier(_)
    | PaddingModifier(_)
    | FrameModifier(_)
    | BackgroundModifier(_)
    | ForegroundModifier(_)
    | FontModifier(_)
    | CornerRadiusModifier(_)
    | OpacityModifier(_)
    | ShadowModifier(_)
    | BorderModifier(_)
    | OffsetModifier(_, _)
    | ClipModifier
    | ScaleModifier(_, _)
    | FlexibleModifier(_)
    | LayoutPriorityModifier(_)
    | AlignModifier(_)
    | AspectRatioModifier(_)
    | IntrinsicWidthModifier
    | IntrinsicHeightModifier =>
      { role: Group, label: "", value: "", actions: [] }
  }
}

///|
fn ElementNode::is_semantics_checked(self : ElementNode) -> Bool {
  match self.spec {
    CheckboxSpec(data) => data.checked.get()
    ModifiedSpec(_) =>
      if self.children.length() > 0 {
        self.children[0].is_semantics_checked()
      } else {
        false
      }
    _ => false
  }
}

///|
fn ElementNode::is_semantics_disabled(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) => data.modifier is DisabledModifier(true)
    _ => false
  }
}
