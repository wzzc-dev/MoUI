///|
/// View-owned control theme tokens. This file migrates per-control design
/// tokens out of `moui/core` so `core.Theme` stays neutral (ADR 0017).
/// Token structs hold raw `Color`/`Double` values; `ControlStateStyle`
/// holds the resolved `Brush`/`BorderStyle` values that paint consumes.
/// Both layers live in `moui/views` because they are control vocabulary:
/// adding a control adds tokens here, not in `core`.
///
/// Resolution flow:
///   `ControlStateTokens` --resolve()--> `ControlStateStyle`
///   `ButtonTheme`        --resolve(variant, state)--> `ControlStateStyle`
///
/// Controls read their `ControlThemeSet` (see `control_theme_set.mbt`)
/// at paint time and resolve variant/state; `style?` on each control
/// constructor is a one-shot override that bypasses this resolution.
///
/// The neutral `InteractionState` enum + the gesture-driven `PressableState`
/// enum + `PressableState::to_interaction` stay in `core` (ADR 0017): they are
/// the neutral gesture/interaction state machine consumed by core's own
/// view-tree and gesture layers (gesture.mbt, view_tree.mbt), not control
/// vocabulary. View-side token resolution reads `@core.InteractionState`
/// directly via the `control_interaction_state` adapter in
/// `control_theme_set.mbt`.

///|
/// Raw per-state token. Token layer: colors are plain `Color`, background is a
/// `Color` (paint resolves it to `Brush::solid`). `border_width == 0.0` means
/// "no border". `bottom_border_only` paints only the bottom edge (Fluent 2
/// underline inputs). `inner_focus_border` paints an inner stroke inside the
/// control frame on focus (Fluent 2 focus reveal).
pub(all) struct ControlStateTokens {
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
  border_width : Double
  radius : Double
  bottom_border_only : Bool
  inner_focus_border : @core.Color?
} derive(Eq, Debug, ToJson)

///|
/// Resolved per-state style. Paint layer: `background` is a `Brush`, `border`
/// is `None` when `border_width == 0.0`. This is the type controls actually
/// consume when emitting `DrawCommand`s.
pub(all) struct ControlStateStyle {
  foreground : @core.Color
  background : @core.Brush
  border : @core.BorderStyle?
  radius : Double
  shadow : @core.ShadowStyle?
  bottom_border_only : Bool
  inner_focus_border : @core.Color?
} derive(Eq, Debug, ToJson)

///|
/// Convenience constructor for `ControlStateTokens`.
pub fn ControlStateTokens::new(
  foreground~ : @core.Color,
  background~ : @core.Color,
  border~ : @core.Color,
  border_width~ : Double,
  radius~ : Double,
  bottom_border_only? : Bool = false,
  inner_focus_border? : @core.Color? = None,
) -> ControlStateTokens {
  {
    foreground,
    background,
    border,
    border_width,
    radius,
    bottom_border_only,
    inner_focus_border,
  }
}

///|
/// Resolve a token set into a paint-ready `ControlStateStyle`. The border is
/// dropped when `border_width <= 0.0`. `shadow` is always `None` here; layered
/// shadows are attached by the component theme that owns the token (e.g.
/// `SurfaceTheme`), not by individual control states.
pub fn ControlStateTokens::resolve(
  self : ControlStateTokens,
) -> ControlStateStyle {
  {
    foreground: self.foreground,
    background: @core.Brush::Solid(self.background),
    border: control_state_border(self),
    radius: self.radius,
    shadow: None,
    bottom_border_only: self.bottom_border_only,
    inner_focus_border: self.inner_focus_border,
  }
}

///|
fn control_state_border(state : ControlStateTokens) -> @core.BorderStyle? {
  if state.border_width > 0.0 {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::Solid(state.border),
        width=state.border_width,
      ),
    )
  } else {
    None
  }
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------

