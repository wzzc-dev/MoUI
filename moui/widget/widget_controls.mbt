///|
pub fn[Msg] button(
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
  @core.View::widget(
    @core.WidgetOps::new(
      identity=() => @core.WidgetIdentity::new(kind~, key~),
      revision=() => {
        "button:\{text}:\{widget_size_revision(size)}:\{widget_font_revision(font)}:\{widget_color_revision(foreground)}:\{widget_brush_revision(background)}:\{widget_brush_revision(hovered_background)}:\{widget_brush_revision(pressed_background)}:\{widget_border_option_revision(border)}:\{widget_shadow_option_revision(shadow)}:\{corner_radius}:\{on_click is Some(_)}"
      },
      layout=ctx => {
        @core.WidgetLayoutResult::new(size=ctx.constraints.constrain(size))
      },
      paint=ctx => {
        let background = widget_button_background(
          ctx.state,
          background,
          hovered_background,
          pressed_background,
        )
        let commands : Array[@core.DrawCommand] = []
        let rounded = @core.RoundedRect::new(
          rect=ctx.frame,
          radius=corner_radius,
        )
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
        @core.WidgetPaintPlan::commands(commands)
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
            let next = widget_button_next_state(current, inside, event.phase)
            let activated = event.phase == @core.PointerPhase::Up &&
              inside &&
              current == @core.ButtonState::Pressed
            let changed = next != current || activated
            match (activated, on_click) {
              (true, Some(message)) =>
                widget_event_result(
                  changed~,
                  activated=true,
                  captured=true,
                  state=Some(widget_button_state_context(ctx.state, next)),
                  dirty=@core.WidgetDirtyHint::WidgetPaintDirty,
                  messages=[message],
                )
              (true, None) =>
                widget_event_result(
                  changed~,
                  activated=false,
                  captured=true,
                  state=Some(widget_button_state_context(ctx.state, next)),
                  dirty=@core.WidgetDirtyHint::WidgetPaintDirty,
                )
              (false, _) =>
                widget_event_result(
                  changed~,
                  captured=inside || changed,
                  state=if changed {
                    Some(widget_button_state_context(ctx.state, next))
                  } else {
                    None
                  },
                  dirty=if changed {
                    @core.WidgetDirtyHint::WidgetPaintDirty
                  } else {
                    @core.WidgetDirtyHint::WidgetClean
                  },
                )
            }
          }
          @core.AppEvent::Keyboard(event) =>
            if event.pressed &&
              (event.key == "Enter" || event.key == "Space" || event.key == " ") {
              match on_click {
                Some(message) =>
                  widget_event_result(
                    changed=true,
                    activated=true,
                    captured=true,
                    dirty=@core.WidgetDirtyHint::WidgetPaintDirty,
                    messages=[message],
                  )
                None =>
                  widget_event_result(
                    changed=true,
                    captured=true,
                    dirty=@core.WidgetDirtyHint::WidgetPaintDirty,
                  )
              }
            } else {
              @core.WidgetEventResult::ignored()
            }
          _ => @core.WidgetEventResult::ignored()
        }
      },
      semantics=() => {
        @core.WidgetSemanticsInfo::new(
          role=@core.SemanticsRole::Button,
          label=text,
          actions=[
            @core.SemanticsAction::Focus,
            @core.SemanticsAction::Activate,
          ],
        )
      },
      focusable=() => true,
    ),
  )
}

///|
fn widget_button_state_context(
  current : @core.WidgetStateContext,
  next : @core.ButtonState,
) -> @core.WidgetStateContext {
  {
    ..current,
    hovered: next == @core.ButtonState::Hovered,
    pressed: next == @core.ButtonState::Pressed,
  }
}

///|
pub fn[Msg] checkbox(
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
  @core.View::widget(
    @core.WidgetOps::new(
      identity=() => @core.WidgetIdentity::new(kind~, key~),
      revision=() => {
        "checkbox:\{label}:\{checked.get()}:\{widget_font_revision(font)}:\{widget_color_revision(foreground)}:\{widget_color_revision(check_color)}:\{widget_size_revision(size)}:\{on_change is Some(_)}"
      },
      layout=ctx => {
        @core.WidgetLayoutResult::new(
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
        @core.WidgetPaintPlan::commands(commands)
      },
      event=ctx => {
        match ctx.event {
          @core.AppEvent::Pointer(event) =>
            if event.phase == @core.PointerPhase::Up &&
              ctx.frame.contains(event.position) {
              let next = !checked.get()
              checked.set(next)
              widget_event_result(
                changed=true,
                activated=true,
                captured=true,
                dirty=@core.WidgetDirtyHint::WidgetPaintDirty,
                messages=checkbox_messages(on_change, next),
              )
            } else {
              @core.WidgetEventResult::ignored()
            }
          @core.AppEvent::Keyboard(event) =>
            if event.pressed &&
              (event.key == "Enter" || event.key == "Space" || event.key == " ") {
              let next = !checked.get()
              checked.set(next)
              widget_event_result(
                changed=true,
                activated=true,
                captured=true,
                dirty=@core.WidgetDirtyHint::WidgetPaintDirty,
                messages=checkbox_messages(on_change, next),
              )
            } else {
              @core.WidgetEventResult::ignored()
            }
          _ => @core.WidgetEventResult::ignored()
        }
      },
      semantics=() => {
        @core.WidgetSemanticsInfo::new(
          role=@core.SemanticsRole::Checkbox,
          label~,
          value=if checked.get() { "true" } else { "false" },
          actions=[
            @core.SemanticsAction::Focus,
            @core.SemanticsAction::Activate,
          ],
        )
      },
      focusable=() => true,
    ),
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
  let label_width = widget_text_length(label).to_double() * font.size * 0.58
  @core.Size::new(
    width=size.width + spacing + label_width,
    height=widget_max_double(size.height, font.size * 1.25),
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
    widget_max_double(0.0, (frame.size.height - box_side) / 2.0)
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
          width=widget_max_double(0.0, frame.size.width - box_side - 8.0),
          height=frame.size.height,
        ),
        font~,
        color=foreground,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
}
