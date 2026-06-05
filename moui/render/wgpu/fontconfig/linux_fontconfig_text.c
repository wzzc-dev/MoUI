#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(__linux__)
#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#endif

#define MOUI_NATIVE_FONT_SPEC_VERSION 1
#define MOUI_NATIVE_FONT_REGISTRATION_VERSION 1
#define MOUI_FONTCONFIG_RUN_VERSION 1
#define MOUI_FONTCONFIG_RASTER_VERSION 1
#define MOUI_FONTCONFIG_GLYPH_PAYLOAD_VERSION 1

typedef struct {
  int32_t size_key;
  int32_t weight;
  int32_t style;
  int32_t family_count;
  const uint8_t *families;
  int32_t families_len;
} MouiNativeFontSpec;

typedef struct {
  int32_t family_name_len;
  int32_t data_len;
} MouiNativeFontRegistration;

static int32_t moui_read_i32_le(const uint8_t *p) {
  return (int32_t)(((uint32_t)p[0]) | ((uint32_t)p[1] << 8) |
                   ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24));
}

static uint32_t moui_read_u32_le(const uint8_t *p) {
  return ((uint32_t)p[0]) | ((uint32_t)p[1] << 8) |
         ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void moui_write_i32_le(uint8_t *p, int32_t value) {
  uint32_t u = (uint32_t)value;
  p[0] = (uint8_t)(u & 0xffu);
  p[1] = (uint8_t)((u >> 8) & 0xffu);
  p[2] = (uint8_t)((u >> 16) & 0xffu);
  p[3] = (uint8_t)((u >> 24) & 0xffu);
}

static void moui_write_double_le(uint8_t *p, double value) {
  uint64_t u = 0;
  memcpy(&u, &value, sizeof(double));
  for (int i = 0; i < 8; i++) {
    p[i] = (uint8_t)((u >> (8 * i)) & 0xffu);
  }
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
    out->families = src + 20;
    out->families_len = len - 20;
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

typedef struct {
  void *handle;
  FT_Error (*init_free_type)(FT_Library *);
  FT_Error (*new_face)(FT_Library, const char *, FT_Long, FT_Face *);
  FT_Error (*done_face)(FT_Face);
  FT_Error (*done_free_type)(FT_Library);
  FT_Error (*set_pixel_sizes)(FT_Face, FT_UInt, FT_UInt);
  FT_Error (*select_size)(FT_Face, FT_Int);
  FT_UInt (*get_char_index)(FT_Face, FT_ULong);
  FT_Error (*load_glyph)(FT_Face, FT_UInt, FT_Int32);
  FT_Error (*render_glyph)(FT_GlyphSlot, FT_Render_Mode);
} MouiFreeTypeApi;

typedef struct {
  int32_t glyph_id;
  int32_t codepoint;
  int32_t pixel_size;
  const uint8_t *path;
  int32_t path_len;
} MouiFontconfigGlyphPayload;

static moonbit_bytes_t moui_linux_empty_bytes(void) {
  return moonbit_make_bytes(0, 0);
}

static int32_t moui_linux_load_freetype(MouiFreeTypeApi *api) {
  memset(api, 0, sizeof(*api));
  const char *candidates[] = {
    "libfreetype.so.6",
    "libfreetype.so",
  };
  for (int i = 0; i < 2; i++) {
    api->handle = dlopen(candidates[i], RTLD_LAZY | RTLD_LOCAL);
    if (api->handle != NULL) {
      break;
    }
  }
  if (api->handle == NULL) {
    return 0;
  }
#define MOUI_LOAD_FT(name, symbol)                                            \
  do {                                                                        \
    api->name = dlsym(api->handle, symbol);                                   \
    if (api->name == NULL) {                                                  \
      dlclose(api->handle);                                                   \
      memset(api, 0, sizeof(*api));                                           \
      return 0;                                                               \
    }                                                                         \
  } while (0)
  MOUI_LOAD_FT(init_free_type, "FT_Init_FreeType");
  MOUI_LOAD_FT(new_face, "FT_New_Face");
  MOUI_LOAD_FT(done_face, "FT_Done_Face");
  MOUI_LOAD_FT(done_free_type, "FT_Done_FreeType");
  MOUI_LOAD_FT(set_pixel_sizes, "FT_Set_Pixel_Sizes");
  MOUI_LOAD_FT(select_size, "FT_Select_Size");
  MOUI_LOAD_FT(get_char_index, "FT_Get_Char_Index");
  MOUI_LOAD_FT(load_glyph, "FT_Load_Glyph");
  MOUI_LOAD_FT(render_glyph, "FT_Render_Glyph");
#undef MOUI_LOAD_FT
  return 1;
}

static void moui_linux_unload_freetype(MouiFreeTypeApi *api) {
  if (api->handle != NULL) {
    dlclose(api->handle);
  }
  memset(api, 0, sizeof(*api));
}

static int32_t moui_linux_font_spec_has_emoji_family(MouiNativeFontSpec spec) {
  const uint8_t *cursor = spec.families;
  int32_t remaining = spec.families_len;
  for (int32_t i = 0; i < spec.family_count; i++) {
    if (remaining < 4) {
      return 0;
    }
    int32_t name_len = moui_read_i32_le(cursor);
    cursor += 4;
    remaining -= 4;
    if (name_len <= 0 || name_len > remaining) {
      return 0;
    }
    if (name_len == 5 && memcmp(cursor, "emoji", 5) == 0) {
      return 1;
    }
    cursor += name_len;
    remaining -= name_len;
  }
  return 0;
}

static int32_t moui_linux_codepoint_is_color_emoji(uint32_t codepoint) {
  return (codepoint >= 0x1F000u && codepoint <= 0x1FAFFu) ||
         (codepoint >= 0x2600u && codepoint <= 0x27BFu);
}

static int32_t moui_linux_find_emoji_font(char *out, int32_t cap) {
  const char *candidates[] = {
    "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf",
    "/usr/share/fonts/noto/NotoColorEmoji.ttf",
    "/usr/share/fonts/google-noto-emoji/NotoColorEmoji.ttf",
    "/usr/local/share/fonts/NotoColorEmoji.ttf",
  };
  for (int i = 0; i < 4; i++) {
    FILE *file = fopen(candidates[i], "rb");
    if (file != NULL) {
      fclose(file);
      int32_t len = (int32_t)strlen(candidates[i]);
      if (len > 0 && len < cap) {
        memcpy(out, candidates[i], (size_t)len + 1u);
        return len;
      }
    }
  }
  return 0;
}

static int32_t moui_linux_pixel_size(MouiNativeFontSpec spec, double scale_factor) {
  double size = spec.size_key > 0 ? ((double)spec.size_key / 64.0) : 16.0;
  double scale = scale_factor > 0.0 ? scale_factor : 1.0;
  int32_t pixel_size = (int32_t)(size * scale + 0.5);
  if (pixel_size < 1) {
    pixel_size = 1;
  }
  if (pixel_size > 512) {
    pixel_size = 512;
  }
  return pixel_size;
}

static int32_t moui_linux_select_freetype_size(
  MouiFreeTypeApi *ft,
  FT_Face face,
  int32_t pixel_size
) {
  if (ft->set_pixel_sizes(face, 0, (FT_UInt)pixel_size) == 0) {
    return 1;
  }
  if (face->num_fixed_sizes <= 0) {
    return 0;
  }
  int best = 0;
  int best_ppem = 0;
  for (int i = 0; i < face->num_fixed_sizes; i++) {
    int ppem = (int)((face->available_sizes[i].y_ppem + 32) / 64);
    if (ppem <= 0) {
      ppem = face->available_sizes[i].height;
    }
    if (best_ppem == 0 ||
        (best_ppem < pixel_size && ppem > best_ppem) ||
        (best_ppem >= pixel_size && ppem >= pixel_size && ppem < best_ppem)) {
      best = i;
      best_ppem = ppem;
    }
  }
  return ft->select_size(face, best) == 0;
}

static int32_t moui_linux_open_emoji_face(
  MouiFreeTypeApi *ft,
  const char *path,
  int32_t pixel_size,
  FT_Library *library,
  FT_Face *face
) {
  *library = NULL;
  *face = NULL;
  if (!moui_linux_load_freetype(ft)) {
    return 0;
  }
  if (ft->init_free_type(library) != 0) {
    moui_linux_unload_freetype(ft);
    return 0;
  }
  if (ft->new_face(*library, path, 0, face) != 0) {
    ft->done_free_type(*library);
    *library = NULL;
    moui_linux_unload_freetype(ft);
    return 0;
  }
  if (!moui_linux_select_freetype_size(ft, *face, pixel_size)) {
    ft->done_face(*face);
    ft->done_free_type(*library);
    *face = NULL;
    *library = NULL;
    moui_linux_unload_freetype(ft);
    return 0;
  }
  return 1;
}

static void moui_linux_close_emoji_face(
  MouiFreeTypeApi *ft,
  FT_Library library,
  FT_Face face
) {
  if (face != NULL) {
    ft->done_face(face);
  }
  if (library != NULL) {
    ft->done_free_type(library);
  }
  moui_linux_unload_freetype(ft);
}

static int32_t moui_linux_parse_glyph_payload(
  moonbit_bytes_t payload,
  MouiFontconfigGlyphPayload *out
) {
  int32_t len = (int32_t)Moonbit_array_length(payload);
  if (len < 20) {
    return 0;
  }
  const uint8_t *src = (const uint8_t *)payload;
  int32_t version = moui_read_i32_le(src);
  int32_t path_len = moui_read_i32_le(src + 16);
  if (version != MOUI_FONTCONFIG_GLYPH_PAYLOAD_VERSION ||
      path_len <= 0 ||
      path_len > len - 20 ||
      len != 20 + path_len) {
    return 0;
  }
  if (out != NULL) {
    out->glyph_id = moui_read_i32_le(src + 4);
    out->codepoint = moui_read_i32_le(src + 8);
    out->pixel_size = moui_read_i32_le(src + 12);
    out->path_len = path_len;
    out->path = src + 20;
  }
  return 1;
}

static void moui_linux_write_glyph_payload(
  uint8_t *dst,
  int32_t glyph_id,
  uint32_t codepoint,
  int32_t pixel_size,
  const char *path,
  int32_t path_len
) {
  moui_write_i32_le(dst, MOUI_FONTCONFIG_GLYPH_PAYLOAD_VERSION);
  moui_write_i32_le(dst + 4, glyph_id);
  moui_write_i32_le(dst + 8, (int32_t)codepoint);
  moui_write_i32_le(dst + 12, pixel_size);
  moui_write_i32_le(dst + 16, path_len);
  memcpy(dst + 20, path, (size_t)path_len);
}

static uint8_t moui_linux_unpremultiply_channel(uint8_t channel, uint8_t alpha) {
  if (alpha == 0 || channel == 0) {
    return 0;
  }
  uint32_t value = ((uint32_t)channel * 255u + (uint32_t)alpha / 2u) / (uint32_t)alpha;
  return value > 255u ? 255u : (uint8_t)value;
}

static int32_t moui_linux_high_saturation_rgba_count(
  uint8_t r,
  uint8_t g,
  uint8_t b,
  uint8_t a
) {
  if (a < 16) {
    return 0;
  }
  uint8_t max = r > g ? (r > b ? r : b) : (g > b ? g : b);
  uint8_t min = r < g ? (r < b ? r : b) : (g < b ? g : b);
  return max > 120 && (max - min) > 48 ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_measure_utf32(
  moonbit_bytes_t utf32,
  moonbit_bytes_t font_spec
) {
  (void)utf32;
  if (!moui_linux_parse_font_spec(font_spec, NULL)) {
    return moonbit_make_bytes(0, 0);
  }
  return moui_linux_empty_bytes();
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_layout_run_utf32(
  moonbit_bytes_t utf32,
  moonbit_bytes_t font_spec,
  double max_width,
  double scale_factor
) {
  (void)max_width;
  int32_t len = (int32_t)Moonbit_array_length(utf32);
  if (len < 0 || (len % 4) != 0) {
    return moui_linux_empty_bytes();
  }
  MouiNativeFontSpec spec = {0};
  if (!moui_linux_parse_font_spec(font_spec, &spec) ||
      !moui_linux_font_spec_has_emoji_family(spec)) {
    return moui_linux_empty_bytes();
  }
  char font_path[4096];
  int32_t path_len = moui_linux_find_emoji_font(font_path, (int32_t)sizeof(font_path));
  if (path_len <= 0) {
    return moui_linux_empty_bytes();
  }
  int32_t pixel_size = moui_linux_pixel_size(spec, scale_factor);
  MouiFreeTypeApi ft = {0};
  FT_Library library = NULL;
  FT_Face face = NULL;
  if (!moui_linux_open_emoji_face(&ft, font_path, pixel_size, &library, &face)) {
    return moui_linux_empty_bytes();
  }

  const uint8_t *src = (const uint8_t *)utf32;
  int32_t char_count = len / 4;
  int32_t glyph_count = 0;
  int64_t out_len = 32;
  for (int32_t i = 0; i < char_count; i++) {
    uint32_t codepoint = moui_read_u32_le(src + i * 4);
    if (!moui_linux_codepoint_is_color_emoji(codepoint)) {
      continue;
    }
    FT_UInt glyph_id = ft.get_char_index(face, (FT_ULong)codepoint);
    if (glyph_id == 0) {
      continue;
    }
    char cache_key[128];
    int key_len = snprintf(
      cache_key,
      sizeof(cache_key),
      "fontconfig-emoji:%u:%u:%d",
      (unsigned int)glyph_id,
      (unsigned int)codepoint,
      pixel_size
    );
    if (key_len <= 0 || key_len >= (int)sizeof(cache_key)) {
      continue;
    }
    glyph_count++;
    out_len += 24 + key_len + 20 + path_len;
    if (out_len > INT32_MAX) {
      moui_linux_close_emoji_face(&ft, library, face);
      return moui_linux_empty_bytes();
    }
  }
  if (glyph_count <= 0) {
    moui_linux_close_emoji_face(&ft, library, face);
    return moui_linux_empty_bytes();
  }

  moonbit_bytes_t out = moonbit_make_bytes((int32_t)out_len, 0);
  uint8_t *dst = (uint8_t *)out;
  moui_write_i32_le(dst, MOUI_FONTCONFIG_RUN_VERSION);
  moui_write_i32_le(dst + 4, glyph_count);
  moui_write_double_le(dst + 8, (double)(glyph_count * pixel_size));
  moui_write_double_le(dst + 16, (double)pixel_size * 1.25);
  moui_write_double_le(dst + 24, (double)pixel_size);
  int32_t offset = 32;
  int32_t glyph_index = 0;
  for (int32_t i = 0; i < char_count; i++) {
    uint32_t codepoint = moui_read_u32_le(src + i * 4);
    if (!moui_linux_codepoint_is_color_emoji(codepoint)) {
      continue;
    }
    FT_UInt glyph_id = ft.get_char_index(face, (FT_ULong)codepoint);
    if (glyph_id == 0) {
      continue;
    }
    char cache_key[128];
    int key_len = snprintf(
      cache_key,
      sizeof(cache_key),
      "fontconfig-emoji:%u:%u:%d",
      (unsigned int)glyph_id,
      (unsigned int)codepoint,
      pixel_size
    );
    if (key_len <= 0 || key_len >= (int)sizeof(cache_key)) {
      continue;
    }
    int32_t payload_len = 20 + path_len;
    moui_write_double_le(dst + offset, (double)(glyph_index * pixel_size));
    moui_write_double_le(dst + offset + 8, 0.0);
    moui_write_i32_le(dst + offset + 16, key_len);
    moui_write_i32_le(dst + offset + 20, payload_len);
    memcpy(dst + offset + 24, cache_key, (size_t)key_len);
    moui_linux_write_glyph_payload(
      dst + offset + 24 + key_len,
      (int32_t)glyph_id,
      codepoint,
      pixel_size,
      font_path,
      path_len
    );
    offset += 24 + key_len + payload_len;
    glyph_index++;
  }
  moui_linux_close_emoji_face(&ft, library, face);
  return out;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_raster_glyph(moonbit_bytes_t payload) {
  MouiFontconfigGlyphPayload parsed = {0};
  if (!moui_linux_parse_glyph_payload(payload, &parsed) ||
      parsed.glyph_id <= 0 ||
      parsed.pixel_size <= 0) {
    return moui_linux_empty_bytes();
  }
  char font_path[4096];
  if (parsed.path_len >= (int32_t)sizeof(font_path)) {
    return moui_linux_empty_bytes();
  }
  memcpy(font_path, parsed.path, (size_t)parsed.path_len);
  font_path[parsed.path_len] = '\0';

  MouiFreeTypeApi ft = {0};
  FT_Library library = NULL;
  FT_Face face = NULL;
  if (!moui_linux_open_emoji_face(&ft, font_path, parsed.pixel_size, &library, &face)) {
    return moui_linux_empty_bytes();
  }
  FT_UInt glyph_id = (FT_UInt)parsed.glyph_id;
  if (ft.load_glyph(face, glyph_id, FT_LOAD_COLOR | FT_LOAD_DEFAULT) != 0) {
    moui_linux_close_emoji_face(&ft, library, face);
    return moui_linux_empty_bytes();
  }
  FT_GlyphSlot slot = face->glyph;
  if (slot->format != FT_GLYPH_FORMAT_BITMAP &&
      ft.render_glyph(slot, FT_RENDER_MODE_NORMAL) != 0) {
    moui_linux_close_emoji_face(&ft, library, face);
    return moui_linux_empty_bytes();
  }
  FT_Bitmap bitmap = slot->bitmap;
  if (bitmap.pixel_mode != FT_PIXEL_MODE_BGRA ||
      bitmap.width <= 0 ||
      bitmap.rows <= 0 ||
      bitmap.buffer == NULL) {
    moui_linux_close_emoji_face(&ft, library, face);
    return moui_linux_empty_bytes();
  }
  int32_t width = (int32_t)bitmap.width;
  int32_t height = (int32_t)bitmap.rows;
  int64_t pixel_len = (int64_t)width * (int64_t)height * 4;
  if (pixel_len <= 0 || pixel_len > INT32_MAX - 32) {
    moui_linux_close_emoji_face(&ft, library, face);
    return moui_linux_empty_bytes();
  }
  moonbit_bytes_t out = moonbit_make_bytes(32 + (int32_t)pixel_len, 0);
  uint8_t *dst = (uint8_t *)out;
  moui_write_i32_le(dst, width);
  moui_write_i32_le(dst + 4, height);
  moui_write_i32_le(dst + 8, slot->bitmap_left);
  moui_write_i32_le(dst + 12, -slot->bitmap_top);
  moui_write_i32_le(dst + 16, MOUI_FONTCONFIG_RASTER_VERSION);
  moui_write_i32_le(dst + 20, 1);
  moui_write_double_le(dst + 24, slot->advance.x > 0 ? ((double)slot->advance.x / 64.0) : (double)parsed.pixel_size);
  for (int32_t y = 0; y < height; y++) {
    const uint8_t *row = bitmap.pitch >= 0
      ? bitmap.buffer + y * bitmap.pitch
      : bitmap.buffer + (height - 1 - y) * (-bitmap.pitch);
    for (int32_t x = 0; x < width; x++) {
      const uint8_t *src = row + x * 4;
      uint8_t b = src[0];
      uint8_t g = src[1];
      uint8_t r = src[2];
      uint8_t a = src[3];
      int32_t out_offset = 32 + (y * width + x) * 4;
      dst[out_offset] = moui_linux_unpremultiply_channel(r, a);
      dst[out_offset + 1] = moui_linux_unpremultiply_channel(g, a);
      dst[out_offset + 2] = moui_linux_unpremultiply_channel(b, a);
      dst[out_offset + 3] = a;
    }
  }
  moui_linux_close_emoji_face(&ft, library, face);
  return out;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_register_font_data(
  moonbit_bytes_t payload
) {
  return moui_linux_parse_font_registration(payload, NULL);
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_color_emoji_raster_pixels(void) {
  char font_path[4096];
  int32_t path_len = moui_linux_find_emoji_font(font_path, (int32_t)sizeof(font_path));
  if (path_len <= 0) {
    return -1;
  }
  MouiFreeTypeApi ft = {0};
  FT_Library library = NULL;
  FT_Face face = NULL;
  if (!moui_linux_open_emoji_face(&ft, font_path, 26, &library, &face)) {
    return -1;
  }
  FT_UInt glyph_id = ft.get_char_index(face, (FT_ULong)0x1F642u);
  if (glyph_id == 0 ||
      ft.load_glyph(face, glyph_id, FT_LOAD_COLOR | FT_LOAD_DEFAULT) != 0) {
    moui_linux_close_emoji_face(&ft, library, face);
    return 0;
  }
  FT_GlyphSlot slot = face->glyph;
  if (slot->format != FT_GLYPH_FORMAT_BITMAP &&
      ft.render_glyph(slot, FT_RENDER_MODE_NORMAL) != 0) {
    moui_linux_close_emoji_face(&ft, library, face);
    return 0;
  }
  FT_Bitmap bitmap = slot->bitmap;
  if (bitmap.pixel_mode != FT_PIXEL_MODE_BGRA ||
      bitmap.width <= 0 ||
      bitmap.rows <= 0 ||
      bitmap.buffer == NULL) {
    moui_linux_close_emoji_face(&ft, library, face);
    return 0;
  }
  int32_t count = 0;
  int32_t width = (int32_t)bitmap.width;
  int32_t height = (int32_t)bitmap.rows;
  for (int32_t y = 0; y < height; y++) {
    const uint8_t *row = bitmap.pitch >= 0
      ? bitmap.buffer + y * bitmap.pitch
      : bitmap.buffer + (height - 1 - y) * (-bitmap.pitch);
    for (int32_t x = 0; x < width; x++) {
      const uint8_t *src = row + x * 4;
      uint8_t b = src[0];
      uint8_t g = src[1];
      uint8_t r = src[2];
      uint8_t a = src[3];
      count += moui_linux_high_saturation_rgba_count(
        moui_linux_unpremultiply_channel(r, a),
        moui_linux_unpremultiply_channel(g, a),
        moui_linux_unpremultiply_channel(b, a),
        a
      );
    }
  }
  moui_linux_close_emoji_face(&ft, library, face);
  return count;
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

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_color_emoji_raster_pixels(void) {
  return -1;
}

#endif
