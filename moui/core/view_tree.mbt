///|
type DragGestureMessageHandler[Msg] = (DragGestureEvent) -> Msg

///|
type FrameDragGestureMessageHandler[Msg] = (DragGestureEvent, Rect) -> Msg

///|
type FileDropMessageHandler[Msg] = (Array[String], Point) -> Msg

///|
priv struct FrameModifierSpec {
  width : Double?
  height : Double?
  min_width : Double?
  min_height : Double?
  max_width : Double?
  max_height : Double?
}

///|
/// 
#warnings("-unused_field")
priv enum ViewModifier[Msg] {
  KeyModifier(Key)
  PaddingModifier(Insets)
  FrameModifier(FrameModifierSpec)
  BackgroundModifier(Brush)
  ForegroundModifier(Color)
  FontModifier(FontSpec)
  CornerRadiusModifier(Double)
  OpacityModifier(Double)
  ShadowModifier(ShadowStyle)
  BorderModifier(BorderStyle)
  OffsetModifier(Double, Double)
  ClipModifier
  ScaleModifier(Double, Double)
  DisabledModifier(Bool)
  AccessibilityLabelModifier(String)
  SemanticIdModifier(SemanticId)
  SemanticsCompositionModifier(SemanticsComposition)
  SemanticsRoleModifier(SemanticsRole)
  SemanticsLevelModifier(Int)
  SemanticsUrlModifier(String)
  SemanticsSelectedModifier(Bool)
  SemanticsPressedModifier(Bool)
  SemanticsCheckedModifier(Bool)
  SemanticsExpandedModifier(Bool)
  SemanticsInvalidModifier(Bool)
  SemanticsRequiredModifier(Bool)
  SemanticsDescriptionModifier(String)
  FocusableModifier(Bool)
  FocusTrapModifier(Bool)
  OnTapMessageModifier(Msg)
  OnLongPressMessageModifier(Msg)
  OnDoubleTapMessageModifier(Msg)
  OnDragMessageModifier(DragGestureMessageHandler[Msg])
  OnDragWithFrameMessageModifier(FrameDragGestureMessageHandler[Msg])
  OnFileDropMessageModifier(FileDropMessageHandler[Msg])
  KeyboardShortcutModifier(KeyboardShortcut)
  FlexibleModifier(Double)
  LayoutPriorityModifier(Double)
  AlignModifier(Alignment)
  SpacingModifier(Double)
  MainAxisAlignmentModifier(MainAxisAlignment)
  CrossAxisAlignmentModifier(CrossAxisAlignment)
  ThemeModifier(Theme)
  EnvironmentModifier(Environment)
  AspectRatioModifier(Double)
  IntrinsicWidthModifier
  IntrinsicHeightModifier
  RepaintBoundaryModifier
}

///|
fn[Msg] View::apply_modifier(
  self : View[Msg],
  modifier : ViewModifier[Msg],
) -> View[Msg] {
  modifier_view(self, modifier)
}

///|
fn[Msg] modifier_child_constraints(
  modifier : ViewModifier[Msg],
  constraints : Constraints,
) -> Constraints {
  match modifier {
    PaddingModifier(insets) => constraints.deflate(insets)
    FrameModifier(data) =>
      frame_modifier_constraints_for_measure(data, constraints)
    _ => constraints.loosen()
  }
}

///|
fn[Msg] modifier_child_environment(
  modifier : ViewModifier[Msg],
  environment : Environment,
) -> Environment {
  match modifier {
    ThemeModifier(theme) => environment.with_theme(theme)
    EnvironmentModifier(value) => value
    DisabledModifier(disabled) => environment.with_enabled(!disabled)
    _ => environment
  }
}

///|
fn[Msg] modifier_child_style(
  modifier : ViewModifier[Msg],
  style : ViewStyle,
) -> ViewStyle {
  match modifier {
    ForegroundModifier(color) => { ..style, foreground: Some(color) }
    FontModifier(font) => { ..style, font: Some(font) }
    CornerRadiusModifier(radius) => { ..style, corner_radius: Some(radius) }
    BackgroundModifier(brush) => { ..style, background: Some(brush) }
    _ => style
  }
}

