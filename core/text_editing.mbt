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
fn text_length(text : String) -> Int {
  text.to_array().length()
}

