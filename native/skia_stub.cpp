#include <moonbit.h>

#include <string.h>
#include <stdint.h>
#include <stddef.h>
#include <memory>
#include <vector>

#if defined(SKIA_MBT_HAS_SKIA)
#if defined(_WIN32) && !defined(SK_BUILD_FOR_WIN)
#define SK_BUILD_FOR_WIN
#endif
#if defined(__APPLE__) && !defined(SK_BUILD_FOR_MAC)
#define SK_BUILD_FOR_MAC
#endif
#include "include/core/SkCanvas.h"
#include "include/core/SkBitmap.h"
#include "include/core/SkClipOp.h"
#include "include/core/SkColor.h"
#include "include/core/SkData.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMetrics.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkFontStyle.h"
#include "include/core/SkImage.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkPathTypes.h"
#if __has_include("include/core/SkPathBuilder.h")
#include "include/core/SkPathBuilder.h"
#define SKIA_MBT_HAS_PATH_BUILDER 1
#endif
#include "include/core/SkPoint.h"
#include "include/core/SkRect.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSamplingOptions.h"
#include "include/core/SkShader.h"
#include "include/core/SkString.h"
#include "include/core/SkSurface.h"
#include "include/core/SkTypeface.h"
#include "include/core/SkTypes.h"
#include "include/codec/SkCodec.h"
#include "include/codec/SkEncodedImageFormat.h"
#include "include/encode/SkJpegEncoder.h"
#include "include/encode/SkPngEncoder.h"
#include "include/encode/SkWebpEncoder.h"
#if __has_include("include/effects/SkColorFilter.h")
#include "include/effects/SkColorFilter.h"
#define SKIA_MBT_HAS_LEGACY_COLOR_FILTER 1
#elif __has_include("include/core/SkColorFilter.h")
#include "include/core/SkColorFilter.h"
#define SKIA_MBT_HAS_CORE_COLOR_FILTER 1
#endif
#if __has_include("include/effects/SkImageFilters.h")
#include "include/effects/SkImageFilters.h"
#define SKIA_MBT_HAS_IMAGE_FILTERS 1
#endif
#if __has_include("include/core/SkMaskFilter.h")
#include "include/core/SkMaskFilter.h"
#define SKIA_MBT_HAS_MASK_FILTER 1
#endif
#if __has_include("include/core/SkBlurTypes.h")
#include "include/core/SkBlurTypes.h"
#define SKIA_MBT_HAS_BLUR_TYPES 1
#endif
#if __has_include("include/effects/SkGradientShader.h")
#include "include/effects/SkGradientShader.h"
#define SKIA_MBT_HAS_LEGACY_GRADIENT_SHADER 1
#elif __has_include("include/effects/SkGradient.h")
#include "include/effects/SkGradient.h"
#define SKIA_MBT_HAS_NEW_GRADIENT_SHADER 1
#endif
#include "include/core/SkRefCnt.h"
#if defined(_WIN32)
#include "include/ports/SkTypeface_win.h"
#endif
#if defined(__APPLE__)
#include "include/ports/SkFontMgr_mac_ct.h"
#endif
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
  SkSurface* surface_owner;
#else
  void* canvas;
  void* surface_owner;
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

struct MoonbitSkiaFontMgr {
#if defined(SKIA_MBT_HAS_SKIA)
  SkFontMgr* font_mgr;
#else
  void* font_mgr;
#endif
};

struct MoonbitSkiaShader {
#if defined(SKIA_MBT_HAS_SKIA)
  SkShader* shader;
#else
  void* shader;
#endif
};

struct MoonbitSkiaColorFilter {
#if defined(SKIA_MBT_HAS_SKIA) && \
  (defined(SKIA_MBT_HAS_LEGACY_COLOR_FILTER) || defined(SKIA_MBT_HAS_CORE_COLOR_FILTER))
  SkColorFilter* color_filter;
#else
  void* color_filter;
#endif
};

struct MoonbitSkiaImageFilter {
#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_IMAGE_FILTERS)
  SkImageFilter* image_filter;
#else
  void* image_filter;
#endif
};

struct MoonbitSkiaMaskFilter {
#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_MASK_FILTER)
  SkMaskFilter* mask_filter;
#else
  void* mask_filter;
#endif
};

struct MoonbitSkiaBitmap {
#if defined(SKIA_MBT_HAS_SKIA)
  SkBitmap* bitmap;
#else
  void* bitmap;
#endif
};

struct MoonbitSkiaFloatArray {
  int32_t length;
  float* buffer;
};

struct MoonbitSkiaGlyphIdArray {
  int32_t length;
  uint16_t* buffer;
};

struct MoonbitSkiaPoint {
  float x;
  float y;
};

struct MoonbitSkiaRect {
  float left;
  float top;
  float right;
  float bottom;
};

struct MoonbitSkiaPointArray {
  int32_t length;
  MoonbitSkiaPoint** buffer;
};

struct MoonbitSkiaRectArray {
  int32_t length;
  MoonbitSkiaRect** buffer;
};

static uint32_t moonbit_skia_regular_object_header(
  uint32_t pointer_field_offset_words,
  uint32_t pointer_field_count,
  uint32_t tag
) {
  return (
    (static_cast<uint32_t>(moonbit_BLOCK_KIND_REGULAR) << 30) |
    ((pointer_field_offset_words & (((uint32_t)1 << 11) - 1)) << 19) |
    ((pointer_field_count & (((uint32_t)1 << 11) - 1)) << 8) |
    (tag & 0xFF)
  );
}

static MoonbitSkiaFloatArray* moonbit_skia_make_float_array(
  int32_t length,
  float* buffer
) {
  MoonbitSkiaFloatArray* array = static_cast<MoonbitSkiaFloatArray*>(
    moonbit_malloc(sizeof(MoonbitSkiaFloatArray))
  );
  Moonbit_object_header(array)->meta = moonbit_skia_regular_object_header(
    static_cast<uint32_t>(offsetof(MoonbitSkiaFloatArray, buffer) >> 2),
    1,
    0
  );
  array->length = length;
  array->buffer = buffer;
  return array;
}

static MoonbitSkiaGlyphIdArray* moonbit_skia_make_glyph_id_array(
  int32_t length,
  uint16_t* buffer
) {
  MoonbitSkiaGlyphIdArray* array = static_cast<MoonbitSkiaGlyphIdArray*>(
    moonbit_malloc(sizeof(MoonbitSkiaGlyphIdArray))
  );
  Moonbit_object_header(array)->meta = moonbit_skia_regular_object_header(
    static_cast<uint32_t>(offsetof(MoonbitSkiaGlyphIdArray, buffer) >> 2),
    1,
    0
  );
  array->length = length;
  array->buffer = buffer;
  return array;
}

static MoonbitSkiaPoint* moonbit_skia_make_point(float x, float y) {
  MoonbitSkiaPoint* point = static_cast<MoonbitSkiaPoint*>(
    moonbit_malloc(sizeof(MoonbitSkiaPoint))
  );
  Moonbit_object_header(point)->meta = moonbit_skia_regular_object_header(
    static_cast<uint32_t>(sizeof(MoonbitSkiaPoint) >> 2),
    0,
    0
  );
  point->x = x;
  point->y = y;
  return point;
}

