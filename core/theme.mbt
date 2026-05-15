///|
///|
pub(all) enum ColorScheme {
  Light
  Dark
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ColorPalette {
  foreground : Color
  background : Color
  surface : Color
  surface_variant : Color
  primary : Color
  primary_foreground : Color
  outline : Color
  muted : Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SpacingScale {
  xs : Double
  sm : Double
  md : Double
  lg : Double
  xl : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RadiusScale {
  sm : Double
  md : Double
  lg : Double
  pill : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TypographyScale {
  body : FontSpec
  title : FontSpec
  caption : FontSpec
  control : FontSpec
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Theme {
  scheme : ColorScheme
  palette : ColorPalette
  spacing_scale : SpacingScale
  radius_scale : RadiusScale
  typography : TypographyScale
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
  color_scheme : ColorScheme
} derive(Eq, Debug, ToJson)

///|
pub fn ColorPalette::light() -> ColorPalette {
  {
    foreground: Color::black(),
    background: Color::white(),
    surface: Color::rgba(r=0.96, g=0.97, b=0.98),
    surface_variant: Color::rgba(r=0.90, g=0.92, b=0.95),
    primary: Color::blue(),
    primary_foreground: Color::white(),
    outline: Color::gray(),
    muted: Color::rgba(r=0.42, g=0.45, b=0.50),
  }
}

///|
pub fn ColorPalette::dark() -> ColorPalette {
  {
    foreground: Color::rgba(r=0.94, g=0.95, b=0.96),
    background: Color::rgba(r=0.08, g=0.09, b=0.11),
    surface: Color::rgba(r=0.13, g=0.15, b=0.18),
    surface_variant: Color::rgba(r=0.20, g=0.23, b=0.28),
    primary: Color::rgba(r=0.42, g=0.58, b=1.0),
    primary_foreground: Color::white(),
    outline: Color::rgba(r=0.34, g=0.38, b=0.45),
    muted: Color::rgba(r=0.64, g=0.67, b=0.72),
  }
}

///|
pub fn SpacingScale::default() -> SpacingScale {
  { xs: 4.0, sm: 8.0, md: 12.0, lg: 16.0, xl: 24.0 }
}

///|
pub fn RadiusScale::default() -> RadiusScale {
  { sm: 4.0, md: 8.0, lg: 12.0, pill: 999.0 }
}

///|
pub fn TypographyScale::default() -> TypographyScale {
  {
    body: FontSpec::new(size=16.0, weight=400),
    title: FontSpec::new(size=22.0, weight=700),
    caption: FontSpec::new(size=13.0, weight=400),
    control: FontSpec::new(size=16.0, weight=600),
  }
}

///|
pub fn Theme::light() -> Theme {
  let palette = ColorPalette::light()
  let spacing_scale = SpacingScale::default()
  let radius_scale = RadiusScale::default()
  let typography = TypographyScale::default()
  {
    scheme: ColorScheme::Light,
    palette,
    spacing_scale,
    radius_scale,
    typography,
    font: typography.body,
    foreground: palette.foreground,
    background: palette.background,
    accent: palette.primary,
    spacing: spacing_scale.sm,
    corner_radius: radius_scale.md,
  }
}

///|
pub fn Theme::dark() -> Theme {
  let palette = ColorPalette::dark()
  let spacing_scale = SpacingScale::default()
  let radius_scale = RadiusScale::default()
  let typography = TypographyScale::default()
  {
    scheme: ColorScheme::Dark,
    palette,
    spacing_scale,
    radius_scale,
    typography,
    font: typography.body,
    foreground: palette.foreground,
    background: palette.background,
    accent: palette.primary,
    spacing: spacing_scale.sm,
    corner_radius: radius_scale.md,
  }
}

///|
pub fn Theme::default() -> Theme {
  Theme::light()
}

///|
pub fn Theme::with_font(self : Theme, font : FontSpec) -> Theme {
  { ..self, font, typography: { ..self.typography, body: font } }
}

///|
pub fn Theme::with_foreground(self : Theme, color : Color) -> Theme {
  { ..self, foreground: color, palette: { ..self.palette, foreground: color } }
}

///|
pub fn Theme::with_background(self : Theme, color : Color) -> Theme {
  { ..self, background: color, palette: { ..self.palette, background: color } }
}

///|
pub fn Theme::with_accent(self : Theme, color : Color) -> Theme {
  { ..self, accent: color, palette: { ..self.palette, primary: color } }
}

///|
pub fn Theme::with_spacing(self : Theme, spacing : Double) -> Theme {
  { ..self, spacing, spacing_scale: { ..self.spacing_scale, sm: spacing } }
}

///|
pub fn Theme::with_corner_radius(self : Theme, radius : Double) -> Theme {
  { ..self, corner_radius: radius, radius_scale: { ..self.radius_scale, md: radius } }
}

///|
pub fn Theme::with_palette(self : Theme, palette : ColorPalette) -> Theme {
  {
    ..self,
    palette,
    foreground: palette.foreground,
    background: palette.background,
    accent: palette.primary,
  }
}

///|
pub fn Theme::with_spacing_scale(
  self : Theme,
  spacing_scale : SpacingScale,
) -> Theme {
  { ..self, spacing_scale, spacing: spacing_scale.sm }
}

///|
pub fn Theme::with_radius_scale(
  self : Theme,
  radius_scale : RadiusScale,
) -> Theme {
  { ..self, radius_scale, corner_radius: radius_scale.md }
}

///|
pub fn Theme::with_typography(
  self : Theme,
  typography : TypographyScale,
) -> Theme {
  { ..self, typography, font: typography.body }
}

///|
pub fn Environment::default() -> Environment {
  let theme = Theme::default()
  { theme, color_scheme: theme.scheme }
}

///|
pub fn Environment::with_theme(
  self : Environment,
  theme : Theme,
) -> Environment {
  ignore(self)
  { theme, color_scheme: theme.scheme }
}

///|
pub fn Environment::with_color_scheme(
  self : Environment,
  color_scheme : ColorScheme,
) -> Environment {
  let theme = match color_scheme {
    Light => Theme::light()
    Dark => Theme::dark()
  }
  ignore(self)
  { theme, color_scheme }
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