///|
/// Button variant tokens. Each variant carries its own `ControlStateTokens`
/// for the normal state; hover/press/disabled are derived from the state-layer
/// model (see `ButtonTheme::resolve`). Fluent 2 fills `subtle`/`subtle_brand`
/// distinctly; neutral presets alias them to `ghost`/`tonal`.
pub(all) struct ButtonTheme {
  primary : ControlStateTokens
  tonal : ControlStateTokens
  outline : ControlStateTokens
  ghost : ControlStateTokens
  subtle : ControlStateTokens
  subtle_brand : ControlStateTokens
  // State-layer alphas used to derive hovered/pressed/disabled backgrounds.
  state_layer : StateLayerTokens
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ButtonVariantToken {
  Primary
  Tonal
  Outline
  Ghost
  Subtle
  SubtleBrand
} derive(Eq, Debug, ToJson)

///|
/// State-layer tokens. Shared by all controls that use the state-layer model
/// (buttons, list rows, menu items): a translucent overlay of `color` is
/// blended onto the base background at `hover_alpha`/`focus_alpha`/... to
/// produce interaction feedback without per-variant color shifts.
pub(all) struct StateLayerTokens {
  color : @core.Color
  hover_alpha : Double
  focus_alpha : Double
  pressed_alpha : Double
  dragged_alpha : Double
  selected_alpha : Double
  disabled_alpha : Double
} derive(Eq, Debug, ToJson)

///|
/// Resolve a button variant + interaction state into a paint-ready
/// `ControlStateStyle`. Hover/press/disabled are derived from the variant's
/// normal tokens via the state-layer model so every variant shares a uniform
/// interaction grammar.
pub fn ButtonTheme::resolve(
  self : ButtonTheme,
  variant : ButtonVariantToken,
  state : @core.InteractionState,
) -> ControlStateStyle {
  let base = self.variant_tokens(variant)
  let normal = base.resolve()
  match state {
    Normal => normal
    Hovered =>
      {
        ..normal,
        background: @core.Brush::Solid(
          state_layer_background(
            base.background,
            self.state_layer.color,
            self.state_layer.hover_alpha,
          ),
        ),
      }
    Pressed =>
      {
        ..normal,
        background: @core.Brush::Solid(
          state_layer_background(
            base.background,
            self.state_layer.color,
            self.state_layer.pressed_alpha,
          ),
        ),
      }
    Focused =>
      {
        ..normal,
        background: @core.Brush::Solid(
          state_layer_background(
            base.background,
            self.state_layer.color,
            self.state_layer.focus_alpha,
          ),
        ),
      }
    Disabled =>
      {
        ..normal,
        foreground: normal.foreground.multiply_alpha(
          self.state_layer.disabled_alpha,
        ),
        background: normal.background.multiply_alpha(
          self.state_layer.disabled_alpha,
        ),
        border: control_state_disabled_border(normal.border, self.state_layer),
        shadow: None,
      }
    Selected | Invalid => normal
  }
}

///|
fn ButtonTheme::variant_tokens(
  self : ButtonTheme,
  variant : ButtonVariantToken,
) -> ControlStateTokens {
  match variant {
    Primary => self.primary
    Tonal => self.tonal
    Outline => self.outline
    Ghost => self.ghost
    Subtle => self.subtle
    SubtleBrand => self.subtle_brand
  }
}

///|
fn control_state_disabled_border(
  border : @core.BorderStyle?,
  state_layer : StateLayerTokens,
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
/// Blend a translucent state-layer color onto a base background. When the base
/// is fully transparent, the layer is emitted at the requested alpha; otherwise
/// the layer is composited over the base keeping the base alpha.
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

// ---------------------------------------------------------------------------
// TextField
// ---------------------------------------------------------------------------

///|
/// Text-field appearance tier. Fluent 2 ships an underline variant; the neutral
/// default is `Outline` (full border).
pub(all) enum TextFieldAppearance {
  Filled
  Outline
  Underline
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextFieldTheme {
  normal : ControlStateTokens
  focused : ControlStateTokens
  disabled : ControlStateTokens
  placeholder : @core.Color
  cursor : @core.Color
  font : @core.FontSpec
  appearance : TextFieldAppearance
} derive(Eq, Debug, ToJson)

///|
pub fn TextFieldTheme::resolve(
  self : TextFieldTheme,
  state : @core.InteractionState,
) -> ControlStateStyle {
  match state {
    Focused => self.focused.resolve()
    Disabled => self.disabled.resolve()
    _ => self.normal.resolve()
  }
}

// ---------------------------------------------------------------------------
// Surface
// ---------------------------------------------------------------------------

///|
/// Per-tier surface component tokens. Fluent 2 cards carry distinct shadows
/// per layer (shadow2/4/28); neutral presets leave them `None` and rely on the
/// flat surface idiom.
pub(all) struct SurfaceTheme {
  base_padding : Double
  raised_padding : Double
  overlay_padding : Double
  base_radius : Double
  raised_radius : Double
  overlay_radius : Double
  base_shadow : @core.ShadowStyle?
  raised_shadow : @core.ShadowStyle?
  overlay_shadow : @core.ShadowStyle?
} derive(Eq, Debug, ToJson)

// ---------------------------------------------------------------------------
// Choice / progress / slider / picker / feedback / badge / form validation
// ---------------------------------------------------------------------------

///|
/// Shape of a choice-control box (checkbox/radio). `Square` draws a rounded
/// rectangle; `Circle` draws a full circle. Fluent 2 radios use `Circle`,
/// checkboxes use `Square`.
pub(all) enum ChoiceControlShape {
  Square
  Circle
} derive(Eq, Debug, ToJson)

///|
/// Short label for revision/identity strings.
pub fn ChoiceControlShape::label(self : ChoiceControlShape) -> String {
  match self {
    Square => "square"
    Circle => "circle"
  }
}

///|
/// How a selected choice control marks itself. `Checkmark` draws a "✓" glyph
/// on the filled box; `Dot` draws a small filled inner circle (radio style).
pub(all) enum CheckMarkStyle {
  Checkmark
  Dot
} derive(Eq, Debug, ToJson)

///|
pub fn CheckMarkStyle::label(self : CheckMarkStyle) -> String {
  match self {
    Checkmark => "checkmark"
    Dot => "dot"
  }
}

///|
/// Shape of a slider thumb. `Rounded` uses the theme radius; `Circle` forces a
/// full circle (thumb radius = thumb_size / 2). Fluent 2 sliders use `Circle`.
pub(all) enum ThumbShape {
  Rounded
  Circle
} derive(Eq, Debug, ToJson)

///|
pub fn ThumbShape::label(self : ThumbShape) -> String {
  match self {
    Rounded => "rounded"
    Circle => "circle"
  }
}

///|
pub(all) struct ChoiceControlTheme {
  foreground : @core.Color
  selected_color : @core.Color
  disabled_foreground : @core.Color
  disabled_selected_color : @core.Color
  control_size : Double
  // Shape of the indicator box. Square for checkboxes, Circle for radios.
  box_shape : ChoiceControlShape
  // How a selected indicator renders its mark. Checkmark for checkboxes, Dot
  // for radios.
  check_style : CheckMarkStyle
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ProgressTheme {
  foreground : @core.Color
  background : @core.Color
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SliderTheme {
  foreground : @core.Color
  background : @core.Color
  thumb_color : @core.Color
  track_height : Double
  thumb_size : Double
  radius : Double
  // Thumb shape. Circle forces a round thumb regardless of `radius`.
  thumb_shape : ThumbShape
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PickerTheme {
  font : @core.FontSpec
  foreground : @core.Color
  background : @core.Brush
  radius : Double
  popup_max_height : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ToneTokens {
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FeedbackTheme {
  neutral : ToneTokens
  info : ToneTokens
  success : ToneTokens
  warning : ToneTokens
  danger : ToneTokens
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct BadgeTheme {
  neutral : ToneTokens
  accent : ToneTokens
  success : ToneTokens
  warning : ToneTokens
  danger : ToneTokens
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FormValidationTheme {
  foreground : @core.Color
  background : @core.Color
  border : @core.Color
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)