static MoonbitSkiaRect* moonbit_skia_make_rect(
  float left,
  float top,
  float right,
  float bottom
) {
  MoonbitSkiaRect* rect = static_cast<MoonbitSkiaRect*>(
    moonbit_malloc(sizeof(MoonbitSkiaRect))
  );
  Moonbit_object_header(rect)->meta = moonbit_skia_regular_object_header(
    static_cast<uint32_t>(sizeof(MoonbitSkiaRect) >> 2),
    0,
    0
  );
  rect->left = left;
  rect->top = top;
  rect->right = right;
  rect->bottom = bottom;
  return rect;
}

static MoonbitSkiaPointArray* moonbit_skia_make_point_array(
  int32_t length,
  MoonbitSkiaPoint** buffer
) {
  MoonbitSkiaPointArray* array = static_cast<MoonbitSkiaPointArray*>(
    moonbit_malloc(sizeof(MoonbitSkiaPointArray))
  );
  Moonbit_object_header(array)->meta = moonbit_skia_regular_object_header(
    static_cast<uint32_t>(offsetof(MoonbitSkiaPointArray, buffer) >> 2),
    1,
    0
  );
  array->length = length;
  array->buffer = buffer;
  return array;
}

static MoonbitSkiaRectArray* moonbit_skia_make_rect_array(
  int32_t length,
  MoonbitSkiaRect** buffer
) {
  MoonbitSkiaRectArray* array = static_cast<MoonbitSkiaRectArray*>(
    moonbit_malloc(sizeof(MoonbitSkiaRectArray))
  );
  Moonbit_object_header(array)->meta = moonbit_skia_regular_object_header(
    static_cast<uint32_t>(offsetof(MoonbitSkiaRectArray, buffer) >> 2),
    1,
    0
  );
  array->length = length;
  array->buffer = buffer;
  return array;
}

#if defined(SKIA_MBT_HAS_SKIA)
static moonbit_bytes_t moonbit_skia_make_bytes_from_sk_string(
  const SkString& value
) {
  if (value.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes_raw(
    static_cast<int32_t>(value.size())
  );
  if (value.size() > 0) {
    memcpy(bytes, value.data(), value.size());
  }
  return bytes;
}
#endif

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

static void moonbit_skia_font_mgr_finalize(void* ptr) {
  MoonbitSkiaFontMgr* wrapper = static_cast<MoonbitSkiaFontMgr*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA)
  if (wrapper->font_mgr != nullptr) {
    wrapper->font_mgr->unref();
    wrapper->font_mgr = nullptr;
  }
#else
  wrapper->font_mgr = nullptr;
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

static void moonbit_skia_color_filter_finalize(void* ptr) {
  MoonbitSkiaColorFilter* wrapper = static_cast<MoonbitSkiaColorFilter*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA) && \
  (defined(SKIA_MBT_HAS_LEGACY_COLOR_FILTER) || defined(SKIA_MBT_HAS_CORE_COLOR_FILTER))
  if (wrapper->color_filter != nullptr) {
    wrapper->color_filter->unref();
    wrapper->color_filter = nullptr;
  }
#else
  wrapper->color_filter = nullptr;
#endif
}

static void moonbit_skia_image_filter_finalize(void* ptr) {
  MoonbitSkiaImageFilter* wrapper = static_cast<MoonbitSkiaImageFilter*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_IMAGE_FILTERS)
  if (wrapper->image_filter != nullptr) {
    wrapper->image_filter->unref();
    wrapper->image_filter = nullptr;
  }
#else
  wrapper->image_filter = nullptr;
#endif
}

