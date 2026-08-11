#ifndef MOUI_SKIA_STUB_COMMON_H
#define MOUI_SKIA_STUB_COMMON_H

// moonbit.h may declare memcpy without a C++ exception specifier. Include the
// system string.h first on Unix-like hosts (Linux/Android/HarmonyOS) so the
// libc declaration wins before moonbit.h redeclares it.
#if defined(__cplusplus) && \
  (defined(__linux__) || defined(__ANDROID__) || defined(__OHOS__))
#include <string.h>
#define MOUI_SKIA_SKIP_MOONBIT_MEMCPY_DECL 1
#define memcpy memcpy
#endif
#include <moonbit.h>
#if defined(MOUI_SKIA_SKIP_MOONBIT_MEMCPY_DECL)
#undef memcpy
#undef MOUI_SKIA_SKIP_MOONBIT_MEMCPY_DECL
#else
#include <string.h>
#endif
#include <stdint.h>
#include <stddef.h>
#include <algorithm>
#include <limits>
#include <map>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#if defined(MOUI_SKIA_HAS_SKIA) && \
  __has_include("include/gpu/ganesh/GrDirectContext.h") && \
  __has_include("include/gpu/ganesh/vk/GrVkDirectContext.h") && \
  __has_include("include/gpu/ganesh/vk/GrVkTypes.h") && \
  __has_include("include/gpu/ganesh/vk/GrVkBackendSurface.h") && \
  __has_include("include/gpu/vk/VulkanBackendContext.h") && \
  __has_include("include/android/vk/AndroidVulkanMemoryAllocator.h") && \
  __has_include("include/gpu/ganesh/GrBackendSurface.h") && \
  __has_include("include/gpu/ganesh/SkSurfaceGanesh.h") && \
  __has_include(<vulkan/vulkan.h>)
#if (defined(__ANDROID__) && __has_include(<vulkan/vulkan_android.h>) && \
  __has_include(<android/native_window.h>)) || \
  (defined(__linux__) && __has_include(<vulkan/vulkan_wayland.h>) && \
  __has_include(<wayland-client.h>))
#define MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS 1
#endif
#endif

#if defined(MOUI_SKIA_HAS_SKIA)
#if defined(_WIN32) && !defined(SK_BUILD_FOR_WIN)
#define SK_BUILD_FOR_WIN
#endif
#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#if !defined(SK_BUILD_FOR_IOS)
#define SK_BUILD_FOR_IOS
#endif
#elif !defined(SK_BUILD_FOR_MAC)
#define SK_BUILD_FOR_MAC
#endif
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
#define MOUI_SKIA_HAS_PATH_BUILDER 1
#endif
#include "include/core/SkPoint.h"
#include "include/core/SkRect.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSamplingOptions.h"
#include "include/core/SkShader.h"
#include "include/core/SkString.h"
#include "include/core/SkSurface.h"
#if __has_include("include/core/SkPicture.h")
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#define MOUI_SKIA_HAS_PICTURE 1
#endif
#include "include/core/SkTypeface.h"
#include "include/core/SkTypes.h"
#if defined(MOUI_SKIA_HAS_SKIA)
// Embedded-font registry lookup (see moonbit_skia_typeface_register_data in
// skia_stub_text_font.cpp). Returns nullptr when the family name is unknown.
// Paragraph layout uses this to resolve app-registered font data.
sk_sp<SkTypeface> moonbit_skia_embedded_typeface_for_name(
  const std::string& name
);
#endif
#if __has_include("include/gpu/ganesh/GrDirectContext.h")
#include "include/gpu/ganesh/GrDirectContext.h"
#define MOUI_SKIA_HAS_GANESH_DIRECT_CONTEXT 1
#if __has_include("include/gpu/ganesh/SkSurfaceGanesh.h")
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#define MOUI_SKIA_HAS_GANESH_SURFACE 1
#endif
#else
class GrDirectContext;
#endif
#if defined(MOUI_SKIA_HAS_SKSHAPER) && __has_include("modules/skshaper/include/SkShaper.h")
#include "modules/skshaper/include/SkShaper.h"
#define MOUI_SKIA_HAS_SKSHAPER_HEADERS 1
#if !defined(SK_DISABLE_LEGACY_SKSHAPER_FUNCTIONS)
#define MOUI_SKIA_HAS_SKSHAPER_LEGACY 1
#endif
#if defined(__APPLE__) && __has_include("modules/skshaper/include/SkShaper_coretext.h")
#include "modules/skshaper/include/SkShaper_coretext.h"
#define MOUI_SKIA_HAS_SKSHAPER_CORETEXT 1
#endif
#endif
#if defined(MOUI_SKIA_HAS_SKPARAGRAPH) && \
  __has_include("modules/skparagraph/include/Paragraph.h") && \
  __has_include("modules/skparagraph/include/ParagraphBuilder.h") && \
  __has_include("modules/skparagraph/include/ParagraphStyle.h") && \
  __has_include("modules/skparagraph/include/TextStyle.h") && \
  __has_include("modules/skparagraph/include/FontCollection.h") && \
  __has_include("modules/skunicode/include/SkUnicode_icu.h")
