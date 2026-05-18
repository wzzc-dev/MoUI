///|
pub(all) enum TextInputSessionAction {
  NoImeChange
  EnableIme(@window_core.ImeRequest)
  UpdateIme(@window_core.ImeRequest)
  DisableIme(@window_core.ImeRequest)
} derive(Eq, Debug)

///|
pub(all) struct TextInputSession {
  mut enabled : Bool
}

///|
pub fn TextInputSession::new() -> TextInputSession {
  { enabled: false }
}

///|
pub fn TextInputSession::sync(
  self : TextInputSession,
  state : @core.TextInputState,
) -> TextInputSessionAction {
  if !state.focused {
    if self.enabled {
      self.enabled = false
      DisableIme(@window_core.ImeRequest::Disable)
    } else {
      NoImeChange
    }
  } else {
    let update = text_input_ime_request_data(state)
    let capabilities = text_input_ime_capabilities(update)
    if self.enabled {
      UpdateIme(update.into_request())
    } else {
      match @window_core.ImeEnableRequest::new(capabilities, update) {
        Some(request) => {
          self.enabled = true
          EnableIme(request.into_request())
        }
        None => NoImeChange
      }
    }
  }
}

///|
pub fn text_input_ime_request_data(
  state : @core.TextInputState,
) -> @window_core.ImeRequestData {
  let mut request = @window_core.ImeRequestData::default()
    .with_hint_and_purpose(
      @window_core.ImeHint::none(),
      @window_core.ImePurpose::Normal,
    )
    .with_cursor_area(
      @dpi.LogicalPosition::new(
        state.caret_rect.origin.x,
        state.caret_rect.origin.y,
      ).into_position(),
      @dpi.LogicalSize::new(
        max_double(1.0, state.caret_rect.size.width),
        max_double(1.0, state.caret_rect.size.height),
      ).into_size(),
    )
  match text_input_surrounding_text(state) {
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
) -> @window_core.ImeSurroundingText? {
  let caret = clamp_int(state.caret, 0, state.text.to_array().length())
  let chars = state.text.to_array()
  let before = String::from_array(chars[:caret])
  let cursor = @utf8.encode(before[:], bom=false).length()
  Some(@window_core.ImeSurroundingText::new(state.text, cursor, cursor)) catch {
    _ => None
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
fn clamp_int(value : Int, min_value : Int, max_value : Int) -> Int {
  if value < min_value {
    min_value
  } else if value > max_value {
    max_value
  } else {
    value
  }
}
