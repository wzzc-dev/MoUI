#include "skia_stub_common.h"

#ifndef __has_include
#define __has_include(x) 0
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(__APPLE__) && \
  __has_include("include/gpu/ganesh/GrDirectContext.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlBackendContext.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlDirectContext.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlTypes.h") && \
  __has_include("include/gpu/ganesh/SkSurfaceGanesh.h")
#define MOUI_SKIA_HAS_GANESH_METAL_HEADERS 1
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(_WIN32) && \
  __has_include("include/gpu/ganesh/GrDirectContext.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DBackendContext.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DDirectContext.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DTypes.h") && \
  __has_include("include/gpu/ganesh/GrBackendRenderTarget.h") && \
  __has_include("include/gpu/ganesh/SkSurfaceGanesh.h")
#define MOUI_SKIA_HAS_GANESH_D3D_HEADERS 1
#endif

#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && \
  defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
#include "include/gpu/ganesh/mtl/GrMtlBackendContext.h"
#include "include/gpu/ganesh/mtl/GrMtlDirectContext.h"
#include "include/gpu/ganesh/mtl/GrMtlTypes.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include <objc/message.h>
#include <objc/runtime.h>

extern "C" void* MTLCreateSystemDefaultDevice(void);

void moonbit_skia_objc_release(void* object) {
  if (object == nullptr) {
    return;
  }
  using ObjcSendVoidNoArg = void (*)(void*, SEL);
  reinterpret_cast<ObjcSendVoidNoArg>(objc_msgSend)(
    object,
    sel_registerName("release")
  );
}

static GrDirectContext* moonbit_skia_make_metal_direct_context(void) {
  void* device = MTLCreateSystemDefaultDevice();
  if (device == nullptr) {
    return nullptr;
  }
  using ObjcSendNoArg = void* (*)(void*, SEL);
  void* queue = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    device,
    sel_registerName("newCommandQueue")
  );
  if (queue == nullptr) {
    moonbit_skia_objc_release(device);
    return nullptr;
  }

  GrMtlBackendContext backend_context;
  backend_context.fDevice.retain(static_cast<GrMTLHandle>(device));
  backend_context.fQueue.retain(static_cast<GrMTLHandle>(queue));
  sk_sp<GrDirectContext> context = GrDirectContexts::MakeMetal(backend_context);

  moonbit_skia_objc_release(queue);
  moonbit_skia_objc_release(device);

  return context.release();
}
#elif defined(__APPLE__)
#include <objc/message.h>
#include <objc/runtime.h>

void moonbit_skia_objc_release(void* object) {
  if (object == nullptr) {
    return;
  }
  using ObjcSendVoidNoArg = void (*)(void*, SEL);
  reinterpret_cast<ObjcSendVoidNoArg>(objc_msgSend)(
    object,
    sel_registerName("release")
  );
}
#endif

#if defined(MOUI_SKIA_ENABLE_GPU_D3D) && \
  defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
#include "include/gpu/ganesh/d3d/GrD3DBackendContext.h"
#include "include/gpu/ganesh/d3d/GrD3DDirectContext.h"
#include "include/gpu/ganesh/d3d/GrD3DTypes.h"
#include "include/gpu/ganesh/GrBackendRenderTarget.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"

#include <d3d11.h>
#include <dxgi.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;

void moonbit_skia_com_release(void* object) {
  if (object == nullptr) {
    return;
  }
  static_cast<IUnknown*>(object)->Release();
}

