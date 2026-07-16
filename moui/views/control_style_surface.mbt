// === SurfaceStyle constructors, getters, with_xxx ===

///|
pub fn SurfaceStyle::new(
  brush~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  radius~ : Double,
  shadow? : @core.ShadowStyle? = None,
  padding~ : @core.Insets,
  level~ : @core.SurfaceLevel,
) -> SurfaceStyle {
  { brush, border, radius, shadow, padding, level }
}

///|
pub fn SurfaceStyle::brush(self : SurfaceStyle) -> @core.Brush {
  self.brush
}

///|
pub fn SurfaceStyle::border(self : SurfaceStyle) -> @core.BorderStyle? {
  self.border
}

///|
pub fn SurfaceStyle::radius(self : SurfaceStyle) -> Double {
  self.radius
}

///|
pub fn SurfaceStyle::shadow(self : SurfaceStyle) -> @core.ShadowStyle? {
  self.shadow
}

///|
pub fn SurfaceStyle::padding(self : SurfaceStyle) -> @core.Insets {
  self.padding
}

///|
pub fn SurfaceStyle::level(self : SurfaceStyle) -> @core.SurfaceLevel {
  self.level
}

///|
pub fn SurfaceStyle::with_brush(
  self : SurfaceStyle,
  brush~ : @core.Brush,
) -> SurfaceStyle {
  { ..self, brush, }
}

///|
pub fn SurfaceStyle::with_border(
  self : SurfaceStyle,
  border~ : @core.BorderStyle?,
) -> SurfaceStyle {
  { ..self, border, }
}

///|
pub fn SurfaceStyle::with_radius(
  self : SurfaceStyle,
  radius~ : Double,
) -> SurfaceStyle {
  { ..self, radius, }
}

///|
pub fn SurfaceStyle::with_shadow(
  self : SurfaceStyle,
  shadow~ : @core.ShadowStyle?,
) -> SurfaceStyle {
  { ..self, shadow, }
}

///|
pub fn SurfaceStyle::with_padding(
  self : SurfaceStyle,
  padding~ : @core.Insets,
) -> SurfaceStyle {
  { ..self, padding, }
}

///|
pub fn SurfaceStyle::with_level(
  self : SurfaceStyle,
  level~ : @core.SurfaceLevel,
) -> SurfaceStyle {
  { ..self, level, }
}
