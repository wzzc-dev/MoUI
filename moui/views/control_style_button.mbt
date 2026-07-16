// === ButtonStyle constructors, getters, with_xxx ===

///|
pub fn ButtonStyle::new(
  normal~ : ControlStateStyle,
  hovered~ : ControlStateStyle,
  pressed~ : ControlStateStyle,
  disabled~ : ControlStateStyle,
) -> ButtonStyle {
  { normal, hovered, pressed, disabled }
}

///|
pub fn ButtonStyle::normal(self : ButtonStyle) -> ControlStateStyle {
  self.normal
}

///|
pub fn ButtonStyle::hovered(self : ButtonStyle) -> ControlStateStyle {
  self.hovered
}

///|
pub fn ButtonStyle::pressed(self : ButtonStyle) -> ControlStateStyle {
  self.pressed
}

///|
pub fn ButtonStyle::disabled(self : ButtonStyle) -> ControlStateStyle {
  self.disabled
}

///|
pub fn ButtonStyle::with_normal(
  self : ButtonStyle,
  normal~ : ControlStateStyle,
) -> ButtonStyle {
  { ..self, normal, }
}

///|
pub fn ButtonStyle::with_hovered(
  self : ButtonStyle,
  hovered~ : ControlStateStyle,
) -> ButtonStyle {
  { ..self, hovered, }
}

///|
pub fn ButtonStyle::with_pressed(
  self : ButtonStyle,
  pressed~ : ControlStateStyle,
) -> ButtonStyle {
  { ..self, pressed, }
}

///|
pub fn ButtonStyle::with_disabled(
  self : ButtonStyle,
  disabled~ : ControlStateStyle,
) -> ButtonStyle {
  { ..self, disabled, }
}
