///|
pub fn view_exact_channel(
  key : @core.DeclarationKey,
) -> @core.DeclarationChannel {
  @core.DeclarationChannel::Exact(key)
}

///|

///|
pub fn view_double_option_key(value : Double?) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(@core.DeclarationKey::double))
}

///|
pub fn view_point_key(point : @core.Point) -> @core.DeclarationKey {
  view_record_key("Point", [
    ("x", @core.DeclarationKey::double(point.x)),
    ("y", @core.DeclarationKey::double(point.y)),
  ])
}

///|

///|
pub fn view_size_option_key(size : @core.Size?) -> @core.DeclarationKey {
  @core.DeclarationKey::option(size.map(view_size_key))
}

///|
pub fn view_insets_key(insets : @core.Insets) -> @core.DeclarationKey {
  view_record_key("Insets", [
    ("top", @core.DeclarationKey::double(insets.top)),
    ("right", @core.DeclarationKey::double(insets.right)),
    ("bottom", @core.DeclarationKey::double(insets.bottom)),
    ("left", @core.DeclarationKey::double(insets.left)),
  ])
}

///|
pub fn view_font_family_key(family : @core.FontFamily) -> @core.DeclarationKey {
  match family {
    @core.FontFamily::Name(name) =>
      view_record_key("FontFamily.Name", [
        ("name", @core.DeclarationKey::string(name)),
      ])
    @core.FontFamily::SystemUi => @core.DeclarationKey::int(1)
    @core.FontFamily::UiSansSerif => @core.DeclarationKey::int(2)
    @core.FontFamily::UiSerif => @core.DeclarationKey::int(3)
    @core.FontFamily::UiMonospace => @core.DeclarationKey::int(4)
    @core.FontFamily::SansSerif => @core.DeclarationKey::int(5)
    @core.FontFamily::Serif => @core.DeclarationKey::int(6)
    @core.FontFamily::Monospace => @core.DeclarationKey::int(7)
    @core.FontFamily::Emoji => @core.DeclarationKey::int(8)
    @core.FontFamily::Math => @core.DeclarationKey::int(9)
    @core.FontFamily::FangSong => @core.DeclarationKey::int(10)
  }
}

///|
pub fn view_font_key(font : @core.FontSpec) -> @core.DeclarationKey {
  view_record_key("FontSpec", [
    (
      "families",
      @core.DeclarationKey::array(
        font.families.families.map(view_font_family_key),
      ),
    ),
    ("size", @core.DeclarationKey::double(font.size)),
    ("weight", @core.DeclarationKey::int(font.weight)),
    (
      "style",
      @core.DeclarationKey::int(
        match font.style {
          @core.FontStyle::Normal => 0
          @core.FontStyle::Italic => 1
        },
      ),
    ),
  ])
}

///|
pub fn view_font_option_key(font : @core.FontSpec?) -> @core.DeclarationKey {
  @core.DeclarationKey::option(font.map(view_font_key))
}

///|
pub fn view_semantics_role_key(
  role : @core.SemanticsRole,
) -> @core.DeclarationKey {
  @core.DeclarationKey::int(
    match role {
      @core.SemanticsRole::None => 0
      @core.SemanticsRole::Text => 1
      @core.SemanticsRole::Link => 2
      @core.SemanticsRole::Heading => 3
      @core.SemanticsRole::Navigation => 4
      @core.SemanticsRole::Main => 5
      @core.SemanticsRole::Button => 6
      @core.SemanticsRole::Checkbox => 7
      @core.SemanticsRole::TextField => 8
      @core.SemanticsRole::List => 9
      @core.SemanticsRole::ListItem => 10
      @core.SemanticsRole::Grid => 11
      @core.SemanticsRole::ScrollView => 12
      @core.SemanticsRole::Switch => 13
      @core.SemanticsRole::Radio => 14
      @core.SemanticsRole::Slider => 15
      @core.SemanticsRole::Progress => 16
      @core.SemanticsRole::Tab => 17
      @core.SemanticsRole::Dialog => 18
      @core.SemanticsRole::Tooltip => 19
      @core.SemanticsRole::Menu => 20
      @core.SemanticsRole::ButtonGroup => 21
      @core.SemanticsRole::Form => 22
      @core.SemanticsRole::FormField => 23
      @core.SemanticsRole::Tree => 24
      @core.SemanticsRole::TreeItem => 25
      @core.SemanticsRole::Group => 26
      @core.SemanticsRole::WebView => 27
      @core.SemanticsRole::Image => 28
      @core.SemanticsRole::Alert => 29
      @core.SemanticsRole::Status => 30
      @core.SemanticsRole::ComboBox => 31
      @core.SemanticsRole::Option => 32
      @core.SemanticsRole::Table => 33
      @core.SemanticsRole::Row => 34
      @core.SemanticsRole::Cell => 35
      @core.SemanticsRole::Separator => 36
    },
  )
}