///|
fn[Msg] modifier_layout(
  modifier : ViewModifier[Msg],
  ctx : ViewLayoutContext,
) -> ViewLayoutResult {
  let child_size = first_modifier_child_size(ctx.child_sizes)
  let size = ctx.constraints.constrain(
    match modifier {
      PaddingModifier(insets) => child_size.inflate(insets)
      FrameModifier(data) => resolve_frame_modifier_size(data, child_size)
      AspectRatioModifier(ratio) => aspect_ratio_size(child_size, ratio)
      // Tight-fit (flex-basis 0): measured size is zero so the parent flex
      // distributes the full main-axis space by weight without leaking the
      // child's greedy measurement into the cached intrinsic size.
      FlexibleModifier(_) => Size::new(width=0.0, height=0.0)
      _ => child_size
    },
  )
  ViewLayoutResult::new(size~, child_frames=[
    modifier_child_frame(modifier, size, child_size),
  ])
}

///|
fn[Msg] modifier_child_frame(
  modifier : ViewModifier[Msg],
  size : Size,
  child_size : Size,
) -> Rect {
  let frame = Rect::new(x=0.0, y=0.0, width=size.width, height=size.height)
  match modifier {
    PaddingModifier(insets) => frame.inset(insets)
    FrameModifier(data) => frame_rect_for_modifier(data, frame)
    AlignModifier(alignment) => aligned_rect(frame, child_size, alignment)
    OffsetModifier(dx, dy) => frame.offset(dx~, dy~)
    AspectRatioModifier(ratio) => aspect_ratio_rect(frame, ratio)
    _ => frame
  }
}

