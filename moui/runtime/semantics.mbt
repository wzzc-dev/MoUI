///|
fn ElementNode::semantics(
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
  let actions = self.semantics_actions(info.actions)
  let focusable = actions.any(action => action == SemanticsAction::Focus)
  let focus_order = if focusable {
    let order = next_order.val
    next_order.val = next_order.val + 1
    Some(order)
  } else {
    None
  }
  let state : SemanticsState = {
    focused: focused == Some(self.id),
    disabled: self.is_semantics_disabled(),
    selected: self.is_semantics_selected(),
    pressed: self.is_semantics_pressed(),
    checked: self.is_semantics_checked(),
    expanded: self.is_semantics_expanded(),
    invalid: self.is_semantics_invalid(),
    required: self.is_semantics_required(),
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
    role: self.semantics_role(info.role),
    label: self.semantics_label(info.label),
    value: self.semantics_value(info.value),
    description: self.semantics_description(info.description),
    state,
    actions,
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
  description : String
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
        description: "",
        actions: [],
      }
    ButtonSpec(data) =>
      {
        role: Button,
        label: data.text,
        value: "",
        description: "",
        actions: [Focus, Activate],
      }
    CheckboxSpec(data) =>
      {
        role: Checkbox,
        label: data.label,
        value: if data.checked.get() {
          "true"
        } else {
          "false"
        },
        description: "",
        actions: [Focus, Activate],
      }
    PickerSpec(data) =>
      {
        role: Menu,
        label: data.placeholder,
        value: data.selected.get(),
        description: "",
        actions: [Focus, Activate],
      }
    DatePickerSpec(data) =>
      {
        role: Menu,
        label: data.placeholder,
        value: data.selected.get().format(data.mode),
        description: "",
        actions: [Focus, Activate],
      }
    SearchBarSpec(data) =>
      {
        role: TextField,
        label: data.placeholder,
        value: data.query.get(),
        description: "",
        actions: [Focus, SetText, Submit],
      }
    WebViewHostSpec(data) =>
      {
        role: WebView,
        label: data.title,
        value: data.url,
        description: "",
        actions: [Focus],
      }
    SheetSpec(_data) =>
      { role: Dialog, label: "", value: "", description: "", actions: [] }
    TextFieldSpec(data) =>
      {
        role: TextField,
        label: data.placeholder,
        value: data.value.get(),
        description: "",
        actions: [Focus, SetText, Submit],
      }
    RichTextEditorSpec(data) =>
      {
        role: TextField,
        label: data.placeholder,
        value: data.value.get(),
        description: "",
        actions: [Focus, SetText],
      }
    ListSpec(_) =>
      { role: List, label: "", value: "", description: "", actions: [] }
    GridSpec(_) =>
      { role: Grid, label: "", value: "", description: "", actions: [] }
    ScrollSpec(_) =>
      {
        role: ScrollView,
        label: "",
        value: "",
        description: "",
        actions: [Scroll],
      }
    ImageSpec(data) =>
      {
        role: None,
        label: data.source,
        value: "",
        description: "",
        actions: [],
      }
    CustomSpec(data) =>
      {
        role: data.semantics_role,
        label: data.semantics_label,
        value: data.semantics_label,
        description: "",
        actions: [],
      }
    CustomLayoutSpec(data) =>
      {
        role: data.semantics_role,
        label: data.semantics_label,
        value: data.semantics_label,
        description: "",
        actions: [],
      }
    EmptySpec | SpacerSpec(_) =>
      { role: None, label: "", value: "", description: "", actions: [] }
    FlexSpec(_)
    | PaddingSpec(_)
    | ContainerSpec(_)
    | FrameSpec(_)
    | StackSpec(_)
    | ComponentSpec(_) =>
      { role: Group, label: "", value: "", description: "", actions: [] }
    ModifiedSpec(data) => modified_semantics_info(data.modifier)
  }
}

