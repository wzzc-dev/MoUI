// === SliderStyle constructors, getters, with_xxx ===

///|
pub fn SliderStyle::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  thumb_color~ : @core.Color,
  track_height~ : Double,
  thumb_size~ : Double,
  radius~ : Double,
) -> SliderStyle {
  { foreground, background, thumb_color, track_height, thumb_size, radius }
}

///|
pub fn SliderStyle::foreground(self : SliderStyle) -> @core.Color {
  self.foreground
}

///|
pub fn SliderStyle::background(self : SliderStyle) -> @core.Color {
  self.background
}

///|
pub fn SliderStyle::thumb_color(self : SliderStyle) -> @core.Color {
  self.thumb_color
}

///|
pub fn SliderStyle::track_height(self : SliderStyle) -> Double {
  self.track_height
}

///|
pub fn SliderStyle::thumb_size(self : SliderStyle) -> Double {
  self.thumb_size
}

///|
pub fn SliderStyle::radius(self : SliderStyle) -> Double {
  self.radius
}

///|
pub fn SliderStyle::with_foreground(
  self : SliderStyle,
  foreground~ : @core.Color,
) -> SliderStyle {
  { ..self, foreground, }
}

///|
pub fn SliderStyle::with_background(
  self : SliderStyle,
  background~ : @core.Color,
) -> SliderStyle {
  { ..self, background, }
}

///|
pub fn SliderStyle::with_thumb_color(
  self : SliderStyle,
  thumb_color~ : @core.Color,
) -> SliderStyle {
  { ..self, thumb_color, }
}

///|
pub fn SliderStyle::with_track_height(
  self : SliderStyle,
  track_height~ : Double,
) -> SliderStyle {
  { ..self, track_height, }
}

///|
pub fn SliderStyle::with_thumb_size(
  self : SliderStyle,
  thumb_size~ : Double,
) -> SliderStyle {
  { ..self, thumb_size, }
}

///|
pub fn SliderStyle::with_radius(
  self : SliderStyle,
  radius~ : Double,
) -> SliderStyle {
  { ..self, radius, }
}
