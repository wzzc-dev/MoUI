///|
pub struct TextStyle {
  font : @core.FontSpec
  color : @core.Color
} derive(Eq, Debug, ToJson)

///|
pub struct SurfaceStyle {
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
pub struct ButtonStyle {
  normal : ControlStateStyle
  hovered : ControlStateStyle
  pressed : ControlStateStyle
  disabled : ControlStateStyle
} derive(Eq, Debug, ToJson)

///|
pub struct TextFieldStyle {
  normal : ControlStateStyle
  focused : ControlStateStyle
  disabled : ControlStateStyle
  placeholder_color : @core.Color
  cursor_color : @core.Color
  font : @core.FontSpec
} derive(Eq, Debug, ToJson)

///|
pub struct ChoiceControlStyle {
  foreground : @core.Color
  selected_color : @core.Color
  disabled_foreground : @core.Color
  disabled_selected_color : @core.Color
  control_size : Double
} derive(Eq, Debug, ToJson)

///|
pub struct ProgressStyle {
  foreground : @core.Color
  background : @core.Color
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub struct SliderStyle {
  foreground : @core.Color
  background : @core.Color
  thumb_color : @core.Color
  track_height : Double
  thumb_size : Double
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub struct PickerStyle {
  font : @core.FontSpec
  foreground : @core.Color
  background : @core.Brush
  radius : Double
  popup_max_height : Double
} derive(Eq, Debug, ToJson)

///|
pub struct ToneStyle {
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
} derive(Eq, Debug, ToJson)

///|
pub struct FeedbackStyle {
  neutral : ToneStyle
  info : ToneStyle
  success : ToneStyle
  warning : ToneStyle
  danger : ToneStyle
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub struct BadgeStyle {
  neutral : ToneStyle
  accent : ToneStyle
  success : ToneStyle
  warning : ToneStyle
  danger : ToneStyle
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub struct FormValidationStyle {
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
/// Public constructor for `ControlStateStyle` so external packages can build
/// per-state control styles without importing `@core` directly.
pub fn new_control_state_style(
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

// === TextStyle constructors, getters, with_xxx ===

///|
pub fn TextStyle::new(
  font~ : @core.FontSpec,
  color~ : @core.Color,
) -> TextStyle {
  { font, color }
}

///|
pub fn TextStyle::font(self : TextStyle) -> @core.FontSpec {
  self.font
}

///|
pub fn TextStyle::color(self : TextStyle) -> @core.Color {
  self.color
}

///|
pub fn TextStyle::with_font(
  self : TextStyle,
  font~ : @core.FontSpec,
) -> TextStyle {
  { ..self, font, }
}

///|
pub fn TextStyle::with_color(
  self : TextStyle,
  color~ : @core.Color,
) -> TextStyle {
  { ..self, color, }
}

// === SurfaceStyle constructors, getters, with_xxx ===

///|
pub fn SurfaceStyle::new(
  brush~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  radius~ : Double,
  shadow? : @core.ShadowStyle? = None,
  padding~ : @core.Insets,
  level~ : @core.SurfaceLevel,
) -> SurfaceStyle {
  { brush, border, radius, shadow, padding, level }
}

///|
pub fn SurfaceStyle::brush(self : SurfaceStyle) -> @core.Brush {
  self.brush
}

///|
pub fn SurfaceStyle::border(self : SurfaceStyle) -> @core.BorderStyle? {
  self.border
}

///|
pub fn SurfaceStyle::radius(self : SurfaceStyle) -> Double {
  self.radius
}

///|
pub fn SurfaceStyle::shadow(self : SurfaceStyle) -> @core.ShadowStyle? {
  self.shadow
}

///|
pub fn SurfaceStyle::padding(self : SurfaceStyle) -> @core.Insets {
  self.padding
}

///|
pub fn SurfaceStyle::level(self : SurfaceStyle) -> @core.SurfaceLevel {
  self.level
}

///|
pub fn SurfaceStyle::with_brush(
  self : SurfaceStyle,
  brush~ : @core.Brush,
) -> SurfaceStyle {
  { ..self, brush, }
}

///|
pub fn SurfaceStyle::with_border(
  self : SurfaceStyle,
  border~ : @core.BorderStyle?,
) -> SurfaceStyle {
  { ..self, border, }
}

///|
pub fn SurfaceStyle::with_radius(
  self : SurfaceStyle,
  radius~ : Double,
) -> SurfaceStyle {
  { ..self, radius, }
}

///|
pub fn SurfaceStyle::with_shadow(
  self : SurfaceStyle,
  shadow~ : @core.ShadowStyle?,
) -> SurfaceStyle {
  { ..self, shadow, }
}

///|
pub fn SurfaceStyle::with_padding(
  self : SurfaceStyle,
  padding~ : @core.Insets,
) -> SurfaceStyle {
  { ..self, padding, }
}

///|
pub fn SurfaceStyle::with_level(
  self : SurfaceStyle,
  level~ : @core.SurfaceLevel,
) -> SurfaceStyle {
  { ..self, level, }
}

// === ButtonStyle constructors, getters, with_xxx ===

///|
pub fn ButtonStyle::new(
  normal~ : ControlStateStyle,
  hovered~ : ControlStateStyle,
  pressed~ : ControlStateStyle,
  disabled~ : ControlStateStyle,
) -> ButtonStyle {
  { normal, hovered, pressed, disabled }
}

///|
pub fn ButtonStyle::normal(self : ButtonStyle) -> ControlStateStyle {
  self.normal
}

///|
pub fn ButtonStyle::hovered(self : ButtonStyle) -> ControlStateStyle {
  self.hovered
}

///|
pub fn ButtonStyle::pressed(self : ButtonStyle) -> ControlStateStyle {
  self.pressed
}

///|
pub fn ButtonStyle::disabled(self : ButtonStyle) -> ControlStateStyle {
  self.disabled
}

///|
pub fn ButtonStyle::with_normal(
  self : ButtonStyle,
  normal~ : ControlStateStyle,
) -> ButtonStyle {
  { ..self, normal, }
}

///|
pub fn ButtonStyle::with_hovered(
  self : ButtonStyle,
  hovered~ : ControlStateStyle,
) -> ButtonStyle {
  { ..self, hovered, }
}

///|
pub fn ButtonStyle::with_pressed(
  self : ButtonStyle,
  pressed~ : ControlStateStyle,
) -> ButtonStyle {
  { ..self, pressed, }
}

///|
pub fn ButtonStyle::with_disabled(
  self : ButtonStyle,
  disabled~ : ControlStateStyle,
) -> ButtonStyle {
  { ..self, disabled, }
}

// === TextFieldStyle constructors, getters, with_xxx ===

///|
pub fn TextFieldStyle::new(
  normal~ : ControlStateStyle,
  focused~ : ControlStateStyle,
  disabled~ : ControlStateStyle,
  placeholder_color~ : @core.Color,
  cursor_color~ : @core.Color,
  font~ : @core.FontSpec,
) -> TextFieldStyle {
  { normal, focused, disabled, placeholder_color, cursor_color, font }
}

///|
pub fn TextFieldStyle::normal(self : TextFieldStyle) -> ControlStateStyle {
  self.normal
}

///|
pub fn TextFieldStyle::focused(self : TextFieldStyle) -> ControlStateStyle {
  self.focused
}

///|
pub fn TextFieldStyle::disabled(self : TextFieldStyle) -> ControlStateStyle {
  self.disabled
}

///|
pub fn TextFieldStyle::placeholder_color(self : TextFieldStyle) -> @core.Color {
  self.placeholder_color
}

///|
pub fn TextFieldStyle::cursor_color(self : TextFieldStyle) -> @core.Color {
  self.cursor_color
}

///|
pub fn TextFieldStyle::font(self : TextFieldStyle) -> @core.FontSpec {
  self.font
}

///|
pub fn TextFieldStyle::with_normal(
  self : TextFieldStyle,
  normal~ : ControlStateStyle,
) -> TextFieldStyle {
  { ..self, normal, }
}

///|
pub fn TextFieldStyle::with_focused(
  self : TextFieldStyle,
  focused~ : ControlStateStyle,
) -> TextFieldStyle {
  { ..self, focused, }
}

///|
pub fn TextFieldStyle::with_disabled(
  self : TextFieldStyle,
  disabled~ : ControlStateStyle,
) -> TextFieldStyle {
  { ..self, disabled, }
}

///|
pub fn TextFieldStyle::with_placeholder_color(
  self : TextFieldStyle,
  placeholder_color~ : @core.Color,
) -> TextFieldStyle {
  { ..self, placeholder_color, }
}

///|
pub fn TextFieldStyle::with_cursor_color(
  self : TextFieldStyle,
  cursor_color~ : @core.Color,
) -> TextFieldStyle {
  { ..self, cursor_color, }
}

///|
pub fn TextFieldStyle::with_font(
  self : TextFieldStyle,
  font~ : @core.FontSpec,
) -> TextFieldStyle {
  { ..self, font, }
}

// === ChoiceControlStyle constructors, getters, with_xxx ===

///|
pub fn ChoiceControlStyle::new(
  foreground~ : @core.Color,
  selected_color~ : @core.Color,
  disabled_foreground~ : @core.Color,
  disabled_selected_color~ : @core.Color,
  control_size~ : Double,
) -> ChoiceControlStyle {
  {
    foreground,
    selected_color,
    disabled_foreground,
    disabled_selected_color,
    control_size,
  }
}

///|
pub fn ChoiceControlStyle::foreground(self : ChoiceControlStyle) -> @core.Color {
  self.foreground
}

///|
pub fn ChoiceControlStyle::selected_color(
  self : ChoiceControlStyle,
) -> @core.Color {
  self.selected_color
}

///|
pub fn ChoiceControlStyle::disabled_foreground(
  self : ChoiceControlStyle,
) -> @core.Color {
  self.disabled_foreground
}

///|
pub fn ChoiceControlStyle::disabled_selected_color(
  self : ChoiceControlStyle,
) -> @core.Color {
  self.disabled_selected_color
}

///|
pub fn ChoiceControlStyle::control_size(self : ChoiceControlStyle) -> Double {
  self.control_size
}

///|
pub fn ChoiceControlStyle::with_foreground(
  self : ChoiceControlStyle,
  foreground~ : @core.Color,
) -> ChoiceControlStyle {
  { ..self, foreground, }
}

///|
pub fn ChoiceControlStyle::with_selected_color(
  self : ChoiceControlStyle,
  selected_color~ : @core.Color,
) -> ChoiceControlStyle {
  { ..self, selected_color, }
}

///|
pub fn ChoiceControlStyle::with_disabled_foreground(
  self : ChoiceControlStyle,
  disabled_foreground~ : @core.Color,
) -> ChoiceControlStyle {
  { ..self, disabled_foreground, }
}

///|
pub fn ChoiceControlStyle::with_disabled_selected_color(
  self : ChoiceControlStyle,
  disabled_selected_color~ : @core.Color,
) -> ChoiceControlStyle {
  { ..self, disabled_selected_color, }
}

///|
pub fn ChoiceControlStyle::with_control_size(
  self : ChoiceControlStyle,
  control_size~ : Double,
) -> ChoiceControlStyle {
  { ..self, control_size, }
}

// === ProgressStyle constructors, getters, with_xxx ===

///|
pub fn ProgressStyle::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  radius~ : Double,
) -> ProgressStyle {
  { foreground, background, radius }
}

///|
pub fn ProgressStyle::foreground(self : ProgressStyle) -> @core.Color {
  self.foreground
}

///|
pub fn ProgressStyle::background(self : ProgressStyle) -> @core.Color {
  self.background
}

///|
pub fn ProgressStyle::radius(self : ProgressStyle) -> Double {
  self.radius
}

///|
pub fn ProgressStyle::with_foreground(
  self : ProgressStyle,
  foreground~ : @core.Color,
) -> ProgressStyle {
  { ..self, foreground, }
}

///|
pub fn ProgressStyle::with_background(
  self : ProgressStyle,
  background~ : @core.Color,
) -> ProgressStyle {
  { ..self, background, }
}

///|
pub fn ProgressStyle::with_radius(
  self : ProgressStyle,
  radius~ : Double,
) -> ProgressStyle {
  { ..self, radius, }
}

// === SliderStyle constructors, getters, with_xxx ===

///|
pub fn SliderStyle::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  thumb_color~ : @core.Color,
  track_height~ : Double,
  thumb_size~ : Double,
  radius~ : Double,
) -> SliderStyle {
  { foreground, background, thumb_color, track_height, thumb_size, radius }
}

///|
pub fn SliderStyle::foreground(self : SliderStyle) -> @core.Color {
  self.foreground
}

///|
pub fn SliderStyle::background(self : SliderStyle) -> @core.Color {
  self.background
}

///|
pub fn SliderStyle::thumb_color(self : SliderStyle) -> @core.Color {
  self.thumb_color
}

///|
pub fn SliderStyle::track_height(self : SliderStyle) -> Double {
  self.track_height
}

///|
pub fn SliderStyle::thumb_size(self : SliderStyle) -> Double {
  self.thumb_size
}

///|
pub fn SliderStyle::radius(self : SliderStyle) -> Double {
  self.radius
}

///|
pub fn SliderStyle::with_foreground(
  self : SliderStyle,
  foreground~ : @core.Color,
) -> SliderStyle {
  { ..self, foreground, }
}

///|
pub fn SliderStyle::with_background(
  self : SliderStyle,
  background~ : @core.Color,
) -> SliderStyle {
  { ..self, background, }
}

///|
pub fn SliderStyle::with_thumb_color(
  self : SliderStyle,
  thumb_color~ : @core.Color,
) -> SliderStyle {
  { ..self, thumb_color, }
}

///|
pub fn SliderStyle::with_track_height(
  self : SliderStyle,
  track_height~ : Double,
) -> SliderStyle {
  { ..self, track_height, }
}

///|
pub fn SliderStyle::with_thumb_size(
  self : SliderStyle,
  thumb_size~ : Double,
) -> SliderStyle {
  { ..self, thumb_size, }
}

///|
pub fn SliderStyle::with_radius(
  self : SliderStyle,
  radius~ : Double,
) -> SliderStyle {
  { ..self, radius, }
}

// === PickerStyle constructors, getters, with_xxx ===

///|
pub fn PickerStyle::new(
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  radius~ : Double,
  popup_max_height~ : Double,
) -> PickerStyle {
  { font, foreground, background, radius, popup_max_height }
}

///|
pub fn PickerStyle::font(self : PickerStyle) -> @core.FontSpec {
  self.font
}

///|
pub fn PickerStyle::foreground(self : PickerStyle) -> @core.Color {
  self.foreground
}

///|
pub fn PickerStyle::background(self : PickerStyle) -> @core.Brush {
  self.background
}

///|
pub fn PickerStyle::radius(self : PickerStyle) -> Double {
  self.radius
}

///|
pub fn PickerStyle::popup_max_height(self : PickerStyle) -> Double {
  self.popup_max_height
}

///|
pub fn PickerStyle::with_font(
  self : PickerStyle,
  font~ : @core.FontSpec,
) -> PickerStyle {
  { ..self, font, }
}

///|
pub fn PickerStyle::with_foreground(
  self : PickerStyle,
  foreground~ : @core.Color,
) -> PickerStyle {
  { ..self, foreground, }
}

///|
pub fn PickerStyle::with_background(
  self : PickerStyle,
  background~ : @core.Brush,
) -> PickerStyle {
  { ..self, background, }
}

///|
pub fn PickerStyle::with_radius(
  self : PickerStyle,
  radius~ : Double,
) -> PickerStyle {
  { ..self, radius, }
}

///|
pub fn PickerStyle::with_popup_max_height(
  self : PickerStyle,
  popup_max_height~ : Double,
) -> PickerStyle {
  { ..self, popup_max_height, }
}

// === ToneStyle constructors, getters, with_xxx ===

///|
pub fn ToneStyle::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  border~ : @core.Color,
) -> ToneStyle {
  { foreground, background, border }
}

///|
pub fn ToneStyle::foreground(self : ToneStyle) -> @core.Color {
  self.foreground
}

///|
pub fn ToneStyle::background(self : ToneStyle) -> @core.Color {
  self.background
}

///|
pub fn ToneStyle::border(self : ToneStyle) -> @core.Color {
  self.border
}

///|
pub fn ToneStyle::with_foreground(
  self : ToneStyle,
  foreground~ : @core.Color,
) -> ToneStyle {
  { ..self, foreground, }
}

///|
pub fn ToneStyle::with_background(
  self : ToneStyle,
  background~ : @core.Color,
) -> ToneStyle {
  { ..self, background, }
}

///|
pub fn ToneStyle::with_border(
  self : ToneStyle,
  border~ : @core.Color,
) -> ToneStyle {
  { ..self, border, }
}

// === FeedbackStyle constructors, getters, with_xxx ===

///|
pub fn FeedbackStyle::new(
  neutral~ : ToneStyle,
  info~ : ToneStyle,
  success~ : ToneStyle,
  warning~ : ToneStyle,
  danger~ : ToneStyle,
  radius~ : Double,
  padding~ : Double,
) -> FeedbackStyle {
  { neutral, info, success, warning, danger, radius, padding }
}

///|
pub fn FeedbackStyle::neutral(self : FeedbackStyle) -> ToneStyle {
  self.neutral
}

///|
pub fn FeedbackStyle::info(self : FeedbackStyle) -> ToneStyle {
  self.info
}

///|
pub fn FeedbackStyle::success(self : FeedbackStyle) -> ToneStyle {
  self.success
}

///|
pub fn FeedbackStyle::warning(self : FeedbackStyle) -> ToneStyle {
  self.warning
}

///|
pub fn FeedbackStyle::danger(self : FeedbackStyle) -> ToneStyle {
  self.danger
}

///|
pub fn FeedbackStyle::radius(self : FeedbackStyle) -> Double {
  self.radius
}

///|
pub fn FeedbackStyle::padding(self : FeedbackStyle) -> Double {
  self.padding
}

///|
pub fn FeedbackStyle::with_neutral(
  self : FeedbackStyle,
  neutral~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, neutral, }
}

///|
pub fn FeedbackStyle::with_info(
  self : FeedbackStyle,
  info~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, info, }
}

///|
pub fn FeedbackStyle::with_success(
  self : FeedbackStyle,
  success~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, success, }
}

///|
pub fn FeedbackStyle::with_warning(
  self : FeedbackStyle,
  warning~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, warning, }
}

