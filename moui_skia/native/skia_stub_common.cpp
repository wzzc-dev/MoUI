#include "skia_stub_common.h"

#include <cmath>

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

MoonbitSkiaFloatArray* moonbit_skia_make_float_array(
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
  array->length = std::max(0, length);
  array->buffer = buffer == nullptr ? moonbit_empty_float_array : buffer;
  return array;
}

MoonbitSkiaGlyphIdArray* moonbit_skia_make_glyph_id_array(
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
  array->length = std::max(0, length);
  array->buffer = buffer == nullptr ? moonbit_empty_int16_array : buffer;
  return array;
}

uint16_t* moonbit_skia_make_glyph_id_array_storage(
  int32_t length
) {
  if (length <= 0) {
    return moonbit_empty_int16_array;
  }
  return moonbit_make_string_raw(length);
}

MoonbitSkiaPoint* moonbit_skia_make_point(float x, float y) {
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

MoonbitSkiaRect* moonbit_skia_make_rect(
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

MoonbitSkiaPointArray* moonbit_skia_make_point_array(
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
  array->length = std::max(0, length);
  array->buffer = buffer == nullptr
    ? reinterpret_cast<MoonbitSkiaPoint**>(moonbit_empty_ref_array)
    : buffer;
  return array;
}

MoonbitSkiaPoint** moonbit_skia_make_point_array_storage(
  int32_t length
) {
  if (length <= 0) {
    return reinterpret_cast<MoonbitSkiaPoint**>(moonbit_empty_ref_array);
  }
  return reinterpret_cast<MoonbitSkiaPoint**>(moonbit_make_ref_array_raw(length));
}

MoonbitSkiaRectArray* moonbit_skia_make_rect_array(
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
  array->length = std::max(0, length);
  array->buffer = buffer == nullptr
    ? reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array)
    : buffer;
  return array;
}

MoonbitSkiaRect** moonbit_skia_make_rect_array_storage(
  int32_t length
) {
  if (length <= 0) {
    return reinterpret_cast<MoonbitSkiaRect**>(moonbit_empty_ref_array);
  }
  return reinterpret_cast<MoonbitSkiaRect**>(moonbit_make_ref_array_raw(length));
}

MoonbitSkiaInt32Array* moonbit_skia_make_int32_array(
  int32_t length,
  int32_t* buffer
) {
  MoonbitSkiaInt32Array* array = static_cast<MoonbitSkiaInt32Array*>(
    moonbit_malloc(sizeof(MoonbitSkiaInt32Array))
  );
  Moonbit_object_header(array)->meta = moonbit_skia_regular_object_header(
    static_cast<uint32_t>(offsetof(MoonbitSkiaInt32Array, buffer) >> 2),
    1,
    0
  );
  array->length = std::max(0, length);
  array->buffer = buffer == nullptr ? moonbit_empty_int32_array : buffer;
  return array;
}

MoonbitSkiaShapedTextRun* moonbit_skia_make_shaped_text_run(
  int32_t glyph_count,
  float advance_x,
  float advance_y,
  MoonbitSkiaGlyphIdArray* glyphs,
  MoonbitSkiaPointArray* positions,
  MoonbitSkiaInt32Array* clusters
) {
  MoonbitSkiaShapedTextRun* run = static_cast<MoonbitSkiaShapedTextRun*>(
    moonbit_malloc(sizeof(MoonbitSkiaShapedTextRun))
  );
  Moonbit_object_header(run)->meta = moonbit_skia_regular_object_header(
    static_cast<uint32_t>(offsetof(MoonbitSkiaShapedTextRun, glyphs) >> 2),
    3,
    0
  );
  run->glyph_count = glyph_count;
  run->advance_x = advance_x;
  run->advance_y = advance_y;
  run->glyphs = glyphs;
  run->positions = positions;
  run->clusters = clusters;
  return run;
}

MoonbitSkiaShapedTextRun* moonbit_skia_make_empty_shaped_text_run() {
  return moonbit_skia_make_shaped_text_run(
    0,
    0.0f,
    0.0f,
    moonbit_skia_make_glyph_id_array(0, moonbit_empty_int16_array),
    moonbit_skia_make_point_array(
      0,
      reinterpret_cast<MoonbitSkiaPoint**>(moonbit_empty_ref_array)
    ),
    moonbit_skia_make_int32_array(0, moonbit_empty_int32_array)
  );
}

#if defined(MOUI_SKIA_HAS_SKIA)
moonbit_bytes_t moonbit_skia_make_bytes_from_sk_string(
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

std::string moonbit_skia_bytes_to_string(moonbit_bytes_t value) {
  if (value == nullptr) {
    return std::string();
  }
  int32_t length = Moonbit_array_length(value);
  if (length <= 0) {
    return std::string();
  }
  return std::string(
    reinterpret_cast<const char*>(value),
    static_cast<size_t>(length)
  );
}
#endif

static void moonbit_skia_path_finalize(void* ptr) {
  MoonbitSkiaPath* wrapper = static_cast<MoonbitSkiaPath*>(ptr);
#if defined(MOUI_SKIA_HAS_SKIA)
  delete wrapper->path;
  wrapper->path = nullptr;
#else
  wrapper->path = nullptr;
#endif
}

static void moonbit_skia_font_finalize(void* ptr) {
  MoonbitSkiaFont* wrapper = static_cast<MoonbitSkiaFont*>(ptr);
#if defined(MOUI_SKIA_HAS_SKIA)
  delete wrapper->font;
  wrapper->font = nullptr;
#else
  wrapper->font = nullptr;
#endif
}

static void moonbit_skia_typeface_finalize(void* ptr) {
  MoonbitSkiaTypeface* wrapper = static_cast<MoonbitSkiaTypeface*>(ptr);
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
  if (wrapper->font_mgr != nullptr) {
    wrapper->font_mgr->unref();
    wrapper->font_mgr = nullptr;
  }
#else
  wrapper->font_mgr = nullptr;
#endif
}

static void moonbit_skia_paragraph_finalize(void* ptr) {
  MoonbitSkiaParagraph* wrapper = static_cast<MoonbitSkiaParagraph*>(ptr);
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  delete wrapper->paragraph;
  wrapper->paragraph = nullptr;
#else
  wrapper->paragraph = nullptr;
#endif
}

static void moonbit_skia_shader_finalize(void* ptr) {
  MoonbitSkiaShader* wrapper = static_cast<MoonbitSkiaShader*>(ptr);
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA) && \
  (defined(MOUI_SKIA_HAS_LEGACY_COLOR_FILTER) || defined(MOUI_SKIA_HAS_CORE_COLOR_FILTER))
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
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_IMAGE_FILTERS)
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
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_MASK_FILTER)
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
#if defined(MOUI_SKIA_HAS_SKIA)
  delete wrapper->bitmap;
  wrapper->bitmap = nullptr;
