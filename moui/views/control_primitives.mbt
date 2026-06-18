///|
fn[Msg] button_control(
  text~ : String,
  min_size~ : @core.Size,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  hovered_background~ : @core.Brush,
  pressed_background~ : @core.Brush,
  padding_horizontal~ : Double,
  padding_vertical~ : Double,
  transition_duration_ms~ : Double,
  transition_easing~ : @core.Easing,
  border? : @core.BorderStyle? = None,
  shadow? : @core.ShadowStyle? = None,
  corner_radius? : Double = 0.0,
  leading_icon? : IconName? = None,
  on_click? : Msg? = None,
  kind? : String = "Button",
  key? : String? = None,
) -> @core.View[Msg] {
  let icon_size = font.size
  let icon_gap = padding_horizontal * 0.5
  let icon_block_width = match leading_icon {
    Some(_) => icon_size + icon_gap
    None => 0.0
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "button:\{text}:\{view_size_revision(min_size)}:\{view_font_revision(font)}:\{view_color_revision(foreground)}:\{view_brush_revision(background)}:\{view_brush_revision(hovered_background)}:\{view_brush_revision(pressed_background)}:\{view_border_option_revision(border)}:\{view_shadow_option_revision(shadow)}:\{corner_radius}:\{padding_horizontal}:\{padding_vertical}:\{icon_block_width}:\{on_click is Some(_)}"
    },
    layout=ctx => {
      // Content-driven sizing: measure the label with the real text system,
      // then pad it and floor it at the supplied minimum size. When a leading
      // icon is present, reserve its square plus a small gap before the label.
      // Constraints still clamp the result so parents can force a fixed frame.
      let measured = ctx.text_system.measure_text(
        @core.TextLayoutInput::new(text~, font~),
      )
      let content_width = view_max_double(
        min_size.width,
        icon_block_width +
        measured.size.width +
        padding_horizontal * 2.0,
      )
      let content_height = view_max_double(
        min_size.height,
        measured.size.height + padding_vertical * 2.0,
      )
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=content_width, height=content_height),
        ),
      )
    },
    paint=ctx => {
      let current_state = if ctx.state.pressed {
        @core.ButtonState::Pressed
      } else if ctx.state.hovered {
        @core.ButtonState::Hovered
      } else {
        @core.ButtonState::Normal
      }
      // Resolve the transition progress from the scratch-recorded start time
      // and the current animation clock. When reduced motion is requested or
      // the transition has completed, snap to the terminal color; otherwise
      // interpolate the background color between the previous visual state and
      // the current one so hover/press ease in instead of hard-cutting.
      let transition = parse_button_transition(ctx.state.scratch)
      let (background_brush, animating) = match transition {
        Some((from_state, start_ms)) => {
          if ctx.environment.reduced_motion ||
            transition_duration_ms <= 0.0 ||
            ctx.now_ms <= 0.0 {
            (button_state_brush(current_state, background, hovered_background, pressed_background), false)
          } else {
            let start = start_ms.to_double()
            let raw_progress = (ctx.now_ms - start) / transition_duration_ms
            if raw_progress >= 1.0 {
              (button_state_brush(current_state, background, hovered_background, pressed_background), false)
            } else if raw_progress <= 0.0 {
              (button_state_brush(from_state, background, hovered_background, pressed_background), true)
            } else {
              let from_color = button_state_color(
                button_state_brush(
                  from_state,
                  background,
                  hovered_background,
                  pressed_background,
                ),
              )
              let to_color = button_state_color(
                button_state_brush(
                  current_state,
                  background,
                  hovered_background,
                  pressed_background,
                ),
              )
              let blended = @core.animated_color(
                from=from_color,
                to=to_color,
                progress=raw_progress,
                easing=transition_easing,
              )
              (@core.Brush::solid(blended), true)
            }
          }
        }
        None =>
          (button_state_brush(current_state, background, hovered_background, pressed_background), false)
      }
      let commands : Array[@core.DrawCommand] = []
      let rounded = @core.RoundedRect::new(rect=ctx.frame, radius=corner_radius)
      emit_elevation_shadow(commands, rounded, shadow, ctx.environment.color_scheme)
      commands.push(
        @core.DrawCommand::FillRoundedRectBrush(rounded, background_brush),
      )
      match border {
        Some(border) =>
          if border.width > 0.0 {
            commands.push(
              @core.DrawCommand::StrokeRoundedRectBrush(
                rounded,
                border.brush,
                border.width,
              ),
            )
          }
        None => ()
      }
      // Lay out the leading icon (vertically centered) and offset the text
      // frame to the right of it so the label stays centered in the remainder.
      let text_origin_x = ctx.frame.origin.x + padding_horizontal + icon_block_width
      let text_frame = @core.Rect::new(
        x=text_origin_x,
        y=ctx.frame.origin.y,
        width=view_max_double(0.0, ctx.frame.size.width - padding_horizontal - icon_block_width - padding_horizontal),
        height=ctx.frame.size.height,
      )
      match leading_icon {
        Some(name) => {
          let icon_origin_x = ctx.frame.origin.x + padding_horizontal
          let icon_origin_y = ctx.frame.origin.y + (ctx.frame.size.height - icon_size) / 2.0
          let scale = icon_size / 24.0
          let scaled = icon_scale_verbs(
            icon_path(name),
            icon_origin_x,
            icon_origin_y,
            scale,
          )
          commands.push(
            @core.DrawCommand::DrawPath(
              @core.PathSpec::new(
                verbs=scaled,
                stroke=Some(@core.Brush::solid(foreground)),
                stroke_width=1.6,
              ),
            ),
          )
        }
        None => ()
      }
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(text~, frame=text_frame, font~, color=foreground),
        ),
      )
      if animating {
        @core.ViewPaintPlan::animating_commands(commands)
      } else {
        @core.ViewPaintPlan::commands(commands)
      }
    },
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) => {
          let inside = ctx.frame.contains(event.position)
          let current = if ctx.state.pressed {
            @core.ButtonState::Pressed
          } else if ctx.state.hovered {
            @core.ButtonState::Hovered
          } else {
            @core.ButtonState::Normal
          }
          let next = view_button_next_state(current, inside, event.phase)
          let activated = event.phase == @core.PointerPhase::Up &&
            inside &&
            current == @core.ButtonState::Pressed
          let changed = next != current || activated
          match (activated, on_click) {
            (true, Some(message)) =>
              view_event_result(
                changed~,
                activated=true,
                captured=true,
                state=Some(
                  view_button_state_context(ctx.state, current, next, ctx.now_ms),
                ),
                dirty=@core.ViewDirtyHint::ViewPaintDirty,
                messages=[message],
              )
            (true, None) =>
              view_event_result(
                changed~,
                activated=false,
                captured=true,
                state=Some(
                  view_button_state_context(ctx.state, current, next, ctx.now_ms),
                ),
                dirty=@core.ViewDirtyHint::ViewPaintDirty,
              )
            (false, _) =>
              view_event_result(
                changed~,
                captured=inside || changed,
                state=if changed {
                  Some(
                    view_button_state_context(ctx.state, current, next, ctx.now_ms),
                  )
                } else {
                  None
                },
                dirty=if changed {
                  @core.ViewDirtyHint::ViewPaintDirty
                } else {
                  @core.ViewDirtyHint::ViewClean
                },
              )
          }
        }
        @core.AppEvent::Keyboard(event) =>
          if event.pressed &&
            (event.key == "Enter" || event.key == "Space" || event.key == " ") {
            match on_click {
              Some(message) =>
                view_event_result(
                  changed=true,
                  activated=true,
                  captured=true,
                  dirty=@core.ViewDirtyHint::ViewPaintDirty,
                  messages=[message],
                )
              None =>
                view_event_result(
                  changed=true,
                  captured=true,
                  dirty=@core.ViewDirtyHint::ViewPaintDirty,
                )
            }
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Button,
        label=text,
        actions=[@core.SemanticsAction::Focus, @core.SemanticsAction::Activate],
      )
    },
    focusable=() => true,
  )
}

