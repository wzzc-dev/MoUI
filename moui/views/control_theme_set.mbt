///|
/// View-owned control theme aggregate (ADR 0017). Replaces `core.ComponentThemes`
/// so `core.Theme` carries only neutral palette/typography/spacing/motion/
/// surfaces. Apps and branded addons (`moui_theme/*`) set a `ControlThemeSet`
/// once; every control inherits it. Controls resolve variant/state at paint
/// time via the `resolve` methods on `control_theme_tokens.mbt`.
///
/// Resolution: `minimal_control_theme_set(theme)` derives the default neutral
/// control tokens from a resolved neutral `core.Theme` (palette + scales).
/// Branded addons call it for the base then overlay their own tokens.

///|
/// First-class component theme aggregate owned by `moui/views`. Each field is a
/// per-control token set; controls resolve variant/state at paint time. An app
/// that wants a branded design system sets this once on the root environment
/// (via the ambient resolver) and every control inherits it.
pub(all) struct ControlThemeSet {
  button : ButtonTheme
  text_field : TextFieldTheme
  surface : SurfaceTheme
  choice_control : ChoiceControlTheme
  progress : ProgressTheme
  slider : SliderTheme
  picker : PickerTheme
  feedback : FeedbackTheme
  badge : BadgeTheme
  form_validation : FormValidationTheme
} derive(Eq, Debug, ToJson)

///|
/// Derive the default neutral `ControlThemeSet` for the Minimal preset from a
/// resolved neutral `core.Theme`. This mirrors the neutral control styles the
/// legacy `@views.ButtonStyle::filled/tonal/outline/ghost` helpers produced,
/// but expressed as token sets so controls can resolve variant/state at paint
/// time without a `style?` argument. Branded addons call this for the base and
/// then overlay their own tokens.
pub fn minimal_control_theme_set(
  theme : @core.Theme,
) -> ControlThemeSet {
  let palette = theme.palette
  let scheme = theme.scheme
  let spacing = theme.spacing_scale
  let radius = theme.radius_scale
  let typography = theme.typography
  let transparent = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
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
  let progress : ProgressTheme = {
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
  let picker : PickerTheme = {
    font: typography.control,
    foreground: palette.foreground,
    background: @core.Brush::solid(palette.surface),
    radius: radius.md,
    popup_max_height: 200.0,
  }
  let feedback_background_alpha = match scheme {
    Light => 0.14
    Dark => 0.24
  }
  let feedback : FeedbackTheme = {
    neutral: tone_tokens(palette.muted, feedback_background_alpha, 0.78),
    info: tone_tokens(palette.info, feedback_background_alpha, 0.78),
    success: tone_tokens(palette.success, feedback_background_alpha, 0.78),
    warning: tone_tokens(palette.warning, feedback_background_alpha, 0.78),
    danger: tone_tokens(palette.danger, feedback_background_alpha, 0.78),
    radius: radius.md,
    padding: spacing.sm,
  }
  let badge_neutral : ToneTokens = {
    foreground: palette.foreground,
    background: palette.surface_variant,
    border: palette.outline.multiply_alpha(0.42),
  }
  let badge : BadgeTheme = {
    neutral: badge_neutral,
    accent: tone_tokens(palette.info, 1.0, 1.0),
    success: tone_tokens(palette.success, 1.0, 1.0),
    warning: tone_tokens(palette.warning, 1.0, 1.0),
    danger: tone_tokens(palette.danger, 1.0, 1.0),
    radius: radius.pill,
    padding: 3.0,
  }
  let form_validation : FormValidationTheme = {
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
fn minimal_state_layer(palette : @core.ColorPalette) -> StateLayerTokens {
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
  foreground : @core.Color,
  background_alpha : Double,
  border_alpha : Double,
) -> ToneTokens {
  {
    foreground,
    background: foreground.multiply_alpha(background_alpha),
    border: foreground.multiply_alpha(border_alpha),
  }
}

///|
/// Resolve the views-owned `ControlThemeSet` for a neutral `core.Theme`,
/// falling back to the neutral theme when none is supplied. Composite
/// views use this for construction-time reads; leaf children resolve
/// variant/state at paint time against the ambient `ControlThemeSet`.
fn views_ambient_control_theme(
  theme : @core.Theme,
) -> ControlThemeSet {
  minimal_control_theme_set(theme)
}
