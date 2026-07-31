// === ToneStyle constructors, getters, with_xxx ===

///|
pub fn ToneStyle::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  border~ : @core.Color,
) -> ToneStyle {
  { foreground, background, border }
}

///|
pub fn ToneStyle::foreground(self : ToneStyle) -> @core.Color {
  self.foreground
}

///|
pub fn ToneStyle::background(self : ToneStyle) -> @core.Color {
  self.background
}

///|
pub fn ToneStyle::border(self : ToneStyle) -> @core.Color {
  self.border
}

///|
pub fn ToneStyle::with_foreground(
  self : ToneStyle,
  foreground~ : @core.Color,
) -> ToneStyle {
  { ..self, foreground, }
}

///|
pub fn ToneStyle::with_background(
  self : ToneStyle,
  background~ : @core.Color,
) -> ToneStyle {
  { ..self, background, }
}

///|
pub fn ToneStyle::with_border(
  self : ToneStyle,
  border~ : @core.Color,
) -> ToneStyle {
  { ..self, border, }
}
