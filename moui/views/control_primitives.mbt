///|
fn[Msg] button_control(
  text~ : String,
  size~ : @core.Size,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  hovered_background~ : @core.Brush,
  pressed_background~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  shadow? : @core.ShadowStyle? = None,
  corner_radius? : Double = 0.0,
  on_click? : Msg? = None,
  kind? : String = "Button",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "button:\{text}:\{view_size_revision(size)}:\{view_font_revision(font)}:\{view_color_revision(foreground)}:\{view_brush_revision(background)}:\{view_brush_revision(hovered_background)}:\{view_brush_revision(pressed_background)}:\{view_border_option_revision(border)}:\{view_shadow_option_revision(shadow)}:\{corner_radius}:\{on_click is Some(_)}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      let background = view_button_background(
        ctx.state,
        background,
        hovered_background,
        pressed_background,
      )
      let commands : Array[@core.DrawCommand] = []
      let rounded = @core.RoundedRect::new(rect=ctx.frame, radius=corner_radius)
      match shadow {
        Some(shadow) =>
          commands.push(
            @core.DrawCommand::DrawShadow(
              @core.ShadowSpec::new(
                rect=rounded,
                color=shadow.color,
                offset=shadow.offset,
                blur_radius=shadow.blur_radius,
                spread=shadow.spread,
              ),
            ),
          )
        None => ()
      }
      commands.push(
        @core.DrawCommand::FillRoundedRectBrush(rounded, background),
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
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(text~, frame=ctx.frame, font~, color=foreground),
        ),
      )
      @core.ViewPaintPlan::commands(commands)
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
                state=Some(view_button_state_context(ctx.state, next)),
                dirty=@core.ViewDirtyHint::ViewPaintDirty,
                messages=[message],
              )
            (true, None) =>
              view_event_result(
                changed~,
                activated=false,
                captured=true,
                state=Some(view_button_state_context(ctx.state, next)),
                dirty=@core.ViewDirtyHint::ViewPaintDirty,
              )
            (false, _) =>
              view_event_result(
                changed~,
                captured=inside || changed,
                state=if changed {
                  Some(view_button_state_context(ctx.state, next))
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
  next : @core.ButtonState,
) -> @core.ViewStateContext {
  {
    ..current,
    hovered: next == @core.ButtonState::Hovered,
    pressed: next == @core.ButtonState::Pressed,
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
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          checkbox_intrinsic_size(label, font, size),
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
fn checkbox_intrinsic_size(
  label : String,
  font : @core.FontSpec,
  size : @core.Size,
) -> @core.Size {
  let spacing = 8.0
  let label_width = view_text_length(label).to_double() * font.size * 0.58
  @core.Size::new(
    width=size.width + spacing + label_width,
    height=view_max_double(size.height, font.size * 1.25),
  )
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
