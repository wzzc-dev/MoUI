#include "skia_stub_common.h"

#include <algorithm>
#include <cmath>

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_canvas_draw_backdrop_blur(
  MoonbitSkiaCanvas* wrapper,
  float x,
  float y,
  float width,
  float height,
  float radius,
  float blur,
  uint32_t tint_argb
) {
  if (
    wrapper == nullptr ||
    wrapper->canvas == nullptr ||
    !std::isfinite(x) ||
    !std::isfinite(y) ||
    !std::isfinite(width) ||
    !std::isfinite(height) ||
    width <= 0.0f ||
    height <= 0.0f
  ) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkCanvas* canvas = wrapper->canvas;
  SkRect rect = SkRect::MakeXYWH(x, y, width, height);
  SkScalar corner = std::max(0.0f, std::min(radius, std::min(width, height) * 0.5f));
  SkRRect rrect = SkRRect::MakeRectXY(rect, corner, corner);
  bool blurred = false;
  if (std::isfinite(blur) && blur > 0.0f) {
    SkPixmap pixmap;
    if (canvas->peekPixels(&pixmap)) {
      sk_sp<SkImage> image = SkImages::RasterFromPixmapCopy(pixmap);
      if (image) {
        SkPaint paint;
        paint.setAntiAlias(true);
        paint.setImageFilter(
          SkImageFilters::Blur(blur, blur, SkTileMode::kClamp, nullptr)
        );
        canvas->save();
        canvas->clipRRect(rrect, SkClipOp::kIntersect, true);
        canvas->drawImage(
          image,
          0.0f,
          0.0f,
          SkSamplingOptions(SkFilterMode::kLinear),
          &paint
        );
        canvas->restore();
        blurred = true;
      }
    }
  }
  SkPaint tint;
  tint.setAntiAlias(true);
  tint.setColor(static_cast<SkColor>(tint_argb));
  canvas->drawRRect(rrect, tint);
  return blurred ? 1 : 0;
#else
  (void)x;
  (void)y;
  (void)width;
  (void)height;
  (void)radius;
  (void)blur;
  (void)tint_argb;
  return 0;
#endif
}
