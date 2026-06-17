///|
priv struct TextEditResult {
  text : String
  caret : Int
  selection : @core.TextRange?
}

///|
priv enum TextCaretDirection {
  MoveLeft
  MoveRight
  MoveStart
  MoveEnd
}

///|
priv struct TextCaretMoveResult {
  caret : Int
  selection : @core.TextRange?
}

///|
priv struct TextHistoryRestoreResult {
  text : String
  control : @core.TextControlStateContext
  changed : Bool
}

///|
priv struct TextInputApplyResult {
  text : String
  control : @core.TextControlStateContext
  changed : Bool
}

///|
fn restore_text_history(
  control : @core.TextControlStateContext,
  current : String,
  undo~ : Bool,
) -> TextHistoryRestoreResult {
  let source = if undo { control.undo_stack } else { control.redo_stack }
  if source.length() == 0 {
    return { text: current, control, changed: false }
  }
  let restored = source[source.length() - 1]
  let next_source : Array[@core.TextHistoryEntryContext] = []
  for index in 0..<(source.length() - 1) {
    next_source.push(source[index])
  }
  let current_entry : @core.TextHistoryEntryContext = {
    text: current,
    caret: control.caret,
    selection: control.selection,
  }
  let destination = if undo { control.redo_stack } else { control.undo_stack }
  let next_destination : Array[@core.TextHistoryEntryContext] = []
  next_destination.append(destination)
  next_destination.push(current_entry)
  let next_control = if undo {
    {
      ..control,
      caret: restored.caret,
      selection: restored.selection,
      composition: None,
      composition_cursor: None,
      undo_stack: next_source,
      redo_stack: next_destination,
    }
  } else {
    {
      ..control,
      caret: restored.caret,
      selection: restored.selection,
      composition: None,
      composition_cursor: None,
      undo_stack: next_destination,
      redo_stack: next_source,
    }
  }
  {
    text: restored.text,
    control: next_control,
    changed: restored.text != current,
  }
}

///|
fn apply_text_input(
  control : @core.TextControlStateContext,
  text : String,
  event : @core.TextInputEvent,
  record_history~ : Bool,
) -> TextInputApplyResult {
  match event {
    @core.TextInputEvent::InsertText(inserted) => {
      if inserted == "" {
        return { text, control, changed: false }
      }
      let edit = replace_current_selection(
        text,
        control.caret,
        control.selection,
        inserted,
      )
      apply_text_edit(control, text, edit, record_history~)
    }
    @core.TextInputEvent::CompositionStart => {
      let next_control = {
        ..control,
        composition: Some(""),
        composition_cursor: None,
      }
      { text, control: next_control, changed: true }
    }
    @core.TextInputEvent::CompositionUpdate(update) => {
      let next_control = {
        ..control,
        composition: if update.text() == "" {
          None
        } else {
          Some(update.text())
        },
        composition_cursor: match update.cursor() {
          Some(cursor) => {
            let normalized = normalize_text_range_to_grapheme(
              update.text(),
              cursor,
            )
            let length = text_length(update.text())
            let start = clamp_int(normalized.start, 0, length)
            let end = clamp_int(normalized.end, 0, length)
            Some(@core.TextRange::new(start~, end~))
          }
          None => None
        },
      }
      { text, control: next_control, changed: true }
    }
    @core.TextInputEvent::CompositionEnd(inserted) => {
      let next_control = {
        ..control,
        composition: None,
        composition_cursor: None,
      }
      if inserted == "" {
        { text, control: { ..next_control, selection: None }, changed: true }
      } else {
        let edit = replace_current_selection(
          text,
          next_control.caret,
          next_control.selection,
          inserted,
        )
        apply_text_edit(next_control, text, edit, record_history~)
      }
    }
    @core.TextInputEvent::DeleteRange(range) => {
      let edit = replace_text_range(text, range, "")
      apply_text_edit(control, text, edit, record_history~)
    }
    @core.TextInputEvent::DeleteSurrounding(before, after) => {
      let range = surrounding_delete_range(text, control.caret, before, after)
      let edit = replace_text_range(text, range, "")
      apply_text_edit(control, text, edit, record_history~)
    }
  }
}