#include "modules/skparagraph/include/Paragraph.h"
#include "modules/skparagraph/include/ParagraphBuilder.h"
#include "modules/skparagraph/include/ParagraphStyle.h"
#include "modules/skparagraph/include/TextStyle.h"
#include "modules/skparagraph/include/FontCollection.h"
#include "modules/skunicode/include/SkUnicode_icu.h"
#define MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS 1
#endif
#include "include/codec/SkCodec.h"
#include "include/codec/SkEncodedImageFormat.h"
#include "include/encode/SkJpegEncoder.h"
#include "include/encode/SkPngEncoder.h"
#if defined(MOUI_SKIA_HAS_WEBP_ENCODER) && __has_include("include/encode/SkWebpEncoder.h")
#include "include/encode/SkWebpEncoder.h"
#endif
#if __has_include("include/effects/SkColorFilter.h")
#include "include/effects/SkColorFilter.h"
#define MOUI_SKIA_HAS_LEGACY_COLOR_FILTER 1
#elif __has_include("include/core/SkColorFilter.h")
#include "include/core/SkColorFilter.h"
#define MOUI_SKIA_HAS_CORE_COLOR_FILTER 1
#endif
#if __has_include("include/effects/SkImageFilters.h")
#include "include/effects/SkImageFilters.h"
#define MOUI_SKIA_HAS_IMAGE_FILTERS 1
#endif
#if __has_include("include/core/SkMaskFilter.h")
#include "include/core/SkMaskFilter.h"
#define MOUI_SKIA_HAS_MASK_FILTER 1
#endif
#if __has_include("include/core/SkBlurTypes.h")
#include "include/core/SkBlurTypes.h"
#define MOUI_SKIA_HAS_BLUR_TYPES 1
#endif
#if __has_include("include/effects/SkGradientShader.h")
#include "include/effects/SkGradientShader.h"
#define MOUI_SKIA_HAS_LEGACY_GRADIENT_SHADER 1
#elif __has_include("include/effects/SkGradient.h")
#include "include/effects/SkGradient.h"
#define MOUI_SKIA_HAS_NEW_GRADIENT_SHADER 1
#endif
#include "include/core/SkRefCnt.h"
#if defined(_WIN32)
#include "include/ports/SkTypeface_win.h"
#endif
#if defined(__APPLE__)
#include "include/ports/SkFontMgr_mac_ct.h"
#endif
#if defined(__ANDROID__) && \
  __has_include("include/ports/SkFontMgr_android_ndk.h") && \
  __has_include("include/ports/SkFontScanner_FreeType.h")
#include "include/ports/SkFontMgr_android_ndk.h"
#include "include/ports/SkFontScanner_FreeType.h"
#define MOUI_SKIA_HAS_ANDROID_NDK_FONTMGR 1
#endif
#if defined(__ANDROID__) && \
  __has_include("include/ports/SkFontMgr_android.h") && \
  __has_include("include/ports/SkFontScanner_FreeType.h")
#include "include/ports/SkFontMgr_android.h"
#include "include/ports/SkFontScanner_FreeType.h"
#define MOUI_SKIA_HAS_ANDROID_FONTMGR 1
#endif
#if defined(__linux__) && __has_include(<fontconfig/fontconfig.h>) && \
  __has_include("include/ports/SkFontMgr_fontconfig.h") && \
  __has_include("include/ports/SkFontScanner_FreeType.h")