///|
pub fn FeedbackStyle::with_danger(
  self : FeedbackStyle,
  danger~ : ToneStyle,
) -> FeedbackStyle {
  { ..self, danger, }
}

///|
pub fn FeedbackStyle::with_radius(
  self : FeedbackStyle,
  radius~ : Double,
) -> FeedbackStyle {
  { ..self, radius, }
}

///|
pub fn FeedbackStyle::with_padding(
  self : FeedbackStyle,
  padding~ : Double,
) -> FeedbackStyle {
  { ..self, padding, }
}

// === BadgeStyle constructors, getters, with_xxx ===

///|
pub fn BadgeStyle::new(
  neutral~ : ToneStyle,
  accent~ : ToneStyle,
  success~ : ToneStyle,
  warning~ : ToneStyle,
  danger~ : ToneStyle,
  radius~ : Double,
  padding~ : Double,
) -> BadgeStyle {
  { neutral, accent, success, warning, danger, radius, padding }
}

///|
pub fn BadgeStyle::neutral(self : BadgeStyle) -> ToneStyle {
  self.neutral
}

///|
pub fn BadgeStyle::accent(self : BadgeStyle) -> ToneStyle {
  self.accent
}

///|
pub fn BadgeStyle::success(self : BadgeStyle) -> ToneStyle {
  self.success
}

