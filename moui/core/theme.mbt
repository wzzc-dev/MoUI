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
pub(all) struct SemanticColorScale {
  success : Color
  warning : Color
  danger : Color
  info : Color
  focus : Color
  scrim : Color
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
pub(all) struct ShadowScale {
  sm : ShadowStyle
  md : ShadowStyle
  lg : ShadowStyle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MotionScale {
  fast_ms : Double
  normal_ms : Double
  slow_ms : Double
  easing : Easing
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SurfaceScale {
  base : Brush
  raised : Brush
  overlay : Brush
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SurfaceLevel {
  Base
  Raised
  Overlay
} derive(Eq, Debug, ToJson)

///|
pub(all) enum LayoutDirection {
  LeftToRight
  RightToLeft
} derive(Eq, Debug, ToJson)

///|
pub(all) enum AccessibilityContrast {
  Standard
  High
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ContentSizeCategory {
  Small
  Medium
  Large
  ExtraLarge
  Accessibility
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Theme {
  scheme : ColorScheme
  palette : ColorPalette
  semantic_colors : SemanticColorScale
  spacing_scale : SpacingScale
  radius_scale : RadiusScale
  typography : TypographyScale
  shadow_scale : ShadowScale
  motion : MotionScale
  surfaces : SurfaceScale
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
  scale_factor : Double
  text_scale : Double
  locale : String
  layout_direction : LayoutDirection
  accessibility_contrast : AccessibilityContrast
  reduced_motion : Bool
  content_size_category : ContentSizeCategory
  enabled : Bool
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
pub fn SemanticColorScale::default(
  palette : ColorPalette,
  scheme : ColorScheme,
) -> SemanticColorScale {
  match scheme {
    Light =>
      {
        success: Color::rgba(r=0.08, g=0.48, b=0.28),
        warning: Color::rgba(r=0.76, g=0.44, b=0.06),
        danger: Color::rgba(r=0.74, g=0.12, b=0.16),
        info: palette.primary,
        focus: palette.primary,
        scrim: Color::rgba(r=0.0, g=0.0, b=0.0, a=0.42),
      }
    Dark =>
      {
        success: Color::rgba(r=0.36, g=0.78, b=0.48),
        warning: Color::rgba(r=1.0, g=0.76, b=0.34),
        danger: Color::rgba(r=1.0, g=0.48, b=0.52),
        info: palette.primary,
        focus: palette.primary,
        scrim: Color::rgba(r=0.0, g=0.0, b=0.0, a=0.62),
      }
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
pub fn ShadowScale::default(
  scheme? : ColorScheme = ColorScheme::Light,
) -> ShadowScale {
  let alpha = match scheme {
    Light => 0.18
    Dark => 0.36
  }
  {
    sm: ShadowStyle::new(
      color=Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha * 0.65),
      offset=Point::new(x=0.0, y=1.0),
      blur_radius=6.0,
    ),
    md: ShadowStyle::new(
      color=Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha),
      offset=Point::new(x=0.0, y=4.0),
      blur_radius=16.0,
    ),
    lg: ShadowStyle::new(
      color=Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha * 1.2),
      offset=Point::new(x=0.0, y=10.0),
      blur_radius=28.0,
      spread=2.0,
    ),
  }
}

///|
pub fn MotionScale::default() -> MotionScale {
  {
    fast_ms: 120.0,
    normal_ms: 180.0,
    slow_ms: 280.0,
    easing: Easing::EaseInOut,
  }
}

///|
pub fn SurfaceScale::default(
  palette : ColorPalette,
  scheme : ColorScheme,
) -> SurfaceScale {
  let raised = match scheme {
    Light =>
      Brush::linear_gradient(
        start=Point::new(x=0.0, y=0.0),
        end=Point::new(x=0.0, y=120.0),
        start_color=Color::white(),
        end_color=palette.surface,
      )
    Dark =>
      Brush::linear_gradient(
        start=Point::new(x=0.0, y=0.0),
        end=Point::new(x=0.0, y=120.0),
        start_color=palette.surface_variant,
        end_color=palette.surface,
      )
  }
  {
    base: Brush::solid(palette.surface),
    raised,
    overlay: Brush::solid(palette.surface_variant),
  }
}

///|
pub fn Theme::light() -> Theme {
  let palette = ColorPalette::light()
  let semantic_colors = SemanticColorScale::default(palette, ColorScheme::Light)
  let spacing_scale = SpacingScale::default()
  let radius_scale = RadiusScale::default()
  let typography = TypographyScale::default()
  let shadow_scale = ShadowScale::default(scheme=ColorScheme::Light)
  let motion = MotionScale::default()
  let surfaces = SurfaceScale::default(palette, ColorScheme::Light)
  {
    scheme: ColorScheme::Light,
    palette,
    semantic_colors,
    spacing_scale,
    radius_scale,
    typography,
    shadow_scale,
    motion,
    surfaces,
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
  let semantic_colors = SemanticColorScale::default(palette, ColorScheme::Dark)
  let spacing_scale = SpacingScale::default()
  let radius_scale = RadiusScale::default()
  let typography = TypographyScale::default()
  let shadow_scale = ShadowScale::default(scheme=ColorScheme::Dark)
  let motion = MotionScale::default()
  let surfaces = SurfaceScale::default(palette, ColorScheme::Dark)
  {
    scheme: ColorScheme::Dark,
    palette,
    semantic_colors,
    spacing_scale,
    radius_scale,
    typography,
    shadow_scale,
    motion,
    surfaces,
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
  {
    ..self,
    accent: color,
    palette: { ..self.palette, primary: color },
    semantic_colors: { ..self.semantic_colors, info: color, focus: color },
  }
}

///|
pub fn Theme::with_spacing(self : Theme, spacing : Double) -> Theme {
  { ..self, spacing, spacing_scale: { ..self.spacing_scale, sm: spacing } }
}

///|
pub fn Theme::with_corner_radius(self : Theme, radius : Double) -> Theme {
  {
    ..self,
    corner_radius: radius,
    radius_scale: { ..self.radius_scale, md: radius },
  }
}

///|
pub fn Theme::with_palette(self : Theme, palette : ColorPalette) -> Theme {
  let surfaces = SurfaceScale::default(palette, self.scheme)
  let semantic_colors = {
    ..self.semantic_colors,
    info: palette.primary,
    focus: palette.primary,
  }
  {
    ..self,
    palette,
    semantic_colors,
    surfaces,
    foreground: palette.foreground,
    background: palette.background,
    accent: palette.primary,
  }
}

///|
pub fn Theme::with_semantic_colors(
  self : Theme,
  semantic_colors : SemanticColorScale,
) -> Theme {
  { ..self, semantic_colors, }
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
pub fn Theme::with_shadow_scale(
  self : Theme,
  shadow_scale : ShadowScale,
) -> Theme {
  { ..self, shadow_scale, }
}

///|
pub fn Theme::with_motion(self : Theme, motion : MotionScale) -> Theme {
  { ..self, motion, }
}

///|
pub fn Theme::with_surfaces(self : Theme, surfaces : SurfaceScale) -> Theme {
  { ..self, surfaces, }
}

///|
pub fn Theme::surface_brush(self : Theme, level : SurfaceLevel) -> Brush {
  match level {
    Base => self.surfaces.base
    Raised => self.surfaces.raised
    Overlay => self.surfaces.overlay
  }
}

///|
pub fn Environment::default() -> Environment {
  let theme = Theme::default()
  {
    theme,
    color_scheme: theme.scheme,
    scale_factor: 1.0,
    text_scale: 1.0,
    locale: "en-US",
    layout_direction: LayoutDirection::LeftToRight,
    accessibility_contrast: AccessibilityContrast::Standard,
    reduced_motion: false,
    content_size_category: ContentSizeCategory::Medium,
    enabled: true,
  }
}

///|
pub fn Environment::with_theme(
  self : Environment,
  theme : Theme,
) -> Environment {
  { ..self, theme, color_scheme: theme.scheme }
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
  { ..self, theme, color_scheme }
}

///|
pub fn Environment::with_scale_factor(
  self : Environment,
  scale_factor : Double,
) -> Environment {
  { ..self, scale_factor: max_double(0.1, scale_factor) }
}

///|
pub fn Environment::with_text_scale(
  self : Environment,
  text_scale : Double,
) -> Environment {
  { ..self, text_scale: max_double(0.1, text_scale) }
}

///|
pub fn Environment::with_locale(
  self : Environment,
  locale : String,
) -> Environment {
  { ..self, locale, }
}

///|
pub fn Environment::with_layout_direction(
  self : Environment,
  layout_direction : LayoutDirection,
) -> Environment {
  { ..self, layout_direction, }
}

///|
pub fn Environment::with_accessibility_contrast(
  self : Environment,
  accessibility_contrast : AccessibilityContrast,
) -> Environment {
  { ..self, accessibility_contrast, }
}

///|
pub fn Environment::with_reduced_motion(
  self : Environment,
  reduced_motion : Bool,
) -> Environment {
  { ..self, reduced_motion, }
}

///|
pub fn Environment::with_content_size_category(
  self : Environment,
  content_size_category : ContentSizeCategory,
) -> Environment {
  {
    ..self,
    content_size_category,
    text_scale: content_size_category.text_scale(),
  }
}

///|
pub fn Environment::with_enabled(
  self : Environment,
  enabled : Bool,
) -> Environment {
  { ..self, enabled, }
}

///|
pub fn ContentSizeCategory::text_scale(self : ContentSizeCategory) -> Double {
  match self {
    Small => 0.9
    Medium => 1.0
    Large => 1.15
    ExtraLarge => 1.3
    Accessibility => 1.6
  }
}

///|
pub fn ViewStyle::from_theme(theme : Theme) -> ViewStyle {
  {
    font: Some(theme.font),
    foreground: Some(theme.foreground),
    background: Some(theme.surface_brush(SurfaceLevel::Base)),
    corner_radius: Some(theme.corner_radius),
  }
}