#else
  wrapper->bitmap = nullptr;
#endif
}

static void moonbit_skia_data_finalize(void* ptr) {
  MoonbitSkiaData* wrapper = static_cast<MoonbitSkiaData*>(ptr);
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
  delete wrapper->codec;
  wrapper->codec = nullptr;
#else
  wrapper->codec = nullptr;
#endif
}

static void moonbit_skia_image_finalize(void* ptr) {
  MoonbitSkiaImage* wrapper = static_cast<MoonbitSkiaImage*>(ptr);
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
  if (wrapper->surface != nullptr) {
    wrapper->surface->unref();
    wrapper->surface = nullptr;
  }
#else
  wrapper->surface = nullptr;
#endif
#if defined(MOUI_SKIA_HAS_GANESH_DIRECT_CONTEXT)
  if (wrapper->gpu_context_owner != nullptr) {
    wrapper->gpu_context_owner->unref();
    wrapper->gpu_context_owner = nullptr;
  }
#else
  wrapper->gpu_context_owner = nullptr;
#endif
  if (wrapper->host_present_handle != nullptr) {
    moonbit_skia_objc_release(wrapper->host_present_handle);
    moonbit_skia_com_release(wrapper->host_present_handle);
    moonbit_skia_vulkan_release_swapchain(wrapper->host_present_handle);
    moonbit_skia_egl_release_window(wrapper->host_present_handle);
    wrapper->host_present_handle = nullptr;
  }
}

