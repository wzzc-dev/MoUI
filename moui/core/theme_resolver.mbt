///|
/// Theme resolver. Turns a `ThemeSpec` plus the current system color scheme
/// into a fully resolved, drawable neutral `Theme` (palette + scales +
/// surfaces + motion).
///
/// `core` only resolves the `Minimal` preset itself. Branded presets
/// (Material/Carbon/Primer/Fluent) are resolved by the `moui_theme` addon,
/// which calls `resolve_minimal_theme` for the base scales and then overlays
/// its own palette. Concrete control theme tokens are **not** produced here;
/// they live in `moui/views` as `ControlThemeSet` (ADR 0017) and are resolved
/// views-side from this neutral `Theme`. The resolver is the single place
/// that applies density scaling, contrast adjustment, and reduced-motion
/// zeroing, so every path that rebuilds a theme (host `ThemeChanged`, app
/// preset switch, a11y change) gets consistent post-processing.

///|
/// Resolve a `ThemeSpec` against a system color scheme. For branded presets
/// this resolves the Minimal base; branded addons must call
/// `resolve_minimal_theme` and then replace the palette themselves. Component
/// themes are resolved views-side as a `ControlThemeSet`.
pub fn resolve_theme(spec : ThemeSpec, system_scheme : ColorScheme) -> Theme {
  // `core` only owns Minimal. Branded presets are resolved by the addon; if a
  // branded spec reaches here (e.g. the addon is not linked), fall back to
  // Minimal so the app still renders.
  resolve_minimal_theme(spec, system_scheme)
}

///|
/// Resolve the Minimal preset. This is the canonical resolver: it picks the
/// palette by scheme, applies density to spacing, applies contrast adjustment,
/// zeroes motion when reduced motion is requested, and assembles the neutral
/// scales/surfaces. Concrete control theme tokens are **not** produced here;
/// they live in `moui/views` as `ControlThemeSet` (ADR 0017) and are resolved
/// views-side from this neutral `Theme`.
pub fn resolve_minimal_theme(
  spec : ThemeSpec,
  system_scheme : ColorScheme,
) -> Theme {
  let scheme = spec.resolve_scheme(system_scheme)
  let palette = match spec.seed {
    Some(seed) => ColorPalette::from_seed(primary=seed, scheme)
    None =>
      match scheme {
        Light => ColorPalette::light()
        Dark => ColorPalette::dark()
      }
  }
  // High-contrast override: pure black/white surfaces with thick outlines.
  let palette = match spec.contrast {
    High => high_contrast_palette(palette, scheme)
    Standard => palette
  }
  let spacing_scale = apply_density(SpacingScale::default(), spec.density)
  let radius_scale = RadiusScale::default()
  let typography = TypographyScale::default()
  let shadow_scale = ShadowScale::default(scheme~)
  let motion = match spec.reduced_motion {
    true =>
      { ..MotionScale::default(), fast_ms: 0.0, normal_ms: 0.0, slow_ms: 0.0 }
    false => MotionScale::default()
  }
  let surfaces = SurfaceScale::default(palette, scheme)
  {
    scheme,
    palette,
    spacing_scale,
    radius_scale,
    typography,
    shadow_scale,
    motion,
    surfaces,
  }
}

///|
fn apply_density(base : SpacingScale, density : ThemeDensity) -> SpacingScale {
  let m = density.multiplier()
  {
    xs: base.xs * m,
    sm: base.sm * m,
    md: base.md * m,
    lg: base.lg * m,
    xl: base.xl * m,
  }
}

///|
/// High-contrast palette: snap surfaces to pure black/white, outlines to the
/// foreground, and semantic colors to their maximum-saturation forms so edges
/// and state stay legible regardless of the base palette's subtle alphas.
fn high_contrast_palette(
  palette : ColorPalette,
  scheme : ColorScheme,
) -> ColorPalette {
  match scheme {
    Light =>
      {
        ..palette,
        background: Color::white(),
        surface: Color::white(),
        surface_variant: Color::rgba(r=0.92, g=0.92, b=0.92),
        foreground: Color::black(),
        on_surface: Color::black(),
        on_surface_variant: Color::rgba(r=0.22, g=0.22, b=0.22),
        outline: Color::black(),
        outline_variant: Color::black(),
        scrim: Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0),
        success: Color::rgba(r=0.00, g=0.42, b=0.12),
        warning: Color::rgba(r=0.62, g=0.36, b=0.00),
        danger: Color::rgba(r=0.75, g=0.00, b=0.00),
        info: Color::rgba(r=0.00, g=0.24, b=0.86),
      }
    Dark =>
      {
        ..palette,
        background: Color::black(),
        surface: Color::black(),
        surface_variant: Color::rgba(r=0.10, g=0.10, b=0.10),
        foreground: Color::white(),
        on_surface: Color::white(),
        on_surface_variant: Color::rgba(r=0.82, g=0.82, b=0.82),
        outline: Color::white(),
        outline_variant: Color::white(),
        scrim: Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0),
        success: Color::rgba(r=0.58, g=1.0, b=0.58),
        warning: Color::rgba(r=1.0, g=0.86, b=0.30),
        danger: Color::rgba(r=1.0, g=0.58, b=0.58),
        info: Color::rgba(r=0.48, g=0.82, b=1.0),
      }
  }
}
