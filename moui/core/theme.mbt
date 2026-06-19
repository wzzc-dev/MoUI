///|

///|
pub(all) enum ColorScheme {
  Light
  Dark
} derive(Eq, Debug, ToJson)

///|
/// Full semantic color palette. Extended from the original 8-role palette to
/// the complete on*/container matrix used by Material 3 / Fluent 2 so a
/// branded design system can express primary/secondary/tertiary/error
/// container pairs and their on-colors instead of deriving them ad hoc with
/// `multiply_alpha`/`lerp`. Semantic colors (success/warning/danger/info) are
/// folded in directly; the separate `SemanticColorScale` is removed.
///
/// Role naming follows Compose Material 3 `ColorScheme`:
/// - `on_<role>` is the text/icon color drawn on top of `<role>`.
/// - `<role>_container` is a tinted surface variant; `on_<role>_container`
///   is the text color on that container.
/// `on_foreground` is an explicit alias of `background` for symmetry.
pub(all) struct ColorPalette {
  // Base surfaces.
  foreground : Color
  background : Color
  surface : Color
  surface_variant : Color
  // Primary family.
  primary : Color
  on_primary : Color
  primary_container : Color
  on_primary_container : Color
  // Secondary family.
  secondary : Color
  on_secondary : Color
  secondary_container : Color
  on_secondary_container : Color
  // Tertiary family.
  tertiary : Color
  on_tertiary : Color
  tertiary_container : Color
  on_tertiary_container : Color
  // Error family.
  error : Color
  on_error : Color
  error_container : Color
  on_error_container : Color
  // Surface text roles.
  on_foreground : Color
  on_surface : Color
  on_surface_variant : Color
  // Outlines.
  outline : Color
  outline_variant : Color
  muted : Color
  // Semantic pairs (success/warning/danger/info with on-colors).
  success : Color
  on_success : Color
  warning : Color
  on_warning : Color
  info : Color
  on_info : Color
  danger : Color
  on_danger : Color
  // Focus + scrim.
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
  /// Largest tier; page-level display numbers or hero headlines.
  display : FontSpec
  /// Section/page headlines.
  headline : FontSpec
  /// Card or panel titles.
  title : FontSpec
  /// Secondary title beneath a title or a list-section label.
  subtitle : FontSpec
  /// Default body copy.
  body : FontSpec
  /// Compact emphasized text for buttons, tabs, and form labels.
  label : FontSpec
  /// Small ancillary text. Kept as an alias-friendly name alongside `caption`;
  /// `caption` is the historical field, `overline` adds an even smaller
  /// uppercase-style tier for eyebrows and metadata labels.
  caption : FontSpec
  /// Tiny all-caps-style metadata label (eyebrows, table headers).
  overline : FontSpec
  /// Legacy alias for `label`: emphasized control text (buttons, tabs).
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
/// Resolved, drawable theme. A `Theme` is the output of `resolve_theme(spec,
/// system_scheme)`: it carries the full palette, all scale tiers, and a
/// first-class `components` aggregate. Controls read
/// `ctx.environment.theme.components.<control>` at paint time; `style?` on a
/// control constructor is a one-shot override.
pub(all) struct Theme {
  scheme : ColorScheme
  palette : ColorPalette
  spacing_scale : SpacingScale
  radius_scale : RadiusScale
  typography : TypographyScale
  shadow_scale : ShadowScale
  motion : MotionScale
  surfaces : SurfaceScale
  components : ComponentThemes
} derive(Eq, Debug, ToJson)

///|
/// Runtime environment snapshot. Carries the user's `theme_spec` (intent), the
/// current `system_scheme` (host-reported), and the resolved `theme` derived
/// from both. Changing `system_scheme` rebuilds the full theme via
/// `with_system_scheme`; the legacy `with_color_scheme` (which only flipped a
/// flag and left the palette stale) is removed.
pub(all) struct Environment {
  theme_spec : ThemeSpec
  system_scheme : ColorScheme
  theme : Theme
  scale_factor : Double
  text_scale : Double
  locale : String
  layout_direction : LayoutDirection
  accessibility_contrast : AccessibilityContrast
  reduced_motion : Bool
  content_size_category : ContentSizeCategory
  enabled : Bool
} derive(Eq, Debug, ToJson)

// ---------------------------------------------------------------------------
// ColorPalette factories
// ---------------------------------------------------------------------------

///|
/// Build a palette from a primary color and scheme, deriving every on*/container
/// role programmatically. This is the shared derivation used by both the
/// Minimal preset and (optionally) branded addons that want a seed-driven
/// palette without hand-writing 30+ colors.
///
/// Derivation rules:
/// - `on_primary`/`on_secondary`/`on_tertiary`/`on_error` = white on dark
///   primaries, near-black on light primaries (contrast-aware).
/// - `<role>_container` = the role color lerped toward the surface by ~0.85
///   (a soft tint); `on_<role>_container` = the role color darkened (light) or
///   lightened (dark) for legibility on the tint.
/// - `secondary`/`tertiary` default to a desaturated primary analog so the
///   palette stays coherent when only a seed is supplied.
pub fn ColorPalette::from_seed(
  primary~ : Color,
  scheme : ColorScheme,
  foreground? : Color,
  background? : Color,
  surface? : Color,
  surface_variant? : Color,
  outline? : Color,
  muted? : Color,
) -> ColorPalette {
  let (fg, bg, surf, surf_var, outline_color, muted_color) = match scheme {
    Light =>
      (
        foreground.unwrap_or(Color::rgba(r=0.145, g=0.145, b=0.149)),
        background.unwrap_or(Color::rgba(r=1.0, g=1.0, b=1.0)),
        surface.unwrap_or(Color::rgba(r=0.984, g=0.984, b=0.988)),
        surface_variant.unwrap_or(Color::rgba(r=0.957, g=0.957, b=0.961)),
        outline.unwrap_or(Color::rgba(r=0.898, g=0.898, b=0.906)),
        muted.unwrap_or(Color::rgba(r=0.553, g=0.553, b=0.588)),
      )
    Dark =>
      (
        foreground.unwrap_or(Color::rgba(r=0.953, g=0.953, b=0.953)),
        background.unwrap_or(Color::rgba(r=0.090, g=0.090, b=0.090)),
        surface.unwrap_or(Color::rgba(r=0.145, g=0.145, b=0.145)),
        surface_variant.unwrap_or(Color::rgba(r=0.212, g=0.212, b=0.212)),
        outline.unwrap_or(Color::rgba(r=0.290, g=0.290, b=0.290)),
        muted.unwrap_or(Color::rgba(r=0.643, g=0.643, b=0.643)),
      )
  }
  // Contrast-aware on-color for a fill: white on dark fills, near-black on
  // light fills. Uses perceived luminance as the threshold.
  fn on_for(fill : Color) -> Color {
    let lum = fill.r * 0.299 + fill.g * 0.587 + fill.b * 0.114
    if lum < 0.55 {
      Color::white()
    } else {
      Color::rgba(r=0.10, g=0.10, b=0.12)
    }
  }
  // Container tint: fill lerped toward the surface by 0.85.
  fn container_for(fill : Color) -> Color {
    fill.lerp(surf, 0.85)
  }
  // On-container: fill darkened (light scheme) / lightened (dark scheme) for
  // legibility on the soft tint.
  fn on_container_for(fill : Color) -> Color {
    match scheme {
      Light => fill.darken(0.30)
      Dark => fill.lighten(0.35)
    }
  }
  let secondary = primary.lerp(surf, 0.45)
  let tertiary = primary.lerp(
    Color::rgba(r=0.55, g=0.30, b=0.70),
    0.40,
  )
  let error = match scheme {
    Light => Color::rgba(r=0.76, g=0.16, b=0.18)
    Dark => Color::rgba(r=1.0, g=0.52, b=0.50)
  }
  let success = match scheme {
    Light => Color::rgba(r=0.10, g=0.50, b=0.30)
    Dark => Color::rgba(r=0.38, g=0.76, b=0.50)
  }
  let warning = match scheme {
    Light => Color::rgba(r=0.74, g=0.46, b=0.08)
    Dark => Color::rgba(r=0.98, g=0.78, b=0.36)
  }
  let info = primary
  let danger = error
  let focus = primary
  let scrim = match scheme {
    Light => Color::rgba(r=0.0, g=0.0, b=0.0, a=0.38)
    Dark => Color::rgba(r=0.0, g=0.0, b=0.0, a=0.62)
  }
  let outline_variant = match scheme {
    Light => outline_color.lerp(surf, 0.55)
    Dark => outline_color.lerp(surf, 0.45)
  }
  {
    foreground: fg,
    background: bg,
    surface: surf,
    surface_variant: surf_var,
    primary,
    on_primary: on_for(primary),
    primary_container: container_for(primary),
    on_primary_container: on_container_for(primary),
    secondary,
    on_secondary: on_for(secondary),
    secondary_container: container_for(secondary),
    on_secondary_container: on_container_for(secondary),
    tertiary,
    on_tertiary: on_for(tertiary),
    tertiary_container: container_for(tertiary),
    on_tertiary_container: on_container_for(tertiary),
    error,
    on_error: on_for(error),
    error_container: container_for(error),
    on_error_container: on_container_for(error),
    on_foreground: bg,
    on_surface: fg,
    on_surface_variant: muted_color,
    outline: outline_color,
    outline_variant,
    muted: muted_color,
    success,
    on_success: on_for(success),
    warning,
    on_warning: on_for(warning),
    info,
    on_info: on_for(info),
    danger,
    on_danger: on_for(danger),
    focus,
    scrim,
  }
}

///|
/// Minimal light palette (zinc neutrals, near-black primary). Equivalent to
/// the legacy hand-written palette but now fills the full on*/container matrix
/// via `from_seed`.
pub fn ColorPalette::light() -> ColorPalette {
  ColorPalette::from_seed(
    primary=Color::rgba(r=0.145, g=0.145, b=0.149),
    ColorScheme::Light,
  )
}

///|
/// Minimal dark palette (zinc neutrals, near-white primary). Mirrors light.
pub fn ColorPalette::dark() -> ColorPalette {
  ColorPalette::from_seed(
    primary=Color::rgba(r=0.953, g=0.953, b=0.953),
    ColorScheme::Dark,
  )
}

// ---------------------------------------------------------------------------
// Scale defaults
// ---------------------------------------------------------------------------

///|
pub fn SpacingScale::default() -> SpacingScale {
  { xs: 4.0, sm: 8.0, md: 12.0, lg: 16.0, xl: 24.0 }
}

///|
pub fn RadiusScale::default() -> RadiusScale {
  // shadcn/minimal: sharp, small radii. Controls read as crisp rectangles,
  // not soft pills. `pill` retained for chips/badges that need full rounding.
  { sm: 4.0, md: 6.0, lg: 8.0, pill: 999.0 }
}

///|
pub fn TypographyScale::default() -> TypographyScale {
  let label = FontSpec::new(size=16.0, weight=600)
  {
    display: FontSpec::new(size=38.0, weight=600),
    headline: FontSpec::new(size=27.0, weight=600),
    title: FontSpec::new(size=21.0, weight=600),
    subtitle: FontSpec::new(size=18.0, weight=600),
    body: FontSpec::new(size=16.0, weight=400),
    label,
    caption: FontSpec::new(size=13.0, weight=400),
    overline: FontSpec::new(size=11.0, weight=600),
    // `control` is the historical name for emphasized control text; alias it
    // to `label` so existing callers keep the same visuals.
    control: label,
  }
}

///|
pub fn ShadowScale::default(
  scheme? : ColorScheme = ColorScheme::Light,
) -> ShadowScale {
  // shadcn/minimal: near-zero shadows by default. Cards and buttons rely on
  // borders, not elevation. `sm` stays flat so controls read as crisp
  // rectangles. `md` carries a hair of depth so floating mid layers (picker
  // popups, feedback panels) separate without imposing Material-style
  // elevation. `lg` (popovers/dialogs/menus) uses a soft, diffuse shadow so
  // floating layers lift gently rather than reading as a hard drop.
  let alpha = match scheme {
    Light => 0.06
    Dark => 0.50
  }
  {
    sm: ShadowStyle::new(
      color=Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha * 0.5),
      offset=Point::new(x=0.0, y=0.0),
      blur_radius=0.0,
    ),
    md: ShadowStyle::new(
      color=Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha),
      offset=Point::new(x=0.0, y=2.0),
      blur_radius=8.0,
    ),
    lg: ShadowStyle::new(
      color=Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha * 1.4),
      offset=Point::new(x=0.0, y=2.0),
      blur_radius=16.0,
      spread=0.0,
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
  ignore(scheme)
  // shadcn/minimal: flat solid surfaces, no gradients. Layer separation comes
  // from border tone, not surface sheen. Raised = surface, overlay = variant.
  {
    base: Brush::solid(palette.surface),
    raised: Brush::solid(palette.surface),
    overlay: Brush::solid(palette.surface_variant),
  }
}

