#include "skia_stub_common.h"

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_data_is_null(MoonbitSkiaData* wrapper) {
  return wrapper == nullptr || wrapper->data == nullptr;
}



extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_bitmap_is_null(MoonbitSkiaBitmap* wrapper) {
  return wrapper == nullptr || wrapper->bitmap == nullptr;
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