static void moonbit_skia_mask_filter_finalize(void* ptr) {
  MoonbitSkiaMaskFilter* wrapper = static_cast<MoonbitSkiaMaskFilter*>(ptr);
#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_MASK_FILTER)
  if (wrapper->mask_filter != nullptr) {
    wrapper->mask_filter->unref();
    wrapper->mask_filter = nullptr;
  }
#else
  wrapper->mask_filter = nullptr;
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
#if defined(SKIA_MBT_HAS_SKIA)
  if (wrapper->surface_owner != nullptr) {
    wrapper->surface_owner->unref();
    wrapper->surface_owner = nullptr;
  }
#else
  wrapper->surface_owner = nullptr;
#endif
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

static MoonbitSkiaFontMgr* moonbit_skia_make_font_mgr_wrapper(
#if defined(SKIA_MBT_HAS_SKIA)
  SkFontMgr* font_mgr
#else
  void* font_mgr
#endif
) {
  MoonbitSkiaFontMgr* wrapper = static_cast<MoonbitSkiaFontMgr*>(
    moonbit_make_external_object(
      moonbit_skia_font_mgr_finalize,
      sizeof(MoonbitSkiaFontMgr)
    )
  );
  wrapper->font_mgr = font_mgr;
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

static MoonbitSkiaColorFilter* moonbit_skia_make_color_filter_wrapper(
#if defined(SKIA_MBT_HAS_SKIA) && \
  (defined(SKIA_MBT_HAS_LEGACY_COLOR_FILTER) || defined(SKIA_MBT_HAS_CORE_COLOR_FILTER))
  SkColorFilter* color_filter
#else
  void* color_filter
#endif
) {
  MoonbitSkiaColorFilter* wrapper = static_cast<MoonbitSkiaColorFilter*>(
    moonbit_make_external_object(
      moonbit_skia_color_filter_finalize,
      sizeof(MoonbitSkiaColorFilter)
    )
  );
  wrapper->color_filter = color_filter;
  return wrapper;
}

static MoonbitSkiaImageFilter* moonbit_skia_make_image_filter_wrapper(
#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_IMAGE_FILTERS)
  SkImageFilter* image_filter
#else
  void* image_filter
#endif
) {
  MoonbitSkiaImageFilter* wrapper = static_cast<MoonbitSkiaImageFilter*>(
    moonbit_make_external_object(
      moonbit_skia_image_filter_finalize,
      sizeof(MoonbitSkiaImageFilter)
    )
  );
  wrapper->image_filter = image_filter;
  return wrapper;
}

static MoonbitSkiaMaskFilter* moonbit_skia_make_mask_filter_wrapper(
#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_MASK_FILTER)
  SkMaskFilter* mask_filter
#else
  void* mask_filter
#endif
) {
  MoonbitSkiaMaskFilter* wrapper = static_cast<MoonbitSkiaMaskFilter*>(
    moonbit_make_external_object(
      moonbit_skia_mask_filter_finalize,
      sizeof(MoonbitSkiaMaskFilter)
    )
  );
  wrapper->mask_filter = mask_filter;
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

#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_PATH_BUILDER)
template <typename Mutate>
static void moonbit_skia_path_mutate(
  MoonbitSkiaPath* wrapper,
  Mutate mutate
) {
  SkPathBuilder builder(*wrapper->path);
  mutate(builder);
  *wrapper->path = builder.snapshot();
}
#endif

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

#if defined(SKIA_MBT_HAS_SKIA)
#if defined(_WIN32)
static SkFontMgr* moonbit_skia_windows_font_mgr(void) {
  static sk_sp<SkFontMgr> font_mgr = SkFontMgr_New_DirectWrite();
  if (!font_mgr) {
    font_mgr = SkFontMgr_New_GDI();
  }
  return font_mgr.get();
}

static sk_sp<SkTypeface> moonbit_skia_windows_typeface_from_family(
  const char* family_name,
  const SkFontStyle& style
) {
  SkFontMgr* font_mgr = moonbit_skia_windows_font_mgr();
  if (font_mgr == nullptr) {
    return nullptr;
  }

  const bool has_family_name = family_name != nullptr && family_name[0] != '\0';
  if (has_family_name) {
    sk_sp<SkTypeface> typeface = font_mgr->matchFamilyStyle(
      family_name,
      style
    );
    if (typeface) {
      return typeface;
    }
  }

  const char* zh_bcp47[] = {"zh-Hans", "zh"};
  return font_mgr->matchFamilyStyleCharacter(
    has_family_name ? family_name : nullptr,
    style,
    zh_bcp47,
    2,
    0x4F60
  );
}
#endif

#if defined(__APPLE__)
static SkFontMgr* moonbit_skia_macos_font_mgr(void) {
  static sk_sp<SkFontMgr> font_mgr = SkFontMgr_New_CoreText(nullptr);
  return font_mgr.get();
}

static sk_sp<SkTypeface> moonbit_skia_macos_typeface_from_family(
  const char* family_name,
  const SkFontStyle& style
) {
  SkFontMgr* font_mgr = moonbit_skia_macos_font_mgr();
  if (font_mgr == nullptr) {
    return nullptr;
  }

  const bool has_family_name = family_name != nullptr && family_name[0] != '\0';
  if (has_family_name) {
    sk_sp<SkTypeface> typeface = font_mgr->matchFamilyStyle(
      family_name,
      style
    );
    if (typeface) {
      return typeface;
    }
  }

  const char* zh_bcp47[] = {"zh-Hans", "zh"};
  return font_mgr->matchFamilyStyleCharacter(
    has_family_name ? family_name : nullptr,
    style,
    zh_bcp47,
    2,
    0x4F60
  );
}
#endif

static sk_sp<SkTypeface> moonbit_skia_default_typeface(void) {
#if defined(_WIN32)
  sk_sp<SkTypeface> typeface =
    moonbit_skia_windows_typeface_from_family(
      "Microsoft YaHei",
      SkFontStyle::Normal()
    );
  if (typeface) {
    return typeface;
  }
  typeface = moonbit_skia_windows_typeface_from_family(
    "SimSun",
    SkFontStyle::Normal()
  );
  if (typeface) {
    return typeface;
  }
  return moonbit_skia_windows_typeface_from_family(
    nullptr,
    SkFontStyle::Normal()
  );
#elif defined(__APPLE__)
  sk_sp<SkTypeface> typeface =
    moonbit_skia_macos_typeface_from_family(
      "PingFang SC",
      SkFontStyle::Normal()
    );
  if (typeface) {
    return typeface;
  }
  typeface = moonbit_skia_macos_typeface_from_family(
    "Hiragino Sans GB",
    SkFontStyle::Normal()
  );
  if (typeface) {
    return typeface;
  }
  typeface = moonbit_skia_macos_typeface_from_family(
    "Helvetica Neue",
    SkFontStyle::Normal()
  );
  if (typeface) {
    return typeface;
  }
  return moonbit_skia_macos_typeface_from_family(
    nullptr,
    SkFontStyle::Normal()
  );
#endif
  return SkTypeface::MakeEmpty();
}

static sk_sp<SkTypeface> moonbit_skia_typeface_from_family(
  const char* family_name,
  const SkFontStyle& style
) {
#if defined(_WIN32)
  return moonbit_skia_windows_typeface_from_family(family_name, style);
#elif defined(__APPLE__)
  return moonbit_skia_macos_typeface_from_family(family_name, style);
#else
  (void)family_name;
  (void)style;
#endif
  return SkTypeface::MakeEmpty();
}

static sk_sp<SkFontMgr> moonbit_skia_default_font_mgr(void) {
#if defined(_WIN32)
  SkFontMgr* font_mgr = moonbit_skia_windows_font_mgr();
  if (font_mgr == nullptr) {
    return nullptr;
  }
  font_mgr->ref();
  return sk_sp<SkFontMgr>(font_mgr);
#elif defined(__APPLE__)
  SkFontMgr* font_mgr = moonbit_skia_macos_font_mgr();
  if (font_mgr == nullptr) {
    return nullptr;
  }
  font_mgr->ref();
  return sk_sp<SkFontMgr>(font_mgr);
#else
  return SkFontMgr::RefEmpty();
#endif
}
#endif

static int32_t moonbit_skia_clamp_int32(
  int32_t value,
  int32_t min_value,
  int32_t max_value
) {
  if (value < min_value) {
    return min_value;
  }
  if (value > max_value) {
    return max_value;
  }
  return value;
}

#if defined(SKIA_MBT_HAS_SKIA)
static SkFontStyle moonbit_skia_font_style(
  int32_t weight,
  int32_t width,
  int32_t slant
) {
  SkFontStyle::Slant skia_slant = SkFontStyle::kUpright_Slant;
  switch (moonbit_skia_clamp_int32(slant, 0, 2)) {
    case 1:
      skia_slant = SkFontStyle::kItalic_Slant;
      break;
    case 2:
      skia_slant = SkFontStyle::kOblique_Slant;
      break;
    default:
      skia_slant = SkFontStyle::kUpright_Slant;
      break;
  }
  return SkFontStyle(
    moonbit_skia_clamp_int32(weight, 1, 1000),
    moonbit_skia_clamp_int32(width, 1, 9),
    skia_slant
  );
}
#endif

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
  SkCanvas* canvas,
  SkSurface* surface_owner
#else
  void* canvas,
  void* surface_owner
#endif
) {
  MoonbitSkiaCanvas* wrapper = static_cast<MoonbitSkiaCanvas*>(
    moonbit_make_external_object(
      moonbit_skia_canvas_finalize,
      sizeof(MoonbitSkiaCanvas)
    )
  );
  wrapper->canvas = canvas;
  wrapper->surface_owner = surface_owner;
#if defined(SKIA_MBT_HAS_SKIA)
  if (wrapper->surface_owner != nullptr) {
    wrapper->surface_owner->ref();
  }
#endif
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
  int32_t blend_mode,
  MoonbitSkiaColorFilter* color_filter,
  MoonbitSkiaImageFilter* image_filter,
  MoonbitSkiaMaskFilter* mask_filter
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
#if defined(SKIA_MBT_HAS_LEGACY_COLOR_FILTER) || defined(SKIA_MBT_HAS_CORE_COLOR_FILTER)
  if (color_filter != nullptr && color_filter->color_filter != nullptr) {
    paint.setColorFilter(sk_ref_sp(color_filter->color_filter));
  }
#else
  (void)color_filter;
#endif
#if defined(SKIA_MBT_HAS_IMAGE_FILTERS)
  if (image_filter != nullptr && image_filter->image_filter != nullptr) {
    paint.setImageFilter(sk_ref_sp(image_filter->image_filter));
  }
#else
  (void)image_filter;
#endif
#if defined(SKIA_MBT_HAS_MASK_FILTER)
  if (mask_filter != nullptr && mask_filter->mask_filter != nullptr) {
    paint.setMaskFilter(sk_ref_sp(mask_filter->mask_filter));
  }
#else
  (void)mask_filter;
#endif
  return paint;
}

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
  return moonbit_skia_make_paint(
    color_argb,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode,
    nullptr,
    nullptr,
    nullptr
  );
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

static SkImageInfo moonbit_skia_make_rgba8888_premul_info(
  int32_t width,
  int32_t height
) {
  return SkImageInfo::Make(
    width,
    height,
    kRGBA_8888_SkColorType,
    kPremul_SkAlphaType
  );
}

static SkRRect moonbit_skia_make_rrect(
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
  float lower_left_height
) {
  SkVector radii[4] = {
    {upper_left_width, upper_left_height},
    {upper_right_width, upper_right_height},
    {lower_right_width, lower_right_height},
    {lower_left_width, lower_left_height}
  };
  SkRRect rrect;
  rrect.setRectRadii(SkRect::MakeLTRB(left, top, right, bottom), radii);
  return rrect;
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_available(void) {
#if defined(SKIA_MBT_HAS_SKIA)
  return 1;
#else
  return 0;
#endif
}

#if defined(SKIA_MBT_HAS_SKIA)
static SkFontMetrics moonbit_skia_get_font_metrics(MoonbitSkiaFont* wrapper) {
  SkFontMetrics metrics = {};
  if (wrapper != nullptr && wrapper->font != nullptr) {
    wrapper->font->getMetrics(&metrics);
  }
  return metrics;
}
#endif

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
  sk_sp<SkTypeface> typeface = moonbit_skia_default_typeface();
  SkFont* font = typeface ? new SkFont(typeface, size) : new SkFont();
  if (!typeface) {
    font->setSize(size);
  }
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

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_utf8(MoonbitSkiaFont* wrapper, moonbit_bytes_t text) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    Moonbit_array_length(text) <= 0
  ) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->font->measureText(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8
  );
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_count_text_utf8(MoonbitSkiaFont* wrapper, moonbit_bytes_t text) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    Moonbit_array_length(text) <= 0
  ) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  size_t glyph_count = wrapper->font->countText(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8
  );
  if (glyph_count > static_cast<size_t>(INT32_MAX)) {
    return INT32_MAX;
  }
  return static_cast<int32_t>(glyph_count);
#else
  return 0;
#endif
}

