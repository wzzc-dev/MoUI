///|
pub fn EmbeddedImeRequest::from_state(
  revision~ : Int,
  state : @core.TextInputState,
) -> EmbeddedImeRequest {
  let diagnostics = text_input_ime_request_diagnostics(state)
  let selection = match state.selection {
    Some(selection) =>
      Some(
        embedded_runtime_text_range_to_utf16(state.text, selection.normalized()),
      )
    None => None
  }
  let composition_cursor = match (state.composition, state.composition_cursor) {
    (Some(composition), Some(cursor)) =>
      Some(embedded_runtime_text_range_to_utf16(composition, cursor))
    _ => None
  }
  {
    revision,
    enabled: state.focused,
    text: state.text,
    caret: embedded_runtime_char_index_to_utf16(state.text, diagnostics.cursor),
    selection,
    composition: state.composition,
    composition_cursor,
    frame: state.frame,
    candidate_anchor: diagnostics.candidate_anchor,
  }
}

///|
fn embedded_runtime_char_index_to_utf16(text : String, index : Int) -> Int {
  let length = text.char_length()
  let index = if index < 0 {
    0
  } else if index > length {
    length
  } else {
    index
  }
  if index == length {
    text.length()
  } else {
    text.offset_of_nth_char(index).unwrap_or(text.length())
  }
}

///|
fn embedded_runtime_utf16_to_char_index(
  text : String,
  offset : Int,
  round_up~ : Bool,
) -> Int {
  let utf16_length = text.length()
  let offset = if offset < 0 {
    0
  } else if offset > utf16_length {
    utf16_length
  } else {
    offset
  }
  let char_length = text.char_length()
  let mut index = 0
  while index < char_length {
    let next = embedded_runtime_char_index_to_utf16(text, index + 1)
    if next == offset {
      return index + 1
    }
    if next > offset {
      return if round_up { index + 1 } else { index }
    }
    index = index + 1
  }
  char_length
}

///|
fn embedded_runtime_text_range_to_utf16(
  text : String,
  range : @core.TextRange,
) -> @core.TextRange {
  @core.TextRange::new(
    start=embedded_runtime_char_index_to_utf16(text, range.start),
    end=embedded_runtime_char_index_to_utf16(text, range.end),
  )
}

///|
fn embedded_runtime_text_range_from_utf16(
  text : String,
  range : @core.TextRange,
) -> @core.TextRange {
  let normalized = range.normalized()
  @core.TextRange::new(
    start=embedded_runtime_utf16_to_char_index(
      text,
      normalized.start,
      round_up=false,
    ),
    end=embedded_runtime_utf16_to_char_index(
      text,
      normalized.end,
      round_up=true,
    ),
  )
}

///|
fn embedded_runtime_text_input_from_utf16(
  event : @core.TextInputEvent,
  state : @core.TextInputState,
) -> @core.TextInputEvent {
  match event {
    @core.TextInputEvent::ReplaceText(range, replacement) =>
      @core.TextInputEvent::ReplaceText(
        embedded_runtime_text_range_from_utf16(state.text, range),
        replacement,
      )
    @core.TextInputEvent::SetSelection(range) =>
      @core.TextInputEvent::SetSelection(
        embedded_runtime_text_range_from_utf16(state.text, range),
      )
    @core.TextInputEvent::DeleteRange(range) =>
      @core.TextInputEvent::DeleteRange(
        embedded_runtime_text_range_from_utf16(state.text, range),
      )
    @core.TextInputEvent::DeleteSurrounding(before, after) => {
      let caret_utf16 = embedded_runtime_char_index_to_utf16(
        state.text,
        state.caret,
      )
      @core.TextInputEvent::DeleteRange(
        embedded_runtime_text_range_from_utf16(
          state.text,
          @core.TextRange::new(
            start=caret_utf16 - before,
            end=caret_utf16 + after,
          ),
        ),
      )
    }
    @core.TextInputEvent::CompositionUpdate(update) => {
      let composition = update.text()
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(
          text=composition,
          cursor=match update.cursor() {
            Some(cursor) =>
              Some(embedded_runtime_text_range_from_utf16(composition, cursor))
            None => None
          },
        ),
      )
    }
    other => other
  }
}

///|
fn EmbeddedRuntimeHostBridge::sync_text_input(
  self : EmbeddedRuntimeHostBridge,
  state : @core.TextInputState,
) -> Unit {
  if self.last_text_input != Some(state) {
    self.ime_revision = self.ime_revision + 1
    self.last_text_input = Some(state)
    self.updates.push(
      EmbeddedHostUpdate::Ime(
        EmbeddedImeRequest::from_state(revision=self.ime_revision, state),
      ),
    )
  }
}
