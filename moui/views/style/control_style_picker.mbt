// === PickerStyle constructors, getters, with_xxx ===

///|
pub fn PickerStyle::new(
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  radius~ : Double,
  popup_max_height~ : Double,
) -> PickerStyle {
  { font, foreground, background, radius, popup_max_height }
}

///|
pub fn PickerStyle::font(self : PickerStyle) -> @core.FontSpec {
  self.font
}

///|
pub fn PickerStyle::foreground(self : PickerStyle) -> @core.Color {
  self.foreground
}

///|
pub fn PickerStyle::background(self : PickerStyle) -> @core.Brush {
  self.background
}

///|
pub fn PickerStyle::radius(self : PickerStyle) -> Double {
  self.radius
}

///|
pub fn PickerStyle::popup_max_height(self : PickerStyle) -> Double {
  self.popup_max_height
}

///|
pub fn PickerStyle::with_font(
  self : PickerStyle,
  font~ : @core.FontSpec,
) -> PickerStyle {
  { ..self, font, }
}

///|
pub fn PickerStyle::with_foreground(
  self : PickerStyle,
  foreground~ : @core.Color,
) -> PickerStyle {
  { ..self, foreground, }
}

///|
pub fn PickerStyle::with_background(
  self : PickerStyle,
  background~ : @core.Brush,
) -> PickerStyle {
  { ..self, background, }
}

///|
pub fn PickerStyle::with_radius(
  self : PickerStyle,
  radius~ : Double,
) -> PickerStyle {
  { ..self, radius, }
}

///|
pub fn PickerStyle::with_popup_max_height(
  self : PickerStyle,
  popup_max_height~ : Double,
) -> PickerStyle {
  { ..self, popup_max_height, }
}