// ---------------------------------------------------------------------------
// Theme factories
// ---------------------------------------------------------------------------

///|
/// Neutral fallback theme. Equivalent to resolving `ThemeSpec::default()` with
/// a light system scheme. Carries default `ComponentThemes` derived from the
/// minimal palette.
pub fn Theme::neutral() -> Theme {
  resolve_minimal_theme(ThemeSpec::minimal_light(), ColorScheme::Light)
}

///|
pub fn Theme::with_palette(self : Theme, palette : ColorPalette) -> Theme {
  let surfaces = SurfaceScale::default(palette, self.scheme)
  { ..self, palette, surfaces }
}

///|
pub fn Theme::with_spacing_scale(
  self : Theme,
  spacing_scale : SpacingScale,
) -> Theme {
  { ..self, spacing_scale }
}

///|
pub fn Theme::with_radius_scale(
  self : Theme,
  radius_scale : RadiusScale,
) -> Theme {
  { ..self, radius_scale }
}

///|
pub fn Theme::with_typography(
  self : Theme,
  typography : TypographyScale,
) -> Theme {
  { ..self, typography }
}

///|
pub fn Theme::with_shadow_scale(
  self : Theme,
  shadow_scale : ShadowScale,
) -> Theme {
  { ..self, shadow_scale }
}

