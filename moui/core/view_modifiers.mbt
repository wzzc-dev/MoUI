///|
pub fn[Msg, NextMsg] View::map(
  self : View[Msg],
  map : (Msg) -> NextMsg,
) -> View[NextMsg] {
  View::virtual_node(self.ops().map(map))
}

///|
pub fn[Msg] View::key(self : View[Msg], value : String) -> View[Msg] {
  self.apply_modifier(KeyModifier(Key::new(value)))
}

///|
pub fn[Msg] View::font(self : View[Msg], font : FontSpec) -> View[Msg] {
  self.apply_modifier(FontModifier(font))
}

///|
pub fn[Msg] View::foreground(self : View[Msg], color : Color) -> View[Msg] {
  self.apply_modifier(ForegroundModifier(color))
}

///|
pub fn[Msg] View::title(self : View[Msg]) -> View[Msg] {
  let theme = Theme::neutral()
  self.font(theme.typography.title).foreground(theme.foreground)
}

///|
pub fn[Msg] View::caption(self : View[Msg]) -> View[Msg] {
  let theme = Theme::neutral()
  self.font(theme.typography.caption).foreground(theme.palette.muted)
}

///|
pub fn[Msg] View::mono(self : View[Msg]) -> View[Msg] {
  let theme = Theme::neutral()
  self
  .font({ ..theme.typography.body, families: FontFamilyStack::monospace() })
  .foreground(theme.foreground)
}

///|
pub fn[Msg] View::background(self : View[Msg], color : Color) -> View[Msg] {
  self.background_brush(Brush::solid(color))
}

///|
pub fn[Msg] View::background_brush(
  self : View[Msg],
  brush : Brush,
) -> View[Msg] {
  self.apply_modifier(BackgroundModifier(brush))
}

///|
pub fn[Msg] View::corner_radius(self : View[Msg], radius : Double) -> View[Msg] {
  self.apply_modifier(CornerRadiusModifier(radius))
}

///|
pub fn[Msg] View::opacity(self : View[Msg], opacity : Double) -> View[Msg] {
  self.apply_modifier(OpacityModifier(opacity))
}

///|
pub fn[Msg] View::shadow(self : View[Msg], style : ShadowStyle) -> View[Msg] {
  self.apply_modifier(ShadowModifier(style))
}

///|
pub fn[Msg] View::border(self : View[Msg], style : BorderStyle) -> View[Msg] {
  self.apply_modifier(BorderModifier(style))
}

///|
pub fn[Msg] View::offset(
  self : View[Msg],
  dx? : Double = 0.0,
  dy? : Double = 0.0,
) -> View[Msg] {
  self.apply_modifier(OffsetModifier(dx, dy))
}

///|
pub fn[Msg] View::clip(self : View[Msg]) -> View[Msg] {
  self.apply_modifier(ClipModifier)
}

///|
pub fn[Msg] View::scale(
  self : View[Msg],
  sx? : Double = 1.0,
  sy? : Double = 1.0,
) -> View[Msg] {
  self.apply_modifier(ScaleModifier(sx, sy))
}

///|
pub fn[Msg] View::transition(
  self : View[Msg],
  spec? : TransitionSpec = TransitionSpec::new(),
  progress? : Double = 1.0,
  reduced_motion? : Bool = false,
) -> View[Msg] {
  self.apply_transition_style(spec.sample(progress, reduced_motion~).style)
}

///|
pub fn[Msg] View::presence(
  self : View[Msg],
  present~ : Bool,
  spec? : TransitionSpec = TransitionSpec::fade(),
  progress? : Double = 1.0,
  reduced_motion? : Bool = false,
) -> View[Msg] {
  let sample = spec.presence(present~, progress~, reduced_motion~)
  if sample.present {
    self.apply_transition_style(sample.style)
  } else {
    View::virtual_node(
      VirtualNode::new(identity=() => VirtualNodeIdentity::new(kind="Empty"), layout=ctx => {
        VirtualNodeLayoutResult::new(
          size=ctx.constraints.constrain(Size::new(width=0.0, height=0.0)),
        )
      }),
    )
  }
}

///|
fn[Msg] View::apply_transition_style(
  self : View[Msg],
  style : TransitionStyle,
) -> View[Msg] {
  let mut view = self
  view = view.opacity(style.opacity)
  if style.offset.x != 0.0 || style.offset.y != 0.0 {
    view = view.offset(dx=style.offset.x, dy=style.offset.y)
  }
  if style.scale.x != 1.0 || style.scale.y != 1.0 {
    view = view.scale(sx=style.scale.x, sy=style.scale.y)
  }
  match style.foreground {
    Some(color) => view.foreground(color)
    None => view
  }
}

///|
pub fn[Msg] View::disabled(
  self : View[Msg],
  disabled? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(DisabledModifier(disabled))
}

///|
pub fn[Msg] View::accessibility_label(
  self : View[Msg],
  label : String,
) -> View[Msg] {
  self.apply_modifier(AccessibilityLabelModifier(label))
}

///|
pub fn[Msg] View::semantics_role(
  self : View[Msg],
  role : SemanticsRole,
) -> View[Msg] {
  self.apply_modifier(SemanticsRoleModifier(role))
}

///|
pub fn[Msg] View::semantics_selected(
  self : View[Msg],
  selected? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(SemanticsSelectedModifier(selected))
}

///|
pub fn[Msg] View::semantics_pressed(
  self : View[Msg],
  pressed? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(SemanticsPressedModifier(pressed))
}

///|
pub fn[Msg] View::semantics_checked(
  self : View[Msg],
  checked? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(SemanticsCheckedModifier(checked))
}

///|
pub fn[Msg] View::semantics_expanded(
  self : View[Msg],
  expanded? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(SemanticsExpandedModifier(expanded))
}