#if defined(SKIA_MBT_HAS_SKIA)
static bool moonbit_skia_font_text_to_glyphs_utf8_vector(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  std::vector<SkGlyphID>* glyphs
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    glyphs == nullptr ||
    Moonbit_array_length(text) <= 0
  ) {
    return false;
  }

  size_t glyph_count = wrapper->font->countText(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8
  );
  if (glyph_count == 0) {
    return false;
  }

  glyphs->resize(glyph_count);
  size_t copied = wrapper->font->textToGlyphs(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8,
    SkSpan<SkGlyphID>(glyphs->data(), glyphs->size())
  );
  if (copied == 0) {
    glyphs->clear();
    return false;
  }
  if (copied < glyphs->size()) {
    glyphs->resize(copied);
  }
  return true;
}

static int32_t moonbit_skia_font_text_to_glyphs_utf8_at(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index
) {
  if (index < 0) {
    return 0;
  }

  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(wrapper, text, &glyphs)) {
    return 0;
  }
  if (static_cast<size_t>(index) >= glyphs.size()) {
    return 0;
  }
  return static_cast<int32_t>(glyphs[static_cast<size_t>(index)]);
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_text_to_glyphs_utf8_value(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index
) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_font_text_to_glyphs_utf8_at(wrapper, text, index);
#else
  (void)wrapper;
  (void)text;
  (void)index;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaGlyphIdArray*
moonbit_skia_font_text_to_glyphs_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(SKIA_MBT_HAS_SKIA)
  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(
    wrapper,
    text,
    &glyphs
  ) || glyphs.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_skia_make_glyph_id_array(0, moonbit_empty_int16_array);
  }

  uint16_t* buffer = moonbit_make_string_raw(
    static_cast<int32_t>(glyphs.size())
  );
  for (size_t i = 0; i < glyphs.size(); ++i) {
    buffer[i] = static_cast<uint16_t>(glyphs[i]);
  }
  return moonbit_skia_make_glyph_id_array(
    static_cast<int32_t>(glyphs.size()),
    buffer
  );
#else
  (void)wrapper;
  (void)text;
  return moonbit_skia_make_glyph_id_array(0, moonbit_empty_int16_array);
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_width(MoonbitSkiaFont* wrapper, int32_t glyph) {
  if (wrapper == nullptr || wrapper->font == nullptr || glyph < 0) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->font->getWidth(static_cast<SkGlyphID>(glyph));
#else
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFloatArray*
moonbit_skia_font_glyph_widths(
  MoonbitSkiaFont* wrapper,
  MoonbitSkiaGlyphIdArray* glyphs
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    glyphs == nullptr ||
    glyphs->length <= 0 ||
    glyphs->buffer == nullptr
  ) {
    return moonbit_skia_make_float_array(0, moonbit_empty_float_array);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  float* buffer = moonbit_make_float_array_raw(glyphs->length);
  for (int32_t i = 0; i < glyphs->length; ++i) {
    buffer[i] = wrapper->font->getWidth(
      static_cast<SkGlyphID>(glyphs->buffer[i])
    );
  }
  return moonbit_skia_make_float_array(glyphs->length, buffer);
#else
  return moonbit_skia_make_float_array(0, moonbit_empty_float_array);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaPointArray*
moonbit_skia_font_text_glyph_positions_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  float origin_x,
  float origin_y
) {
#if defined(SKIA_MBT_HAS_SKIA)
  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(
    wrapper,
    text,
    &glyphs
  ) || glyphs.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_skia_make_point_array(
      0,
      reinterpret_cast<MoonbitSkiaPoint**>(moonbit_empty_ref_array)
    );
  }

  std::vector<SkPoint> positions(glyphs.size());
  wrapper->font->getPos(
    SkSpan<const SkGlyphID>(glyphs.data(), glyphs.size()),
    SkSpan<SkPoint>(positions.data(), positions.size()),
    SkPoint::Make(origin_x, origin_y)
  );

  MoonbitSkiaPoint** buffer = reinterpret_cast<MoonbitSkiaPoint**>(
    moonbit_make_ref_array_raw(static_cast<int32_t>(positions.size()))
  );
  for (size_t i = 0; i < positions.size(); ++i) {
    buffer[i] = moonbit_skia_make_point(positions[i].x(), positions[i].y());
  }
  return moonbit_skia_make_point_array(
    static_cast<int32_t>(positions.size()),
    buffer
  );
#else
  (void)wrapper;
  (void)text;
  (void)origin_x;
  (void)origin_y;
  return moonbit_skia_make_point_array(
    0,
    reinterpret_cast<MoonbitSkiaPoint**>(moonbit_empty_ref_array)
  );
#endif
}

#if defined(SKIA_MBT_HAS_SKIA)
static SkPoint moonbit_skia_font_text_glyph_position_utf8_point(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin_x,
  float origin_y
) {
  if (index < 0) {
    return SkPoint::Make(0.0f, 0.0f);
  }

  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(wrapper, text, &glyphs)) {
    return SkPoint::Make(0.0f, 0.0f);
  }
  if (static_cast<size_t>(index) >= glyphs.size()) {
    return SkPoint::Make(0.0f, 0.0f);
  }

  std::vector<SkPoint> positions(glyphs.size());
  wrapper->font->getPos(
    SkSpan<const SkGlyphID>(glyphs.data(), glyphs.size()),
    SkSpan<SkPoint>(positions.data(), positions.size()),
    SkPoint::Make(origin_x, origin_y)
  );
  return positions[static_cast<size_t>(index)];
}

