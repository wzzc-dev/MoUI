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
moonbit_skia_color_filter_matrix(void* values_obj) {
  if (values_obj == nullptr) {
    return moonbit_skia_make_color_filter_wrapper(nullptr);
  }
  // MoonBit passes a FixedArray[Float] (val array, inline float32 data with
  // the length in the object header meta). A regular object
  // (MoonbitSkiaFloatArray, {length, buffer*}) is still accepted for callers
  // that build the descriptor by hand. Detect the kind and read accordingly.
  const float* values_data = nullptr;
  int32_t values_length;
  if (Moonbit_object_kind(values_obj) == moonbit_BLOCK_KIND_VAL_ARRAY) {
    values_length = Moonbit_array_length(values_obj);
    values_data = static_cast<const float*>(values_obj);
  } else {
    MoonbitSkiaFloatArray* values =
      static_cast<MoonbitSkiaFloatArray*>(values_obj);
    values_length = values->length;
    if (values->buffer == nullptr) {
      return moonbit_skia_make_color_filter_wrapper(nullptr);
    }
    values_data = values->buffer;
  }
  if (values_length != 20) {
    return moonbit_skia_make_color_filter_wrapper(nullptr);
  }
  for (int32_t i = 0; i < values_length; ++i) {
    if (!std::isfinite(values_data[static_cast<size_t>(i)])) {
      return moonbit_skia_make_color_filter_wrapper(nullptr);
    }
  }
#if defined(MOUI_SKIA_HAS_SKIA) && \
  (defined(MOUI_SKIA_HAS_LEGACY_COLOR_FILTER) || defined(MOUI_SKIA_HAS_CORE_COLOR_FILTER))
  sk_sp<SkColorFilter> filter = SkColorFilters::Matrix(values_data);
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

#if defined(MOUI_SKIA_HAS_SKIA)
static bool moonbit_skia_read_gradient_payload(
  moonbit_bytes_t colors_bytes,
  moonbit_bytes_t positions_bytes,
  int32_t count,
  std::vector<SkColor>& colors_out,
  std::vector<SkScalar>& positions_out
) {
  if (count < 2 || colors_bytes == nullptr || positions_bytes == nullptr) {
    return false;
  }
  if (Moonbit_array_length(colors_bytes) < count * 4) {
    return false;
  }
  if (Moonbit_array_length(positions_bytes) < count * 8) {
    return false;
  }
  colors_out.resize(static_cast<size_t>(count));
  positions_out.resize(static_cast<size_t>(count));
  memcpy(colors_out.data(), colors_bytes, static_cast<size_t>(count) * 4);
  std::vector<double> raw_positions(static_cast<size_t>(count));
  memcpy(raw_positions.data(), positions_bytes, static_cast<size_t>(count) * 8);
  for (int32_t index = 0; index < count; ++index) {
    positions_out[static_cast<size_t>(index)] =
      static_cast<SkScalar>(raw_positions[static_cast<size_t>(index)]);
  }
  return true;
}
#endif

#if defined(MOUI_SKIA_HAS_SKIA)
static void moonbit_skia_fill_stop_gradient(
  const std::vector<SkColor>& colors,
  const std::vector<SkScalar>& positions,
  int32_t oklab,
  int32_t tile_mode,
  std::vector<SkColor4f>& color4fs,
  SkGradient& gradient
) {
  color4fs.clear();
  color4fs.reserve(colors.size());
  for (SkColor color : colors) {
    color4fs.push_back(SkColor4f::FromColor(color));
  }
  SkGradient::Interpolation interpolation;
#if defined(MOUI_SKIA_HAS_NEW_GRADIENT_SHADER)
  interpolation.fColorSpace = oklab
    ? SkGradient::Interpolation::ColorSpace::kOKLab
    : SkGradient::Interpolation::ColorSpace::kDestination;
#else
  (void)oklab;
#endif
  // The spans must stay alive until SkShaders::* consumes the gradient, so
  // `color4fs` and `positions` are owned by the caller.
  gradient = SkGradient(
    SkGradient::Colors(
      SkSpan<const SkColor4f>(color4fs.data(), color4fs.size()),
      SkSpan<const float>(positions.data(), positions.size()),
      static_cast<SkTileMode>(tile_mode)
    ),
    interpolation
  );
}
#endif

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaShader*
moonbit_skia_shader_linear_gradient_stops(
  float x0,
  float y0,
  float x1,
  float y1,
  moonbit_bytes_t colors_bytes,
  moonbit_bytes_t positions_bytes,
  int32_t count,
  int32_t tile_mode,
  int32_t oklab
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
  std::vector<SkColor> colors;
  std::vector<SkScalar> positions;
  if (!moonbit_skia_read_gradient_payload(
    colors_bytes, positions_bytes, count, colors, positions
  )) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  SkPoint points[2] = {SkPoint::Make(x0, y0), SkPoint::Make(x1, y1)};
  std::vector<SkColor4f> color4fs;
  SkGradient gradient;
  moonbit_skia_fill_stop_gradient(
    colors, positions, oklab, tile_mode, color4fs, gradient
  );
#if defined(MOUI_SKIA_HAS_NEW_GRADIENT_SHADER)
  sk_sp<SkShader> shader = SkShaders::LinearGradient(points, gradient);
#else
  sk_sp<SkShader> shader = SkGradientShader::MakeLinear(
    points,
    colors.data(),
    positions.data(),
    count,
    static_cast<SkTileMode>(tile_mode)
  );
#endif
  if (!shader) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  return moonbit_skia_make_shader_wrapper(shader.release());
#else
  (void)x0; (void)y0; (void)x1; (void)y1; (void)oklab;
  (void)colors_bytes; (void)positions_bytes; (void)count; (void)tile_mode;
  return moonbit_skia_make_shader_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaShader*
moonbit_skia_shader_radial_gradient_stops(
  float center_x,
  float center_y,
  float radius,
  moonbit_bytes_t colors_bytes,
  moonbit_bytes_t positions_bytes,
  int32_t count,
  int32_t tile_mode,
  int32_t oklab
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
  std::vector<SkColor> colors;
  std::vector<SkScalar> positions;
  if (!moonbit_skia_read_gradient_payload(
    colors_bytes, positions_bytes, count, colors, positions
  )) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  std::vector<SkColor4f> color4fs;
  SkGradient gradient;
  moonbit_skia_fill_stop_gradient(
    colors, positions, oklab, tile_mode, color4fs, gradient
  );
#if defined(MOUI_SKIA_HAS_NEW_GRADIENT_SHADER)
  sk_sp<SkShader> shader = SkShaders::RadialGradient(
    SkPoint::Make(center_x, center_y),
    radius,
    gradient
  );
#else
  sk_sp<SkShader> shader = SkGradientShader::MakeRadial(
    SkPoint::Make(center_x, center_y),
    radius,
    colors.data(),
    positions.data(),
    count,
    static_cast<SkTileMode>(tile_mode)
  );
#endif
  if (!shader) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  return moonbit_skia_make_shader_wrapper(shader.release());
#else
  (void)center_x; (void)center_y; (void)radius; (void)oklab;
  (void)colors_bytes; (void)positions_bytes; (void)count; (void)tile_mode;
  return moonbit_skia_make_shader_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaShader*
moonbit_skia_shader_sweep_gradient_stops(
  float center_x,
  float center_y,
  float start_angle,
  float end_angle,
  moonbit_bytes_t colors_bytes,
  moonbit_bytes_t positions_bytes,
  int32_t count,
  int32_t tile_mode,
  int32_t oklab
) {
  if (
    !std::isfinite(center_x) ||
    !std::isfinite(center_y) ||
    !std::isfinite(start_angle) ||
    !std::isfinite(end_angle) ||
    start_angle >= end_angle
  ) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  std::vector<SkColor> colors;
  std::vector<SkScalar> positions;
  if (!moonbit_skia_read_gradient_payload(
    colors_bytes, positions_bytes, count, colors, positions
  )) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  std::vector<SkColor4f> color4fs;
  SkGradient gradient;
  moonbit_skia_fill_stop_gradient(
    colors, positions, oklab, tile_mode, color4fs, gradient
  );
#if defined(MOUI_SKIA_HAS_NEW_GRADIENT_SHADER)
  sk_sp<SkShader> shader = SkShaders::SweepGradient(
    SkPoint::Make(center_x, center_y),
    start_angle,
    end_angle,
    gradient
  );
#else
  sk_sp<SkShader> shader = SkGradientShader::MakeSweep(
    center_x,
    center_y,
    colors.data(),
    positions.data(),
    count,
    static_cast<SkTileMode>(tile_mode),
    start_angle,
    end_angle
  );
#endif
  if (!shader) {
    return moonbit_skia_make_shader_wrapper(nullptr);
  }
  return moonbit_skia_make_shader_wrapper(shader.release());
#else
  (void)center_x; (void)center_y; (void)start_angle; (void)end_angle; (void)oklab;
  (void)colors_bytes; (void)positions_bytes; (void)count; (void)tile_mode;
  return moonbit_skia_make_shader_wrapper(nullptr);
#endif
}
