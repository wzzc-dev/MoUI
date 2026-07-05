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
