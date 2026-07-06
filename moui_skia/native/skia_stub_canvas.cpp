#include "skia_stub_common.h"

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_path(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaPath* path,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    path == nullptr ||
    path->path == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawPath(*path->path, paint);
#else
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_path_shader(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaPath* path,
  MoonbitSkiaShader* shader,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    path == nullptr ||
    path->path == nullptr ||
    shader == nullptr ||
    shader->shader == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint_with_shader(
    shader,
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawPath(*path->path, paint);
#else
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_image(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaImage* image,
  float x,
  float y
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    image == nullptr ||
    image->image == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->drawImage(image->image, x, y);
#else
  (void)x;
  (void)y;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_image_rect(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaImage* image,
  float src_left,
  float src_top,
  float src_right,
  float src_bottom,
  float dst_left,
  float dst_top,
  float dst_right,
  float dst_bottom,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode,
  int32_t sampling_filter,
  int32_t sampling_mipmap,
  int32_t sampling_use_cubic,
  float sampling_cubic_b,
  float sampling_cubic_c
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    image == nullptr ||
    image->image == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  SkSamplingOptions sampling = moonbit_skia_make_sampling_options(
    sampling_filter,
    sampling_mipmap,
    sampling_use_cubic,
    sampling_cubic_b,
    sampling_cubic_c
  );
  wrapper->canvas->drawImageRect(
    image->image,
    SkRect::MakeLTRB(src_left, src_top, src_right, src_bottom),
    SkRect::MakeLTRB(dst_left, dst_top, dst_right, dst_bottom),
    sampling,
    &paint,
    SkCanvas::kStrict_SrcRectConstraint
  );
#else
  (void)src_left;
  (void)src_top;
  (void)src_right;
  (void)src_bottom;
  (void)dst_left;
  (void)dst_top;
  (void)dst_right;
  (void)dst_bottom;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
  (void)sampling_filter;
  (void)sampling_mipmap;
  (void)sampling_use_cubic;
  (void)sampling_cubic_b;
  (void)sampling_cubic_c;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_text_utf8(
  MoonbitSkiaCanvas* wrapper,
  moonbit_bytes_t text,
  float x,
  float y,
  MoonbitSkiaFont* font,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    text == nullptr ||
    font == nullptr ||
    font->font == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  int32_t length = static_cast<int32_t>(Moonbit_array_length(text));
  if (length <= 0) {
    return;
  }
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawSimpleText(
    text,
    static_cast<size_t>(length),
    SkTextEncoding::kUTF8,
    x,
    y,
    *font->font,
    paint
  );
#else
  (void)x;
  (void)y;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

static uint16_t moonbit_skia_read_u16_be(const uint8_t* bytes) {
  return static_cast<uint16_t>(
    (static_cast<uint16_t>(bytes[0]) << 8) |
    static_cast<uint16_t>(bytes[1])
  );
}

static float moonbit_skia_read_f32_be(const uint8_t* bytes) {
  uint32_t bits =
    (static_cast<uint32_t>(bytes[0]) << 24) |
    (static_cast<uint32_t>(bytes[1]) << 16) |
    (static_cast<uint32_t>(bytes[2]) << 8) |
    static_cast<uint32_t>(bytes[3]);
  float value = 0.0f;
  memcpy(&value, &bits, sizeof(float));
  return value;
}

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_canvas_draw_glyphs(
  MoonbitSkiaCanvas* wrapper,
  moonbit_bytes_t glyph_bytes,
  moonbit_bytes_t position_bytes,
  int32_t glyph_count,
  float origin_x,
  float origin_y,
  MoonbitSkiaFont* font,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    glyph_bytes == nullptr ||
    position_bytes == nullptr ||
    font == nullptr ||
    font->font == nullptr
  ) {
    return 0;
  }
  int32_t glyph_byte_count = Moonbit_array_length(glyph_bytes);
  int32_t position_byte_count = Moonbit_array_length(position_bytes);
  if (
    glyph_count <= 0 ||
    glyph_byte_count != glyph_count * 2 ||
    position_byte_count != glyph_count * 8
  ) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  const uint8_t* glyph_data = static_cast<const uint8_t*>(
    static_cast<const void*>(glyph_bytes)
  );
  const uint8_t* position_data = static_cast<const uint8_t*>(
    static_cast<const void*>(position_bytes)
  );
  std::vector<SkGlyphID> sk_glyphs(static_cast<size_t>(glyph_count));
  std::vector<SkPoint> sk_positions(static_cast<size_t>(glyph_count));
  bool has_visible_glyph = false;
  for (int32_t i = 0; i < glyph_count; ++i) {
    size_t index = static_cast<size_t>(i);
    sk_glyphs[index] = static_cast<SkGlyphID>(
      moonbit_skia_read_u16_be(glyph_data + index * 2)
    );
    has_visible_glyph = has_visible_glyph || sk_glyphs[index] != 0;
    sk_positions[index] = SkPoint::Make(
      moonbit_skia_read_f32_be(position_data + index * 8),
      moonbit_skia_read_f32_be(position_data + index * 8 + 4)
    );
  }
  if (!has_visible_glyph) {
    return 0;
  }
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawGlyphs(
    SkSpan<const SkGlyphID>(sk_glyphs.data(), sk_glyphs.size()),
    SkSpan<const SkPoint>(sk_positions.data(), sk_positions.size()),
    SkPoint::Make(origin_x, origin_y),
    *font->font,
    paint
  );
  return 1;
#else
  (void)origin_x;
  (void)origin_y;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_paint_shader(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaShader* shader,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    shader == nullptr ||
    shader->shader == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint_with_shader(
    shader,
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawPaint(paint);
#else
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_rect_shader(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaShader* shader,
  float left,
  float top,
  float right,
  float bottom,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    shader == nullptr ||
    shader->shader == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint_with_shader(
    shader,
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawRect(SkRect::MakeLTRB(left, top, right, bottom), paint);
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_round_rect_shader(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaShader* shader,
  float left,
  float top,
  float right,
  float bottom,
  float rx,
  float ry,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    shader == nullptr ||
    shader->shader == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint_with_shader(
    shader,
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawRoundRect(
    SkRect::MakeLTRB(left, top, right, bottom),
    rx,
    ry,
    paint
  );
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)rx;
  (void)ry;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}
extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_is_null(MoonbitSkiaCanvas* wrapper) {
  return wrapper == nullptr || wrapper->canvas == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_save(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->canvas->save();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_canvas_save_layer(
  MoonbitSkiaCanvas* wrapper,
  int32_t has_bounds,
  float left,
  float top,
  float right,
  float bottom,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode,
  MoonbitSkiaColorFilter* color_filter,
  MoonbitSkiaImageFilter* image_filter,
  MoonbitSkiaMaskFilter* mask_filter
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode,
    color_filter,
    image_filter,
    mask_filter
  );
  if (has_bounds != 0) {
    SkRect bounds = SkRect::MakeLTRB(left, top, right, bottom);
    return wrapper->canvas->saveLayer(&bounds, &paint);
  }
  return wrapper->canvas->saveLayer(nullptr, &paint);
#else
  (void)has_bounds;
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
  (void)color_filter;
  (void)image_filter;
  (void)mask_filter;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_canvas_restore(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->restore();
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_restore_to_count(
  MoonbitSkiaCanvas* wrapper,
  int32_t count
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->restoreToCount(count);
#else
  (void)count;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_save_count(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->canvas->getSaveCount();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_translate(
  MoonbitSkiaCanvas* wrapper,
  float dx,
  float dy
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->translate(dx, dy);
#else
  (void)dx;
  (void)dy;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_scale(
  MoonbitSkiaCanvas* wrapper,
  float sx,
  float sy
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->scale(sx, sy);
#else
  (void)sx;
  (void)sy;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_rotate(
  MoonbitSkiaCanvas* wrapper,
  float degrees
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->rotate(degrees);
#else
  (void)degrees;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_skew(
  MoonbitSkiaCanvas* wrapper,
  float sx,
  float sy
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->skew(sx, sy);
#else
  (void)sx;
  (void)sy;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_concat(
  MoonbitSkiaCanvas* wrapper,
  float scale_x,
  float skew_x,
  float trans_x,
  float skew_y,
  float scale_y,
  float trans_y,
  float persp_0,
  float persp_1,
  float persp_2
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkMatrix matrix;
  matrix.setAll(
    scale_x,
    skew_x,
    trans_x,
    skew_y,
    scale_y,
    trans_y,
    persp_0,
    persp_1,
    persp_2
  );
  wrapper->canvas->concat(matrix);
#else
  (void)scale_x;
  (void)skew_x;
  (void)trans_x;
  (void)skew_y;
  (void)scale_y;
  (void)trans_y;
  (void)persp_0;
  (void)persp_1;
  (void)persp_2;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_canvas_reset_matrix(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->resetMatrix();
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_canvas_discard(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->discard();
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_clip_rect(
  MoonbitSkiaCanvas* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  int32_t op,
  int32_t anti_alias
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->clipRect(
    SkRect::MakeLTRB(left, top, right, bottom),
    static_cast<SkClipOp>(op),
    anti_alias != 0
  );
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)op;
  (void)anti_alias;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_clip_rrect(
  MoonbitSkiaCanvas* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  float upper_left_width,
  float upper_left_height,
  float upper_right_width,
  float upper_right_height,
  float lower_right_width,
  float lower_right_height,
  float lower_left_width,
  float lower_left_height,
  int32_t op,
  int32_t anti_alias
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRRect rrect = moonbit_skia_make_rrect(
    left,
    top,
    right,
    bottom,
    upper_left_width,
    upper_left_height,
    upper_right_width,
    upper_right_height,
    lower_right_width,
    lower_right_height,
    lower_left_width,
    lower_left_height
  );
  wrapper->canvas->clipRRect(
    rrect,
    static_cast<SkClipOp>(op),
    anti_alias != 0
  );
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)upper_left_width;
  (void)upper_left_height;
  (void)upper_right_width;
  (void)upper_right_height;
  (void)lower_right_width;
  (void)lower_right_height;
  (void)lower_left_width;
  (void)lower_left_height;
  (void)op;
  (void)anti_alias;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_clip_path(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaPath* path,
  int32_t op,
  int32_t anti_alias
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    path == nullptr ||
    path->path == nullptr
  ) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->clipPath(
    *path->path,
    static_cast<SkClipOp>(op),
    anti_alias != 0
  );
#else
  (void)op;
  (void)anti_alias;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_local_clip_bounds(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  return wrapper->canvas->getLocalClipBounds(&bounds);
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_canvas_local_clip_bounds_left(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (!wrapper->canvas->getLocalClipBounds(&bounds)) {
    return 0.0f;
  }
  return bounds.left();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_canvas_local_clip_bounds_top(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (!wrapper->canvas->getLocalClipBounds(&bounds)) {
    return 0.0f;
  }
  return bounds.top();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_canvas_local_clip_bounds_right(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (!wrapper->canvas->getLocalClipBounds(&bounds)) {
    return 0.0f;
  }
  return bounds.right();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_canvas_local_clip_bounds_bottom(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0.0f;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkRect bounds;
  if (!wrapper->canvas->getLocalClipBounds(&bounds)) {
    return 0.0f;
  }
  return bounds.bottom();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_device_clip_bounds(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkIRect bounds;
  return wrapper->canvas->getDeviceClipBounds(&bounds);
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_device_clip_bounds_left(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkIRect bounds;
  if (!wrapper->canvas->getDeviceClipBounds(&bounds)) {
    return 0;
  }
  return bounds.left();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_device_clip_bounds_top(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkIRect bounds;
  if (!wrapper->canvas->getDeviceClipBounds(&bounds)) {
    return 0;
  }
  return bounds.top();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_device_clip_bounds_right(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkIRect bounds;
  if (!wrapper->canvas->getDeviceClipBounds(&bounds)) {
    return 0;
  }
  return bounds.right();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_device_clip_bounds_bottom(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkIRect bounds;
  if (!wrapper->canvas->getDeviceClipBounds(&bounds)) {
    return 0;
  }
  return bounds.bottom();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_canvas_quick_reject_rect(
  MoonbitSkiaCanvas* wrapper,
  float left,
  float top,
  float right,
  float bottom
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->canvas->quickReject(SkRect::MakeLTRB(left, top, right, bottom));
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_canvas_quick_reject_path(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaPath* path
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    path == nullptr ||
    path->path == nullptr
  ) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  return wrapper->canvas->quickReject(*path->path);
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_color(
  MoonbitSkiaCanvas* wrapper,
  uint32_t color_argb,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  wrapper->canvas->drawColor(
    static_cast<SkColor>(color_argb),
    static_cast<SkBlendMode>(blend_mode)
  );
#else
  (void)color_argb;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_paint(
  MoonbitSkiaCanvas* wrapper,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawPaint(paint);
#else
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_point(
  MoonbitSkiaCanvas* wrapper,
  float x,
  float y,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawPoint(x, y, paint);
#else
  (void)x;
  (void)y;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_line(
  MoonbitSkiaCanvas* wrapper,
  float x0,
  float y0,
  float x1,
  float y1,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawLine(x0, y0, x1, y1, paint);
#else
  (void)x0;
  (void)y0;
  (void)x1;
  (void)y1;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_rect(
  MoonbitSkiaCanvas* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawRect(SkRect::MakeLTRB(left, top, right, bottom), paint);
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_oval(
  MoonbitSkiaCanvas* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawOval(SkRect::MakeLTRB(left, top, right, bottom), paint);
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_circle(
  MoonbitSkiaCanvas* wrapper,
  float x,
  float y,
  float radius,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawCircle(x, y, radius, paint);
#else
  (void)x;
  (void)y;
  (void)radius;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_arc(
  MoonbitSkiaCanvas* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  float start_angle,
  float sweep_angle,
  int32_t use_center,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawArc(
    SkRect::MakeLTRB(left, top, right, bottom),
    start_angle,
    sweep_angle,
    use_center != 0,
    paint
  );
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)start_angle;
  (void)sweep_angle;
  (void)use_center;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_round_rect(
  MoonbitSkiaCanvas* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  float rx,
  float ry,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  wrapper->canvas->drawRoundRect(
    SkRect::MakeLTRB(left, top, right, bottom),
    rx,
    ry,
    paint
  );
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)rx;
  (void)ry;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_rrect(
  MoonbitSkiaCanvas* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  float upper_left_width,
  float upper_left_height,
  float upper_right_width,
  float upper_right_height,
  float lower_right_width,
  float lower_right_height,
  float lower_left_width,
  float lower_left_height,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  SkRRect rrect = moonbit_skia_make_rrect(
    left,
    top,
    right,
    bottom,
    upper_left_width,
    upper_left_height,
    upper_right_width,
    upper_right_height,
    lower_right_width,
    lower_right_height,
    lower_left_width,
    lower_left_height
  );
  wrapper->canvas->drawRRect(rrect, paint);
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)upper_left_width;
  (void)upper_left_height;
  (void)upper_right_width;
  (void)upper_right_height;
  (void)lower_right_width;
  (void)lower_right_height;
  (void)lower_left_width;
  (void)lower_left_height;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_drrect(
  MoonbitSkiaCanvas* wrapper,
  float outer_left,
  float outer_top,
  float outer_right,
  float outer_bottom,
  float outer_upper_left_width,
  float outer_upper_left_height,
  float outer_upper_right_width,
  float outer_upper_right_height,
  float outer_lower_right_width,
  float outer_lower_right_height,
  float outer_lower_left_width,
  float outer_lower_left_height,
  float inner_left,
  float inner_top,
  float inner_right,
  float inner_bottom,
  float inner_upper_left_width,
  float inner_upper_left_height,
  float inner_upper_right_width,
  float inner_upper_right_height,
  float inner_lower_right_width,
  float inner_lower_right_height,
  float inner_lower_left_width,
  float inner_lower_left_height,
  uint32_t color_argb,
  int32_t anti_alias,
  int32_t dither,
  int32_t style,
  float stroke_width,
  float stroke_miter,
  int32_t stroke_cap,
  int32_t stroke_join,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPaint paint = moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode
  );
  SkRRect outer = moonbit_skia_make_rrect(
    outer_left,
    outer_top,
    outer_right,
    outer_bottom,
    outer_upper_left_width,
    outer_upper_left_height,
    outer_upper_right_width,
    outer_upper_right_height,
    outer_lower_right_width,
    outer_lower_right_height,
    outer_lower_left_width,
    outer_lower_left_height
  );
  SkRRect inner = moonbit_skia_make_rrect(
    inner_left,
    inner_top,
    inner_right,
    inner_bottom,
    inner_upper_left_width,
    inner_upper_left_height,
    inner_upper_right_width,
    inner_upper_right_height,
    inner_lower_right_width,
    inner_lower_right_height,
    inner_lower_left_width,
    inner_lower_left_height
  );
  wrapper->canvas->drawDRRect(outer, inner, paint);
#else
  (void)outer_left;
  (void)outer_top;
  (void)outer_right;
  (void)outer_bottom;
  (void)outer_upper_left_width;
  (void)outer_upper_left_height;
  (void)outer_upper_right_width;
  (void)outer_upper_right_height;
  (void)outer_lower_right_width;
  (void)outer_lower_right_height;
  (void)outer_lower_left_width;
  (void)outer_lower_left_height;
  (void)inner_left;
  (void)inner_top;
  (void)inner_right;
  (void)inner_bottom;
  (void)inner_upper_left_width;
  (void)inner_upper_left_height;
  (void)inner_upper_right_width;
  (void)inner_upper_right_height;
  (void)inner_lower_right_width;
  (void)inner_lower_right_height;
  (void)inner_lower_left_width;
  (void)inner_lower_left_height;
  (void)color_argb;
  (void)anti_alias;
  (void)dither;
  (void)style;
  (void)stroke_width;
  (void)stroke_miter;
  (void)stroke_cap;
  (void)stroke_join;
  (void)blend_mode;
#endif
}