static void moonbit_skia_gpu_context_finalize(void* ptr) {
  MoonbitSkiaGpuContext* wrapper = static_cast<MoonbitSkiaGpuContext*>(ptr);
#if defined(MOUI_SKIA_HAS_GANESH_DIRECT_CONTEXT)
  if (wrapper->context != nullptr) {
    wrapper->context->unref();
    wrapper->context = nullptr;
  }
#else
  wrapper->context = nullptr;
#endif
  if (wrapper->device != nullptr) {
    moonbit_skia_com_release(wrapper->device);
    moonbit_skia_vulkan_release_context(wrapper->device);
    moonbit_skia_egl_release_context(wrapper->device);
    wrapper->device = nullptr;
  }
  if (wrapper->queue != nullptr) {
    moonbit_skia_com_release(wrapper->queue);
    wrapper->queue = nullptr;
  }
  wrapper->backend = 0;
}

static void moonbit_skia_canvas_finalize(void* ptr) {
  MoonbitSkiaCanvas* wrapper = static_cast<MoonbitSkiaCanvas*>(ptr);
#if defined(MOUI_SKIA_HAS_SKIA)
  if (wrapper->surface_owner != nullptr) {
    wrapper->surface_owner->unref();
    wrapper->surface_owner = nullptr;
  }
#else
  wrapper->surface_owner = nullptr;
#endif
  wrapper->canvas = nullptr;
}

MoonbitSkiaFont* moonbit_skia_make_font_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

MoonbitSkiaTypeface* moonbit_skia_make_typeface_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

MoonbitSkiaFontMgr* moonbit_skia_make_font_mgr_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

MoonbitSkiaParagraph* moonbit_skia_make_paragraph_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  skia::textlayout::Paragraph* paragraph
#else
  void* paragraph
#endif
) {
  MoonbitSkiaParagraph* wrapper = static_cast<MoonbitSkiaParagraph*>(
    moonbit_make_external_object(
      moonbit_skia_paragraph_finalize,
      sizeof(MoonbitSkiaParagraph)
    )
  );
  wrapper->paragraph = paragraph;
  return wrapper;
}

MoonbitSkiaShader* moonbit_skia_make_shader_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

MoonbitSkiaColorFilter* moonbit_skia_make_color_filter_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && \
  (defined(MOUI_SKIA_HAS_LEGACY_COLOR_FILTER) || defined(MOUI_SKIA_HAS_CORE_COLOR_FILTER))
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

MoonbitSkiaImageFilter* moonbit_skia_make_image_filter_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_IMAGE_FILTERS)
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

MoonbitSkiaMaskFilter* moonbit_skia_make_mask_filter_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_MASK_FILTER)
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

MoonbitSkiaCodec* moonbit_skia_make_codec_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

MoonbitSkiaBitmap* moonbit_skia_make_bitmap_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

MoonbitSkiaPath* moonbit_skia_make_path_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

MoonbitSkiaData* moonbit_skia_make_data_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

#if defined(MOUI_SKIA_HAS_SKIA)
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

#if defined(__linux__) && \
  (defined(MOUI_SKIA_HAS_FONTCONFIG_FONTMGR) || defined(MOUI_SKIA_HAS_DIRECTORY_FONTMGR))
static bool moonbit_skia_typeface_can_draw_character(
  const sk_sp<SkTypeface>& typeface,
  SkUnichar character
) {
  return typeface && typeface->unicharToGlyph(character) != 0;
}

static bool moonbit_skia_typeface_can_draw_characters(
  const sk_sp<SkTypeface>& typeface,
  const SkUnichar* characters,
  size_t character_count
) {
  if (!typeface) {
    return false;
  }
  for (size_t index = 0; index < character_count; ++index) {
    SkUnichar character = characters[index];
    if (character != 0 && typeface->unicharToGlyph(character) == 0) {
      return false;
    }
  }
  return true;
}

static SkFontMgr* moonbit_skia_linux_font_mgr(void);