#include "include/ports/SkFontMgr_fontconfig.h"
#include "include/ports/SkFontScanner_FreeType.h"
#define MOUI_SKIA_HAS_FONTCONFIG_FONTMGR 1
#endif
#if defined(__linux__) && __has_include("include/ports/SkFontMgr_directory.h")
#include "include/ports/SkFontMgr_directory.h"
#define MOUI_SKIA_HAS_DIRECTORY_FONTMGR 1
#endif
#if defined(__linux__) && __has_include("include/ports/SkFontMgr_empty.h")
#include "include/ports/SkFontMgr_empty.h"
#define MOUI_SKIA_HAS_EMPTY_FONTMGR 1
#endif
#if defined(__linux__) && __has_include("include/utils/SkOrderedFontMgr.h")
#include "include/utils/SkOrderedFontMgr.h"
#define MOUI_SKIA_HAS_ORDERED_FONTMGR 1
#endif
#endif

struct MoonbitSkiaSurface {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkSurface* surface;
  GrDirectContext* gpu_context_owner;
#else
  void* surface;
  void* gpu_context_owner;
#endif
  /// Retained host present handle (e.g. id<CAMetalDrawable>) that owns the
  /// MTLTexture backing this surface. Null for raster / offscreen GPU surfaces.
  void* host_present_handle;
};

#if defined(__APPLE__)
/// Retain an Objective-C object that crosses an asynchronous native boundary.
void moonbit_skia_objc_retain(void* object);
/// Release a retained Objective-C object (e.g. CAMetalDrawable) stored as
/// host_present_handle. Safe to call with nullptr. On non-Apple platforms
/// this is a no-op stub.
void moonbit_skia_objc_release(void* object);
#else
static inline void moonbit_skia_objc_retain(void* object) { (void)object; }
static inline void moonbit_skia_objc_release(void* object) { (void)object; }
#endif

#if defined(_WIN32)
/// Release a COM object (e.g. IDXGISwapChain) stored as host_present_handle on
/// Windows. Safe to call with nullptr. On non-Windows platforms this is a
/// no-op stub. The definition lives in skia_stub_surface_image_data.cpp.
void moonbit_skia_com_release(void* object);
#else
static inline void moonbit_skia_com_release(void* object) { (void)object; }
#endif

#if defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  defined(MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS)
/// Release a heap-allocated MoonbitSkiaVulkanContext stored as the `device`
/// field of MoonbitSkiaGpuContext on Android or Linux. Safe to call with
/// nullptr. When Vulkan support is unavailable this is an inline no-op. The
/// definition lives in
/// skia_stub_surface_image_data.cpp.
void moonbit_skia_vulkan_release_context(void* object);
/// Release a heap-allocated MoonbitSkiaVulkanSwapChain stored as
/// host_present_handle on Android or Linux. Safe to call with nullptr. When
/// Vulkan support is unavailable this is an inline no-op. The definition
/// lives in skia_stub_surface_image_data.cpp.
void moonbit_skia_vulkan_release_swapchain(void* object);
#else
static inline void moonbit_skia_vulkan_release_context(void* object) {
  (void)object;
}
static inline void moonbit_skia_vulkan_release_swapchain(void* object) {
  (void)object;
}
#endif

#if defined(__OHOS__) || defined(__ANDROID__)
/// Release a heap-allocated MoonbitSkiaEglContext stored as the `device`
/// field of MoonbitSkiaGpuContext on HarmonyOS or Android. Safe to call with
/// nullptr. On other platforms this is a no-op stub. The definition lives in
/// skia_stub_surface_image_data.cpp.
void moonbit_skia_egl_release_context(void* object);
/// Release a heap-allocated MoonbitSkiaEglWindow stored as
/// host_present_handle on HarmonyOS or Android. Safe to call with nullptr. On
/// other platforms this is a no-op stub. The definition lives in
/// skia_stub_surface_image_data.cpp.
void moonbit_skia_egl_release_window(void* object);
#else
static inline void moonbit_skia_egl_release_context(void* object) {
  (void)object;
}
static inline void moonbit_skia_egl_release_window(void* object) {
  (void)object;
}
#endif

struct MoonbitSkiaGpuContext {
#if defined(MOUI_SKIA_HAS_SKIA)
  GrDirectContext* context;
#else
  void* context;
#endif
  void* device;
  void* queue;
  int32_t backend;
};

struct MoonbitSkiaNativeGpuWorker;

