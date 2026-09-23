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
  // The text the IME request delivers as surrounding text. `None` on the
  // exact path, where the whole input text already fits the surrounding
  // text budget; oversized texts deliver a bounded window around the
  // cursor instead (see `text_input_ime_request_diagnostics_windowed`).
  surrounding_text : String?
} derive(Eq, Debug, ToJson)

///|
/// Identity of the text-input state the cached IME diagnostics describe.
/// The text is compared by object identity (`physical_equal`), never by
/// value: the runtime's input text is an immutable string, so an
/// unchanged frame re-observes the same object while every edit
/// materializes a new one. A content comparison here would itself scan
/// megabytes on every frame.
pub struct TextInputImeStateKey {
  focused : Bool
  text : String
  caret : Int
  selection : @core.TextRange?
  composition : String?
  composition_cursor : @core.TextRange?
  caret_rect : @core.Rect
}

///|
fn TextInputImeStateKey::matches(
  self : TextInputImeStateKey,
  other : TextInputImeStateKey,
) -> Bool {
  self.focused == other.focused &&
  physical_equal(self.text, other.text) &&
  self.caret == other.caret &&
  self.selection == other.selection &&
  self.composition == other.composition &&
  self.composition_cursor == other.composition_cursor &&
  self.caret_rect == other.caret_rect
}

///|
fn text_input_ime_state_key(
  state : @core.TextInputState,
) -> TextInputImeStateKey {
  {
    focused: state.focused,
    text: state.text,
    caret: state.caret,
    selection: state.selection,
    composition: state.composition,
    composition_cursor: state.composition_cursor,
    caret_rect: state.caret_rect,
  }
}

///|
pub(all) struct TextInputSession {
  mut enabled : Bool
  mut last_request : @window_core.ImeRequestData?
  mut last_capabilities : @window_core.ImeCapabilities?
  mut last_diagnostics : TextInputImeRequestDiagnostics?
  mut last_state : TextInputImeStateKey?
}

///|
pub fn TextInputSession::new() -> TextInputSession {
  {
    enabled: false,
    last_request: None,
    last_capabilities: None,
    last_diagnostics: None,
    last_state: None,
  }
}

///|
/// Diagnostics for `state`, reused from the previous sync while the
/// focused text input is unchanged. The window redraw loop re-syncs on
/// every presented frame; without this reuse every frame paid the full
/// grapheme/UTF-8 diagnostics even though nothing had changed. Recompute
/// is still bounded for oversized texts (see
/// `text_input_ime_request_diagnostics_windowed`), so an edit on a
/// multi-megabyte input never rebuilds a whole-document boundary table.
fn TextInputSession::diagnostics_for(
  self : TextInputSession,
  state : @core.TextInputState,
) -> TextInputImeRequestDiagnostics {
  let current = text_input_ime_state_key(state)
  match (self.last_state, self.last_diagnostics) {
    (Some(cached), Some(diagnostics)) if cached.matches(current) => diagnostics
    _ => {
      let diagnostics = text_input_ime_request_diagnostics(state)
      self.last_state = Some(current)
      self.last_diagnostics = Some(diagnostics)
      diagnostics
    }
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
      DisableIme(Disable)
    } else {
      self.clear_cached_request()
      NoImeChange
    }
  } else {
    let diagnostics = self.diagnostics_for(state)
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
  self.last_state = None
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
  // UTF-8 byte length is at least the UTF-16 code-unit count, so a text
  // beyond the surrounding-text budget can never be delivered in full.
  // Whole-document diagnostics would build a per-codepoint boundary table
  // and re-encode multi-megabyte prefixes per frame; oversized texts get
  // caret-local grapheme context and a truncated surrounding-text window
  // instead.
  if state.text.length() > @window_core.ImeSurroundingText::max_text_bytes() {
    return text_input_ime_request_diagnostics_windowed(state)
  }
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
    cursor_utf8: boundaries.nearest_boundary_utf8_offset(cursor),
    anchor_utf8: boundaries.nearest_boundary_utf8_offset(anchor),
    cursor_is_grapheme_boundary: boundaries.is_boundary(cursor),
    anchor_is_grapheme_boundary: boundaries.is_boundary(anchor),
    candidate_anchor: text_input_candidate_anchor_rect(state),
    has_surrounding_text: text_utf8_length <=
    @window_core.ImeSurroundingText::max_text_bytes(),
    surrounding_text_utf8_length: text_utf8_length,
    surrounding_text: None,
  }
}

///|
/// Half-width of the oversized-text diagnostics window, in codepoints.
/// Every practical grapheme cluster (emoji ZWJ chains, regional-indicator
/// runs, Indic conjuncts) fits far inside this radius, so boundaries at
/// the caret and anchor match the whole-text table.
const TEXT_INPUT_IME_WINDOW_CHARS : Int = 128

