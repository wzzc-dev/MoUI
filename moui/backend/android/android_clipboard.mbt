// Android clipboard host service bindings.
//
// The native side lives in the window embedder
// (`window/modules/window/android/native_android_host.c`) and talks to the
// HostedActivity ClipboardManager helpers through JNI. macOS exposes the same
// shape from `moui/backend/macos/macos_services.mbt` and HarmonyOS from
// `moui/backend/harmonyos/harmonyos_clipboard.mbt`; the embedded path needs
// its own because `EmbeddedHostServices` only queues Clipboard requests and no
// Android template code drained that queue.

///|
extern "C" fn android_clipboard_read_text_bytes() -> Bytes = "mbw_android_clipboard_read_text"

///|
#borrow(text)
extern "C" fn android_clipboard_write_text_bytes(text : Bytes) -> Int32 = "mbw_android_clipboard_write_text"

///|
/// Reads the system clipboard plain text. Returns `None` when the clipboard
/// holds no text.
pub fn android_clipboard_read_text() -> String? {
  let bytes = android_clipboard_read_text_bytes()
  if bytes.length() == 0 {
    None
  } else {
    Some(@utf8.decode_lossy(bytes[:], ignore_bom=false))
  }
}

///|
/// Writes plain text to the system clipboard. Returns whether the write
/// succeeded. Empty text is rejected so a failed read cannot clear the
/// clipboard.
pub fn android_clipboard_write_text(text : String) -> Bool {
  if text == "" {
    return false
  }
  android_clipboard_write_text_bytes(@utf8.encode(text, bom=false)) != 0
}
