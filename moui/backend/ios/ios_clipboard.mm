// iOS clipboard host service.
//
// The window embedder routes IME/surface/input; the clipboard is answered
// here synchronously through UIPasteboard, the same contract the Android
// bridge provides from the template's ClipboardManager helpers and macOS
// from `moui/backend/macos/macos_services.mbt`.

#include <moonbit.h>
#include <stdint.h>
#include <string.h>

#if defined(__APPLE__) && TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#ifndef MOONBIT_FFI_EXPORT
#define MOONBIT_FFI_EXPORT __attribute__((visibility("default")))
#endif

extern "C" {

// Reads plain text from the general pasteboard. Returns an empty byte string
// when the clipboard holds no text.
MOONBIT_FFI_EXPORT moonbit_bytes_t mbw_ios_clipboard_read_text(void) {
#if defined(__APPLE__) && TARGET_OS_IPHONE
  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  if (pasteboard == nil || pasteboard.hasStrings == NO) {
    return moonbit_make_bytes(0, 0);
  }
  NSString *text = pasteboard.string;
  if (text == nil) {
    return moonbit_make_bytes(0, 0);
  }
  const char *utf8 = [text UTF8String];
  int32_t length = (int32_t)strlen(utf8);
  moonbit_bytes_t bytes = moonbit_make_bytes(length, 0);
  if (length > 0) {
    memcpy(bytes, utf8, (size_t)length);
  }
  return bytes;
#else
  return moonbit_make_bytes(0, 0);
#endif
}

// Writes plain text to the general pasteboard. Returns 1 on success. Empty
// text is rejected so a failed read cannot clear the clipboard.
MOONBIT_FFI_EXPORT int32_t mbw_ios_clipboard_write_text(moonbit_bytes_t text) {
  const int32_t len = (int32_t)Moonbit_array_length(text);
  if (len <= 0) {
    return 0;
  }
#if defined(__APPLE__) && TARGET_OS_IPHONE
  @autoreleasepool {
    NSString *string = [[NSString alloc] initWithBytes:text
                                                length:(NSUInteger)len
                                              encoding:NSUTF8StringEncoding];
    if (string == nil) {
      return 0;
    }
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = string;
    return 1;
  }
#else
  return 0;
#endif
}

}  // extern "C"