///|
fn apply_text_edit(
  control : @core.TextControlStateContext,
  previous : String,
  edit : TextEditResult,
  record_history~ : Bool,
) -> TextInputApplyResult {
  let changed = edit.text != previous ||
    edit.caret != control.caret ||
    edit.selection != control.selection ||
    control.composition is Some(_) ||
    control.composition_cursor is Some(_)
  if changed {
    let undo_stack : Array[@core.TextHistoryEntryContext] = []
    undo_stack.append(control.undo_stack)
    if record_history && previous != edit.text {
      undo_stack.push({
        text: previous,
        caret: control.caret,
        selection: control.selection,
      })
    }
    {
      text: edit.text,
      control: {
        ..control,
        caret: edit.caret,
        selection: edit.selection,
        composition: None,
        composition_cursor: None,
        undo_stack,
        redo_stack: [],
      },
      changed: true,
    }
  } else {
    { text: previous, control, changed: false }
  }
}

///|
fn active_text_selection(selection : @core.TextRange?) -> @core.TextRange? {
  match selection {
    Some(selection) => {
      let normalized = selection.normalized()
      if normalized.is_collapsed() {
        None
      } else {
        Some(normalized)
      }
    }
    None => None
  }
}

///|
fn selected_text(text : String, selection : @core.TextRange?) -> String {
  match active_text_selection(selection) {
    Some(selection) => {
      let chars = text.to_array()
      let range = @core.normalize_grapheme_range(
        @core.TextGraphemeBoundaries::new(text~),
        selection,
      )
      let start = clamp_int(range.start, 0, chars.length())
      let end = clamp_int(range.end, start, chars.length())
      String::from_array(chars[start:end])
    }
    None => ""
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
  caret : Int,
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
fn replace_text_range(
  text : String,
  range : @core.TextRange,
  replacement : String,
) -> TextEditResult {
  let chars = text.to_array()
  let normalized = range.normalized()
  let range = @core.normalize_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
    normalized,
  )
  let start = clamp_int(range.start, 0, chars.length())
  let end = clamp_int(range.end, start, chars.length())
  let replacement_chars = replacement.to_array()
  {
    text: String::from_array(chars[:start] + replacement_chars + chars[end:]),
    caret: start + replacement_chars.length(),
    selection: None,
  }
}

///|
fn surrounding_delete_range(
  text : String,
  caret : Int,
  before : Int,
  after : Int,
) -> @core.TextRange {
  let length = text_length(text)
  let before = max_int(0, before)
  let after = max_int(0, after)
  let range = @core.delete_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
    caret,
    before,
    after,
  )
  @core.TextRange::new(
    start=clamp_int(range.start, 0, length),
    end=clamp_int(range.end, 0, length),
  )
}

///|
fn move_text_caret(
  text : String,
  caret : Int,
  selection : @core.TextRange?,
  direction : TextCaretDirection,
  extend~ : Bool,
) -> TextCaretMoveResult {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let length = boundaries.length()
  let caret = boundaries.clamp_index(caret)
  if extend {
    let anchor = boundaries.nearest_boundary(
      text_selection_anchor(caret, selection),
    )
    let next = move_text_caret_index(text, caret, direction)
    {
      caret: next,
      selection: if next == anchor {
        None
      } else {
        Some(@core.TextRange::new(start=anchor, end=next))
      },
    }
  } else {
    match active_text_selection(selection) {
      Some(selection) => {
        let selection = @core.normalize_grapheme_range(boundaries, selection)
        match direction {
          MoveLeft => { caret: selection.start, selection: None }
          MoveRight => { caret: selection.end, selection: None }
          MoveStart => { caret: 0, selection: None }
          MoveEnd => { caret: length, selection: None }
        }
      }
      None =>
        {
          caret: move_text_caret_index(text, caret, direction),
          selection: None,
        }
    }
  }
}

///|
fn text_selection_anchor(caret : Int, selection : @core.TextRange?) -> Int {
  match selection {
    Some(selection) =>
      if caret == selection.start {
        selection.end
      } else {
        selection.start
      }
    None => caret
  }
}

