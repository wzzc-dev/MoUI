#include <moonbit.h>

#include <string.h>
#include <stdint.h>
#include <memory>

#if defined(SKIA_MBT_HAS_SKIA)
#include "include/core/SkCanvas.h"
#include "include/core/SkBitmap.h"
#include "include/core/SkClipOp.h"
#include "include/core/SkColor.h"
#include "include/core/SkData.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontStyle.h"
#include "include/core/SkImage.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkPoint.h"
#include "include/core/SkRect.h"
#include "include/core/SkSamplingOptions.h"
#include "include/core/SkShader.h"
#include "include/core/SkSurface.h"
#include "include/core/SkTypeface.h"
#include "include/core/SkTypes.h"
#include "include/codec/SkCodec.h"
#include "include/codec/SkEncodedImageFormat.h"
#include "include/effects/SkGradientShader.h"
#include "include/core/SkRefCnt.h"
#endif

struct MoonbitSkiaSurface {
#if defined(SKIA_MBT_HAS_SKIA)
  SkSurface* surface;
#else
  void* surface;
#endif
};

struct MoonbitSkiaData {
#if defined(SKIA_MBT_HAS_SKIA)
  SkData* data;
#else
  void* data;
#endif
};

struct MoonbitSkiaCodec {
#if defined(SKIA_MBT_HAS_SKIA)
  SkCodec* codec;
#else
  void* codec;
#endif
};

struct MoonbitSkiaImage {
#if defined(SKIA_MBT_HAS_SKIA)
  SkImage* image;
#else
  void* image;
#endif
};

struct MoonbitSkiaCanvas {
#if defined(SKIA_MBT_HAS_SKIA)
  SkCanvas* canvas;
#else
  void* canvas;
#endif
};

struct MoonbitSkiaPath {
#if defined(SKIA_MBT_HAS_SKIA)
  SkPath* path;
#else
  void* path;
#endif
};

struct MoonbitSkiaFont {
#if defined(SKIA_MBT_HAS_SKIA)
  SkFont* font;
#else
  void* font;
#endif
};

struct MoonbitSkiaTypeface {
#if defined(SKIA_MBT_HAS_SKIA)
  SkTypeface* typeface;
#else
  void* typeface;
#endif
};

struct MoonbitSkiaShader {
#if defined(SKIA_MBT_HAS_SKIA)
  SkShader* shader;
#else
  void* shader;
#endif
};

struct MoonbitSkiaBitmap {
#if defined(SKIA_MBT_HAS_SKIA)
  SkBitmap* bitmap;
#else
  void* bitmap;
#endif
};

static void moonbit_skia_path_finalize(void* ptr) {
  MoonbitSkiaPath* wrapper = static_cast<MoonbitSkiaPath*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  delete wrapper->path;
  wrapper->path = nullptr;
#else
  wrapper->path = nullptr;
#endif
}

static void moonbit_skia_font_finalize(void* ptr) {
  MoonbitSkiaFont* wrapper = static_cast<MoonbitSkiaFont*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  delete wrapper->font;
  wrapper->font = nullptr;
#else
  wrapper->font = nullptr;
#endif
}

static void moonbit_skia_typeface_finalize(void* ptr) {
  MoonbitSkiaTypeface* wrapper = static_cast<MoonbitSkiaTypeface*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  if (wrapper->typeface != nullptr) {
    wrapper->typeface->unref();
    wrapper->typeface = nullptr;
  }
#else
  wrapper->typeface = nullptr;
#endif
}

static void moonbit_skia_shader_finalize(void* ptr) {
  MoonbitSkiaShader* wrapper = static_cast<MoonbitSkiaShader*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  if (wrapper->shader != nullptr) {
    wrapper->shader->unref();
    wrapper->shader = nullptr;
  }
#else
  wrapper->shader = nullptr;
#endif
}

static void moonbit_skia_bitmap_finalize(void* ptr) {
  MoonbitSkiaBitmap* wrapper = static_cast<MoonbitSkiaBitmap*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  delete wrapper->bitmap;
  wrapper->bitmap = nullptr;
#else
  wrapper->bitmap = nullptr;
#endif
}

