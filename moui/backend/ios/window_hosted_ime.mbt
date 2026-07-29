///|
/// Window-hosted iOS IME bridge.
///
/// The MoUI runtime owns the IME state machine (`AppRuntime::focused_text_input`
/// -> `TextInputState`). Whenever the runtime's focused text state changes, the
/// backend forwards it to the native UIKit layer via `mbw_ios_ime_set_state`.
/// UIKit drives the system keyboard through a hidden UITextView and sends the
/// user's typing back through `mbw_ios_host_on_ime_event`, which is drained by
/// `window/ios/host_ffi.mbt` and re-enters the runtime as `WindowEvent::Ime`.
///
/// This file owns the **runtime -> host** direction only; the reverse direction
/// lives entirely in `window/ios/host_queue.mbt` / `host_ffi.mbt`.

///|
#borrow(text)
extern "C" fn mbw_ios_ime_set_state(
  enabled : Int,
  text : Bytes,
  sel_location : Int,
  sel_length : Int,
  caret_x : Double,
  caret_y : Double,
  caret_w : Double,
  caret_h : Double,
) -> Unit = "mbw_ios_ime_set_state"

///|
extern "C" fn mbw_ios_ime_reset() -> Unit = "mbw_ios_ime_reset"

///|
/// Compare the previous focused text input snapshot with the latest state and
/// forward any difference to the native UIKit responder.
pub struct IosImeSink {
  priv mut last_enabled : Bool
  priv mut last_text : String
  priv mut last_selection : @core.TextRange?
  priv mut last_rect : @core.Rect?
}

///|
pub fn IosImeSink::new() -> IosImeSink {
  { last_enabled: false, last_text: "", last_selection: None, last_rect: None }
}

///|
/// Apply the runtime's current focused text input state. Safe to call on
/// every pump; only dispatches a native call when state meaningfully changes.
pub fn IosImeSink::apply(
  self : IosImeSink,
  state : @core.TextInputState,
) -> Unit {
  if !state.focused {
    if self.last_enabled {
      mbw_ios_ime_reset()
      self.last_enabled = false
      self.last_text = ""
      self.last_selection = None
      self.last_rect = None
    }
    return
  }
  let text = state.text
  let selection : @core.TextRange? = state.selection
  let caret : @core.Rect = if state.caret_rect.size.width > 0.0 ||
    state.caret_rect.size.height > 0.0 {
    state.caret_rect
  } else {
    state.frame
  }
  let changed = self.last_enabled != true ||
    self.last_text != text ||
    self.last_selection != selection ||
    self.last_rect.unwrap_or(default_rect()) != caret
  if changed {
    let (sel_start, sel_len) = match selection {
      Some(r) => (r.start, r.end - r.start)
      None => (state.caret, 0)
    }
    mbw_ios_ime_set_state(
      1,
      @utf8.encode(text),
      sel_start,
      sel_len,
      caret.origin.x,
      caret.origin.y,
      caret.size.width,
      caret.size.height,
    )
    self.last_enabled = true
    self.last_text = text
    self.last_selection = selection
    self.last_rect = Some(caret)
  }
}

///|
fn default_rect() -> @core.Rect {
  @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0)
}
