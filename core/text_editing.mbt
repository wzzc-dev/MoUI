///|
priv struct TextEditResult {
  text : String
  caret : Int
}

///|
pub(all) struct TextCommandResult {
  handled : Bool
  changed : Bool
  clipboard_text : String?
} derive(Eq, Debug, ToJson)

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
  selection : TextRange?
}

///|
fn apply_text_edit(
  element : ElementNode,
  data : TextFieldViewSpec,
  edit : TextEditResult,
) -> ElementEventResult {
  let previous = data.value.get()
  if edit.text != data.value.get() ||
    edit.caret != element.caret ||
    element.selection is Some(_) ||
    element.composition is Some(_) {
    record_text_history(element, previous, edit.text)
    data.value.set(edit.text)
    element.caret = edit.caret
    element.selection = None
    element.composition = None
    element.composition_cursor = None
    element.dirty.mark_paint()
    { changed: true, activated: false, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn apply_text_caret_move(
  element : ElementNode,
  caret_move : TextCaretMoveResult,
) -> ElementEventResult {
  let changed = element.caret != caret_move.caret ||
    element.selection != caret_move.selection ||
    element.composition is Some(_) ||
    element.composition_cursor is Some(_)
  if changed {
    element.caret = caret_move.caret
    element.selection = caret_move.selection
    element.composition = None
    element.composition_cursor = None
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
  let previous = data.value.get()
  if edit.text != data.value.get() ||
    edit.caret != element.caret ||
    element.selection is Some(_) ||
    element.composition is Some(_) ||
    element.composition_cursor is Some(_) {
    record_text_history(element, previous, edit.text)
    data.value.set(edit.text)
    element.caret = edit.caret
    element.selection = None
    element.composition = None
    element.composition_cursor = None
    element.dirty.mark_paint()
    { changed: true, activated: false, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn apply_searchbar_edit(
  element : ElementNode,
  data : SearchBarViewSpec,
  edit : TextEditResult,
) -> ElementEventResult {
  let previous = data.query.get()
  if edit.text != data.query.get() ||
    edit.caret != element.caret ||
    element.selection is Some(_) ||
    element.composition is Some(_) ||
    element.composition_cursor is Some(_) {
    record_text_history(element, previous, edit.text)
    data.query.set(edit.text)
    element.caret = edit.caret
    element.selection = None
    element.composition = None
    element.composition_cursor = None
    element.dirty.mark_paint()
    { changed: true, activated: false, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn TextCommandResult::ignored() -> TextCommandResult {
  { handled: false, changed: false, clipboard_text: None }
}

///|
fn TextCommandResult::handled(
  changed~ : Bool = false,
  clipboard_text? : String? = None,
) -> TextCommandResult {
  { handled: true, changed, clipboard_text }
}

///|
fn record_text_history(
  element : ElementNode,
  previous : String,
  next : String,
) -> Unit {
  if previous != next {
    element.text_undo_stack.push(previous)
    element.text_redo_stack.clear()
  }
}

///|
fn selected_text(text : String, selection : TextRange?) -> String {
  match active_text_selection(selection) {
    Some(selection) => {
      let chars = text.to_array()
      let start = clamp_int(selection.start, 0, chars.length())
      let end = clamp_int(selection.end, start, chars.length())
      String::from_array(chars[start:end])
    }
    None => ""
  }
}

///|
fn restore_text_history(
  element : ElementNode,
  current : String,
  apply : (TextEditResult) -> ElementEventResult,
  undo~ : Bool,
) -> TextCommandResult {
  let source = if undo { element.text_undo_stack } else { element.text_redo_stack }
  if source.length() == 0 {
    return TextCommandResult::handled()
  }
  let restored = source[source.length() - 1]
  ignore(source.pop())
  let result = apply({ text: restored, caret: text_length(restored) })
  if undo && result.changed {
    element.text_redo_stack.push(current)
  }
  TextCommandResult::handled(changed=result.changed)
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
fn active_text_selection(selection : TextRange?) -> TextRange? {
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
fn text_selection_anchor(caret : Int, selection : TextRange?) -> Int {
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
fn move_text_caret(
  text : String,
  caret : Int,
  selection : TextRange?,
  direction : TextCaretDirection,
  extend~ : Bool,
) -> TextCaretMoveResult {
  let length = text_length(text)
  let caret = clamp_int(caret, 0, length)
  if extend {
    let anchor = clamp_int(text_selection_anchor(caret, selection), 0, length)
    let next = move_text_caret_index(caret, length, direction)
    {
      caret: next,
      selection: if next == anchor {
        None
      } else {
        Some(TextRange::new(start=anchor, end=next))
      },
    }
  } else {
    match active_text_selection(selection) {
      Some(selection) =>
        match direction {
          MoveLeft => { caret: selection.start, selection: None }
          MoveRight => { caret: selection.end, selection: None }
          MoveStart => { caret: 0, selection: None }
          MoveEnd => { caret: length, selection: None }
        }
      None =>
        {
          caret: move_text_caret_index(caret, length, direction),
          selection: None,
        }
    }
  }
}

///|
fn move_text_caret_index(
  caret : Int,
  length : Int,
  direction : TextCaretDirection,
) -> Int {
  match direction {
    MoveLeft => clamp_int(caret - 1, 0, length)
    MoveRight => clamp_int(caret + 1, 0, length)
    MoveStart => 0
    MoveEnd => length
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
        replace_current_selection(
          text,
          element.caret,
          element.selection,
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
        composition_start_index(text, element.caret, element.selection) +
        composition_cursor_offset(element, composition)
      None => caret
    }
  }
}

///|
fn composition_start_index(
  text : String,
  caret : Int,
  selection : TextRange?,
) -> Int {
  match active_text_selection(selection) {
    Some(selection) => selection.start
    None => clamp_int(caret, 0, text_length(text))
  }
}

///|
fn composition_cursor_offset(
  element : ElementNode,
  composition : String,
) -> Int {
  let length = text_length(composition)
  match element.composition_cursor {
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
  element.composition = None
  element.composition_cursor = None
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
      element.composition_cursor = None
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
          element.composition_cursor = Some(TextRange::new(start~, end~))
        }
        None => element.composition_cursor = None
      }
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionEnd(text) => {
      element.composition = None
      element.composition_cursor = None
      if text == "" {
        element.selection = None
        element.dirty.mark_paint()
        { changed: true, activated: false, focused: None }
      } else {
        let edit = replace_current_selection(
          data.value.get(),
          element.caret,
          element.selection,
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

///|
fn ElementNode::dispatch_text_command(
  self : ElementNode,
  target : ElementId,
  intent : CommandIntent,
  paste_text~ : String? = None,
) -> TextCommandResult {
  if self.spec is ModifiedSpec({ modifier: DisabledModifier(true), .. }) {
    return TextCommandResult::ignored()
  }
  if self.id == target {
    match self.spec {
      TextFieldSpec(data) =>
        handle_text_field_command(self, data, intent, paste_text~)
      SearchBarSpec(data) =>
        handle_searchbar_command(self, data, intent, paste_text~)
      RichTextEditorSpec(data) =>
        handle_rich_text_editor_command(self, data, intent, paste_text~)
      _ => TextCommandResult::ignored()
    }
  } else {
    for child in self.children {
      let result = child.dispatch_text_command(target, intent, paste_text~)
      if result.handled {
        if result.changed {
          self.dirty.mark_paint()
        }
        return result
      }
    }
    TextCommandResult::ignored()
  }
}

///|
fn handle_text_field_command(
  element : ElementNode,
  data : TextFieldViewSpec,
  intent : CommandIntent,
  paste_text~ : String?,
) -> TextCommandResult {
  let text = data.value.get()
  match intent {
    Copy =>
      TextCommandResult::handled(
        clipboard_text=Some(selected_text(text, element.selection)),
      )
    Cut => {
      let copied = selected_text(text, element.selection)
      match active_text_selection(element.selection) {
        Some(selection) => {
          let result = handle_text_field_input(element, data, DeleteRange(selection))
          TextCommandResult::handled(changed=result.changed, clipboard_text=Some(copied))
        }
        None => TextCommandResult::handled(clipboard_text=Some(""))
      }
    }
    Paste =>
      match paste_text {
        Some(value) => {
          let result = handle_text_field_input(element, data, InsertText(value))
          TextCommandResult::handled(changed=result.changed)
        }
        None => TextCommandResult::handled()
      }
    Undo =>
      restore_text_history(
        element,
        text,
        edit => apply_text_edit(element, data, edit),
        undo=true,
      )
    Redo =>
      restore_text_history(
        element,
        text,
        edit => apply_text_edit(element, data, edit),
        undo=false,
      )
    SelectAll => {
      let result = select_text_range(element, text)
      TextCommandResult::handled(changed=result.changed)
    }
    _ => TextCommandResult::ignored()
  }
}

///|
fn handle_searchbar_command(
  element : ElementNode,
  data : SearchBarViewSpec,
  intent : CommandIntent,
  paste_text~ : String?,
) -> TextCommandResult {
  let text = data.query.get()
  match intent {
    Copy =>
      TextCommandResult::handled(
        clipboard_text=Some(selected_text(text, element.selection)),
      )
    Cut => {
      let copied = selected_text(text, element.selection)
      match active_text_selection(element.selection) {
        Some(selection) => {
          let result = handle_searchbar_input(element, data, DeleteRange(selection))
          TextCommandResult::handled(changed=result.changed, clipboard_text=Some(copied))
        }
        None => TextCommandResult::handled(clipboard_text=Some(""))
      }
    }
    Paste =>
      match paste_text {
        Some(value) => {
          let result = handle_searchbar_input(element, data, InsertText(value))
          TextCommandResult::handled(changed=result.changed)
        }
        None => TextCommandResult::handled()
      }
    Undo =>
      restore_text_history(
        element,
        text,
        edit => apply_searchbar_edit(element, data, edit),
        undo=true,
      )
    Redo =>
      restore_text_history(
        element,
        text,
        edit => apply_searchbar_edit(element, data, edit),
        undo=false,
      )
    SelectAll => {
      let result = select_text_range(element, text)
      TextCommandResult::handled(changed=result.changed)
    }
    _ => TextCommandResult::ignored()
  }
}

///|
fn handle_rich_text_editor_command(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  intent : CommandIntent,
  paste_text~ : String?,
) -> TextCommandResult {
  let text = data.value.get()
  match intent {
    Copy =>
      TextCommandResult::handled(
        clipboard_text=Some(selected_text(text, element.selection)),
      )
    Cut => {
      let copied = selected_text(text, element.selection)
      match active_text_selection(element.selection) {
        Some(selection) => {
          let result = handle_rich_text_editor_input(
            element,
            data,
            DeleteRange(selection),
          )
          TextCommandResult::handled(changed=result.changed, clipboard_text=Some(copied))
        }
        None => TextCommandResult::handled(clipboard_text=Some(""))
      }
    }
    Paste =>
      match paste_text {
        Some(value) => {
          let result = handle_rich_text_editor_input(element, data, InsertText(value))
          TextCommandResult::handled(changed=result.changed)
        }
        None => TextCommandResult::handled()
      }
    Undo =>
      restore_text_history(
        element,
        text,
        edit => apply_multiline_text_edit(element, data, edit),
        undo=true,
      )
    Redo =>
      restore_text_history(
        element,
        text,
        edit => apply_multiline_text_edit(element, data, edit),
        undo=false,
      )
    SelectAll => {
      let result = select_text_range(element, text)
      TextCommandResult::handled(changed=result.changed)
    }
    _ => TextCommandResult::ignored()
  }
}