static SkFontMgr* moonbit_skia_linux_file_font_mgr(void) {
#if defined(MOUI_SKIA_HAS_EMPTY_FONTMGR)
  static sk_sp<SkFontMgr> font_mgr = SkFontMgr_New_Custom_Empty();
  return font_mgr.get();
#else
  return moonbit_skia_linux_font_mgr();
#endif
}

#if defined(MOUI_SKIA_HAS_FONTCONFIG_FONTMGR)
static int moonbit_skia_fontconfig_weight(const SkFontStyle& style) {
  int weight = style.weight();
  if (weight < 150) return FC_WEIGHT_THIN;
  if (weight < 250) return FC_WEIGHT_EXTRALIGHT;
  if (weight < 350) return FC_WEIGHT_LIGHT;
  if (weight < 450) return FC_WEIGHT_REGULAR;
  if (weight < 550) return FC_WEIGHT_MEDIUM;
  if (weight < 650) return FC_WEIGHT_DEMIBOLD;
  if (weight < 750) return FC_WEIGHT_BOLD;
  if (weight < 850) return FC_WEIGHT_EXTRABOLD;
  return FC_WEIGHT_BLACK;
}
#endif

static bool moonbit_skia_font_mgr_has_families(
  const sk_sp<SkFontMgr>& font_mgr
) {
  return font_mgr && font_mgr->countFamilies() > 0;
}

#if defined(__ANDROID__)
static SkFontMgr* moonbit_skia_android_font_mgr(void) {
  static sk_sp<SkFontMgr> font_mgr = []() -> sk_sp<SkFontMgr> {
#if defined(MOUI_SKIA_HAS_ANDROID_NDK_FONTMGR)
    sk_sp<SkFontMgr> ndk_mgr = SkFontMgr_New_AndroidNDK(
      true,
      SkFontScanner_Make_FreeType()
    );
    if (moonbit_skia_font_mgr_has_families(ndk_mgr)) {
      return ndk_mgr;
    }
#endif
#if defined(MOUI_SKIA_HAS_ANDROID_FONTMGR)
    sk_sp<SkFontMgr> legacy_mgr = SkFontMgr_New_Android(
      nullptr,
      SkFontScanner_Make_FreeType()
    );
    if (moonbit_skia_font_mgr_has_families(legacy_mgr)) {
      return legacy_mgr;
    }
#endif
    return SkFontMgr::RefEmpty();
  }();
  return font_mgr.get();
}

static sk_sp<SkTypeface> moonbit_skia_android_typeface_from_family(
  const char* family_name,
  const SkFontStyle& style
) {
  SkFontMgr* font_mgr = moonbit_skia_android_font_mgr();
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

  const char* en_bcp47[] = {"en"};
  return font_mgr->matchFamilyStyleCharacter(
    has_family_name ? family_name : nullptr,
    style,
    en_bcp47,
    1,
    'S'
  );
}

static sk_sp<SkTypeface> moonbit_skia_android_typeface_for_characters(
  const char* family_name,
  const SkFontStyle& style,
  const SkUnichar* characters,
  size_t character_count
) {
  SkFontMgr* font_mgr = moonbit_skia_android_font_mgr();
  if (font_mgr == nullptr || characters == nullptr || character_count == 0) {
    return nullptr;
  }

  const bool has_family_name = family_name != nullptr && family_name[0] != '\0';
  const char* en_bcp47[] = {"en"};
  sk_sp<SkTypeface> typeface = font_mgr->matchFamilyStyleCharacter(
    has_family_name ? family_name : nullptr,
    style,
    en_bcp47,
    1,
    characters[0]
  );
  if (moonbit_skia_typeface_can_draw_characters(typeface, characters, character_count)) {
    return typeface;
  }
  return nullptr;
}
#endif

static sk_sp<SkFontMgr> moonbit_skia_linux_fontconfig_font_mgr(void) {
#if defined(MOUI_SKIA_HAS_FONTCONFIG_FONTMGR)
  sk_sp<SkFontMgr> font_mgr = SkFontMgr_New_FontConfig(
    FcInitLoadConfigAndFonts(),
    SkFontScanner_Make_FreeType()
  );
  if (moonbit_skia_font_mgr_has_families(font_mgr)) {
    return font_mgr;
  }
#endif
  return nullptr;
}

