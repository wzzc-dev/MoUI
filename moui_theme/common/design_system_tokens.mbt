///|
pub(all) enum DesignDensity {
  Compact
  Standard
  Comfortable
} derive(Eq, Debug, ToJson)

///|
/// Variant of a design-system theme resolved against a system color scheme.
/// Construction-surface enum (lives in `common` because `DesignSystemTokens.variant`
/// and `tokens_for_variant` consume it); audit records reference it via `@common`.
pub(all) enum DesignSchemeVariant {
  SchemeLight
  SchemeDark
  SchemeHighContrast
  SchemeSystem
} derive(Eq, Debug, ToJson)

///|

///|
/// Design-system semantic palette. Extended with a neutral background/foreground/
/// stroke ramp so Fluent 2 (and any system with layered neutral surfaces) can
/// express `colorNeutralBackground1/2/3`, `colorNeutralForeground1/2`, and
/// `colorNeutralStroke1/2` distinctly instead of collapsing them into a single
/// `surface`/`surface_variant` pair. Presets that do not need the full ramp
/// alias the tiers (e.g. background2 = background1) via their palette builder.
pub(all) struct DesignSemanticPalette {
  foreground : @core.Color
  background : @core.Color
  surface : @core.Color
  surface_variant : @core.Color
  // Neutral background ramp. background1 = app canvas, background2 = card,
  // background3 = raised/flyout. Presets without a ramp set all three equal
  // to `background`/`surface`.
  background_2 : @core.Color
  background_3 : @core.Color
  // Neutral foreground ramp. foreground1 = primary text, foreground2 = secondary
  // text. Presets without a ramp set foreground2 = foreground.
  foreground_2 : @core.Color
  // Neutral stroke ramp. stroke1 = strong control border, stroke2 = subtle
  // divider. Presets without a ramp set both to `outline`.
  stroke_1 : @core.Color
  stroke_2 : @core.Color
  // Brand stroke (distinct from brand fill). Fluent 2 separates
  // colorBrandBackground from colorBrandStroke1. Presets without a separate
  // brand stroke set this to `primary`.
  brand_stroke : @core.Color
  // colorNeutralBackground4 (subtle inset / toolbar). Presets without a ramp
  // alias this to `background_3`.
  background_4 : @core.Color
  // colorNeutralStrokeAccessible (stronger than stroke_1, used for high-contrast
  // control borders). Presets without a ramp alias this to `stroke_1`.
  stroke_accessible : @core.Color
  primary : @core.Color
  primary_foreground : @core.Color
  outline : @core.Color
  muted : @core.Color
  success : @core.Color
  warning : @core.Color
  danger : @core.Color
  info : @core.Color
  focus : @core.Color
  scrim : @core.Color
} derive(Eq, Debug, ToJson)

