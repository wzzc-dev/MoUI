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
  height? : Double = 32.0,
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
fn resolve_choice_font(
  font : @core.FontSpec?,
  theme : @core.Theme,
) -> @core.FontSpec {
  match font {
    Some(value) => value
    None => theme.typography.control
  }
}

///|
fn resolve_control_double(value : Double?, fallback : Double) -> Double {
  match value {
    Some(resolved) => resolved
    None => fallback
  }
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
  height? : Double = 32.0,
  kind? : String = "Checkbox",
  key? : String? = None,
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
          @core.ViewSemanticsActionResult::accepted(
            dirty=@core.ViewDirtyHint::ViewBuildDirty,
            messages=[checked.changed(next)],
          )
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
impl @core.ViewNode for Checkbox with fn declaration(self) {
  @common.view_declaration_auto(
    "Checkbox",
    self.theme,
    [
      ("label", @core.DeclarationKey::string(self.label)),
      ("font", @common.view_font_option_key(self.font)),
      ("box_size", @common.view_double_option_key(self.box_size)),
      ("height", @core.DeclarationKey::double(self.height)),
    ],
    [
      ("checked", @core.DeclarationKey::bool(self.checked)),
      (
        "foreground",
        @core.DeclarationKey::option(
          self.foreground.map(@common.view_color_key),
        ),
      ),
      (
        "check_color",
        @core.DeclarationKey::option(
          self.check_color.map(@common.view_color_key),
        ),
      ),
      (
        "box_shape",
        @core.DeclarationKey::option(
          self.box_shape.map(value => {
            @core.DeclarationKey::int(
              match value {
                @style.ChoiceControlShape::Square => 0
                @style.ChoiceControlShape::Circle => 1
              },
            )
          }),
        ),
      ),
      (
        "check_style",
        @core.DeclarationKey::option(
          self.check_style.map(value => {
            @core.DeclarationKey::int(
              match value {
                @style.CheckMarkStyle::Checkmark => 0
                @style.CheckMarkStyle::Dot => 1
              },
            )
          }),
        ),
      ),
    ],
    [
      ("label", @core.DeclarationKey::string(self.label)),
      ("checked", @core.DeclarationKey::bool(self.checked)),
    ],
  )
}

///|
impl @core.ViewNode for Checkbox with fn layout(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let cc = @style.views_ambient_control_theme(resolved_theme).choice_control
  let resolved_font = resolve_choice_font(self.font, resolved_theme)
  let resolved_box_size = resolve_control_double(self.box_size, cc.control_size)
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
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let cc = @style.views_ambient_control_theme(resolved_theme).choice_control
  let resolved_font = resolve_choice_font(self.font, resolved_theme)
  let resolved_foreground = @common.resolve_control_color(
    self.foreground,
    cc.foreground,
  )
  let resolved_check_color = @common.resolve_control_color(
    self.check_color,
    cc.selected_color,
  )
  let resolved_box_size = resolve_control_double(self.box_size, cc.control_size)
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
  )
  @core.ViewPaintPlan::commands(commands)
}

///|
impl @core.ViewNode for Checkbox with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Checkbox,
    label=self.label,
    value=if self.checked { "true" } else { "false" },
    checked=if self.checked {
      @core.SemanticsCheckedState::Checked
    } else {
      @core.SemanticsCheckedState::Unchecked
    },
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
    @core.AppEvent::Pointer(event) =>
      if event.phase == @core.PointerPhase::Up &&
        ctx.frame.contains(event.position) {
        let next = !checked.value()
        @common.view_event_result(
          changed=true,
          activated=true,
          captured=true,
          dirty=@core.ViewDirtyHint::ViewBuildDirty,
          messages=[checked.changed(next)],
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    @core.AppEvent::Keyboard(event) =>
      if event.pressed &&
        (event.key == "Enter" || event.key == "Space" || event.key == " ") {
        let next = !checked.value()
        @common.view_event_result(
          changed=true,
          activated=true,
          captured=true,
          dirty=@core.ViewDirtyHint::ViewBuildDirty,
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
) -> Unit {
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
    @style.ChoiceControlShape::Circle => box_side / 2.0
    @style.ChoiceControlShape::Square => theme.radius_scale.sm
  }
  let box = @core.RoundedRect::new(rect=box_rect, radius=box_radius)
  if checked {
    match check_style {
      @style.CheckMarkStyle::Checkmark => {
        commands.push(@core.DrawCommand::FillRoundedRect(box, check_color))
        commands.push(
          @core.DrawCommand::DrawText(
            @core.TextRun::new(
              text="✓",
              frame=box_rect,
              font=@core.FontSpec::new(size=box_side * 0.78, weight=700),
              color=theme.palette.on_primary,
            ),
          ),
        )
      }
      @style.CheckMarkStyle::Dot => {
        commands.push(
          @core.DrawCommand::StrokeRoundedRect(box, check_color, 2.0),
        )
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
        commands.push(@core.DrawCommand::FillRoundedRect(inner, check_color))
      }
    }
  } else {
    let outline = if focused { check_color } else { theme.palette.outline }
    commands.push(@core.DrawCommand::StrokeRoundedRect(box, outline, 2.0))
  }
  commands.push(
    @core.DrawCommand::DrawText(
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
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
}
