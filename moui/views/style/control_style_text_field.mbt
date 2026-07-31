// === TextFieldStyle constructors, getters, with_xxx ===

///|
pub fn TextFieldStyle::new(
  normal~ : ControlStateStyle,
  focused~ : ControlStateStyle,
  disabled~ : ControlStateStyle,
  placeholder_color~ : @core.Color,
  cursor_color~ : @core.Color,
  font~ : @core.FontSpec,
) -> TextFieldStyle {
  { normal, focused, disabled, placeholder_color, cursor_color, font }
}

///|
pub fn TextFieldStyle::normal(self : TextFieldStyle) -> ControlStateStyle {
  self.normal
}

///|
pub fn TextFieldStyle::focused(self : TextFieldStyle) -> ControlStateStyle {
  self.focused
}

///|
pub fn TextFieldStyle::disabled(self : TextFieldStyle) -> ControlStateStyle {
  self.disabled
}

///|
pub fn TextFieldStyle::placeholder_color(self : TextFieldStyle) -> @core.Color {
  self.placeholder_color
}

///|
pub fn TextFieldStyle::cursor_color(self : TextFieldStyle) -> @core.Color {
  self.cursor_color
}

///|
pub fn TextFieldStyle::font(self : TextFieldStyle) -> @core.FontSpec {
  self.font
}

///|
pub fn TextFieldStyle::with_normal(
  self : TextFieldStyle,
  normal~ : ControlStateStyle,
) -> TextFieldStyle {
  { ..self, normal, }
}

///|
pub fn TextFieldStyle::with_focused(
  self : TextFieldStyle,
  focused~ : ControlStateStyle,
) -> TextFieldStyle {
  { ..self, focused, }
}

///|
pub fn TextFieldStyle::with_disabled(
  self : TextFieldStyle,
  disabled~ : ControlStateStyle,
) -> TextFieldStyle {
  { ..self, disabled, }
}

///|
pub fn TextFieldStyle::with_placeholder_color(
  self : TextFieldStyle,
  placeholder_color~ : @core.Color,
) -> TextFieldStyle {
  { ..self, placeholder_color, }
}

///|
pub fn TextFieldStyle::with_cursor_color(
  self : TextFieldStyle,
  cursor_color~ : @core.Color,
) -> TextFieldStyle {
  { ..self, cursor_color, }
}

///|
pub fn TextFieldStyle::with_font(
  self : TextFieldStyle,
  font~ : @core.FontSpec,
) -> TextFieldStyle {
  { ..self, font, }
}