#if defined(MOUI_SKIA_HAS_DIRECTORY_FONTMGR) && defined(MOUI_SKIA_HAS_ORDERED_FONTMGR)
static void moonbit_skia_linux_append_font_dir(
  SkOrderedFontMgr* ordered,
  const char* dir
) {
  if (ordered == nullptr || dir == nullptr || dir[0] == '\0') {
    return;
  }
  sk_sp<SkFontMgr> font_mgr = SkFontMgr_New_Custom_Directory(dir);
  if (moonbit_skia_font_mgr_has_families(font_mgr)) {
    ordered->append(font_mgr);
  }
}
#endif

static sk_sp<SkFontMgr> moonbit_skia_linux_directory_font_mgr(void) {
#if defined(MOUI_SKIA_HAS_DIRECTORY_FONTMGR) && defined(MOUI_SKIA_HAS_ORDERED_FONTMGR)
  sk_sp<SkOrderedFontMgr> ordered = sk_make_sp<SkOrderedFontMgr>();
#if defined(__OHOS__)
  moonbit_skia_linux_append_font_dir(ordered.get(), "/system/fonts");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/system/font");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/product/fonts");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/vendor/fonts");
#endif
  moonbit_skia_linux_append_font_dir(ordered.get(), "/usr/share/fonts/truetype/dejavu");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/usr/share/fonts/truetype/droid");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/usr/share/fonts/truetype/noto");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/usr/share/fonts/opentype");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/usr/share/fonts/truetype");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/usr/share/fonts");
  moonbit_skia_linux_append_font_dir(ordered.get(), "/usr/local/share/fonts");
  if (ordered->countFamilies() > 0) {
    return ordered;
  }
#endif
  return nullptr;
}

static SkFontMgr* moonbit_skia_linux_font_mgr(void) {
  static sk_sp<SkFontMgr> font_mgr = []() -> sk_sp<SkFontMgr> {
    sk_sp<SkFontMgr> fontconfig_mgr = moonbit_skia_linux_fontconfig_font_mgr();
    if (fontconfig_mgr) {
      return fontconfig_mgr;
    }
    sk_sp<SkFontMgr> directory_mgr = moonbit_skia_linux_directory_font_mgr();
    if (directory_mgr) {
      return directory_mgr;
    }
    return SkFontMgr::RefEmpty();
  }();
  return font_mgr.get();
}

#if defined(MOUI_SKIA_HAS_FONTCONFIG_FONTMGR)
static int moonbit_skia_fontconfig_width(const SkFontStyle& style) {
  switch (style.width()) {
    case 1: return FC_WIDTH_ULTRACONDENSED;
    case 2: return FC_WIDTH_EXTRACONDENSED;
    case 3: return FC_WIDTH_CONDENSED;
    case 4: return FC_WIDTH_SEMICONDENSED;
    case 6: return FC_WIDTH_SEMIEXPANDED;
    case 7: return FC_WIDTH_EXPANDED;
    case 8: return FC_WIDTH_EXTRAEXPANDED;
    case 9: return FC_WIDTH_ULTRAEXPANDED;
    default: return FC_WIDTH_NORMAL;
  }
}
#endif

