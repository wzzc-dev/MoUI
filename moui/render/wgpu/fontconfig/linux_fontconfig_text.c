#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(__linux__)
#include <limits.h>
#include <stdio.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_ADVANCES_H
#include <fontconfig/fontconfig.h>
#include <hb.h>
#include <hb-ft.h>
#endif

#define MOUI_NATIVE_FONT_SPEC_VERSION 1
#define MOUI_NATIVE_FONT_REGISTRATION_VERSION 1
#define MOUI_FONTCONFIG_RUN_VERSION 1
#define MOUI_FONTCONFIG_RASTER_VERSION 1
#define MOUI_FONTCONFIG_GLYPH_PAYLOAD_VERSION 2
#define MOUI_FONTCONFIG_REGISTERED_FONT_LIMIT 64
#define MOUI_FONTCONFIG_SOURCE_PATH 0
#define MOUI_FONTCONFIG_SOURCE_REGISTERED 1

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
  const uint8_t *family_name;
  const uint8_t *data;
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
    out->family_name = src + 12;
    out->data = src + 12 + family_name_len;
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
  int32_t source_kind;
  int32_t glyph_id;
  int32_t codepoint;
  int32_t pixel_size;
  int32_t face_index;
  const uint8_t *path;
  int32_t path_len;
} MouiFontconfigGlyphPayload;

typedef struct {
  char *alias;
  uint8_t *data;
  int32_t data_len;
} MouiFontconfigRegisteredFont;

typedef struct {
  int32_t source_kind;
  char path[4096];
  int32_t path_len;
  int32_t face_index;
  int32_t registered_index;
} MouiFontconfigResolvedFont;

typedef struct {
  FT_Library library;
  FT_Face face;
} MouiFontconfigOpenFont;

static MouiFontconfigRegisteredFont
  moui_linux_registered_fonts[MOUI_FONTCONFIG_REGISTERED_FONT_LIMIT];
static int32_t moui_linux_registered_font_count = 0;

static moonbit_bytes_t moui_linux_empty_bytes(void) {
  return moonbit_make_bytes(0, 0);
}

static char *moui_linux_cstring_from_bytes(const uint8_t *bytes, int32_t len) {
  if (bytes == NULL || len <= 0) {
    return NULL;
  }
  char *out = (char *)malloc((size_t)len + 1u);
  if (out == NULL) {
    return NULL;
  }
  memcpy(out, bytes, (size_t)len);
  out[len] = '\0';
  return out;
}

static uint32_t moui_linux_hash_bytes(const uint8_t *bytes, int32_t len) {
  uint32_t hash = 2166136261u;
  for (int32_t i = 0; i < len; i++) {
    hash ^= (uint32_t)bytes[i];
    hash *= 16777619u;
  }
  return hash;
}

static int32_t moui_linux_ascii_lower(uint8_t ch) {
  if (ch >= 'A' && ch <= 'Z') {
    return (int32_t)(ch + ('a' - 'A'));
  }
  return (int32_t)ch;
}

static int32_t moui_linux_bytes_equal_ascii(
  const uint8_t *bytes,
  int32_t len,
  const char *ascii
) {
  int32_t ascii_len = (int32_t)strlen(ascii);
  if (len != ascii_len) {
    return 0;
  }
  for (int32_t i = 0; i < len; i++) {
    if (moui_linux_ascii_lower(bytes[i]) != (int32_t)ascii[i]) {
      return 0;
    }
  }
  return 1;
}

static const char *moui_linux_generic_family_name(
  const uint8_t *bytes,
  int32_t len
) {
  if (moui_linux_bytes_equal_ascii(bytes, len, "system-ui") ||
      moui_linux_bytes_equal_ascii(bytes, len, "ui-sans-serif") ||
      moui_linux_bytes_equal_ascii(bytes, len, "sans-serif")) {
    return "sans-serif";
  }
  if (moui_linux_bytes_equal_ascii(bytes, len, "ui-serif") ||
      moui_linux_bytes_equal_ascii(bytes, len, "serif")) {
    return "serif";
  }
  if (moui_linux_bytes_equal_ascii(bytes, len, "ui-monospace") ||
      moui_linux_bytes_equal_ascii(bytes, len, "monospace")) {
    return "monospace";
  }
  if (moui_linux_bytes_equal_ascii(bytes, len, "emoji")) {
    return "emoji";
  }
  return NULL;
}

static int32_t moui_linux_font_spec_family_at(
  MouiNativeFontSpec spec,
  int32_t target,
  const uint8_t **family,
  int32_t *family_len
) {
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
    if (i == target) {
      *family = cursor;
      *family_len = name_len;
      return 1;
    }
    cursor += name_len;
    remaining -= name_len;
  }
  return 0;
}

static int32_t moui_linux_registered_font_index(
  const uint8_t *family,
  int32_t family_len
) {
  if (family == NULL || family_len <= 0) {
    return -1;
  }
  for (int32_t i = 0; i < moui_linux_registered_font_count; i++) {
    char *alias = moui_linux_registered_fonts[i].alias;
    if (alias != NULL &&
        (int32_t)strlen(alias) == family_len &&
        memcmp(alias, family, (size_t)family_len) == 0) {
      return i;
    }
  }
  return -1;
}

