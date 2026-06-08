///|
priv struct TextEditResult {
  text : String
  caret : Int
  selection : TextRange?
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
  apply_text_edit_with_history(element, data, edit, record_history=true)
}

///|
fn apply_text_edit_with_history(
  element : ElementNode,
  data : TextFieldViewSpec,
  edit : TextEditResult,
  record_history~ : Bool,
) -> ElementEventResult {
  let previous = data.value.get()
  let previous_entry = TextHistoryEntry::from_element(previous, element)
  if edit.text != data.value.get() ||
    edit.caret != element.control.caret ||
    edit.selection != element.control.selection ||
    element.control.composition is Some(_) {
    if record_history {
      record_text_history(element, previous_entry, edit.text)
    }
    data.value.set(edit.text)
    element.control.caret = edit.caret
    element.control.selection = edit.selection
    element.control.composition = None
    element.control.composition_cursor = None
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
  let changed = element.control.caret != caret_move.caret ||
    element.control.selection != caret_move.selection ||
    element.control.composition is Some(_) ||
    element.control.composition_cursor is Some(_)
  if changed {
    element.control.caret = caret_move.caret
    element.control.selection = caret_move.selection
    element.control.composition = None
    element.control.composition_cursor = None
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
  apply_multiline_text_edit_with_history(
    element,
    data,
    edit,
    record_history=true,
  )
}

///|
fn apply_multiline_text_edit_with_history(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  edit : TextEditResult,
  record_history~ : Bool,
) -> ElementEventResult {
  let previous = data.value.get()
  let previous_entry = TextHistoryEntry::from_element(previous, element)
  if edit.text != data.value.get() ||
    edit.caret != element.control.caret ||
    edit.selection != element.control.selection ||
    element.control.composition is Some(_) ||
    element.control.composition_cursor is Some(_) {
    if record_history {
      record_text_history(element, previous_entry, edit.text)
    }
    data.value.set(edit.text)
    element.control.caret = edit.caret
    element.control.selection = edit.selection
    element.control.composition = None
    element.control.composition_cursor = None
    notify_rich_text_selection_change(data, element)
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
  apply_searchbar_edit_with_history(element, data, edit, record_history=true)
}

///|
fn apply_searchbar_edit_with_history(
  element : ElementNode,
  data : SearchBarViewSpec,
  edit : TextEditResult,
  record_history~ : Bool,
) -> ElementEventResult {
  let previous = data.query.get()
  let previous_entry = TextHistoryEntry::from_element(previous, element)
  if edit.text != data.query.get() ||
    edit.caret != element.control.caret ||
    edit.selection != element.control.selection ||
    element.control.composition is Some(_) ||
    element.control.composition_cursor is Some(_) {
    if record_history {
      record_text_history(element, previous_entry, edit.text)
    }
    data.query.set(edit.text)
    element.control.caret = edit.caret
    element.control.selection = edit.selection
    element.control.composition = None
    element.control.composition_cursor = None
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
  changed? : Bool = false,
  clipboard_text? : String? = None,
) -> TextCommandResult {
  { handled: true, changed, clipboard_text }
}

///|
fn record_text_history(
  element : ElementNode,
  previous : TextHistoryEntry,
  next : String,
) -> Unit {
  if previous.text != next {
    element.control.text_undo_stack.push(previous)
    element.control.text_redo_stack.clear()
  }
}

///|
fn selected_text(text : String, selection : TextRange?) -> String {
  match active_text_selection(selection) {
    Some(selection) => {
      let chars = text.to_array()
      let range = TextGraphemeBoundaries::new(text~).normalize_range(selection)
      let start = clamp_int(range.start, 0, chars.length())
      let end = clamp_int(range.end, start, chars.length())
      String::from_array(chars[start:end])
    }
    None => ""
  }
}

///|
fn selected_rich_text(
  text : String,
  document : RichTextDocument,
  selection : TextRange?,
) -> String {
  match active_text_selection(selection) {
    Some(selection) =>
      if rich_text_document_has_source_ranges(document) {
        selected_rich_text_document_text(document, selection)
      } else {
        selected_text(text, Some(selection))
      }
    None => ""
  }
}

///|
fn selected_rich_text_document_text(
  document : RichTextDocument,
  selection : TextRange,
) -> String {
  let lines : Array[String] = []
  for block in document.blocks {
    match selected_rich_text_block_text(block, selection) {
      Some(text) => lines.push(text)
      None => ()
    }
  }
  join_text_lines(lines)
}

///|
fn selected_rich_text_block_text(
  block : RichTextBlock,
  selection : TextRange,
) -> String? {
  match block.content_range {
    Some(content) =>
      if selection.end <= content.start || selection.start >= content.end {
        None
      } else {
        let start = clamp_int(selection.start, content.start, content.end)
        let end = clamp_int(selection.end, content.start, content.end)
        let text = selected_rich_text_runs_text(block, start, end)
        if text == "" && start != end {
          None
        } else {
          Some(text)
        }
      }
    None => None
  }
}

///|
fn selected_rich_text_runs_text(
  block : RichTextBlock,
  start : Int,
  end : Int,
) -> String {
  let parts : Array[String] = []
  for run in block.runs {
    match run.source_range {
      Some(range) =>
        if end > range.start && start < range.end {
          parts.push(
            rich_text_run_slice(
              run.text,
              clamp_int(start - range.start, 0, text_length(run.text)),
              clamp_int(end - range.start, 0, text_length(run.text)),
            ),
          )
        }
      None => ()
    }
  }
  join_text_lines(parts)
}

///|
fn rich_text_run_slice(text : String, start : Int, end : Int) -> String {
  let chars = text.to_array()
  let range = TextGraphemeBoundaries::new(text~).normalize_range(
    TextRange::new(start~, end~),
  )
  let start = clamp_int(range.start, 0, chars.length())
  let end = clamp_int(range.end, start, chars.length())
  String::from_array(chars[start:end])
}

///|
fn join_text_lines(lines : Array[String]) -> String {
  let chars : Array[Char] = []
  for index in 0..<lines.length() {
    if index > 0 {
      chars.push('\n')
    }
    chars.append(lines[index].to_array())
  }
  String::from_array(chars)
}

///|
fn restore_text_history(
  element : ElementNode,
  current : String,
  apply : (TextEditResult) -> ElementEventResult,
  undo~ : Bool,
) -> TextCommandResult {
  let source = if undo {
    element.control.text_undo_stack
  } else {
    element.control.text_redo_stack
  }
  if source.length() == 0 {
    return TextCommandResult::handled()
  }
  let restored = source[source.length() - 1]
  ignore(source.pop())
  let current_entry = TextHistoryEntry::from_element(current, element)
  let result = apply({
    text: restored.text,
    caret: restored.caret,
    selection: restored.selection,
  })
  if result.changed {
    if undo {
      element.control.text_redo_stack.push(current_entry)
    } else {
      element.control.text_undo_stack.push(current_entry)
    }
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
  let range = TextGraphemeBoundaries::new(text~).normalize_range(normalized)
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
fn normalize_text_range_to_grapheme(
  text : String,
  range : TextRange,
) -> TextRange {
  TextGraphemeBoundaries::new(text~).normalize_range(range)
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
  let boundaries = TextGraphemeBoundaries::new(text~)
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
        Some(TextRange::new(start=anchor, end=next))
      },
    }
  } else {
    match active_text_selection(selection) {
      Some(selection) => {
        let selection = boundaries.normalize_range(selection)
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
fn move_text_caret_index(
  text : String,
  caret : Int,
  direction : TextCaretDirection,
) -> Int {
  let length = text_length(text)
  let caret = clamp_int(caret, 0, length)
  match direction {
    MoveLeft => text_previous_grapheme_caret_boundary(text, caret)
    MoveRight => text_next_grapheme_caret_boundary(text, caret)
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
  let before = max_int(0, before)
  let after = max_int(0, after)
  let boundaries = TextGraphemeBoundaries::new(text~)
  let range = boundaries.delete_range(caret, before, after)
  TextRange::new(
    start=clamp_int(range.start, 0, length),
    end=clamp_int(range.end, 0, length),
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
    match element.control.composition {
      Some(composition) =>
        replace_current_selection(
          text,
          element.control.caret,
          element.control.selection,
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
  let caret = clamp_int(element.control.caret, 0, text_length(text))
  if !focused {
    caret
  } else {
    match element.control.composition {
      Some(composition) =>
        composition_start_index(
          text,
          element.control.caret,
          element.control.selection,
        ) +
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
    Some(selection) =>
      TextGraphemeBoundaries::new(text~).normalize_range(selection).start
    None => TextGraphemeBoundaries::new(text~).nearest_boundary(caret)
  }
}

///|
fn composition_cursor_offset(
  element : ElementNode,
  composition : String,
) -> Int {
  let length = text_length(composition)
  match element.control.composition_cursor {
    Some(cursor) => {
      let normalized = cursor.normalized()
      TextGraphemeBoundaries::new(text=composition).nearest_boundary(
        clamp_int(normalized.end, 0, length),
      )
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
  let current_start = multiline_line_start(text, element.control.caret)
  let current_end = multiline_line_end(text, element.control.caret)
  let column = element.control.caret - current_start
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
  element.control.caret = TextGraphemeBoundaries::new(text~).nearest_boundary(
    min_int(next_start + column, next_end),
  )
  element.control.selection = None
  element.control.composition = None
  element.control.composition_cursor = None
  notify_rich_text_selection_change(data, element)
  element.dirty.mark_paint()
  { changed: true, activated: false, focused: None }
}

///|
fn apply_rich_text_caret_move(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  caret_move : TextCaretMoveResult,
) -> ElementEventResult {
  let result = apply_text_caret_move(element, caret_move)
  if result.changed {
    notify_rich_text_selection_change(data, element)
  }
  result
}

///|
fn notify_rich_text_selection_change(
  data : RichTextEditorViewSpec,
  element : ElementNode,
) -> Unit {
  match data.on_selection_change {
    Some(handler) => handler(element.control.caret, element.control.selection)
    None => ()
  }
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
      match rich_text_transform_insert(data, element, text) {
        Some(edit) =>
          return apply_rich_text_input_transform(element, data, edit)
        None => ()
      }
      let edit = replace_current_selection(
        data.value.get(),
        element.control.caret,
        element.control.selection,
        text,
      )
      apply_multiline_text_edit(element, data, edit)
    }
    CompositionStart => {
      element.control.composition = Some("")
      element.control.composition_cursor = None
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionUpdate(update) => {
      element.control.composition = if update.text == "" {
        None
      } else {
        Some(update.text)
      }
      match update.cursor {
        Some(cursor) => {
          let normalized = normalize_text_range_to_grapheme(update.text, cursor)
          let length = text_length(update.text)
          let start = clamp_int(normalized.start, 0, length)
          let end = clamp_int(normalized.end, 0, length)
          element.control.composition_cursor = Some(
            TextRange::new(start~, end~),
          )
        }
        None => element.control.composition_cursor = None
      }
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionEnd(text) => {
      element.control.composition = None
      element.control.composition_cursor = None
      if text == "" {
        element.control.selection = None
        element.dirty.mark_paint()
        { changed: true, activated: false, focused: None }
      } else {
        let edit = replace_current_selection(
          data.value.get(),
          element.control.caret,
          element.control.selection,
          text,
        )
        apply_multiline_text_edit(element, data, edit)
      }
    }
    DeleteRange(range) => {
      match rich_text_transform_insert(data, element, "\u{000e}") {
        Some(edit) =>
          return apply_rich_text_input_transform(element, data, edit)
        None => ()
      }
      let edit = replace_text_range(data.value.get(), range, "")
      apply_multiline_text_edit(element, data, edit)
    }
    DeleteSurrounding(before, after) => {
      let text = data.value.get()
      let signal = if before > 0 && after == 0 {
        "\u{0008}"
      } else if before == 0 && after > 0 {
        "\u{007f}"
      } else {
        ""
      }
      if signal != "" {
        match rich_text_transform_insert(data, element, signal) {
          Some(edit) =>
            return apply_rich_text_input_transform(element, data, edit)
          None => ()
        }
      }
      let range = surrounding_delete_range(
        text,
        element.control.caret,
        before,
        after,
      )
      let edit = replace_text_range(text, range, "")
      apply_multiline_text_edit(element, data, edit)
    }
  }
}

///|
fn rich_text_transform_insert(
  data : RichTextEditorViewSpec,
  element : ElementNode,
  text : String,
) -> RichTextInputTransform? {
  match data.input_transform {
    Some(transform) =>
      transform(
        data.value.get(),
        element.control.caret,
        element.control.selection,
        text,
      )
    None => None
  }
}

///|
fn apply_rich_text_input_transform(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  edit : RichTextInputTransform,
) -> ElementEventResult {
  let previous = data.value.get()
  let previous_entry = TextHistoryEntry::from_element(previous, element)
  let changed = edit.text != data.value.get() ||
    edit.caret != element.control.caret ||
    edit.selection != element.control.selection ||
    element.control.composition is Some(_) ||
    element.control.composition_cursor is Some(_)
  if changed {
    record_text_history(element, previous_entry, edit.text)
    data.value.set(edit.text)
    element.control.caret = edit.caret
    element.control.selection = edit.selection
    element.control.composition = None
    element.control.composition_cursor = None
    notify_rich_text_selection_change(data, element)
    element.dirty.mark_paint()
    { changed: true, activated: false, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn ElementNode::dispatch_text_command(
  self : ElementNode,
  target : ElementId,
  intent : CommandIntent,
  paste_text? : String? = None,
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
        clipboard_text=Some(selected_text(text, element.control.selection)),
      )
    Cut => {
      let copied = selected_text(text, element.control.selection)
      match active_text_selection(element.control.selection) {
        Some(selection) => {
          let result = handle_text_field_input(
            element,
            data,
            DeleteRange(selection),
          )
          TextCommandResult::handled(
            changed=result.changed,
            clipboard_text=Some(copied),
          )
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
        edit => {
          apply_text_edit_with_history(
            element,
            data,
            edit,
            record_history=false,
          )
        },
        undo=true,
      )
    Redo =>
      restore_text_history(
        element,
        text,
        edit => {
          apply_text_edit_with_history(
            element,
            data,
            edit,
            record_history=false,
          )
        },
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
        clipboard_text=Some(selected_text(text, element.control.selection)),
      )
    Cut => {
      let copied = selected_text(text, element.control.selection)
      match active_text_selection(element.control.selection) {
        Some(selection) => {
          let result = handle_searchbar_input(
            element,
            data,
            DeleteRange(selection),
          )
          TextCommandResult::handled(
            changed=result.changed,
            clipboard_text=Some(copied),
          )
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
        edit => {
          apply_searchbar_edit_with_history(
            element,
            data,
            edit,
            record_history=false,
          )
        },
        undo=true,
      )
    Redo =>
      restore_text_history(
        element,
        text,
        edit => {
          apply_searchbar_edit_with_history(
            element,
            data,
            edit,
            record_history=false,
          )
        },
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
  let document = (data.format)(text)
  match intent {
    Copy =>
      TextCommandResult::handled(
        clipboard_text=Some(
          selected_rich_text(text, document, element.control.selection),
        ),
      )
    Cut => {
      let copied = selected_rich_text(text, document, element.control.selection)
      match active_text_selection(element.control.selection) {
        Some(selection) => {
          let result = handle_rich_text_editor_input(
            element,
            data,
            DeleteRange(selection),
          )
          TextCommandResult::handled(
            changed=result.changed,
            clipboard_text=Some(copied),
          )
        }
        None => TextCommandResult::handled(clipboard_text=Some(""))
      }
    }
    Paste =>
      match paste_text {
        Some(value) => {
          let result = handle_rich_text_editor_input(
            element,
            data,
            InsertText(value),
          )
          TextCommandResult::handled(changed=result.changed)
        }
        None => TextCommandResult::handled()
      }
    Undo =>
      restore_text_history(
        element,
        text,
        edit => {
          apply_multiline_text_edit_with_history(
            element,
            data,
            edit,
            record_history=false,
          )
        },
        undo=true,
      )
    Redo =>
      restore_text_history(
        element,
        text,
        edit => {
          apply_multiline_text_edit_with_history(
            element,
            data,
            edit,
            record_history=false,
          )
        },
        undo=false,
      )
    SelectAll => {
      let result = select_text_range(element, text)
      TextCommandResult::handled(changed=result.changed)
    }
    _ => TextCommandResult::ignored()
  }
}