static sk_sp<SkTypeface> moonbit_skia_linux_typeface_from_fontconfig(
  const char* family_name,
  const SkFontStyle& style,
  const SkUnichar* characters,
  size_t character_count
) {
#if defined(MOUI_SKIA_HAS_FONTCONFIG_FONTMGR)
  FcConfig* config = FcInitLoadConfigAndFonts();
  if (config == nullptr) {
    return nullptr;
  }

  FcPattern* pattern = FcPatternCreate();
  if (pattern == nullptr) {
    FcConfigDestroy(config);
    return nullptr;
  }

  const bool has_family_name = family_name != nullptr && family_name[0] != '\0';
  if (has_family_name) {
    FcPatternAddString(
      pattern,
      FC_FAMILY,
      reinterpret_cast<const FcChar8*>(family_name)
    );
  }
  if (characters != nullptr && character_count > 0) {
    FcCharSet* charset = FcCharSetCreate();
    if (charset != nullptr) {
      for (size_t index = 0; index < character_count; ++index) {
        SkUnichar character = characters[index];
        if (character != 0) {
          FcCharSetAddChar(charset, static_cast<FcChar32>(character));
        }
      }
      FcPatternAddCharSet(pattern, FC_CHARSET, charset);
      FcCharSetDestroy(charset);
    }
  }
  FcPatternAddInteger(pattern, FC_WEIGHT, moonbit_skia_fontconfig_weight(style));
  FcPatternAddInteger(pattern, FC_WIDTH, moonbit_skia_fontconfig_width(style));
  if (style.slant() != SkFontStyle::kUpright_Slant) {
    FcPatternAddInteger(pattern, FC_SLANT, FC_SLANT_ITALIC);
  }
  FcConfigSubstitute(config, pattern, FcMatchPattern);
  FcDefaultSubstitute(pattern);

  FcResult result = FcResultNoMatch;
  FcPattern* matched = FcFontMatch(config, pattern, &result);
  FcPatternDestroy(pattern);
  if (matched == nullptr || result != FcResultMatch) {
    if (matched != nullptr) {
      FcPatternDestroy(matched);
    }
    FcConfigDestroy(config);
    return nullptr;
  }

  FcChar8* file = nullptr;
  int index = 0;
  if (FcPatternGetString(matched, FC_FILE, 0, &file) != FcResultMatch) {
    FcPatternDestroy(matched);
    FcConfigDestroy(config);
    return nullptr;
  }
  if (FcPatternGetInteger(matched, FC_INDEX, 0, &index) != FcResultMatch) {
    index = 0;
  }

  SkFontMgr* font_mgr = moonbit_skia_linux_file_font_mgr();
  sk_sp<SkTypeface> typeface;
  if (font_mgr != nullptr) {
    typeface = font_mgr->makeFromFile(
      reinterpret_cast<const char*>(file),
      index
    );
  }
  FcPatternDestroy(matched);
  FcConfigDestroy(config);
  if (
    characters == nullptr ||
    character_count == 0 ||
    moonbit_skia_typeface_can_draw_characters(
      typeface,
      characters,
      character_count
    )
  ) {
    return typeface;
  }
#else
  (void)family_name;
  (void)style;
  (void)characters;
  (void)character_count;
#endif
  return nullptr;
}

