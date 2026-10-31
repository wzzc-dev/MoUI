// HarmonyOS clipboard host service.
//
// The embedded runtime routes Clipboard requests through
// `EmbeddedHostServices` -> `flush_updates_to_shell` -> the host transport, but
// nothing on the HarmonyOS side ever drained that transport or called the
// platform pasteboard, so `AppEnvironment::services()` clipboard calls never
// completed. macOS answers clipboard synchronously from its service bridge
// (`moui/backend/macos/macos_service_host.m`); this file provides the same
// synchronous contract for HarmonyOS through the native OH_Pasteboard API
// (`database/pasteboard/oh_pasteboard.h` + `database/udmf/uds.h`).

#include <moonbit.h>

#include <cstring>
#include <string>

#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define MBW_HARMONYOS_HAS_HILOG 1
#endif

#if defined(__OHOS__) && defined(__has_include)
#if __has_include(<database/pasteboard/oh_pasteboard.h>) && \
    __has_include(<database/udmf/udmf.h>)
#include <database/pasteboard/oh_pasteboard.h>
#include <database/udmf/udmf.h>
#define MBW_HARMONYOS_HAS_PASTEBOARD 1
#endif
#endif

#ifndef MOONBIT_FFI_EXPORT
#define MOONBIT_FFI_EXPORT __attribute__((visibility("default")))
#endif

// Host input channel (window/modules/window/harmonyos/native_harmonyos_host.c).
extern "C" void mbw_harmonyos_host_on_keyboard_codepoint(int32_t codepoint);

namespace {

static const unsigned int k_clipboard_log_domain = 0x4D4F;
static const char *k_clipboard_log_tag = "MoUIHarmony";

void log_clipboard(const char *message, int value) {
#if defined(MBW_HARMONYOS_HAS_HILOG)
  OH_LOG_Print(
    LOG_APP,
    LOG_INFO,
    k_clipboard_log_domain,
    k_clipboard_log_tag,
    "%{public}s value=%{public}d",
    message,
    value
  );
#else
  (void)message;
  (void)value;
#endif
}

moonbit_bytes_t bytes_from_string(const std::string &text) {
  moonbit_bytes_t bytes = moonbit_make_bytes(static_cast<int32_t>(text.size()), 0);
  if (!text.empty()) {
    std::memcpy(bytes, text.data(), text.size());
  }
  return bytes;
}

}  // namespace

