#include "skia_stub_common.h"

#include <cmath>

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
  for (int32_t i = 0; i < values->length; ++i) {
    if (!std::isfinite(values->buffer[i])) {
      return moonbit_skia_make_color_filter_wrapper(nullptr);
    }
  }
#if defined(MOUI_SKIA_HAS_SKIA) && \
  (defined(MOUI_SKIA_HAS_LEGACY_COLOR_FILTER) || defined(MOUI_SKIA_HAS_CORE_COLOR_FILTER))
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
  if (
    !std::isfinite(sigma_x) ||
    !std::isfinite(sigma_y) ||
    sigma_x <= 0.0f ||
    sigma_y <= 0.0f
  ) {
    return moonbit_skia_make_image_filter_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_IMAGE_FILTERS)
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
  if (!std::isfinite(sigma) || sigma <= 0.0f) {
    return moonbit_skia_make_mask_filter_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_MASK_FILTER) && \
  defined(MOUI_SKIA_HAS_BLUR_TYPES)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_shader_is_null(MoonbitSkiaShader* wrapper) {
  return wrapper == nullptr || wrapper->shader == nullptr;
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
  if (
    !std::isfinite(x0) ||
    !std::isfinite(y0) ||
    !std::isfinite(x1) ||
    !std::isfinite(y1) ||
    (x0 == x1 && y0 == y1)
  ) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkPoint points[2] = {
    SkPoint::Make(x0, y0),
    SkPoint::Make(x1, y1)
  };
  SkColor colors[2] = {
    static_cast<SkColor>(color0_argb),
    static_cast<SkColor>(color1_argb)
  };
#if defined(MOUI_SKIA_HAS_NEW_GRADIENT_SHADER)
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
  if (
    !std::isfinite(center_x) ||
    !std::isfinite(center_y) ||
    !std::isfinite(radius) ||
    radius <= 0.0f
  ) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkColor colors[2] = {
    static_cast<SkColor>(color0_argb),
    static_cast<SkColor>(color1_argb)
  };
#if defined(MOUI_SKIA_HAS_NEW_GRADIENT_SHADER)
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
