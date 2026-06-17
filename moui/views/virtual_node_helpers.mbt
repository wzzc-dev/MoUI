///|
fn virtual_node_color_revision(color : @core.Color) -> String {
  "\{color.r},\{color.g},\{color.b},\{color.a}"
}

///|
fn virtual_node_brush_revision(value : @core.Brush) -> String {
  match value {
    @core.Brush::Solid(color) => "solid:\{virtual_node_color_revision(color)}"
    @core.Brush::LinearGradient(spec) =>
      "linear:\{spec.start.x},\{spec.start.y},\{spec.end.x},\{spec.end.y},\{virtual_node_color_revision(spec.start_color)},\{virtual_node_color_revision(spec.end_color)}"
    @core.Brush::RadialGradient(spec) =>
      "radial:\{spec.center.x},\{spec.center.y},\{spec.radius},\{virtual_node_color_revision(spec.center_color)},\{virtual_node_color_revision(spec.edge_color)}"
  }
}

///|
fn virtual_node_brush_option_revision(value : @core.Brush?) -> String {
  match value {
    Some(brush) => virtual_node_brush_revision(brush)
    None => "none"
  }
}

///|
fn virtual_node_border_option_revision(value : @core.BorderStyle?) -> String {
  match value {
    Some(value) => "\{virtual_node_brush_revision(value.brush)}:\{value.width}"
    None => "none"
  }
}

///|
fn virtual_node_shadow_option_revision(value : @core.ShadowStyle?) -> String {
  match value {
    Some(value) =>
      "\{virtual_node_color_revision(value.color)}:\{value.offset.x},\{value.offset.y}:\{value.blur_radius}:\{value.spread}"
    None => "none"
  }
}

///|
fn virtual_node_font_revision(font : @core.FontSpec) -> String {
  let style = match font.style {
    @core.FontStyle::Normal => "normal"
    @core.FontStyle::Italic => "italic"
  }
  "\{font.size}:\{font.weight}:\{style}"
}

///|
fn virtual_node_size_revision(size : @core.Size) -> String {
  "\{size.width}x\{size.height}"
}

///|
fn virtual_node_text_length(text : String) -> Int {
  text.to_array().length()
}

///|
fn virtual_node_max_double(left : Double, right : Double) -> Double {
  if left >= right {
    left
  } else {
    right
  }
}

///|
fn virtual_node_min_double(left : Double, right : Double) -> Double {
  if left <= right {
    left
  } else {
    right
  }
}

///|
fn virtual_node_max_int(left : Int, right : Int) -> Int {
  if left >= right {
    left
  } else {
    right
  }
}

///|
fn virtual_node_button_next_state(
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
fn virtual_node_button_background(
  state : @core.VirtualNodeStateContext,
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
fn[Msg] virtual_node_event_result(
  changed? : Bool = false,
  activated? : Bool = false,
  focused? : Bool = false,
  captured? : Bool = false,
  state? : @core.VirtualNodeStateContext? = None,
  text_control? : @core.TextControlStateContext? = None,
  dirty? : @core.VirtualNodeDirtyHint = @core.VirtualNodeDirtyHint::VirtualNodeClean,
  messages? : Array[Msg] = [],
) -> @core.VirtualNodeEventResult[Msg] {
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