///|
fn view_button_state_context(
  current : @core.ViewStateContext,
  from_state : @core.ButtonState,
  next : @core.ButtonState,
  now_ms : Double,
) -> @core.ViewStateContext {
  // Record the transition origin and start time in scratch so the next paint
  // can interpolate the background from `from_state` toward `next`. When the
  // state did not actually change (e.g. a no-op move), keep the prior scratch
  // so an in-flight animation continues instead of restarting.
  let scratch = if from_state == next {
    current.scratch
  } else {
    button_transition_scratch(from_state, now_ms)
  }
  {
    ..current,
    hovered: next == @core.ButtonState::Hovered,
    pressed: next == @core.ButtonState::Pressed,
    scratch,
  }
}

///|
fn[Msg] checkbox_control(
  label~ : String,
  checked~ : @core.Binding[Bool],
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  check_color~ : @core.Color,
  size~ : @core.Size,
  on_change? : ((Bool) -> Msg)? = None,
  kind? : String = "Checkbox",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "checkbox:\{label}:\{checked.get()}:\{view_font_revision(font)}:\{view_color_revision(foreground)}:\{view_color_revision(check_color)}:\{view_size_revision(size)}:\{on_change is Some(_)}"
    },
    layout=ctx => {
      // Measure the label with the real text system instead of the old
      // `char_count * font.size * 0.58` estimate, so checkbox intrinsic
      // width tracks the actual font instead of drifting across scripts.
      let label_width = if label.length() == 0 {
        0.0
      } else {
        let measured = ctx.text_system.measure_text(
          @core.TextLayoutInput::new(text=label, font=font),
        )
        measured.size.width
      }
      let spacing = 8.0
      let intrinsic_width = size.width + spacing + label_width
      let intrinsic_height = view_max_double(size.height, font.size * 1.25)
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=intrinsic_width, height=intrinsic_height),
        ),
      )
    },
    paint=ctx => {
      let commands : Array[@core.DrawCommand] = []
      append_checkbox_commands(
        commands,
        label~,
        checked=checked.get(),
        font~,
        foreground~,
        check_color~,
        size~,
        frame=ctx.frame,
      )
      @core.ViewPaintPlan::commands(commands)
    },
    event=ctx => {
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          if event.phase == @core.PointerPhase::Up &&
            ctx.frame.contains(event.position) {
            let next = !checked.get()
            checked.set(next)
            view_event_result(
              changed=true,
              activated=true,
              captured=true,
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
              messages=checkbox_messages(on_change, next),
            )
          } else {
            @core.ViewEventResult::ignored()
          }
        @core.AppEvent::Keyboard(event) =>
          if event.pressed &&
            (event.key == "Enter" || event.key == "Space" || event.key == " ") {
            let next = !checked.get()
            checked.set(next)
            view_event_result(
              changed=true,
              activated=true,
              captured=true,
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
              messages=checkbox_messages(on_change, next),
            )
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Checkbox,
        label~,
        value=if checked.get() { "true" } else { "false" },
        checked=checked.get(),
        actions=[@core.SemanticsAction::Focus, @core.SemanticsAction::Activate],
      )
    },
    focusable=() => true,
  )
}

