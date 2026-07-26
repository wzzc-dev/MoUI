///|
fn[Msg] modifier_view(
  child : View[Msg],
  modifier : ViewModifier[Msg],
) -> View[Msg] {
  let node = ModifierViewNode::{ child, modifier }
  View::from_node(
    node,
    children=node => [node.child],
    event=(node, context) => modifier_event(node.modifier, context),
    text_command=(node, context, intent, paste_text) => {
      node.child.text_command_result(context, intent, paste_text~)
    },
  )
}

///|
priv struct ModifierViewNode[Msg] {
  child : View[Msg]
  modifier : ViewModifier[Msg]
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn identity(self) {
  modifier_identity(self.child, self.modifier)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn revision(self) {
  "modifier:\{modifier_revision(self.modifier)}:\{self.child.revision()}"
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn child_constraints(
  self,
  constraints,
) {
  modifier_child_constraints(self.modifier, constraints)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn child_environment(
  self,
  environment,
) {
  modifier_child_environment(self.modifier, environment)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn child_style(self, style) {
  modifier_child_style(self.modifier, style)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn layout(self, context) {
  modifier_layout(self.modifier, context)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn paint(self, context) {
  modifier_paint(self.modifier, context)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn text_input_state(
  self,
  context,
) {
  self.child.text_input_state(context)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn semantics(self) {
  modifier_semantics(self.modifier)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn focusable(self) {
  modifier_focusable(self.modifier)
}

///|
impl[Msg] ViewNode for ModifierViewNode[Msg] with fn flex_weight(self) {
  modifier_flex_weight(self.modifier)
}

///|
fn[Msg] modifier_identity(
  child : View[Msg],
  modifier : ViewModifier[Msg],
) -> ViewIdentity {
  match modifier {
    KeyModifier(key) => {
      let identity = child.identity()
      { kind: identity.kind, key: Some(key) }
    }
    _ => {
      let identity = child.identity()
      {
        kind: "Modified<\{modifier_kind(modifier)}>/\{identity.kind}",
        key: identity.key,
      }
    }
  }
}

///|
fn[Msg] modifier_kind(modifier : ViewModifier[Msg]) -> String {
  match modifier {
    KeyModifier(_) => "Key"
    PaddingModifier(_) => "Padding"
    FrameModifier(_) => "Frame"
    BackgroundModifier(_) => "Background"
    ForegroundModifier(_) => "Foreground"
    FontModifier(_) => "Font"
    CornerRadiusModifier(_) => "CornerRadius"
    OpacityModifier(_) => "Opacity"
    ShadowModifier(_) => "Shadow"
    BorderModifier(_) => "Border"
    OffsetModifier(_, _) => "Offset"
    ClipModifier => "Clip"
    ScaleModifier(_, _) => "Scale"
    DisabledModifier(_) => "Disabled"
    AccessibilityLabelModifier(_) => "AccessibilityLabel"
    SemanticsRoleModifier(_) => "SemanticsRole"
    SemanticsLevelModifier(_) => "SemanticsLevel"
    SemanticsUrlModifier(_) => "SemanticsUrl"
    SemanticsSelectedModifier(_) => "SemanticsSelected"
    SemanticsPressedModifier(_) => "SemanticsPressed"
    SemanticsCheckedModifier(_) => "SemanticsChecked"
    SemanticsExpandedModifier(_) => "SemanticsExpanded"
    SemanticsInvalidModifier(_) => "SemanticsInvalid"
    SemanticsRequiredModifier(_) => "SemanticsRequired"
    SemanticsDescriptionModifier(_) => "SemanticsDescription"
    SemanticsActionModifier(_) => "SemanticsAction"
    FocusableModifier(_) => "Focusable"
    FocusTrapModifier(_) => "FocusTrap"
    OnTapMessageModifier(_) => "OnTap"
    OnLongPressMessageModifier(_) => "OnLongPress"
    OnDoubleTapMessageModifier(_) => "OnDoubleTap"
    OnDragMessageModifier(_) => "OnDrag"
    OnDragWithFrameMessageModifier(_) => "OnDragWithFrame"
    OnFileDropMessageModifier(_) => "OnFileDrop"
    KeyboardShortcutModifier(_) => "KeyboardShortcut"
    FlexibleModifier(_) => "Flexible"
    LayoutPriorityModifier(_) => "LayoutPriority"
    AlignModifier(_) => "Align"
    SpacingModifier(_) => "Spacing"
    MainAxisAlignmentModifier(_) => "MainAxisAlignment"
    CrossAxisAlignmentModifier(_) => "CrossAxisAlignment"
    ThemeModifier(_) => "Theme"
    EnvironmentModifier(_) => "Environment"
    AspectRatioModifier(_) => "AspectRatio"
    IntrinsicWidthModifier => "IntrinsicWidth"
    IntrinsicHeightModifier => "IntrinsicHeight"
    RepaintBoundaryModifier => "RepaintBoundary"
  }
}
