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
  SemanticsActionModifier(SemanticsAction)
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
fn[Msg] modifier_view(
  child : View[Msg],
  modifier : ViewModifier[Msg],
) -> View[Msg] {
  View::node(
    identity=() => modifier_identity(child, modifier),
    revision=() => "modifier:\{modifier_revision(modifier)}:\{child.revision()}",
    children=() => [child],
    child_constraints=constraints => {
      modifier_child_constraints(modifier, constraints)
    },
    child_environment=environment => {
      modifier_child_environment(modifier, environment)
    },
    child_style=style => modifier_child_style(modifier, style),
    layout=ctx => modifier_layout(modifier, ctx),
    paint=ctx => modifier_paint(modifier, ctx),
    event=ctx => modifier_event(modifier, ctx),
    text_input_state=ctx => child.text_input_state(ctx),
    text_command=(ctx, intent, paste_text) => {
      child.text_command_result(ctx, intent, paste_text~)
    },
    semantics=() => modifier_semantics(modifier),
    focusable=() => modifier_focusable(modifier),
    flex_weight=() => modifier_flex_weight(modifier),
  )
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

///|
fn[Msg] modifier_revision(modifier : ViewModifier[Msg]) -> String {
  match modifier {
    KeyModifier(key) => "key:\{key.value}"
    PaddingModifier(insets) =>
      "padding:\{insets.top}:\{insets.right}:\{insets.bottom}:\{insets.left}"
    FrameModifier(data) =>
      "frame:\{option_double_revision(data.width)}:\{option_double_revision(data.height)}:\{option_double_revision(data.min_width)}:\{option_double_revision(data.min_height)}:\{option_double_revision(data.max_width)}:\{option_double_revision(data.max_height)}"
    BackgroundModifier(brush) => "background:\{brush_revision(brush)}"
    ForegroundModifier(color) => "foreground:\{color_revision(color)}"
    FontModifier(font) => "font:\{font.size}:\{font.weight}"
    CornerRadiusModifier(radius) => "corner-radius:\{radius}"
    OpacityModifier(opacity) => "opacity:\{opacity}"
    ShadowModifier(style) =>
      "shadow:\{color_revision(style.color)}:\{style.offset.x}:\{style.offset.y}:\{style.blur_radius}:\{style.spread}"
    BorderModifier(style) =>
      "border:\{brush_revision(style.brush)}:\{style.width}"
    OffsetModifier(dx, dy) => "offset:\{dx}:\{dy}"
    ClipModifier => "clip"
    ScaleModifier(sx, sy) => "scale:\{sx}:\{sy}"
    DisabledModifier(disabled) => "disabled:\{disabled}"
    AccessibilityLabelModifier(label) => "accessibility-label:\{label}"
    SemanticsRoleModifier(role) => "semantics-role:\{role_label(role)}"
    SemanticsLevelModifier(level) => "semantics-level:\{level}"
    SemanticsUrlModifier(url) => "semantics-url:\{url}"
    SemanticsSelectedModifier(selected) => "semantics-selected:\{selected}"
    SemanticsPressedModifier(pressed) => "semantics-pressed:\{pressed}"
    SemanticsCheckedModifier(checked) => "semantics-checked:\{checked}"
    SemanticsExpandedModifier(expanded) => "semantics-expanded:\{expanded}"
    SemanticsInvalidModifier(invalid) => "semantics-invalid:\{invalid}"
    SemanticsRequiredModifier(required) => "semantics-required:\{required}"
    SemanticsDescriptionModifier(description) =>
      "semantics-description:\{description}"
    SemanticsActionModifier(action) =>
      "semantics-action:\{action_label(action)}"
    FocusableModifier(focusable) => "focusable:\{focusable}"
    FocusTrapModifier(enabled) => "focus-trap:\{enabled}"
    OnTapMessageModifier(_) => "on-tap"
    OnLongPressMessageModifier(_) => "on-long-press"
    OnDoubleTapMessageModifier(_) => "on-double-tap"
    OnDragMessageModifier(_) => "on-drag"
    OnDragWithFrameMessageModifier(_) => "on-drag-with-frame"
    OnFileDropMessageModifier(_) => "on-file-drop"
    KeyboardShortcutModifier(shortcut) =>
      "keyboard-shortcut:\{shortcut.key}:\{shortcut.modifiers.meta}:\{shortcut.modifiers.control}:\{shortcut.modifiers.alt}:\{shortcut.modifiers.shift}"
    FlexibleModifier(weight) => "flexible:\{weight}"
    LayoutPriorityModifier(priority) => "layout-priority:\{priority}"
    AlignModifier(alignment) => "align:\{alignment.x}:\{alignment.y}"
    SpacingModifier(spacing) => "spacing:\{spacing}"
    MainAxisAlignmentModifier(alignment) =>
      "main-axis-alignment:\{main_axis_alignment_label(alignment)}"
    CrossAxisAlignmentModifier(alignment) =>
      "cross-axis-alignment:\{cross_axis_alignment_label(alignment)}"
    ThemeModifier(theme) => theme.revision_fingerprint()
    EnvironmentModifier(env) => env.revision_fingerprint()
    AspectRatioModifier(ratio) => "aspect-ratio:\{ratio}"
    IntrinsicWidthModifier => "intrinsic-width"
    IntrinsicHeightModifier => "intrinsic-height"
    RepaintBoundaryModifier => "repaint-boundary"
  }
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
        platform_views: [],
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
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    ScaleModifier(sx, sy) =>
      {
        commands: [DrawCommand::PushTransform(Transform2D::scale(sx~, sy~))],
        child_layers: [],
        post_commands: [DrawCommand::PopTransform],
        overlay_commands: [],
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    DisabledModifier(true) =>
      {
        commands: [DrawCommand::PushOpacity(0.42)],
        child_layers: [],
        post_commands: [DrawCommand::PopOpacity],
        overlay_commands: [],
        platform_views: [],
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
      let current = view_state_to_button_state(ctx.state)
      let tap = recognize_button_tap(current, inside, event.phase)
      let next_state = button_state_to_view_state(ctx.state, tap.next_state)
      let changed = next_state != ctx.state || tap.activated
      {
        changed,
        activated: tap.activated,
        focused: false,
        captured: inside || current == ButtonState::Pressed,
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
      let result = DragGestureState::new().update(
        event,
        inside=ctx.frame.contains(event.position),
      )
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
            state: None,
            text_control: None,
            dirty: ViewDirtyHint::ViewPaintDirty,
            messages: [handler(drag_event, frame)],
          }
        }
        None => ViewEventResult::ignored()
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
    SemanticsRoleModifier(role) => ViewSemanticsInfo::new(role~)
    SemanticsLevelModifier(level) => ViewSemanticsInfo::new(level~)
    SemanticsUrlModifier(url) => ViewSemanticsInfo::new(url~)
    DisabledModifier(disabled) => ViewSemanticsInfo::new(disabled~)
    FocusableModifier(focusable) =>
      ViewSemanticsInfo::new(actions=if focusable { [Focus] } else { [] })
    OnTapMessageModifier(_)
    | OnLongPressMessageModifier(_)
    | OnDoubleTapMessageModifier(_)
    | OnDragMessageModifier(_)
    | OnDragWithFrameMessageModifier(_)
    | KeyboardShortcutModifier(_) =>
      ViewSemanticsInfo::new(role=SemanticsRole::Button, actions=[
        Focus,
        Activate,
      ])
    SemanticsSelectedModifier(selected) =>
      ViewSemanticsInfo::new(selected~, actions=[SemanticsAction::Select])
    SemanticsPressedModifier(pressed) => ViewSemanticsInfo::new(pressed~)
    SemanticsCheckedModifier(checked) => ViewSemanticsInfo::new(checked~)
    SemanticsExpandedModifier(expanded) =>
      ViewSemanticsInfo::new(
        expanded~,
        actions=if expanded {
          [SemanticsAction::Collapse]
        } else {
          [SemanticsAction::Expand]
        },
      )
    SemanticsInvalidModifier(invalid) => ViewSemanticsInfo::new(invalid~)
    SemanticsRequiredModifier(required) => ViewSemanticsInfo::new(required~)
    SemanticsDescriptionModifier(description) =>
      ViewSemanticsInfo::new(description~)
    SemanticsActionModifier(action) => ViewSemanticsInfo::new(actions=[action])
    _ => ViewSemanticsInfo::new()
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
fn view_state_to_button_state(state : ViewStateContext) -> ButtonState {
  if state.pressed {
    ButtonState::Pressed
  } else if state.hovered {
    ButtonState::Hovered
  } else {
    ButtonState::Normal
  }
}

///|
fn button_state_to_view_state(
  state : ViewStateContext,
  button_state : ButtonState,
) -> ViewStateContext {
  match button_state {
    ButtonState::Normal => { ..state, hovered: false, pressed: false }
    ButtonState::Hovered => { ..state, hovered: true, pressed: false }
    ButtonState::Pressed => { ..state, hovered: true, pressed: true }
  }
}
