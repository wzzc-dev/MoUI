#import <moonbit.h>
#import <limits.h>
#import <stdint.h>
#import <stdlib.h>
#import <string.h>

#if defined(__APPLE__)

#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>

#define MOUI_CORETEXT_LAYOUT_VERSION 1
#define MOUI_CORETEXT_RUN_VERSION 1
#define MOUI_CORETEXT_RASTER_VERSION 1
#define MOUI_NATIVE_FONT_SPEC_VERSION 1
#define MOUI_NATIVE_FONT_REGISTRATION_VERSION 1
#define MOUI_CORETEXT_REGISTERED_FONT_LIMIT 64

typedef struct {
  int32_t size_key;
  int32_t weight;
  int32_t style;
  int32_t family_count;
  const uint8_t *families;
  int32_t families_len;
} MouiCoreTextFontSpec;

typedef struct {
  const uint8_t *family_name;
  int32_t family_name_len;
  const uint8_t *data;
  int32_t data_len;
} MouiCoreTextFontRegistration;

typedef struct {
  char *alias;
  char *postscript_name;
} MouiCoreTextRegisteredFont;

static MouiCoreTextRegisteredFont moui_coretext_registered_fonts[MOUI_CORETEXT_REGISTERED_FONT_LIMIT];
static int32_t moui_coretext_registered_font_count = 0;