static void moonbit_skia_data_finalize(void* ptr) {
  MoonbitSkiaData* wrapper = static_cast<MoonbitSkiaData*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  if (wrapper->data != nullptr) {
    wrapper->data->unref();
    wrapper->data = nullptr;
  }
#else
  wrapper->data = nullptr;
#endif
}

static void moonbit_skia_codec_finalize(void* ptr) {
  MoonbitSkiaCodec* wrapper = static_cast<MoonbitSkiaCodec*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  delete wrapper->codec;
  wrapper->codec = nullptr;
#else
  wrapper->codec = nullptr;
#endif
}

static void moonbit_skia_image_finalize(void* ptr) {
  MoonbitSkiaImage* wrapper = static_cast<MoonbitSkiaImage*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  if (wrapper->image != nullptr) {
    wrapper->image->unref();
    wrapper->image = nullptr;
  }
#else
  wrapper->image = nullptr;
#endif
}

static void moonbit_skia_surface_finalize(void* ptr) {
  MoonbitSkiaSurface* wrapper = static_cast<MoonbitSkiaSurface*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  if (wrapper->surface != nullptr) {
    wrapper->surface->unref();
    wrapper->surface = nullptr;
  }
#else
  wrapper->surface = nullptr;
#endif
}

static void moonbit_skia_canvas_finalize(void* ptr) {
  MoonbitSkiaCanvas* wrapper = static_cast<MoonbitSkiaCanvas*>(ptr);
  wrapper->canvas = nullptr;
}

static MoonbitSkiaFont* moonbit_skia_make_font_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkFont* font
#else
  void* font
#endif
) {
  MoonbitSkiaFont* wrapper = static_cast<MoonbitSkiaFont*>(
    moonbit_make_external_object(
      moonbit_skia_font_finalize,
      sizeof(MoonbitSkiaFont)
    )
  );
  wrapper->font = font;
  return wrapper;
}

static MoonbitSkiaTypeface* moonbit_skia_make_typeface_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkTypeface* typeface
#else
  void* typeface
#endif
) {
  MoonbitSkiaTypeface* wrapper = static_cast<MoonbitSkiaTypeface*>(
    moonbit_make_external_object(
      moonbit_skia_typeface_finalize,
      sizeof(MoonbitSkiaTypeface)
    )
  );
  wrapper->typeface = typeface;
  return wrapper;
}

static MoonbitSkiaShader* moonbit_skia_make_shader_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkShader* shader
#else
  void* shader
#endif
) {
  MoonbitSkiaShader* wrapper = static_cast<MoonbitSkiaShader*>(
    moonbit_make_external_object(
      moonbit_skia_shader_finalize,
      sizeof(MoonbitSkiaShader)
    )
  );
  wrapper->shader = shader;
  return wrapper;
}

static MoonbitSkiaCodec* moonbit_skia_make_codec_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkCodec* codec
#else
  void* codec
#endif
) {
  MoonbitSkiaCodec* wrapper = static_cast<MoonbitSkiaCodec*>(
    moonbit_make_external_object(
      moonbit_skia_codec_finalize,
      sizeof(MoonbitSkiaCodec)
    )
  );
  wrapper->codec = codec;
  return wrapper;
}

static MoonbitSkiaBitmap* moonbit_skia_make_bitmap_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkBitmap* bitmap
#else
  void* bitmap
#endif
) {
  MoonbitSkiaBitmap* wrapper = static_cast<MoonbitSkiaBitmap*>(
    moonbit_make_external_object(
      moonbit_skia_bitmap_finalize,
      sizeof(MoonbitSkiaBitmap)
    )
  );
  wrapper->bitmap = bitmap;
  return wrapper;
}

static MoonbitSkiaPath* moonbit_skia_make_path_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkPath* path
#else
  void* path
