///|
pub fn[Msg] checkbox(
  label : String,
  checked~ : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
  font? : @core.FontSpec,
  foreground? : @core.Color,
  check_color? : @core.Color,
  box_size? : Double,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let style = @core.ChoiceControlStyle::default(theme~)
  let font = resolve_choice_font(font, theme)
  let foreground = resolve_control_color(foreground, style.foreground)
  let check_color = resolve_control_color(check_color, style.selected_color)
  let box_size = resolve_control_double(box_size, style.control_size)
  @core.View::controlled_checkbox(
    label~,
    checked~,
    on_change~,
    font~,
    foreground~,
    check_color~,
    size=@core.Size::new(width=box_size, height~),
  )
}

///|
pub fn[Msg] checkbox_binding(
  label : String,
  checked~ : @core.Binding[Bool],
  theme? : @core.Theme = @core.Theme::default(),
  font? : @core.FontSpec,
  foreground? : @core.Color,
  check_color? : @core.Color,
  box_size? : Double,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let style = @core.ChoiceControlStyle::default(theme~)
  let font = resolve_choice_font(font, theme)
  let foreground = resolve_control_color(foreground, style.foreground)
  let check_color = resolve_control_color(check_color, style.selected_color)
  let box_size = resolve_control_double(box_size, style.control_size)
  @core.View::checkbox(
    label~,
    checked~,
    font~,
    foreground~,
    check_color~,
    size=@core.Size::new(width=box_size, height~),
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