///|
pub fn view_brush_key(value : @core.Brush) -> @core.DeclarationKey {
  match value {
    @core.Brush::Solid(color) =>
      view_record_key("Brush.Solid", [("color", view_color_key(color))])
    @core.Brush::LinearGradient(spec) =>
      view_record_key("Brush.LinearGradient", [
        ("start", view_point_key(spec.start)),
        ("end", view_point_key(spec.end)),
        ("start_color", view_color_key(spec.start_color)),
        ("end_color", view_color_key(spec.end_color)),
      ])
    @core.Brush::RadialGradient(spec) =>
      view_record_key("Brush.RadialGradient", [
        ("center", view_point_key(spec.center)),
        ("radius", @core.DeclarationKey::double(spec.radius)),
        ("center_color", view_color_key(spec.center_color)),
        ("edge_color", view_color_key(spec.edge_color)),
      ])
  }
}

///|
pub fn view_brush_option_key(value : @core.Brush?) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(view_brush_key))
}

///|
pub fn view_border_key(value : @core.BorderStyle) -> @core.DeclarationKey {
  view_record_key("BorderStyle", [
    ("brush", view_brush_key(value.brush)),
    ("width", @core.DeclarationKey::double(value.width)),
  ])
}

///|
pub fn view_border_option_key(
  value : @core.BorderStyle?,
) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(view_border_key))
}

///|
pub fn view_shadow_key(value : @core.ShadowStyle) -> @core.DeclarationKey {
  view_record_key("ShadowStyle", [
    ("color", view_color_key(value.color)),
    ("offset", view_point_key(value.offset)),
    ("blur_radius", @core.DeclarationKey::double(value.blur_radius)),
    ("spread", @core.DeclarationKey::double(value.spread)),
  ])
}

///|
pub fn view_shadow_option_key(
  value : @core.ShadowStyle?,
) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(view_shadow_key))
}

///|
pub fn view_max_double(left : Double, right : Double) -> Double {
  if left >= right {
    left
  } else {
    right
  }
}

///|
pub fn view_min_double(left : Double, right : Double) -> Double {
  if left <= right {
    left
  } else {
    right
  }
}

///|
pub fn view_max_int(left : Int, right : Int) -> Int {
  if left >= right {
    left
  } else {
    right
  }
}

///|
pub fn view_button_next_state(
  current : @core.PressableState,
  inside : Bool,
  phase : @core.PointerPhase,
) -> @core.PressableState {
  match phase {
    @core.PointerPhase::Move =>
      if current == @core.PressableState::Pressed && inside {
        @core.PressableState::Pressed
      } else if inside {
        @core.PressableState::Hovered
      } else {
        @core.PressableState::Normal
      }
    @core.PointerPhase::Down =>
      if inside {
        @core.PressableState::Pressed
      } else {
        @core.PressableState::Normal
      }
    @core.PointerPhase::Up =>
      if inside {
        @core.PressableState::Hovered
      } else {
        @core.PressableState::Normal
      }
    // Synthetic runtime phase: the pointer left the element. Drop any hover or
    // press state and return to rest. (`inside` is always false for an `Exit`,
    // but the branch is unconditional so the intent is explicit.)
    @core.PointerPhase::Exit | @core.PointerPhase::Cancel =>
      @core.PressableState::Normal
  }
}

///|
pub(all) enum ButtonTransitionState {
  Idle
  Active(@core.PressableState, Double)
}

///|
impl @core.ViewStateValue for ButtonTransitionState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.ButtonTransitionState.v1")
}

///|
impl @core.ViewStateValue for ButtonTransitionState with fn encode_view_state(
  self,
) {
  match self {
    Idle => b"\x00"
    Active(from_state, start_ms) => {
      let output = Buffer(size_hint=10)
      output.write_byte(1)
      output.write_byte(
        match from_state {
          @core.PressableState::Normal => 0
          @core.PressableState::Hovered => 1
          @core.PressableState::Pressed => 2
        },
      )
      output.write_double_be(start_ms)
      output.to_bytes()
    }
  }
}

