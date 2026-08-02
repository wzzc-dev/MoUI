///|
pub fn[Msg] toggle(
  label : String,
  checked : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme,
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox(label, checked~, on_change~, theme?, foreground?, check_color?).semantics_role(
    @core.SemanticsRole::Switch,
  )
}

///|
pub fn[Msg] radio(
  label : String,
  selected : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme,
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox(
    label,
    checked=selected,
    on_change~,
    theme?,
    foreground?,
    check_color?,
    box_shape=@style.ChoiceControlShape::Circle,
    check_style=@style.CheckMarkStyle::Dot,
  ).semantics_role(@core.SemanticsRole::Radio)
}