///|
pub fn BadgeStyle::warning(self : BadgeStyle) -> ToneStyle {
  self.warning
}

///|
pub fn BadgeStyle::danger(self : BadgeStyle) -> ToneStyle {
  self.danger
}

///|
pub fn BadgeStyle::radius(self : BadgeStyle) -> Double {
  self.radius
}

///|
pub fn BadgeStyle::padding(self : BadgeStyle) -> Double {
  self.padding
}

///|
pub fn BadgeStyle::with_neutral(
  self : BadgeStyle,
  neutral~ : ToneStyle,
) -> BadgeStyle {
  { ..self, neutral, }
}

///|
pub fn BadgeStyle::with_accent(
  self : BadgeStyle,
  accent~ : ToneStyle,
) -> BadgeStyle {
  { ..self, accent, }
}

///|
pub fn BadgeStyle::with_success(
  self : BadgeStyle,
  success~ : ToneStyle,
) -> BadgeStyle {
  { ..self, success, }
}

///|
pub fn BadgeStyle::with_warning(
  self : BadgeStyle,
  warning~ : ToneStyle,
) -> BadgeStyle {
  { ..self, warning, }
}

///|
pub fn BadgeStyle::with_danger(
  self : BadgeStyle,
  danger~ : ToneStyle,
) -> BadgeStyle {
  { ..self, danger, }
}

