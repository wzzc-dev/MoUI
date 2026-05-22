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
#define MOUI_CORETEXT_RASTER_VERSION 1

static uint32_t moui_read_u32_le(const uint8_t *p) {
  return ((uint32_t)p[0]) | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
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

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_measure_utf32(moonbit_bytes_t utf32, double size, int32_t weight, int32_t style) {
  int32_t len = (int32_t)Moonbit_array_length(utf32);
  if (len < 0 || (len % 4) != 0) {
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
  CTFontRef font = moui_create_system_font(size, weight, style);
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
    line_height = size * 1.25;
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
moonbit_bytes_t moui_macos_coretext_raster_glyph(uint32_t codepoint, double size, int32_t weight, int32_t style, double scale_factor) {
  moonbit_bytes_t empty = moonbit_make_bytes(16, 0);
  double scale = scale_factor > 0.0 ? scale_factor : 1.0;
  double font_size = size > 0.0 ? size : 16.0;
  CTFontRef font = moui_create_system_font(font_size * scale, weight, style);
  if (font == NULL) {
    return empty;
  }
  NSString *s = moui_string_from_utf32_codepoint(codepoint);
  if (s.length == 0) {
    CFRelease(font);
    return empty;
  }
  CGColorRef white = CGColorCreateGenericGray(1.0, 1.0);
  NSDictionary *attrs = @{
    (__bridge id)kCTFontAttributeName: (__bridge id)font,
    (__bridge id)kCTForegroundColorAttributeName: (__bridge id)white,
  };
  NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:s attributes:attrs];
  CGColorRelease(white);
  CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
  CFArrayRef runs = line != NULL ? CTLineGetGlyphRuns(line) : NULL;
  if (runs == NULL || CFArrayGetCount(runs) == 0) {
    if (line != NULL) {
      CFRelease(line);
    }
    CFRelease(font);
    return empty;
  }
  CGRect bounds = CGRectNull;
  double advance = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
  CGFloat ascent = 0.0;
  CGFloat descent = 0.0;
  CGFloat leading = 0.0;
  CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
  for (CFIndex run_index = 0; run_index < CFArrayGetCount(runs); run_index++) {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, run_index);
    CGRect run_bounds = CTRunGetImageBounds(run, NULL, CFRangeMake(0, 0));
    bounds = CGRectIsNull(bounds) ? run_bounds : CGRectUnion(bounds, run_bounds);
  }
  if (CGRectIsNull(bounds)) {
    bounds = CGRectMake(0.0, -descent, advance, ascent + descent);
  }
  double padding = 2.0 * scale;
  int32_t width = (int32_t)ceil(bounds.size.width + padding * 2.0);
  int32_t height = (int32_t)ceil(ascent + descent + leading + padding * 2.0);
  if (width <= 0 || height <= 0 || width > 2048 || height > 2048) {
    CFRelease(line);
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
    CFRelease(line);
    CFRelease(font);
    return empty;
  }
  CGContextSetAllowsAntialiasing(ctx, true);
  CGContextSetShouldAntialias(ctx, true);
  CGContextSetGrayFillColor(ctx, 1.0, 1.0);
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  CGContextTranslateCTM(ctx, padding - bounds.origin.x, height - (padding + ascent));
  CTLineDraw(line, ctx);
  CGContextRelease(ctx);
  CFRelease(line);
  CFRelease(font);
  return out;
}

#else

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_measure_utf32(moonbit_bytes_t utf32, double size, int32_t weight, int32_t style) {
  (void)utf32;
  (void)size;
  (void)weight;
  (void)style;
  return moonbit_make_bytes(16, 0);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_coretext_raster_glyph(uint32_t codepoint, double size, int32_t weight, int32_t style, double scale_factor) {
  (void)codepoint;
  (void)size;
  (void)weight;
  (void)style;
  (void)scale_factor;
  return moonbit_make_bytes(16, 0);
}

#endif