///|
fn[Msg] checkbox_messages(
  on_change : ((Bool) -> Msg)?,
  checked : Bool,
) -> Array[Msg] {
  match on_change {
    Some(handler) => [handler(checked)]
    None => []
  }
}

///|
fn append_checkbox_commands(
  commands : Array[@core.DrawCommand],
  label~ : String,
  checked~ : Bool,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  check_color~ : @core.Color,
  size~ : @core.Size,
  frame~ : @core.Rect,
) -> Unit {
  let box_side = size.width
  let box_y = frame.origin.y +
    view_max_double(0.0, (frame.size.height - box_side) / 2.0)
  let box_rect = @core.Rect::new(
    x=frame.origin.x,
    y=box_y,
    width=box_side,
    height=box_side,
  )
  let box = @core.RoundedRect::new(rect=box_rect, radius=4.0)
  if checked {
    commands.push(@core.DrawCommand::FillRoundedRect(box, check_color))
    commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text="✓",
          frame=box_rect,
          font=@core.FontSpec::new(size=box_side * 0.78, weight=700),
          color=@core.Color::white(),
        ),
      ),
    )
  } else {
    commands.push(@core.DrawCommand::StrokeRoundedRect(box, check_color, 2.0))
  }
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=label,
        frame=@core.Rect::new(
          x=frame.origin.x + box_side + 8.0,
          y=frame.origin.y,
          width=view_max_double(0.0, frame.size.width - box_side - 8.0),
          height=frame.size.height,
        ),
        font~,
        color=foreground,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
}
