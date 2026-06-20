///|
/// Theme resolver. Turns a `ThemeSpec` plus the current system color scheme
/// into a fully resolved, drawable `Theme` (palette + scales + components).
///
/// `core` only resolves the `Minimal` preset itself. Branded presets
/// (Material/Carbon/Primer/Fluent) are resolved by the `moui_theme` addon,
/// which calls `resolve_minimal_theme` for the base scales and then overlays
/// its own palette/components. The resolver is the single place that applies
/// density scaling, contrast adjustment, and reduced-motion zeroing, so every
/// path that rebuilds a theme (host `ThemeChanged`, app preset switch, a11y
/// change) gets consistent post-processing.

///|
/// Resolve a `ThemeSpec` against a system color scheme. For branded presets
/// this resolves the Minimal base; branded addons must call
/// `resolve_minimal_theme` and then replace the palette/components themselves.
pub fn resolve_theme(spec : ThemeSpec, system_scheme : ColorScheme) -> Theme {
  // `core` only owns Minimal. Branded presets are resolved by the addon; if a
  // branded spec reaches here (e.g. the addon is not linked), fall back to
  // Minimal so the app still renders.
  resolve_minimal_theme(spec, system_scheme)
}

///|
/// Resolve the Minimal preset. This is the canonical resolver: it picks the
/// palette by scheme, applies density to spacing, applies contrast adjustment,
/// zeroes motion when reduced motion is requested, and derives default
/// `ComponentThemes` from the resolved palette.
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
    true => { ..MotionScale::default(), fast_ms: 0.0, normal_ms: 0.0, slow_ms: 0.0 }
    false => MotionScale::default()
  }
  let surfaces = SurfaceScale::default(palette, scheme)
  let components = minimal_components(palette, scheme, spacing_scale, radius_scale, typography)
  {
    scheme,
    palette,
    spacing_scale,
    radius_scale,
    typography,
    shadow_scale,
    motion,
    surfaces,
    components,
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
fn high_contrast_palette(palette : ColorPalette, scheme : ColorScheme) -> ColorPalette {
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

///|
/// Derive default `ComponentThemes` for the Minimal preset from a palette +
/// scales. This mirrors the neutral control styles the legacy
/// `@views.ButtonStyle::filled/tonal/outline/ghost` helpers produced, but
/// expressed as token sets so controls can resolve variant/state at paint time
/// without a `style?` argument.
fn minimal_components(
  palette : ColorPalette,
  scheme : ColorScheme,
  spacing : SpacingScale,
  radius : RadiusScale,
  typography : TypographyScale,
) -> ComponentThemes {
  let transparent = Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  let state_layer = minimal_state_layer(palette)
  let button = {
    primary: ControlStateTokens::new(
      foreground=palette.on_primary,
      background=palette.primary,
      border=palette.primary,
      border_width=0.0,
      radius=radius.md,
    ),
    tonal: ControlStateTokens::new(
      foreground=palette.primary,
      background=palette.surface.lerp(palette.primary, 0.12),
      border=palette.surface_variant,
      border_width=0.0,
      radius=radius.md,
    ),
    outline: ControlStateTokens::new(
      foreground=palette.foreground,
      background=transparent,
      border=palette.outline.multiply_alpha(0.8),
      border_width=1.0,
      radius=radius.md,
    ),
    ghost: ControlStateTokens::new(
      foreground=palette.foreground,
      background=transparent,
      border=transparent,
      border_width=0.0,
      radius=radius.md,
    ),
    // Minimal aliases subtle/subtle-brand to ghost/tonal so the 6-variant
    // surface stays uniform; Fluent fills them distinctly.
    subtle: ControlStateTokens::new(
      foreground=palette.foreground,
      background=transparent,
      border=transparent,
      border_width=0.0,
      radius=radius.md,
    ),
    subtle_brand: ControlStateTokens::new(
      foreground=palette.primary,
      background=transparent,
      border=transparent,
      border_width=0.0,
      radius=radius.md,
    ),
    state_layer,
  }
  let text_field = {
    normal: ControlStateTokens::new(
      foreground=palette.foreground,
      background=palette.surface,
      border=palette.outline.multiply_alpha(0.85),
      border_width=1.0,
      radius=radius.md,
    ),
    focused: ControlStateTokens::new(
      foreground=palette.foreground,
      background=palette.surface,
      border=palette.focus,
      border_width=2.0,
      radius=radius.md,
    ),
    disabled: ControlStateTokens::new(
      foreground=palette.muted,
      background=palette.surface_variant,
      border=palette.outline.multiply_alpha(0.38),
      border_width=1.0,
      radius=radius.md,
    ),
    placeholder: palette.muted,
    cursor: palette.focus,
    font: typography.body,
    appearance: TextFieldAppearance::Outline,
  }
  let surface = {
    base_padding: spacing.md,
    raised_padding: spacing.lg,
    overlay_padding: spacing.md,
    base_radius: radius.md,
    raised_radius: radius.lg,
    overlay_radius: radius.lg,
    base_shadow: None,
    raised_shadow: None,
    overlay_shadow: None,
  }
  let choice_control = {
    foreground: palette.foreground,
    selected_color: palette.primary,
    disabled_foreground: palette.muted,
    disabled_selected_color: palette.primary.multiply_alpha(0.42),
    control_size: 20.0,
    box_shape: ChoiceControlShape::Square,
    check_style: CheckMarkStyle::Checkmark,
  }
  let progress = {
    foreground: palette.primary,
    background: palette.surface_variant,
    radius: radius.pill,
  }
  let slider = {
    foreground: palette.primary,
    background: palette.surface_variant,
    thumb_color: palette.primary,
    track_height: 4.0,
    thumb_size: 18.0,
    radius: radius.pill,
    thumb_shape: ThumbShape::Circle,
  }
  let picker = {
    font: typography.control,
    foreground: palette.foreground,
    background: Brush::solid(palette.surface),
    radius: radius.md,
    popup_max_height: 200.0,
  }
  let feedback_background_alpha = match scheme {
    Light => 0.14
    Dark => 0.24
  }
  let feedback = {
    neutral: tone_tokens(palette.muted, feedback_background_alpha, 0.78),
    info: tone_tokens(palette.info, feedback_background_alpha, 0.78),
    success: tone_tokens(palette.success, feedback_background_alpha, 0.78),
    warning: tone_tokens(palette.warning, feedback_background_alpha, 0.78),
    danger: tone_tokens(palette.danger, feedback_background_alpha, 0.78),
    radius: radius.md,
    padding: spacing.sm,
  }
  let badge = {
    neutral: {
      foreground: palette.foreground,
      background: palette.surface_variant,
      border: palette.outline.multiply_alpha(0.42),
    },
    accent: tone_tokens(palette.info, 1.0, 1.0),
    success: tone_tokens(palette.success, 1.0, 1.0),
    warning: tone_tokens(palette.warning, 1.0, 1.0),
    danger: tone_tokens(palette.danger, 1.0, 1.0),
    radius: radius.pill,
    padding: 3.0,
  }
  let form_validation = {
    foreground: palette.danger,
    background: palette.danger.multiply_alpha(0.12),
    border: palette.danger.multiply_alpha(0.72),
    radius: radius.md,
    padding: spacing.md,
  }
  {
    button,
    text_field,
    surface,
    choice_control,
    progress,
    slider,
    picker,
    feedback,
    badge,
    form_validation,
  }
}

///|
fn minimal_state_layer(palette : ColorPalette) -> StateLayerTokens {
  {
    color: palette.primary,
    hover_alpha: 0.08,
    focus_alpha: 0.12,
    pressed_alpha: 0.12,
    dragged_alpha: 0.16,
    selected_alpha: 0.10,
    disabled_alpha: 0.38,
  }
}

///|
fn tone_tokens(
  foreground : Color,
  background_alpha : Double,
  border_alpha : Double,
) -> ToneTokens {
  {
    foreground,
    background: foreground.multiply_alpha(background_alpha),
    border: foreground.multiply_alpha(border_alpha),
  }
}