static bool moonbit_skia_font_text_glyph_x_positions_utf8_vector(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  float origin,
  std::vector<SkScalar>* positions
) {
  if (positions == nullptr) {
    return false;
  }

  std::vector<SkGlyphID> glyphs;
  if (!moonbit_skia_font_text_to_glyphs_utf8_vector(wrapper, text, &glyphs)) {
    return false;
  }

  positions->resize(glyphs.size());
  wrapper->font->getXPos(
    SkSpan<const SkGlyphID>(glyphs.data(), glyphs.size()),
    SkSpan<SkScalar>(positions->data(), positions->size()),
    origin
  );
  return true;
}

static float moonbit_skia_font_text_glyph_x_position_utf8_value(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin
) {
  if (index < 0) {
    return 0.0f;
  }

  std::vector<SkScalar> positions;
  if (!moonbit_skia_font_text_glyph_x_positions_utf8_vector(
    wrapper,
    text,
    origin,
    &positions
  )) {
    return 0.0f;
  }
  if (static_cast<size_t>(index) >= positions.size()) {
    return 0.0f;
  }
  return positions[static_cast<size_t>(index)];
}
#endif

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_text_glyph_position_utf8_x(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin_x,
  float origin_y
) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_font_text_glyph_position_utf8_point(
    wrapper,
    text,
    index,
    origin_x,
    origin_y
  ).x();
#else
  (void)wrapper;
  (void)text;
  (void)index;
  (void)origin_x;
  (void)origin_y;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_text_glyph_position_utf8_y(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin_x,
  float origin_y
) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_font_text_glyph_position_utf8_point(
    wrapper,
    text,
    index,
    origin_x,
    origin_y
  ).y();
#else
  (void)wrapper;
  (void)text;
  (void)index;
  (void)origin_x;
  (void)origin_y;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_text_glyph_x_position_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  int32_t index,
  float origin
) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_font_text_glyph_x_position_utf8_value(
    wrapper,
    text,
    index,
    origin
  );
#else
  (void)wrapper;
  (void)text;
  (void)index;
  (void)origin;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFloatArray*
moonbit_skia_font_text_glyph_x_positions_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  float origin
) {
#if defined(SKIA_MBT_HAS_SKIA)
  std::vector<SkScalar> positions;
  if (!moonbit_skia_font_text_glyph_x_positions_utf8_vector(
    wrapper,
    text,
    origin,
    &positions
  ) || positions.size() > static_cast<size_t>(INT32_MAX)) {
    return moonbit_skia_make_float_array(0, moonbit_empty_float_array);
  }

  float* buffer = moonbit_make_float_array_raw(
    static_cast<int32_t>(positions.size())
  );
  for (size_t i = 0; i < positions.size(); ++i) {
    buffer[i] = positions[i];
  }
  return moonbit_skia_make_float_array(
    static_cast<int32_t>(positions.size()),
    buffer
  );
#else
  (void)wrapper;
  (void)text;
  (void)origin;
  return moonbit_skia_make_float_array(0, moonbit_empty_float_array);
#endif
}

#if defined(SKIA_MBT_HAS_SKIA)
static SkRect moonbit_skia_font_glyph_bounds_rect(
  MoonbitSkiaFont* wrapper,
  int32_t glyph
) {
  if (wrapper == nullptr || wrapper->font == nullptr || glyph < 0) {
    return SkRect::MakeEmpty();
  }
  return wrapper->font->getBounds(static_cast<SkGlyphID>(glyph), nullptr);
}
#endif

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_bounds_left(MoonbitSkiaFont* wrapper, int32_t glyph) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_font_glyph_bounds_rect(wrapper, glyph).left();
#else
  (void)wrapper;
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_bounds_top(MoonbitSkiaFont* wrapper, int32_t glyph) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_font_glyph_bounds_rect(wrapper, glyph).top();
#else
  (void)wrapper;
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_bounds_right(MoonbitSkiaFont* wrapper, int32_t glyph) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_font_glyph_bounds_rect(wrapper, glyph).right();
#else
  (void)wrapper;
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_glyph_bounds_bottom(MoonbitSkiaFont* wrapper, int32_t glyph) {
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_font_glyph_bounds_rect(wrapper, glyph).bottom();
#else
  (void)wrapper;
  (void)glyph;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaRectArray*
moonbit_skia_font_glyph_bounds_many(
  MoonbitSkiaFont* wrapper,
  MoonbitSkiaGlyphIdArray* glyphs
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    glyphs == nullptr ||
    glyphs->length <= 0 ||
    glyphs->buffer == nullptr
  ) {
    return moonbit_skia_make_rect_array(
      0,
      reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
    );
  }
#if defined(SKIA_MBT_HAS_SKIA)
  std::vector<SkGlyphID> sk_glyphs(static_cast<size_t>(glyphs->length));
  for (int32_t i = 0; i < glyphs->length; ++i) {
    sk_glyphs[static_cast<size_t>(i)] = static_cast<SkGlyphID>(glyphs->buffer[i]);
  }

  std::vector<SkRect> sk_bounds(sk_glyphs.size());
  wrapper->font->getBounds(
    SkSpan<const SkGlyphID>(sk_glyphs.data(), sk_glyphs.size()),
    SkSpan<SkRect>(sk_bounds.data(), sk_bounds.size()),
    nullptr
  );

  MoonbitSkiaRect** buffer = reinterpret_cast<MoonbitSkiaRect**>(
    moonbit_make_ref_array_raw(glyphs->length)
  );
  for (size_t i = 0; i < sk_bounds.size(); ++i) {
    buffer[i] = moonbit_skia_make_rect(
      sk_bounds[i].left(),
      sk_bounds[i].top(),
      sk_bounds[i].right(),
      sk_bounds[i].bottom()
    );
  }
  return moonbit_skia_make_rect_array(glyphs->length, buffer);
#else
  return moonbit_skia_make_rect_array(
    0,
    reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
  );
#endif
}