#endif
) {
  MoonbitSkiaPath* wrapper = static_cast<MoonbitSkiaPath*>(
    moonbit_make_external_object(
      moonbit_skia_path_finalize,
      sizeof(MoonbitSkiaPath)
    )
  );
  wrapper->path = path;
  return wrapper;
}

static MoonbitSkiaData* moonbit_skia_make_data_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkData* data
#else
  void* data
#endif
) {
  MoonbitSkiaData* wrapper = static_cast<MoonbitSkiaData*>(
    moonbit_make_external_object(
      moonbit_skia_data_finalize,
      sizeof(MoonbitSkiaData)
    )
  );
  wrapper->data = data;
  return wrapper;
}

static MoonbitSkiaImage* moonbit_skia_make_image_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkImage* image
#else
  void* image
#endif
) {
  MoonbitSkiaImage* wrapper = static_cast<MoonbitSkiaImage*>(
    moonbit_make_external_object(
      moonbit_skia_image_finalize,
      sizeof(MoonbitSkiaImage)
    )
  );
  wrapper->image = image;
  return wrapper;
}

static MoonbitSkiaSurface* moonbit_skia_make_surface_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkSurface* surface
#else
  void* surface
#endif
) {
  MoonbitSkiaSurface* wrapper = static_cast<MoonbitSkiaSurface*>(
    moonbit_make_external_object(
      moonbit_skia_surface_finalize,
      sizeof(MoonbitSkiaSurface)
    )
  );
  wrapper->surface = surface;
  return wrapper;
}

static MoonbitSkiaCanvas* moonbit_skia_make_canvas_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkCanvas* canvas
#else
  void* canvas
#endif
) {
  MoonbitSkiaCanvas* wrapper = static_cast<MoonbitSkiaCanvas*>(
    moonbit_make_external_object(
      moonbit_skia_canvas_finalize,
      sizeof(MoonbitSkiaCanvas)
    )
  );
  wrapper->canvas = canvas;
  return wrapper;
}

#if defined(SKIA_MBT_HAS_SKIA)
static SkPaint moonbit_skia_make_paint(
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
  SkPaint paint;
  paint.setColor(static_cast<SkColor>(color_argb));
  paint.setAntiAlias(anti_alias != 0);
  paint.setDither(dither != 0);
  paint.setStyle(static_cast<SkPaint::Style>(style));
  paint.setStrokeWidth(stroke_width);
  paint.setStrokeMiter(stroke_miter);
  paint.setStrokeCap(static_cast<SkPaint::Cap>(stroke_cap));
  paint.setStrokeJoin(static_cast<SkPaint::Join>(stroke_join));
  paint.setBlendMode(static_cast<SkBlendMode>(blend_mode));
  return paint;
}

static SkPaint moonbit_skia_make_paint_with_shader(
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
  if (shader != nullptr && shader->shader != nullptr) {
    paint.setShader(sk_ref_sp(shader->shader));
  }
  return paint;
}