struct MoonbitSkiaData {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkData* data;
#else
  void* data;
#endif
};

struct MoonbitSkiaCodec {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkCodec* codec;
#else
  void* codec;
#endif
};

struct MoonbitSkiaImage {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkImage* image;
#else
  void* image;
#endif
};

struct MoonbitSkiaCanvas {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkCanvas* canvas;
  SkSurface* surface_owner;
#else
  void* canvas;
  void* surface_owner;
#endif
};

struct MoonbitSkiaPath {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPath* path;
#else
  void* path;
#endif
};

struct MoonbitSkiaFont {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkFont* font;
#else
  void* font;
#endif
};

struct MoonbitSkiaTypeface {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkTypeface* typeface;
#else
  void* typeface;
#endif
};

struct MoonbitSkiaFontMgr {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkFontMgr* font_mgr;
#else
  void* font_mgr;
#endif
};

struct MoonbitSkiaShader {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkShader* shader;
#else
  void* shader;
#endif
};

struct MoonbitSkiaColorFilter {
#if defined(MOUI_SKIA_HAS_SKIA) && \
  (defined(MOUI_SKIA_HAS_LEGACY_COLOR_FILTER) || defined(MOUI_SKIA_HAS_CORE_COLOR_FILTER))
  SkColorFilter* color_filter;
#else
  void* color_filter;
#endif
};

struct MoonbitSkiaImageFilter {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_IMAGE_FILTERS)
  SkImageFilter* image_filter;
#else
  void* image_filter;
#endif
};

struct MoonbitSkiaMaskFilter {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_MASK_FILTER)
  SkMaskFilter* mask_filter;
#else
  void* mask_filter;
#endif
};

struct MoonbitSkiaBitmap {
#if defined(MOUI_SKIA_HAS_SKIA)
  SkBitmap* bitmap;
#else
  void* bitmap;
#endif
};

struct MoonbitSkiaPicture {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  SkPicture* picture;
#else
  void* picture;
#endif
};

struct MoonbitSkiaPictureRecorder {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  SkPictureRecorder* recorder;
#else
  void* recorder;
#endif
};

MoonbitSkiaPicture* moonbit_skia_make_picture_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  SkPicture* picture
#else
  void* picture
#endif
);

MoonbitSkiaPictureRecorder* moonbit_skia_make_picture_recorder_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  SkPictureRecorder* recorder
#else
  void* recorder
#endif
);

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

struct MoonbitSkiaFloatArray {
  int32_t length;
  float* buffer;
};

struct MoonbitSkiaGlyphIdArray {
  int32_t length;
  uint16_t* buffer;
};

struct MoonbitSkiaPointArray {
  int32_t length;
  MoonbitSkiaPoint** buffer;
};

struct MoonbitSkiaRectArray {
  int32_t length;
  MoonbitSkiaRect** buffer;
};

struct MoonbitSkiaInt32Array {
  int32_t length;
  int32_t* buffer;
};

struct MoonbitSkiaShapedTextRun {
  int32_t glyph_count;
  float advance_x;
  float advance_y;
  MoonbitSkiaGlyphIdArray* glyphs;
  MoonbitSkiaPointArray* positions;
  MoonbitSkiaInt32Array* clusters;
};

struct MoonbitSkiaParagraph {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  skia::textlayout::Paragraph* paragraph;
#else
  void* paragraph;
#endif
};

MoonbitSkiaFloatArray* moonbit_skia_make_float_array(
  int32_t length,
  float* buffer
);
MoonbitSkiaGlyphIdArray* moonbit_skia_make_glyph_id_array(
  int32_t length,
  uint16_t* buffer
);
uint16_t* moonbit_skia_make_glyph_id_array_storage(
  int32_t length
);
MoonbitSkiaPoint* moonbit_skia_make_point(float x, float y);
MoonbitSkiaRect* moonbit_skia_make_rect(
  float left,
  float top,
  float right,
  float bottom
);
MoonbitSkiaPointArray* moonbit_skia_make_point_array(
  int32_t length,
  MoonbitSkiaPoint** buffer
);
MoonbitSkiaPoint** moonbit_skia_make_point_array_storage(
  int32_t length
);
MoonbitSkiaRectArray* moonbit_skia_make_rect_array(
  int32_t length,
  MoonbitSkiaRect** buffer
);
MoonbitSkiaRect** moonbit_skia_make_rect_array_storage(
  int32_t length
);
MoonbitSkiaInt32Array* moonbit_skia_make_int32_array(
  int32_t length,
  int32_t* buffer
);
MoonbitSkiaShapedTextRun* moonbit_skia_make_shaped_text_run(
  int32_t glyph_count,
  float advance_x,
  float advance_y,
  MoonbitSkiaGlyphIdArray* glyphs,
  MoonbitSkiaPointArray* positions,
  MoonbitSkiaInt32Array* clusters
);
MoonbitSkiaShapedTextRun* moonbit_skia_make_empty_shaped_text_run();
MoonbitSkiaParagraph* moonbit_skia_make_paragraph_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
  skia::textlayout::Paragraph* paragraph