///|
pub fn[Msg] View::semantics_invalid(
  self : View[Msg],
  invalid? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(SemanticsInvalidModifier(invalid))
}

///|
pub fn[Msg] View::semantics_required(
  self : View[Msg],
  required? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(SemanticsRequiredModifier(required))
}

///|
pub fn[Msg] View::semantics_description(
  self : View[Msg],
  description : String,
) -> View[Msg] {
  self.apply_modifier(SemanticsDescriptionModifier(description))
}

///|
pub fn[Msg] View::semantics_action(
  self : View[Msg],
  action : SemanticsAction,
) -> View[Msg] {
  self.apply_modifier(SemanticsActionModifier(action))
}

///|
pub fn[Msg] View::semantics_dismiss_action(self : View[Msg]) -> View[Msg] {
  self.semantics_action(SemanticsAction::Dismiss)
}

///|
pub fn[Msg] View::focusable(
  self : View[Msg],
  focusable? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(FocusableModifier(focusable))
}

///|
pub fn[Msg] View::focus_trap(
  self : View[Msg],
  enabled? : Bool = true,
) -> View[Msg] {
  self.apply_modifier(FocusTrapModifier(enabled))
}

///|
pub fn[Msg] View::on_tap(self : View[Msg], message : Msg) -> View[Msg] {
  self.apply_modifier(OnTapMessageModifier(message))
}

///|
pub fn[Msg] View::on_long_press(self : View[Msg], message : Msg) -> View[Msg] {
  self.apply_modifier(OnLongPressMessageModifier(message))
}

///|
pub fn[Msg] View::on_double_tap(self : View[Msg], message : Msg) -> View[Msg] {
  self.apply_modifier(OnDoubleTapMessageModifier(message))
}

///|
pub fn[Msg] View::on_drag(
  self : View[Msg],
  handler : (DragGestureEvent) -> Msg,
) -> View[Msg] {
  self.apply_modifier(OnDragMessageModifier(handler))
}

///|
pub fn[Msg] View::on_drag_with_frame(
  self : View[Msg],
  handler : (DragGestureEvent, Rect) -> Msg,
) -> View[Msg] {
  self.apply_modifier(OnDragWithFrameMessageModifier(handler))
}

///|
pub fn[Msg] View::on_file_drop(
  self : View[Msg],
  handler : (Array[String], Point) -> Msg,
) -> View[Msg] {
  self.apply_modifier(OnFileDropMessageModifier(handler))
}

///|
pub fn[Msg] View::keyboard_shortcut(
  self : View[Msg],
  shortcut : KeyboardShortcut,
) -> View[Msg] {
  self.apply_modifier(KeyboardShortcutModifier(shortcut))
}

///|
pub fn[Msg] View::flexible(
  self : View[Msg],
  weight? : Double = 1.0,
) -> View[Msg] {
  self.apply_modifier(FlexibleModifier(max_double(0.0, weight)))
}

///|
pub fn[Msg] View::layout_priority(
  self : View[Msg],
  priority : Double,
) -> View[Msg] {
  self.apply_modifier(LayoutPriorityModifier(priority))
}

///|
pub fn[Msg] View::expanded(
  self : View[Msg],
  weight? : Double = 1.0,
) -> View[Msg] {
  self.flexible(weight~)
}

///|
pub fn[Msg] View::align(
  self : View[Msg],
  alignment? : Alignment = Alignment::center(),
) -> View[Msg] {
  self.apply_modifier(AlignModifier(alignment))
}

///|
pub fn[Msg] View::aspect_ratio(self : View[Msg], ratio : Double) -> View[Msg] {
  self.apply_modifier(AspectRatioModifier(max_double(0.01, ratio)))
}

///|
pub fn[Msg] View::intrinsic_width(self : View[Msg]) -> View[Msg] {
  self.apply_modifier(IntrinsicWidthModifier)
}

///|
pub fn[Msg] View::intrinsic_height(self : View[Msg]) -> View[Msg] {
  self.apply_modifier(IntrinsicHeightModifier)
}

///|
pub fn[Msg] View::repaint_boundary(self : View[Msg]) -> View[Msg] {
  self.apply_modifier(RepaintBoundaryModifier)
}

///|
pub fn[Msg] View::padding(self : View[Msg], value : Double) -> View[Msg] {
  self.apply_modifier(PaddingModifier(Insets::all(value)))
}

///|
pub fn[Msg] View::spacing(self : View[Msg], spacing : Double) -> View[Msg] {
  self.apply_modifier(SpacingModifier(spacing))
}

///|
pub fn[Msg] View::main_axis_alignment(
  self : View[Msg],
  alignment : MainAxisAlignment,
) -> View[Msg] {
  self.apply_modifier(MainAxisAlignmentModifier(alignment))
}

///|
pub fn[Msg] View::cross_axis_alignment(
  self : View[Msg],
  alignment : CrossAxisAlignment,
) -> View[Msg] {
  self.apply_modifier(CrossAxisAlignmentModifier(alignment))
}

///|
pub fn[Msg] View::theme(self : View[Msg], theme : Theme) -> View[Msg] {
  self.apply_modifier(ThemeModifier(theme))
}

///|
pub fn[Msg] View::environment(
  self : View[Msg],
  environment : Environment,
) -> View[Msg] {
  self.apply_modifier(EnvironmentModifier(environment))
}

///|
pub fn[Msg] View::frame(
  self : View[Msg],
  width? : Double,
  height? : Double,
  min_width? : Double,
  min_height? : Double,
  max_width? : Double,
  max_height? : Double,
) -> View[Msg] {
  self.apply_modifier(
    FrameModifier({
      width,
      height,
      min_width,
      min_height,
      max_width,
      max_height,
    }),
  )
}
