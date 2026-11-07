// iOS clipboard host service bindings.
//
// The native side lives in `ios_clipboard.mm` and talks to the general
// UIPasteboard. macOS exposes the same shape from
// `moui/backend/macos/macos_services.mbt`, Android from the embedder's JNI
// ClipboardManager bridge, and HarmonyOS from OH_Pasteboard.

///|
extern "C" fn ios_clipboard_read_text_bytes() -> Bytes = "mbw_ios_clipboard_read_text"

///|
#borrow(text)
extern "C" fn ios_clipboard_write_text_bytes(text : Bytes) -> Int32 = "mbw_ios_clipboard_write_text"

///|
/// Reads the system pasteboard plain text. Returns `None` when the clipboard
/// holds no text.
pub fn ios_clipboard_read_text() -> String? {
  let bytes = ios_clipboard_read_text_bytes()
  if bytes.length() == 0 {
    None
  } else {
    Some(@utf8.decode_lossy(bytes[:], ignore_bom=false))
  }
}

///|
/// Writes plain text to the system pasteboard. Returns whether the write
/// succeeded. Empty text is rejected so a failed read cannot clear the
/// clipboard.
pub fn ios_clipboard_write_text(text : String) -> Bool {
  if text == "" {
    return false
  }
  ios_clipboard_write_text_bytes(@utf8.encode(text, bom=false)) != 0
}