///|
fn move_text_caret_index(
  text : String,
  caret : Int,
  direction : TextCaretDirection,
) -> Int {
  let length = text_length(text)
  let caret = clamp_int(caret, 0, length)
  match direction {
    MoveLeft =>
      @core.TextGraphemeBoundaries::new(text~).previous_boundary(caret)
    MoveRight => @core.TextGraphemeBoundaries::new(text~).next_boundary(caret)
    MoveStart => 0
    MoveEnd => length
  }
}

///|
fn text_input_grapheme_selection(
  boundaries : @core.TextGraphemeBoundaries,
  selection : @core.TextRange?,
) -> @core.TextRange? {
  match selection {
    Some(selection) => {
      let start = boundaries.nearest_boundary(selection.start)
      let end = boundaries.nearest_boundary(selection.end)
      if start == end {
        None
      } else {
        Some(@core.TextRange::new(start~, end~))
      }
    }
    None => None
  }
}

///|
fn composition_start_index(
  text : String,
  caret : Int,
  selection : @core.TextRange?,
) -> Int {
  match active_text_selection(selection) {
    Some(selection) =>
      @core.normalize_grapheme_range(
        @core.TextGraphemeBoundaries::new(text~),
        selection,
      ).start
    None => @core.TextGraphemeBoundaries::new(text~).nearest_boundary(caret)
  }
}

///|
fn composition_cursor_offset(
  control : @core.TextControlStateContext,
  composition : String,
) -> Int {
  let length = text_length(composition)
  match control.composition_cursor {
    Some(cursor) => {
      let normalized = cursor.normalized()
      @core.TextGraphemeBoundaries::new(text=composition).nearest_boundary(
        clamp_int(normalized.end, 0, length),
      )
    }
    None => length
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
fn is_select_all_shortcut(event : @core.KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "a" || event.key == "A") &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
fn is_undo_shortcut(event : @core.KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "z" || event.key == "Z") &&
  !event.modifiers.shift &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
fn is_redo_shortcut(event : @core.KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "z" || event.key == "Z") &&
  event.modifiers.shift &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
fn widget_color_revision(color : @core.Color) -> String {
  "\{color.r},\{color.g},\{color.b},\{color.a}"
}

///|
fn widget_brush_revision(value : @core.Brush) -> String {
  match value {
    @core.Brush::Solid(color) => "solid:\{widget_color_revision(color)}"
    @core.Brush::LinearGradient(spec) =>
      "linear:\{spec.start.x},\{spec.start.y},\{spec.end.x},\{spec.end.y},\{widget_color_revision(spec.start_color)},\{widget_color_revision(spec.end_color)}"
    @core.Brush::RadialGradient(spec) =>
      "radial:\{spec.center.x},\{spec.center.y},\{spec.radius},\{widget_color_revision(spec.center_color)},\{widget_color_revision(spec.edge_color)}"
  }
}

///|
fn widget_border_option_revision(value : @core.BorderStyle?) -> String {
  match value {
    Some(value) => "\{widget_brush_revision(value.brush)}:\{value.width}"
    None => "none"
  }
}

///|
fn widget_font_revision(font : @core.FontSpec) -> String {
  let style = match font.style {
    @core.FontStyle::Normal => "normal"
    @core.FontStyle::Italic => "italic"
  }
  "\{font.size}:\{font.weight}:\{style}"
}

///|
fn widget_size_revision(size : @core.Size) -> String {
  "\{size.width}x\{size.height}"
}

///|
fn[Msg] widget_event_result(
  changed? : Bool = false,
  activated? : Bool = false,
  focused? : Bool = false,
  captured? : Bool = false,
  state? : @core.WidgetStateContext? = None,
  text_control? : @core.TextControlStateContext? = None,
  dirty? : @core.WidgetDirtyHint = @core.WidgetDirtyHint::WidgetClean,
  messages? : Array[Msg] = [],
) -> @core.WidgetEventResult[Msg] {
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
fn text_length(text : String) -> Int {
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
fn min_double(a : Double, b : Double) -> Double {
  if a <= b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a >= b {
    a
  } else {
    b
  }
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