///|
/// A bounded, grapheme-snapped slice of the input text around one offset.
/// `boundaries` index codepoints relative to `start`; `utf8` offsets
/// computed from them index `text` bytes.
priv struct TextInputImeWindow {
  text : String
  boundaries : @core.TextGraphemeBoundaries
  start : Int
  utf8_length : Int
}

///|
/// Build the diagnostics window for `center` (a codepoint index). The
/// window edges are located with one scan that stops at the window end,
/// so carets near the document start never walk the whole text; the
/// slice itself is at most a few hundred bytes.
fn text_input_ime_window(text : String, center : Int) -> TextInputImeWindow {
  let start_char = (center - TEXT_INPUT_IME_WINDOW_CHARS).max(0)
  let end_char = center + TEXT_INPUT_IME_WINDOW_CHARS
  let mut char_index = 0
  let mut unit_offset = 0
  let mut start_unit = 0
  let mut start_found = start_char == 0
  let mut end_unit = 0
  let mut end_found = false
  for ch in text {
    if !start_found && char_index == start_char {
      start_unit = unit_offset
      start_found = true
    }
    if char_index >= end_char {
      end_unit = unit_offset
      end_found = true
      break
    }
    unit_offset = unit_offset + ch.utf16_len()
    char_index = char_index + 1
  }
  if !end_found {
    end_unit = unit_offset
  }
  let text = if start_found {
    text.exact_view(start=start_unit, end=end_unit).to_owned()
  } else {
    // Defensive: the center is at or past the text end (carets are
    // clamped by the runtime), so the window collapses to an empty slice.
    ""
  }
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let utf8_length = boundaries.utf8_offset(boundaries.length())
  {
    text,
    boundaries,
    start: if start_found {
      start_char
    } else {
      char_index
    },
    utf8_length,
  }
}

///|
/// Nearest grapheme boundary to `offset` (a text-relative codepoint
/// index) inside `window`; returns the text-relative position.
fn text_input_ime_window_boundary(
  window : TextInputImeWindow,
  offset : Int,
) -> Int {
  let window_local = (offset - window.start)
    .max(0)
    .min(window.boundaries.length())
  window.start + window.boundaries.nearest_boundary(window_local)
}

///|
fn text_input_ime_request_diagnostics_windowed(
  state : @core.TextInputState,
) -> TextInputImeRequestDiagnostics {
  let anchor = text_input_selection_anchor(state)
  let caret_window = text_input_ime_window(state.text, state.caret)
  // The anchor shares the caret window while it stays inside it (the
  // typing case); a distant selection anchor gets its own window.
  let anchor_window = if anchor >= caret_window.start &&
    anchor <= caret_window.start + caret_window.boundaries.length() {
    caret_window
  } else {
    text_input_ime_window(state.text, anchor)
  }
  let cursor = text_input_ime_window_boundary(caret_window, state.caret)
  let anchor_position = text_input_ime_window_boundary(anchor_window, anchor)
  let cursor_window_offset = cursor - caret_window.start
  let cursor_utf8 = caret_window.boundaries.utf8_offset(cursor_window_offset)
  let anchor_window_offset = anchor_position - anchor_window.start
  let anchor_utf8 = anchor_window.boundaries.utf8_offset(anchor_window_offset)
  {
    focused: state.focused,
    // Oversized texts report the UTF-16 code-unit count here; the exact
    // codepoint count would cost an O(document) decode and nothing on
    // this path reads it.
    text_length: state.text.length(),
    text_utf8_length: 0,
    cursor,
    anchor: anchor_position,
    cursor_utf8,
    anchor_utf8,
    cursor_is_grapheme_boundary: caret_window.boundaries.is_boundary(
      cursor_window_offset,
    ),
    anchor_is_grapheme_boundary: anchor_window.boundaries.is_boundary(
      anchor_window_offset,
    ),
    candidate_anchor: text_input_candidate_anchor_rect(state),
    has_surrounding_text: caret_window.utf8_length <=
    @window_core.ImeSurroundingText::max_text_bytes(),
    surrounding_text_utf8_length: caret_window.utf8_length,
    surrounding_text: Some(caret_window.text),
  }
}

///|
fn text_input_ime_request_data_with_diagnostics(
  state : @core.TextInputState,
  diagnostics : TextInputImeRequestDiagnostics,
) -> @window_core.ImeRequestData {
  let mut request = @window_core.ImeRequestData::default()
    .with_hint_and_purpose(@window_core.ImeHint::none(), Normal)
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
  // Oversized texts deliver the truncated window the diagnostics built;
  // its UTF-8 offsets already index the window.
  let text = match diagnostics.surrounding_text {
    Some(window) => window
    None => state.text
  }
  Some(
    ImeSurroundingText(text, diagnostics.cursor_utf8, diagnostics.anchor_utf8),
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
