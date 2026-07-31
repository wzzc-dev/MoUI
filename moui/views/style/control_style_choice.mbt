// === ChoiceControlStyle constructors, getters, with_xxx ===

///|
pub fn ChoiceControlStyle::new(
  foreground~ : @core.Color,
  selected_color~ : @core.Color,
  disabled_foreground~ : @core.Color,
  disabled_selected_color~ : @core.Color,
  control_size~ : Double,
) -> ChoiceControlStyle {
  {
    foreground,
    selected_color,
    disabled_foreground,
    disabled_selected_color,
    control_size,
  }
}

///|
pub fn ChoiceControlStyle::foreground(self : ChoiceControlStyle) -> @core.Color {
  self.foreground
}

///|
pub fn ChoiceControlStyle::selected_color(
  self : ChoiceControlStyle,
) -> @core.Color {
  self.selected_color
}

///|
pub fn ChoiceControlStyle::disabled_foreground(
  self : ChoiceControlStyle,
) -> @core.Color {
  self.disabled_foreground
}

///|
pub fn ChoiceControlStyle::disabled_selected_color(
  self : ChoiceControlStyle,
) -> @core.Color {
  self.disabled_selected_color
}

///|
pub fn ChoiceControlStyle::control_size(self : ChoiceControlStyle) -> Double {
  self.control_size
}

///|
pub fn ChoiceControlStyle::with_foreground(
  self : ChoiceControlStyle,
  foreground~ : @core.Color,
) -> ChoiceControlStyle {
  { ..self, foreground, }
}

///|
pub fn ChoiceControlStyle::with_selected_color(
  self : ChoiceControlStyle,
  selected_color~ : @core.Color,
) -> ChoiceControlStyle {
  { ..self, selected_color, }
}

///|
pub fn ChoiceControlStyle::with_disabled_foreground(
  self : ChoiceControlStyle,
  disabled_foreground~ : @core.Color,
) -> ChoiceControlStyle {
  { ..self, disabled_foreground, }
}

///|
pub fn ChoiceControlStyle::with_disabled_selected_color(
  self : ChoiceControlStyle,
  disabled_selected_color~ : @core.Color,
) -> ChoiceControlStyle {
  { ..self, disabled_selected_color, }
}

///|
pub fn ChoiceControlStyle::with_control_size(
  self : ChoiceControlStyle,
  control_size~ : Double,
) -> ChoiceControlStyle {
  { ..self, control_size, }
}