extern "C" {

// Reads plain text from the system pasteboard. Returns an empty byte string
// when the clipboard holds no text, the platform call fails, or the build has
// no pasteboard support.
MOONBIT_FFI_EXPORT moonbit_bytes_t mbw_harmonyos_clipboard_read_text(void) {
#if defined(MBW_HARMONYOS_HAS_PASTEBOARD)
  OH_Pasteboard *pasteboard = OH_Pasteboard_Create();
  if (pasteboard == nullptr) {
    return moonbit_make_bytes(0, 0);
  }
  int status = 0;
  OH_UdmfData *data = OH_Pasteboard_GetData(pasteboard, &status);
  if (data == nullptr) {
    log_clipboard("clipboard read get-data failed, status", status);
    OH_Pasteboard_Destroy(pasteboard);
    return moonbit_make_bytes(0, 0);
  }
  unsigned int record_count = 0;
  OH_UdmfRecord **records = OH_UdmfData_GetRecords(data, &record_count);
  log_clipboard("clipboard read record count", static_cast<int>(record_count));
  std::string text;
  if (records != nullptr) {
    for (unsigned int i = 0; i < record_count && text.empty(); ++i) {
      if (records[i] == nullptr) {
        continue;
      }
      OH_UdsPlainText *plain = OH_UdsPlainText_Create();
      if (plain == nullptr) {
        continue;
      }
      if (OH_UdmfRecord_GetPlainText(records[i], plain) == 0) {
        const char *content = OH_UdsPlainText_GetContent(plain);
        if (content != nullptr) {
          text.assign(content);
        }
      }
      OH_UdsPlainText_Destroy(plain);
    }
  }
  OH_UdmfData_Destroy(data);
  OH_Pasteboard_Destroy(pasteboard);
  log_clipboard("clipboard read", static_cast<int>(text.size()));
  return bytes_from_string(text);
#else
  return moonbit_make_bytes(0, 0);
#endif
}

// Writes plain text to the system pasteboard. Returns 1 on success. Empty text
// is rejected so a failed local read cannot silently clear the clipboard.
MOONBIT_FFI_EXPORT int32_t mbw_harmonyos_clipboard_write_text(
    moonbit_bytes_t text
) {
  const int32_t len = static_cast<int32_t>(Moonbit_array_length(text));
  if (len <= 0) {
    return 0;
  }
#if defined(MBW_HARMONYOS_HAS_PASTEBOARD)
  OH_Pasteboard *pasteboard = OH_Pasteboard_Create();
  if (pasteboard == nullptr) {
    return 0;
  }
  OH_UdmfData *data = OH_UdmfData_Create();
  OH_UdmfRecord *record = OH_UdmfRecord_Create();
  OH_UdsPlainText *plain = OH_UdsPlainText_Create();
  int32_t ok = 0;
  if (data != nullptr && record != nullptr && plain != nullptr) {
    std::string owned(reinterpret_cast<const char *>(text), static_cast<size_t>(len));
    if (OH_UdsPlainText_SetContent(plain, owned.c_str()) == 0 &&
        OH_UdmfRecord_AddPlainText(record, plain) == 0 &&
        OH_UdmfData_AddRecord(data, record) == 0 &&
        OH_Pasteboard_SetData(pasteboard, data) == 0) {
      ok = 1;
    }
  }
  if (plain != nullptr) {
    OH_UdsPlainText_Destroy(plain);
  }
  if (record != nullptr) {
    OH_UdmfRecord_Destroy(record);
  }
  if (data != nullptr) {
    OH_UdmfData_Destroy(data);
  }
  OH_Pasteboard_Destroy(pasteboard);
  log_clipboard("clipboard write ok", static_cast<int>(ok));
  return ok;
#else
  return 0;
#endif
}


// Called from the ArkTS PasteButton click handler, i.e. after the platform
// granted a one-shot paste authorization. A plain application cannot read the
// pasteboard otherwise (ohos.permission.READ_PASTEBOARD is system_basic +
// user_grant), so this is the only path that works for a normal-level HAP.
//
// The text is forwarded to the runtime as keyboard input: the hosted surface
// owns editing state, and an accessibility-style text insertion is the same
// channel a physical paste shortcut would use.
MOONBIT_FFI_EXPORT int32_t mbw_harmonyos_clipboard_request_granted_read(void) {
  moonbit_bytes_t text = mbw_harmonyos_clipboard_read_text();
  const int32_t len = static_cast<int32_t>(Moonbit_array_length(text));
  log_clipboard("clipboard granted read bytes", len);
  if (len <= 0) {
    return 0;
  }
  // Reuse the existing keyboard codepoint channel: pasted text and typed text
  // both arrive as `Ime(Commit(...))` in the runtime, so no new host event kind
  // is needed. UTF-8 is decoded here because the channel carries code points.
  int32_t forwarded = 0;
  const auto *bytes = reinterpret_cast<const unsigned char *>(text);
  int32_t i = 0;
  while (i < len) {
    unsigned char lead = bytes[i];
    uint32_t codepoint = 0;
    int32_t extra = 0;
    if (lead < 0x80) {
      codepoint = lead;
      extra = 0;
    } else if ((lead & 0xE0) == 0xC0) {
      codepoint = lead & 0x1F;
      extra = 1;
    } else if ((lead & 0xF0) == 0xE0) {
      codepoint = lead & 0x0F;
      extra = 2;
    } else if ((lead & 0xF8) == 0xF0) {
      codepoint = lead & 0x07;
      extra = 3;
    } else {
      i += 1;
      continue;
    }
    if (i + extra >= len) {
      break;
    }
    bool valid = true;
    for (int32_t k = 1; k <= extra; ++k) {
      const unsigned char cont = bytes[i + k];
      if ((cont & 0xC0) != 0x80) {
        valid = false;
        break;
      }
      codepoint = (codepoint << 6) | (cont & 0x3F);
    }
    if (!valid) {
      i += 1;
      continue;
    }
    mbw_harmonyos_host_on_keyboard_codepoint(static_cast<int32_t>(codepoint));
    forwarded += 1;
    i += extra + 1;
  }
  log_clipboard("clipboard granted read forwarded", forwarded);
  return forwarded;
}

// Round-trips a marker string through the pasteboard at startup so a device
// log alone proves the native bridge works, without needing UI navigation to
// reach the Showcase clipboard buttons.
MOONBIT_FFI_EXPORT int32_t mbw_harmonyos_clipboard_selftest(void) {
#if defined(MBW_HARMONYOS_HAS_PASTEBOARD)
  const char *marker = "moui-clipboard-selftest";
  const int32_t len = static_cast<int32_t>(std::strlen(marker));
  OH_Pasteboard *pasteboard = OH_Pasteboard_Create();
  if (pasteboard == nullptr) {
    log_clipboard("clipboard selftest no pasteboard", 0);
    return 0;
  }
  OH_UdmfData *data = OH_UdmfData_Create();
  OH_UdmfRecord *record = OH_UdmfRecord_Create();
  OH_UdsPlainText *plain = OH_UdsPlainText_Create();
  int32_t wrote = 0;
  if (data != nullptr && record != nullptr && plain != nullptr) {
    if (OH_UdsPlainText_SetContent(plain, marker) == 0 &&
        OH_UdmfRecord_AddPlainText(record, plain) == 0 &&
        OH_UdmfData_AddRecord(data, record) == 0 &&
        OH_Pasteboard_SetData(pasteboard, data) == 0) {
      wrote = 1;
    }
  }
  if (plain != nullptr) {
    OH_UdsPlainText_Destroy(plain);
  }
  if (record != nullptr) {
    OH_UdmfRecord_Destroy(record);
  }
  if (data != nullptr) {
    OH_UdmfData_Destroy(data);
  }
  OH_Pasteboard_Destroy(pasteboard);
  log_clipboard("clipboard selftest wrote", wrote);
  if (wrote == 0) {
    return 0;
  }
  // Read it back through a fresh pasteboard handle; a value equal to the
  // marker length proves the write reached the system pasteboard.
  moonbit_bytes_t read_back = mbw_harmonyos_clipboard_read_text();
  const int32_t read_len = static_cast<int32_t>(Moonbit_array_length(read_back));
  const int32_t matched = read_len == len ? 1 : 0;
  log_clipboard("clipboard selftest readback", matched);
  return matched;
#else
  log_clipboard("clipboard selftest unsupported", 0);
  return 0;
#endif
}

}  // extern "C"
