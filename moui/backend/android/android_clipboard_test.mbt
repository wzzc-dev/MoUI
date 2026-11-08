// Contract tests for the clipboard wrappers. Host native builds link the
// stubs from `android_present.cpp` (write fails, read empty), so these pin
// the offline behavior; the JNI path itself is exercised on matching-device
// evidence passes (see `docs/android-support.md`).

///|
test "android clipboard write rejects empty text without calling native" {
  inspect(@android.android_clipboard_write_text(""), content="false")
}

///|
test "android clipboard host stubs report unavailable" {
  // The host stub never carries text: read is None, write of non-empty text
  // fails. On Android the JNI bridge turns these into real results.
  inspect(@android.android_clipboard_read_text() == None, content="true")
  inspect(@android.android_clipboard_write_text("moui"), content="false")
}