static void moui_linux_store_registered_font(
  const uint8_t *alias_bytes,
  int32_t alias_len,
  const uint8_t *data,
  int32_t data_len
) {
  if (alias_bytes == NULL || alias_len <= 0 || data == NULL || data_len <= 0) {
    return;
  }
  char *alias = moui_linux_cstring_from_bytes(alias_bytes, alias_len);
  uint8_t *copy = (uint8_t *)malloc((size_t)data_len);
  if (alias == NULL || copy == NULL) {
    free(alias);
    free(copy);
    return;
  }
  memcpy(copy, data, (size_t)data_len);
  for (int32_t i = 0; i < moui_linux_registered_font_count; i++) {
    if (strcmp(moui_linux_registered_fonts[i].alias, alias) == 0) {
      free(moui_linux_registered_fonts[i].data);
      moui_linux_registered_fonts[i].data = copy;
      moui_linux_registered_fonts[i].data_len = data_len;
      free(alias);
      return;
    }
  }
  if (moui_linux_registered_font_count >= MOUI_FONTCONFIG_REGISTERED_FONT_LIMIT) {
    free(alias);
    free(copy);
    return;
  }
  moui_linux_registered_fonts[moui_linux_registered_font_count].alias = alias;
  moui_linux_registered_fonts[moui_linux_registered_font_count].data = copy;
  moui_linux_registered_fonts[moui_linux_registered_font_count].data_len = data_len;
  moui_linux_registered_font_count++;
}

static int32_t moui_linux_fontconfig_weight(int32_t css_weight) {
  if (css_weight <= 200) {
    return FC_WEIGHT_LIGHT;
  }
  if (css_weight <= 350) {
    return FC_WEIGHT_BOOK;
  }
  if (css_weight < 600) {
    return FC_WEIGHT_REGULAR;
  }
  if (css_weight < 700) {
    return FC_WEIGHT_DEMIBOLD;
  }
  if (css_weight < 800) {
    return FC_WEIGHT_BOLD;
  }
  return FC_WEIGHT_BLACK;
}

static int32_t moui_linux_font_spec_has_emoji_family(MouiNativeFontSpec spec);
static int32_t moui_linux_find_emoji_font(char *out, int32_t cap);

static int32_t moui_linux_resolve_registered_font(
  MouiNativeFontSpec spec,
  MouiFontconfigResolvedFont *out
) {
  for (int32_t i = 0; i < spec.family_count; i++) {
    const uint8_t *family = NULL;
    int32_t family_len = 0;
    if (!moui_linux_font_spec_family_at(spec, i, &family, &family_len)) {
      return 0;
    }
    int32_t registered_index = moui_linux_registered_font_index(
      family,
      family_len
    );
    if (registered_index >= 0) {
      memset(out, 0, sizeof(*out));
      out->source_kind = MOUI_FONTCONFIG_SOURCE_REGISTERED;
      out->registered_index = registered_index;
      return 1;
    }
  }
  return 0;
}

static int32_t moui_linux_resolve_fontconfig_font(
  MouiNativeFontSpec spec,
  MouiFontconfigResolvedFont *out
) {
  if (!FcInit()) {
    return 0;
  }
  FcPattern *pattern = FcPatternCreate();
  if (pattern == NULL) {
    return 0;
  }
  for (int32_t i = 0; i < spec.family_count; i++) {
    const uint8_t *family_bytes = NULL;
    int32_t family_len = 0;
    if (!moui_linux_font_spec_family_at(spec, i, &family_bytes, &family_len)) {
      FcPatternDestroy(pattern);
      return 0;
    }
    const char *generic = moui_linux_generic_family_name(family_bytes, family_len);
    char *family = generic != NULL
      ? moui_linux_cstring_from_bytes((const uint8_t *)generic, (int32_t)strlen(generic))
      : moui_linux_cstring_from_bytes(family_bytes, family_len);
    if (family == NULL) {
      FcPatternDestroy(pattern);
      return 0;
    }
    FcPatternAddString(pattern, FC_FAMILY, (const FcChar8 *)family);
    free(family);
  }
  FcPatternAddInteger(pattern, FC_WEIGHT, moui_linux_fontconfig_weight(spec.weight));
  FcPatternAddInteger(
    pattern,
    FC_SLANT,
    spec.style == 1 ? FC_SLANT_ITALIC : FC_SLANT_ROMAN
  );
  FcConfigSubstitute(NULL, pattern, FcMatchPattern);
  FcDefaultSubstitute(pattern);
  FcResult result = FcResultNoMatch;
  FcPattern *match = FcFontMatch(NULL, pattern, &result);
  FcPatternDestroy(pattern);
  if (match == NULL || result != FcResultMatch) {
    if (match != NULL) {
      FcPatternDestroy(match);
    }
    return 0;
  }
  FcChar8 *file = NULL;
  int32_t face_index = 0;
  if (FcPatternGetString(match, FC_FILE, 0, &file) != FcResultMatch ||
      file == NULL) {
    FcPatternDestroy(match);
    return 0;
  }
  (void)FcPatternGetInteger(match, FC_INDEX, 0, &face_index);
  int32_t path_len = (int32_t)strlen((const char *)file);
  if (path_len <= 0 || path_len >= (int32_t)sizeof(out->path)) {
    FcPatternDestroy(match);
    return 0;
  }
  memset(out, 0, sizeof(*out));
  out->source_kind = MOUI_FONTCONFIG_SOURCE_PATH;
  out->path_len = path_len;
  out->face_index = face_index;
  out->registered_index = -1;
  memcpy(out->path, file, (size_t)path_len + 1u);
  FcPatternDestroy(match);
  return 1;
}

