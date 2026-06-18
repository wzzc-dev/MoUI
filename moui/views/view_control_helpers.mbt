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
fn view_text_length(text : String) -> Int {
  text.to_array().length()
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
    @core.PointerPhase::Cancel => @core.ButtonState::Normal
  }
}

///|
fn view_button_background(
  state : @core.ViewStateContext,
  normal : @core.Brush,
  hovered : @core.Brush,
  pressed : @core.Brush,
) -> @core.Brush {
  if state.pressed {
    pressed
  } else if state.hovered {
    hovered
  } else {
    normal
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