///|
fn[Msg] modifier_paint(
  modifier : ViewModifier[Msg],
  ctx : ViewPaintContext,
) -> ViewPaintPlan {
  match modifier {
    BackgroundModifier(brush) => {
      let radius = match ctx.style.corner_radius {
        Some(value) => value
        None => 0.0
      }
      ViewPaintPlan::commands([
        DrawCommand::FillRoundedRectBrush(
          RoundedRect::new(rect=ctx.frame, radius~),
          brush,
        ),
      ])
    }
    OpacityModifier(opacity) =>
      {
        commands: [DrawCommand::PushOpacity(opacity)],
        child_layers: [],
        post_commands: [DrawCommand::PopOpacity],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    ShadowModifier(style) =>
      ViewPaintPlan::commands([
        DrawCommand::DrawShadow(
          ShadowSpec::new(
            rect=RoundedRect::new(rect=ctx.frame, radius=0.0),
            color=style.color,
            offset=style.offset,
            blur_radius=style.blur_radius,
            spread=style.spread,
          ),
        ),
      ])
    BorderModifier(style) =>
      if style.width > 0.0 {
        let radius = match ctx.style.corner_radius {
          Some(value) => value
          None => 0.0
        }
        ViewPaintPlan::commands([
          DrawCommand::StrokeRoundedRectBrush(
            RoundedRect::new(rect=ctx.frame, radius~),
            style.brush,
            style.width,
          ),
        ])
      } else {
        ViewPaintPlan::empty()
      }
    ClipModifier =>
      {
        commands: [DrawCommand::PushClip(ctx.frame)],
        child_layers: [],
        post_commands: [DrawCommand::PopClip],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    ScaleModifier(sx, sy) =>
      {
        commands: [DrawCommand::PushTransform(Transform2D::scale(sx~, sy~))],
        child_layers: [],
        post_commands: [DrawCommand::PopTransform],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    DisabledModifier(true) =>
      {
        commands: [DrawCommand::PushOpacity(0.42)],
        child_layers: [],
        post_commands: [DrawCommand::PopOpacity],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    RepaintBoundaryModifier =>
      { ..ViewPaintPlan::empty(), repaint_boundary: true }
    _ => ViewPaintPlan::empty()
  }
}

///|
fn[Msg] modifier_event(
  modifier : ViewModifier[Msg],
  ctx : ViewEventContext,
) -> ViewEventResult[Msg] {
  match modifier {
    DisabledModifier(true) => ViewEventResult::ignored()
    OnTapMessageModifier(message) => handle_tap_modifier(message, ctx)
    OnLongPressMessageModifier(message) =>
      handle_long_press_modifier(message, ctx)
    OnDoubleTapMessageModifier(message) =>
      handle_double_tap_modifier(message, ctx)
    OnDragMessageModifier(handler) =>
      handle_drag_modifier(ctx, handler=(event, _frame) => handler(event))
    OnDragWithFrameMessageModifier(handler) =>
      handle_drag_modifier(ctx, handler~)
    OnFileDropMessageModifier(handler) =>
      handle_file_drop_modifier(handler, ctx)
    KeyboardShortcutModifier(shortcut) =>
      handle_keyboard_shortcut(shortcut, ctx)
    FocusableModifier(true) => handle_focusable_modifier(ctx)
    _ => ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_tap_modifier(
  message : Msg,
  ctx : ViewEventContext,
) -> ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) => {
      let inside = ctx.frame.contains(event.position)
      let current = view_state_to_pressable_state(ctx.state)
      let tap = recognize_press_tap(current, inside, event.phase)
      let next_state = pressable_state_to_view_state(ctx.state, tap.next_state)
      let changed = next_state != ctx.state || tap.activated
      {
        changed,
        activated: tap.activated,
        focused: false,
        captured: inside || current == PressableState::Pressed,
        state: Some(next_state),
        text_control: None,
        dirty: if changed {
          ViewDirtyHint::ViewPaintDirty
        } else {
          ViewDirtyHint::ViewClean
        },
        messages: if tap.activated {
          [message]
        } else {
          []
        },
      }
    }
    Keyboard(event) =>
      if event.pressed && (event.key == "Enter" || event.key == " ") {
        ViewEventResult::message(message)
      } else {
        ViewEventResult::ignored()
      }
    _ => ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_long_press_modifier(
  message : Msg,
  ctx : ViewEventContext,
) -> ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) => {
      let result = LongPressGestureState::new().update(
        event,
        inside=ctx.frame.contains(event.position),
      )
      if result.recognized {
        ViewEventResult::message(message)
      } else {
        {
          ..ViewEventResult::ignored(),
          changed: result.cancelled,
          captured: result.cancelled,
          dirty: if result.cancelled {
            ViewDirtyHint::ViewPaintDirty
          } else {
            ViewDirtyHint::ViewClean
          },
        }
      }
    }
    _ => ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_double_tap_modifier(
  message : Msg,
  ctx : ViewEventContext,
) -> ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) => {
      let result = DoubleTapGestureState::new().update(
        event,
        inside=ctx.frame.contains(event.position),
      )
      if result.recognized {
        ViewEventResult::message(message)
      } else {
        ViewEventResult::ignored()
      }
    }
    _ => ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_drag_modifier(
  ctx : ViewEventContext,
  handler~ : (DragGestureEvent, Rect) -> Msg,
) -> ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) => {
      let slot = drag_gesture_view_state_slot()
      let gesture = ctx.state.read_slot(slot)
      let result = gesture.update(
        event,
        inside=ctx.frame.contains(event.position),
      )
      let active = result.state.phase != DragGesturePhase::Idle
      let next_state = if active {
        ctx.state.with_slot(slot, result.state)
      } else {
        ctx.state.without_slot(slot)
      }
      match result.event {
        Some(drag_event) => {
          let frame = match ctx.child_frames {
            [child_frame, ..] => child_frame
            [] => ctx.frame
          }
          {
            changed: true,
            activated: true,
            focused: false,
            captured: true,
            state: Some(next_state),
            text_control: None,
            dirty: ViewDirtyHint::ViewPaintDirty,
            messages: [handler(drag_event, frame)],
          }
        }
        None =>
          if active {
            {
              changed: next_state != ctx.state,
              activated: false,
              focused: false,
              captured: true,
              state: Some(next_state),
              text_control: None,
              dirty: if next_state != ctx.state {
                ViewDirtyHint::ViewPaintDirty
              } else {
                ViewDirtyHint::ViewClean
              },
              messages: [],
            }
          } else {
            ViewEventResult::ignored()
          }
      }
    }
    _ => ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_file_drop_modifier(
  handler : (Array[String], Point) -> Msg,
  ctx : ViewEventContext,
) -> ViewEventResult[Msg] {
  match ctx.event {
    DragDrop(event) =>
      match (event.phase, event.position) {
        (Dropped, Some(position)) =>
          if ctx.frame.contains(position) && event.paths.length() > 0 {
            {
              changed: true,
              activated: true,
              focused: false,
              captured: true,
              state: None,
              text_control: None,
              dirty: ViewDirtyHint::ViewPaintDirty,
              messages: [handler(event.paths, position)],
            }
          } else {
            ViewEventResult::ignored()
          }
        _ => ViewEventResult::ignored()
      }
    _ => ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_keyboard_shortcut(
  shortcut : KeyboardShortcut,
  ctx : ViewEventContext,
) -> ViewEventResult[Msg] {
  match ctx.event {
    Keyboard(event) =>
      if shortcut.matches(event) {
        { ..ViewEventResult::ignored(), captured: true }
      } else {
        ViewEventResult::ignored()
      }
    _ => ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_focusable_modifier(
  ctx : ViewEventContext,
) -> ViewEventResult[Msg] {
  match ctx.event {
    Keyboard(event) =>
      if event.pressed && (event.key == "Enter" || event.key == " ") {
        { ..ViewEventResult::ignored(), activated: true, captured: true }
      } else {
        ViewEventResult::ignored()
      }
    Pointer(event) =>
      if event.phase == PointerPhase::Down && ctx.frame.contains(event.position) {
        { ..ViewEventResult::ignored(), focused: true, captured: true }
      } else {
        ViewEventResult::ignored()
      }
    _ => ViewEventResult::ignored()
  }
}

///|
fn[Msg] modifier_semantics(modifier : ViewModifier[Msg]) -> ViewSemanticsInfo {
  match modifier {
    AccessibilityLabelModifier(label) =>
      ViewSemanticsInfo::new(label~, value=label)
    SemanticIdModifier(semantic_id) => ViewSemanticsInfo::new(semantic_id~)
    SemanticsCompositionModifier(composition) =>
      ViewSemanticsInfo::new(composition~)
    SemanticsRoleModifier(role) => ViewSemanticsInfo::new(role~)
    SemanticsLevelModifier(level) => ViewSemanticsInfo::new(level~)
    SemanticsUrlModifier(url) => ViewSemanticsInfo::new(url~)
    DisabledModifier(disabled) => ViewSemanticsInfo::new(disabled~)
    FocusableModifier(_) => ViewSemanticsInfo::new()
    OnTapMessageModifier(_)
    | OnLongPressMessageModifier(_)
    | OnDoubleTapMessageModifier(_)
    | OnDragMessageModifier(_)
    | OnDragWithFrameMessageModifier(_)
    | KeyboardShortcutModifier(_) =>
      ViewSemanticsInfo::new(role=SemanticsRole::Button)
    SemanticsSelectedModifier(selected) => ViewSemanticsInfo::new(selected~)
    SemanticsPressedModifier(pressed) => ViewSemanticsInfo::new(pressed~)
    SemanticsCheckedModifier(checked) => ViewSemanticsInfo::new(checked~)
    SemanticsExpandedModifier(expanded) => ViewSemanticsInfo::new(expanded~)
    SemanticsInvalidModifier(invalid) => ViewSemanticsInfo::new(invalid~)
    SemanticsRequiredModifier(required) => ViewSemanticsInfo::new(required~)
    SemanticsDescriptionModifier(description) =>
      ViewSemanticsInfo::new(description~)
    _ => ViewSemanticsInfo::new()
  }
}

///|
fn[Msg] modifier_semantics_actions(
  modifier : ViewModifier[Msg],
) -> Array[ViewSemanticsActionHandler[Msg]] {
  match modifier {
    OnTapMessageModifier(message) =>
      [
        ViewSemanticsActionHandler::activate(_context => {
          ViewSemanticsActionResult::message(message)
        }),
      ]
    _ => []
  }
}

///|
fn[Msg] modifier_focusable(modifier : ViewModifier[Msg]) -> Bool {
  match modifier {
    FocusableModifier(value) => value
    OnTapMessageModifier(_)
    | OnLongPressMessageModifier(_)
    | OnDoubleTapMessageModifier(_)
    | KeyboardShortcutModifier(_) => true
    _ => false
  }
}

///|
/// `FlexibleModifier` (applied via `View::flexible` / `View::expanded`)
/// declares a flex growth weight so the parent `row`/`column` distributes
/// leftover main-axis space to this node. All other modifiers pass the
/// child's own weight through unchanged.
fn[Msg] modifier_flex_weight(modifier : ViewModifier[Msg]) -> Double {
  match modifier {
    FlexibleModifier(weight) => weight
    _ => 0.0
  }
}

///|
fn first_modifier_child_size(sizes : Array[Size]) -> Size {
  match sizes {
    [size, ..] => size
    [] => Size::new(width=0.0, height=0.0)
  }
}

///|
fn frame_modifier_constraints_for_measure(
  data : FrameModifierSpec,
  constraints : Constraints,
) -> Constraints {
  match (data.width, data.height) {
    (Some(width), Some(height)) => constraints.tighten(width~, height~).loosen()
    (Some(width), None) => constraints.tighten(width~).loosen()
    (None, Some(height)) => constraints.tighten(height~).loosen()
    (None, None) => constraints.loosen()
  }
}

///|
fn resolve_frame_modifier_size(data : FrameModifierSpec, child : Size) -> Size {
  let width = data.width.unwrap_or(child.width)
  let height = data.height.unwrap_or(child.height)
  let min_width = data.min_width.unwrap_or(0.0)
  let min_height = data.min_height.unwrap_or(0.0)
  let max_width = data.max_width.unwrap_or(width)
  let max_height = data.max_height.unwrap_or(height)
  Size::new(width~, height~).clamp({
    min: Size::new(width=min_width, height=min_height),
    max: Size::new(
      width=max_double(min_width, max_width),
      height=max_double(min_height, max_height),
    ),
  })
}

///|
fn frame_rect_for_modifier(data : FrameModifierSpec, bounds : Rect) -> Rect {
  let size = resolve_frame_modifier_size(data, bounds.size)
  Rect::new(
    x=bounds.origin.x,
    y=bounds.origin.y,
    width=size.width,
    height=size.height,
  )
}

///|
fn aligned_rect(
  bounds : Rect,
  child_size : Size,
  alignment : Alignment,
) -> Rect {
  let width = min_double(bounds.size.width, child_size.width)
  let height = min_double(bounds.size.height, child_size.height)
  let dx = max_double(0.0, bounds.size.width - width) *
    (alignment.x + 1.0) /
    2.0
  let dy = max_double(0.0, bounds.size.height - height) *
    (alignment.y + 1.0) /
    2.0
  Rect::new(x=bounds.origin.x + dx, y=bounds.origin.y + dy, width~, height~)
}

///|
fn aspect_ratio_size(size : Size, ratio : Double) -> Size {
  if size.width > 0.0 {
    Size::new(width=size.width, height=size.width / ratio)
  } else if size.height > 0.0 {
    Size::new(width=size.height * ratio, height=size.height)
  } else {
    size
  }
}

///|
fn aspect_ratio_rect(frame : Rect, ratio : Double) -> Rect {
  let size = aspect_ratio_size(frame.size, ratio).clamp(
    Constraints::tight(frame.size),
  )
  Rect::new(
    x=frame.origin.x,
    y=frame.origin.y,
    width=size.width,
    height=size.height,
  )
}

///|
fn view_state_to_pressable_state(state : ViewStateContext) -> PressableState {
  if state.pressed {
    PressableState::Pressed
  } else if state.hovered {
    PressableState::Hovered
  } else {
    PressableState::Normal
  }
}

///|
fn pressable_state_to_view_state(
  state : ViewStateContext,
  pressable_state : PressableState,
) -> ViewStateContext {
  match pressable_state {
    PressableState::Normal => { ..state, hovered: false, pressed: false }
    PressableState::Hovered => { ..state, hovered: true, pressed: false }
    PressableState::Pressed => { ..state, hovered: true, pressed: true }
  }
}
