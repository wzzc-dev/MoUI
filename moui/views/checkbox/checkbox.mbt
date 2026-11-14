///|
pub fn[Msg] checkbox(
  label : String,
  checked~ : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme,
  font? : @core.FontSpec,
  foreground? : @core.Color,
  check_color? : @core.Color,
  box_size? : Double,
  box_shape? : @style.ChoiceControlShape,
  check_style? : @style.CheckMarkStyle,
  height~ : Double = 32.0,
) -> @core.View[Msg] {
  checkbox_control(
    label~,
    checked=@core.ControlledValue::new(value=checked, changed=on_change),
    theme?,
    font?,
    foreground?,
    check_color?,
    box_size?,
    box_shape?,
    check_style?,
    height~,
  )
}

///|
pub fn[Msg] checkbox_control(
  label~ : String,
  checked~ : @core.ControlledValue[Bool, Msg],
  theme? : @core.Theme,
  font? : @core.FontSpec,
  foreground? : @core.Color,
  check_color? : @core.Color,
  box_size? : Double,
  box_shape? : @style.ChoiceControlShape,
  check_style? : @style.CheckMarkStyle,
  height~ : Double = 32.0,
  kind~ : String = "Checkbox",
  key~ : String? = None,
) -> @core.View[Msg] {
  let checked_snapshot = checked.value()
  @core.View::from_node(
    Checkbox::{
      label,
      checked: checked_snapshot,
      theme,
      font,
      foreground,
      check_color,
      box_size,
      box_shape,
      check_style,
      height,
      kind,
      key,
    },
    event=(node, ctx) => checkbox_event(node, ctx, checked),
    semantics_actions=_node => {
      [
        @core.ViewSemanticsActionHandler::activate(_ctx => {
          let next = !checked.value()
          @core.ViewSemanticsActionResult::accepted(dirty=ViewBuildDirty, messages=[
            checked.changed(next),
          ])
        }),
      ]
    },
  )
}

///|
priv struct Checkbox {
  label : String
  checked : Bool
  theme : @core.Theme?
  font : @core.FontSpec?
  foreground : @core.Color?
  check_color : @core.Color?
  box_size : Double?
  box_shape : @style.ChoiceControlShape?
  check_style : @style.CheckMarkStyle?
  height : Double
  kind : String
  key : String?
}

///|
impl @core.ViewNode for Checkbox with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for Checkbox with fn layout(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let cc = @style.views_ambient_control_theme(resolved_theme).choice_control
  let resolved_font = self.font.unwrap_or(resolved_theme.typography.control)
  let resolved_box_size = self.box_size.unwrap_or(cc.control_size)
  let label_width = if self.label.length() == 0 {
    0.0
  } else {
    let measured = ctx.text_system.measure_text(
      @core.TextLayoutInput::new(text=self.label, font=resolved_font),
    )
    measured.size.width
  }
  let intrinsic_width = resolved_box_size + 8.0 + label_width
  let intrinsic_height = @common.view_max_double(
    self.height,
    resolved_font.size * 1.25,
  )
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=intrinsic_width, height=intrinsic_height),
    ),
  )
}

///|
impl @core.ViewNode for Checkbox with fn paint(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let cc = @style.views_ambient_control_theme(resolved_theme).choice_control
  let resolved_font = self.font.unwrap_or(resolved_theme.typography.control)
  let resolved_foreground = self.foreground.unwrap_or(cc.foreground)
  let resolved_check_color = self.check_color.unwrap_or(cc.selected_color)
  let resolved_box_size = self.box_size.unwrap_or(cc.control_size)
  let disabled = ctx.state.disabled || !ctx.environment.enabled
  let transparent = @core.Color::transparent()
  let (state_overlay, animating) = if disabled {
    (transparent, false)
  } else {
    @common.pressable_transition_color(
      ctx,
      control="checkbox",
      normal=transparent,
      hovered=resolved_foreground.multiply_alpha(0.06),
      pressed=resolved_foreground.multiply_alpha(0.10),
    )
  }
  let commands : Array[@core.DrawCommand] = []
  append_checkbox_commands(
    commands,
    label=self.label,
    checked=self.checked,
    font=resolved_font,
    foreground=resolved_foreground,
    check_color=resolved_check_color,
    size=@core.Size::new(width=resolved_box_size, height=resolved_box_size),
    box_shape=self.box_shape.unwrap_or(cc.box_shape),
    check_style=self.check_style.unwrap_or(cc.check_style),
    frame=ctx.frame,
    theme=resolved_theme,
    focused=ctx.focused,
    state_overlay~,
    disabled~,
  )
  if animating {
    @core.ViewPaintPlan::animating_commands(commands)
  } else {
    @core.ViewPaintPlan::commands(commands)
  }
}

