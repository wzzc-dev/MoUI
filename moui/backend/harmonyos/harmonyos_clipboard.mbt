// HarmonyOS clipboard host service bindings.
//
// The native side lives in `harmonyos_clipboard.cpp` and talks to
// OH_Pasteboard (`database/pasteboard/oh_pasteboard.h`). macOS exposes the same
// shape from `moui/backend/macos/macos_services.mbt`; the embedded path needs
// its own because `EmbeddedHostServices` only queues Clipboard requests and no
// HarmonyOS template code drains that queue.

///|
extern "C" fn harmonyos_clipboard_read_text_bytes() -> Bytes = "mbw_harmonyos_clipboard_read_text"

///|
#borrow(text)
extern "C" fn harmonyos_clipboard_write_text_bytes(text : Bytes) -> Int32 = "mbw_harmonyos_clipboard_write_text"

///|
/// Reads the system pasteboard plain text. Returns `None` when the clipboard
/// holds no text.
pub fn harmonyos_clipboard_read_text() -> String? {
  let bytes = harmonyos_clipboard_read_text_bytes()
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
pub fn harmonyos_clipboard_write_text(text : String) -> Bool {
  if text == "" {
    return false
  }
  harmonyos_clipboard_write_text_bytes(@utf8.encode(text, bom=false)) != 0
}

///|
extern "C" fn harmonyos_clipboard_selftest_native() -> Int32 = "mbw_harmonyos_clipboard_selftest"

///|
/// Round-trips a marker string through the system pasteboard and reports
/// whether the value read back matches what was written. Used as startup
/// evidence on a matching device; a host build without the pasteboard reports
/// false instead of failing.
pub fn harmonyos_clipboard_selftest() -> Bool {
  harmonyos_clipboard_selftest_native() != 0
}