static sk_sp<SkTypeface> moonbit_skia_linux_typeface_from_family(
  const char* family_name,
  const SkFontStyle& style
) {
  SkFontMgr* font_mgr = moonbit_skia_linux_font_mgr();
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

static sk_sp<SkTypeface> moonbit_skia_linux_typeface_for_character(
  const char* family_name,
  const SkFontStyle& style,
  SkUnichar character
) {
  SkUnichar characters[] = {character};
  sk_sp<SkTypeface> from_fontconfig = moonbit_skia_linux_typeface_from_fontconfig(
    family_name,
    style,
    characters,
    1
  );
  if (from_fontconfig) {
    return from_fontconfig;
  }

  SkFontMgr* font_mgr = moonbit_skia_linux_font_mgr();
  if (font_mgr == nullptr) {
    return nullptr;
  }

  const bool has_family_name = family_name != nullptr && family_name[0] != '\0';
  const char* zh_bcp47[] = {"zh-Hans", "zh"};
  sk_sp<SkTypeface> typeface = font_mgr->matchFamilyStyleCharacter(
    has_family_name ? family_name : nullptr,
    style,
    zh_bcp47,
    2,
    character
  );
  if (moonbit_skia_typeface_can_draw_character(typeface, character)) {
    return typeface;
  }
  return nullptr;
}

static sk_sp<SkTypeface> moonbit_skia_linux_typeface_for_characters(
  const char* family_name,
  const SkFontStyle& style,
  const SkUnichar* characters,
  size_t character_count
) {
  sk_sp<SkTypeface> from_fontconfig = moonbit_skia_linux_typeface_from_fontconfig(
    family_name,
    style,
    characters,
    character_count
  );
  if (from_fontconfig) {
    return from_fontconfig;
  }

  SkFontMgr* font_mgr = moonbit_skia_linux_font_mgr();
  if (font_mgr == nullptr || characters == nullptr || character_count == 0) {
    return nullptr;
  }

  const bool has_family_name = family_name != nullptr && family_name[0] != '\0';
  const char* zh_bcp47[] = {"zh-Hans", "zh"};
  sk_sp<SkTypeface> typeface = font_mgr->matchFamilyStyleCharacter(
    has_family_name ? family_name : nullptr,
    style,
    zh_bcp47,
    2,
    characters[0]
  );
  if (moonbit_skia_typeface_can_draw_characters(typeface, characters, character_count)) {
    return typeface;
  }
  return nullptr;
}
#endif

sk_sp<SkTypeface> moonbit_skia_default_typeface(void) {
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
#elif defined(__ANDROID__)
  SkUnichar latin_sample[] = {'S'};
  const char* android_families[] = {
    "sans-serif",
    "Roboto",
    "Noto Sans",
    nullptr,
  };
  for (const char* family : android_families) {
    sk_sp<SkTypeface> typeface = moonbit_skia_android_typeface_for_characters(
      family,
      SkFontStyle::Normal(),
      latin_sample,
      1
    );
    if (typeface) {
      return typeface;
    }
  }
  return moonbit_skia_android_typeface_from_family(nullptr, SkFontStyle::Normal());
#elif defined(__linux__) && \
  (defined(MOUI_SKIA_HAS_FONTCONFIG_FONTMGR) || defined(MOUI_SKIA_HAS_DIRECTORY_FONTMGR))
  SkUnichar mixed_script_sample[] = {0x4F60, 'S'};
  const char* mixed_script_families[] = {
    "HarmonyOS Sans SC",
    "HarmonyOS Sans",
    "Noto Sans CJK SC",
    "Noto Sans CJK",
    "Source Han Sans SC",
    "WenQuanYi Zen Hei",
    "Droid Sans Fallback",
    "DejaVu Sans",
    "Noto Sans",
    nullptr,
  };
  for (const char* family : mixed_script_families) {
    sk_sp<SkTypeface> typeface = moonbit_skia_linux_typeface_for_characters(
      family,
      SkFontStyle::Normal(),
      mixed_script_sample,
      2
    );
    if (typeface) {
      return typeface;
    }
  }

  SkUnichar latin_sample[] = {'S'};
  const char* latin_families[] = {
    "HarmonyOS Sans",
    "DejaVu Sans",
    "Noto Sans",
    "Liberation Sans",
    "Nimbus Sans",
    nullptr,
  };
  for (const char* family : latin_families) {
    sk_sp<SkTypeface> typeface = moonbit_skia_linux_typeface_for_characters(
      family,
      SkFontStyle::Normal(),
      latin_sample,
      1
    );
    if (typeface) {
      return typeface;
    }
  }
  return moonbit_skia_linux_typeface_from_family(nullptr, SkFontStyle::Normal());
#endif
  return SkTypeface::MakeEmpty();
}

sk_sp<SkTypeface> moonbit_skia_typeface_from_family(
  const char* family_name,
  const SkFontStyle& style
) {
#if defined(_WIN32)
  return moonbit_skia_windows_typeface_from_family(family_name, style);
#elif defined(__APPLE__)
  return moonbit_skia_macos_typeface_from_family(family_name, style);
#elif defined(__ANDROID__)
  return moonbit_skia_android_typeface_from_family(family_name, style);
#elif defined(__linux__) && \
  (defined(MOUI_SKIA_HAS_FONTCONFIG_FONTMGR) || defined(MOUI_SKIA_HAS_DIRECTORY_FONTMGR))
  return moonbit_skia_linux_typeface_from_family(family_name, style);
#else
  (void)family_name;
  (void)style;
#endif
  return SkTypeface::MakeEmpty();
}

sk_sp<SkFontMgr> moonbit_skia_default_font_mgr(void) {
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
#elif defined(__ANDROID__)
  SkFontMgr* font_mgr = moonbit_skia_android_font_mgr();
  if (font_mgr == nullptr) {
    return nullptr;
  }
  font_mgr->ref();
  return sk_sp<SkFontMgr>(font_mgr);
#elif defined(__linux__) && \
  (defined(MOUI_SKIA_HAS_FONTCONFIG_FONTMGR) || defined(MOUI_SKIA_HAS_DIRECTORY_FONTMGR))
  SkFontMgr* font_mgr = moonbit_skia_linux_font_mgr();
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

#if defined(MOUI_SKIA_HAS_SKIA)
SkFontStyle moonbit_skia_font_style(
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

MoonbitSkiaImage* moonbit_skia_make_image_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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

MoonbitSkiaSurface* moonbit_skia_make_surface_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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
  wrapper->gpu_context_owner = nullptr;
  wrapper->host_present_handle = nullptr;
  return wrapper;
}

MoonbitSkiaGpuContext* moonbit_skia_make_gpu_context_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  GrDirectContext* context,
#else
  void* context,
#endif
  void* device,
  void* queue,
  int32_t backend
) {
  MoonbitSkiaGpuContext* wrapper = static_cast<MoonbitSkiaGpuContext*>(
    moonbit_make_external_object(
      moonbit_skia_gpu_context_finalize,
      sizeof(MoonbitSkiaGpuContext)
    )
  );
  wrapper->context = context;
  wrapper->device = device;
  wrapper->queue = queue;
  wrapper->backend = backend;
  return wrapper;
}

MoonbitSkiaCanvas* moonbit_skia_make_canvas_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
  if (wrapper->surface_owner != nullptr) {
    wrapper->surface_owner->ref();
  }
#endif
  return wrapper;
}

