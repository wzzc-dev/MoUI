///|
fn handle_searchbar_input(
  element : ElementNode,
  data : SearchBarViewSpec,
  event : TextInputEvent,
) -> ElementEventResult {
  match event {
    InsertText(text) => {
      if text == "" {
        return { changed: false, activated: false, focused: None }
      }
      let edit = replace_current_selection(
        data.query.get(),
        element.control.caret,
        element.control.selection,
        text,
      )
      apply_searchbar_edit(element, data, edit)
    }
    CompositionStart => {
      element.control.composition = Some("")
      element.control.composition_cursor = None
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionUpdate(update) => {
      element.control.composition = if update.text() == "" {
        None
      } else {
        Some(update.text())
      }
      match update.cursor() {
        Some(cursor) => {
          let normalized = normalize_text_range_to_grapheme(
            update.text(),
            cursor,
          )
          let length = text_length(update.text())
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
          data.query.get(),
          element.control.caret,
          element.control.selection,
          text,
        )
        apply_searchbar_edit(element, data, edit)
      }
    }
    DeleteRange(range) => {
      let edit = replace_text_range(data.query.get(), range, "")
      apply_searchbar_edit(element, data, edit)
    }
    DeleteSurrounding(before, after) => {
      let text = data.query.get()
      let range = surrounding_delete_range(
        text,
        element.control.caret,
        before,
        after,
      )
      let edit = replace_text_range(text, range, "")
      apply_searchbar_edit(element, data, edit)
    }
  }
}

///|
fn handle_text_field_input(
  element : ElementNode,
  data : TextFieldViewSpec,
  event : TextInputEvent,
) -> ElementEventResult {
  match event {
    InsertText(text) => {
      if text == "" {
        return { changed: false, activated: false, focused: None }
      }
      let edit = replace_current_selection(
        data.value.get(),
        element.control.caret,
        element.control.selection,
        text,
      )
      apply_text_edit(element, data, edit)
    }
    CompositionStart => {
      element.control.composition = Some("")
      element.control.composition_cursor = None
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionUpdate(update) => {
      element.control.composition = if update.text() == "" {
        None
      } else {
        Some(update.text())
      }
      match update.cursor() {
        Some(cursor) => {
          let normalized = normalize_text_range_to_grapheme(
            update.text(),
            cursor,
          )
          let length = text_length(update.text())
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
        apply_text_edit(element, data, edit)
      }
    }
    DeleteRange(range) => {
      let edit = replace_text_range(data.value.get(), range, "")
      apply_text_edit(element, data, edit)
    }
    DeleteSurrounding(before, after) => {
      let text = data.value.get()
      let range = surrounding_delete_range(
        text,
        element.control.caret,
        before,
        after,
      )
      let edit = replace_text_range(text, range, "")
      apply_text_edit(element, data, edit)
    }
  }
}
