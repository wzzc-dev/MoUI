///|
pub fn[Msg] toggle(
  label : String,
  checked : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = default_theme(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox(label, checked~, on_change~, theme~, foreground?, check_color?).semantics_role(
    @core.SemanticsRole::Switch,
  )
}

///|
pub fn[Msg] toggle_switch(
  label : String,
  checked : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = default_theme(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  toggle(label, checked, on_change~, theme~, foreground?, check_color?)
}

///|
pub fn[Msg] radio(
  label : String,
  selected : Bool,
  on_change~ : (Bool) -> Msg,
  theme? : @core.Theme = default_theme(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox(
    label,
    checked=selected,
    on_change~,
    theme~,
    foreground?,
    check_color?,
    box_shape=@core.ChoiceControlShape::Circle,
    check_style=@core.CheckMarkStyle::Dot,
  ).semantics_role(@core.SemanticsRole::Radio)
}

///|
pub fn[Msg] toggle_binding(
  label : String,
  checked : @core.Binding[Bool],
  theme? : @core.Theme = default_theme(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox_binding(label, checked~, theme~, foreground?, check_color?).semantics_role(
    @core.SemanticsRole::Switch,
  )
}

///|
pub fn[Msg] toggle_switch_binding(
  label : String,
  checked : @core.Binding[Bool],
  theme? : @core.Theme = default_theme(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  toggle_binding(label, checked, theme~, foreground?, check_color?)
}

///|
pub fn[Msg] radio_binding(
  label : String,
  selected : @core.Binding[Bool],
  theme? : @core.Theme = default_theme(),
  foreground? : @core.Color,
  check_color? : @core.Color,
) -> @core.View[Msg] {
  checkbox_binding(
    label,
    checked=selected,
    theme~,
    foreground?,
    check_color?,
    box_shape=@core.ChoiceControlShape::Circle,
    check_style=@core.CheckMarkStyle::Dot,
  ).semantics_role(@core.SemanticsRole::Radio)
}