#if defined(SKIA_MBT_HAS_SKIA)
static int32_t moonbit_skia_font_measure_text_bounds_utf8_rect(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text,
  SkRect* bounds
) {
  if (
    wrapper == nullptr ||
    wrapper->font == nullptr ||
    text == nullptr ||
    bounds == nullptr ||
    Moonbit_array_length(text) <= 0
  ) {
    return 0;
  }
  wrapper->font->measureText(
    text,
    static_cast<size_t>(Moonbit_array_length(text)),
    SkTextEncoding::kUTF8,
    bounds
  );
  return 1;
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_measure_text_bounds_utf8(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  return moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds);
#else
  (void)wrapper;
  (void)text;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_bounds_utf8_left(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  if (!moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds)) {
    return 0.0f;
  }
  return bounds.left();
#else
  (void)wrapper;
  (void)text;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_bounds_utf8_top(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  if (!moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds)) {
    return 0.0f;
  }
  return bounds.top();
#else
  (void)wrapper;
  (void)text;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_bounds_utf8_right(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  if (!moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds)) {
    return 0.0f;
  }
  return bounds.right();
#else
  (void)wrapper;
  (void)text;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_measure_text_bounds_utf8_bottom(
  MoonbitSkiaFont* wrapper,
  moonbit_bytes_t text
) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  if (!moonbit_skia_font_measure_text_bounds_utf8_rect(wrapper, text, &bounds)) {
    return 0.0f;
  }
  return bounds.bottom();
#else
  (void)wrapper;
  (void)text;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_font_metrics_value(MoonbitSkiaFont* wrapper, int32_t metric) {
  if (wrapper == nullptr || wrapper->font == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkFontMetrics metrics = moonbit_skia_get_font_metrics(wrapper);
  switch (metric) {
    case 0: return metrics.fTop;
    case 1: return metrics.fAscent;
    case 2: return metrics.fDescent;
    case 3: return metrics.fBottom;
    case 4: return metrics.fLeading;
    case 5: return metrics.fAvgCharWidth;
    case 6: return metrics.fMaxCharWidth;
    case 7: return metrics.fXMin;
    case 8: return metrics.fXMax;
    case 9: return metrics.fXHeight;
    case 10: return metrics.fCapHeight;
    case 11: return metrics.fUnderlineThickness;
    case 12: return metrics.fUnderlinePosition;
    case 13: return metrics.fStrikeoutThickness;
    case 14: return metrics.fStrikeoutPosition;
    default: return 0.0f;
  }
#else
  (void)metric;
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_metrics_has(MoonbitSkiaFont* wrapper, int32_t metric) {
  if (wrapper == nullptr || wrapper->font == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkFontMetrics metrics = moonbit_skia_get_font_metrics(wrapper);
  SkScalar value = 0;
  switch (metric) {
    case 0:
    case 1:
    case 2:
    case 3:
    case 4:
    case 5:
    case 6:
    case 7:
    case 8:
    case 9:
    case 10:
      return 1;
    case 11: return metrics.hasUnderlineThickness(&value);
    case 12: return metrics.hasUnderlinePosition(&value);
    case 13: return metrics.hasStrikeoutThickness(&value);
    case 14: return metrics.hasStrikeoutPosition(&value);
    case 15: return metrics.hasBounds();
    default: return 0;
  }
#else
  (void)metric;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_typeface_is_null(MoonbitSkiaTypeface* wrapper) {
  return wrapper == nullptr || wrapper->typeface == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_mgr_is_null(MoonbitSkiaFontMgr* wrapper) {
  return wrapper == nullptr || wrapper->font_mgr == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaFontMgr*
moonbit_skia_font_mgr_default(void) {
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkFontMgr> font_mgr = moonbit_skia_default_font_mgr();
  if (!font_mgr) {
    return moonbit_skia_make_font_mgr_wrapper(nullptr);
  }
  return moonbit_skia_make_font_mgr_wrapper(font_mgr.release());
#else
  return moonbit_skia_make_font_mgr_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_font_mgr_count_families(MoonbitSkiaFontMgr* wrapper) {
  if (wrapper == nullptr || wrapper->font_mgr == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  int count = wrapper->font_mgr->countFamilies();
  return count < 0 ? 0 : count;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT moonbit_bytes_t
moonbit_skia_font_mgr_family_name(MoonbitSkiaFontMgr* wrapper, int32_t index) {
  if (wrapper == nullptr || wrapper->font_mgr == nullptr || index < 0) {
    return moonbit_make_bytes(0, 0);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  int count = wrapper->font_mgr->countFamilies();
  if (index >= count) {
    return moonbit_make_bytes(0, 0);
  }
  SkString family_name;
  wrapper->font_mgr->getFamilyName(index, &family_name);
  return moonbit_skia_make_bytes_from_sk_string(family_name);
#else
  (void)index;
  return moonbit_make_bytes(0, 0);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_font_mgr_match_family_style(
  MoonbitSkiaFontMgr* wrapper,
  moonbit_bytes_t family_name,
  int32_t weight,
  int32_t width,
  int32_t slant
) {
  if (wrapper == nullptr || wrapper->font_mgr == nullptr) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  const char* family = nullptr;
  if (family_name != nullptr && Moonbit_array_length(family_name) > 0) {
    family = reinterpret_cast<const char*>(family_name);
  }
  sk_sp<SkTypeface> typeface = wrapper->font_mgr->matchFamilyStyle(
    family,
    moonbit_skia_font_style(weight, width, slant)
  );
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  (void)family_name;
  (void)weight;
  (void)width;
  (void)slant;
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_default(void) {
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkTypeface> typeface = moonbit_skia_default_typeface();
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  return moonbit_skia_make_typeface_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaTypeface*
moonbit_skia_typeface_from_name(
  moonbit_bytes_t family_name,
  int32_t weight,
  int32_t width,
  int32_t slant
) {
  if (family_name == nullptr || Moonbit_array_length(family_name) <= 0) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  sk_sp<SkTypeface> typeface = moonbit_skia_typeface_from_family(
    reinterpret_cast<const char*>(family_name),
    moonbit_skia_font_style(weight, width, slant)
  );
  if (!typeface) {
    return moonbit_skia_make_typeface_wrapper(nullptr);
  }
  return moonbit_skia_make_typeface_wrapper(typeface.release());
#else
  (void)weight;
  (void)width;
  (void)slant;
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

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaColorFilter*
moonbit_skia_color_filter_null(void) {
  return moonbit_skia_make_color_filter_wrapper(nullptr);
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_color_filter_is_null(MoonbitSkiaColorFilter* wrapper) {
  return wrapper == nullptr || wrapper->color_filter == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaColorFilter*
moonbit_skia_color_filter_matrix(MoonbitSkiaFloatArray* values) {
  if (values == nullptr || values->buffer == nullptr || values->length != 20) {
    return moonbit_skia_make_color_filter_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA) && \
  (defined(SKIA_MBT_HAS_LEGACY_COLOR_FILTER) || defined(SKIA_MBT_HAS_CORE_COLOR_FILTER))
  sk_sp<SkColorFilter> filter = SkColorFilters::Matrix(values->buffer);
  if (!filter) {
    return moonbit_skia_make_color_filter_wrapper(nullptr);
  }
  return moonbit_skia_make_color_filter_wrapper(filter.release());
#else
  return moonbit_skia_make_color_filter_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaImageFilter*
moonbit_skia_image_filter_null(void) {
  return moonbit_skia_make_image_filter_wrapper(nullptr);
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_image_filter_is_null(MoonbitSkiaImageFilter* wrapper) {
  return wrapper == nullptr || wrapper->image_filter == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaImageFilter*
moonbit_skia_image_filter_blur(float sigma_x, float sigma_y) {
  if (!(sigma_x > 0.0f) || !(sigma_y > 0.0f)) {
    return moonbit_skia_make_image_filter_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_IMAGE_FILTERS)
  sk_sp<SkImageFilter> filter = SkImageFilters::Blur(sigma_x, sigma_y, nullptr);
  if (!filter) {
    return moonbit_skia_make_image_filter_wrapper(nullptr);
  }
  return moonbit_skia_make_image_filter_wrapper(filter.release());
#else
  (void)sigma_x;
  (void)sigma_y;
  return moonbit_skia_make_image_filter_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaMaskFilter*
moonbit_skia_mask_filter_null(void) {
  return moonbit_skia_make_mask_filter_wrapper(nullptr);
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_mask_filter_is_null(MoonbitSkiaMaskFilter* wrapper) {
  return wrapper == nullptr || wrapper->mask_filter == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaMaskFilter*
moonbit_skia_mask_filter_blur(float sigma) {
  if (!(sigma > 0.0f)) {
    return moonbit_skia_make_mask_filter_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA) && defined(SKIA_MBT_HAS_MASK_FILTER) && \
  defined(SKIA_MBT_HAS_BLUR_TYPES)
  sk_sp<SkMaskFilter> filter = SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, sigma);
  if (!filter) {
    return moonbit_skia_make_mask_filter_wrapper(nullptr);
  }
  return moonbit_skia_make_mask_filter_wrapper(filter.release());
#else
  (void)sigma;
  return moonbit_skia_make_mask_filter_wrapper(nullptr);
#endif
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
#if defined(SKIA_MBT_HAS_NEW_GRADIENT_SHADER)
  SkColor4f color4fs[2] = {
    SkColor4f::FromColor(colors[0]),
    SkColor4f::FromColor(colors[1])
  };
  SkGradient gradient(
    SkGradient::Colors(
      SkSpan<const SkColor4f>(color4fs, 2),
      static_cast<SkTileMode>(tile_mode)
    ),
    SkGradient::Interpolation()
  );
  sk_sp<SkShader> shader = SkShaders::LinearGradient(points, gradient);
#else
  sk_sp<SkShader> shader = SkGradientShader::MakeLinear(
    points,
    colors,
    nullptr,
    2,
    static_cast<SkTileMode>(tile_mode)
  );
#endif
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
#if defined(SKIA_MBT_HAS_NEW_GRADIENT_SHADER)
  SkColor4f color4fs[2] = {
    SkColor4f::FromColor(colors[0]),
    SkColor4f::FromColor(colors[1])
  };
  SkGradient gradient(
    SkGradient::Colors(
      SkSpan<const SkColor4f>(color4fs, 2),
      static_cast<SkTileMode>(tile_mode)
    ),
    SkGradient::Interpolation()
  );
  sk_sp<SkShader> shader = SkShaders::RadialGradient(
    SkPoint::Make(center_x, center_y),
    radius,
    gradient
  );
#else
  sk_sp<SkShader> shader = SkGradientShader::MakeRadial(
    SkPoint::Make(center_x, center_y),
    radius,
    colors,
    nullptr,
    2,
    static_cast<SkTileMode>(tile_mode)
  );
#endif
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
  if (!bitmap->tryAllocPixels(
    moonbit_skia_make_rgba8888_premul_info(width, height)
  )) {
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
  SkImageInfo info = moonbit_skia_make_rgba8888_premul_info(width, height);
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
  sk_sp<SkData> data;
  switch (static_cast<SkEncodedImageFormat>(format)) {
  case SkEncodedImageFormat::kPNG: {
    SkPngEncoder::Options options;
    data = SkPngEncoder::Encode(nullptr, wrapper->image, options);
    break;
  }
  case SkEncodedImageFormat::kJPEG: {
    SkJpegEncoder::Options options;
    if (quality < 0) {
      quality = 0;
    } else if (quality > 100) {
      quality = 100;
    }
    options.fQuality = quality;
    data = SkJpegEncoder::Encode(nullptr, wrapper->image, options);
    break;
  }
  case SkEncodedImageFormat::kWEBP: {
    SkWebpEncoder::Options options;
    if (quality < 0) {
      quality = 0;
    } else if (quality > 100) {
      quality = 100;
    }
    options.fQuality = static_cast<float>(quality);
    data = SkWebpEncoder::Encode(nullptr, wrapper->image, options);
    break;
  }
  default:
    data = nullptr;
    break;
  }
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
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  *wrapper->path = SkPath();
#else
  wrapper->path->reset();
#endif
#endif
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_path_rewind(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  *wrapper->path = SkPath();
#else
  wrapper->path->rewind();
#endif
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_set_fill_type(
  MoonbitSkiaPath* wrapper,
  int32_t fill_type
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  *wrapper->path = wrapper->path->makeFillType(
    static_cast<SkPathFillType>(fill_type)
  );
#else
  wrapper->path->setFillType(static_cast<SkPathFillType>(fill_type));
#endif
#else
  (void)fill_type;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_fill_type(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return static_cast<int32_t>(wrapper->path->getFillType());
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_inverse_fill_type(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->isInverseFillType();
#else
  return 0;
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
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.moveTo(x, y);
  });
#else
  wrapper->path->moveTo(x, y);
#endif
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
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.lineTo(x, y);
  });
#else
  wrapper->path->lineTo(x, y);
#endif
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
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.quadTo(x1, y1, x2, y2);
  });
#else
  wrapper->path->quadTo(x1, y1, x2, y2);
#endif
#else
  (void)x1;
  (void)y1;
  (void)x2;
  (void)y2;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_conic_to(
  MoonbitSkiaPath* wrapper,
  float x1,
  float y1,
  float x2,
  float y2,
  float weight
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.conicTo(x1, y1, x2, y2, weight);
  });
#else
  wrapper->path->conicTo(x1, y1, x2, y2, weight);
#endif
#else
  (void)x1;
  (void)y1;
  (void)x2;
  (void)y2;
  (void)weight;
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
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.cubicTo(x1, y1, x2, y2, x3, y3);
  });
#else
  wrapper->path->cubicTo(x1, y1, x2, y2, x3, y3);
#endif
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
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [](SkPathBuilder& builder) {
    builder.close();
  });
#else
  wrapper->path->close();
#endif
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_rect(
  MoonbitSkiaPath* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addRect(
      SkRect::MakeLTRB(left, top, right, bottom),
      static_cast<SkPathDirection>(direction)
    );
  });
#else
  wrapper->path->addRect(
    SkRect::MakeLTRB(left, top, right, bottom),
    static_cast<SkPathDirection>(direction)
  );
#endif
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_oval(
  MoonbitSkiaPath* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addOval(
      SkRect::MakeLTRB(left, top, right, bottom),
      static_cast<SkPathDirection>(direction)
    );
  });
#else
  wrapper->path->addOval(
    SkRect::MakeLTRB(left, top, right, bottom),
    static_cast<SkPathDirection>(direction)
  );
#endif
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_circle(
  MoonbitSkiaPath* wrapper,
  float x,
  float y,
  float radius,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addCircle(
      x,
      y,
      radius,
      static_cast<SkPathDirection>(direction)
    );
  });
#else
  wrapper->path->addCircle(
    x,
    y,
    radius,
    static_cast<SkPathDirection>(direction)
  );
#endif
#else
  (void)x;
  (void)y;
  (void)radius;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_round_rect(
  MoonbitSkiaPath* wrapper,
  float left,
  float top,
  float right,
  float bottom,
  float rx,
  float ry,
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  SkRRect rrect = SkRRect::MakeRectXY(
    SkRect::MakeLTRB(left, top, right, bottom),
    rx,
    ry
  );
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addRRect(rrect, static_cast<SkPathDirection>(direction));
  });
#else
  wrapper->path->addRoundRect(
    SkRect::MakeLTRB(left, top, right, bottom),
    rx,
    ry,
    static_cast<SkPathDirection>(direction)
  );
#endif
#else
  (void)left;
  (void)top;
  (void)right;
  (void)bottom;
  (void)rx;
  (void)ry;
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_add_rrect(
  MoonbitSkiaPath* wrapper,
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
  int32_t direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  moonbit_skia_path_mutate(wrapper, [=](SkPathBuilder& builder) {
    builder.addRRect(rrect, static_cast<SkPathDirection>(direction));
  });
#else
  wrapper->path->addRRect(rrect, static_cast<SkPathDirection>(direction));
#endif
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
  (void)direction;
#endif
}

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_transform(
  MoonbitSkiaPath* wrapper,
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
  if (wrapper == nullptr || wrapper->path == nullptr) {
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
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  *wrapper->path = wrapper->path->makeTransform(matrix);
#else
  wrapper->path->transform(matrix);
#endif
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

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_path_offset(
  MoonbitSkiaPath* wrapper,
  float dx,
  float dy
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
#if defined(SKIA_MBT_HAS_PATH_BUILDER)
  *wrapper->path = wrapper->path->makeOffset(dx, dy);
#else
  wrapper->path->offset(dx, dy);
#endif
#else
  (void)dx;
  (void)dy;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_path_contains(
  MoonbitSkiaPath* wrapper,
  float x,
  float y
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->contains(x, y);
#else
  (void)x;
  (void)y;
  return 0;
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

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_finite(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 1;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->isFinite();
#else
  return 1;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_count_points(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->countPoints();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_count_verbs(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->countVerbs();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_segment_masks(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->getSegmentMasks();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_last_contour_closed(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->isLastContourClosed();
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_has_last_point(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint point;
  return wrapper->path->getLastPt(&point);
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_last_point_x(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint point;
  if (wrapper->path->getLastPt(&point)) {
    return point.x();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_last_point_y(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint point;
  if (wrapper->path->getLastPt(&point)) {
    return point.y();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_line(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint points[2];
  return wrapper->path->isLine(points);
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_line_start_x(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint points[2];
  if (wrapper->path->isLine(points)) {
    return points[0].x();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_line_start_y(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint points[2];
  if (wrapper->path->isLine(points)) {
    return points[0].y();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_line_end_x(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint points[2];
  if (wrapper->path->isLine(points)) {
    return points[1].x();
  }
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_line_end_y(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkPoint points[2];
  if (wrapper->path->isLine(points)) {
    return points[1].y();
  }
#endif
  return 0.0f;
}

#if defined(SKIA_MBT_HAS_SKIA)
static int moonbit_skia_path_get_rect(
  MoonbitSkiaPath* wrapper,
  SkRect* rect,
  bool* is_closed,
  SkPathDirection* direction
) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
  return wrapper->path->isRect(rect, is_closed, direction);
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_rect(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  return moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction);
#else
  (void)wrapper;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_rect_left(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return rect.left();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_rect_top(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return rect.top();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_rect_right(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return rect.right();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_rect_bottom(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return rect.bottom();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_rect_is_closed(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return is_closed;
  }
#else
  (void)wrapper;
#endif
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_rect_direction(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect rect;
  bool is_closed = false;
  SkPathDirection direction = SkPathDirection::kCW;
  if (moonbit_skia_path_get_rect(wrapper, &rect, &is_closed, &direction)) {
    return static_cast<int32_t>(direction);
  }
#else
  (void)wrapper;
#endif
  return 0;
}

#if defined(SKIA_MBT_HAS_SKIA)
static int moonbit_skia_path_get_oval(MoonbitSkiaPath* wrapper, SkRect* bounds) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0;
  }
  return wrapper->path->isOval(bounds);
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_path_is_oval(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  return moonbit_skia_path_get_oval(wrapper, &bounds);
#else
  (void)wrapper;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_oval_left(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  if (moonbit_skia_path_get_oval(wrapper, &bounds)) {
    return bounds.left();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_oval_top(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  if (moonbit_skia_path_get_oval(wrapper, &bounds)) {
    return bounds.top();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_oval_right(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  if (moonbit_skia_path_get_oval(wrapper, &bounds)) {
    return bounds.right();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_oval_bottom(MoonbitSkiaPath* wrapper) {
#if defined(SKIA_MBT_HAS_SKIA)
  SkRect bounds;
  if (moonbit_skia_path_get_oval(wrapper, &bounds)) {
    return bounds.bottom();
  }
#else
  (void)wrapper;
#endif
  return 0.0f;
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_bounds_left(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->getBounds().left();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_bounds_top(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->getBounds().top();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_bounds_right(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->getBounds().right();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_bounds_bottom(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->getBounds().bottom();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_tight_bounds_left(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->computeTightBounds().left();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_tight_bounds_top(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->computeTightBounds().top();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_tight_bounds_right(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->computeTightBounds().right();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT float
moonbit_skia_path_tight_bounds_bottom(MoonbitSkiaPath* wrapper) {
  if (wrapper == nullptr || wrapper->path == nullptr) {
    return 0.0f;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return wrapper->path->computeTightBounds().bottom();
#else
  return 0.0f;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_raster_n32_premul(int32_t width, int32_t height) {
  if (width <= 0 || height <= 0) {
    return moonbit_skia_make_surface_wrapper(nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  SkImageInfo info = moonbit_skia_make_rgba8888_premul_info(width, height);
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
  SkImageInfo info = moonbit_skia_make_rgba8888_premul_info(width, height);
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

extern "C" MOONBIT_FFI_EXPORT void moonbit_skia_canvas_draw_glyphs(
  MoonbitSkiaCanvas* wrapper,
  MoonbitSkiaGlyphIdArray* glyphs,
  MoonbitSkiaPointArray* positions,
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
    glyphs == nullptr ||
    glyphs->length <= 0 ||
    glyphs->buffer == nullptr ||
    positions == nullptr ||
    positions->buffer == nullptr ||
    glyphs->length != positions->length ||
    font == nullptr ||
    font->font == nullptr
  ) {
    return;
  }
#if defined(SKIA_MBT_HAS_SKIA)
  std::vector<SkGlyphID> sk_glyphs(static_cast<size_t>(glyphs->length));
  std::vector<SkPoint> sk_positions(static_cast<size_t>(positions->length));
  for (int32_t i = 0; i < glyphs->length; ++i) {
    MoonbitSkiaPoint* point = positions->buffer[i];
    if (point == nullptr) {
      return;
    }
    sk_glyphs[static_cast<size_t>(i)] = static_cast<SkGlyphID>(glyphs->buffer[i]);
    sk_positions[static_cast<size_t>(i)] = SkPoint::Make(point->x, point->y);
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
    return moonbit_skia_make_canvas_wrapper(nullptr, nullptr);
  }
#if defined(SKIA_MBT_HAS_SKIA)
  return moonbit_skia_make_canvas_wrapper(
    wrapper->surface->getCanvas(),
    wrapper->surface
  );
#else
  return moonbit_skia_make_canvas_wrapper(nullptr, nullptr);
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
#if defined(SKIA_MBT_HAS_SKIA)
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

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_local_clip_bounds(MoonbitSkiaCanvas* wrapper) {
  if (wrapper == nullptr || wrapper->canvas == nullptr) {
    return 0;
  }
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
#if defined(SKIA_MBT_HAS_SKIA)
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
