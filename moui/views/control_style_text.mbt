// === TextStyle constructors, getters, with_xxx ===

///|
pub fn TextStyle::new(
  font~ : @core.FontSpec,
  color~ : @core.Color,
) -> TextStyle {
  { font, color }
}

///|
pub fn TextStyle::font(self : TextStyle) -> @core.FontSpec {
  self.font
}

///|
pub fn TextStyle::color(self : TextStyle) -> @core.Color {
  self.color
}

///|
pub fn TextStyle::with_font(
  self : TextStyle,
  font~ : @core.FontSpec,
) -> TextStyle {
  { ..self, font, }
}

///|
pub fn TextStyle::with_color(
  self : TextStyle,
  color~ : @core.Color,
) -> TextStyle {
  { ..self, color, }
}