///|
/// Extended typography tiers matching Fluent 2 / Material 3 type ramps beyond
/// the legacy body/title/caption/control four. Presets that do not define a
/// full ramp leave these `None`; `core_typography` falls back to derived
/// values from the four base tiers.
pub(all) struct DesignTypographyTokens {
  body : @core.FontSpec
  title : @core.FontSpec
  caption : @core.FontSpec
  control : @core.FontSpec
  // Fluent 2 type ramp: subtitle1 (20/600), title1 (28/600), title2 (24/600),
  // body1_strong (14/600), caption2 (12/600). `None` means derive from base.
  subtitle : @core.FontSpec?
  title_large : @core.FontSpec?
  title_medium : @core.FontSpec?
  body_strong : @core.FontSpec?
  caption_strong : @core.FontSpec?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSpacingTokens {
  xs : Double
  sm : Double
  md : Double
  lg : Double
  xl : Double
  density_multiplier : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignRadiusTokens {
  sm : Double
  md : Double
  lg : Double
  pill : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignElevationTokens {
  sm : @core.ShadowStyle
  md : @core.ShadowStyle
  lg : @core.ShadowStyle
  // Fluent 2 shadow tiers (shadow2/4/8/16/28/64). Neutral presets leave these
  // `None`; Fluent fills them from the pinned source ramp so cards, flyouts,
  // and dialogs carry distinct layered shadows instead of a single `lift`.
  card : @core.ShadowStyle?
  flyout : @core.ShadowStyle?
  dialog : @core.ShadowStyle?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignMotionTokens {
  fast_ms : Double
  normal_ms : Double
  slow_ms : Double
  easing : @core.Easing
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSurfaceTokens {
  base : @core.Brush
  raised : @core.Brush
  overlay : @core.Brush
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignStateLayerTokens {
  color : @core.Color
  hover_alpha : Double
  focus_alpha : Double
  pressed_alpha : Double
  dragged_alpha : Double
  selected_alpha : Double
  disabled_alpha : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignControlStateTokens {
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
  border_width : Double
  radius : Double
  state_layer_alpha : Double
  // Fluent 2 underline inputs render only the bottom edge; neutral for other
  // systems which always draw a full border.
  bottom_border_only : Bool
  // Fluent 2 focus "reveal" paints an inner stroke inside the control frame.
  // `None` means no inner focus border (the neutral default).
  inner_focus_border : @core.Color?
} derive(Eq, Debug, ToJson)

///|
/// TextField appearance tier. Fluent 2 ships an underline variant; the neutral
/// default is `Outline` so existing presets keep their full-border behavior.
pub(all) enum DesignTextFieldAppearance {
  Filled
  Outline
  Underline
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignButtonTokens {
  primary : DesignControlStateTokens
  tonal : DesignControlStateTokens
  outline : DesignControlStateTokens
  ghost : DesignControlStateTokens
  // Fluent 2 subtle / subtle-brand variants. Neutral presets alias these to
  // `ghost`/`tonal` so the shared builder keeps a uniform 4-variant surface.
  subtle : DesignControlStateTokens
  subtle_brand : DesignControlStateTokens
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignTextFieldTokens {
  normal : DesignControlStateTokens
  focused : DesignControlStateTokens
  disabled : DesignControlStateTokens
  placeholder : @core.Color
  cursor : @core.Color
  font : @core.FontSpec
  // Fluent 2 declares an underline appearance; neutral presets use `Outline`.
  appearance : DesignTextFieldAppearance
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSurfaceComponentTokens {
  base_padding : Double
  raised_padding : Double
  overlay_padding : Double
  base_radius : Double
  raised_radius : Double
  overlay_radius : Double
  // Per-tier elevation binding. Fluent 2 cards carry distinct shadows per
  // layer (shadow2/4/28); neutral presets leave these `None` and rely on the
  // flat surface idiom.
  base_shadow : @core.ShadowStyle?
  raised_shadow : @core.ShadowStyle?
  overlay_shadow : @core.ShadowStyle?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignChoiceControlTokens {
  foreground : @core.Color
  selected_color : @core.Color
  disabled_foreground : @core.Color
  disabled_selected_color : @core.Color
  control_size : Double
  box_shape : @views.ChoiceControlShape
  check_style : @views.CheckMarkStyle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignProgressTokens {
  foreground : @core.Color
  background : @core.Color
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSliderTokens {
  foreground : @core.Color
  background : @core.Color
  thumb_color : @core.Color
  track_height : Double
  thumb_size : Double
  radius : Double
  thumb_shape : @views.ThumbShape
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignPickerTokens {
  font : @core.FontSpec
  foreground : @core.Color
  background : @core.Brush
  radius : Double
  popup_max_height : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignToneTokens {
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignFeedbackTokens {
  neutral : DesignToneTokens
  info : DesignToneTokens
  success : DesignToneTokens
  warning : DesignToneTokens
  danger : DesignToneTokens
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignBadgeTokens {
  neutral : DesignToneTokens
  accent : DesignToneTokens
  success : DesignToneTokens
  warning : DesignToneTokens
  danger : DesignToneTokens
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignFormValidationTokens {
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignComponentTokens {
  button : DesignButtonTokens
  text_field : DesignTextFieldTokens
  surface : DesignSurfaceComponentTokens
  choice_control : DesignChoiceControlTokens
  progress : DesignProgressTokens
  slider : DesignSliderTokens
  picker : DesignPickerTokens
  date_picker : DesignPickerTokens
  feedback : DesignFeedbackTokens
  badge : DesignBadgeTokens
  form_validation : DesignFormValidationTokens
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignButtonCoreStyles {
  primary : @views.ButtonStyle
  tonal : @views.ButtonStyle
  outline : @views.ButtonStyle
  ghost : @views.ButtonStyle
  subtle : @views.ButtonStyle
  subtle_brand : @views.ButtonStyle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignTextFieldCoreStyles {
  filled : @views.TextFieldStyle
  outline : @views.TextFieldStyle
  plain : @views.TextFieldStyle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSurfaceCoreStyles {
  base : @views.SurfaceStyle
  raised : @views.SurfaceStyle
  overlay : @views.SurfaceStyle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignCoreComponentStyles {
  button : DesignButtonCoreStyles
  text_field : DesignTextFieldCoreStyles
  surface : DesignSurfaceCoreStyles
  choice_control : @views.ChoiceControlStyle
  progress : @views.ProgressStyle
  slider : @views.SliderStyle
  picker : @views.PickerStyle
  date_picker : @views.PickerStyle
  feedback : @views.FeedbackStyle
  badge : @views.BadgeStyle
  form_validation : @views.FormValidationStyle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSystemTokens {
  preset : DesignPreset
  scheme : @core.ColorScheme
  variant : DesignSchemeVariant
  density : DesignDensity
  source_family : String
  palette : DesignSemanticPalette
  typography : DesignTypographyTokens
  spacing : DesignSpacingTokens
  radius : DesignRadiusTokens
  elevation : DesignElevationTokens
  motion : DesignMotionTokens
  surfaces : DesignSurfaceTokens
  state_layer : DesignStateLayerTokens
  components : DesignComponentTokens
} derive(Eq, Debug, ToJson)

///|
pub fn DesignDensity::label(self : DesignDensity) -> String {
  match self {
    Compact => "compact"
    Standard => "standard"
    Comfortable => "comfortable"
  }
}

///|
pub fn DesignDensity::multiplier(self : DesignDensity) -> Double {
  match self {
    Compact => 0.82
    Standard => 1.0
    Comfortable => 1.18
  }
}

///|
pub fn DesignSchemeVariant::label(self : DesignSchemeVariant) -> String {
  match self {
    SchemeLight => "light"
    SchemeDark => "dark"
    SchemeHighContrast => "high contrast"
    SchemeSystem => "system"
  }
}

///|
/// Project the design-system semantic palette onto a full `@core.ColorPalette`.
/// Uses `ColorPalette::from_seed` to derive the complete on*/container matrix,
/// then overrides every role the design-system palette owns explicitly. This
/// replaces the legacy 8-field `palette()` helper and the separate
/// `core_semantic_colors()` projection (semantic colors now live on the
/// palette itself).
pub fn DesignSemanticPalette::core_palette(
  self : DesignSemanticPalette,
  scheme : @core.ColorScheme,
) -> @core.ColorPalette {
  {
    ..@core.ColorPalette::from_seed(primary=self.primary, scheme),
    foreground: self.foreground,
    background: self.background,
    // Map the neutral background ramp onto the palette surface tiers:
    // surface = background_2 (card), surface_variant = background_3 (raised).
    surface: self.background_2,
    surface_variant: self.background_3,
    on_surface: self.foreground,
    on_surface_variant: self.foreground_2,
    primary: self.primary,
    on_primary: self.primary_foreground,
    // stroke_1 = strong control border, stroke_2 = subtle divider.
    outline: self.stroke_1,
    outline_variant: self.stroke_2,
    muted: self.muted,
    success: self.success,
    on_success: contrast_on(self.success),
    warning: self.warning,
    on_warning: contrast_on(self.warning),
    info: self.info,
    on_info: contrast_on(self.info),
    danger: self.danger,
    on_danger: contrast_on(self.danger),
    error: self.danger,
    on_error: contrast_on(self.danger),
    focus: self.focus,
    scrim: self.scrim,
  }
}

///|
/// Pick white or near-black for text drawn on top of `fill`, by perceived
/// luminance. Mirrors the derivation in `core`'s `ColorPalette::from_seed`.
fn contrast_on(fill : @core.Color) -> @core.Color {
  let lum = fill.r * 0.299 + fill.g * 0.587 + fill.b * 0.114
  if lum < 0.55 {
    @core.Color::white()
  } else {
    @core.Color::rgba(r=0.10, g=0.10, b=0.12)
  }
}

///|
pub fn DesignTypographyTokens::core_typography(
  self : DesignTypographyTokens,
) -> @core.TypographyScale {
  // Start from the neutral default so the extended tiers (display/headline/
  // subtitle/label/overline) keep sensible values, then override the slots
  // this design-system token set owns. Fluent 2 supplies subtitle/title_large/
  // title_medium/body_strong; other presets leave them None and inherit the
  // neutral defaults.
  // Override every TypographyScale slot. Fluent 2 supplies the extended
  // tiers (subtitle/headline/display/label/overline); other presets leave
  // them None and inherit the neutral default values.
  let neutral = @core.TypographyScale::default()
  {
    body: self.body,
    title: self.title,
    caption: self.caption,
    control: self.control,
    subtitle: self.subtitle.unwrap_or(neutral.subtitle),
    headline: self.title_large.unwrap_or(neutral.headline),
    display: self.title_medium.unwrap_or(neutral.display),
    label: self.body_strong.unwrap_or(neutral.label),
    overline: self.caption_strong.unwrap_or(neutral.overline),
  }
}

///|
pub fn DesignSpacingTokens::core_spacing_scale(
  self : DesignSpacingTokens,
) -> @core.SpacingScale {
  { xs: self.xs, sm: self.sm, md: self.md, lg: self.lg, xl: self.xl }
}

///|
pub fn DesignRadiusTokens::core_radius_scale(
  self : DesignRadiusTokens,
) -> @core.RadiusScale {
  { sm: self.sm, md: self.md, lg: self.lg, pill: self.pill }
}

///|
pub fn DesignElevationTokens::core_shadow_scale(
  self : DesignElevationTokens,
) -> @core.ShadowScale {
  { sm: self.sm, md: self.md, lg: self.lg }
}

///|
pub fn DesignMotionTokens::core_motion(
  self : DesignMotionTokens,
) -> @core.MotionScale {
  {
    fast_ms: self.fast_ms,
    normal_ms: self.normal_ms,
    slow_ms: self.slow_ms,
    easing: self.easing,
  }
}

///|
pub fn DesignSurfaceTokens::core_surfaces(
  self : DesignSurfaceTokens,
) -> @core.SurfaceScale {
  { base: self.base, raised: self.raised, overlay: self.overlay }
}

///|
pub fn DesignControlStateTokens::core_style(
  self : DesignControlStateTokens,
) -> @views.ControlStateStyle {
  @views.new_control_state_style(
    foreground=self.foreground,
    background=@core.Brush::solid(self.background),
    border?=control_state_border(self),
    radius=self.radius,
    bottom_border_only=self.bottom_border_only,
    inner_focus_border=self.inner_focus_border,
  )
}

///|
/// Project a design-system control-state token onto a `@views.ControlStateTokens`
/// (the token layer stored on the views-owned `ControlThemeSet`). Drops
/// `state_layer_alpha` because the state-layer model lives on the owning
/// `ButtonTheme.state_layer` aggregate, not on individual state tokens.
pub fn DesignControlStateTokens::core_tokens(
  self : DesignControlStateTokens,
) -> @views.ControlStateTokens {
  @views.ControlStateTokens::new(
    foreground=self.foreground,
    background=self.background,
    border=self.border,
    border_width=self.border_width,
    radius=self.radius,
    bottom_border_only=self.bottom_border_only,
    inner_focus_border=self.inner_focus_border,
  )
}

///|
/// Convert a design-system state-layer token set into the core form.
pub fn DesignStateLayerTokens::core_tokens(
  self : DesignStateLayerTokens,
) -> @views.StateLayerTokens {
  {
    color: self.color,
    hover_alpha: self.hover_alpha,
    focus_alpha: self.focus_alpha,
    pressed_alpha: self.pressed_alpha,
    dragged_alpha: self.dragged_alpha,
    selected_alpha: self.selected_alpha,
    disabled_alpha: self.disabled_alpha,
  }
}

///|
pub fn DesignButtonTokens::core_styles(
  self : DesignButtonTokens,
  state_layer : DesignStateLayerTokens,
) -> DesignButtonCoreStyles {
  {
    primary: button_core_style(self.primary, state_layer),
    tonal: button_core_style(self.tonal, state_layer),
    outline: button_core_style(self.outline, state_layer),
    ghost: button_core_style(self.ghost, state_layer),
    subtle: button_core_style(self.subtle, state_layer),
    subtle_brand: button_core_style(self.subtle_brand, state_layer),
  }
}

///|
pub fn DesignTextFieldTokens::core_style(
  self : DesignTextFieldTokens,
) -> @views.TextFieldStyle {
  @views.TextFieldStyle::new(
    normal=self.normal.core_style(),
    focused=self.focused.core_style(),
    disabled=self.disabled.core_style(),
    placeholder_color=self.placeholder,
    cursor_color=self.cursor,
    font=self.font,
  )
}

///|
pub fn DesignTextFieldTokens::core_styles(
  self : DesignTextFieldTokens,
) -> DesignTextFieldCoreStyles {
  let filled = self.core_style()
  let clear = @core.Brush::solid(transparent())
  let plain_normal = @views.new_control_state_style(
    foreground=self.normal.foreground,
    background=clear,
    radius=0.0,
  )
  let plain = filled
    .with_normal(normal=plain_normal)
    .with_focused(focused=plain_normal)
  { filled, outline: filled, plain }
}

///|
pub fn DesignChoiceControlTokens::core_style(
  self : DesignChoiceControlTokens,
) -> @views.ChoiceControlStyle {
  @views.ChoiceControlStyle::new(
    foreground=self.foreground,
    selected_color=self.selected_color,
    disabled_foreground=self.disabled_foreground,
    disabled_selected_color=self.disabled_selected_color,
    control_size=self.control_size,
  )
}

///|
pub fn DesignProgressTokens::core_style(
  self : DesignProgressTokens,
) -> @views.ProgressStyle {
  @views.ProgressStyle::new(
    foreground=self.foreground,
    background=self.background,
    radius=self.radius,
  )
}

///|
pub fn DesignSliderTokens::core_style(
  self : DesignSliderTokens,
) -> @views.SliderStyle {
  @views.SliderStyle::new(
    foreground=self.foreground,
    background=self.background,
    thumb_color=self.thumb_color,
    track_height=self.track_height,
    thumb_size=self.thumb_size,
    radius=self.radius,
  )
}

///|
pub fn DesignPickerTokens::core_style(
  self : DesignPickerTokens,
) -> @views.PickerStyle {
  @views.PickerStyle::new(
    font=self.font,
    foreground=self.foreground,
    background=self.background,
    radius=self.radius,
    popup_max_height=self.popup_max_height,
  )
}

///|
pub fn DesignSurfaceComponentTokens::core_styles(
  self : DesignSurfaceComponentTokens,
  theme : @core.Theme,
) -> DesignSurfaceCoreStyles {
  let base = @views.SurfaceStyle::default(theme~)
    .with_padding(padding=@core.Insets::all(self.base_padding))
    .with_radius(radius=self.base_radius)
    .with_shadow(shadow=self.base_shadow)
  let raised = @views.SurfaceStyle::raised(theme~)
    .with_padding(padding=@core.Insets::all(self.raised_padding))
    .with_radius(radius=self.raised_radius)
    .with_shadow(shadow=self.raised_shadow)
  let overlay_shadow = match self.overlay_shadow {
    Some(value) => Some(value)
    None => Some(theme.shadow_scale.sm)
  }
  let overlay = @views.SurfaceStyle::default(theme~)
    .with_brush(brush=theme.surface_brush(@core.SurfaceLevel::Overlay))
    .with_padding(padding=@core.Insets::all(self.overlay_padding))
    .with_radius(radius=self.overlay_radius)
    // Fluent supplies a layered overlay shadow; otherwise fall back to the
    // neutral minimal faint shadow used before per-tier elevation existed.
    .with_shadow(shadow=overlay_shadow)
    .with_level(level=@core.SurfaceLevel::Overlay)
  { base, raised, overlay }
}

///|
pub fn DesignToneTokens::core_style(
  self : DesignToneTokens,
) -> @views.ToneStyle {
  @views.ToneStyle::new(
    foreground=self.foreground,
    background=self.background,
    border=self.border,
  )
}

///|
pub fn DesignFeedbackTokens::core_style(
  self : DesignFeedbackTokens,
) -> @views.FeedbackStyle {
  @views.FeedbackStyle::new(
    neutral=self.neutral.core_style(),
    info=self.info.core_style(),
    success=self.success.core_style(),
    warning=self.warning.core_style(),
    danger=self.danger.core_style(),
    radius=self.radius,
    padding=self.padding,
  )
}

///|
pub fn DesignBadgeTokens::core_style(
  self : DesignBadgeTokens,
) -> @views.BadgeStyle {
  @views.BadgeStyle::new(
    neutral=self.neutral.core_style(),
    accent=self.accent.core_style(),
    success=self.success.core_style(),
    warning=self.warning.core_style(),
    danger=self.danger.core_style(),
    radius=self.radius,
    padding=self.padding,
  )
}

///|
pub fn DesignFormValidationTokens::core_style(
  self : DesignFormValidationTokens,
) -> @views.FormValidationStyle {
  @views.FormValidationStyle::new(
    foreground=self.foreground,
    background=self.background,
    border=self.border,
    radius=self.radius,
    padding=self.padding,
  )
}

///|
/// Project the design-system component tokens onto a `@views.ControlThemeSet`
/// (the views-owned control theme aggregate, ADR 0017). This is the single
/// projection that lets a branded design system set `ControlThemeSet` once
/// on the root environment instead of passing `style=` to every control.
/// `scheme` is required so surface brushes and shadow fallbacks can be
/// resolved without recursing into `to_theme()` (which itself calls this
/// method).
pub fn DesignComponentTokens::core_themes(
  self : DesignComponentTokens,
  scheme : @core.ColorScheme,
) -> @views.ControlThemeSet {
  let state_layer = self_button_state_layer(self)
  let button : @views.ButtonTheme = {
    primary: self.button.primary.core_tokens(),
    tonal: self.button.tonal.core_tokens(),
    outline: self.button.outline.core_tokens(),
    ghost: self.button.ghost.core_tokens(),
    subtle: self.button.subtle.core_tokens(),
    subtle_brand: self.button.subtle_brand.core_tokens(),
    state_layer,
  }
  let text_field : @views.TextFieldTheme = {
    normal: self.text_field.normal.core_tokens(),
    focused: self.text_field.focused.core_tokens(),
    disabled: self.text_field.disabled.core_tokens(),
    placeholder: self.text_field.placeholder,
    cursor: self.text_field.cursor,
    font: self.text_field.font,
    appearance: core_text_field_appearance(self.text_field.appearance),
  }
  let surface : @views.SurfaceTheme = {
    base_padding: self.surface.base_padding,
    raised_padding: self.surface.raised_padding,
    overlay_padding: self.surface.overlay_padding,
    base_radius: self.surface.base_radius,
    raised_radius: self.surface.raised_radius,
    overlay_radius: self.surface.overlay_radius,
    base_shadow: self.surface.base_shadow,
    raised_shadow: self.surface.raised_shadow,
    overlay_shadow: self.surface.overlay_shadow,
  }
  let choice_control : @views.ChoiceControlTheme = {
    foreground: self.choice_control.foreground,
    selected_color: self.choice_control.selected_color,
    disabled_foreground: self.choice_control.disabled_foreground,
    disabled_selected_color: self.choice_control.disabled_selected_color,
    control_size: self.choice_control.control_size,
    box_shape: self.choice_control.box_shape,
    check_style: self.choice_control.check_style,
  }
  let progress : @views.ProgressTheme = {
    foreground: self.progress.foreground,
    background: self.progress.background,
    radius: self.progress.radius,
  }
  let slider : @views.SliderTheme = {
    foreground: self.slider.foreground,
    background: self.slider.background,
    thumb_color: self.slider.thumb_color,
    track_height: self.slider.track_height,
    thumb_size: self.slider.thumb_size,
    radius: self.slider.radius,
    thumb_shape: self.slider.thumb_shape,
  }
  let picker : @views.PickerTheme = {
    font: self.picker.font,
    foreground: self.picker.foreground,
    background: self.picker.background,
    radius: self.picker.radius,
    popup_max_height: self.picker.popup_max_height,
  }
  let feedback : @views.FeedbackTheme = {
    neutral: core_tone(self.feedback.neutral),
    info: core_tone(self.feedback.info),
    success: core_tone(self.feedback.success),
    warning: core_tone(self.feedback.warning),
    danger: core_tone(self.feedback.danger),
    radius: self.feedback.radius,
    padding: self.feedback.padding,
  }
  let badge : @views.BadgeTheme = {
    neutral: core_tone(self.badge.neutral),
    accent: core_tone(self.badge.accent),
    success: core_tone(self.badge.success),
    warning: core_tone(self.badge.warning),
    danger: core_tone(self.badge.danger),
    radius: self.badge.radius,
    padding: self.badge.padding,
  }
  let form_validation : @views.FormValidationTheme = {
    foreground: self.form_validation.foreground,
    background: self.form_validation.background,
    border: self.form_validation.border,
    radius: self.form_validation.radius,
    padding: self.form_validation.padding,
  }
  ignore(scheme)
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
fn self_button_state_layer(
  components : DesignComponentTokens,
) -> @views.StateLayerTokens {
  // The design-system button tokens do not carry their own state-layer; the
  // shared `DesignStateLayerTokens` lives on `DesignSystemTokens.state_layer`.
  // Callers pass it through `DesignSystemTokens::core_themes` instead. This
  // helper is only reached when projecting bare `DesignComponentTokens`, so
  // fall back to a neutral state-layer derived from the primary foreground.
  ignore(components)
  {
    color: @core.Color::white(),
    hover_alpha: 0.08,
    focus_alpha: 0.12,
    pressed_alpha: 0.12,
    dragged_alpha: 0.16,
    selected_alpha: 0.10,
    disabled_alpha: 0.38,
  }
}

///|
fn core_text_field_appearance(
  appearance : DesignTextFieldAppearance,
) -> @views.TextFieldAppearance {
  match appearance {
    Filled => @views.TextFieldAppearance::Filled
    Outline => @views.TextFieldAppearance::Outline
    Underline => @views.TextFieldAppearance::Underline
  }
}

///|
fn core_tone(tokens : DesignToneTokens) -> @views.ToneTokens {
  {
    foreground: tokens.foreground,
    background: tokens.background,
    border: tokens.border,
  }
}

///|
/// Project the full design-system tokens (including the shared state-layer)
/// onto a `@views.ControlThemeSet`. This is the entry point `to_theme()` uses
/// so the resolved theme carries first-class component themes.
pub fn DesignSystemTokens::core_themes(
  self : DesignSystemTokens,
) -> @views.ControlThemeSet {
  let state_layer = self.state_layer.core_tokens()
  let base = self.components.core_themes(self.scheme)
  { ..base, button: { ..base.button, state_layer, } }
}

///|
pub fn DesignSystemTokens::core_component_styles(
  self : DesignSystemTokens,
) -> DesignCoreComponentStyles {
  let theme = self.to_theme()
  {
    button: self.components.button.core_styles(self.state_layer),
    text_field: self.components.text_field.core_styles(),
    surface: self.components.surface.core_styles(theme),
    choice_control: self.components.choice_control.core_style(),
    progress: self.components.progress.core_style(),
    slider: self.components.slider.core_style(),
    picker: self.components.picker.core_style(),
    date_picker: self.components.date_picker.core_style(),
    feedback: self.components.feedback.core_style(),
    badge: self.components.badge.core_style(),
    form_validation: self.components.form_validation.core_style(),
  }
}

///|
pub fn DesignSystemTokens::to_theme(self : DesignSystemTokens) -> @core.Theme {
  let base = match self.scheme {
    @core.ColorScheme::Light => @views.light_theme()
    @core.ColorScheme::Dark => @views.dark_theme()
  }
  base
  .with_palette(self.palette.core_palette(self.scheme))
  .with_spacing_scale(self.spacing.core_spacing_scale())
  .with_radius_scale(self.radius.core_radius_scale())
  .with_typography(self.typography.core_typography())
  .with_shadow_scale(self.elevation.core_shadow_scale())
  .with_motion(self.motion.core_motion())
  .with_surfaces(self.surfaces.core_surfaces())
  // Concrete control tokens no longer attach to `core.Theme` (ADR 0017);
  // `core_themes()` resolves a separate `@views.ControlThemeSet` for callers
  // that need the branded component theme set.
}

///|
pub fn DesignSystemTokens::with_palette(
  self : DesignSystemTokens,
  palette : DesignSemanticPalette,
) -> DesignSystemTokens {
  let surfaces = surface_tokens(palette, self.scheme)
  let components = component_tokens(
    self.scheme,
    palette,
    self.typography,
    self.radius,
    self.spacing,
    self.state_layer,
  )
  { ..self, palette, surfaces, components }
}

///|
pub fn DesignSystemTokens::with_spacing(
  self : DesignSystemTokens,
  spacing : DesignSpacingTokens,
) -> DesignSystemTokens {
  let components = component_tokens(
    self.scheme,
    self.palette,
    self.typography,
    self.radius,
    spacing,
    self.state_layer,
  )
  { ..self, spacing, components }
}

///|
pub fn DesignSystemTokens::with_radius(
  self : DesignSystemTokens,
  radius : DesignRadiusTokens,
) -> DesignSystemTokens {
  let components = component_tokens(
    self.scheme,
    self.palette,
    self.typography,
    radius,
    self.spacing,
    self.state_layer,
  )
  { ..self, radius, components }
}

///|
pub fn DesignSystemTokens::with_state_layer(
  self : DesignSystemTokens,
  state_layer : DesignStateLayerTokens,
) -> DesignSystemTokens {
  let components = component_tokens(
    self.scheme,
    self.palette,
    self.typography,
    self.radius,
    self.spacing,
    state_layer,
  )
  { ..self, state_layer, components }
}

///|
pub fn DesignPreset::tokens(
  self : DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : DesignDensity = DesignDensity::Standard,
) -> DesignSystemTokens {
  match self {
    Material =>
      material_design_tokens(scheme, density, variant=scheme_variant(scheme))
    Carbon =>
      carbon_design_tokens(scheme, density, variant=scheme_variant(scheme))
    Primer =>
      primer_design_tokens(scheme, density, variant=scheme_variant(scheme))
    Fluent =>
      fluent_design_tokens(scheme, density, variant=scheme_variant(scheme))
  }
}

///|
pub fn DesignPreset::tokens_for_variant(
  self : DesignPreset,
  variant? : DesignSchemeVariant = DesignSchemeVariant::SchemeLight,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : DesignDensity = DesignDensity::Standard,
) -> DesignSystemTokens {
  let scheme = variant_core_scheme(variant, system_scheme)
  if variant == DesignSchemeVariant::SchemeHighContrast {
    high_contrast_design_tokens(self, scheme, density)
  } else {
    let tokens = self.tokens(scheme~, density~)
    { ..tokens, variant, }
  }
}

///|
pub fn custom_tokens(
  base : DesignSystemTokens,
  palette? : DesignSemanticPalette,
  typography? : DesignTypographyTokens,
  spacing? : DesignSpacingTokens,
  radius? : DesignRadiusTokens,
  elevation? : DesignElevationTokens,
  motion? : DesignMotionTokens,
  surfaces? : DesignSurfaceTokens,
  state_layer? : DesignStateLayerTokens,
  components? : DesignComponentTokens,
) -> DesignSystemTokens {
  let mut tokens = base
  let mut surfaces_overridden = false
  let mut components_overridden = false
  match palette {
    Some(value) => tokens = { ..tokens, palette: value }
    None => ()
  }
  match typography {
    Some(value) => tokens = { ..tokens, typography: value }
    None => ()
  }
  match spacing {
    Some(value) => tokens = { ..tokens, spacing: value }
    None => ()
  }
  match radius {
    Some(value) => tokens = { ..tokens, radius: value }
    None => ()
  }
  match elevation {
    Some(value) => tokens = { ..tokens, elevation: value }
    None => ()
  }
  match motion {
    Some(value) => tokens = { ..tokens, motion: value }
    None => ()
  }
  match surfaces {
    Some(value) => {
      surfaces_overridden = true
      tokens = { ..tokens, surfaces: value }
    }
    None => ()
  }
  match state_layer {
    Some(value) => tokens = { ..tokens, state_layer: value }
    None => ()
  }
  match components {
    Some(value) => {
      components_overridden = true
      tokens = { ..tokens, components: value }
    }
    None => ()
  }
  if !surfaces_overridden {
    tokens = {
      ..tokens,
      surfaces: surface_tokens(tokens.palette, tokens.scheme),
    }
  }
  if !components_overridden {
    tokens = {
      ..tokens,
      components: component_tokens(
        tokens.scheme,
        tokens.palette,
        tokens.typography,
        tokens.radius,
        tokens.spacing,
        tokens.state_layer,
      ),
    }
  }
  tokens
}

///|
fn material_design_tokens(
  scheme : @core.ColorScheme,
  density : DesignDensity,
  variant~ : DesignSchemeVariant,
) -> DesignSystemTokens {
  let palette = match scheme {
    @core.ColorScheme::Light =>
      semantic_palette(
        foreground=color_byte(r=29, g=27, b=32),
        background=color_byte(r=254, g=247, b=255),
        surface=color_byte(r=254, g=247, b=255),
        surface_variant=color_byte(r=231, g=224, b=236),
        primary=color_byte(r=103, g=80, b=164),
        primary_foreground=@core.Color::white(),
        outline=color_byte(r=121, g=116, b=126),
        muted=color_byte(r=73, g=69, b=79),
        success=color(r=0.10, g=0.45, b=0.22),
        warning=color(r=0.66, g=0.43, b=0.00),
        danger=color_byte(r=179, g=38, b=30),
        info=color(r=0.12, g=0.35, b=0.82),
        scrim=Some(color(r=0.0, g=0.0, b=0.0, a=1.0)),
      )
    @core.ColorScheme::Dark =>
      semantic_palette(
        foreground=color(r=0.93, g=0.91, b=0.96),
        background=color(r=0.09, g=0.08, b=0.11),
        surface=color(r=0.15, g=0.13, b=0.18),
        surface_variant=color(r=0.23, g=0.21, b=0.28),
        primary=color(r=0.82, g=0.73, b=1.0),
        primary_foreground=color(r=0.13, g=0.09, b=0.22),
        outline=color(r=0.58, g=0.54, b=0.63),
        muted=color(r=0.73, g=0.69, b=0.77),
        success=color(r=0.52, g=0.80, b=0.56),
        warning=color(r=0.95, g=0.73, b=0.36),
        danger=color(r=1.0, g=0.71, b=0.67),
        info=color(r=0.66, g=0.78, b=1.0),
      )
  }
  let tokens = design_tokens(
    preset=DesignPreset::Material,
    scheme~,
    variant~,
    density~,
    source_family="Material Design 3 system tokens",
    palette~,
    spacing=spacing_tokens(
      { xs: 4.0, sm: 8.0, md: 16.0, lg: 24.0, xl: 32.0 },
      density,
    ),
    radius={ sm: 8.0, md: 12.0, lg: 22.0, pill: 999.0 },
    typography=typography_tokens(
      title=24.0,
      body=14.0,
      caption=12.0,
      control=14.0,
    ),
    elevation=material_elevation_tokens(scheme),
    motion={
      fast_ms: 200.0,
      normal_ms: 300.0,
      slow_ms: 400.0,
      easing: @core.Easing::EaseOut,
    },
  )
  match scheme {
    @core.ColorScheme::Light => {
      let picker = {
        ..tokens.components.picker,
        background: @core.Brush::solid(color_byte(r=243, g=237, b=247)),
      }
      { ..tokens, components: { ..tokens.components, picker, } }
    }
    @core.ColorScheme::Dark => tokens
  }
}

///|
fn carbon_design_tokens(
  scheme : @core.ColorScheme,
  density : DesignDensity,
  variant~ : DesignSchemeVariant,
) -> DesignSystemTokens {
  let palette = match scheme {
    @core.ColorScheme::Light =>
      semantic_palette(
        foreground=color_byte(r=22, g=22, b=22),
        background=@core.Color::white(),
        surface=color_byte(r=244, g=244, b=244),
        surface_variant=color_byte(r=224, g=224, b=224),
        primary=color_byte(r=15, g=98, b=254),
        primary_foreground=@core.Color::white(),
        outline=color_byte(r=141, g=141, b=141),
        muted=color_byte(r=82, g=82, b=82),
        success=color_byte(r=36, g=161, b=72),
        warning=color_byte(r=241, g=194, b=27),
        danger=color_byte(r=218, g=30, b=40),
        info=color_byte(r=0, g=67, b=206),
        scrim=Some(color(r=0.0, g=0.0, b=0.0, a=0.6)),
      )
    @core.ColorScheme::Dark =>
      semantic_palette(
        foreground=color(r=0.96, g=0.96, b=0.96),
        background=color(r=0.08, g=0.08, b=0.08),
        surface=color(r=0.15, g=0.15, b=0.15),
        surface_variant=color(r=0.23, g=0.23, b=0.23),
        primary=color(r=0.27, g=0.55, b=1.0),
        primary_foreground=color(r=0.03, g=0.06, b=0.12),
        outline=color(r=0.48, g=0.48, b=0.48),
        muted=color(r=0.76, g=0.76, b=0.76),
        success=color(r=0.25, g=0.68, b=0.35),
        warning=color(r=0.95, g=0.72, b=0.32),
        danger=color(r=1.0, g=0.51, b=0.51),
        info=color(r=0.47, g=0.68, b=1.0),
      )
  }
  let tokens = design_tokens(
    preset=DesignPreset::Carbon,
    scheme~,
    variant~,
    density~,
    source_family="Carbon theme tokens",
    palette~,
    spacing=spacing_tokens(
      { xs: 2.0, sm: 8.0, md: 12.0, lg: 16.0, xl: 24.0 },
      density,
    ),
    radius={ sm: 0.0, md: 2.0, lg: 4.0, pill: 999.0 },
    typography=typography_tokens(
      title=20.0,
      body=16.0,
      caption=12.0,
      control=14.0,
    ),
    elevation=elevation_tokens(scheme, lift=0.48),
    motion={
      fast_ms: 90.0,
      normal_ms: 150.0,
      slow_ms: 240.0,
      easing: @core.Easing::EaseInOut,
    },
  )
  match scheme {
    @core.ColorScheme::Light => {
      let state_layer = { ..tokens.state_layer, hover_alpha: 0.12 }
      let components = component_tokens(
        tokens.scheme,
        tokens.palette,
        tokens.typography,
        tokens.radius,
        tokens.spacing,
        state_layer,
      )
      let slider = {
        ..components.slider,
        foreground: color_byte(r=22, g=22, b=22),
      }
      { ..tokens, state_layer, components: { ..components, slider, } }
    }
    @core.ColorScheme::Dark => tokens
  }
}

///|
fn primer_design_tokens(
  scheme : @core.ColorScheme,
  density : DesignDensity,
  variant~ : DesignSchemeVariant,
) -> DesignSystemTokens {
  let palette = match scheme {
    @core.ColorScheme::Light =>
      semantic_palette(
        foreground=color_byte(r=31, g=35, b=40),
        background=@core.Color::white(),
        surface=color_byte(r=246, g=248, b=250),
        surface_variant=color_byte(r=246, g=248, b=250),
        primary=color_byte(r=9, g=105, b=218),
        primary_foreground=@core.Color::white(),
        outline=color_byte(r=209, g=217, b=224),
        muted=color_byte(r=89, g=99, b=110),
        success=color_byte(r=26, g=127, b=55),
        warning=color_byte(r=154, g=103, b=0),
        danger=color_byte(r=209, g=36, b=47),
        info=color_byte(r=9, g=105, b=218),
        focus=Some(color_byte(r=9, g=105, b=218)),
        scrim=Some(
          color(
            r=0.7843137254901961,
            g=0.8196078431372549,
            b=0.8549019607843137,
            a=0.4,
          ),
        ),
      )
    @core.ColorScheme::Dark =>
      semantic_palette(
        foreground=color(r=0.90, g=0.93, b=0.96),
        background=color(r=0.05, g=0.07, b=0.10),
        surface=color(r=0.09, g=0.12, b=0.16),
        surface_variant=color(r=0.13, g=0.17, b=0.23),
        primary=color(r=0.23, g=0.68, b=0.36),
        primary_foreground=color(r=0.02, g=0.07, b=0.03),
        outline=color(r=0.25, g=0.30, b=0.37),
        muted=color(r=0.55, g=0.61, b=0.69),
        success=color(r=0.23, g=0.68, b=0.36),
        warning=color(r=0.82, g=0.55, b=0.18),
        danger=color(r=1.0, g=0.48, b=0.42),
        info=color(r=0.36, g=0.61, b=1.0),
      )
  }
  design_tokens(
    preset=DesignPreset::Primer,
    scheme~,
    variant~,
    density~,
    source_family="Primer primitives",
    palette~,
    spacing=spacing_tokens(
      { xs: 4.0, sm: 8.0, md: 12.0, lg: 16.0, xl: 24.0 },
      density,
    ),
    radius={ sm: 4.0, md: 6.0, lg: 8.0, pill: 999.0 },
    typography=typography_tokens(
      title=20.0,
      body=14.0,
      caption=12.0,
      control=14.0,
    ),
    elevation=elevation_tokens(scheme, lift=0.72),
    motion={
      fast_ms: 100.0,
      normal_ms: 160.0,
      slow_ms: 260.0,
      easing: @core.Easing::EaseOut,
    },
  )
}

///|
fn fluent_design_tokens(
  scheme : @core.ColorScheme,
  density : DesignDensity,
  variant~ : DesignSchemeVariant,
) -> DesignSystemTokens {
  // Fluent 2 token values pinned from @fluentui/tokens. The neutral ramp
  // (colorNeutralBackground1/2/3, colorNeutralForeground1/2,
  // colorNeutralStroke1/2) is now first-class instead of collapsed into a
  // single surface pair; brand stroke is separated from brand fill
  // (colorBrandStroke1 != colorBrandBackground). Status colors use the Fluent
  // 2 status ramp (green/yellow/red) rather than the legacy Office palette.
  let palette = match scheme {
    @core.ColorScheme::Light =>
      semantic_palette(
        // colorNeutralForeground1 / Background1
        foreground=color_byte(r=36, g=36, b=36),
        background=@core.Color::white(),
        // Legacy aliases kept for compatibility; the ramp fields below are
        // the source of truth for surface tiers.
        surface=color_byte(r=250, g=250, b=250),
        surface_variant=color_byte(r=245, g=245, b=245),
        // Fluent 2 neutral background ramp.
        // colorNeutralBackground2 (card) / Background3 (raised/flyout).
        background_2=Some(color_byte(r=250, g=250, b=250)),
        background_3=Some(color_byte(r=245, g=245, b=245)),
        // colorNeutralForeground2 (secondary text).
        foreground_2=Some(color_byte(r=97, g=97, b=97)),
        // colorNeutralStroke1 (strong border) / Stroke2 (subtle divider).
        stroke_1=Some(color_byte(r=209, g=209, b=209)),
        stroke_2=Some(color_byte(r=224, g=224, b=224)),
        // colorNeutralBackground4 (light) = #EBEBEB, StrokeAccessible = #616161.
        background_4=Some(color_byte(r=235, g=235, b=235)),
        stroke_accessible=Some(color_byte(r=97, g=97, b=97)),
        // colorBrandBackground (primary fill) / colorBrandStroke1.
        primary=color_byte(r=15, g=108, b=189),
        primary_foreground=@core.Color::white(),
        brand_stroke=Some(color_byte(r=15, g=108, b=189)),
        outline=color_byte(r=209, g=209, b=209),
        muted=color_byte(r=97, g=97, b=97),
        // Fluent 2 status ramp (BackgroundGreen/Yellow/Red).
        success=color_byte(r=16, g=124, b=16),
        warning=color_byte(r=138, g=84, b=0),
        danger=color_byte(r=177, g=15, b=14),
        info=color_byte(r=15, g=108, b=189),
        focus=Some(@core.Color::black()),
        scrim=Some(color(r=0.0, g=0.0, b=0.0, a=0.4)),
      )
    @core.ColorScheme::Dark =>
      semantic_palette(
        // colorNeutralForeground1 / Background1 (Fluent 2 dark: #292929).
        foreground=@core.Color::white(),
        background=color_byte(r=41, g=41, b=41),
        surface=color_byte(r=31, g=31, b=31),
        surface_variant=color_byte(r=20, g=20, b=20),
        // Dark neutral ramp: Background2 = #1F1F1F, Background3 = #141414.
        background_2=Some(color_byte(r=31, g=31, b=31)),
        background_3=Some(color_byte(r=20, g=20, b=20)),
        // colorNeutralForeground2 (dark) = #D6D6D6.
        foreground_2=Some(color_byte(r=214, g=214, b=214)),
        // colorNeutralStroke1 (dark) = #525252, Stroke2 = #3D3D3D.
        stroke_1=Some(color_byte(r=82, g=82, b=82)),
        stroke_2=Some(color_byte(r=61, g=61, b=61)),
        // colorNeutralBackground4 (dark) = #0A0A0A, StrokeAccessible = #FFFFFF.
        background_4=Some(color_byte(r=10, g=10, b=10)),
        stroke_accessible=Some(@core.Color::white()),
        // colorBrandBackground (dark) = #115EA3, BrandStroke1 = #2886DE.
        primary=color_byte(r=17, g=94, b=163),
        primary_foreground=@core.Color::white(),
        brand_stroke=Some(color_byte(r=40, g=134, b=222)),
        outline=color_byte(r=82, g=82, b=82),
        muted=color_byte(r=214, g=214, b=214),
        success=color_byte(r=154, g=223, b=125),
        warning=color_byte(r=255, g=200, b=0),
        danger=color_byte(r=255, g=159, b=150),
        info=color_byte(r=96, g=205, b=255),
        focus=Some(@core.Color::white()),
        scrim=Some(color(r=0.0, g=0.0, b=0.0, a=0.6)),
      )
  }
  let tokens = design_tokens(
    preset=DesignPreset::Fluent,
    scheme~,
    variant~,
    density~,
    source_family="Fluent 2 alias tokens (@fluentui/tokens)",
    palette~,
    spacing=spacing_tokens(
      { xs: 4.0, sm: 8.0, md: 12.0, lg: 20.0, xl: 32.0 },
      density,
    ),
    // Fluent 2 border-radius tiers: sm=2 (borderRadiusSmall), md=4
    // (borderRadiusMedium), lg=8 (borderRadiusXLarge), pill=circular.
    radius={ sm: 2.0, md: 4.0, lg: 8.0, pill: 999.0 },
    typography=typography_tokens(
      title=20.0,
      body=14.0,
      caption=12.0,
      control=14.0,
      // Fluent 2 type ramp: subtitle1 (20/600), title1 (28/600),
      // title2 (24/600), body1Strong (14/600), caption2 (12/600).
      subtitle=Some(@core.FontSpec::new(size=20.0, weight=600)),
      title_large=Some(@core.FontSpec::new(size=28.0, weight=600)),
      title_medium=Some(@core.FontSpec::new(size=24.0, weight=600)),
      body_strong=Some(@core.FontSpec::new(size=14.0, weight=600)),
      caption_strong=Some(@core.FontSpec::new(size=12.0, weight=600)),
    ),
    elevation=fluent_elevation_tokens(scheme),
    motion={
      // Fluent 2 duration tokens: normal=0.15s, fast=0.1s, slow=0.25s,
      // ease curve = cubic-bezier(0.33,0,0.67,1) (EaseInOut approximated).
      fast_ms: 100.0,
      normal_ms: 150.0,
      slow_ms: 250.0,
      easing: @core.Easing::EaseInOut,
    },
  )
  fluent_component_overrides(tokens, palette, scheme)
}

///|
/// Fluent 2 structural component differentiation applied on top of the shared
/// `component_tokens` base. This is where Fluent stops being "just a palette
/// swap": subtle/subtle-brand button variants, underline text-field appearance,
/// focus inner-reveal borders, and per-tier card shadows.
fn fluent_component_overrides(
  tokens : DesignSystemTokens,
  palette : DesignSemanticPalette,
  scheme : @core.ColorScheme,
) -> DesignSystemTokens {
  let base = tokens.components
  let button = {
    ..base
    // Primary button: Fluent 2 uses colorBrandBackground as fill and
    // colorBrandStroke1 as the rest border, separated from the fill color.
    .button,
    primary: { ..base.button.primary, border: palette.brand_stroke },
    // subtle: transparent background, foreground tint, hover reveals a faint
    // neutral wash (colorNeutralBackground1Hover semantics).
    subtle: control_state_tokens(
      foreground=palette.foreground,
      background=transparent(),
      border=transparent(),
      border_width=0.0,
      radius=tokens.radius.md,
      state_layer_alpha=tokens.state_layer.hover_alpha,
    ),
    // subtle-brand: transparent background, brand-tinted foreground, hover
    // reveals a faint brand wash.
    subtle_brand: control_state_tokens(
      foreground=palette.primary,
      background=transparent(),
      border=transparent(),
      border_width=0.0,
      radius=tokens.radius.md,
      state_layer_alpha=tokens.state_layer.hover_alpha,
    ),
  }
  // Underline text field: bottom-border-only normal/focused, no side/top
  // border. Normal uses colorNeutralStroke1, focused uses colorBrandStroke1 at
  // 2px with an inner-reveal hint (colorBrandBackground).
  let underline_border_width = 1.0
  let underline_focus_width = 2.0
  let tf = base.text_field
  let text_field = {
    ..tf,
    normal: {
      ..tf.normal,
      border: palette.stroke_1,
      border_width: underline_border_width,
      bottom_border_only: true,
      inner_focus_border: None,
    },
    focused: {
      ..tf.focused,
      border: palette.brand_stroke,
      border_width: underline_focus_width,
      bottom_border_only: true,
      inner_focus_border: Some(palette.primary),
    },
    appearance: DesignTextFieldAppearance::Underline,
  }
  // Fluent 2 also uses neutral stroke1 (not outline) for picker borders and
  // brand stroke for choice-control selected state.
  let picker = {
    ..base.picker,
    background: @core.Brush::solid(palette.background_2),
  }
  // Per-tier card shadows from the Fluent elevation ramp.
  let surface = {
    ..base.surface,
    base_shadow: tokens.elevation.card,
    raised_shadow: tokens.elevation.card,
    overlay_shadow: tokens.elevation.flyout,
  }
  ignore(scheme)
  { ..tokens, components: { ..base, button, text_field, picker, surface } }
}

///|
fn high_contrast_design_tokens(
  preset : DesignPreset,
  scheme : @core.ColorScheme,
  density : DesignDensity,
) -> DesignSystemTokens {
  let palette = match scheme {
    @core.ColorScheme::Light =>
      semantic_palette(
        foreground=@core.Color::black(),
        background=@core.Color::white(),
        surface=@core.Color::white(),
        surface_variant=color(r=0.92, g=0.92, b=0.92),
        primary=color(r=0.00, g=0.24, b=0.86),
        primary_foreground=@core.Color::white(),
        outline=@core.Color::black(),
        muted=color(r=0.22, g=0.22, b=0.22),
        success=color(r=0.00, g=0.42, b=0.12),
        warning=color(r=0.62, g=0.36, b=0.00),
        danger=color(r=0.75, g=0.00, b=0.00),
        info=color(r=0.00, g=0.24, b=0.86),
      )
    @core.ColorScheme::Dark =>
      semantic_palette(
        foreground=@core.Color::white(),
        background=@core.Color::black(),
        surface=@core.Color::black(),
        surface_variant=color(r=0.10, g=0.10, b=0.10),
        primary=color(r=0.48, g=0.82, b=1.0),
        primary_foreground=@core.Color::black(),
        outline=@core.Color::white(),
        muted=color(r=0.82, g=0.82, b=0.82),
        success=color(r=0.58, g=1.0, b=0.58),
        warning=color(r=1.0, g=0.86, b=0.30),
        danger=color(r=1.0, g=0.58, b=0.58),
        info=color(r=0.48, g=0.82, b=1.0),
      )
  }
  design_tokens(
    preset~,
    scheme~,
    variant=DesignSchemeVariant::SchemeHighContrast,
    density~,
    source_family=preset.label() + " high-contrast adapter",
    palette~,
    spacing=spacing_tokens(
      { xs: 4.0, sm: 8.0, md: 14.0, lg: 20.0, xl: 28.0 },
      density,
    ),
    radius={ sm: 2.0, md: 4.0, lg: 8.0, pill: 999.0 },
    typography=typography_tokens(
      title=22.0,
      body=16.0,
      caption=13.0,
      control=16.0,
    ),
    elevation=elevation_tokens(scheme, lift=0.24),
    motion={
      fast_ms: 0.0,
      normal_ms: 0.0,
      slow_ms: 0.0,
      easing: @core.Easing::Linear,
    },
  )
}

///|
fn design_tokens(
  preset~ : DesignPreset,
  scheme~ : @core.ColorScheme,
  variant~ : DesignSchemeVariant,
  density~ : DesignDensity,
  source_family~ : String,
  palette~ : DesignSemanticPalette,
  spacing~ : DesignSpacingTokens,
  radius~ : DesignRadiusTokens,
  typography~ : DesignTypographyTokens,
  elevation~ : DesignElevationTokens,
  motion~ : DesignMotionTokens,
) -> DesignSystemTokens {
  let surfaces = surface_tokens(palette, scheme)
  let state_layer = state_layer_tokens(palette)
  let components = component_tokens(
    scheme, palette, typography, radius, spacing, state_layer,
  )
  {
    preset,
    scheme,
    variant,
    density,
    source_family,
    palette,
    typography,
    spacing,
    radius,
    elevation,
    motion,
    surfaces,
    state_layer,
    components,
  }
}

///|
fn semantic_palette(
  foreground~ : @core.Color,
  background~ : @core.Color,
  surface~ : @core.Color,
  surface_variant~ : @core.Color,
  primary~ : @core.Color,
  primary_foreground~ : @core.Color,
  outline~ : @core.Color,
  muted~ : @core.Color,
  success~ : @core.Color,
  warning~ : @core.Color,
  danger~ : @core.Color,
  info~ : @core.Color,
  focus? : @core.Color? = None,
  scrim? : @core.Color? = None,
  // Neutral ramp overrides. Default to the legacy surface/foreground/outline
  // aliases so presets without a ramp keep their old appearance.
  background_2? : @core.Color? = None,
  background_3? : @core.Color? = None,
  background_4? : @core.Color? = None,
  foreground_2? : @core.Color? = None,
  stroke_1? : @core.Color? = None,
  stroke_2? : @core.Color? = None,
  stroke_accessible? : @core.Color? = None,
  brand_stroke? : @core.Color? = None,
) -> DesignSemanticPalette {
  {
    foreground,
    background,
    surface,
    surface_variant,
    background_2: background_2.unwrap_or(surface),
    background_3: background_3.unwrap_or(surface_variant),
    background_4: background_4.unwrap_or(surface_variant),
    foreground_2: foreground_2.unwrap_or(muted),
    stroke_1: stroke_1.unwrap_or(outline),
    stroke_2: stroke_2.unwrap_or(outline),
    stroke_accessible: stroke_accessible.unwrap_or(outline),
    brand_stroke: brand_stroke.unwrap_or(primary),
    primary,
    primary_foreground,
    outline,
    muted,
    success,
    warning,
    danger,
    info,
    focus: focus.unwrap_or(primary),
    scrim: scrim.unwrap_or(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.42)),
  }
}

///|
fn typography_tokens(
  title~ : Double,
  body~ : Double,
  caption~ : Double,
  control~ : Double,
  subtitle? : @core.FontSpec? = None,
  title_large? : @core.FontSpec? = None,
  title_medium? : @core.FontSpec? = None,
  body_strong? : @core.FontSpec? = None,
  caption_strong? : @core.FontSpec? = None,
) -> DesignTypographyTokens {
  {
    body: @core.FontSpec::new(size=body, weight=400),
    title: @core.FontSpec::new(size=title, weight=700),
    caption: @core.FontSpec::new(size=caption, weight=400),
    control: @core.FontSpec::new(size=control, weight=600),
    subtitle,
    title_large,
    title_medium,
    body_strong,
    caption_strong,
  }
}

///|
fn spacing_tokens(
  base : @core.SpacingScale,
  density : DesignDensity,
) -> DesignSpacingTokens {
  let multiplier = density.multiplier()
  {
    xs: scaled_spacing(base.xs, multiplier),
    sm: scaled_spacing(base.sm, multiplier),
    md: scaled_spacing(base.md, multiplier),
    lg: scaled_spacing(base.lg, multiplier),
    xl: scaled_spacing(base.xl, multiplier),
    density_multiplier: multiplier,
  }
}

///|
fn scaled_spacing(value : Double, multiplier : Double) -> Double {
  value * multiplier
}

///|
fn elevation_tokens(
  scheme : @core.ColorScheme,
  lift~ : Double,
) -> DesignElevationTokens {
  let shadows = shadow_scale(scheme, lift~)
  // Neutral presets do not carry Fluent 2's layered card/flyout/dialog tiers;
  // callers that need them (Fluent) override via `fluent_elevation_tokens`.
  {
    sm: shadows.sm,
    md: shadows.md,
    lg: shadows.lg,
    card: None,
    flyout: None,
    dialog: None,
  }
}

///|
fn material_elevation_tokens(
  scheme : @core.ColorScheme,
) -> DesignElevationTokens {
  let tokens = elevation_tokens(scheme, lift=1.14)
  {
    sm: { ..tokens.sm, offset: @core.Point::new(x=0.0, y=1.0) },
    md: { ..tokens.md, offset: @core.Point::new(x=0.0, y=6.0) },
    lg: { ..tokens.lg, offset: @core.Point::new(x=0.0, y=12.0) },
    card: None,
    flyout: None,
    dialog: None,
  }
}

///|
/// Fluent 2 shadow tiers. The official @fluentui/tokens ramp defines
/// shadow2/4/8/16/28/64 as ambient+key pairs; this models the visible key
/// shadow per tier (offset + blur + alpha) since the runtime `ShadowStyle`
/// is single-layer. Card/flyout/dialog map to shadow4/shadow16/shadow64 so
/// layered surfaces separate cleanly without the heavy elevation Material uses.
fn fluent_elevation_tokens(scheme : @core.ColorScheme) -> DesignElevationTokens {
  let base_alpha = match scheme {
    @core.ColorScheme::Light => 0.10
    @core.ColorScheme::Dark => 0.28
  }
  // sm/md/lg stay on the neutral formula so generic controls (picker popup,
  // feedback) keep their existing depth. Only the Fluent-specific tiers carry
  // the layered card shadows.
  let neutral = elevation_tokens(scheme, lift=1.0)
  {
    sm: neutral.sm,
    md: neutral.md,
    lg: neutral.lg,
    // shadow4: resting card / raised surface.
    card: Some(
      @core.ShadowStyle::new(
        color=color(r=0.0, g=0.0, b=0.0, a=base_alpha),
        offset=@core.Point::new(x=0.0, y=2.0),
        blur_radius=4.0,
      ),
    ),
    // shadow16: flyout / menu / popover.
    flyout: Some(
      @core.ShadowStyle::new(
        color=color(r=0.0, g=0.0, b=0.0, a=base_alpha * 1.6),
        offset=@core.Point::new(x=0.0, y=8.0),
        blur_radius=16.0,
      ),
    ),
    // shadow64: dialog / modal overlay.
    dialog: Some(
      @core.ShadowStyle::new(
        color=color(r=0.0, g=0.0, b=0.0, a=base_alpha * 2.4),
        offset=@core.Point::new(x=0.0, y=32.0),
        blur_radius=64.0,
      ),
    ),
  }
}

///|
fn surface_tokens(
  palette : DesignSemanticPalette,
  scheme : @core.ColorScheme,
) -> DesignSurfaceTokens {
  let surfaces = @core.SurfaceScale::default(
    palette.core_palette(scheme),
    scheme,
  )
  { base: surfaces.base, raised: surfaces.raised, overlay: surfaces.overlay }
}

///|
fn state_layer_tokens(
  palette : DesignSemanticPalette,
) -> DesignStateLayerTokens {
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
fn component_tokens(
  scheme : @core.ColorScheme,
  palette : DesignSemanticPalette,
  typography : DesignTypographyTokens,
  radius : DesignRadiusTokens,
  spacing : DesignSpacingTokens,
  state_layer : DesignStateLayerTokens,
) -> DesignComponentTokens {
  let feedback_background_alpha = match scheme {
    @core.ColorScheme::Light => 0.12
    @core.ColorScheme::Dark => 0.22
  }
  {
    button: {
      primary: control_state_tokens(
        foreground=palette.primary_foreground,
        background=palette.primary,
        border=palette.primary,
        border_width=0.0,
        radius=radius.md,
        state_layer_alpha=state_layer.pressed_alpha,
      ),
      tonal: control_state_tokens(
        foreground=palette.foreground,
        background=palette.surface_variant,
        border=palette.surface_variant,
        border_width=0.0,
        radius=radius.md,
        state_layer_alpha=state_layer.hover_alpha,
      ),
      outline: control_state_tokens(
        foreground=palette.foreground,
        background=transparent(),
        border=palette.outline,
        border_width=1.0,
        radius=radius.md,
        state_layer_alpha=state_layer.hover_alpha,
      ),
      ghost: control_state_tokens(
        foreground=palette.foreground,
        background=transparent(),
        border=transparent(),
        border_width=0.0,
        radius=radius.md,
        state_layer_alpha=state_layer.hover_alpha,
      ),
      // Neutral presets alias subtle/subtle-brand to ghost/tonal so the shared
      // builder exposes a uniform 6-variant surface without imposing Fluent 2's
      // transparent-on-brand hover semantics on Material/Carbon/Primer.
      subtle: control_state_tokens(
        foreground=palette.foreground,
        background=transparent(),
        border=transparent(),
        border_width=0.0,
        radius=radius.md,
        state_layer_alpha=state_layer.hover_alpha,
      ),
      subtle_brand: control_state_tokens(
        foreground=palette.primary,
        background=transparent(),
        border=transparent(),
        border_width=0.0,
        radius=radius.md,
        state_layer_alpha=state_layer.hover_alpha,
      ),
    },
    text_field: {
      normal: control_state_tokens(
        foreground=palette.foreground,
        background=palette.surface,
        border=palette.outline,
        border_width=1.0,
        radius=radius.md,
        state_layer_alpha=state_layer.hover_alpha,
      ),
      focused: control_state_tokens(
        foreground=palette.foreground,
        background=palette.surface,
        border=palette.focus,
        border_width=2.0,
        radius=radius.md,
        state_layer_alpha=state_layer.focus_alpha,
      ),
      disabled: control_state_tokens(
        foreground=palette.muted,
        background=palette.surface_variant,
        border=palette.outline.multiply_alpha(state_layer.disabled_alpha),
        border_width=1.0,
        radius=radius.md,
        state_layer_alpha=state_layer.disabled_alpha,
      ),
      placeholder: palette.muted,
      cursor: palette.focus,
      font: typography.body,
      appearance: DesignTextFieldAppearance::Outline,
    },
    surface: {
      base_padding: spacing.md,
      raised_padding: spacing.lg,
      overlay_padding: spacing.md,
      base_radius: radius.md,
      raised_radius: radius.lg,
      overlay_radius: radius.lg,
      base_shadow: None,
      raised_shadow: None,
      overlay_shadow: None,
    },
    choice_control: {
      foreground: palette.foreground,
      selected_color: palette.primary,
      disabled_foreground: palette.muted,
      disabled_selected_color: palette.primary.multiply_alpha(0.42),
      control_size: 20.0,
      box_shape: @views.ChoiceControlShape::Square,
      check_style: @views.CheckMarkStyle::Checkmark,
    },
    progress: {
      foreground: palette.primary,
      background: palette.surface_variant,
      radius: radius.pill,
    },
    slider: {
      foreground: palette.primary,
      background: palette.surface_variant,
      thumb_color: palette.primary,
      track_height: 6.0,
      thumb_size: 20.0,
      radius: radius.pill,
      thumb_shape: @views.ThumbShape::Circle,
    },
    picker: {
      font: typography.control,
      foreground: palette.foreground,
      background: @core.Brush::solid(palette.surface),
      radius: radius.md,
      popup_max_height: 200.0,
    },
    date_picker: {
      font: typography.control,
      foreground: palette.foreground,
      background: @core.Brush::solid(palette.surface),
      radius: radius.md,
      popup_max_height: 200.0,
    },
    feedback: {
      neutral: tone_tokens(
        foreground=palette.muted,
        background_alpha=feedback_background_alpha,
        border_alpha=0.72,
      ),
      info: tone_tokens(
        foreground=palette.info,
        background_alpha=feedback_background_alpha,
        border_alpha=0.72,
      ),
      success: tone_tokens(
        foreground=palette.success,
        background_alpha=feedback_background_alpha,
        border_alpha=0.72,
      ),
      warning: tone_tokens(
        foreground=palette.warning,
        background_alpha=feedback_background_alpha,
        border_alpha=0.72,
      ),
      danger: tone_tokens(
        foreground=palette.danger,
        background_alpha=feedback_background_alpha,
        border_alpha=0.72,
      ),
      radius: radius.md,
      padding: spacing.sm,
    },
    badge: {
      neutral: {
        foreground: palette.foreground,
        background: palette.surface_variant,
        border: palette.outline.multiply_alpha(0.42),
      },
      accent: badge_tone_tokens(palette.info),
      success: badge_tone_tokens(palette.success),
      warning: badge_tone_tokens(palette.warning),
      danger: badge_tone_tokens(palette.danger),
      radius: radius.pill,
      padding: 3.0,
    },
    form_validation: {
      foreground: palette.danger,
      background: palette.danger.multiply_alpha(0.12),
      border: palette.danger.multiply_alpha(0.72),
      radius: radius.md,
      padding: spacing.md,
    },
  }
}

///|
fn tone_tokens(
  foreground~ : @core.Color,
  background_alpha~ : Double,
  border_alpha~ : Double,
) -> DesignToneTokens {
  {
    foreground,
    background: foreground.multiply_alpha(background_alpha),
    border: foreground.multiply_alpha(border_alpha),
  }
}

///|
fn badge_tone_tokens(background : @core.Color) -> DesignToneTokens {
  { foreground: @core.Color::white(), background, border: background }
}

///|
fn control_state_tokens(
  foreground~ : @core.Color,
  background~ : @core.Color,
  border~ : @core.Color,
  border_width~ : Double,
  radius~ : Double,
  state_layer_alpha~ : Double,
  bottom_border_only? : Bool = false,
  inner_focus_border? : @core.Color? = None,
) -> DesignControlStateTokens {
  {
    foreground,
    background,
    border,
    border_width,
    radius,
    state_layer_alpha,
    bottom_border_only,
    inner_focus_border,
  }
}

///|
fn control_state_border(state : DesignControlStateTokens) -> @core.BorderStyle? {
  if state.border_width > 0.0 {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(state.border),
        width=state.border_width,
      ),
    )
  } else {
    None
  }
}

///|
fn button_core_style(
  state : DesignControlStateTokens,
  state_layer : DesignStateLayerTokens,
) -> @views.ButtonStyle {
  let normal = state.core_style()
  let hovered = @views.new_control_state_style(
    foreground=normal.foreground,
    background=@core.Brush::solid(
      state_layer_background(
        state.background,
        state_layer.color,
        state_layer.hover_alpha,
      ),
    ),
    border?=normal.border,
    radius=normal.radius,
    shadow?=normal.shadow,
    bottom_border_only=normal.bottom_border_only,
    inner_focus_border=normal.inner_focus_border,
  )
  let pressed = @views.new_control_state_style(
    foreground=normal.foreground,
    background=@core.Brush::solid(
      state_layer_background(
        state.background,
        state_layer.color,
        state_layer.pressed_alpha,
      ),
    ),
    border?=normal.border,
    radius=normal.radius,
    shadow?=normal.shadow,
    bottom_border_only=normal.bottom_border_only,
    inner_focus_border=normal.inner_focus_border,
  )
  let disabled = @views.new_control_state_style(
    foreground=normal.foreground.multiply_alpha(state_layer.disabled_alpha),
    background=normal.background.multiply_alpha(state_layer.disabled_alpha),
    border?=control_state_disabled_border(normal.border, state_layer),
    radius=normal.radius,
    bottom_border_only=normal.bottom_border_only,
    inner_focus_border=normal.inner_focus_border,
  )
  @views.ButtonStyle::new(normal~, hovered~, pressed~, disabled~)
}

///|
fn control_state_disabled_border(
  border : @core.BorderStyle?,
  state_layer : DesignStateLayerTokens,
) -> @core.BorderStyle? {
  match border {
    Some(value) =>
      Some({
        ..value,
        brush: value.brush.multiply_alpha(state_layer.disabled_alpha),
      })
    None => None
  }
}

///|
fn state_layer_background(
  background : @core.Color,
  layer : @core.Color,
  alpha : Double,
) -> @core.Color {
  if background.a <= 0.0 {
    layer.with_alpha(alpha)
  } else {
    let amount = clamp_unit(alpha)
    @core.Color::rgba(
      r=background.r * (1.0 - amount) + layer.r * amount,
      g=background.g * (1.0 - amount) + layer.g * amount,
      b=background.b * (1.0 - amount) + layer.b * amount,
      a=background.a,
    )
  }
}

///|
fn clamp_unit(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn transparent() -> @core.Color {
  @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
}

///|
fn scheme_variant(scheme : @core.ColorScheme) -> DesignSchemeVariant {
  match scheme {
    @core.ColorScheme::Light => DesignSchemeVariant::SchemeLight
    @core.ColorScheme::Dark => DesignSchemeVariant::SchemeDark
  }
}

///|
fn variant_core_scheme(
  variant : DesignSchemeVariant,
  system_scheme : @core.ColorScheme,
) -> @core.ColorScheme {
  match variant {
    DesignSchemeVariant::SchemeLight => @core.ColorScheme::Light
    DesignSchemeVariant::SchemeDark => @core.ColorScheme::Dark
    DesignSchemeVariant::SchemeHighContrast => system_scheme
    DesignSchemeVariant::SchemeSystem => system_scheme
  }
}
