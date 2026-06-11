///|
pub(all) struct TextStyle {
  font : FontSpec
  color : Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SurfaceStyle {
  brush : Brush
  border : BorderStyle?
  radius : Double
  shadow : ShadowStyle?
  padding : Insets
  level : SurfaceLevel
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ControlStateStyle {
  foreground : Color
  background : Brush
  border : BorderStyle?
  radius : Double
  shadow : ShadowStyle?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ButtonStyle {
  normal : ControlStateStyle
  hovered : ControlStateStyle
  pressed : ControlStateStyle
  disabled : ControlStateStyle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextFieldStyle {
  normal : ControlStateStyle
  focused : ControlStateStyle
  disabled : ControlStateStyle
  placeholder_color : Color
  cursor_color : Color
  font : FontSpec
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ChoiceControlStyle {
  foreground : Color
  selected_color : Color
  disabled_foreground : Color
  disabled_selected_color : Color
  control_size : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ProgressStyle {
  foreground : Color
  background : Color
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SliderStyle {
  foreground : Color
  background : Color
  thumb_color : Color
  track_height : Double
  thumb_size : Double
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PickerStyle {
  font : FontSpec
  foreground : Color
  background : Brush
  radius : Double
  popup_max_height : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ToneStyle {
  foreground : Color
  background : Color
  border : Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FeedbackStyle {
  neutral : ToneStyle
  info : ToneStyle
  success : ToneStyle
  warning : ToneStyle
  danger : ToneStyle
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct BadgeStyle {
  neutral : ToneStyle
  accent : ToneStyle
  success : ToneStyle
  warning : ToneStyle
  danger : ToneStyle
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FormValidationStyle {
  foreground : Color
  background : Color
  border : Color
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub fn TextStyle::body(theme? : Theme = Theme::default()) -> TextStyle {
  { font: theme.typography.body, color: theme.foreground }
}

///|
pub fn TextStyle::title(theme? : Theme = Theme::default()) -> TextStyle {
  { font: theme.typography.title, color: theme.foreground }
}

///|
pub fn SurfaceStyle::default(theme? : Theme = Theme::default()) -> SurfaceStyle {
  {
    brush: theme.surface_brush(SurfaceLevel::Base),
    border: None,
    radius: theme.radius_scale.md,
    shadow: None,
    padding: Insets::all(theme.spacing_scale.md),
    level: SurfaceLevel::Base,
  }
}

///|
pub fn SurfaceStyle::raised(theme? : Theme = Theme::default()) -> SurfaceStyle {
  {
    brush: theme.surface_brush(SurfaceLevel::Raised),
    border: Some(
      BorderStyle::new(brush=Brush::solid(theme.palette.outline), width=1.0),
    ),
    radius: theme.radius_scale.lg,
    shadow: Some(theme.shadow_scale.md),
    padding: Insets::all(theme.spacing_scale.lg),
    level: SurfaceLevel::Raised,
  }
}

///|
fn control_state(
  foreground~ : Color,
  background~ : Brush,
  border? : BorderStyle,
  radius? : Double = 0.0,
  shadow? : ShadowStyle,
) -> ControlStateStyle {
  { foreground, background, border, radius, shadow }
}

///|
pub fn ButtonStyle::filled(theme? : Theme = Theme::default()) -> ButtonStyle {
  let normal = control_state(
    foreground=theme.palette.primary_foreground,
    background=Brush::solid(theme.palette.primary),
    radius=theme.radius_scale.md,
  )
  let hovered = control_state(
    foreground=theme.palette.primary_foreground,
    background=Brush::solid(Color::rgba(r=0.18, g=0.42, b=1.0)),
    radius=theme.radius_scale.md,
  )
  let pressed = control_state(
    foreground=theme.palette.primary_foreground,
    background=Brush::solid(Color::rgba(r=0.08, g=0.25, b=0.76)),
    radius=theme.radius_scale.md,
  )
  let disabled = control_state(
    foreground=theme.palette.muted,
    background=Brush::solid(theme.palette.surface_variant),
    radius=theme.radius_scale.md,
  )
  { normal, hovered, pressed, disabled }
}

///|
pub fn ButtonStyle::tonal(theme? : Theme = Theme::default()) -> ButtonStyle {
  let normal = control_state(
    foreground=theme.foreground,
    background=Brush::solid(theme.palette.surface_variant),
    radius=theme.radius_scale.md,
  )
  { normal, hovered: normal, pressed: normal, disabled: normal }
}

///|
pub fn ButtonStyle::outline(theme? : Theme = Theme::default()) -> ButtonStyle {
  let normal = control_state(
    foreground=theme.foreground,
    background=Brush::solid(Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
    border=BorderStyle::new(
      brush=Brush::solid(theme.palette.outline),
      width=1.0,
    ),
    radius=theme.radius_scale.md,
  )
  { normal, hovered: normal, pressed: normal, disabled: normal }
}

///|
pub fn ButtonStyle::ghost(theme? : Theme = Theme::default()) -> ButtonStyle {
  let normal = control_state(
    foreground=theme.foreground,
    background=Brush::solid(Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
    radius=theme.radius_scale.md,
  )
  { normal, hovered: normal, pressed: normal, disabled: normal }
}

///|
pub fn TextFieldStyle::filled(
  theme? : Theme = Theme::default(),
) -> TextFieldStyle {
  let normal = control_state(
    foreground=theme.foreground,
    background=Brush::solid(theme.palette.surface),
    border=BorderStyle::new(
      brush=Brush::solid(theme.palette.outline),
      width=1.0,
    ),
    radius=theme.radius_scale.md,
  )
  let focused = control_state(
    foreground=theme.foreground,
    background=Brush::solid(theme.palette.surface),
    border=BorderStyle::new(
      brush=Brush::solid(theme.palette.primary),
      width=2.0,
    ),
    radius=theme.radius_scale.md,
  )
  {
    normal,
    focused,
    disabled: normal,
    placeholder_color: theme.palette.muted,
    cursor_color: theme.palette.primary,
    font: theme.typography.body,
  }
}

///|
pub fn TextFieldStyle::outline(
  theme? : Theme = Theme::default(),
) -> TextFieldStyle {
  TextFieldStyle::filled(theme~)
}

///|
pub fn ChoiceControlStyle::default(
  theme? : Theme = Theme::default(),
) -> ChoiceControlStyle {
  {
    foreground: theme.palette.foreground,
    selected_color: theme.palette.primary,
    disabled_foreground: theme.palette.muted,
    disabled_selected_color: theme.palette.primary.multiply_alpha(0.42),
    control_size: 20.0,
  }
}

///|
pub fn ProgressStyle::default(
  theme? : Theme = Theme::default(),
) -> ProgressStyle {
  {
    foreground: theme.palette.primary,
    background: theme.palette.surface_variant,
    radius: theme.radius_scale.pill,
  }
}

///|
pub fn SliderStyle::default(theme? : Theme = Theme::default()) -> SliderStyle {
  {
    foreground: theme.palette.primary,
    background: theme.palette.surface_variant,
    thumb_color: theme.palette.primary,
    track_height: 6.0,
    thumb_size: 20.0,
    radius: theme.radius_scale.pill,
  }
}

///|
pub fn PickerStyle::default(theme? : Theme = Theme::default()) -> PickerStyle {
  {
    font: theme.typography.control,
    foreground: theme.foreground,
    background: Brush::solid(theme.palette.surface),
    radius: theme.radius_scale.md,
    popup_max_height: 200.0,
  }
}

///|
pub fn FeedbackStyle::default(
  theme? : Theme = Theme::default(),
) -> FeedbackStyle {
  let background_alpha = match theme.scheme {
    ColorScheme::Light => 0.12
    ColorScheme::Dark => 0.22
  }
  {
    neutral: tone_style(
      foreground=theme.palette.muted,
      background_alpha~,
      border_alpha=0.72,
    ),
    info: tone_style(
      foreground=theme.semantic_colors.info,
      background_alpha~,
      border_alpha=0.72,
    ),
    success: tone_style(
      foreground=theme.semantic_colors.success,
      background_alpha~,
      border_alpha=0.72,
    ),
    warning: tone_style(
      foreground=theme.semantic_colors.warning,
      background_alpha~,
      border_alpha=0.72,
    ),
    danger: tone_style(
      foreground=theme.semantic_colors.danger,
      background_alpha~,
      border_alpha=0.72,
    ),
    radius: theme.radius_scale.md,
    padding: theme.spacing_scale.sm,
  }
}

///|
pub fn BadgeStyle::default(theme? : Theme = Theme::default()) -> BadgeStyle {
  {
    neutral: {
      foreground: theme.palette.foreground,
      background: theme.palette.surface_variant,
      border: theme.palette.outline.multiply_alpha(0.42),
    },
    accent: badge_tone(theme.semantic_colors.info),
    success: badge_tone(theme.semantic_colors.success),
    warning: badge_tone(theme.semantic_colors.warning),
    danger: badge_tone(theme.semantic_colors.danger),
    radius: theme.radius_scale.pill,
    padding: 3.0,
  }
}

///|
pub fn FormValidationStyle::default(
  theme? : Theme = Theme::default(),
) -> FormValidationStyle {
  let color = theme.semantic_colors.danger
  {
    foreground: color,
    background: color.multiply_alpha(0.12),
    border: color.multiply_alpha(0.72),
    radius: theme.radius_scale.md,
    padding: theme.spacing_scale.md,
  }
}

///|
fn tone_style(
  foreground~ : Color,
  background_alpha~ : Double,
  border_alpha~ : Double,
) -> ToneStyle {
  {
    foreground,
    background: foreground.multiply_alpha(background_alpha),
    border: foreground.multiply_alpha(border_alpha),
  }
}

///|
fn badge_tone(background : Color) -> ToneStyle {
  { foreground: Color::white(), background, border: background }
}