static SkSamplingOptions moonbit_skia_make_sampling_options(
  int32_t filter,
  int32_t mipmap,
  int32_t use_cubic,
  float cubic_b,
  float cubic_c
) {
  if (use_cubic != 0) {
    return SkSamplingOptions(SkCubicResampler{cubic_b, cubic_c});
  }
  return SkSamplingOptions(
    static_cast<SkFilterMode>(filter),
    static_cast<SkMipmapMode>(mipmap)
  );
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_available(void) {
#if defined(SKIA_MBT_HAS_SKIA)
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_data_is_null(MoonbitSkiaData* wrapper) {
  return wrapper == nullptr || wrapper->data == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_bitmap_is_null(MoonbitSkiaBitmap* wrapper) {
  return wrapper == nullptr || wrapper->bitmap == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_is_null(MoonbitSkiaFont* wrapper) {
  return wrapper == nullptr || wrapper->font == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFont*
moonbit_skia_font_default(float size) {
  if (size <= 0.0f) {
    return moonbit_skia_make_font_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkFont* font = new SkFont();
  font->setSize(size);
  return moonbit_skia_make_font_wrapper(font);
#else
  (void)size;
  return moonbit_skia_make_font_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFont*
moonbit_skia_font_from_typeface(MoonbitSkiaTypeface* typeface, float size) {
  if (typeface == nullptr || typeface->typeface == nullptr || size <= 0.0f) {
    return moonbit_skia_make_font_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkFont* font = new SkFont(sk_ref_sp(typeface->typeface), size);
  return moonbit_skia_make_font_wrapper(font);
#else
  (void)size;
  return moonbit_skia_make_font_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_size(MoonbitSkiaFont* wrapper) {
  if (wrapper == nullptr || wrapper->font == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->font->getSize();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_font_set_size(MoonbitSkiaFont* wrapper, float size) {
  if (wrapper == nullptr || wrapper->font == nullptr || size <= 0.0f) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->font->setSize(size);
#else
  (void)size;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_null(MoonbitSkiaTypeface* wrapper) {
  return wrapper == nullptr || wrapper->typeface == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_default(void) {
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkTypeface> typeface = SkTypeface::MakeDefault();
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_from_name(moonbit_bytes_t family_name) {
  if (family_name == nullptr || Moonbit_array_length(family_name) <= 0) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkTypeface> typeface = SkTypeface::MakeFromName(
    reinterpret_cast<const char*>(family_name),
    SkFontStyle()
  );
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_bold(MoonbitSkiaTypeface* wrapper) {
  if (wrapper == nullptr || wrapper->typeface == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->typeface->isBold();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_italic(MoonbitSkiaTypeface* wrapper) {
  if (wrapper == nullptr || wrapper->typeface == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->typeface->isItalic();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_fixed_pitch(MoonbitSkiaTypeface* wrapper) {
  if (wrapper == nullptr || wrapper->typeface == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->typeface->isFixedPitch();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_shader_is_null(MoonbitSkiaShader* wrapper) {
  return wrapper == nullptr || wrapper->shader == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaShader*
moonbit_skia_shader_color(uint32_t color_argb) {
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkShader> shader = SkShaders::Color(static_cast<SkColor>(color_argb));
  if (!shader) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  return moonbit_skia_make_shader_wrapper(shader.release());
#else
  (void)color_argb;
  return moonbit_skia_make_shader_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaShader*
moonbit_skia_shader_linear_gradient(
  float x0,
  float y0,
  float x1,
  float y1,
  uint32_t color0_argb,
  uint32_t color1_argb,
  int32_t tile_mode
) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint points[2] = {
    SkPoint::Make(x0, y0),
    SkPoint::Make(x1, y1)
  };
  SkColor colors[2] = {
    static_cast<SkColor>(color0_argb),
    static_cast<SkColor>(color1_argb)
  };
  sk_sp<SkShader> shader = SkGradientShader::MakeLinear(
    points,
    colors,
    nullptr,
    2,
    static_cast<SkTileMode>(tile_mode)
  );
  if (!shader) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  return moonbit_skia_make_shader_wrapper(shader.release());
#else
  (void)x0;
  (void)y0;
  (void)x1;
  (void)y1;
  (void)color0_argb;
  (void)color1_argb;
  (void)tile_mode;
  return moonbit_skia_make_shader_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaShader*
moonbit_skia_shader_radial_gradient(
  float center_x,
  float center_y,
  float radius,
  uint32_t color0_argb,
  uint32_t color1_argb,
  int32_t tile_mode
) {
  if (radius <= 0.0f) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkColor colors[2] = {
    static_cast<SkColor>(color0_argb),
    static_cast<SkColor>(color1_argb)
  };
  sk_sp<SkShader> shader = SkGradientShader::MakeRadial(
    SkPoint::Make(center_x, center_y),
    radius,
    colors,
    nullptr,
    2,
    static_cast<SkTileMode>(tile_mode)
  );
  if (!shader) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  return moonbit_skia_make_shader_wrapper(shader.release());
#else
  (void)center_x;
  (void)center_y;
  (void)color0_argb;
  (void)color1_argb;
  (void)tile_mode;
  return moonbit_skia_make_shader_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaBitmap*
moonbit_skia_bitmap_alloc_n32_premul(int32_t width, int32_t height) {
  if (width <= 0 || height <= 0) {
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkBitmap* bitmap = new SkBitmap();
  if (!bitmap->tryAllocPixels(SkImageInfo::MakeN32Premul(width, height))) {
    delete bitmap;
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }
  return moonbit_skia_make_bitmap_wrapper(bitmap);
#else
  (void)width;
  (void)height;
  return moonbit_skia_make_bitmap_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_bitmap_width(MoonbitSkiaBitmap* wrapper) {
  if (wrapper == nullptr || wrapper->bitmap == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->bitmap->width();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_bitmap_height(MoonbitSkiaBitmap* wrapper) {
  if (wrapper == nullptr || wrapper->bitmap == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->bitmap->height();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_bitmap_row_bytes(MoonbitSkiaBitmap* wrapper) {
  if (wrapper == nullptr || wrapper->bitmap == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return static_cast<int32_t>(wrapper->bitmap->rowBytes());
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_bitmap_byte_size(MoonbitSkiaBitmap* wrapper) {
  if (wrapper == nullptr || wrapper->bitmap == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return static_cast<int32_t>(wrapper->bitmap->computeByteSize());
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_bitmap_erase_color(MoonbitSkiaBitmap* wrapper, uint32_t color_argb) {
  if (wrapper == nullptr || wrapper->bitmap == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->bitmap->eraseColor(static_cast<SkColor>(color_argb));
#else
  (void)color_argb;
#endif
}

extern "C" MOONBIT_FFI_EXPORT moonbit_bytes_t
moonbit_skia_bitmap_to_bytes(MoonbitSkiaBitmap* wrapper) {
  int32_t size = moonbit_skia_bitmap_byte_size(wrapper);
  moonbit_bytes_t bytes = moonbit_make_bytes(size, 0);
  if (size <= 0 || wrapper == nullptr || wrapper->bitmap == nullptr) {
    return bytes;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  const void* pixels = wrapper->bitmap->getPixels();
  if (pixels != nullptr) {
    memcpy(bytes, pixels, static_cast<size_t>(size));
  }
#endif
  return bytes;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaData*
moonbit_skia_data_from_bytes(moonbit_bytes_t bytes) {
  if (bytes == nullptr) {
    return moonbit_skia_make_data_wrapper(nullptr);
  }
  int32_t size = static_cast<int32_t>(Moonbit_array_length(bytes));
  if (size <= 0) {
    return moonbit_skia_make_data_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkData> data = SkData::MakeWithCopy(bytes, static_cast<size_t>(size));
  if (!data) {
    return moonbit_skia_make_data_wrapper(nullptr);
  }
  return moonbit_skia_make_data_wrapper(data.release());
#else
  (void)bytes;
  return moonbit_skia_make_data_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_data_size(MoonbitSkiaData* wrapper) {
  if (wrapper == nullptr || wrapper->data == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return static_cast<int32_t>(wrapper->data->size());
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT moonbit_bytes_t
moonbit_skia_data_to_bytes(MoonbitSkiaData* wrapper) {
  int32_t size = moonbit_skia_data_size(wrapper);
  moonbit_bytes_t bytes = moonbit_make_bytes(size, 0);
  if (size <= 0 || wrapper == nullptr || wrapper->data == nullptr) {
    return bytes;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  memcpy(bytes, wrapper->data->data(), static_cast<size_t>(size));
#endif
  return bytes;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_codec_is_null(MoonbitSkiaCodec* wrapper) {
  return wrapper == nullptr || wrapper->codec == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaCodec*
moonbit_skia_codec_from_data(MoonbitSkiaData* wrapper) {
  if (wrapper == nullptr || wrapper->data == nullptr) {
    return moonbit_skia_make_codec_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  std::unique_ptr<SkCodec> codec = SkCodec::MakeFromData(
    sk_ref_sp(wrapper->data)
  );
  if (!codec) {
    return moonbit_skia_make_codec_wrapper(nullptr);
  }
  return moonbit_skia_make_codec_wrapper(codec.release());
#else
  return moonbit_skia_make_codec_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_codec_width(MoonbitSkiaCodec* wrapper) {
  if (wrapper == nullptr || wrapper->codec == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->codec->getInfo().width();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_codec_height(MoonbitSkiaCodec* wrapper) {
  if (wrapper == nullptr || wrapper->codec == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->codec->getInfo().height();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_codec_encoded_format(MoonbitSkiaCodec* wrapper) {
  if (wrapper == nullptr || wrapper->codec == nullptr) {
    return -1;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return static_cast<int32_t>(wrapper->codec->getEncodedFormat());
#else
  return -1;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaBitmap*
moonbit_skia_codec_decode_n32_premul(MoonbitSkiaCodec* wrapper) {
  if (wrapper == nullptr || wrapper->codec == nullptr) {
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  int32_t width = wrapper->codec->getInfo().width();
  int32_t height = wrapper->codec->getInfo().height();
  if (width <= 0 || height <= 0) {
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }
  SkBitmap* bitmap = new SkBitmap();
  SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
  if (!bitmap->tryAllocPixels(info)) {
    delete bitmap;
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }
  SkCodec::Result result = wrapper->codec->getPixels(
    info,
    bitmap->getPixels(),
    bitmap->rowBytes()
  );
  if (result != SkCodec::kSuccess) {
    delete bitmap;
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }
  return moonbit_skia_make_bitmap_wrapper(bitmap);
#else
  return moonbit_skia_make_bitmap_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_image_is_null(MoonbitSkiaImage* wrapper) {
  return wrapper == nullptr || wrapper->image == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_image_width(MoonbitSkiaImage* wrapper) {
  if (wrapper == nullptr || wrapper->image == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->image->width();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_image_height(MoonbitSkiaImage* wrapper) {
  if (wrapper == nullptr || wrapper->image == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->image->height();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaImage*
moonbit_skia_image_from_bitmap(MoonbitSkiaBitmap* wrapper) {
  if (wrapper == nullptr || wrapper->bitmap == nullptr) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkImage> image = wrapper->bitmap->asImage();
  if (!image) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
  return moonbit_skia_make_image_wrapper(image.release());
#else
  return moonbit_skia_make_image_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaImage*
moonbit_skia_image_from_encoded_data(MoonbitSkiaData* wrapper) {
  if (wrapper == nullptr || wrapper->data == nullptr) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkImage> image = SkImages::DeferredFromEncodedData(
    sk_ref_sp(wrapper->data)
  );
  if (!image) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
  return moonbit_skia_make_image_wrapper(image.release());
#else
  return moonbit_skia_make_image_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaData*
moonbit_skia_image_encode_to_data(
  MoonbitSkiaImage* wrapper,
  int32_t format,
  int32_t quality
) {
  if (wrapper == nullptr || wrapper->image == nullptr) {
    return moonbit_skia_make_data_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkData> data = wrapper->image->encodeToData(
    static_cast<SkEncodedImageFormat>(format),
    quality
  );
  if (!data) {
    return moonbit_skia_make_data_wrapper(nullptr);
  }
  return moonbit_skia_make_data_wrapper(data.release());
#else
  (void)format;
  (void)quality;
  return moonbit_skia_make_data_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaPath* moonbit_skia_path_new(void) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_make_path_wrapper(new SkPath());
#else
  return moonbit_skia_make_path_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_null(MoonbitSkiaPath* wrapper) {
  return wrapper == nullptr || wrapper->path == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_path_reset(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->path->reset();
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_move_to(
  MoonbitSkiaPath* wrapper,
  float x,
  float y
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->path->moveTo(x, y);
#else
  (void)x;
  (void)y;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_line_to(
  MoonbitSkiaPath* wrapper,
  float x,
  float y
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->path->lineTo(x, y);
#else
  (void)x;
  (void)y;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_quad_to(
  MoonbitSkiaPath* wrapper,
  float x1,
  float y1,
  float x2,
  float y2
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->path->quadTo(x1, y1, x2, y2);
#else
  (void)x1;
  (void)y1;
  (void)x2;
  (void)y2;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_cubic_to(
  MoonbitSkiaPath* wrapper,
  float x1,
  float y1,
  float x2,
  float y2,
  float x3,
  float y3
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->path->cubicTo(x1, y1, x2, y2, x3, y3);
#else
  (void)x1;
  (void)y1;
  (void)x2;
  (void)y2;
  (void)x3;
  (void)y3;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_path_close(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->path->close();
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_empty(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 1;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->isEmpty();
#else
  return 1;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_raster_n32_premul(int32_t width, int32_t height) {
  if (width <= 0 || height <= 0) {
    return moonbit_skia_make_surface_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
  sk_sp<SkSurface> surface = SkSurfaces::Raster(info);
  if (!surface) {
    return moonbit_skia_make_surface_wrapper(nullptr);
  }
  return moonbit_skia_make_surface_wrapper(surface.release());
#else
  (void)width;
  (void)height;
  return moonbit_skia_make_surface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaImage*
moonbit_skia_surface_image_snapshot(MoonbitSkiaSurface* wrapper) {
  if (wrapper == nullptr || wrapper->surface == nullptr) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkImage> image = wrapper->surface->makeImageSnapshot();
  if (!image) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
  return moonbit_skia_make_image_wrapper(image.release());
#else
  return moonbit_skia_make_image_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaImage*
moonbit_skia_surface_image_snapshot_with_bounds(
  MoonbitSkiaSurface* wrapper,
  int32_t left,
  int32_t top,
  int32_t right,
  int32_t bottom
) {
  if (
    wrapper == nullptr ||
    wrapper->surface == nullptr ||
    right <= left ||
    bottom <= top
  ) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkImage> image = wrapper->surface->makeImageSnapshot(
    SkIRect::MakeLTRB(left, top, right, bottom)
  );
  if (!image) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
  return moonbit_skia_make_image_wrapper(image.release());
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  return moonbit_skia_make_image_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT moonbit_bytes_t
moonbit_skia_surface_read_pixels(
  MoonbitSkiaSurface* wrapper,
  int32_t left,
  int32_t top,
  int32_t width,
  int32_t height
) {
  int32_t row_bytes = width > 0 ? width * 4 : 0;
  int32_t size = height > 0 ? row_bytes * height : 0;
  moonbit_bytes_t bytes = moonbit_make_bytes(size, 0);
  if (
    size <= 0 ||
    wrapper == nullptr ||
    wrapper->surface == nullptr
  ) {
    return bytes;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
  wrapper->surface->readPixels(
    info,
    bytes,
    static_cast<size_t>(row_bytes),
    left,
    top
  );
#else
  (void)left;
  (void)top;
#endif
  return bytes;
}

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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_is_null(MoonbitSkiaSurface* wrapper) {
  return wrapper == nullptr || wrapper->surface == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_width(MoonbitSkiaSurface* wrapper) {
  if (wrapper == nullptr || wrapper->surface == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->surface->width();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_height(MoonbitSkiaSurface* wrapper) {
  if (wrapper == nullptr || wrapper->surface == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->surface->height();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaCanvas*
moonbit_skia_surface_canvas(MoonbitSkiaSurface* wrapper) {
  if (wrapper == nullptr || wrapper->surface == nullptr) {
    return moonbit_skia_make_canvas_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_make_canvas_wrapper(wrapper->surface->getCanvas());
#else
  return moonbit_skia_make_canvas_wrapper(nullptr);
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
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->canvas->save();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_canvas_restore(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
  wrapper->canvas->resetMatrix();
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_canvas_discard(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_color(
  MoonbitSkiaCanvas* wrapper,
  uint32_t color_argb,
  int32_t blend_mode
) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
