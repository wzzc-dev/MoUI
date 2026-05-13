///|
pub(all) struct Theme {
  font : FontSpec
  foreground : Color
  background : Color
  accent : Color
  spacing : Double
  corner_radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Environment {
  theme : Theme
} derive(Eq, Debug, ToJson)

///|
pub fn Theme::default() -> Theme {
  {
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    background: Color::white(),
    accent: Color::blue(),
    spacing: 8.0,
    corner_radius: 6.0,
  }
}

///|
pub fn Theme::with_font(self : Theme, font : FontSpec) -> Theme {
  { ..self, font, }
}

///|
pub fn Theme::with_foreground(self : Theme, color : Color) -> Theme {
  { ..self, foreground: color }
}

///|
pub fn Theme::with_background(self : Theme, color : Color) -> Theme {
  { ..self, background: color }
}

///|
pub fn Theme::with_accent(self : Theme, color : Color) -> Theme {
  { ..self, accent: color }
}

///|
pub fn Theme::with_spacing(self : Theme, spacing : Double) -> Theme {
  { ..self, spacing, }
}

///|
pub fn Theme::with_corner_radius(self : Theme, radius : Double) -> Theme {
  { ..self, corner_radius: radius }
}

///|
pub fn Environment::default() -> Environment {
  { theme: Theme::default() }
}

///|
pub fn Environment::with_theme(
  self : Environment,
  theme : Theme,
) -> Environment {
  ignore(self)
  { theme, }
}

///|
pub fn ViewStyle::from_theme(theme : Theme) -> ViewStyle {
  {
    font: Some(theme.font),
    foreground: Some(theme.foreground),
    background: Some(theme.background),
    corner_radius: Some(theme.corner_radius),
  }
}
