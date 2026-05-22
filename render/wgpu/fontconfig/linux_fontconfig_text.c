#include <moonbit.h>
#include <stdint.h>

#define MOUI_NATIVE_FONT_SPEC_VERSION 1
#define MOUI_NATIVE_FONT_REGISTRATION_VERSION 1

typedef struct {
  int32_t size_key;
  int32_t weight;
  int32_t style;
  int32_t family_count;
} MouiNativeFontSpec;

typedef struct {
  int32_t family_name_len;
  int32_t data_len;
} MouiNativeFontRegistration;

static int32_t moui_read_i32_le(const uint8_t *p) {
  return (int32_t)(((uint32_t)p[0]) | ((uint32_t)p[1] << 8) |
                   ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24));
}

static int32_t moui_linux_parse_font_spec(
  moonbit_bytes_t bytes,
  MouiNativeFontSpec *out
) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  if (len < 20) {
    return 0;
  }
  const uint8_t *src = (const uint8_t *)bytes;
  int32_t version = moui_read_i32_le(src);
  int32_t size_key = moui_read_i32_le(src + 4);
  int32_t weight = moui_read_i32_le(src + 8);
  int32_t style = moui_read_i32_le(src + 12);
  int32_t family_count = moui_read_i32_le(src + 16);
  if (version != MOUI_NATIVE_FONT_SPEC_VERSION || size_key <= 0 ||
      (style != 0 && style != 1) || family_count <= 0) {
    return 0;
  }
  int32_t offset = 20;
  for (int32_t i = 0; i < family_count; i++) {
    if (offset > len - 4) {
      return 0;
    }
    int32_t name_len = moui_read_i32_le(src + offset);
    offset += 4;
    if (name_len <= 0 || name_len > len - offset) {
      return 0;
    }
    offset += name_len;
  }
  if (offset != len) {
    return 0;
  }
  if (out != NULL) {
    out->size_key = size_key;
    out->weight = weight;
    out->style = style;
    out->family_count = family_count;
  }
  return 1;
}

static int32_t moui_linux_parse_font_registration(
  moonbit_bytes_t bytes,
  MouiNativeFontRegistration *out
) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  if (len < 12) {
    return 0;
  }
  const uint8_t *src = (const uint8_t *)bytes;
  int32_t version = moui_read_i32_le(src);
  int32_t family_name_len = moui_read_i32_le(src + 4);
  int32_t data_len = moui_read_i32_le(src + 8);
  if (version != MOUI_NATIVE_FONT_REGISTRATION_VERSION ||
      family_name_len <= 0 || data_len <= 0 ||
      family_name_len > len - 12 ||
      data_len > len - 12 - family_name_len ||
      len != 12 + family_name_len + data_len) {
    return 0;
  }
  if (out != NULL) {
    out->family_name_len = family_name_len;
    out->data_len = data_len;
  }
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_font_spec_family_count(
  moonbit_bytes_t font_spec
) {
  MouiNativeFontSpec spec = {0};
  if (!moui_linux_parse_font_spec(font_spec, &spec)) {
    return -1;
  }
  return spec.family_count;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_font_registration_data_len(
  moonbit_bytes_t payload
) {
  MouiNativeFontRegistration registration = {0};
  if (!moui_linux_parse_font_registration(payload, &registration)) {
    return -1;
  }
  return registration.data_len;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_font_spec_protocol_version(void) {
  return MOUI_NATIVE_FONT_SPEC_VERSION;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_font_registration_protocol_version(void) {
  return MOUI_NATIVE_FONT_REGISTRATION_VERSION;
}

#if defined(__linux__)

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_measure_utf32(
  moonbit_bytes_t utf32,
  moonbit_bytes_t font_spec
) {
  (void)utf32;
  if (!moui_linux_parse_font_spec(font_spec, NULL)) {
    return moonbit_make_bytes(0, 0);
  }
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_layout_run_utf32(
  moonbit_bytes_t utf32,
  moonbit_bytes_t font_spec,
  double max_width,
  double scale_factor
) {
  (void)utf32;
  (void)max_width;
  (void)scale_factor;
  if (!moui_linux_parse_font_spec(font_spec, NULL)) {
    return moonbit_make_bytes(0, 0);
  }
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_raster_glyph(moonbit_bytes_t payload) {
  (void)payload;
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_register_font_data(
  moonbit_bytes_t payload
) {
  return moui_linux_parse_font_registration(payload, NULL);
}

#else

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_measure_utf32(
  moonbit_bytes_t utf32,
  moonbit_bytes_t font_spec
) {
  (void)utf32;
  if (!moui_linux_parse_font_spec(font_spec, NULL)) {
    return moonbit_make_bytes(0, 0);
  }
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_layout_run_utf32(
  moonbit_bytes_t utf32,
  moonbit_bytes_t font_spec,
  double max_width,
  double scale_factor
) {
  (void)utf32;
  (void)max_width;
  (void)scale_factor;
  if (!moui_linux_parse_font_spec(font_spec, NULL)) {
    return moonbit_make_bytes(0, 0);
  }
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_raster_glyph(moonbit_bytes_t payload) {
  (void)payload;
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_register_font_data(
  moonbit_bytes_t payload
) {
  return moui_linux_parse_font_registration(payload, NULL);
}

#endif
