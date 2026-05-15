///|
pub(all) struct TextStyle {
  font : FontSpec
  color : Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SurfaceStyle {
  brush : Brush
  border : Brush?
  border_width : Double
  radius : Double
  shadow : ShadowSpec?
  padding : Insets
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ControlStateStyle {
  foreground : Color
  background : Brush
  border : Brush?
  border_width : Double
  radius : Double
  shadow : ShadowSpec?
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
    brush: Brush::solid(theme.palette.surface),
    border: None,
    border_width: 0.0,
    radius: theme.radius_scale.md,
    shadow: None,
    padding: Insets::all(theme.spacing_scale.md),
  }
}

///|
fn control_state(
  foreground~ : Color,
  background~ : Brush,
  border? : Brush,
  border_width? : Double = 0.0,
  radius? : Double = 0.0,
  shadow? : ShadowSpec,
) -> ControlStateStyle {
  { foreground, background, border, border_width, radius, shadow }
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
    border=Brush::solid(theme.palette.outline),
    border_width=1.0,
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
pub fn TextFieldStyle::filled(theme? : Theme = Theme::default()) -> TextFieldStyle {
  let normal = control_state(
    foreground=theme.foreground,
    background=Brush::solid(theme.palette.surface),
    border=Brush::solid(theme.palette.outline),
    border_width=1.0,
    radius=theme.radius_scale.md,
  )
  let focused = control_state(
    foreground=theme.foreground,
    background=Brush::solid(theme.palette.surface),
    border=Brush::solid(theme.palette.primary),
    border_width=2.0,
    radius=theme.radius_scale.md,
  )
  { normal, focused, disabled: normal, placeholder_color: theme.palette.muted, cursor_color: theme.palette.primary, font: theme.typography.body }
}

///|
pub fn TextFieldStyle::outline(theme? : Theme = Theme::default()) -> TextFieldStyle {
  TextFieldStyle::filled(theme~)
}
