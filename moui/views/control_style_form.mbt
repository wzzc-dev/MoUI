// === FormValidationStyle constructors, getters, with_xxx ===

///|
pub fn FormValidationStyle::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  border~ : @core.Color,
  radius~ : Double,
  padding~ : Double,
) -> FormValidationStyle {
  { foreground, background, border, radius, padding }
}

///|
pub fn FormValidationStyle::foreground(
  self : FormValidationStyle,
) -> @core.Color {
  self.foreground
}

///|
pub fn FormValidationStyle::background(
  self : FormValidationStyle,
) -> @core.Color {
  self.background
}

///|
pub fn FormValidationStyle::border(self : FormValidationStyle) -> @core.Color {
  self.border
}

///|
pub fn FormValidationStyle::radius(self : FormValidationStyle) -> Double {
  self.radius
}

///|
pub fn FormValidationStyle::padding(self : FormValidationStyle) -> Double {
  self.padding
}

///|
pub fn FormValidationStyle::with_foreground(
  self : FormValidationStyle,
  foreground~ : @core.Color,
) -> FormValidationStyle {
  { ..self, foreground, }
}

///|
pub fn FormValidationStyle::with_background(
  self : FormValidationStyle,
  background~ : @core.Color,
) -> FormValidationStyle {
  { ..self, background, }
}

///|
pub fn FormValidationStyle::with_border(
  self : FormValidationStyle,
  border~ : @core.Color,
) -> FormValidationStyle {
  { ..self, border, }
}

///|
pub fn FormValidationStyle::with_radius(
  self : FormValidationStyle,
  radius~ : Double,
) -> FormValidationStyle {
  { ..self, radius, }
}

///|
pub fn FormValidationStyle::with_padding(
  self : FormValidationStyle,
  padding~ : Double,
) -> FormValidationStyle {
  { ..self, padding, }
}