#if defined(MOUI_SKIA_HAS_SKIA)
SkPaint moonbit_skia_make_paint(
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
#if defined(MOUI_SKIA_HAS_LEGACY_COLOR_FILTER) || defined(MOUI_SKIA_HAS_CORE_COLOR_FILTER)
  if (color_filter != nullptr && color_filter->color_filter != nullptr) {
    paint.setColorFilter(sk_ref_sp(color_filter->color_filter));
  }
#else
  (void)color_filter;
#endif
#if defined(MOUI_SKIA_HAS_IMAGE_FILTERS)
  if (image_filter != nullptr && image_filter->image_filter != nullptr) {
    paint.setImageFilter(sk_ref_sp(image_filter->image_filter));
  }
#else
  (void)image_filter;
#endif
#if defined(MOUI_SKIA_HAS_MASK_FILTER)
  if (mask_filter != nullptr && mask_filter->mask_filter != nullptr) {
    paint.setMaskFilter(sk_ref_sp(mask_filter->mask_filter));
  }
#else
  (void)mask_filter;
#endif
  return paint;
}

SkPaint moonbit_skia_make_paint(
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

SkPaint moonbit_skia_make_paint_with_shader(
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

SkSamplingOptions moonbit_skia_make_sampling_options(
  int32_t filter,
  int32_t mipmap,
  int32_t use_cubic,
  float cubic_b,
  float cubic_c
) {
  if (use_cubic != 0 && std::isfinite(cubic_b) && std::isfinite(cubic_c)) {
    return SkSamplingOptions(SkCubicResampler{cubic_b, cubic_c});
  }
  return SkSamplingOptions(
    static_cast<SkFilterMode>(filter),
    static_cast<SkMipmapMode>(mipmap)
  );
}

SkImageInfo moonbit_skia_make_rgba8888_premul_info(
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

SkRRect moonbit_skia_make_rrect(
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
#if defined(MOUI_SKIA_HAS_SKIA)
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_shaper_available(void) {
#if defined(MOUI_SKIA_HAS_SKIA) && \
  defined(MOUI_SKIA_HAS_SKSHAPER_HEADERS) && \
  defined(MOUI_SKIA_HAS_SKSHAPER_LEGACY)
  return 1;
#else
  return 0;
#endif
}

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
sk_sp<SkUnicode> moonbit_skia_shared_icu_unicode() {
  static sk_sp<SkUnicode> instance = SkUnicodes::ICU::Make();
  return instance;
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t moonbit_skia_paragraph_available(void) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  return moonbit_skia_shared_icu_unicode() != nullptr ? 1 : 0;
#else
  return 0;
#endif
}
