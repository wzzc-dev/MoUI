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
  box_shape? : @core.ChoiceControlShape,
  check_style? : @core.CheckMarkStyle,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  // Style is resolved ambient-ly inside checkbox_control (an explicit theme?
  // overrides ctx.environment.theme) so the checkbox tracks dark-mode / a11y
  // changes without the caller rebuilding the view tree.
  checkbox_control(
    label~,
    checked=@core.Binding::new(get=() => checked, set=_value => ()),
    theme?,
    font?,
    foreground?,
    check_color?,
    box_size?,
    box_shape?,
    check_style?,
    height~,
    on_change=Some(on_change),
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
fn[Msg] checkbox_control(
  label~ : String,
  checked~ : @core.Binding[Bool],
  theme? : @core.Theme,
  font? : @core.FontSpec,
  foreground? : @core.Color,
  check_color? : @core.Color,
  box_size? : Double,
  box_shape? : @core.ChoiceControlShape,
  check_style? : @core.CheckMarkStyle,
  height? : Double = 32.0,
  on_change? : ((Bool) -> Msg)? = None,
  kind? : String = "Checkbox",
  key? : String? = None,
) -> @core.View[Msg] {
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  @core.View::from_node(
    Checkbox::{
      label,
      checked,
      theme,
      font,
      foreground,
      check_color,
      box_size,
      box_shape,
      check_style,
      height,
      theme_revision,
      has_on_change: on_change is Some(_),
      kind,
      key,
    },
    event=(node, ctx) => checkbox_event(node, ctx, on_change),
  )
}

///|
priv struct Checkbox {
  label : String
  checked : @core.Binding[Bool]
  theme : @core.Theme?
  font : @core.FontSpec?
  foreground : @core.Color?
  check_color : @core.Color?
  box_size : Double?
  box_shape : @core.ChoiceControlShape?
  check_style : @core.CheckMarkStyle?
  height : Double
  theme_revision : String
  has_on_change : Bool
  kind : String
  key : String?
}

///|
impl @core.ViewNode for Checkbox with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for Checkbox with fn revision(self) {
  "checkbox:\{self.label}:\{self.checked.get()}:\{self.theme_revision}:\{self.font is Some(_)}:\{self.foreground is Some(_)}:\{self.check_color is Some(_)}:\{self.box_size is Some(_)}:\{self.box_shape is Some(_)}:\{self.check_style is Some(_)}:\{self.has_on_change}"
}

///|
impl @core.ViewNode for Checkbox with fn layout(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let style = ChoiceControlStyle::default(theme=resolved_theme)
  let resolved_font = resolve_choice_font(self.font, resolved_theme)
  let resolved_box_size = resolve_control_double(
    self.box_size,
    style.control_size,
  )
  let label_width = if self.label.length() == 0 {
    0.0
  } else {
    let measured = ctx.text_system.measure_text(
      @core.TextLayoutInput::new(text=self.label, font=resolved_font),
    )
    measured.size.width
  }
  let intrinsic_width = resolved_box_size + 8.0 + label_width
  let intrinsic_height = view_max_double(self.height, resolved_font.size * 1.25)
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=intrinsic_width, height=intrinsic_height),
    ),
  )
}

///|
impl @core.ViewNode for Checkbox with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let style = ChoiceControlStyle::default(theme=resolved_theme)
  let resolved_font = resolve_choice_font(self.font, resolved_theme)
  let resolved_foreground = resolve_control_color(
    self.foreground,
    style.foreground,
  )
  let resolved_check_color = resolve_control_color(
    self.check_color,
    style.selected_color,
  )
  let resolved_box_size = resolve_control_double(
    self.box_size,
    style.control_size,
  )
  let cc = resolved_theme.components.choice_control
  let commands : Array[@core.DrawCommand] = []
  append_checkbox_commands(
    commands,
    label=self.label,
    checked=self.checked.get(),
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
    role=@core.SemanticsRole::Checkbox,
    label=self.label,
    value=if self.checked.get() { "true" } else { "false" },
    checked=self.checked.get(),
    actions=[@core.SemanticsAction::Focus, @core.SemanticsAction::Activate],
  )
}

///|
impl @core.ViewNode for Checkbox with fn focusable(_self) {
  true
}

///|
fn[Msg] checkbox_event(
  node : Checkbox,
  ctx : @core.ViewEventContext,
  on_change : ((Bool) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      if event.phase == @core.PointerPhase::Up &&
        ctx.frame.contains(event.position) {
        let next = !node.checked.get()
        node.checked.set(next)
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
        let next = !node.checked.get()
        node.checked.set(next)
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
  box_shape~ : @core.ChoiceControlShape,
  check_style~ : @core.CheckMarkStyle,
  frame~ : @core.Rect,
  theme~ : @core.Theme,
  focused~ : Bool,
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
  // Circle controls (radio) use a full-circle radius; square controls (checkbox)
  // use the theme's small radius so checkboxes stay consistent with the rest of
  // the control set.
  let box_radius = match box_shape {
    @core.ChoiceControlShape::Circle => box_side / 2.0
    @core.ChoiceControlShape::Square => theme.radius_scale.sm
  }
  let box = @core.RoundedRect::new(rect=box_rect, radius=box_radius)
  if checked {
    match check_style {
      // Checkbox: fill the box with the accent and draw a "✓" glyph on top.
      @core.CheckMarkStyle::Checkmark => {
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
      // Radio: draw an outer ring + a smaller filled inner circle. The ring
      // is the accent at rest; when selected the inner dot fills with the
      // accent. Unchecked radios draw only the ring (handled below).
      @core.CheckMarkStyle::Dot => {
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
    // Unchecked uses a neutral outline (not the accent) so the control reads
    // as inactive at rest; the accent only appears on selection. Focus swaps
    // the outline to the accent to signal keyboard affordance.
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
