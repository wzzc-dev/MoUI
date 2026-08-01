///|
/// Legacy control style structs and their `::default(theme=)` constructors.
/// These `::default` constructors are now thin projections over
/// `ControlThemeSet` (built by `minimal_control_theme_set`) — the single source
/// of truth for control theming. Prefer reading tokens from `ControlThemeSet`
/// directly via `@style.views_ambient_control_theme(theme)` for new code; the
/// `::default` helpers remain only for backward compatibility.
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
/// Resolved per-state control style. Lives in `moui/views`
/// (`control_theme_tokens.mbt`, ADR 0017) alongside the token resolver and
/// the view-layer style structs; `core` no longer carries control types.
/// Same package, so no `using` alias is needed.

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
  let resolved_theme = @common.views_ambient_theme(theme)
  {
    font: resolved_theme.typography.body,
    color: resolved_theme.palette.foreground,
  }
}

///|
pub fn TextStyle::title(theme? : @core.Theme) -> TextStyle {
  let resolved_theme = @common.views_ambient_theme(theme)
  {
    font: resolved_theme.typography.title,
    color: resolved_theme.palette.foreground,
  }
}

///|
pub fn SurfaceStyle::default(theme? : @core.Theme) -> SurfaceStyle {
  let resolved_theme = @common.views_ambient_theme(theme)
  let set = views_ambient_control_theme(resolved_theme)
  {
    brush: resolved_theme.surface_brush(@core.SurfaceLevel::Base),
    border: None,
    radius: set.surface.base_radius,
    shadow: set.surface.base_shadow,
    padding: @core.Insets::all(set.surface.base_padding),
    level: @core.SurfaceLevel::Base,
  }
}

///|
pub fn SurfaceStyle::raised(theme? : @core.Theme) -> SurfaceStyle {
  let resolved_theme = @common.views_ambient_theme(theme)
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
  let resolved_theme = @common.views_ambient_theme(theme)
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
  let resolved_theme = @common.views_ambient_theme(theme)
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
  let resolved_theme = @common.views_ambient_theme(theme)
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
  let resolved_theme = @common.views_ambient_theme(theme)
  let transparent = @core.Brush::solid(
    @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
  )
  let normal = control_state(
    foreground=resolved_theme.palette.foreground,
    background=transparent,
    radius=resolved_theme.radius_scale.md,
  )
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
  let resolved_theme = @common.views_ambient_theme(theme)
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
  let resolved_theme = @common.views_ambient_theme(theme)
  TextFieldStyle::filled(theme=resolved_theme)
}

///|
pub fn ChoiceControlStyle::default(theme? : @core.Theme) -> ChoiceControlStyle {
  let cc = views_ambient_control_theme(@common.views_ambient_theme(theme)).choice_control
  {
    foreground: cc.foreground,
    selected_color: cc.selected_color,
    disabled_foreground: cc.disabled_foreground,
    disabled_selected_color: cc.disabled_selected_color,
    control_size: cc.control_size,
  }
}

///|
pub fn ProgressStyle::default(theme? : @core.Theme) -> ProgressStyle {
  let set = views_ambient_control_theme(@common.views_ambient_theme(theme))
  {
    foreground: set.progress.foreground,
    background: set.progress.background,
    radius: set.progress.radius,
  }
}

///|
pub fn SliderStyle::default(theme? : @core.Theme) -> SliderStyle {
  let s = views_ambient_control_theme(@common.views_ambient_theme(theme)).slider
  {
    foreground: s.foreground,
    background: s.background,
    thumb_color: s.thumb_color,
    track_height: s.track_height,
    thumb_size: s.thumb_size,
    radius: s.radius,
  }
}

///|
pub fn PickerStyle::default(theme? : @core.Theme) -> PickerStyle {
  let set = views_ambient_control_theme(@common.views_ambient_theme(theme))
  {
    font: set.picker.font,
    foreground: set.picker.foreground,
    background: set.picker.background,
    radius: set.picker.radius,
    popup_max_height: set.picker.popup_max_height,
  }
}

///|
pub fn FeedbackStyle::default(theme? : @core.Theme) -> FeedbackStyle {
  let set = views_ambient_control_theme(@common.views_ambient_theme(theme))
  {
    neutral: tone_style_from_tokens(set.feedback.neutral),
    info: tone_style_from_tokens(set.feedback.info),
    success: tone_style_from_tokens(set.feedback.success),
    warning: tone_style_from_tokens(set.feedback.warning),
    danger: tone_style_from_tokens(set.feedback.danger),
    radius: set.feedback.radius,
    padding: set.feedback.padding,
  }
}

///|
pub fn BadgeStyle::default(theme? : @core.Theme) -> BadgeStyle {
  let set = views_ambient_control_theme(@common.views_ambient_theme(theme))
  {
    neutral: tone_style_from_tokens(set.badge.neutral),
    accent: tone_style_from_tokens(set.badge.accent),
    success: tone_style_from_tokens(set.badge.success),
    warning: tone_style_from_tokens(set.badge.warning),
    danger: tone_style_from_tokens(set.badge.danger),
    radius: set.badge.radius,
    padding: set.badge.padding,
  }
}

///|
pub fn FormValidationStyle::default(
  theme? : @core.Theme,
) -> FormValidationStyle {
  let set = views_ambient_control_theme(@common.views_ambient_theme(theme))
  {
    foreground: set.form_validation.foreground,
    background: set.form_validation.background,
    border: set.form_validation.border,
    radius: set.form_validation.radius,
    padding: set.form_validation.padding,
  }
}

///|
/// Project a resolved `ToneTokens` (from `ControlThemeSet`) into the legacy
/// `ToneStyle` shape. After the style unification, `XStyle::default` helpers
/// project from `ControlThemeSet`; this bridges the two parallel token types.
fn tone_style_from_tokens(t : ToneTokens) -> ToneStyle {
  { foreground: t.foreground, background: t.background, border: t.border }
}

///|
pub(all) struct PickerItem {
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