///|
impl @core.ViewStateValue for ButtonTransitionState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes == b"\x00" {
    Some(Idle)
  } else if bytes.length() == 10 && bytes[0] == 1 {
    let from_state = match bytes[1] {
      0 => Some(@core.PressableState::Normal)
      1 => Some(@core.PressableState::Hovered)
      2 => Some(@core.PressableState::Pressed)
      _ => None
    }
    let start_ms = @core.ViewStateValue::decode_view_state(
      0.0,
      bytes[2:10].to_owned(),
    )
    match (from_state, start_ms) {
      (Some(from_state), Some(start_ms)) => Some(Active(from_state, start_ms))
      _ => None
    }
  } else {
    None
  }
}

///|
pub fn button_transition_slot() -> @core.ViewStateSlot[ButtonTransitionState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.button.transition"),
    initial=ButtonTransitionState::Idle,
  )
}

///|
pub fn button_transition(
  state : @core.ViewStateContext,
) -> (@core.PressableState, Double)? {
  match state.read_slot(button_transition_slot()) {
    Active(from_state, start_ms) => Some((from_state, start_ms))
    Idle => None
  }
}

///|
/// Persist button transition state. Wraps `with_slot` so callers outside common/
/// do not need the `ViewStateValue` impl to be visible.
pub fn button_state_with_transition(
  state : @core.ViewStateContext,
  from_state : @core.PressableState,
  next : @core.PressableState,
  now_ms : Double,
) -> @core.ViewStateContext {
  let interaction_state = {
    ..state,
    hovered: next == @core.PressableState::Hovered,
    pressed: next == @core.PressableState::Pressed,
  }
  if from_state == next {
    interaction_state
  } else {
    interaction_state.with_slot(
      button_transition_slot(),
      ButtonTransitionState::Active(from_state, now_ms),
    )
  }
}

///|
/// Resolve the solid background color for a button state by reading the
/// brush's fallback color. All built-in button styles use `Brush::solid`, so
/// this is exact for them; gradient brushes degrade to their start color.
pub fn pressable_state_color(brush : @core.Brush) -> @core.Color {
  brush.fallback_color()
}

///|
/// Map a button visual state to its background brush.
pub fn pressable_state_brush(
  state : @core.PressableState,
  normal : @core.Brush,
  hovered : @core.Brush,
  pressed : @core.Brush,
) -> @core.Brush {
  match state {
    @core.PressableState::Normal => normal
    @core.PressableState::Hovered => hovered
    @core.PressableState::Pressed => pressed
  }
}

///|
pub fn[Msg] view_event_result(
  changed? : Bool = false,
  activated? : Bool = false,
  focused? : Bool = false,
  captured? : Bool = false,
  state? : @core.ViewStateContext? = None,
  text_control? : @core.TextControlStateContext? = None,
  dirty? : @core.ViewDirtyHint = @core.ViewDirtyHint::ViewClean,
  messages? : Array[Msg] = [],
) -> @core.ViewEventResult[Msg] {
  {
    changed,
    activated,
    focused,
    captured,
    state,
    text_control,
    dirty,
    messages,
  }
}

///|
/// Emit a two-layer elevation shadow for a raised surface: a tight ambient
/// shadow (zero offset, small blur, low alpha) for contact depth, followed by
/// the key directional shadow. In dark mode the ambient uses a lighter tint
/// than pure black so the shadow is visible against the dark surface, since
/// black-on-near-black key shadows disappear. Callers that only have a single
/// `ShadowStyle?` (the key shadow) pass it here to upgrade it to the pair;
/// `None` emits nothing.
pub fn emit_elevation_shadow(
  commands : Array[@core.DrawCommand],
  rounded : @core.RoundedRect,
  key_shadow : @core.ShadowStyle?,
  scheme : @core.ColorScheme,
) -> Unit {
  match key_shadow {
    Some(key) => {
      // Ambient: tight, centered, low-alpha. Light surfaces use black; dark
      // surfaces lift toward white so the elevation reads.
      let ambient_color = match scheme {
        @core.ColorScheme::Light =>
          @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.06)
        @core.ColorScheme::Dark =>
          @core.Color::rgba(r=1.0, g=1.0, b=1.0, a=0.04)
      }
      commands.push(
        @core.DrawCommand::DrawShadow(
          @core.ShadowSpec::new(
            rect=rounded,
            color=ambient_color,
            offset=@core.Point::new(x=0.0, y=0.0),
            blur_radius=view_max_double(2.0, key.blur_radius * 0.25),
          ),
        ),
      )
      commands.push(
        @core.DrawCommand::DrawShadow(
          @core.ShadowSpec::new(
            rect=rounded,
            color=key.color,
            offset=key.offset,
            blur_radius=key.blur_radius,
            spread=key.spread,
          ),
        ),
      )
    }
    None => ()
  }
}