static GrDirectContext* moonbit_skia_make_d3d_direct_context(void) {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> immediate_context;
  D3D_FEATURE_LEVEL feature_level;
  HRESULT hr = D3D11CreateDevice(
    nullptr,
    D3D_DRIVER_TYPE_HARDWARE,
    nullptr,
    0,
    nullptr,
    0,
    D3D11_SDK_VERSION,
    &device,
    &feature_level,
    &immediate_context
  );
  if (FAILED(hr)) {
    return nullptr;
  }

  ComPtr<IDXGIDevice> dxgi_device;
  hr = device.As(&dxgi_device);
  if (FAILED(hr)) {
    return nullptr;
  }

  ComPtr<IDXGIAdapter> base_adapter;
  hr = dxgi_device->GetAdapter(&base_adapter);
  if (FAILED(hr)) {
    return nullptr;
  }

  ComPtr<IDXGIAdapter1> adapter;
  hr = base_adapter.As(&adapter);
  if (FAILED(hr)) {
    return nullptr;
  }

  GrD3DBackendContext backend_context;
  backend_context.fDevice = device;
  backend_context.fQueue = immediate_context;
  backend_context.fAdapter = adapter;

  sk_sp<GrDirectContext> context = GrDirectContexts::MakeDirect3D(
    backend_context
  );
  return context.release();
}
#elif defined(_WIN32)
void moonbit_skia_com_release(void* object) { (void)object; }
#endif

static const int32_t MOONBIT_SKIA_GPU_BACKEND_METAL = 1;
static const int32_t MOONBIT_SKIA_GPU_BACKEND_D3D = 2;

