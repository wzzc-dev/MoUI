///|
priv struct TextEditResult {
  text : String
  caret : Int
}

///|
fn apply_text_edit(
  element : ElementNode,
  data : TextFieldViewSpec,
  edit : TextEditResult,
) -> ElementEventResult {
  if edit.text != data.value.get() ||
    edit.caret != element.caret ||
    element.selection is Some(_) ||
    element.composition is Some(_) {
    data.value.set(edit.text)
    element.caret = edit.caret
    element.selection = None
    element.composition = None
    element.dirty.mark_paint()
    { changed: true, activated: false, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn apply_multiline_text_edit(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  edit : TextEditResult,
) -> ElementEventResult {
  if edit.text != data.value.get() ||
    edit.caret != element.caret ||
    element.selection is Some(_) ||
    element.composition is Some(_) {
    data.value.set(edit.text)
    element.caret = edit.caret
    element.selection = None
    element.composition = None
    element.dirty.mark_paint()
    { changed: true, activated: false, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn replace_current_selection(
  text : String,
  caret : Int,
  selection : TextRange?,
  replacement : String,
) -> TextEditResult {
  let range = match selection {
    Some(selection) => selection
    None => TextRange::collapsed(caret)
  }
  replace_text_range(text, range, replacement)
}

///|
fn replace_text_range(
  text : String,
  range : TextRange,
  replacement : String,
) -> TextEditResult {
  let chars = text.to_array()
  let normalized = range.normalized()
  let start = clamp_int(normalized.start, 0, chars.length())
  let end = clamp_int(normalized.end, start, chars.length())
  let replacement_chars = replacement.to_array()
  {
    text: String::from_array(chars[:start] + replacement_chars + chars[end:]),
    caret: start + replacement_chars.length(),
  }
}

///|
fn surrounding_delete_range(
  text : String,
  caret : Int,
  before : Int,
  after : Int,
) -> TextRange {
  let length = text_length(text)
  let caret = clamp_int(caret, 0, length)
  let before = max_int(0, before)
  let after = max_int(0, after)
  TextRange::new(
    start=max_int(0, caret - before),
    end=min_int(length, caret + after),
  )
}

///|
fn text_with_composition(
  text : String,
  element : ElementNode,
  focused : Bool,
) -> String {
  if !focused {
    text
  } else {
    match element.composition {
      Some(composition) =>
        replace_text_range(
          text,
          TextRange::collapsed(element.caret),
          composition,
        ).text
      None => text
    }
  }
}

///|
fn text_field_visual_caret(
  text : String,
  element : ElementNode,
  focused : Bool,
) -> Int {
  let caret = clamp_int(element.caret, 0, text_length(text))
  if !focused {
    caret
  } else {
    match element.composition {
      Some(composition) =>
        caret + composition_cursor_offset(element, composition)
      None => caret
    }
  }
}

///|
fn composition_cursor_offset(
  element : ElementNode,
  composition : String,
) -> Int {
  let length = text_length(composition)
  match element.selection {
    Some(cursor) => {
      let normalized = cursor.normalized()
      clamp_int(normalized.end, 0, length)
    }
    None => length
  }
}

///|
fn text_length(text : String) -> Int {
  text.to_array().length()
}

///|
fn multiline_line_start(text : String, caret : Int) -> Int {
  let chars = text.to_array()
  let mut index = clamp_int(caret, 0, chars.length())
  while index > 0 && chars[index - 1] != '\n' {
    index = index - 1
  }
  index
}

///|
fn multiline_line_end(text : String, caret : Int) -> Int {
  let chars = text.to_array()
  let mut index = clamp_int(caret, 0, chars.length())
  while index < chars.length() && chars[index] != '\n' {
    index = index + 1
  }
  index
}

///|
fn move_multiline_caret_vertical(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  direction : Int,
) -> ElementEventResult {
  let text = data.value.get()
  let chars = text.to_array()
  let current_start = multiline_line_start(text, element.caret)
  let current_end = multiline_line_end(text, element.caret)
  let column = element.caret - current_start
  let mut next_start = current_start
  let mut next_end = current_end
  if direction < 0 {
    if current_start == 0 {
      return { changed: false, activated: false, focused: None }
    }
    next_end = current_start - 1
    next_start = multiline_line_start(text, next_end)
  } else {
    if current_end >= chars.length() {
      return { changed: false, activated: false, focused: None }
    }
    next_start = current_end + 1
    next_end = multiline_line_end(text, next_start)
  }
  element.caret = min_int(next_start + column, next_end)
  element.selection = None
  element.dirty.mark_paint()
  { changed: true, activated: false, focused: None }
}

///|
fn handle_rich_text_editor_input(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  event : TextInputEvent,
) -> ElementEventResult {
  match event {
    InsertText(text) => {
      if text == "" {
        return { changed: false, activated: false, focused: None }
      }
      let edit = replace_current_selection(
        data.value.get(),
        element.caret,
        element.selection,
        text,
      )
      apply_multiline_text_edit(element, data, edit)
    }
    CompositionStart => {
      element.composition = Some("")
      element.selection = None
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionUpdate(update) => {
      element.composition = if update.text == "" {
        None
      } else {
        Some(update.text)
      }
      match update.cursor {
        Some(cursor) => {
          let normalized = cursor.normalized()
          let start = clamp_int(normalized.start, 0, text_length(update.text))
          let end = clamp_int(normalized.end, 0, text_length(update.text))
          element.selection = Some(TextRange::new(start~, end~))
        }
        None => ()
      }
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionEnd(text) => {
      element.composition = None
      element.selection = None
      if text == "" {
        element.dirty.mark_paint()
        { changed: true, activated: false, focused: None }
      } else {
        let edit = replace_current_selection(
          data.value.get(),
          element.caret,
          None,
          text,
        )
        apply_multiline_text_edit(element, data, edit)
      }
    }
    DeleteRange(range) => {
      let edit = replace_text_range(data.value.get(), range, "")
      apply_multiline_text_edit(element, data, edit)
    }
    DeleteSurrounding(before, after) => {
      let text = data.value.get()
      let range = surrounding_delete_range(text, element.caret, before, after)
      let edit = replace_text_range(text, range, "")
      apply_multiline_text_edit(element, data, edit)
    }
  }
}