///|
pub fn BadgeStyle::with_radius(
  self : BadgeStyle,
  radius~ : Double,
) -> BadgeStyle {
  { ..self, radius, }
}

///|
pub fn BadgeStyle::with_padding(
  self : BadgeStyle,
  padding~ : Double,
) -> BadgeStyle {
  { ..self, padding, }
}

// === FormValidationStyle constructors, getters, with_xxx ===

///|
pub fn FormValidationStyle::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  border~ : @core.Color,
  radius~ : Double,
  padding~ : Double,
) -> FormValidationStyle {
  { foreground, background, border, radius, padding }
}

///|
pub fn FormValidationStyle::foreground(
  self : FormValidationStyle,
) -> @core.Color {
  self.foreground
}

///|
pub fn FormValidationStyle::background(
  self : FormValidationStyle,
) -> @core.Color {
  self.background
}

///|
pub fn FormValidationStyle::border(self : FormValidationStyle) -> @core.Color {
  self.border
}

///|
pub fn FormValidationStyle::radius(self : FormValidationStyle) -> Double {
  self.radius
}

///|
pub fn FormValidationStyle::padding(self : FormValidationStyle) -> Double {
  self.padding
}

///|
pub fn FormValidationStyle::with_foreground(
  self : FormValidationStyle,
  foreground~ : @core.Color,
) -> FormValidationStyle {
  { ..self, foreground, }
}

///|
pub fn FormValidationStyle::with_background(
  self : FormValidationStyle,
  background~ : @core.Color,
) -> FormValidationStyle {
  { ..self, background, }
}

///|
pub fn FormValidationStyle::with_border(
  self : FormValidationStyle,
  border~ : @core.Color,
) -> FormValidationStyle {
  { ..self, border, }
}

///|
pub fn FormValidationStyle::with_radius(
  self : FormValidationStyle,
  radius~ : Double,
) -> FormValidationStyle {
  { ..self, radius, }
}

///|
pub fn FormValidationStyle::with_padding(
  self : FormValidationStyle,
  padding~ : Double,
) -> FormValidationStyle {
  { ..self, padding, }
}
