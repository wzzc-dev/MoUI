// === FeedbackStyle constructors, getters, with_xxx ===

///|
pub fn FeedbackStyle::new(
  neutral~ : ToneStyle,
  info~ : ToneStyle,
  success~ : ToneStyle,
  warning~ : ToneStyle,
  danger~ : ToneStyle,
  radius~ : Double,
  padding~ : Double,
) -> FeedbackStyle {
  { neutral, info, success, warning, danger, radius, padding }
}

///|
pub fn FeedbackStyle::neutral(self : FeedbackStyle) -> ToneStyle {
  self.neutral
}

///|
pub fn FeedbackStyle::info(self : FeedbackStyle) -> ToneStyle {
  self.info
}

///|
pub fn FeedbackStyle::success(self : FeedbackStyle) -> ToneStyle {
  self.success
}

///|
pub fn FeedbackStyle::warning(self : FeedbackStyle) -> ToneStyle {
  self.warning
}

///|
pub fn FeedbackStyle::danger(self : FeedbackStyle) -> ToneStyle {
  self.danger
}

///|
pub fn FeedbackStyle::radius(self : FeedbackStyle) -> Double {
  self.radius
}

///|
pub fn FeedbackStyle::padding(self : FeedbackStyle) -> Double {
  self.padding
}

///|
pub fn FeedbackStyle::with_neutral(
  self : FeedbackStyle,
  neutral~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, neutral, }
}

///|
pub fn FeedbackStyle::with_info(
  self : FeedbackStyle,
  info~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, info, }
}

///|
pub fn FeedbackStyle::with_success(
  self : FeedbackStyle,
  success~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, success, }
}

///|
pub fn FeedbackStyle::with_warning(
  self : FeedbackStyle,
  warning~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, warning, }
}

///|
pub fn FeedbackStyle::with_danger(
  self : FeedbackStyle,
  danger~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, danger, }
}

///|
pub fn FeedbackStyle::with_radius(
  self : FeedbackStyle,
  radius~ : Double,
) -> FeedbackStyle {
  { ..self, radius, }
}

///|
pub fn FeedbackStyle::with_padding(
  self : FeedbackStyle,
  padding~ : Double,
) -> FeedbackStyle {
  { ..self, padding, }
}
