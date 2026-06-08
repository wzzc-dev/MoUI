///|
pub(all) enum TextInputSessionAction {
  NoImeChange
  EnableIme(@window_core.ImeRequest)
  UpdateIme(@window_core.ImeRequest)
  DisableIme(@window_core.ImeRequest)
} derive(Eq, Debug)

///|
pub(all) struct TextInputImeRequestDiagnostics {
  focused : Bool
  text_length : Int
  text_utf8_length : Int
  cursor : Int
  anchor : Int
  cursor_utf8 : Int
  anchor_utf8 : Int
  cursor_is_grapheme_boundary : Bool
  anchor_is_grapheme_boundary : Bool
  candidate_anchor : @core.Rect
  has_surrounding_text : Bool
  surrounding_text_utf8_length : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextInputSession {
  mut enabled : Bool
  mut last_request : @window_core.ImeRequestData?
  mut last_capabilities : @window_core.ImeCapabilities?
  mut last_diagnostics : TextInputImeRequestDiagnostics?
}

///|
pub fn TextInputSession::new() -> TextInputSession {
  {
    enabled: false,
    last_request: None,
    last_capabilities: None,
    last_diagnostics: None,
  }
}

///|
pub fn TextInputSession::sync(
  self : TextInputSession,
  state : @core.TextInputState,
) -> TextInputSessionAction {
  if !state.focused {
    if self.enabled {
      self.enabled = false
      self.clear_cached_request()
      DisableIme(@window_core.ImeRequest::Disable)
    } else {
      self.clear_cached_request()
      NoImeChange
    }
  } else {
    let diagnostics = text_input_ime_request_diagnostics(state)
    let update = text_input_ime_request_data_with_diagnostics(
      state, diagnostics,
    )
    let capabilities = text_input_ime_capabilities(update)
    if self.enabled {
      if self.has_cached_request(update, capabilities) {
        NoImeChange
      } else {
        self.cache_request(update, capabilities, diagnostics)
        UpdateIme(update.into_request())
      }
    } else {
      match
        @window_core.ImeEnableRequest::from_capabilities(capabilities, update) {
        Some(request) => {
          self.enabled = true
          self.cache_request(update, capabilities, diagnostics)
          EnableIme(request.into_request())
        }
        None => {
          self.clear_cached_request()
          NoImeChange
        }
      }
    }
  }
}

///|
fn TextInputSession::has_cached_request(
  self : TextInputSession,
  request : @window_core.ImeRequestData,
  capabilities : @window_core.ImeCapabilities,
) -> Bool {
  self.last_request == Some(request) &&
  self.last_capabilities == Some(capabilities)
}

///|
fn TextInputSession::cache_request(
  self : TextInputSession,
  request : @window_core.ImeRequestData,
  capabilities : @window_core.ImeCapabilities,
  diagnostics : TextInputImeRequestDiagnostics,
) -> Unit {
  self.last_request = Some(request)
  self.last_capabilities = Some(capabilities)
  self.last_diagnostics = Some(diagnostics)
}

///|
fn TextInputSession::clear_cached_request(self : TextInputSession) -> Unit {
  self.last_request = None
  self.last_capabilities = None
  self.last_diagnostics = None
}

///|
pub fn TextInputSession::last_diagnostics(
  self : TextInputSession,
) -> TextInputImeRequestDiagnostics? {
  self.last_diagnostics
}

///|
pub fn text_input_ime_request_data(
  state : @core.TextInputState,
) -> @window_core.ImeRequestData {
  text_input_ime_request_data_with_diagnostics(
    state,
    text_input_ime_request_diagnostics(state),
  )
}

///|
pub fn text_input_ime_request_diagnostics(
  state : @core.TextInputState,
) -> TextInputImeRequestDiagnostics {
  let boundaries = @core.TextGraphemeBoundaries::new(text=state.text)
  let cursor = boundaries.nearest_boundary(state.caret)
  let anchor = boundaries.nearest_boundary(text_input_selection_anchor(state))
  let text_length = boundaries.length()
  let text_utf8_length = boundaries.utf8_offset(text_length)
  {
    focused: state.focused,
    text_length,
    text_utf8_length,
    cursor,
    anchor,
    cursor_utf8: boundaries.utf8_offset(cursor),
    anchor_utf8: boundaries.utf8_offset(anchor),
    cursor_is_grapheme_boundary: boundaries.is_boundary(cursor),
    anchor_is_grapheme_boundary: boundaries.is_boundary(anchor),
    candidate_anchor: text_input_candidate_anchor_rect(state),
    has_surrounding_text: text_utf8_length <=
    @window_core.ImeSurroundingText::max_text_bytes(),
    surrounding_text_utf8_length: text_utf8_length,
  }
}

///|
fn text_input_ime_request_data_with_diagnostics(
  state : @core.TextInputState,
  diagnostics : TextInputImeRequestDiagnostics,
) -> @window_core.ImeRequestData {
  let mut request = @window_core.ImeRequestData::default()
    .with_hint_and_purpose(
      @window_core.ImeHint::none(),
      @window_core.ImePurpose::Normal,
    )
    .with_cursor_area(
      @dpi.LogicalPosition::LogicalPosition(
        diagnostics.candidate_anchor.origin.x,
        diagnostics.candidate_anchor.origin.y,
      ).into_position(),
      @dpi.LogicalSize::LogicalSize(
        diagnostics.candidate_anchor.size.width,
        diagnostics.candidate_anchor.size.height,
      ).into_size(),
    )
  match text_input_surrounding_text(state, diagnostics) {
    Some(surrounding) => request = request.with_surrounding_text(surrounding)
    None => ()
  }
  request
}

///|
fn text_input_ime_capabilities(
  request_data : @window_core.ImeRequestData,
) -> @window_core.ImeCapabilities {
  let mut capabilities = @window_core.ImeCapabilities::default()
    .with_hint_and_purpose()
    .with_cursor_area()
  if request_data.has_surrounding_text() {
    capabilities = capabilities.with_surrounding_text()
  }
  capabilities
}

///|
fn text_input_surrounding_text(
  state : @core.TextInputState,
  diagnostics : TextInputImeRequestDiagnostics,
) -> @window_core.ImeSurroundingText? {
  Some(
    @window_core.ImeSurroundingText::ImeSurroundingText(
      state.text,
      diagnostics.cursor_utf8,
      diagnostics.anchor_utf8,
    ),
  ) catch {
    _ => None
  }
}

///|
fn text_input_selection_anchor(state : @core.TextInputState) -> Int {
  match state.selection {
    Some(selection) =>
      if state.caret == selection.start {
        selection.end
      } else {
        selection.start
      }
    None => state.caret
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn text_input_candidate_anchor_rect(state : @core.TextInputState) -> @core.Rect {
  @core.Rect::new(
    x=state.caret_rect.origin.x,
    y=state.caret_rect.origin.y,
    width=max_double(1.0, state.caret_rect.size.width),
    height=max_double(1.0, state.caret_rect.size.height),
  )
}
