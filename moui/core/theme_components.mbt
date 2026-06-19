///|
/// Component theme tokens. This file lifts per-control design tokens from the
/// `moui_theme` addon into `core` so `Theme` can carry a first-class
/// `components` field. Token structs hold raw `Color`/`Double` values (the
/// "token" layer); `ControlStateStyle` holds the resolved `Brush`/`BorderStyle`
/// values that paint consumes. Both layers live in `core` because they only
/// depend on `core` value types (`Color`, `Brush`, `BorderStyle`,
/// `ShadowStyle`).
///
/// Resolution flow:
///   `ControlStateTokens` --resolve()--> `ControlStateStyle`
///   `ButtonTheme`        --resolve(variant, state)--> `ControlStateStyle`
///
/// Controls read `ctx.environment.theme.components.<control>` at paint time
/// and resolve the matching variant/state; `style?` on each control
/// constructor is a one-shot override that bypasses this resolution.

///|
/// Control interaction state for token resolution. This is the token-layer
/// state enum used to select a `ControlStateStyle` from a component theme. It
/// is distinct from the runtime `ButtonState` (a three-state gesture enum):
/// `InteractionState` covers the union of states every component theme needs
/// to resolve (normal/hovered/pressed/focused/disabled/selected/invalid), and
/// individual controls only pass the subset they support.
pub(all) enum InteractionState {
  Normal
  Hovered
  Pressed
  Focused
  Disabled
  Selected
  Invalid
} derive(Eq, Debug, ToJson)

///|
/// Convert a runtime `ButtonState` (gesture-driven three-state) into the
/// token-layer `InteractionState` for button resolution.
pub fn ButtonState::to_interaction(self : ButtonState) -> InteractionState {
  match self {
    Normal => InteractionState::Normal
    Hovered => InteractionState::Hovered
    Pressed => InteractionState::Pressed
  }
}

///|
/// Raw per-state token. Token layer: colors are plain `Color`, background is a
/// `Color` (paint resolves it to `Brush::solid`). `border_width == 0.0` means
/// "no border". `bottom_border_only` paints only the bottom edge (Fluent 2
/// underline inputs). `inner_focus_border` paints an inner stroke inside the
/// control frame on focus (Fluent 2 focus reveal).
pub(all) struct ControlStateTokens {
  foreground : Color
  background : Color
  border : Color
  border_width : Double
  radius : Double
  bottom_border_only : Bool
  inner_focus_border : Color?
} derive(Eq, Debug, ToJson)

///|
/// Resolved per-state style. Paint layer: `background` is a `Brush`, `border`
/// is `None` when `border_width == 0.0`. This is the type controls actually
/// consume when emitting `DrawCommand`s.
pub(all) struct ControlStateStyle {
  foreground : Color
  background : Brush
  border : BorderStyle?
  radius : Double
  shadow : ShadowStyle?
  bottom_border_only : Bool
  inner_focus_border : Color?
} derive(Eq, Debug, ToJson)

///|
/// Convenience constructor for `ControlStateTokens`.
pub fn ControlStateTokens::new(
  foreground~ : Color,
  background~ : Color,
  border~ : Color,
  border_width~ : Double,
  radius~ : Double,
  bottom_border_only? : Bool = false,
  inner_focus_border? : Color? = None,
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
pub fn ControlStateTokens::resolve(self : ControlStateTokens) -> ControlStateStyle {
  {
    foreground: self.foreground,
    background: Brush::Solid(self.background),
    border: control_state_border(self),
    radius: self.radius,
    shadow: None,
    bottom_border_only: self.bottom_border_only,
    inner_focus_border: self.inner_focus_border,
  }
}

///|
fn control_state_border(state : ControlStateTokens) -> BorderStyle? {
  if state.border_width > 0.0 {
    Some(
      BorderStyle::new(brush=Brush::Solid(state.border), width=state.border_width),
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
  color : Color
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
  state : InteractionState,
) -> ControlStateStyle {
  let base = self.variant_tokens(variant)
  let normal = base.resolve()
  match state {
    Normal => normal
    Hovered => {
      ..normal,
      background: Brush::Solid(
        state_layer_background(
          base.background,
          self.state_layer.color,
          self.state_layer.hover_alpha,
        ),
      ),
    }
    Pressed => {
      ..normal,
      background: Brush::Solid(
        state_layer_background(
          base.background,
          self.state_layer.color,
          self.state_layer.pressed_alpha,
        ),
      ),
    }
    Focused => {
      ..normal,
      background: Brush::Solid(
        state_layer_background(
          base.background,
          self.state_layer.color,
          self.state_layer.focus_alpha,
        ),
      ),
    }
    Disabled => {
      ..normal,
      foreground: normal.foreground.multiply_alpha(self.state_layer.disabled_alpha),
      background: normal.background.multiply_alpha(self.state_layer.disabled_alpha),
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
  border : BorderStyle?,
  state_layer : StateLayerTokens,
) -> BorderStyle? {
  match border {
    Some(value) =>
      Some({ ..value, brush: value.brush.multiply_alpha(state_layer.disabled_alpha) })
    None => None
  }
}

///|
/// Blend a translucent state-layer color onto a base background. When the base
/// is fully transparent, the layer is emitted at the requested alpha; otherwise
/// the layer is composited over the base keeping the base alpha.
fn state_layer_background(
  background : Color,
  layer : Color,
  alpha : Double,
) -> Color {
  if background.a <= 0.0 {
    layer.with_alpha(alpha)
  } else {
    let amount = clamp_unit(alpha)
    Color::rgba(
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
  placeholder : Color
  cursor : Color
  font : FontSpec
  appearance : TextFieldAppearance
} derive(Eq, Debug, ToJson)

///|
pub fn TextFieldTheme::resolve(
  self : TextFieldTheme,
  state : InteractionState,
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
  base_shadow : ShadowStyle?
  raised_shadow : ShadowStyle?
  overlay_shadow : ShadowStyle?
} derive(Eq, Debug, ToJson)

// ---------------------------------------------------------------------------
// Choice / progress / slider / picker / feedback / badge / form validation
// ---------------------------------------------------------------------------

///|
pub(all) struct ChoiceControlTheme {
  foreground : Color
  selected_color : Color
  disabled_foreground : Color
  disabled_selected_color : Color
  control_size : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ProgressTheme {
  foreground : Color
  background : Color
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SliderTheme {
  foreground : Color
  background : Color
  thumb_color : Color
  track_height : Double
  thumb_size : Double
  radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PickerTheme {
  font : FontSpec
  foreground : Color
  background : Brush
  radius : Double
  popup_max_height : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ToneTokens {
  foreground : Color
  background : Color
  border : Color
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
  foreground : Color
  background : Color
  border : Color
  radius : Double
  padding : Double
} derive(Eq, Debug, ToJson)

// ---------------------------------------------------------------------------
// ComponentThemes aggregate
// ---------------------------------------------------------------------------

///|
/// First-class component theme aggregate carried by `Theme`. Each field is a
/// per-control token set; controls resolve variant/state at paint time via the
/// `resolve` methods above. An app that wants a branded design system sets
/// this once on the root theme and every control inherits it.
pub(all) struct ComponentThemes {
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
pub fn Theme::with_components(
  self : Theme,
  components : ComponentThemes,
) -> Theme {
  { ..self, components }
}