static uint32_t moui_read_u32_le(const uint8_t *p) {
  return ((uint32_t)p[0]) | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static int32_t moui_read_i32_le(const uint8_t *p) {
  return (int32_t)moui_read_u32_le(p);
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

static int32_t moui_coretext_parse_font_spec(moonbit_bytes_t bytes, MouiCoreTextFontSpec *out) {
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

static int32_t moui_coretext_parse_font_registration(moonbit_bytes_t bytes, MouiCoreTextFontRegistration *out) {
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
    out->family_name = src + 12;
    out->family_name_len = family_name_len;
    out->data = src + 12 + family_name_len;
    out->data_len = data_len;
  }
  return 1;
}

static char *moui_coretext_cstring_from_bytes(const uint8_t *bytes, int32_t len) {
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

static void moui_coretext_store_registered_font_alias(const uint8_t *alias_bytes, int32_t alias_len, const char *postscript_name) {
  if (alias_bytes == NULL || alias_len <= 0 || postscript_name == NULL || postscript_name[0] == '\0') {
    return;
  }
  char *alias = moui_coretext_cstring_from_bytes(alias_bytes, alias_len);
  char *name = moui_coretext_cstring_from_bytes((const uint8_t *)postscript_name, (int32_t)strlen(postscript_name));
  if (alias == NULL || name == NULL) {
    free(alias);
    free(name);
    return;
  }
  for (int32_t i = 0; i < moui_coretext_registered_font_count; i++) {
    if (strcmp(moui_coretext_registered_fonts[i].alias, alias) == 0) {
      free(moui_coretext_registered_fonts[i].postscript_name);
      moui_coretext_registered_fonts[i].postscript_name = name;
      free(alias);
      return;
    }
  }
  if (moui_coretext_registered_font_count >= MOUI_CORETEXT_REGISTERED_FONT_LIMIT) {
    free(alias);
    free(name);
    return;
  }
  moui_coretext_registered_fonts[moui_coretext_registered_font_count].alias = alias;
  moui_coretext_registered_fonts[moui_coretext_registered_font_count].postscript_name = name;
  moui_coretext_registered_font_count++;
}

static const char *moui_coretext_registered_postscript_name(const uint8_t *alias_bytes, int32_t alias_len) {
  if (alias_bytes == NULL || alias_len <= 0) {
    return NULL;
  }
  for (int32_t i = 0; i < moui_coretext_registered_font_count; i++) {
    char *alias = moui_coretext_registered_fonts[i].alias;
    if ((int32_t)strlen(alias) == alias_len && memcmp(alias, alias_bytes, (size_t)alias_len) == 0) {
      return moui_coretext_registered_fonts[i].postscript_name;
    }
  }
  return NULL;
}

static void moui_coretext_release_font_data(void *info, const void *data, size_t size) {
  (void)info;
  (void)size;
  free((void *)data);
}

static NSString *moui_string_from_utf32_codepoint(uint32_t codepoint) {
  if (codepoint <= 0xffffu) {
    unichar ch = (unichar)codepoint;
    return [NSString stringWithCharacters:&ch length:1];
  }
  if (codepoint > 0x10ffffu) {
    return @"";
  }
  uint32_t scalar = codepoint - 0x10000u;
  unichar chars[2] = {
    (unichar)(0xd800u + (scalar >> 10)),
    (unichar)(0xdc00u + (scalar & 0x3ffu)),
  };
  return [NSString stringWithCharacters:chars length:2];
}

static NSString *moui_string_from_utf32_bytes(moonbit_bytes_t utf32, int32_t count, int32_t *boundaries) {
  NSMutableString *result = [NSMutableString stringWithCapacity:(NSUInteger)count];
  const uint8_t *src = (const uint8_t *)utf32;
  int32_t utf16_index = 0;
  if (boundaries != NULL) {
    boundaries[0] = 0;
  }
  for (int32_t i = 0; i < count; i++) {
    NSString *s = moui_string_from_utf32_codepoint(moui_read_u32_le(src + i * 4));
    [result appendString:s];
    utf16_index += (int32_t)s.length;
    if (boundaries != NULL) {
      boundaries[i + 1] = utf16_index;
    }
  }
  return result;
}

static CTFontRef moui_create_system_font(double size, int32_t weight, int32_t style) {
  CGFloat font_size = size > 0.0 ? (CGFloat)size : 16.0;
  CTFontUIFontType ui_type = kCTFontUIFontSystem;
  if (weight >= 700) {
    ui_type = style == 1 ? kCTFontUIFontEmphasizedSystem : kCTFontUIFontEmphasizedSystem;
  } else if (weight >= 600) {
    ui_type = kCTFontUIFontEmphasizedSystem;
  }
  CTFontRef font = CTFontCreateUIFontForLanguage(ui_type, font_size, NULL);
  if (font == NULL) {
    font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, font_size, NULL);
  }
  if (style == 1 && font != NULL) {
    CTFontSymbolicTraits traits = kCTFontItalicTrait;
    CTFontDescriptorRef descriptor = CTFontCopyFontDescriptor(font);
    CTFontDescriptorRef italic_descriptor = CTFontDescriptorCreateCopyWithSymbolicTraits(
      descriptor,
      traits,
      traits
    );
    if (descriptor != NULL) {
      CFRelease(descriptor);
    }
    if (italic_descriptor != NULL) {
      CTFontRef italic = CTFontCreateWithFontDescriptor(italic_descriptor, font_size, NULL);
      CFRelease(italic_descriptor);
      if (italic != NULL) {
        CFRelease(font);
        font = italic;
      }
    }
  }
  return font;
}

static int32_t moui_coretext_is_generic_family_name(const uint8_t *name, int32_t len) {
  return (len == 9 && memcmp(name, "system-ui", 9) == 0) ||
         (len == 12 && memcmp(name, "ui-sans-serif", 12) == 0) ||
         (len == 8 && memcmp(name, "ui-serif", 8) == 0) ||
         (len == 12 && memcmp(name, "ui-monospace", 12) == 0) ||
         (len == 10 && memcmp(name, "sans-serif", 10) == 0) ||
         (len == 5 && memcmp(name, "serif", 5) == 0) ||
         (len == 9 && memcmp(name, "monospace", 9) == 0) ||
         (len == 5 && memcmp(name, "emoji", 5) == 0) ||
         (len == 4 && memcmp(name, "math", 4) == 0) ||
         (len == 8 && memcmp(name, "fangsong", 8) == 0);
}

static CTFontRef moui_create_named_font_from_bytes(const uint8_t *name_bytes, int32_t len, double size);

static CTFontRef moui_create_generic_font(const uint8_t *name, int32_t len, double size) {
  if (name == NULL || len <= 0) {
    return NULL;
  }
  if ((len == 9 && memcmp(name, "system-ui", 9) == 0) ||
      (len == 12 && memcmp(name, "ui-sans-serif", 12) == 0) ||
      (len == 10 && memcmp(name, "sans-serif", 10) == 0)) {
    return moui_create_system_font(size, 400, 0);
  }
  if ((len == 12 && memcmp(name, "ui-monospace", 12) == 0) ||
      (len == 9 && memcmp(name, "monospace", 9) == 0)) {
    const char *candidates[] = {
      "SFMono-Regular", "Menlo-Regular", "Monaco", "CourierNewPSMT",
    };
    for (int i = 0; i < 4; i++) {
      CTFontRef font = moui_create_named_font_from_bytes((const uint8_t *)candidates[i], (int32_t)strlen(candidates[i]), size);
      if (font != NULL) {
        return font;
      }
    }
  }
  if ((len == 8 && memcmp(name, "ui-serif", 8) == 0) ||
      (len == 5 && memcmp(name, "serif", 5) == 0)) {
    const char *candidates[] = {
      "NewYork-Regular", "TimesNewRomanPSMT", "Times-Roman",
    };
    for (int i = 0; i < 3; i++) {
      CTFontRef font = moui_create_named_font_from_bytes((const uint8_t *)candidates[i], (int32_t)strlen(candidates[i]), size);
      if (font != NULL) {
        return font;
      }
    }
  }
  if (len == 5 && memcmp(name, "emoji", 5) == 0) {
    const char *candidate = "AppleColorEmoji";
    return moui_create_named_font_from_bytes((const uint8_t *)candidate, (int32_t)strlen(candidate), size);
  }
  if (len == 4 && memcmp(name, "math", 4) == 0) {
    const char *candidates[] = {
      "STIXGeneral-Regular", "TimesNewRomanPSMT",
    };
    for (int i = 0; i < 2; i++) {
      CTFontRef font = moui_create_named_font_from_bytes((const uint8_t *)candidates[i], (int32_t)strlen(candidates[i]), size);
      if (font != NULL) {
        return font;
      }
    }
  }
  if (len == 8 && memcmp(name, "fangsong", 8) == 0) {
    const char *candidates[] = {
      "STFangsong", "SongtiSC-Regular", "STSongti-SC-Regular",
    };
    for (int i = 0; i < 3; i++) {
      CTFontRef font = moui_create_named_font_from_bytes((const uint8_t *)candidates[i], (int32_t)strlen(candidates[i]), size);
      if (font != NULL) {
        return font;
      }
    }
  }
  return NULL;
}

static CTFontRef moui_create_named_font_from_bytes(const uint8_t *name_bytes, int32_t len, double size) {
  if (len <= 0 || name_bytes == NULL || name_bytes[0] == '.') {
    return NULL;
  }
  CFStringRef name = CFStringCreateWithBytes(NULL, (const UInt8 *)name_bytes, (CFIndex)len, kCFStringEncodingUTF8, false);
  if (name == NULL) {
    return NULL;
  }
  CTFontRef font = CTFontCreateWithName(name, size > 0.0 ? (CGFloat)size : 16.0, NULL);
  CFRelease(name);
  return font;
}

static CTFontRef moui_apply_font_traits(CTFontRef font, double size, int32_t weight, int32_t style) {
  if (font == NULL) {
    return NULL;
  }
  CGFloat font_size = size > 0.0 ? (CGFloat)size : 16.0;
  CTFontRef current = font;
  if (weight >= 600 || style == 1) {
    CTFontSymbolicTraits desired = 0;
    CTFontSymbolicTraits mask = 0;
    if (weight >= 600) {
      desired |= kCTFontBoldTrait;
      mask |= kCTFontBoldTrait;
    }
    if (style == 1) {
      desired |= kCTFontItalicTrait;
      mask |= kCTFontItalicTrait;
    }
    CTFontDescriptorRef descriptor = CTFontCopyFontDescriptor(current);
    CTFontDescriptorRef trait_descriptor = descriptor != NULL
      ? CTFontDescriptorCreateCopyWithSymbolicTraits(descriptor, desired, mask)
      : NULL;
    if (descriptor != NULL) {
      CFRelease(descriptor);
    }
    if (trait_descriptor != NULL) {
      CTFontRef trait_font = CTFontCreateWithFontDescriptor(trait_descriptor, font_size, NULL);
      CFRelease(trait_descriptor);
      if (trait_font != NULL) {
        CFRelease(current);
        current = trait_font;
      }
    }
  }
  return current;
}

static CTFontRef moui_create_font_from_spec(MouiCoreTextFontSpec spec) {
  double size = spec.size_key > 0 ? ((double)spec.size_key / 64.0) : 16.0;
  const uint8_t *cursor = spec.families;
  int32_t remaining = spec.families_len;
  for (int32_t i = 0; i < spec.family_count; i++) {
    if (remaining < 4) {
      break;
    }
    int32_t name_len = moui_read_i32_le(cursor);
    cursor += 4;
    remaining -= 4;
    if (name_len <= 0 || name_len > remaining) {
      break;
    }
    CTFontRef font = NULL;
    const char *registered_name = moui_coretext_registered_postscript_name(cursor, name_len);
    if (registered_name != NULL) {
      font = moui_create_named_font_from_bytes((const uint8_t *)registered_name, (int32_t)strlen(registered_name), size);
    }
    if (font == NULL) {
      if (moui_coretext_is_generic_family_name(cursor, name_len)) {
        font = moui_create_generic_font(cursor, name_len, size);
      } else {
        font = moui_create_named_font_from_bytes(cursor, name_len, size);
      }
    }
    if (font != NULL) {
      return moui_apply_font_traits(font, size, spec.weight, spec.style);
    }
    cursor += name_len;
    remaining -= name_len;
  }
  return moui_create_system_font(size, spec.weight, spec.style);
}

static moonbit_bytes_t moui_coretext_font_name_bytes(CTFontRef font) {
  if (font == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  CFStringRef name = CTFontCopyPostScriptName(font);
  if (name == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  CFIndex max_len = CFStringGetMaximumSizeForEncoding(CFStringGetLength(name), kCFStringEncodingUTF8) + 1;
  char *buffer = (char *)malloc((size_t)max_len);
  if (buffer == NULL) {
    CFRelease(name);
    return moonbit_make_bytes(0, 0);
  }
  if (!CFStringGetCString(name, buffer, max_len, kCFStringEncodingUTF8)) {
    free(buffer);
    CFRelease(name);
    return moonbit_make_bytes(0, 0);
  }
  int32_t len = (int32_t)strlen(buffer);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  memcpy((uint8_t *)out, buffer, (size_t)len);
  free(buffer);
  CFRelease(name);
  return out;
}

static CTFontRef moui_create_font_from_name_bytes(moonbit_bytes_t font_name, double size, int32_t weight, int32_t style) {
  int32_t len = (int32_t)Moonbit_array_length(font_name);
  const uint8_t *name_bytes = (const uint8_t *)font_name;
  if (len > 0 && name_bytes[0] != '.') {
    CFStringRef name = CFStringCreateWithBytes(NULL, (const UInt8 *)font_name, (CFIndex)len, kCFStringEncodingUTF8, false);
    if (name != NULL) {
      CTFontRef font = CTFontCreateWithName(name, size > 0.0 ? (CGFloat)size : 16.0, NULL);
      CFRelease(name);
      if (font != NULL) {
        return font;
      }
    }
  }
  return moui_create_system_font(size, weight, style);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_measure_utf32(moonbit_bytes_t utf32, moonbit_bytes_t font_spec) {
  int32_t len = (int32_t)Moonbit_array_length(utf32);
  if (len < 0 || (len % 4) != 0) {
    return moonbit_make_bytes(16, 0);
  }
  MouiCoreTextFontSpec spec = {0};
  if (!moui_coretext_parse_font_spec(font_spec, &spec)) {
    return moonbit_make_bytes(16, 0);
  }
  int32_t count = len / 4;
  if (count > ((INT32_MAX - 24) / 8) - 1) {
    return moonbit_make_bytes(16, 0);
  }
  int32_t out_len = 24 + (count + 1) * 8;
  moonbit_bytes_t out = moonbit_make_bytes(out_len, 0);
  uint8_t *dst = (uint8_t *)out;
  moui_write_i32_le(dst, count);
  moui_write_i32_le(dst + 4, MOUI_CORETEXT_LAYOUT_VERSION);
  CTFontRef font = moui_create_font_from_spec(spec);
  if (font == NULL) {
    return out;
  }
  int32_t *boundaries = (int32_t *)calloc((size_t)count + 1u, sizeof(int32_t));
  NSString *text = moui_string_from_utf32_bytes(utf32, count, boundaries);
  NSDictionary *attrs = @{ (__bridge id)kCTFontAttributeName: (__bridge id)font };
  NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text attributes:attrs];
  CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
  CGFloat ascent = 0.0;
  CGFloat descent = 0.0;
  CGFloat leading = 0.0;
  double width = line != NULL ? CTLineGetTypographicBounds(line, &ascent, &descent, &leading) : 0.0;
  double line_height = ascent + descent + leading;
  if (line_height <= 0.0) {
    line_height = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font);
  }
  if (line_height <= 0.0) {
    line_height = (spec.size_key > 0 ? ((double)spec.size_key / 64.0) : 16.0) * 1.25;
  }
  for (int32_t i = 0; i <= count; i++) {
    double x = 0.0;
    if (line != NULL) {
      if (i == count) {
        x = width;
      } else {
        x = CTLineGetOffsetForStringIndex(line, boundaries[i], NULL);
      }
    }
    moui_write_double_le(dst + 24 + i * 8, x);
  }
  moui_write_double_le(dst + 8, line_height);
  moui_write_double_le(dst + 16, ascent);
  if (line != NULL) {
    CFRelease(line);
  }
  free(boundaries);
  CFRelease(font);
  return out;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_layout_glyphs_utf32(moonbit_bytes_t utf32, moonbit_bytes_t font_spec) {
  int32_t len = (int32_t)Moonbit_array_length(utf32);
  if (len < 0 || (len % 4) != 0) {
    return moonbit_make_bytes(16, 0);
  }
  MouiCoreTextFontSpec spec = {0};
  if (!moui_coretext_parse_font_spec(font_spec, &spec)) {
    return moonbit_make_bytes(16, 0);
  }
  int32_t count = len / 4;
  CTFontRef font = moui_create_font_from_spec(spec);
  if (font == NULL) {
    return moonbit_make_bytes(16, 0);
  }
  NSString *text = moui_string_from_utf32_bytes(utf32, count, NULL);
  NSDictionary *attrs = @{ (__bridge id)kCTFontAttributeName: (__bridge id)font };
  NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text attributes:attrs];
  CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
  if (line == NULL) {
    CFRelease(font);
    return moonbit_make_bytes(16, 0);
  }
  CFArrayRef runs = CTLineGetGlyphRuns(line);
  CFIndex run_count = runs != NULL ? CFArrayGetCount(runs) : 0;
  int32_t glyph_count = 0;
  int64_t payload_len = 32;
  for (CFIndex run_index = 0; run_index < run_count; run_index++) {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, run_index);
    CFIndex count_in_run = CTRunGetGlyphCount(run);
    if (count_in_run > INT32_MAX - glyph_count) {
      CFRelease(line);
      CFRelease(font);
      return moonbit_make_bytes(16, 0);
    }
    glyph_count += (int32_t)count_in_run;
    CFDictionaryRef run_attrs = CTRunGetAttributes(run);
    CTFontRef run_font = run_attrs != NULL ? (CTFontRef)CFDictionaryGetValue(run_attrs, kCTFontAttributeName) : NULL;
    moonbit_bytes_t font_name = moui_coretext_font_name_bytes(run_font);
    int32_t font_name_len = (int32_t)Moonbit_array_length(font_name);
    if (font_name_len <= 0 || font_name_len > INT32_MAX - 28) {
      CFRelease(line);
      CFRelease(font);
      return moonbit_make_bytes(16, 0);
    }
    payload_len += count_in_run * (int64_t)(28 + font_name_len);
    if (payload_len > INT32_MAX) {
      CFRelease(line);
      CFRelease(font);
      return moonbit_make_bytes(16, 0);
    }
  }
  int32_t out_len = (int32_t)payload_len;
  moonbit_bytes_t out = moonbit_make_bytes(out_len, 0);
  uint8_t *dst = (uint8_t *)out;
  CGFloat ascent = 0.0;
  CGFloat descent = 0.0;
  CGFloat leading = 0.0;
  double width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
  double line_height = ascent + descent + leading;
  if (line_height <= 0.0) {
    line_height = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font);
  }
  moui_write_i32_le(dst, MOUI_CORETEXT_RUN_VERSION);
  moui_write_i32_le(dst + 4, glyph_count);
  moui_write_double_le(dst + 8, line_height);
  moui_write_double_le(dst + 16, ascent);
  moui_write_double_le(dst + 24, width);
  int32_t out_index = 32;
  for (CFIndex run_index = 0; run_index < run_count; run_index++) {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, run_index);
    CFDictionaryRef run_attrs = CTRunGetAttributes(run);
    CTFontRef run_font = run_attrs != NULL ? (CTFontRef)CFDictionaryGetValue(run_attrs, kCTFontAttributeName) : NULL;
    moonbit_bytes_t font_name = moui_coretext_font_name_bytes(run_font);
    int32_t font_name_len = (int32_t)Moonbit_array_length(font_name);
    CFIndex count_in_run = CTRunGetGlyphCount(run);
    if (count_in_run <= 0) {
      continue;
    }
    CGGlyph *glyphs = (CGGlyph *)malloc((size_t)count_in_run * sizeof(CGGlyph));
    CGPoint *positions = (CGPoint *)malloc((size_t)count_in_run * sizeof(CGPoint));
    if (glyphs == NULL || positions == NULL) {
      free(glyphs);
      free(positions);
      CFRelease(line);
      CFRelease(font);
      return moonbit_make_bytes(16, 0);
    }
    CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs);
    CTRunGetPositions(run, CFRangeMake(0, 0), positions);
    for (CFIndex i = 0; i < count_in_run; i++) {
      uint8_t *record = dst + out_index;
      moui_write_i32_le(record, (int32_t)glyphs[i]);
      moui_write_i32_le(record + 4, 0);
      moui_write_double_le(record + 8, positions[i].x);
      moui_write_double_le(record + 16, positions[i].y);
      moui_write_i32_le(record + 24, font_name_len);
      memcpy(record + 28, (const uint8_t *)font_name, (size_t)font_name_len);
      out_index += 28 + font_name_len;
    }
    free(glyphs);
    free(positions);
  }
  CFRelease(line);
  CFRelease(font);
  return out;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_system_font_name(double size, int32_t weight, int32_t style) {
  CTFontRef font = moui_create_system_font(size, weight, style);
  moonbit_bytes_t name = moui_coretext_font_name_bytes(font);
  if (font != NULL) {
    CFRelease(font);
  }
  return name;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_register_font_data(moonbit_bytes_t payload) {
  MouiCoreTextFontRegistration registration = {0};
  if (!moui_coretext_parse_font_registration(payload, &registration)) {
    return 0;
  }
  uint8_t *copy = (uint8_t *)malloc((size_t)registration.data_len);
  if (copy == NULL) {
    return 0;
  }
  memcpy(copy, registration.data, (size_t)registration.data_len);
  CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, copy, (size_t)registration.data_len, moui_coretext_release_font_data);
  if (provider == NULL) {
    free(copy);
    return 0;
  }
  CGFontRef cg_font = CGFontCreateWithDataProvider(provider);
  CGDataProviderRelease(provider);
  if (cg_font == NULL) {
    return 0;
  }
  CFStringRef postscript = CGFontCopyPostScriptName(cg_font);
  CFErrorRef error = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  bool registered = CTFontManagerRegisterGraphicsFont(cg_font, &error);
#pragma clang diagnostic pop
  if (error != NULL) {
    CFRelease(error);
  }
  if (postscript != NULL) {
    CFIndex max_len = CFStringGetMaximumSizeForEncoding(CFStringGetLength(postscript), kCFStringEncodingUTF8) + 1;
    char *buffer = (char *)malloc((size_t)max_len);
    if (buffer != NULL && CFStringGetCString(postscript, buffer, max_len, kCFStringEncodingUTF8)) {
      moui_coretext_store_registered_font_alias(
        registration.family_name,
        registration.family_name_len,
        buffer
      );
    }
    free(buffer);
    CFRelease(postscript);
  }
  CGFontRelease(cg_font);
  return registered ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_registered_font_alias_len(moonbit_bytes_t family_name) {
  const uint8_t *bytes = (const uint8_t *)family_name;
  int32_t len = (int32_t)Moonbit_array_length(family_name);
  const char *postscript_name = moui_coretext_registered_postscript_name(bytes, len);
  return postscript_name != NULL ? (int32_t)strlen(postscript_name) : -1;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_font_registration_data_len(moonbit_bytes_t payload) {
  MouiCoreTextFontRegistration registration = {0};
  if (!moui_coretext_parse_font_registration(payload, &registration)) {
    return -1;
  }
  return registration.data_len;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_font_spec_protocol_version(void) {
  return MOUI_NATIVE_FONT_SPEC_VERSION;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_font_registration_protocol_version(void) {
  return MOUI_NATIVE_FONT_REGISTRATION_VERSION;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_generic_font_name_len(moonbit_bytes_t family_name) {
  const uint8_t *bytes = (const uint8_t *)family_name;
  int32_t len = (int32_t)Moonbit_array_length(family_name);
  CTFontRef font = moui_create_generic_font(bytes, len, 16.0);
  if (font == NULL) {
    return -1;
  }
  moonbit_bytes_t name = moui_coretext_font_name_bytes(font);
  int32_t name_len = (int32_t)Moonbit_array_length(name);
  CFRelease(font);
  return name_len > 0 ? name_len : -1;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_glyph_id_for_codepoint(uint32_t codepoint, double size, int32_t weight, int32_t style) {
  CTFontRef font = moui_create_system_font(size, weight, style);
  if (font == NULL) {
    return 0;
  }
  NSString *s = moui_string_from_utf32_codepoint(codepoint);
  if (s.length == 0) {
    CFRelease(font);
    return 0;
  }
  NSUInteger len = s.length;
  unichar *chars = (unichar *)malloc(len * sizeof(unichar));
  CGGlyph *glyphs = (CGGlyph *)malloc(len * sizeof(CGGlyph));
  if (chars == NULL || glyphs == NULL) {
    free(chars);
    free(glyphs);
    CFRelease(font);
    return 0;
  }
  [s getCharacters:chars range:NSMakeRange(0, len)];
  bool ok = CTFontGetGlyphsForCharacters(font, chars, glyphs, len);
  int32_t glyph_id = ok && len > 0 ? (int32_t)glyphs[0] : 0;
  free(chars);
  free(glyphs);
  CFRelease(font);
  return glyph_id;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_raster_glyph(uint32_t glyph_id, moonbit_bytes_t font_name, double size, int32_t weight, int32_t style, double scale_factor) {
  moonbit_bytes_t empty = moonbit_make_bytes(16, 0);
  double scale = scale_factor > 0.0 ? scale_factor : 1.0;
  double font_size = size > 0.0 ? size : 16.0;
  CTFontRef font = moui_create_font_from_name_bytes(font_name, font_size * scale, weight, style);
  if (font == NULL) {
    return empty;
  }
  if (glyph_id == 0 || glyph_id > UINT16_MAX) {
    CFRelease(font);
    return empty;
  }
  CGGlyph glyph = (CGGlyph)glyph_id;
  CGSize advance_size = CGSizeZero;
  CTFontGetAdvancesForGlyphs(font, kCTFontOrientationDefault, &glyph, &advance_size, 1);
  double advance = advance_size.width;
  CGFloat ascent = 0.0;
  CGFloat descent = 0.0;
  CGFloat leading = 0.0;
  ascent = CTFontGetAscent(font);
  descent = CTFontGetDescent(font);
  leading = CTFontGetLeading(font);
  CGRect bounds = CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationDefault, &glyph, NULL, 1);
  if (CGRectIsNull(bounds)) {
    bounds = CGRectMake(0.0, -descent, advance, ascent + descent);
  }
  double padding = 2.0 * scale;
  int32_t width = (int32_t)ceil(bounds.size.width + padding * 2.0);
  int32_t height = (int32_t)ceil(ascent + descent + leading + padding * 2.0);
  if (width <= 0 || height <= 0 || width > 2048 || height > 2048) {
    CFRelease(font);
    return empty;
  }
  int32_t header = 32;
  moonbit_bytes_t out = moonbit_make_bytes(header + width * height, 0);
  uint8_t *dst = (uint8_t *)out;
  moui_write_i32_le(dst, width);
  moui_write_i32_le(dst + 4, height);
  moui_write_i32_le(dst + 8, (int32_t)floor(bounds.origin.x - padding));
  moui_write_i32_le(dst + 12, (int32_t)floor(-(ascent + padding)));
  moui_write_i32_le(dst + 16, MOUI_CORETEXT_RASTER_VERSION);
  moui_write_i32_le(dst + 20, 0);
  moui_write_double_le(dst + 24, advance / scale);

  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceGray();
  CGContextRef ctx = CGBitmapContextCreate(dst + header, width, height, 8, width, color_space, (CGBitmapInfo)kCGImageAlphaNone);
  CGColorSpaceRelease(color_space);
  if (ctx == NULL) {
    CFRelease(font);
    return empty;
  }
  CGContextSetAllowsAntialiasing(ctx, true);
  CGContextSetShouldAntialias(ctx, true);
  CGContextSetGrayFillColor(ctx, 1.0, 1.0);
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  CGPoint position = CGPointMake(padding - bounds.origin.x, height - (padding + ascent));
  CTFontDrawGlyphs(font, &glyph, &position, 1, ctx);
  CGContextRelease(ctx);
  CFRelease(font);
  return out;
}

#else

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_measure_utf32(moonbit_bytes_t utf32, moonbit_bytes_t font_spec) {
  (void)utf32;
  (void)font_spec;
  return moonbit_make_bytes(16, 0);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_layout_glyphs_utf32(moonbit_bytes_t utf32, moonbit_bytes_t font_spec) {
  (void)utf32;
  (void)font_spec;
  return moonbit_make_bytes(16, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_glyph_id_for_codepoint(uint32_t codepoint, double size, int32_t weight, int32_t style) {
  (void)codepoint;
  (void)size;
  (void)weight;
  (void)style;
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_system_font_name(double size, int32_t weight, int32_t style) {
  (void)size;
  (void)weight;
  (void)style;
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_register_font_data(moonbit_bytes_t payload) {
  (void)payload;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_registered_font_alias_len(moonbit_bytes_t family_name) {
  (void)family_name;
  return -1;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_font_registration_data_len(moonbit_bytes_t payload) {
  (void)payload;
  return -1;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_font_spec_protocol_version(void) {
  return MOUI_NATIVE_FONT_SPEC_VERSION;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_font_registration_protocol_version(void) {
  return MOUI_NATIVE_FONT_REGISTRATION_VERSION;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_coretext_debug_generic_font_name_len(moonbit_bytes_t family_name) {
  (void)family_name;
  return -1;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_raster_glyph(uint32_t glyph_id, moonbit_bytes_t font_name, double size, int32_t weight, int32_t style, double scale_factor) {
  (void)glyph_id;
  (void)font_name;
  (void)size;
  (void)weight;
  (void)style;
  (void)scale_factor;
  return moonbit_make_bytes(16, 0);
}

#endif