///|
fn modified_semantics_info(modifier : ViewModifier) -> SemanticsInfo {
  match modifier {
    AccessibilityLabelModifier(label) =>
      { role: Group, label, value: label, description: "", actions: [] }
    SemanticsRoleModifier(role) =>
      { role, label: "", value: "", description: "", actions: [] }
    FocusableModifier(focusable) =>
      {
        role: Group,
        label: "",
        value: "",
        description: "",
        actions: if focusable {
          [Focus]
        } else {
          []
        },
      }
    OnTapModifier(_)
    | OnLongPressModifier(_)
    | OnDoubleTapModifier(_)
    | OnDragModifier(_)
    | OnDragWithFrameModifier(_)
    | KeyboardShortcutModifier(_) =>
      {
        role: Button,
        label: "",
        value: "",
        description: "",
        actions: [Focus, Activate],
      }
    SemanticsSelectedModifier(_) =>
      { role: Group, label: "", value: "", description: "", actions: [Select] }
    SemanticsPressedModifier(_) =>
      { role: Group, label: "", value: "", description: "", actions: [] }
    SemanticsCheckedModifier(_) =>
      { role: Group, label: "", value: "", description: "", actions: [] }
    SemanticsExpandedModifier(expanded) =>
      {
        role: Group,
        label: "",
        value: "",
        description: "",
        actions: if expanded {
          [Collapse]
        } else {
          [Expand]
        },
      }
    SemanticsInvalidModifier(_) | SemanticsRequiredModifier(_) =>
      { role: Group, label: "", value: "", description: "", actions: [] }
    SemanticsDescriptionModifier(description) =>
      { role: Group, label: "", value: "", description, actions: [] }
    SemanticsActionModifier(action) =>
      { role: Group, label: "", value: "", description: "", actions: [action] }
    OnFileDropModifier(_) =>
      { role: Group, label: "", value: "", description: "", actions: [] }
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
    | FocusTrapModifier(_)
    | FlexibleModifier(_)
    | LayoutPriorityModifier(_)
    | AlignModifier(_)
    | SpacingModifier(_)
    | MainAxisAlignmentModifier(_)
    | CrossAxisAlignmentModifier(_)
    | ThemeModifier(_)
    | EnvironmentModifier(_)
    | AspectRatioModifier(_)
    | IntrinsicWidthModifier
    | IntrinsicHeightModifier
    | RepaintBoundaryModifier =>
      { role: Group, label: "", value: "", description: "", actions: [] }
  }
}

///|
fn ElementNode::semantics_role(
  self : ElementNode,
  role : SemanticsRole,
) -> SemanticsRole {
  if role != SemanticsRole::Group {
    role
  } else if self.should_inherit_child_semantics_role() &&
    self.children.length() > 0 {
    self.children[0].primary_semantics_role()
  } else {
    role
  }
}

///|
fn ElementNode::semantics_label(self : ElementNode, label : String) -> String {
  if label != "" {
    label
  } else if self.should_merge_child_semantics() && self.children.length() > 0 {
    self.children[0].primary_semantics_label()
  } else {
    ""
  }
}

///|
fn ElementNode::semantics_value(self : ElementNode, value : String) -> String {
  if value != "" {
    value
  } else if self.should_merge_child_semantics() && self.children.length() > 0 {
    self.children[0].primary_semantics_value()
  } else {
    ""
  }
}

///|
fn ElementNode::semantics_description(
  self : ElementNode,
  description : String,
) -> String {
  if description != "" {
    description
  } else if self.should_merge_child_semantics() && self.children.length() > 0 {
    self.children[0].primary_semantics_description()
  } else {
    ""
  }
}

///|
fn ElementNode::semantics_actions(
  self : ElementNode,
  actions : Array[SemanticsAction],
) -> Array[SemanticsAction] {
  let merged = actions.copy()
  if self.should_merge_child_semantics() && self.children.length() > 0 {
    append_unique_semantics_actions(
      merged,
      self.children[0].primary_semantics_actions(),
    )
  }
  merged
}

///|
fn ElementNode::primary_semantics_label(self : ElementNode) -> String {
  let info = self.semantics_info(list_item=false)
  if info.label != "" {
    info.label
  } else if self.children.length() > 0 && self.is_semantics_passthrough() {
    self.children[0].primary_semantics_label()
  } else {
    ""
  }
}

///|
fn ElementNode::primary_semantics_role(self : ElementNode) -> SemanticsRole {
  let info = self.semantics_info(list_item=false)
  let role = if info.role == SemanticsRole::Group &&
    self.should_inherit_child_semantics_role() &&
    self.children.length() > 0 {
    self.children[0].primary_semantics_role()
  } else {
    info.role
  }
  if role == SemanticsRole::Group &&
    self.children.length() > 0 &&
    self.is_semantics_passthrough() {
    self.children[0].primary_semantics_role()
  } else {
    role
  }
}

///|
fn ElementNode::should_inherit_child_semantics_role(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) => data.modifier.is_semantic_state_modifier()
    _ => false
  }
}

///|
fn ElementNode::primary_semantics_value(self : ElementNode) -> String {
  let info = self.semantics_info(list_item=false)
  if info.value != "" {
    info.value
  } else if self.children.length() > 0 && self.is_semantics_passthrough() {
    self.children[0].primary_semantics_value()
  } else {
    ""
  }
}

