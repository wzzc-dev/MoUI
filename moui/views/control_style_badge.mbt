// === BadgeStyle constructors, getters, with_xxx ===

///|
pub fn BadgeStyle::new(
  neutral~ : ToneStyle,
  accent~ : ToneStyle,
  success~ : ToneStyle,
  warning~ : ToneStyle,
  danger~ : ToneStyle,
  radius~ : Double,
  padding~ : Double,
) -> BadgeStyle {
  { neutral, accent, success, warning, danger, radius, padding }
}

///|
pub fn BadgeStyle::neutral(self : BadgeStyle) -> ToneStyle {
  self.neutral
}

///|
pub fn BadgeStyle::accent(self : BadgeStyle) -> ToneStyle {
  self.accent
}

///|
pub fn BadgeStyle::success(self : BadgeStyle) -> ToneStyle {
  self.success
}

///|
pub fn BadgeStyle::warning(self : BadgeStyle) -> ToneStyle {
  self.warning
}

///|
pub fn BadgeStyle::danger(self : BadgeStyle) -> ToneStyle {
  self.danger
}

///|
pub fn BadgeStyle::radius(self : BadgeStyle) -> Double {
  self.radius
}

///|
pub fn BadgeStyle::padding(self : BadgeStyle) -> Double {
  self.padding
}

///|
pub fn BadgeStyle::with_neutral(
  self : BadgeStyle,
  neutral~ : ToneStyle,
) -> BadgeStyle {
  { ..self, neutral, }
}

///|
pub fn BadgeStyle::with_accent(
  self : BadgeStyle,
  accent~ : ToneStyle,
) -> BadgeStyle {
  { ..self, accent, }
}

///|
pub fn BadgeStyle::with_success(
  self : BadgeStyle,
  success~ : ToneStyle,
) -> BadgeStyle {
  { ..self, success, }
}

///|
pub fn BadgeStyle::with_warning(
  self : BadgeStyle,
  warning~ : ToneStyle,
) -> BadgeStyle {
  { ..self, warning, }
}

///|
pub fn BadgeStyle::with_danger(
  self : BadgeStyle,
  danger~ : ToneStyle,
) -> BadgeStyle {
  { ..self, danger, }
}

///|
pub fn BadgeStyle::with_radius(
  self : BadgeStyle,
  radius~ : Double,
) -> BadgeStyle {
  { ..self, radius, }
}

///|
pub fn BadgeStyle::with_padding(
  self : BadgeStyle,
  padding~ : Double,
) -> BadgeStyle {
  { ..self, padding, }
}
