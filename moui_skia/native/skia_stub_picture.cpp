#include "skia_stub_common.h"

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaPictureRecorder*
moonbit_skia_picture_recorder_new(void) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  return moonbit_skia_make_picture_recorder_wrapper(new SkPictureRecorder());
#else
  return moonbit_skia_make_picture_recorder_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_picture_recorder_is_null(
  MoonbitSkiaPictureRecorder* recorder
) {
  return recorder == nullptr || recorder->recorder == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_picture_recorder_record_empty(
  MoonbitSkiaPictureRecorder* recorder,
  int32_t width,
  int32_t height
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  if (recorder == nullptr || recorder->recorder == nullptr) {
    return;
  }
  const float safe_width = static_cast<float>(std::max(0, width));
  const float safe_height = static_cast<float>(std::max(0, height));
  SkCanvas* canvas = recorder->recorder->beginRecording(
    SkRect::MakeWH(safe_width, safe_height)
  );
  if (canvas != nullptr) {
    canvas->clear(SK_ColorTRANSPARENT);
  }
#else
  (void)recorder;
  (void)width;
  (void)height;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaCanvas*
moonbit_skia_picture_recorder_begin(
  MoonbitSkiaPictureRecorder* recorder,
  int32_t width,
  int32_t height
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  if (recorder == nullptr || recorder->recorder == nullptr ||
    width <= 0 || height <= 0) {
    return moonbit_skia_make_canvas_wrapper(nullptr, nullptr);
  }
  SkCanvas* canvas = recorder->recorder->beginRecording(
    SkRect::MakeWH(static_cast<float>(width), static_cast<float>(height))
  );
  return moonbit_skia_make_canvas_wrapper(canvas, nullptr);
#else
  (void)recorder;
  (void)width;
  (void)height;
  return moonbit_skia_make_canvas_wrapper(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaPicture*
moonbit_skia_picture_recorder_finish(
  MoonbitSkiaPictureRecorder* recorder
) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  if (recorder == nullptr || recorder->recorder == nullptr) {
    return moonbit_skia_make_picture_wrapper(nullptr);
  }
  sk_sp<SkPicture> picture = recorder->recorder->finishRecordingAsPicture();
  return moonbit_skia_make_picture_wrapper(picture.release());
#else
  (void)recorder;
  return moonbit_skia_make_picture_wrapper(nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_picture_is_null(MoonbitSkiaPicture* picture) {
  return picture == nullptr || picture->picture == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_picture_approximate_bytes_used(MoonbitSkiaPicture* picture) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  if (picture == nullptr || picture->picture == nullptr) {
    return 0;
  }
  return static_cast<int64_t>(picture->picture->approximateBytesUsed());
#else
  (void)picture;
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_picture_unique_id(MoonbitSkiaPicture* picture) {
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  if (picture == nullptr || picture->picture == nullptr) {
    return 0;
  }
  return static_cast<int32_t>(picture->picture->uniqueID());
#else
  (void)picture;
  return 0;
#endif
}
