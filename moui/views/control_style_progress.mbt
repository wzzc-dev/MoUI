// === ProgressStyle constructors, getters, with_xxx ===

///|
pub fn ProgressStyle::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  radius~ : Double,
) -> ProgressStyle {
  { foreground, background, radius }
}

///|
pub fn ProgressStyle::foreground(self : ProgressStyle) -> @core.Color {
  self.foreground
}

///|
pub fn ProgressStyle::background(self : ProgressStyle) -> @core.Color {
  self.background
}

///|
pub fn ProgressStyle::radius(self : ProgressStyle) -> Double {
  self.radius
}

///|
pub fn ProgressStyle::with_foreground(
  self : ProgressStyle,
  foreground~ : @core.Color,
) -> ProgressStyle {
  { ..self, foreground, }
}

///|
pub fn ProgressStyle::with_background(
  self : ProgressStyle,
  background~ : @core.Color,
) -> ProgressStyle {
  { ..self, background, }
}

///|
pub fn ProgressStyle::with_radius(
  self : ProgressStyle,
  radius~ : Double,
) -> ProgressStyle {
  { ..self, radius, }
}