#else
  void* paragraph
#endif
);

#if defined(MOUI_SKIA_HAS_SKIA)
moonbit_bytes_t moonbit_skia_make_bytes_from_sk_string(
  const SkString& value
);
std::string moonbit_skia_bytes_to_string(moonbit_bytes_t value);
sk_sp<SkTypeface> moonbit_skia_default_typeface(void);
sk_sp<SkTypeface> moonbit_skia_typeface_from_family(
  const char* family_name,
  const SkFontStyle& style
);
sk_sp<SkFontMgr> moonbit_skia_default_font_mgr(void);
SkFontStyle moonbit_skia_font_style(
  int32_t weight,
  int32_t width,
  int32_t slant
);
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
);
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
);
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
);
SkSamplingOptions moonbit_skia_make_sampling_options(
  int32_t filter,
  int32_t mipmap,
  int32_t use_cubic,
  float cubic_b,
  float cubic_c
);
SkImageInfo moonbit_skia_make_rgba8888_premul_info(
  int32_t width,
  int32_t height
);
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
);
#endif

MoonbitSkiaFont* moonbit_skia_make_font_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkFont* font
#else
  void* font
#endif
);
MoonbitSkiaTypeface* moonbit_skia_make_typeface_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkTypeface* typeface
#else
  void* typeface
#endif
);
MoonbitSkiaFontMgr* moonbit_skia_make_font_mgr_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkFontMgr* font_mgr
#else
  void* font_mgr
#endif
);
MoonbitSkiaShader* moonbit_skia_make_shader_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkShader* shader
#else
  void* shader
#endif
);
MoonbitSkiaColorFilter* moonbit_skia_make_color_filter_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && \
  (defined(MOUI_SKIA_HAS_LEGACY_COLOR_FILTER) || defined(MOUI_SKIA_HAS_CORE_COLOR_FILTER))
  SkColorFilter* color_filter
#else
  void* color_filter
#endif
);
MoonbitSkiaImageFilter* moonbit_skia_make_image_filter_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_IMAGE_FILTERS)
  SkImageFilter* image_filter
#else
  void* image_filter
#endif
);
MoonbitSkiaMaskFilter* moonbit_skia_make_mask_filter_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_MASK_FILTER)
  SkMaskFilter* mask_filter
#else
  void* mask_filter
#endif
);
MoonbitSkiaCodec* moonbit_skia_make_codec_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkCodec* codec
#else
  void* codec
#endif
);
MoonbitSkiaBitmap* moonbit_skia_make_bitmap_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkBitmap* bitmap
#else
  void* bitmap
#endif
);
MoonbitSkiaPath* moonbit_skia_make_path_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPath* path
#else
  void* path
#endif
);
MoonbitSkiaData* moonbit_skia_make_data_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkData* data
#else
  void* data
#endif
);
MoonbitSkiaImage* moonbit_skia_make_image_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkImage* image
#else
  void* image
#endif
);
MoonbitSkiaSurface* moonbit_skia_make_surface_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkSurface* surface
#else
  void* surface
#endif
);
MoonbitSkiaGpuContext* moonbit_skia_make_gpu_context_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  GrDirectContext* context,
#else
  void* context,
#endif
  void* device,
  void* queue,
  int32_t backend
);
MoonbitSkiaCanvas* moonbit_skia_make_canvas_wrapper(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkCanvas* canvas,
  SkSurface* surface_owner
#else
  void* canvas,
  void* surface_owner
#endif
);
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_SKPARAGRAPH_HEADERS)
sk_sp<SkUnicode> moonbit_skia_shared_icu_unicode(void);
#endif

#endif