///|
fn ElementNode::primary_semantics_description(self : ElementNode) -> String {
  let info = self.semantics_info(list_item=false)
  if info.description != "" {
    info.description
  } else if self.children.length() > 0 && self.is_semantics_passthrough() {
    self.children[0].primary_semantics_description()
  } else {
    ""
  }
}

///|
fn ElementNode::primary_semantics_actions(
  self : ElementNode,
) -> Array[SemanticsAction] {
  let info = self.semantics_info(list_item=false)
  let actions = info.actions.copy()
  if self.children.length() > 0 && self.is_semantics_passthrough() {
    append_unique_semantics_actions(
      actions,
      self.children[0].primary_semantics_actions(),
    )
  }
  actions
}

///|
fn ElementNode::should_merge_child_semantics(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) => data.modifier.is_semantic_metadata_modifier()
    _ => false
  }
}

///|
fn ElementNode::is_semantics_passthrough(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(_) | PaddingSpec(_) | FrameSpec(_) | ContainerSpec(_) => true
    _ => false
  }
}

///|
fn ViewModifier::is_semantic_metadata_modifier(self : ViewModifier) -> Bool {
  match self {
    DisabledModifier(_)
    | AccessibilityLabelModifier(_)
    | SemanticsRoleModifier(_)
    | SemanticsSelectedModifier(_)
    | SemanticsPressedModifier(_)
    | SemanticsCheckedModifier(_)
    | SemanticsExpandedModifier(_)
    | SemanticsInvalidModifier(_)
    | SemanticsRequiredModifier(_)
    | SemanticsDescriptionModifier(_)
    | SemanticsActionModifier(_) => true
    _ => false
  }
}

///|
fn ViewModifier::is_semantic_state_modifier(self : ViewModifier) -> Bool {
  match self {
    DisabledModifier(_)
    | AccessibilityLabelModifier(_)
    | SemanticsSelectedModifier(_)
    | SemanticsPressedModifier(_)
    | SemanticsCheckedModifier(_)
    | SemanticsExpandedModifier(_)
    | SemanticsInvalidModifier(_)
    | SemanticsRequiredModifier(_)
    | SemanticsDescriptionModifier(_)
    | SemanticsActionModifier(_) => true
    _ => false
  }
}

///|
fn append_unique_semantics_actions(
  target : Array[SemanticsAction],
  source : Array[SemanticsAction],
) -> Unit {
  for action in source {
    if !target.any(existing => existing == action) {
      target.push(action)
    }
  }
}

///|
fn ElementNode::is_semantics_checked(self : ElementNode) -> Bool {
  match self.spec {
    CheckboxSpec(data) => data.checked.get()
    ModifiedSpec(data) =>
      match data.modifier {
        SemanticsCheckedModifier(checked) => checked
        _ =>
          if self.children.length() > 0 {
            self.children[0].is_semantics_checked()
          } else {
            false
          }
      }
    _ => false
  }
}

///|
fn ElementNode::is_semantics_pressed(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) =>
      match data.modifier {
        SemanticsPressedModifier(pressed) => pressed
        _ =>
          if self.children.length() > 0 {
            self.children[0].is_semantics_pressed()
          } else {
            false
          }
      }
    _ => false
  }
}

///|
fn ElementNode::is_semantics_selected(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) =>
      match data.modifier {
        SemanticsSelectedModifier(selected) => selected
        _ =>
          if self.children.length() > 0 {
            self.children[0].is_semantics_selected()
          } else {
            false
          }
      }
    _ => false
  }
}

///|
fn ElementNode::is_semantics_expanded(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) =>
      match data.modifier {
        SemanticsExpandedModifier(expanded) => expanded
        _ =>
          if self.children.length() > 0 {
            self.children[0].is_semantics_expanded()
          } else {
            false
          }
      }
    _ => false
  }
}

///|
fn ElementNode::is_semantics_invalid(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) =>
      match data.modifier {
        SemanticsInvalidModifier(invalid) => invalid
        _ =>
          if self.children.length() > 0 {
            self.children[0].is_semantics_invalid()
          } else {
            false
          }
      }
    _ => false
  }
}

///|
fn ElementNode::is_semantics_required(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) =>
      match data.modifier {
        SemanticsRequiredModifier(required) => required
        _ =>
          if self.children.length() > 0 {
            self.children[0].is_semantics_required()
          } else {
            false
          }
      }
    _ => false
  }
}

///|
fn ElementNode::is_semantics_disabled(self : ElementNode) -> Bool {
  match self.spec {
    ModifiedSpec(data) =>
      if data.modifier is DisabledModifier(true) {
        true
      } else if self.children.length() > 0 {
        self.children[0].is_semantics_disabled()
      } else {
        false
      }
    _ => false
  }
}
