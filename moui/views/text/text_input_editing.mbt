///|
priv struct TextEditResult {
  text : String
  caret : Int32
  selection : @core.TextRange?
  start : Int32
  before : String
  after : String
}

///|
fn text_input_state_for_single_line(
  text~ : String,
  frame~ : @core.Rect,
  font~ : @core.FontSpec,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
  search_bar~ : Bool,
) -> @core.TextInputState {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let display_text = text_with_composition(text, control, focused=true)
  let text_frame = single_line_text_frame(frame, search_bar, text != "")
  let layout = text_system.measure_text(
    @core.TextLayoutInput::new(
      text=display_text,
      font~,
      max_width=text_frame.size.width,
    ),
  )
  let caret = boundaries.nearest_boundary(control.caret)
  let visual_caret = clamp_int(
    text_field_visual_caret(text, control, focused=true),
    0,
    max_int(0, layout.caret_positions.length() - 1),
  )
  let cursor_x = text_frame.origin.x +
    caret_offset(layout.caret_positions, visual_caret)
  let caret_rect = text_editing_exact_cursor_rect(text_frame, cursor_x)
  {
    focused: true,
    text,
    caret,
    selection: @core.text_input_grapheme_selection(
      boundaries,
      control.selection,
    ),
    composition: control.composition,
    composition_cursor: control.composition_cursor,
    frame,
    caret_rect,
  }
}

///|
fn single_line_text_frame(
  frame : @core.Rect,
  search_bar : Bool,
  has_text : Bool,
) -> @core.Rect {
  if search_bar {
    searchbar_text_frame(frame, has_text~)
  } else {
    frame.inset(@core.Insets::symmetric(horizontal=10.0, vertical=4.0))
  }
}

///|
/// Find the nearest grapheme-safe caret for a pointer in a single-line field.
/// The layout uses the same caret positions as painting, so this remains
/// correct for native text providers as well as the fallback text system.
fn single_line_text_caret_at_position(
  text : String,
  frame : @core.Rect,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
  search_bar : Bool,
  position : @core.Point,
) -> Int32 {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let text_frame = single_line_text_frame(frame, search_bar, text != "")
  let layout = text_system.measure_text(
    @core.TextLayoutInput::new(text~, font~, max_width=text_frame.size.width),
  )
  let caret_positions = layout.caret_positions
  if caret_positions.is_empty() {
    return 0
  }
  let x = position.x - text_frame.origin.x
  let mut best = 0
  let mut best_distance = 1.0e18
  for boundary in boundaries.boundaries() {
    if boundary >= caret_positions.length() {
      break
    }
    let distance = (caret_positions[boundary] - x).abs()
    // Prefer the later boundary on a tie. This makes clicks past a clipped
    // line select the end rather than the first boundary sharing max_width.
    if distance <= best_distance {
      best = boundary
      best_distance = distance
    }
  }
  best
}

///|
fn text_with_composition(
  text : String,
  control : @core.TextControlStateContext,
  focused~ : Bool,
) -> String {
  if !focused {
    text
  } else {
    match control.composition {
      Some(composition) =>
        replace_current_selection(
          text,
          control.caret,
          control.selection,
          composition,
        ).text
      None => text
    }
  }
}

///|
fn text_field_visual_caret(
  text : String,
  control : @core.TextControlStateContext,
  focused~ : Bool,
) -> Int32 {
  let caret = clamp_int(control.caret, 0, text_length(text))
  if !focused {
    caret
  } else {
    match control.composition {
      Some(composition) =>
        @core.composition_start_index(text, control.caret, control.selection) +
        @core.composition_cursor_offset(control, composition)
      None => caret
    }
  }
}

///|
fn normalize_text_range_to_grapheme(
  text : String,
  range : @core.TextRange,
) -> @core.TextRange {
  @core.normalize_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
    range,
  )
}

///|
fn replace_current_selection(
  text : String,
  caret : Int32,
  selection : @core.TextRange?,
  replacement : String,
) -> TextEditResult {
  let range = match selection {
    Some(selection) => selection
    None => @core.TextRange::collapsed(caret)
  }
  replace_text_range(text, range, replacement)
}

///|
/// Views-only packaging of a core edit: core returns the next text, the
/// deleted slice and the normalized start in one scan, so the caret and the
/// undo delta are derived here instead of by copying the document into a
/// char array.
fn replace_text_range(
  text : String,
  range : @core.TextRange,
  replacement : String,
) -> TextEditResult {
  let (next_text, before, start) = @core.replace_text_range_edit(
    text~,
    normalize_text_range_to_grapheme(text, range),
    replacement,
  )
  let caret = start +
    @core.TextGraphemeBoundaries::new(text=replacement).length()
  {
    text: next_text,
    caret: @core.TextGraphemeBoundaries::new(text=next_text).clamp_index(caret),
    selection: None,
    start,
    before,
    after: replacement,
  }
}

///|
fn select_text_control(
  control : @core.TextControlStateContext,
  text : String,
) -> @core.TextControlStateContext {
  let length = text_length(text)
  {
    ..control,
    caret: length,
    selection: Some(@core.TextRange::new(start=0, end=length)),
    text_selection_anchor: None,
    goal_column: None,
    composition: None,
    composition_cursor: None,
  }
}

///|
fn text_control_for_text(
  control : @core.TextControlStateContext,
  text : String,
) -> @core.TextControlStateContext {
  {
    ..control,
    caret: text_length(text),
    selection: None,
    text_selection_anchor: None,
    goal_column: None,
    composition: None,
    composition_cursor: None,
  }
}

///|
fn[Msg] text_input_messages(
  on_input : ((String) -> Msg)?,
  text : String,
) -> Array[Msg] {
  match on_input {
    Some(handler) => [handler(text)]
    None => []
  }
}

///|
fn[Msg] option_message(message : Msg?) -> Array[Msg] {
  match message {
    Some(message) => [message]
    None => []
  }
}

///|
fn searchbar_text_frame(frame : @core.Rect, has_text~ : Bool) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x + 32.0,
    y=frame.origin.y,
    width=if has_text {
      frame.size.width - 64.0
    } else {
      frame.size.width - 32.0
    },
    height=frame.size.height,
  ).inset(@core.Insets::symmetric(vertical=0.0))
}

///|
fn searchbar_clear_frame(frame : @core.Rect) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x + frame.size.width - 26.0,
    y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
    width=16.0,
    height=16.0,
  )
}

///|
fn text_length(text : String) -> Int32 {
  text.to_array().length()
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a >= b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int32, b : Int32) -> Int32 {
  if a >= b {
    a
  } else {
    b
  }
}

///|
fn clamp_int(value : Int32, min : Int32, max : Int32) -> Int32 {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