static MoonbitSkiaSurface* moonbit_skia_surface_wrapper_with_gpu_context(
#if defined(MOUI_SKIA_HAS_SKIA)
  SkSurface* surface,
  GrDirectContext* gpu_context_owner
#else
  void* surface,
  void* gpu_context_owner
#endif
) {
  MoonbitSkiaSurface* wrapper = moonbit_skia_make_surface_wrapper(surface);
  wrapper->gpu_context_owner = gpu_context_owner;
#if defined(MOUI_SKIA_HAS_GANESH_DIRECT_CONTEXT)
  if (wrapper->gpu_context_owner != nullptr) {
    wrapper->gpu_context_owner->ref();
  }
#endif
  return wrapper;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_metal_opt_in_enabled(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && defined(__APPLE__)
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_metal_headers_available(void) {
#if defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_metal_runtime_available(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && \
  defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
  GrDirectContext* context = moonbit_skia_make_metal_direct_context();
  if (context == nullptr) {
    return 0;
  }
  context->unref();
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_gpu_context_is_null(MoonbitSkiaGpuContext* wrapper) {
  return wrapper == nullptr || wrapper->context == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaGpuContext*
moonbit_skia_gpu_context_metal(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && \
  defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
  GrDirectContext* context = moonbit_skia_make_metal_direct_context();
  if (context == nullptr) {
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }
  return moonbit_skia_make_gpu_context_wrapper(
    context,
    nullptr,
    nullptr,
    MOONBIT_SKIA_GPU_BACKEND_METAL
  );
#else
  return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_d3d_opt_in_enabled(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_D3D) && defined(_WIN32)
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_d3d_headers_available(void) {
#if defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_d3d_runtime_available(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_D3D) && \
  defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
  GrDirectContext* context = moonbit_skia_make_d3d_direct_context();
  if (context == nullptr) {
    return 0;
  }
  context->unref();
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaGpuContext*
moonbit_skia_gpu_context_direct3d(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_D3D) && \
  defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> immediate_context;
  D3D_FEATURE_LEVEL feature_level;
  HRESULT hr = D3D11CreateDevice(
    nullptr,
    D3D_DRIVER_TYPE_HARDWARE,
    nullptr,
    0,
    nullptr,
    0,
    D3D11_SDK_VERSION,
    &device,
    &feature_level,
    &immediate_context
  );
  if (FAILED(hr)) {
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }

  ComPtr<IDXGIDevice> dxgi_device;
  hr = device.As(&dxgi_device);
  if (FAILED(hr)) {
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }

  ComPtr<IDXGIAdapter> base_adapter;
  hr = dxgi_device->GetAdapter(&base_adapter);
  if (FAILED(hr)) {
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }

  ComPtr<IDXGIAdapter1> adapter;
  hr = base_adapter.As(&adapter);
  if (FAILED(hr)) {
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }

  // Store a device reference before the ComPtr is moved into the backend
  // context. The caller (MoonbitSkiaGpuContext.device) owns this reference and
  // releases it via moonbit_skia_com_release in the finalizer.
  ID3D11Device* device_ptr = device.Get();
  device_ptr->AddRef();

  GrD3DBackendContext backend_context;
  backend_context.fDevice = device;
  backend_context.fQueue = immediate_context;
  backend_context.fAdapter = adapter;

  sk_sp<GrDirectContext> context = GrDirectContexts::MakeDirect3D(
    backend_context
  );
  if (!context) {
    device_ptr->Release();
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }

  return moonbit_skia_make_gpu_context_wrapper(
    context.release(),
    device_ptr,
    nullptr,
    MOONBIT_SKIA_GPU_BACKEND_D3D
  );
#else
  return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
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

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaBitmap*
moonbit_skia_bitmap_alloc_n32_premul(int32_t width, int32_t height) {
  if (width <= 0 || height <= 0) {
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
  return static_cast<int32_t>(wrapper->bitmap->computeByteSize());
#else
  return 0;
#endif
}



extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaBitmap*
moonbit_skia_bitmap_from_pixels(
  moonbit_bytes_t pixels,
  int32_t width,
  int32_t height,
  int32_t row_bytes
) {
  if (pixels == nullptr || width <= 0 || height <= 0 || row_bytes <= 0) {
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  SkBitmap* bitmap = new SkBitmap();
  if (!bitmap->tryAllocPixels(moonbit_skia_make_rgba8888_premul_info(width, height))) {
    delete bitmap;
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }

  // Copy pixel data into bitmap
  void* dst = bitmap->getPixels();
  if (dst == nullptr) {
    delete bitmap;
    return moonbit_skia_make_bitmap_wrapper(nullptr);
  }

  // Row-by-row copy to handle different row_bytes
  for (int y = 0; y < height; y++) {
    const uint8_t* src_row = static_cast<const uint8_t*>(static_cast<void*>(pixels)) + y * row_bytes;
    uint8_t* dst_row = static_cast<uint8_t*>(dst) + y * bitmap->rowBytes();
    size_t copy_size = std::min(static_cast<size_t>(row_bytes),
                                 static_cast<size_t>(width * 4));
    memcpy(dst_row, src_row, copy_size);
  }

  return moonbit_skia_make_bitmap_wrapper(bitmap);
#else
  (void)pixels;
  (void)width;
  (void)height;
  (void)row_bytes;
  return moonbit_skia_make_bitmap_wrapper(nullptr);
#endif
}



extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_bitmap_erase_color(MoonbitSkiaBitmap* wrapper, uint32_t color_argb) {
  if (wrapper == nullptr || wrapper->bitmap == nullptr) {
    return;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_WEBP_ENCODER)
    SkWebpEncoder::Options options;
    if (quality < 0) {
      quality = 0;
    } else if (quality > 100) {
      quality = 100;
    }
    options.fQuality = static_cast<float>(quality);
    data = SkWebpEncoder::Encode(nullptr, wrapper->image, options);
#else
    data = nullptr;
#endif
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
#if defined(MOUI_SKIA_HAS_SKIA)
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

#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && \
  defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
static GrSurfaceOrigin moonbit_skia_surface_origin(int32_t origin) {
  return origin == 1 ? kBottomLeft_GrSurfaceOrigin : kTopLeft_GrSurfaceOrigin;
}
#endif

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_gpu_n32_premul(
  MoonbitSkiaGpuContext* context,
  int32_t width,
  int32_t height,
  int32_t origin,
  int32_t sample_count,
  int32_t stencil_bits,
  int32_t budgeted
) {
  if (
    width <= 0 ||
    height <= 0 ||
    context == nullptr ||
    context->context == nullptr ||
    context->backend != MOONBIT_SKIA_GPU_BACKEND_METAL
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && \
  defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
  SkImageInfo info = moonbit_skia_make_rgba8888_premul_info(width, height);
  sk_sp<SkSurface> surface = SkSurfaces::RenderTarget(
    context->context,
    budgeted ? skgpu::Budgeted::kYes : skgpu::Budgeted::kNo,
    info,
    std::max(1, sample_count),
    moonbit_skia_surface_origin(origin),
    nullptr,
    false
  );
  (void)stencil_bits;
  if (!surface) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  return moonbit_skia_surface_wrapper_with_gpu_context(
    surface.release(),
    context->context
  );
#else
  (void)width;
  (void)height;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  (void)budgeted;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_metal_window(
  MoonbitSkiaGpuContext* context,
  uint64_t layer_ptr,
  int32_t width,
  int32_t height,
  int32_t origin,
  int32_t sample_count,
  int32_t stencil_bits
) {
  if (
    width <= 0 ||
    height <= 0 ||
    layer_ptr == 0 ||
    context == nullptr ||
    context->context == nullptr ||
    context->backend != MOONBIT_SKIA_GPU_BACKEND_METAL
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && \
  defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
  (void)sample_count;
  (void)stencil_bits;

  void* layer = reinterpret_cast<void*>(static_cast<uintptr_t>(layer_ptr));

  // [CAMetalLayer nextDrawable] → id<CAMetalDrawable>
  using ObjcSendNoArg = void* (*)(void*, SEL);
  void* drawable = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    layer,
    sel_registerName("nextDrawable")
  );
  if (drawable == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // [CAMetalDrawable texture] → id<MTLTexture>
  void* texture = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    drawable,
    sel_registerName("texture")
  );
  if (texture == nullptr) {
    moonbit_skia_objc_release(drawable);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Wrap the MTLTexture as an SkSurface via SkSurfaces::WrapMetalBackendSurface.
  // The drawable owns the texture; we retain the drawable in host_present_handle
  // so the texture stays alive for the lifetime of this surface.
  GrMtlTextureInfo texture_info;
  texture_info.fTexture = static_cast<GrMTLHandle>(texture);

  sk_sp<SkSurface> surface = SkSurfaces::WrapMetalBackendSurface(
    context->context,
    texture_info,
    moonbit_skia_surface_origin(origin),
    nullptr
  );
  if (!surface) {
    moonbit_skia_objc_release(drawable);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  MoonbitSkiaSurface* wrapper = moonbit_skia_surface_wrapper_with_gpu_context(
    surface.release(),
    context->context
  );
  wrapper->host_present_handle = drawable;
  return wrapper;
#else
  (void)layer_ptr;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_metal_present_and_acquire_next(
  MoonbitSkiaSurface* wrapper,
  uint64_t layer_ptr,
  int32_t width,
  int32_t height,
  int32_t origin,
  int32_t sample_count,
  int32_t stencil_bits
) {
  if (
    wrapper == nullptr ||
    wrapper->surface == nullptr ||
    wrapper->host_present_handle == nullptr ||
    wrapper->gpu_context_owner == nullptr ||
    layer_ptr == 0
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && \
  defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
  (void)width;
  (void)height;
  (void)sample_count;
  (void)stencil_bits;

  void* layer = reinterpret_cast<void*>(static_cast<uintptr_t>(layer_ptr));
  void* old_drawable = wrapper->host_present_handle;
  GrDirectContext* gpu_context = wrapper->gpu_context_owner;

  // The host renderer has already called flush_and_submit() on the surface.
  // Present the drawable so Core Animation displays the rendered content.
  using ObjcSendVoidNoArg = void (*)(void*, SEL);
  reinterpret_cast<ObjcSendVoidNoArg>(objc_msgSend)(
    old_drawable,
    sel_registerName("present")
  );

  // Release the old drawable and SkSurface; they are no longer needed.
  moonbit_skia_objc_release(old_drawable);
  wrapper->surface->unref();
  wrapper->surface = nullptr;
  wrapper->host_present_handle = nullptr;
  // gpu_context_owner is left for the finalizer to unref.

  // Acquire the next drawable for the following frame.
  using ObjcSendNoArg = void* (*)(void*, SEL);
  void* next_drawable = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    layer,
    sel_registerName("nextDrawable")
  );
  if (next_drawable == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  void* next_texture = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    next_drawable,
    sel_registerName("texture")
  );
  if (next_texture == nullptr) {
    moonbit_skia_objc_release(next_drawable);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  GrMtlTextureInfo texture_info;
  texture_info.fTexture = static_cast<GrMTLHandle>(next_texture);

  sk_sp<SkSurface> next_surface = SkSurfaces::WrapMetalBackendSurface(
    gpu_context,
    texture_info,
    moonbit_skia_surface_origin(origin),
    nullptr
  );
  if (!next_surface) {
    moonbit_skia_objc_release(next_drawable);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  MoonbitSkiaSurface* new_wrapper =
    moonbit_skia_surface_wrapper_with_gpu_context(
      next_surface.release(),
      gpu_context
    );
  new_wrapper->host_present_handle = next_drawable;
  return new_wrapper;
#else
  (void)layer_ptr;
  (void)width;
  (void)height;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_direct3d_window(
  MoonbitSkiaGpuContext* context,
  uint64_t hwnd_ptr,
  int32_t width,
  int32_t height,
  int32_t origin,
  int32_t sample_count,
  int32_t stencil_bits
) {
  if (
    width <= 0 ||
    height <= 0 ||
    hwnd_ptr == 0 ||
    context == nullptr ||
    context->context == nullptr ||
    context->backend != MOONBIT_SKIA_GPU_BACKEND_D3D
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
#if defined(MOUI_SKIA_ENABLE_GPU_D3D) && \
  defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
  (void)sample_count;
  (void)stencil_bits;

  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(hwnd_ptr));
  ID3D11Device* device = static_cast<ID3D11Device*>(context->device);
  if (device == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Get DXGI factory from the device
  ComPtr<IDXGIDevice> dxgi_device;
  HRESULT hr = device->QueryInterface(
    __uuidof(IDXGIDevice),
    reinterpret_cast<void**>(dxgi_device.GetAddressOf())
  );
  if (FAILED(hr)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  ComPtr<IDXGIAdapter> adapter;
  hr = dxgi_device->GetAdapter(&adapter);
  if (FAILED(hr)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  ComPtr<IDXGIFactory1> factory;
  hr = adapter->GetParent(
    __uuidof(IDXGIFactory1),
    reinterpret_cast<void**>(factory.GetAddressOf())
  );
  if (FAILED(hr)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Create swap chain targeting the HWND
  DXGI_SWAP_CHAIN_DESC desc;
  ZeroMemory(&desc, sizeof(desc));
  desc.BufferCount = 2;
  desc.BufferDesc.Width = width;
  desc.BufferDesc.Height = height;
  desc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  desc.BufferDesc.RefreshRate.Numerator = 60;
  desc.BufferDesc.RefreshRate.Denominator = 1;
  desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  desc.OutputWindow = hwnd;
  desc.SampleDesc.Count = 1;
  desc.SampleDesc.Quality = 0;
  desc.Windowed = TRUE;
  desc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

  ComPtr<IDXGISwapChain> swap_chain;
  hr = factory->CreateSwapChain(device, &desc, swap_chain.GetAddressOf());
  if (FAILED(hr)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Get the back buffer texture
  ComPtr<ID3D11Texture2D> back_buffer;
  hr = swap_chain->GetBuffer(
    0,
    __uuidof(ID3D11Texture2D),
    reinterpret_cast<void**>(back_buffer.GetAddressOf())
  );
  if (FAILED(hr)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Wrap the back buffer as a GrBackendRenderTarget
  GrD3DTextureResourceInfo resource_info;
  resource_info.fTexture = back_buffer;
  resource_info.fFormat = DXGI_FORMAT_R8G8B8A8_UNORM;

  GrBackendRenderTarget backend_rt = GrBackendRenderTargets::MakeDirect3D(
    width,
    height,
    resource_info
  );

  sk_sp<SkSurface> surface = SkSurfaces::WrapBackendSurface(
    context->context,
    backend_rt,
    moonbit_skia_surface_origin(origin),
    nullptr,
    nullptr
  );
  if (!surface) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  MoonbitSkiaSurface* wrapper = moonbit_skia_surface_wrapper_with_gpu_context(
    surface.release(),
    context->context
  );
  // The swap chain is stored as host_present_handle and released in the
  // finalizer via moonbit_skia_com_release.
  wrapper->host_present_handle = swap_chain.Detach();
  return wrapper;
#else
  (void)hwnd_ptr;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_direct3d_present_and_acquire_next(
  MoonbitSkiaSurface* wrapper,
  uint64_t hwnd_ptr,
  int32_t width,
  int32_t height,
  int32_t origin,
  int32_t sample_count,
  int32_t stencil_bits
) {
  if (
    wrapper == nullptr ||
    wrapper->surface == nullptr ||
    wrapper->host_present_handle == nullptr ||
    wrapper->gpu_context_owner == nullptr
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
#if defined(MOUI_SKIA_ENABLE_GPU_D3D) && \
  defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
  (void)hwnd_ptr;
  (void)sample_count;
  (void)stencil_bits;

  IDXGISwapChain* swap_chain = static_cast<IDXGISwapChain*>(
    wrapper->host_present_handle
  );
  GrDirectContext* gpu_context = wrapper->gpu_context_owner;

  // Present the rendered frame (vsync on)
  HRESULT hr = swap_chain->Present(1, 0);
  if (FAILED(hr)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  // Release the old surface; the swap chain is moved to the new wrapper.
  wrapper->surface->unref();
  wrapper->surface = nullptr;
  wrapper->host_present_handle = nullptr;

  // Acquire the next back buffer
  ComPtr<ID3D11Texture2D> back_buffer;
  hr = swap_chain->GetBuffer(
    0,
    __uuidof(ID3D11Texture2D),
    reinterpret_cast<void**>(back_buffer.GetAddressOf())
  );
  if (FAILED(hr)) {
    swap_chain->Release();
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  GrD3DTextureResourceInfo resource_info;
  resource_info.fTexture = back_buffer;
  resource_info.fFormat = DXGI_FORMAT_R8G8B8A8_UNORM;

  GrBackendRenderTarget backend_rt = GrBackendRenderTargets::MakeDirect3D(
    width,
    height,
    resource_info
  );

  sk_sp<SkSurface> next_surface = SkSurfaces::WrapBackendSurface(
    gpu_context,
    backend_rt,
    moonbit_skia_surface_origin(origin),
    nullptr,
    nullptr
  );
  if (!next_surface) {
    swap_chain->Release();
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  MoonbitSkiaSurface* new_wrapper =
    moonbit_skia_surface_wrapper_with_gpu_context(
      next_surface.release(),
      gpu_context
    );
  new_wrapper->host_present_handle = swap_chain;
  return new_wrapper;
#else
  (void)hwnd_ptr;
  (void)width;
  (void)height;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_flush_and_submit(MoonbitSkiaSurface* wrapper) {
  if (wrapper == nullptr || wrapper->surface == nullptr) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  if (wrapper->gpu_context_owner == nullptr) {
    return wrapper->surface->recordingContext() == nullptr;
  }
#if (defined(MOUI_SKIA_ENABLE_GPU_METAL) || defined(MOUI_SKIA_ENABLE_GPU_D3D)) && \
  defined(MOUI_SKIA_HAS_GANESH_DIRECT_CONTEXT)
  wrapper->gpu_context_owner->flushAndSubmit(wrapper->surface);
  return 1;
#else
  return 0;
#endif
#else
  return 0;
#endif
}



extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaImage*
moonbit_skia_surface_image_snapshot(MoonbitSkiaSurface* wrapper) {
  if (wrapper == nullptr || wrapper->surface == nullptr) {
    return moonbit_skia_make_image_wrapper(nullptr);
  }
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
  SkImageInfo info = moonbit_skia_make_rgba8888_premul_info(width, height);
  bool ok = wrapper->surface->readPixels(
    info,
    bytes,
    static_cast<size_t>(row_bytes),
    left,
    top
  );
  if (!ok) {
    return moonbit_make_bytes(0, 0);
  }
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
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
#if defined(MOUI_SKIA_HAS_SKIA)
  return moonbit_skia_make_canvas_wrapper(
    wrapper->surface->getCanvas(),
    wrapper->surface
  );
#else
  return moonbit_skia_make_canvas_wrapper(nullptr, nullptr);
#endif
}