///|
pub fn Theme::with_motion(self : Theme, motion : MotionScale) -> Theme {
  { ..self, motion }
}

///|
pub fn Theme::with_surfaces(self : Theme, surfaces : SurfaceScale) -> Theme {
  { ..self, surfaces }
}

///|
pub fn Theme::surface_brush(self : Theme, level : SurfaceLevel) -> Brush {
  match level {
    Base => self.surfaces.base
    Raised => self.surfaces.raised
    Overlay => self.surfaces.overlay
  }
}

// ---------------------------------------------------------------------------
// Environment factories
// ---------------------------------------------------------------------------

///|
/// Neutral environment: Minimal theme following a light system scheme, standard
/// density/contrast, full motion. The `theme_spec` records the intent so a
/// later `ThemeChanged(Dark)` event rebuilds the full dark theme instead of
/// leaving a stale light palette.
pub fn Environment::neutral() -> Environment {
  let spec = ThemeSpec::default()
  let theme = resolve_minimal_theme(spec, ColorScheme::Light)
  {
    theme_spec: spec,
    system_scheme: ColorScheme::Light,
    theme,
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
/// Replace the theme. Also updates `system_scheme` to match the theme's scheme
/// so the two stay consistent. Use `with_theme_spec` + `with_system_scheme`
/// for the resolver-driven path; this helper is for callers that already have
/// a fully resolved `Theme` (e.g. a branded addon that built one directly).
pub fn Environment::with_theme(
  self : Environment,
  theme : Theme,
) -> Environment {
  { ..self, theme, system_scheme: theme.scheme }
}

///|
/// Replace the system color scheme and rebuild the full theme from
/// `theme_spec`. This is the host-facing entry point: a `ThemeChanged(Dark)`
/// event calls this so the palette/surfaces/shadows actually switch to dark,
/// fixing the old bug where only the scheme flag flipped.
pub fn Environment::with_system_scheme(
  self : Environment,
  system_scheme : ColorScheme,
) -> Environment {
  let theme = resolve_theme(self.theme_spec, system_scheme)
  { ..self, system_scheme, theme }
}

///|
/// Replace the theme spec and rebuild the full theme against the current
/// system scheme. App code calls this when the user picks a new preset,
/// density, or contrast.
pub fn Environment::with_theme_spec(
  self : Environment,
  theme_spec : ThemeSpec,
) -> Environment {
  let theme = resolve_theme(theme_spec, self.system_scheme)
  { ..self, theme_spec, theme }
}

///|
/// Read the effective color scheme (from the resolved theme). Kept as a
/// convenience accessor so callers do not have to reach into `theme.scheme`.
pub fn Environment::color_scheme(self : Environment) -> ColorScheme {
  self.theme.scheme
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
  { ..self, locale }
}

///|
pub fn Environment::with_layout_direction(
  self : Environment,
  layout_direction : LayoutDirection,
) -> Environment {
  { ..self, layout_direction }
}

///|
/// Update accessibility contrast. Also updates `theme_spec.contrast` so a
/// subsequent system-scheme change re-resolves with the new contrast.
pub fn Environment::with_accessibility_contrast(
  self : Environment,
  accessibility_contrast : AccessibilityContrast,
) -> Environment {
  let spec = self.theme_spec.with_contrast(accessibility_contrast)
  self.with_theme_spec(spec)
}

///|
/// Update reduced motion. Also updates `theme_spec.reduced_motion` so a
/// subsequent re-resolve zeroes motion durations.
pub fn Environment::with_reduced_motion(
  self : Environment,
  reduced_motion : Bool,
) -> Environment {
  let spec = self.theme_spec.with_reduced_motion(reduced_motion)
  self.with_theme_spec(spec)
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
  { ..self, enabled }
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
    font: Some(theme.typography.body),
    foreground: Some(theme.palette.foreground),
    background: Some(theme.surface_brush(SurfaceLevel::Base)),
    corner_radius: Some(theme.radius_scale.md),
  }
}

///|
/// Content fingerprint for a `Theme`, used by `View::theme` modifier revision
/// so reconcile can detect a real theme change (different palette/components)
/// instead of treating every `.theme(...)` wrapper as identical. Covers scheme,
/// the palette colors a paint pass reads, and the button/text-field component
/// tokens that drive control appearance; this is not a full hash, just enough
/// fields to distinguish visually distinct themes.
pub fn Theme::revision_fingerprint(self : Theme) -> String {
  let p = self.palette
  let b = self.components.button.primary
  "theme:\{scheme_label(self.scheme)}:fg:\{color_fp(p.foreground)}:bg:\{color_fp(p.background)}:sf:\{color_fp(p.surface)}:sv:\{color_fp(p.surface_variant)}:pr:\{color_fp(p.primary)}:op:\{color_fp(p.on_primary)}:ol:\{color_fp(p.outline)}:mt:\{color_fp(p.muted)}:sc:\{color_fp(p.success)}:wn:\{color_fp(p.warning)}:dg:\{color_fp(p.danger)}:if:\{color_fp(p.info)}:fc:\{color_fp(p.focus)}:bp:\{color_fp(b.foreground)}:\{color_fp(b.background)}:\{b.radius}:r:\{self.radius_scale.md}:sm:\{self.shadow_scale.md.blur_radius}"
}

///|
/// Content fingerprint for an `Environment`, used by `View::environment`
/// modifier revision. Combines the theme fingerprint with the a11y/motion
/// fields that change paint output so a state-layer or reduced-motion change
/// is not swallowed by reconcile.
pub fn Environment::revision_fingerprint(self : Environment) -> String {
  "env:\{self.theme.revision_fingerprint()}:sys:\{scheme_label(self.system_scheme)}:ct:\{contrast_label(self.accessibility_contrast)}:rm:\{self.reduced_motion}:en:\{self.enabled}:ts:\{self.text_scale}:sf:\{self.scale_factor}"
}

///|
fn scheme_label(scheme : ColorScheme) -> String {
  match scheme {
    Light => "light"
    Dark => "dark"
  }
}

///|
fn contrast_label(contrast : AccessibilityContrast) -> String {
  match contrast {
    Standard => "std"
    High => "high"
  }
}

///|
fn color_fp(color : Color) -> String {
  "\{color.r}:\{color.g}:\{color.b}:\{color.a}"
}
