///|
pub(all) struct TextStyle {
  font : @core.FontSpec
  color : @core.Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SurfaceStyle {
  brush : @core.Brush
  border : @core.BorderStyle?
  radius : Double
  shadow : @core.ShadowStyle?
  padding : @core.Insets
  level : @core.SurfaceLevel
} derive(Eq, Debug, ToJson)

///|
/// Resolved per-state control style. This is an alias of
/// `@core.ControlStateStyle`; the type lives in `core` so both the token
/// resolver and the view-layer style structs share one definition.
pub using @core {type ControlStateStyle}

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
  placeholder_color : @core.Color
  cursor_color : @core.Color
  font : @core.FontSpec
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ChoiceControlStyle {
  foreground : @core.Color
  selected_color : @core.Color
  disabled_foreground : @core.Color
  disabled_selected_color : @core.Color
  control_size : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ProgressStyle {
  foreground : @core.Color
  background : @core.Color
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SliderStyle {
  foreground : @core.Color
  background : @core.Color
  thumb_color : @core.Color
  track_height : Double
  thumb_size : Double
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PickerStyle {
  font : @core.FontSpec
  foreground : @core.Color
  background : @core.Brush
  radius : Double
  popup_max_height : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ToneStyle {
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
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
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub fn TextStyle::body(theme? : @core.Theme) -> TextStyle {
  let resolved_theme = views_ambient_theme(theme)
  {
    font: resolved_theme.typography.body,
    color: resolved_theme.palette.foreground,
  }
}

///|
pub fn TextStyle::title(theme? : @core.Theme) -> TextStyle {
  let resolved_theme = views_ambient_theme(theme)
  {
    font: resolved_theme.typography.title,
    color: resolved_theme.palette.foreground,
  }
}

///|
pub fn SurfaceStyle::default(theme? : @core.Theme) -> SurfaceStyle {
  let resolved_theme = views_ambient_theme(theme)
  {
    brush: resolved_theme.surface_brush(@core.SurfaceLevel::Base),
    border: None,
    radius: resolved_theme.radius_scale.md,
    shadow: None,
    padding: @core.Insets::all(resolved_theme.spacing_scale.md),
    level: @core.SurfaceLevel::Base,
  }
}

///|
pub fn SurfaceStyle::raised(theme? : @core.Theme) -> SurfaceStyle {
  let resolved_theme = views_ambient_theme(theme)
  // shadcn/minimal: raised surfaces are flat with a border, no shadow. Layer
  // separation comes from the outline tone. Dark mode uses a faint white edge
  // since the outline token alone is too subtle against dark surfaces.
  let border_color = match resolved_theme.scheme {
    @core.ColorScheme::Light => resolved_theme.palette.outline
    @core.ColorScheme::Dark => @core.Color::white().multiply_alpha(0.06)
  }
  {
    brush: resolved_theme.surface_brush(@core.SurfaceLevel::Raised),
    border: Some(
      @core.BorderStyle::new(brush=@core.Brush::solid(border_color), width=1.0),
    ),
    radius: resolved_theme.radius_scale.lg,
    shadow: None,
    padding: @core.Insets::all(resolved_theme.spacing_scale.lg),
    level: @core.SurfaceLevel::Raised,
  }
}

///|
fn control_state(
  foreground~ : @core.Color,
  background~ : @core.Brush,
  border? : @core.BorderStyle,
  radius? : Double = 0.0,
  shadow? : @core.ShadowStyle,
  bottom_border_only? : Bool = false,
  inner_focus_border? : @core.Color? = None,
) -> ControlStateStyle {
  {
    foreground,
    background,
    border,
    radius,
    shadow,
    bottom_border_only,
    inner_focus_border,
  }
}

///|
pub fn ButtonStyle::filled(theme? : @core.Theme) -> ButtonStyle {
  let resolved_theme = views_ambient_theme(theme)
  let primary = resolved_theme.palette.primary
  // shadcn/minimal: flat primary button, no shadow. Hover/press use opacity
  // overlays rather than color shifts, so the button stays a solid block that
  // just dims — the shadcn idiom. Tracks any primary including near-black.
  let normal = control_state(
    foreground=resolved_theme.palette.on_primary,
    background=@core.Brush::solid(primary),
    radius=resolved_theme.radius_scale.md,
  )
  let hovered = control_state(
    foreground=resolved_theme.palette.on_primary,
    background=@core.Brush::solid(primary.multiply_alpha(0.90)),
    radius=resolved_theme.radius_scale.md,
  )
  let pressed = control_state(
    foreground=resolved_theme.palette.on_primary,
    background=@core.Brush::solid(primary.multiply_alpha(0.80)),
    radius=resolved_theme.radius_scale.md,
  )
  let disabled = control_state(
    foreground=resolved_theme.palette.muted,
    background=@core.Brush::solid(resolved_theme.palette.surface_variant),
    radius=resolved_theme.radius_scale.md,
  )
  { normal, hovered, pressed, disabled }
}

///|
pub fn ButtonStyle::tonal(theme? : @core.Theme) -> ButtonStyle {
  let resolved_theme = views_ambient_theme(theme)
  // Tonal uses a translucent primary tint over the surface so the control
  // reads as related to the accent without the full saturation of `filled`.
  let base = resolved_theme.palette.surface.lerp(
    resolved_theme.palette.primary,
    0.12,
  )
  let normal = control_state(
    foreground=resolved_theme.palette.primary,
    background=@core.Brush::solid(base),
    radius=resolved_theme.radius_scale.md,
  )
  // Layer a translucent primary tint over the tonal base for hover/press so
  // the control visibly responds to interaction while staying low-emphasis.
  let hovered = control_state(
    foreground=resolved_theme.palette.primary,
    background=@core.Brush::solid(
      base.lerp(resolved_theme.palette.primary, 0.22),
    ),
    radius=resolved_theme.radius_scale.md,
  )
  let pressed = control_state(
    foreground=resolved_theme.palette.primary,
    background=@core.Brush::solid(
      base.lerp(resolved_theme.palette.primary, 0.34),
    ),
    radius=resolved_theme.radius_scale.md,
  )
  let disabled = control_state(
    foreground=resolved_theme.palette.muted,
    background=@core.Brush::solid(base.multiply_alpha(0.6)),
    radius=resolved_theme.radius_scale.md,
  )
  { normal, hovered, pressed, disabled }
}

///|
pub fn ButtonStyle::outline(theme? : @core.Theme) -> ButtonStyle {
  let resolved_theme = views_ambient_theme(theme)
  // shadcn/minimal outline: 1px border at rest, surface-tint background on
  // hover/press. Foreground stays constant — no color shift, just a wash.
  let border = @core.BorderStyle::new(
    brush=@core.Brush::solid(resolved_theme.palette.outline.multiply_alpha(0.8)),
    width=1.0,
  )
  let normal = control_state(
    foreground=resolved_theme.palette.foreground,
    background=@core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
    border~,
    radius=resolved_theme.radius_scale.md,
  )
  let hovered = control_state(
    foreground=resolved_theme.palette.foreground,
    background=@core.Brush::solid(resolved_theme.palette.surface_variant),
    border~,
    radius=resolved_theme.radius_scale.md,
  )
  let pressed = control_state(
    foreground=resolved_theme.palette.foreground,
    background=@core.Brush::solid(
      resolved_theme.palette.surface_variant.lerp(
        resolved_theme.palette.foreground,
        0.06,
      ),
    ),
    border~,
    radius=resolved_theme.radius_scale.md,
  )
  let disabled = control_state(
    foreground=resolved_theme.palette.muted,
    background=@core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
    border=@core.BorderStyle::new(
      brush=@core.Brush::solid(
        resolved_theme.palette.outline.multiply_alpha(0.5),
      ),
      width=1.0,
    ),
    radius=resolved_theme.radius_scale.md,
  )
  { normal, hovered, pressed, disabled }
}

///|
pub fn ButtonStyle::ghost(theme? : @core.Theme) -> ButtonStyle {
  let resolved_theme = views_ambient_theme(theme)
  let transparent = @core.Brush::solid(
    @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
  )
  let normal = control_state(
    foreground=resolved_theme.palette.foreground,
    background=transparent,
    radius=resolved_theme.radius_scale.md,
  )
  // Ghost stays borderless and transparent at rest; hover/press introduce a
  // subtle foreground-tinted wash so the hit area is discoverable.
  let hovered = control_state(
    foreground=resolved_theme.palette.foreground,
    background=@core.Brush::solid(
      resolved_theme.palette.foreground.multiply_alpha(0.06),
    ),
    radius=resolved_theme.radius_scale.md,
  )
  let pressed = control_state(
    foreground=resolved_theme.palette.foreground,
    background=@core.Brush::solid(
      resolved_theme.palette.foreground.multiply_alpha(0.12),
    ),
    radius=resolved_theme.radius_scale.md,
  )
  let disabled = control_state(
    foreground=resolved_theme.palette.muted,
    background=transparent,
    radius=resolved_theme.radius_scale.md,
  )
  { normal, hovered, pressed, disabled }
}

///|
pub fn TextFieldStyle::filled(theme? : @core.Theme) -> TextFieldStyle {
  let resolved_theme = views_ambient_theme(theme)
  let normal = control_state(
    foreground=resolved_theme.palette.foreground,
    background=@core.Brush::solid(resolved_theme.palette.surface),
    border=@core.BorderStyle::new(
      brush=@core.Brush::solid(
        resolved_theme.palette.outline.multiply_alpha(0.85),
      ),
      width=1.0,
    ),
    radius=resolved_theme.radius_scale.md,
  )
  let focused = control_state(
    foreground=resolved_theme.palette.foreground,
    background=@core.Brush::solid(resolved_theme.palette.surface),
    border=@core.BorderStyle::new(
      brush=@core.Brush::solid(resolved_theme.palette.primary),
      width=2.0,
    ),
    radius=resolved_theme.radius_scale.md,
  )
  {
    normal,
    focused,
    disabled: normal,
    placeholder_color: resolved_theme.palette.muted,
    cursor_color: resolved_theme.palette.primary,
    font: resolved_theme.typography.body,
  }
}

///|
pub fn TextFieldStyle::outline(theme? : @core.Theme) -> TextFieldStyle {
  let resolved_theme = views_ambient_theme(theme)
  TextFieldStyle::filled(theme=resolved_theme)
}

///|
pub fn ChoiceControlStyle::default(theme? : @core.Theme) -> ChoiceControlStyle {
  let resolved_theme = views_ambient_theme(theme)
  {
    foreground: resolved_theme.palette.foreground,
    selected_color: resolved_theme.palette.primary,
    disabled_foreground: resolved_theme.palette.muted,
    disabled_selected_color: resolved_theme.palette.primary.multiply_alpha(0.42),
    control_size: 20.0,
  }
}

///|
pub fn ProgressStyle::default(theme? : @core.Theme) -> ProgressStyle {
  let resolved_theme = views_ambient_theme(theme)
  {
    foreground: resolved_theme.palette.primary,
    background: resolved_theme.palette.surface_variant,
    radius: resolved_theme.radius_scale.pill,
  }
}

///|
pub fn SliderStyle::default(theme? : @core.Theme) -> SliderStyle {
  let resolved_theme = views_ambient_theme(theme)
  {
    foreground: resolved_theme.palette.primary,
    background: resolved_theme.palette.surface_variant.multiply_alpha(0.7),
    thumb_color: resolved_theme.palette.primary,
    track_height: 4.0,
    thumb_size: 18.0,
    radius: resolved_theme.radius_scale.pill,
  }
}

///|
pub fn PickerStyle::default(theme? : @core.Theme) -> PickerStyle {
  let resolved_theme = views_ambient_theme(theme)
  {
    font: resolved_theme.typography.control,
    foreground: resolved_theme.palette.foreground,
    background: @core.Brush::solid(resolved_theme.palette.surface),
    radius: resolved_theme.radius_scale.md,
    popup_max_height: 200.0,
  }
}

///|
pub fn FeedbackStyle::default(theme? : @core.Theme) -> FeedbackStyle {
  let resolved_theme = views_ambient_theme(theme)
  let background_alpha = match resolved_theme.scheme {
    @core.ColorScheme::Light => 0.14
    @core.ColorScheme::Dark => 0.24
  }
  {
    neutral: tone_style(
      foreground=resolved_theme.palette.muted,
      background_alpha~,
      border_alpha=0.78,
    ),
    info: tone_style(
      foreground=resolved_theme.palette.info,
      background_alpha~,
      border_alpha=0.78,
    ),
    success: tone_style(
      foreground=resolved_theme.palette.success,
      background_alpha~,
      border_alpha=0.78,
    ),
    warning: tone_style(
      foreground=resolved_theme.palette.warning,
      background_alpha~,
      border_alpha=0.78,
    ),
    danger: tone_style(
      foreground=resolved_theme.palette.danger,
      background_alpha~,
      border_alpha=0.78,
    ),
    radius: resolved_theme.radius_scale.md,
    padding: resolved_theme.spacing_scale.sm,
  }
}

///|
pub fn BadgeStyle::default(theme? : @core.Theme) -> BadgeStyle {
  let resolved_theme = views_ambient_theme(theme)
  {
    neutral: {
      foreground: resolved_theme.palette.foreground,
      background: resolved_theme.palette.surface_variant,
      border: resolved_theme.palette.outline.multiply_alpha(0.42),
    },
    accent: badge_tone(resolved_theme.palette.info),
    success: badge_tone(resolved_theme.palette.success),
    warning: badge_tone(resolved_theme.palette.warning),
    danger: badge_tone(resolved_theme.palette.danger),
    radius: resolved_theme.radius_scale.pill,
    padding: 3.0,
  }
}

///|
pub fn FormValidationStyle::default(
  theme? : @core.Theme,
) -> FormValidationStyle {
  let resolved_theme = views_ambient_theme(theme)
  let color = resolved_theme.palette.danger
  {
    foreground: color,
    background: color.multiply_alpha(0.12),
    border: color.multiply_alpha(0.72),
    radius: resolved_theme.radius_scale.md,
    padding: resolved_theme.spacing_scale.md,
  }
}

///|
fn tone_style(
  foreground~ : @core.Color,
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
fn badge_tone(background : @core.Color) -> ToneStyle {
  { foreground: @core.Color::white(), background, border: background }
}

///|
pub struct PickerItem {
  id : String
  label : String
}

///|
pub fn PickerItem::new(id~ : String, label~ : String) -> PickerItem {
  { id, label }
}

///|
pub fn PickerItem::id(self : PickerItem) -> String {
  self.id
}

///|
pub fn PickerItem::label(self : PickerItem) -> String {
  self.label
}
