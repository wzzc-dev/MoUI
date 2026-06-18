///|
pub(all) enum DesignDensity {
  Compact
  Standard
  Comfortable
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSemanticPalette {
  foreground : @core.Color
  background : @core.Color
  surface : @core.Color
  surface_variant : @core.Color
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
pub(all) struct DesignTypographyTokens {
  body : @core.FontSpec
  title : @core.FontSpec
  caption : @core.FontSpec
  control : @core.FontSpec
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
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignButtonTokens {
  primary : DesignControlStateTokens
  tonal : DesignControlStateTokens
  outline : DesignControlStateTokens
  ghost : DesignControlStateTokens
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignTextFieldTokens {
  normal : DesignControlStateTokens
  focused : DesignControlStateTokens
  disabled : DesignControlStateTokens
  placeholder : @core.Color
  cursor : @core.Color
  font : @core.FontSpec
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSurfaceComponentTokens {
  base_padding : Double
  raised_padding : Double
  overlay_padding : Double
  base_radius : Double
  raised_radius : Double
  overlay_radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignChoiceControlTokens {
  foreground : @core.Color
  selected_color : @core.Color
  disabled_foreground : @core.Color
  disabled_selected_color : @core.Color
  control_size : Double
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
pub fn DesignSemanticPalette::core_palette(
  self : DesignSemanticPalette,
) -> @core.ColorPalette {
  palette(
    foreground=self.foreground,
    background=self.background,
    surface=self.surface,
    surface_variant=self.surface_variant,
    primary=self.primary,
    primary_foreground=self.primary_foreground,
    outline=self.outline,
    muted=self.muted,
  )
}

///|
pub fn DesignSemanticPalette::core_semantic_colors(
  self : DesignSemanticPalette,
) -> @core.SemanticColorScale {
  {
    success: self.success,
    warning: self.warning,
    danger: self.danger,
    info: self.info,
    focus: self.focus,
    scrim: self.scrim,
  }
}

///|
pub fn DesignTypographyTokens::core_typography(
  self : DesignTypographyTokens,
) -> @core.TypographyScale {
  // Start from the neutral default so the extended tiers (display/headline/
  // subtitle/label/overline) keep sensible values, then override the four
  // legacy slots this design-system token set owns.
  {
    ..@core.TypographyScale::default(),
    body: self.body,
    title: self.title,
    caption: self.caption,
    control: self.control,
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
  {
    foreground: self.foreground,
    background: @core.Brush::solid(self.background),
    border: control_state_border(self),
    radius: self.radius,
    shadow: None,
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
  }
}

///|
pub fn DesignTextFieldTokens::core_style(
  self : DesignTextFieldTokens,
) -> @views.TextFieldStyle {
  {
    normal: self.normal.core_style(),
    focused: self.focused.core_style(),
    disabled: self.disabled.core_style(),
    placeholder_color: self.placeholder,
    cursor_color: self.cursor,
    font: self.font,
  }
}

///|
pub fn DesignTextFieldTokens::core_styles(
  self : DesignTextFieldTokens,
) -> DesignTextFieldCoreStyles {
  let filled = self.core_style()
  let clear = @core.Brush::solid(transparent())
  let plain_normal = {
    ..filled.normal,
    background: clear,
    border: None,
    radius: 0.0,
  }
  let plain = { ..filled, normal: plain_normal, focused: plain_normal }
  { filled, outline: filled, plain }
}

///|
pub fn DesignChoiceControlTokens::core_style(
  self : DesignChoiceControlTokens,
) -> @views.ChoiceControlStyle {
  {
    foreground: self.foreground,
    selected_color: self.selected_color,
    disabled_foreground: self.disabled_foreground,
    disabled_selected_color: self.disabled_selected_color,
    control_size: self.control_size,
  }
}

///|
pub fn DesignProgressTokens::core_style(
  self : DesignProgressTokens,
) -> @views.ProgressStyle {
  {
    foreground: self.foreground,
    background: self.background,
    radius: self.radius,
  }
}

///|
pub fn DesignSliderTokens::core_style(
  self : DesignSliderTokens,
) -> @views.SliderStyle {
  {
    foreground: self.foreground,
    background: self.background,
    thumb_color: self.thumb_color,
    track_height: self.track_height,
    thumb_size: self.thumb_size,
    radius: self.radius,
  }
}

///|
pub fn DesignPickerTokens::core_style(
  self : DesignPickerTokens,
) -> @views.PickerStyle {
  {
    font: self.font,
    foreground: self.foreground,
    background: self.background,
    radius: self.radius,
    popup_max_height: self.popup_max_height,
  }
}

///|
pub fn DesignSurfaceComponentTokens::core_styles(
  self : DesignSurfaceComponentTokens,
  theme : @core.Theme,
) -> DesignSurfaceCoreStyles {
  let base = {
    ..@views.SurfaceStyle::default(theme~),
    padding: @core.Insets::all(self.base_padding),
    radius: self.base_radius,
  }
  let raised = {
    ..@views.SurfaceStyle::raised(theme~),
    padding: @core.Insets::all(self.raised_padding),
    radius: self.raised_radius,
  }
  let overlay = {
    ..@views.SurfaceStyle::default(theme~),
    brush: theme.surface_brush(@core.SurfaceLevel::Overlay),
    padding: @core.Insets::all(self.overlay_padding),
    radius: self.overlay_radius,
    shadow: Some(theme.shadow_scale.sm),
    level: @core.SurfaceLevel::Overlay,
  }
  { base, raised, overlay }
}

///|
pub fn DesignToneTokens::core_style(
  self : DesignToneTokens,
) -> @views.ToneStyle {
  {
    foreground: self.foreground,
    background: self.background,
    border: self.border,
  }
}

///|
pub fn DesignFeedbackTokens::core_style(
  self : DesignFeedbackTokens,
) -> @views.FeedbackStyle {
  {
    neutral: self.neutral.core_style(),
    info: self.info.core_style(),
    success: self.success.core_style(),
    warning: self.warning.core_style(),
    danger: self.danger.core_style(),
    radius: self.radius,
    padding: self.padding,
  }
}

///|
pub fn DesignBadgeTokens::core_style(
  self : DesignBadgeTokens,
) -> @views.BadgeStyle {
  {
    neutral: self.neutral.core_style(),
    accent: self.accent.core_style(),
    success: self.success.core_style(),
    warning: self.warning.core_style(),
    danger: self.danger.core_style(),
    radius: self.radius,
    padding: self.padding,
  }
}

///|
pub fn DesignFormValidationTokens::core_style(
  self : DesignFormValidationTokens,
) -> @views.FormValidationStyle {
  {
    foreground: self.foreground,
    background: self.background,
    border: self.border,
    radius: self.radius,
    padding: self.padding,
  }
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
  .with_palette(self.palette.core_palette())
  .with_semantic_colors(self.palette.core_semantic_colors())
  .with_spacing_scale(self.spacing.core_spacing_scale())
  .with_radius_scale(self.radius.core_radius_scale())
  .with_typography(self.typography.core_typography())
  .with_shadow_scale(self.elevation.core_shadow_scale())
  .with_motion(self.motion.core_motion())
  .with_surfaces(self.surfaces.core_surfaces())
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
  let palette = match scheme {
    @core.ColorScheme::Light =>
      semantic_palette(
        foreground=color_byte(r=36, g=36, b=36),
        background=@core.Color::white(),
        surface=color_byte(r=250, g=250, b=250),
        surface_variant=color_byte(r=245, g=245, b=245),
        primary=color_byte(r=0, g=120, b=212),
        primary_foreground=@core.Color::white(),
        outline=color_byte(r=209, g=209, b=209),
        muted=color_byte(r=97, g=97, b=97),
        success=color_byte(r=16, g=124, b=16),
        warning=color_byte(r=218, g=59, b=1),
        danger=color_byte(r=209, g=52, b=56),
        info=color_byte(r=0, g=120, b=212),
        focus=Some(@core.Color::black()),
        scrim=Some(color(r=0.0, g=0.0, b=0.0, a=0.4)),
      )
    @core.ColorScheme::Dark =>
      semantic_palette(
        foreground=color(r=0.95, g=0.95, b=0.95),
        background=color(r=0.08, g=0.09, b=0.10),
        surface=color(r=0.13, g=0.14, b=0.16),
        surface_variant=color(r=0.20, g=0.22, b=0.25),
        primary=color(r=0.38, g=0.71, b=1.0),
        primary_foreground=color(r=0.02, g=0.06, b=0.10),
        outline=color(r=0.36, g=0.39, b=0.43),
        muted=color(r=0.70, g=0.73, b=0.77),
        success=color(r=0.42, g=0.75, b=0.49),
        warning=color(r=0.95, g=0.70, b=0.34),
        danger=color(r=1.0, g=0.55, b=0.57),
        info=color(r=0.51, g=0.73, b=1.0),
      )
  }
  design_tokens(
    preset=DesignPreset::Fluent,
    scheme~,
    variant~,
    density~,
    source_family="Fluent alias tokens",
    palette~,
    spacing=spacing_tokens(
      { xs: 4.0, sm: 8.0, md: 12.0, lg: 20.0, xl: 32.0 },
      density,
    ),
    radius={ sm: 2.0, md: 4.0, lg: 8.0, pill: 999.0 },
    typography=typography_tokens(
      title=22.0,
      body=14.0,
      caption=12.0,
      control=14.0,
    ),
    elevation=elevation_tokens(scheme, lift=1.0),
    motion={
      fast_ms: 100.0,
      normal_ms: 200.0,
      slow_ms: 300.0,
      easing: @core.Easing::EaseOut,
    },
  )
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
) -> DesignSemanticPalette {
  {
    foreground,
    background,
    surface,
    surface_variant,
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
) -> DesignTypographyTokens {
  {
    body: @core.FontSpec::new(size=body, weight=400),
    title: @core.FontSpec::new(size=title, weight=700),
    caption: @core.FontSpec::new(size=caption, weight=400),
    control: @core.FontSpec::new(size=control, weight=600),
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
  { sm: shadows.sm, md: shadows.md, lg: shadows.lg }
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
  }
}

///|
fn surface_tokens(
  palette : DesignSemanticPalette,
  scheme : @core.ColorScheme,
) -> DesignSurfaceTokens {
  let surfaces = @core.SurfaceScale::default(palette.core_palette(), scheme)
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
    },
    surface: {
      base_padding: spacing.md,
      raised_padding: spacing.lg,
      overlay_padding: spacing.md,
      base_radius: radius.md,
      raised_radius: radius.lg,
      overlay_radius: radius.lg,
    },
    choice_control: {
      foreground: palette.foreground,
      selected_color: palette.primary,
      disabled_foreground: palette.muted,
      disabled_selected_color: palette.primary.multiply_alpha(0.42),
      control_size: 20.0,
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
) -> DesignControlStateTokens {
  { foreground, background, border, border_width, radius, state_layer_alpha }
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
  let hovered = {
    ..normal,
    background: @core.Brush::solid(
      state_layer_background(
        state.background,
        state_layer.color,
        state_layer.hover_alpha,
      ),
    ),
  }
  let pressed = {
    ..normal,
    background: @core.Brush::solid(
      state_layer_background(
        state.background,
        state_layer.color,
        state_layer.pressed_alpha,
      ),
    ),
  }
  let disabled = {
    ..normal,
    foreground: normal.foreground.multiply_alpha(state_layer.disabled_alpha),
    background: normal.background.multiply_alpha(state_layer.disabled_alpha),
    border: control_state_disabled_border(normal.border, state_layer),
    shadow: None,
  }
  { normal, hovered, pressed, disabled }
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