static int32_t moui_linux_resolve_font(
  MouiNativeFontSpec spec,
  MouiFontconfigResolvedFont *out
) {
  if (moui_linux_resolve_registered_font(spec, out)) {
    return 1;
  }
  if (moui_linux_resolve_fontconfig_font(spec, out)) {
    return 1;
  }
  if (moui_linux_font_spec_has_emoji_family(spec)) {
    char font_path[4096];
    int32_t path_len = moui_linux_find_emoji_font(
      font_path,
      (int32_t)sizeof(font_path)
    );
    if (path_len > 0) {
      memset(out, 0, sizeof(*out));
      out->source_kind = MOUI_FONTCONFIG_SOURCE_PATH;
      out->path_len = path_len;
      out->face_index = 0;
      out->registered_index = -1;
      memcpy(out->path, font_path, (size_t)path_len + 1u);
      return 1;
    }
  }
  return 0;
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
  FT_Face face,
  int32_t pixel_size
) {
  if (FT_Set_Pixel_Sizes(face, 0, (FT_UInt)pixel_size) == 0) {
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
  return FT_Select_Size(face, best) == 0;
}

static int32_t moui_linux_open_resolved_font(
  MouiFontconfigResolvedFont resolved,
  int32_t pixel_size,
  MouiFontconfigOpenFont *open
) {
  memset(open, 0, sizeof(*open));
  if (FT_Init_FreeType(&open->library) != 0) {
    return 0;
  }
  int ok = 0;
  if (resolved.source_kind == MOUI_FONTCONFIG_SOURCE_REGISTERED) {
    int32_t index = resolved.registered_index;
    if (index >= 0 && index < moui_linux_registered_font_count) {
      MouiFontconfigRegisteredFont registered = moui_linux_registered_fonts[index];
      if (registered.data != NULL && registered.data_len > 0) {
        ok = FT_New_Memory_Face(
          open->library,
          (const FT_Byte *)registered.data,
          (FT_Long)registered.data_len,
          0,
          &open->face
        ) == 0;
      }
    }
  } else {
    ok = FT_New_Face(
      open->library,
      resolved.path,
      (FT_Long)resolved.face_index,
      &open->face
    ) == 0;
  }
  if (!ok || open->face == NULL) {
    FT_Done_FreeType(open->library);
    memset(open, 0, sizeof(*open));
    return 0;
  }
  if (!moui_linux_select_freetype_size(open->face, pixel_size)) {
    FT_Done_Face(open->face);
    FT_Done_FreeType(open->library);
    memset(open, 0, sizeof(*open));
    return 0;
  }
  return 1;
}

static void moui_linux_close_resolved_font(MouiFontconfigOpenFont *open) {
  if (open->face != NULL) {
    FT_Done_Face(open->face);
  }
  if (open->library != NULL) {
    FT_Done_FreeType(open->library);
  }
  memset(open, 0, sizeof(*open));
}

static int32_t moui_linux_utf32_codepoints(
  moonbit_bytes_t utf32,
  uint32_t **out,
  int32_t *out_count
) {
  int32_t len = (int32_t)Moonbit_array_length(utf32);
  if (len < 0 || (len % 4) != 0) {
    return 0;
  }
  int32_t count = len / 4;
  uint32_t *codepoints = NULL;
  if (count > 0) {
    codepoints = (uint32_t *)malloc((size_t)count * sizeof(uint32_t));
    if (codepoints == NULL) {
      return 0;
    }
    const uint8_t *src = (const uint8_t *)utf32;
    for (int32_t i = 0; i < count; i++) {
      codepoints[i] = moui_read_u32_le(src + i * 4);
    }
  }
  *out = codepoints;
  *out_count = count;
  return 1;
}

static double moui_linux_metric_26_6_to_logical(
  FT_Pos value,
  double scale_factor
) {
  double scale = scale_factor > 0.0 ? scale_factor : 1.0;
  return ((double)value / 64.0) / scale;
}

static void moui_linux_font_metrics(
  FT_Face face,
  int32_t pixel_size,
  double scale_factor,
  double *height,
  double *baseline
) {
  double scale = scale_factor > 0.0 ? scale_factor : 1.0;
  double metric_height = 0.0;
  double metric_baseline = 0.0;
  if (face != NULL && face->size != NULL) {
    metric_height = moui_linux_metric_26_6_to_logical(
      face->size->metrics.height,
      scale
    );
    metric_baseline = moui_linux_metric_26_6_to_logical(
      face->size->metrics.ascender,
      scale
    );
  }
  if (metric_height <= 0.0) {
    metric_height = ((double)pixel_size * 1.25) / scale;
  }
  if (metric_baseline <= 0.0 || metric_baseline > metric_height) {
    metric_baseline = ((double)pixel_size) / scale;
  }
  *height = metric_height;
  *baseline = metric_baseline;
}

static hb_buffer_t *moui_linux_shape_buffer(
  FT_Face face,
  const uint32_t *codepoints,
  int32_t count,
  hb_font_t **font_out
) {
  *font_out = NULL;
  hb_font_t *font = hb_ft_font_create(face, NULL);
  if (font == NULL) {
    return NULL;
  }
  hb_buffer_t *buffer = hb_buffer_create();
  if (buffer == NULL) {
    hb_font_destroy(font);
    return NULL;
  }
  hb_buffer_add_utf32(
    buffer,
    (const hb_codepoint_t *)codepoints,
    count,
    0,
    count
  );
  hb_buffer_guess_segment_properties(buffer);
  hb_shape(font, buffer, NULL, 0);
  *font_out = font;
  return buffer;
}

// Sum glyph advances directly from FreeType, bypassing HarfBuzz shaping. This
// is used as a safe fallback for measurement when hb_shape() cannot be used:
// when this stub is linked into an image that also statically links Skia's
// bundled FreeType (a different version than the system libfreetype HarfBuzz
// was built against), hb_ft_font_create installs callbacks that dereference
// FT structs with mismatched offsets and segfault. FreeType's public opaque
// handle API (FT_Get_Char_Index / FT_Load_Glyph / FT_Get_Advance) is ABI-stable
// across those versions, so reading advances directly here is safe and yields a
// correct-enough width for the diagnostic conformance matrix (complex-script
// shaping is intentionally out of scope for this scaffold measurement path).
static double moui_linux_freetype_advance_width(
  FT_Face face,
  const uint32_t *codepoints,
  int32_t char_count,
  int32_t *covered_out
) {
  double width = 0.0;
  int32_t covered = 0;
  for (int32_t i = 0; i < char_count; i++) {
    FT_UInt glyph_id = FT_Get_Char_Index(face, (FT_ULong)codepoints[i]);
    if (glyph_id == 0) {
      // Character not covered by the resolved font. Return -1.0 so the caller
      // can signal incomplete coverage (empty payload), letting the configured
      // fallback engine (e.g. cosmic_text) take over for this text.
      if (covered_out != NULL) {
        *covered_out = 0;
      }
      return -1.0;
    }
    // FT_Load_Glyph with FT_LOAD_DEFAULT yields glyph->advance.x already scaled
    // to the active pixel size, in 26.6 fixed point (matching HarfBuzz's
    // hb_glyph_position units). This mirrors the existing raster path, which is
    // known to work against the statically-linked FreeType.
    if (FT_Load_Glyph(face, glyph_id, FT_LOAD_DEFAULT) == 0) {
      width += (double)face->glyph->advance.x / 64.0;
      covered++;
    }
  }
  if (covered_out != NULL) {
    *covered_out = covered;
  }
  return width;
}

static moonbit_bytes_t moui_linux_write_measure_payload(
  int32_t char_count,
  double width,
  double height,
  double baseline
) {
  if (char_count < 0 || char_count > (INT32_MAX - 24) / 8 - 1) {
    return moui_linux_empty_bytes();
  }
  int32_t caret_count = char_count + 1;
  moonbit_bytes_t out = moonbit_make_bytes(24 + caret_count * 8, 0);
  uint8_t *dst = (uint8_t *)out;
  moui_write_i32_le(dst, char_count);
  moui_write_i32_le(dst + 4, MOUI_FONTCONFIG_RUN_VERSION);
  moui_write_double_le(dst + 8, height);
  moui_write_double_le(dst + 16, baseline);
  for (int32_t i = 0; i < caret_count; i++) {
    double caret = char_count == 0
      ? 0.0
      : width * ((double)i / (double)char_count);
    moui_write_double_le(dst + 24 + i * 8, caret);
  }
  return out;
}

static int32_t moui_linux_payload_source_bytes(
  MouiFontconfigResolvedFont resolved,
  const uint8_t **source,
  int32_t *source_len
) {
  if (resolved.source_kind == MOUI_FONTCONFIG_SOURCE_REGISTERED) {
    int32_t index = resolved.registered_index;
    if (index < 0 || index >= moui_linux_registered_font_count ||
        moui_linux_registered_fonts[index].alias == NULL) {
      return 0;
    }
    *source = (const uint8_t *)moui_linux_registered_fonts[index].alias;
    *source_len = (int32_t)strlen(moui_linux_registered_fonts[index].alias);
    return *source_len > 0;
  }
  *source = (const uint8_t *)resolved.path;
  *source_len = resolved.path_len;
  return *source_len > 0;
}

static uint32_t moui_linux_cache_source_hash(
  MouiFontconfigResolvedFont resolved
) {
  if (resolved.source_kind == MOUI_FONTCONFIG_SOURCE_REGISTERED) {
    int32_t index = resolved.registered_index;
    if (index >= 0 && index < moui_linux_registered_font_count &&
        moui_linux_registered_fonts[index].data != NULL &&
        moui_linux_registered_fonts[index].data_len > 0) {
      return moui_linux_hash_bytes(
        moui_linux_registered_fonts[index].data,
        moui_linux_registered_fonts[index].data_len
      );
    }
  }
  return moui_linux_hash_bytes((const uint8_t *)resolved.path, resolved.path_len);
}

static int32_t moui_linux_open_emoji_face(
  const char *path,
  int32_t pixel_size,
  FT_Library *library,
  FT_Face *face
) {
  *library = NULL;
  *face = NULL;
  if (FT_Init_FreeType(library) != 0) {
    return 0;
  }
  if (FT_New_Face(*library, path, 0, face) != 0) {
    FT_Done_FreeType(*library);
    *library = NULL;
    return 0;
  }
  if (!moui_linux_select_freetype_size(*face, pixel_size)) {
    FT_Done_Face(*face);
    FT_Done_FreeType(*library);
    *face = NULL;
    *library = NULL;
    return 0;
  }
  return 1;
}

static void moui_linux_close_emoji_face(
  FT_Library library,
  FT_Face face
) {
  if (face != NULL) {
    FT_Done_Face(face);
  }
  if (library != NULL) {
    FT_Done_FreeType(library);
  }
}

static int32_t moui_linux_parse_glyph_payload(
  moonbit_bytes_t payload,
  MouiFontconfigGlyphPayload *out
) {
  int32_t len = (int32_t)Moonbit_array_length(payload);
  if (len < 28) {
    return 0;
  }
  const uint8_t *src = (const uint8_t *)payload;
  int32_t version = moui_read_i32_le(src);
  int32_t source_kind = moui_read_i32_le(src + 4);
  int32_t path_len = moui_read_i32_le(src + 24);
  if (version != MOUI_FONTCONFIG_GLYPH_PAYLOAD_VERSION ||
      (source_kind != MOUI_FONTCONFIG_SOURCE_PATH &&
       source_kind != MOUI_FONTCONFIG_SOURCE_REGISTERED) ||
      path_len <= 0 ||
      path_len > len - 28 ||
      len != 28 + path_len) {
    return 0;
  }
  if (out != NULL) {
    out->source_kind = source_kind;
    out->glyph_id = moui_read_i32_le(src + 8);
    out->codepoint = moui_read_i32_le(src + 12);
    out->pixel_size = moui_read_i32_le(src + 16);
    out->face_index = moui_read_i32_le(src + 20);
    out->path_len = path_len;
    out->path = src + 28;
  }
  return 1;
}

static void moui_linux_write_glyph_payload(
  uint8_t *dst,
  MouiFontconfigResolvedFont resolved,
  int32_t glyph_id,
  uint32_t codepoint,
  int32_t pixel_size,
  const uint8_t *source,
  int32_t source_len
) {
  moui_write_i32_le(dst, MOUI_FONTCONFIG_GLYPH_PAYLOAD_VERSION);
  moui_write_i32_le(dst + 4, resolved.source_kind);
  moui_write_i32_le(dst + 8, glyph_id);
  moui_write_i32_le(dst + 12, (int32_t)codepoint);
  moui_write_i32_le(dst + 16, pixel_size);
  moui_write_i32_le(dst + 20, resolved.face_index);
  moui_write_i32_le(dst + 24, source_len);
  memcpy(dst + 28, source, (size_t)source_len);
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

static double moui_linux_hb_position_to_logical(
  int32_t value,
  double scale_factor
) {
  double scale = scale_factor > 0.0 ? scale_factor : 1.0;
  return ((double)value / 64.0) / scale;
}

static int32_t moui_linux_glyph_has_visible_bounds(
  MouiFontconfigOpenFont *open,
  uint32_t glyph_id
) {
  if (glyph_id == 0 || open == NULL || open->face == NULL) {
    return 0;
  }
  if (FT_Load_Glyph(
        open->face,
        (FT_UInt)glyph_id,
        FT_LOAD_COLOR | FT_LOAD_DEFAULT
      ) != 0) {
    return 0;
  }
  FT_GlyphSlot slot = open->face->glyph;
  if (slot->format == FT_GLYPH_FORMAT_BITMAP) {
    return slot->bitmap.width > 0 && slot->bitmap.rows > 0;
  }
  return slot->metrics.width > 0 && slot->metrics.height > 0;
}

static double moui_linux_shaped_width(
  const hb_glyph_position_t *positions,
  unsigned int glyph_count,
  double scale_factor
) {
  double width = 0.0;
  for (unsigned int i = 0; i < glyph_count; i++) {
    width += moui_linux_hb_position_to_logical(
      positions[i].x_advance,
      scale_factor
    );
  }
  return width >= 0.0 ? width : -width;
}

static moonbit_bytes_t moui_linux_write_run_payload(
  hb_glyph_info_t *infos,
  hb_glyph_position_t *positions,
  unsigned int shaped_count,
  const uint32_t *codepoints,
  int32_t char_count,
  MouiFontconfigResolvedFont resolved,
  MouiFontconfigOpenFont *open,
  int32_t pixel_size,
  double scale_factor,
  double width,
  double height,
  double baseline
) {
  const uint8_t *source = NULL;
  int32_t source_len = 0;
  if (!moui_linux_payload_source_bytes(resolved, &source, &source_len)) {
    return moui_linux_empty_bytes();
  }
  uint32_t source_hash = moui_linux_cache_source_hash(resolved);
  int32_t visible_count = 0;
  int64_t out_len = 32;
  for (unsigned int i = 0; i < shaped_count; i++) {
    uint32_t glyph_id = infos[i].codepoint;
    if (!moui_linux_glyph_has_visible_bounds(open, glyph_id)) {
      continue;
    }
    char cache_key[160];
    int key_len = snprintf(
      cache_key,
      sizeof(cache_key),
      "fontconfig:%d:%08x:%d:%u:%d",
      resolved.source_kind,
      (unsigned int)source_hash,
      resolved.face_index,
      (unsigned int)glyph_id,
      pixel_size
    );
    if (key_len <= 0 || key_len >= (int)sizeof(cache_key)) {
      continue;
    }
    visible_count++;
    out_len += 24 + key_len + 28 + source_len;
    if (out_len > INT32_MAX) {
      return moui_linux_empty_bytes();
    }
  }

  moonbit_bytes_t out = moonbit_make_bytes((int32_t)out_len, 0);
  uint8_t *dst = (uint8_t *)out;
  moui_write_i32_le(dst, MOUI_FONTCONFIG_RUN_VERSION);
  moui_write_i32_le(dst + 4, visible_count);
  moui_write_double_le(dst + 8, width);
  moui_write_double_le(dst + 16, height);
  moui_write_double_le(dst + 24, baseline);
  int32_t offset = 32;
  double cursor_x = 0.0;
  for (unsigned int i = 0; i < shaped_count; i++) {
    uint32_t glyph_id = infos[i].codepoint;
    uint32_t cluster = infos[i].cluster;
    uint32_t codepoint = cluster < (uint32_t)char_count
      ? codepoints[cluster]
      : 0u;
    double glyph_x = cursor_x + moui_linux_hb_position_to_logical(
      positions[i].x_offset,
      scale_factor
    );
    double glyph_y = -moui_linux_hb_position_to_logical(
      positions[i].y_offset,
      scale_factor
    );
    double advance = moui_linux_hb_position_to_logical(
      positions[i].x_advance,
      scale_factor
    );
    cursor_x += advance;
    if (!moui_linux_glyph_has_visible_bounds(open, glyph_id)) {
      continue;
    }
    char cache_key[160];
    int key_len = snprintf(
      cache_key,
      sizeof(cache_key),
      "fontconfig:%d:%08x:%d:%u:%d",
      resolved.source_kind,
      (unsigned int)source_hash,
      resolved.face_index,
      (unsigned int)glyph_id,
      pixel_size
    );
    if (key_len <= 0 || key_len >= (int)sizeof(cache_key)) {
      continue;
    }
    int32_t payload_len = 28 + source_len;
    moui_write_double_le(dst + offset, glyph_x);
    moui_write_double_le(dst + offset + 8, glyph_y);
    moui_write_i32_le(dst + offset + 16, key_len);
    moui_write_i32_le(dst + offset + 20, payload_len);
    memcpy(dst + offset + 24, cache_key, (size_t)key_len);
    moui_linux_write_glyph_payload(
      dst + offset + 24 + key_len,
      resolved,
      (int32_t)glyph_id,
      codepoint,
      pixel_size,
      source,
      source_len
    );
    offset += 24 + key_len + payload_len;
  }
  return out;
}

static int32_t moui_linux_resolved_font_from_payload(
  MouiFontconfigGlyphPayload parsed,
  MouiFontconfigResolvedFont *resolved
) {
  memset(resolved, 0, sizeof(*resolved));
  resolved->source_kind = parsed.source_kind;
  resolved->face_index = parsed.face_index;
  resolved->registered_index = -1;
  if (parsed.source_kind == MOUI_FONTCONFIG_SOURCE_REGISTERED) {
    int32_t index = moui_linux_registered_font_index(
      parsed.path,
      parsed.path_len
    );
    if (index < 0) {
      return 0;
    }
    resolved->registered_index = index;
    return 1;
  }
  if (parsed.path_len <= 0 ||
      parsed.path_len >= (int32_t)sizeof(resolved->path)) {
    return 0;
  }
  resolved->path_len = parsed.path_len;
  memcpy(resolved->path, parsed.path, (size_t)parsed.path_len);
  resolved->path[parsed.path_len] = '\0';
  return 1;
}

static moonbit_bytes_t moui_linux_raster_loaded_glyph(
  FT_GlyphSlot slot,
  int32_t pixel_size
) {
  FT_Bitmap bitmap = slot->bitmap;
  if (bitmap.width <= 0 || bitmap.rows <= 0 || bitmap.buffer == NULL) {
    return moui_linux_empty_bytes();
  }
  int32_t format = -1;
  int32_t bytes_per_pixel = 0;
  if (bitmap.pixel_mode == FT_PIXEL_MODE_BGRA) {
    format = 1;
    bytes_per_pixel = 4;
  } else if (bitmap.pixel_mode == FT_PIXEL_MODE_GRAY ||
             bitmap.pixel_mode == FT_PIXEL_MODE_MONO) {
    format = 0;
    bytes_per_pixel = 1;
  } else {
    return moui_linux_empty_bytes();
  }
  int32_t width = (int32_t)bitmap.width;
  int32_t height = (int32_t)bitmap.rows;
  int64_t pixel_len = (int64_t)width * (int64_t)height * bytes_per_pixel;
  if (pixel_len <= 0 || pixel_len > INT32_MAX - 32) {
    return moui_linux_empty_bytes();
  }
  moonbit_bytes_t out = moonbit_make_bytes(32 + (int32_t)pixel_len, 0);
  uint8_t *dst = (uint8_t *)out;
  moui_write_i32_le(dst, width);
  moui_write_i32_le(dst + 4, height);
  moui_write_i32_le(dst + 8, slot->bitmap_left);
  moui_write_i32_le(dst + 12, -slot->bitmap_top);
  moui_write_i32_le(dst + 16, MOUI_FONTCONFIG_RASTER_VERSION);
  moui_write_i32_le(dst + 20, format);
  moui_write_double_le(
    dst + 24,
    slot->advance.x > 0 ? ((double)slot->advance.x / 64.0) : (double)pixel_size
  );
  if (bitmap.pixel_mode == FT_PIXEL_MODE_BGRA) {
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
  } else if (bitmap.pixel_mode == FT_PIXEL_MODE_GRAY) {
    for (int32_t y = 0; y < height; y++) {
      const uint8_t *row = bitmap.pitch >= 0
        ? bitmap.buffer + y * bitmap.pitch
        : bitmap.buffer + (height - 1 - y) * (-bitmap.pitch);
      memcpy(dst + 32 + y * width, row, (size_t)width);
    }
  } else {
    for (int32_t y = 0; y < height; y++) {
      const uint8_t *row = bitmap.pitch >= 0
        ? bitmap.buffer + y * bitmap.pitch
        : bitmap.buffer + (height - 1 - y) * (-bitmap.pitch);
      for (int32_t x = 0; x < width; x++) {
        uint8_t byte = row[x >> 3];
        uint8_t bit = (uint8_t)(0x80u >> (x & 7));
        dst[32 + y * width + x] = (byte & bit) != 0 ? 255 : 0;
      }
    }
  }
  return out;
}

static MouiNativeFontSpec moui_linux_debug_sans_spec(uint8_t *families) {
  moui_write_i32_le(families, 10);
  memcpy(families + 4, "sans-serif", 10);
  MouiNativeFontSpec spec = {
    .size_key = 18 * 64,
    .weight = 400,
    .style = 0,
    .family_count = 1,
    .families = families,
    .families_len = 14,
  };
  return spec;
}

static int32_t moui_linux_bitmap_visible_pixel_count(FT_Bitmap bitmap) {
  if (bitmap.width <= 0 || bitmap.rows <= 0 || bitmap.buffer == NULL) {
    return 0;
  }
  int32_t width = (int32_t)bitmap.width;
  int32_t height = (int32_t)bitmap.rows;
  int32_t count = 0;
  for (int32_t y = 0; y < height; y++) {
    const uint8_t *row = bitmap.pitch >= 0
      ? bitmap.buffer + y * bitmap.pitch
      : bitmap.buffer + (height - 1 - y) * (-bitmap.pitch);
    if (bitmap.pixel_mode == FT_PIXEL_MODE_BGRA) {
      for (int32_t x = 0; x < width; x++) {
        if (row[x * 4 + 3] != 0) {
          count++;
        }
      }
    } else if (bitmap.pixel_mode == FT_PIXEL_MODE_GRAY) {
      for (int32_t x = 0; x < width; x++) {
        if (row[x] != 0) {
          count++;
        }
      }
    } else if (bitmap.pixel_mode == FT_PIXEL_MODE_MONO) {
      for (int32_t x = 0; x < width; x++) {
        uint8_t byte = row[x >> 3];
        uint8_t bit = (uint8_t)(0x80u >> (x & 7));
        if ((byte & bit) != 0) {
          count++;
        }
      }
    }
  }
  return count;
}

static uint8_t *moui_linux_read_file_bytes(
  const char *path,
  int32_t *out_len
) {
  *out_len = 0;
  FILE *file = fopen(path, "rb");
  if (file == NULL) {
    return NULL;
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return NULL;
  }
  long len = ftell(file);
  if (len <= 0 || len > INT32_MAX || fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return NULL;
  }
  uint8_t *data = (uint8_t *)malloc((size_t)len);
  if (data == NULL) {
    fclose(file);
    return NULL;
  }
  size_t read_len = fread(data, 1, (size_t)len, file);
  fclose(file);
  if (read_len != (size_t)len) {
    free(data);
    return NULL;
  }
  *out_len = (int32_t)len;
  return data;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_measure_utf32(
  moonbit_bytes_t utf32,
  moonbit_bytes_t font_spec
) {
  MouiNativeFontSpec spec = {0};
  if (!moui_linux_parse_font_spec(font_spec, &spec)) {
    return moui_linux_empty_bytes();
  }
  uint32_t *codepoints = NULL;
  int32_t char_count = 0;
  if (!moui_linux_utf32_codepoints(utf32, &codepoints, &char_count)) {
    return moui_linux_empty_bytes();
  }
  MouiFontconfigResolvedFont resolved = {0};
  if (!moui_linux_resolve_font(spec, &resolved)) {
    free(codepoints);
    return moui_linux_empty_bytes();
  }
  int32_t pixel_size = moui_linux_pixel_size(spec, 1.0);
  MouiFontconfigOpenFont open = {0};
  if (!moui_linux_open_resolved_font(resolved, pixel_size, &open)) {
    free(codepoints);
    return moui_linux_empty_bytes();
  }
  double height = 0.0;
  double baseline = 0.0;
  moui_linux_font_metrics(open.face, pixel_size, 1.0, &height, &baseline);
  if (char_count == 0) {
    moui_linux_close_resolved_font(&open);
    free(codepoints);
    return moui_linux_write_measure_payload(0, 0.0, height, baseline);
  }
  // Measurement uses a safe FreeType advance summation instead of HarfBuzz
  // shaping. See moui_linux_freetype_advance_width: hb_shape() segfaults in
  // images that also statically link Skia's bundled FreeType (a different
  // version than the system libfreetype HarfBuzz was built against). FreeType's
  // opaque-handle advance API is ABI-stable, so this is safe and yields a
  // correct-enough width for the diagnostic conformance matrix.
  int32_t covered = 0;
  double width = moui_linux_freetype_advance_width(
    open.face,
    codepoints,
    char_count,
    &covered
  );
  if (width < 0.0 || covered <= 0) {
    // Incomplete character coverage: signal failure with an empty payload so
    // the configured fallback engine (e.g. cosmic_text) handles this text.
    moui_linux_close_resolved_font(&open);
    free(codepoints);
    return moui_linux_empty_bytes();
  }
  moonbit_bytes_t out = moui_linux_write_measure_payload(
    char_count,
    width,
    height,
    baseline
  );
  moui_linux_close_resolved_font(&open);
  free(codepoints);
  return out;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_fontconfig_layout_run_utf32(
  moonbit_bytes_t utf32,
  moonbit_bytes_t font_spec,
  double max_width,
  double scale_factor
) {
  int32_t len = (int32_t)Moonbit_array_length(utf32);
  if (len < 0 || (len % 4) != 0) {
    return moui_linux_empty_bytes();
  }
  MouiNativeFontSpec spec = {0};
  if (!moui_linux_parse_font_spec(font_spec, &spec)) {
    return moui_linux_empty_bytes();
  }
  uint32_t *codepoints = NULL;
  int32_t char_count = 0;
  if (!moui_linux_utf32_codepoints(utf32, &codepoints, &char_count)) {
    return moui_linux_empty_bytes();
  }
  MouiFontconfigResolvedFont resolved = {0};
  if (!moui_linux_resolve_font(spec, &resolved)) {
    free(codepoints);
    return moui_linux_empty_bytes();
  }
  int32_t pixel_size = moui_linux_pixel_size(spec, scale_factor);
  MouiFontconfigOpenFont open = {0};
  if (!moui_linux_open_resolved_font(resolved, pixel_size, &open)) {
    free(codepoints);
    return moui_linux_empty_bytes();
  }
  double height = 0.0;
  double baseline = 0.0;
  moui_linux_font_metrics(open.face, pixel_size, scale_factor, &height, &baseline);
  if (char_count == 0) {
    moonbit_bytes_t out = moonbit_make_bytes(32, 0);
    uint8_t *dst = (uint8_t *)out;
    moui_write_i32_le(dst, MOUI_FONTCONFIG_RUN_VERSION);
    moui_write_i32_le(dst + 4, 0);
    moui_write_double_le(dst + 8, 0.0);
    moui_write_double_le(dst + 16, height);
    moui_write_double_le(dst + 24, baseline);
    moui_linux_close_resolved_font(&open);
    free(codepoints);
    return out;
  }
  hb_font_t *hb_font = NULL;
  hb_buffer_t *buffer = moui_linux_shape_buffer(
    open.face,
    codepoints,
    char_count,
    &hb_font
  );
  if (buffer == NULL) {
    moui_linux_close_resolved_font(&open);
    free(codepoints);
    return moui_linux_empty_bytes();
  }
  unsigned int shaped_count = 0;
  hb_glyph_info_t *infos = hb_buffer_get_glyph_infos(buffer, &shaped_count);
  hb_glyph_position_t *positions = hb_buffer_get_glyph_positions(
    buffer,
    &shaped_count
  );
  double width = positions != NULL
    ? moui_linux_shaped_width(positions, shaped_count, scale_factor)
    : 0.0;
  if (max_width > 0.0 && width > max_width) {
    width = max_width;
  }
  moonbit_bytes_t out = infos != NULL && positions != NULL
    ? moui_linux_write_run_payload(
        infos,
        positions,
        shaped_count,
        codepoints,
        char_count,
        resolved,
        &open,
        pixel_size,
        scale_factor,
        width,
        height,
        baseline
      )
    : moui_linux_empty_bytes();
  hb_buffer_destroy(buffer);
  hb_font_destroy(hb_font);
  moui_linux_close_resolved_font(&open);
  free(codepoints);
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
  MouiFontconfigResolvedFont resolved = {0};
  if (!moui_linux_resolved_font_from_payload(parsed, &resolved)) {
    return moui_linux_empty_bytes();
  }
  MouiFontconfigOpenFont open = {0};
  if (!moui_linux_open_resolved_font(resolved, parsed.pixel_size, &open)) {
    return moui_linux_empty_bytes();
  }
  FT_UInt glyph_id = (FT_UInt)parsed.glyph_id;
  if (FT_Load_Glyph(open.face, glyph_id, FT_LOAD_COLOR | FT_LOAD_DEFAULT) != 0) {
    moui_linux_close_resolved_font(&open);
    return moui_linux_empty_bytes();
  }
  FT_GlyphSlot slot = open.face->glyph;
  if (slot->format != FT_GLYPH_FORMAT_BITMAP &&
      FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL) != 0) {
    moui_linux_close_resolved_font(&open);
    return moui_linux_empty_bytes();
  }
  moonbit_bytes_t out = moui_linux_raster_loaded_glyph(slot, parsed.pixel_size);
  moui_linux_close_resolved_font(&open);
  return out;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_register_font_data(
  moonbit_bytes_t payload
) {
  MouiNativeFontRegistration registration = {0};
  if (!moui_linux_parse_font_registration(payload, &registration)) {
    return 0;
  }
  moui_linux_store_registered_font(
    registration.family_name,
    registration.family_name_len,
    registration.data,
    registration.data_len
  );
  return moui_linux_registered_font_index(
    registration.family_name,
    registration.family_name_len
  ) >= 0 ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_registered_font_data_len(
  moonbit_bytes_t family_name
) {
  const uint8_t *bytes = (const uint8_t *)family_name;
  int32_t len = (int32_t)Moonbit_array_length(family_name);
  int32_t index = moui_linux_registered_font_index(bytes, len);
  if (index < 0) {
    return -1;
  }
  return moui_linux_registered_fonts[index].data_len;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_latin_raster_pixels(void) {
  uint8_t families[14];
  MouiNativeFontSpec spec = moui_linux_debug_sans_spec(families);
  MouiFontconfigResolvedFont resolved = {0};
  if (!moui_linux_resolve_font(spec, &resolved)) {
    return -1;
  }
  MouiFontconfigOpenFont open = {0};
  if (!moui_linux_open_resolved_font(resolved, 18, &open)) {
    return -1;
  }
  FT_UInt glyph_id = FT_Get_Char_Index(open.face, (FT_ULong)'A');
  if (glyph_id == 0 ||
      FT_Load_Glyph(open.face, glyph_id, FT_LOAD_DEFAULT) != 0) {
    moui_linux_close_resolved_font(&open);
    return 0;
  }
  FT_GlyphSlot slot = open.face->glyph;
  if (slot->format != FT_GLYPH_FORMAT_BITMAP &&
      FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL) != 0) {
    moui_linux_close_resolved_font(&open);
    return 0;
  }
  int32_t count = moui_linux_bitmap_visible_pixel_count(slot->bitmap);
  moui_linux_close_resolved_font(&open);
  return count;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_register_system_font_data(
  moonbit_bytes_t family_name
) {
  const uint8_t *alias = (const uint8_t *)family_name;
  int32_t alias_len = (int32_t)Moonbit_array_length(family_name);
  if (alias == NULL || alias_len <= 0) {
    return -1;
  }
  uint8_t families[14];
  MouiNativeFontSpec spec = moui_linux_debug_sans_spec(families);
  MouiFontconfigResolvedFont resolved = {0};
  if (!moui_linux_resolve_fontconfig_font(spec, &resolved) ||
      resolved.source_kind != MOUI_FONTCONFIG_SOURCE_PATH) {
    return -1;
  }
  int32_t data_len = 0;
  uint8_t *data = moui_linux_read_file_bytes(resolved.path, &data_len);
  if (data == NULL || data_len <= 0) {
    free(data);
    return -1;
  }
  moui_linux_store_registered_font(alias, alias_len, data, data_len);
  free(data);
  int32_t index = moui_linux_registered_font_index(alias, alias_len);
  return index >= 0 ? moui_linux_registered_fonts[index].data_len : -1;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_fontconfig_debug_color_emoji_raster_pixels(void) {
  char font_path[4096];
  int32_t path_len = moui_linux_find_emoji_font(font_path, (int32_t)sizeof(font_path));
  if (path_len <= 0) {
    return -1;
  }
  FT_Library library = NULL;
  FT_Face face = NULL;
  if (!moui_linux_open_emoji_face(font_path, 26, &library, &face)) {
    return -1;
  }
  FT_UInt glyph_id = FT_Get_Char_Index(face, (FT_ULong)0x1F642u);
  if (glyph_id == 0 ||
      FT_Load_Glyph(face, glyph_id, FT_LOAD_COLOR | FT_LOAD_DEFAULT) != 0) {
    moui_linux_close_emoji_face(library, face);
    return 0;
  }
  FT_GlyphSlot slot = face->glyph;
  if (slot->format != FT_GLYPH_FORMAT_BITMAP &&
      FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL) != 0) {
    moui_linux_close_emoji_face(library, face);
    return 0;
  }
  FT_Bitmap bitmap = slot->bitmap;
  if (bitmap.pixel_mode != FT_PIXEL_MODE_BGRA ||
      bitmap.width <= 0 ||
      bitmap.rows <= 0 ||
      bitmap.buffer == NULL) {
    moui_linux_close_emoji_face(library, face);
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
  moui_linux_close_emoji_face(library, face);
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