///|
impl @core.ViewNode for Checkbox with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(
    role=Checkbox,
    label=self.label,
    value=if self.checked { "true" } else { "false" },
    checked=if self.checked { Checked } else { Unchecked },
  )
}

///|
impl @core.ViewNode for Checkbox with fn focusable(_self) {
  true
}

///|
fn[Msg] checkbox_event(
  _node : Checkbox,
  ctx : @core.ViewEventContext,
  checked : @core.ControlledValue[Bool, Msg],
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) =>
      if event.phase == Up && ctx.frame.contains(event.position) {
        let next = !checked.value()
        @common.view_event_result(
          changed=true,
          activated=true,
          captured=true,
          dirty=ViewBuildDirty,
          messages=[checked.changed(next)],
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    Keyboard(event) =>
      if event.pressed &&
        (event.key == "Enter" || event.key == "Space" || event.key == " ") {
        let next = !checked.value()
        @common.view_event_result(
          changed=true,
          activated=true,
          captured=true,
          dirty=ViewBuildDirty,
          messages=[checked.changed(next)],
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    _ => @core.ViewEventResult::ignored()
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
  box_shape~ : @style.ChoiceControlShape,
  check_style~ : @style.CheckMarkStyle,
  frame~ : @core.Rect,
  theme~ : @core.Theme,
  focused~ : Bool,
  state_overlay~ : @core.Color,
  disabled~ : Bool,
) -> Unit {
  let foreground = if disabled {
    foreground.multiply_alpha(0.38)
  } else {
    foreground
  }
  let check_color = if disabled {
    check_color.multiply_alpha(0.42)
  } else {
    check_color
  }
  // Interaction layer behind the whole row: the box itself is too small for a
  // visible hover without changing its geometry. The color is pre-blended by
  // the caller so hover/press transitions animate here.
  if state_overlay.a > 0.0 {
    commands.push(
      FillRoundedRect(
        @core.RoundedRect::new(rect=frame, radius=theme.radius_scale.sm),
        state_overlay,
      ),
    )
  }
  let box_side = size.width
  let box_y = frame.origin.y +
    @common.view_max_double(0.0, (frame.size.height - box_side) / 2.0)
  let box_rect = @core.Rect::new(
    x=frame.origin.x,
    y=box_y,
    width=box_side,
    height=box_side,
  )
  let box_radius = match box_shape {
    Circle => box_side / 2.0
    Square => theme.radius_scale.sm
  }
  let box = @core.RoundedRect::new(rect=box_rect, radius=box_radius)
  if focused && !disabled {
    commands.push(
      StrokeRoundedRect(
        @core.RoundedRect::new(
          rect=@core.Rect::new(
            x=box_rect.origin.x - 3.0,
            y=box_rect.origin.y - 3.0,
            width=box_side + 6.0,
            height=box_side + 6.0,
          ),
          radius=box_radius + 3.0,
        ),
        theme.palette.focus,
        2.0,
      ),
    )
  }
  if checked {
    match check_style {
      Checkmark => {
        commands.push(FillRoundedRect(box, check_color))
        commands.push(
          DrawText(
            @core.TextRun::new(
              text="✓",
              frame=box_rect,
              font=@core.FontSpec::new(size=box_side * 0.78, weight=700),
              color=if disabled {
                theme.palette.on_primary.multiply_alpha(0.6)
              } else {
                theme.palette.on_primary
              },
            ),
          ),
        )
      }
      Dot => {
        commands.push(StrokeRoundedRect(box, check_color, 2.0))
        let inner_side = box_side * 0.5
        let inner_rect = @core.Rect::new(
          x=box_rect.origin.x + (box_side - inner_side) / 2.0,
          y=box_rect.origin.y + (box_side - inner_side) / 2.0,
          width=inner_side,
          height=inner_side,
        )
        let inner = @core.RoundedRect::new(
          rect=inner_rect,
          radius=inner_side / 2.0,
        )
        commands.push(FillRoundedRect(inner, check_color))
      }
    }
  } else {
    let outline = if disabled {
      theme.palette.muted
    } else if focused {
      check_color
    } else {
      theme.palette.outline
    }
    commands.push(StrokeRoundedRect(box, outline, 2.0))
  }
  commands.push(
    DrawText(
      @core.TextRun::new(
        text=label,
        frame=@core.Rect::new(
          x=frame.origin.x + box_side + 8.0,
          y=frame.origin.y,
          width=@common.view_max_double(0.0, frame.size.width - box_side - 8.0),
          height=frame.size.height,
        ),
        font~,
        color=foreground,
        align=TextStart,
      ),
    ),
  )
}
