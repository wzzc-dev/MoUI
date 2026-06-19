///|
fn view_color_revision(color : @core.Color) -> String {
  "\{color.r},\{color.g},\{color.b},\{color.a}"
}

///|
fn view_brush_revision(value : @core.Brush) -> String {
  match value {
    @core.Brush::Solid(color) => "solid:\{view_color_revision(color)}"
    @core.Brush::LinearGradient(spec) =>
      "linear:\{spec.start.x},\{spec.start.y},\{spec.end.x},\{spec.end.y},\{view_color_revision(spec.start_color)},\{view_color_revision(spec.end_color)}"
    @core.Brush::RadialGradient(spec) =>
      "radial:\{spec.center.x},\{spec.center.y},\{spec.radius},\{view_color_revision(spec.center_color)},\{view_color_revision(spec.edge_color)}"
  }
}

///|
fn view_brush_option_revision(value : @core.Brush?) -> String {
  match value {
    Some(brush) => view_brush_revision(brush)
    None => "none"
  }
}

///|
fn view_border_option_revision(value : @core.BorderStyle?) -> String {
  match value {
    Some(value) => "\{view_brush_revision(value.brush)}:\{value.width}"
    None => "none"
  }
}

///|
fn view_shadow_option_revision(value : @core.ShadowStyle?) -> String {
  match value {
    Some(value) =>
      "\{view_color_revision(value.color)}:\{value.offset.x},\{value.offset.y}:\{value.blur_radius}:\{value.spread}"
    None => "none"
  }
}

///|
fn view_font_revision(font : @core.FontSpec) -> String {
  let style = match font.style {
    @core.FontStyle::Normal => "normal"
    @core.FontStyle::Italic => "italic"
  }
  "\{font.size}:\{font.weight}:\{style}"
}

///|
fn view_size_revision(size : @core.Size) -> String {
  "\{size.width}x\{size.height}"
}

///|
fn view_max_double(left : Double, right : Double) -> Double {
  if left >= right {
    left
  } else {
    right
  }
}

///|
fn view_min_double(left : Double, right : Double) -> Double {
  if left <= right {
    left
  } else {
    right
  }
}

///|
fn view_max_int(left : Int, right : Int) -> Int {
  if left >= right {
    left
  } else {
    right
  }
}

///|
fn view_button_next_state(
  current : @core.ButtonState,
  inside : Bool,
  phase : @core.PointerPhase,
) -> @core.ButtonState {
  match phase {
    @core.PointerPhase::Move =>
      if current == @core.ButtonState::Pressed && inside {
        @core.ButtonState::Pressed
      } else if inside {
        @core.ButtonState::Hovered
      } else {
        @core.ButtonState::Normal
      }
    @core.PointerPhase::Down =>
      if inside {
        @core.ButtonState::Pressed
      } else {
        @core.ButtonState::Normal
      }
    @core.PointerPhase::Up =>
      if inside {
        @core.ButtonState::Hovered
      } else {
        @core.ButtonState::Normal
      }
    // Synthetic runtime phase: the pointer left the element. Drop any hover or
    // press state and return to rest. (`inside` is always false for an `Exit`,
    // but the branch is unconditional so the intent is explicit.)
    @core.PointerPhase::Exit | @core.PointerPhase::Cancel =>
      @core.ButtonState::Normal
  }
}

///|
/// Encode a button transition start into `ViewStateContext.scratch` so the
/// next paint can interpolate from the previous visual state toward the new
/// one. Format: `bt:<from_state>:<start_ms>` where `from_state` is 0=Normal,
/// 1=Hovered, 2=Pressed and `start_ms` is the integer millisecond clock. The
/// `bt:` prefix avoids clashing with other scratch users; a missing/empty
/// scratch means "no transition in flight".
fn button_transition_scratch(
  from_state : @core.ButtonState,
  start_ms : Double,
) -> String {
  let from_code = match from_state {
    @core.ButtonState::Normal => 0
    @core.ButtonState::Hovered => 1
    @core.ButtonState::Pressed => 2
  }
  "bt:\{from_code}:\{start_ms.to_int()}"
}

///|
/// Parse a previously encoded transition start. Returns `(from_state, start_ms)`
/// when the scratch carries a valid `bt:` marker, or `None` when no transition
/// is recorded (e.g. first paint or non-button scratch content).
fn parse_button_transition(
  scratch : String,
) -> ((@core.ButtonState, Int)?) {
  let parts = scratch.split(":").to_array()
  if parts.length() == 3 && parts[0] == "bt" {
    let from_code = match parts[1] {
      "0" => Some(@core.ButtonState::Normal)
      "1" => Some(@core.ButtonState::Hovered)
      "2" => Some(@core.ButtonState::Pressed)
      _ => None
    }
    match (from_code, parse_simple_int(parts[2].to_owned())) {
      (Some(state), Some(start_ms)) => Some((state, start_ms))
      _ => None
    }
  } else {
    None
  }
}

///|
/// Parse a non-negative ASCII-integer string. Avoids depending on a strconv
/// mooncake for the one place (button transition scratch) that needs it; only
/// digits are accepted, so negative or fractional input returns `None`.
fn parse_simple_int(text : String) -> Int? {
  if text.length() == 0 {
    return None
  }
  let mut value = 0
  for ch in text {
    if ch >= '0' && ch <= '9' {
      value = value * 10 + (ch.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  Some(value)
}

///|
/// Resolve the solid background color for a button state by reading the
/// brush's fallback color. All built-in button styles use `Brush::solid`, so
/// this is exact for them; gradient brushes degrade to their start color.
fn button_state_color(
  brush : @core.Brush,
) -> @core.Color {
  brush.fallback_color()
}

///|
/// Map a button visual state to its background brush.
fn button_state_brush(
  state : @core.ButtonState,
  normal : @core.Brush,
  hovered : @core.Brush,
  pressed : @core.Brush,
) -> @core.Brush {
  match state {
    @core.ButtonState::Normal => normal
    @core.ButtonState::Hovered => hovered
    @core.ButtonState::Pressed => pressed
  }
}

///|
fn[Msg] view_event_result(
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
fn emit_elevation_shadow(
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
