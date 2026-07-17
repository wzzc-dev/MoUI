#include "skia_stub_common.h"

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <new>
#include <thread>

#ifndef __has_include
#define __has_include(x) 0
#endif

#if defined(__ANDROID__) && defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  !defined(VK_NO_PROTOTYPES)
#define VK_NO_PROTOTYPES
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE) && \
  defined(MOUI_SKIA_ENABLE_GPU_EGL) && \
  (defined(__ANDROID__) || defined(__OHOS__)) && \
  __has_include("include/gpu/ganesh/gl/GrGLBackendContext.h") && \
  __has_include("include/gpu/ganesh/gl/GrGLDirectContext.h") && \
  __has_include("include/gpu/ganesh/GrBackendSurface.h") && \
  __has_include("include/gpu/ganesh/SkSurfaceGanesh.h") && \
  __has_include(<EGL/egl.h>) && __has_include(<GLES3/gl3.h>)
#if defined(__ANDROID__) && __has_include(<android/native_window.h>)
#define MOUI_SKIA_NATIVE_GPU_WORKER_EGL 1
#elif defined(__OHOS__) && __has_include(<native_window/external_window.h>)
#define MOUI_SKIA_NATIVE_GPU_WORKER_EGL 1
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
#include "include/gpu/ganesh/gl/GrGLBackendContext.h"
#include "include/gpu/ganesh/gl/GrGLDirectContext.h"
#include "include/gpu/ganesh/gl/GrGLTypes.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#if defined(__OHOS__)
#include <native_buffer/native_buffer.h>
#include <native_window/external_window.h>
using NativeGpuEglWindow = OHNativeWindow;
#else
#include <android/native_window.h>
using NativeGpuEglWindow = ANativeWindow;
#endif
#endif
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE) && \
  defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  (defined(__ANDROID__) || defined(__linux__)) && \
  __has_include("include/gpu/ganesh/vk/GrVkBackendSurface.h") && \
  __has_include("include/gpu/ganesh/vk/GrVkDirectContext.h") && \
  __has_include("include/gpu/vk/VulkanBackendContext.h") && \
  __has_include("include/android/vk/AndroidVulkanMemoryAllocator.h") && \
  __has_include(<vulkan/vulkan.h>)
#if defined(__ANDROID__) && __has_include(<vulkan/vulkan_android.h>) && \
  __has_include(<android/native_window.h>)
#define MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN 1
#elif defined(__linux__) && __has_include(<vulkan/vulkan_wayland.h>) && \
  __has_include(<wayland-client.h>)
#define MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN 1
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
#include "include/gpu/ganesh/vk/GrVkBackendSurface.h"
#include "include/gpu/ganesh/vk/GrVkDirectContext.h"
#include "include/gpu/ganesh/vk/GrVkTypes.h"
#include "include/gpu/vk/VulkanBackendContext.h"
#include "include/android/vk/AndroidVulkanMemoryAllocator.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include <vulkan/vulkan.h>
#if defined(__ANDROID__)
#include <android/log.h>
#include <android/native_window.h>
#include <vulkan/vulkan_android.h>
#include "android_vulkan_loader.h"
#else
#include <vulkan/vulkan_wayland.h>
#include <wayland-client.h>
#endif
#endif
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE) && \
  defined(MOUI_SKIA_ENABLE_GPU_D3D) && defined(_WIN32) && \
  __has_include("include/gpu/ganesh/d3d/GrD3DBackendContext.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DBackendSurface.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DDirectContext.h") && \
  __has_include("include/gpu/ganesh/GrBackendSurface.h") && \
  __has_include("include/gpu/ganesh/SkSurfaceGanesh.h")
#define MOUI_SKIA_NATIVE_GPU_WORKER_D3D12 1
#include "include/gpu/ganesh/d3d/GrD3DBackendContext.h"
#include "include/gpu/ganesh/d3d/GrD3DBackendSurface.h"
#include "include/gpu/ganesh/d3d/GrD3DDirectContext.h"
#include "include/gpu/ganesh/d3d/GrD3DTypes.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include <d3d12.h>
#include <dxgi1_4.h>
#include <windows.h>
#include <wrl/client.h>
using Microsoft::WRL::ComPtr;
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE) && \
  defined(MOUI_SKIA_ENABLE_GPU_METAL) && defined(__APPLE__) && \
  __has_include("include/gpu/ganesh/mtl/GrMtlBackendContext.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlBackendSurface.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlDirectContext.h") && \
  __has_include("include/gpu/ganesh/GrBackendSurface.h") && \
  __has_include("include/gpu/ganesh/SkSurfaceGanesh.h")
#define MOUI_SKIA_NATIVE_GPU_WORKER_METAL 1
#include "include/gpu/ganesh/mtl/GrMtlBackendContext.h"
#include "include/gpu/ganesh/mtl/GrMtlBackendSurface.h"
#include "include/gpu/ganesh/mtl/GrMtlDirectContext.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include <objc/message.h>
#include <objc/runtime.h>
extern "C" void* MTLCreateSystemDefaultDevice(void);
#endif

namespace {

// Use unscoped enums so switch cases stay portable under older Apple Clang
// mobile toolchains and mixed ObjC++/C++ response-file flag sets.
enum NativeGpuControlKind {
  NativeGpuControlKind_Attach = 1,
  NativeGpuControlKind_Resize = 2,
  NativeGpuControlKind_Detach = 3,
  NativeGpuControlKind_ContextLoss = 4,
  NativeGpuControlKind_Shutdown = 5,
};

enum NativeGpuCompletionStatus {
  NativeGpuCompletionStatus_PictureRecorded = 1,
  NativeGpuCompletionStatus_Dropped = 2,
  NativeGpuCompletionStatus_ControlAcknowledged = 3,
  NativeGpuCompletionStatus_FallbackToRaster = 4,
  NativeGpuCompletionStatus_Presented = 5,
};

struct NativeGpuFrame {
  int64_t sequence = 0;
  int32_t surface_generation = 1;
  int64_t image_resource_revision = 0;
  double submitted_at_ms = 0.0;
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  sk_sp<SkPicture> picture;
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
  GrDirectContext* egl_context = nullptr;
  EGLDisplay egl_display = EGL_NO_DISPLAY;
  EGLContext egl_native_context = EGL_NO_CONTEXT;
  EGLConfig egl_config = nullptr;
  EGLSurface egl_bootstrap_surface = EGL_NO_SURFACE;
  EGLSurface egl_window_surface = EGL_NO_SURFACE;
  NativeGpuEglWindow* egl_native_window = nullptr;
#endif
};

struct NativeGpuControl {
  NativeGpuControlKind kind = NativeGpuControlKind_Resize;
  int64_t token = 0;
  uint64_t handle = 0;
  uint64_t auxiliary_handle = 0;
  int32_t width = 0;
  int32_t height = 0;
};

struct NativeGpuCompletion {
  int64_t sequence = 0;
  int64_t control_token = 0;
  int32_t surface_generation = 1;
  int32_t context_generation = 1;
  int64_t image_resource_revision = 0;
  double submitted_at_ms = 0.0;
  double gpu_completed_at_ms = 0.0;
  double presented_at_ms = 0.0;
  NativeGpuCompletionStatus status = NativeGpuCompletionStatus_PictureRecorded;
};

double native_gpu_now_ms() {
  const auto now = std::chrono::steady_clock::now().time_since_epoch();
  return std::chrono::duration<double, std::milli>(now).count();
}

void queue_completion(
  MoonbitSkiaNativeGpuWorker* worker,
  NativeGpuCompletion completion
);

}  // namespace

struct MoonbitSkiaNativeGpuWorker {
  std::mutex mutex;
  std::condition_variable wake;
  std::thread thread;
  std::deque<NativeGpuControl> controls;
  std::deque<NativeGpuCompletion> completions;
  std::unique_ptr<NativeGpuFrame> pending;
  bool shutdown_requested = false;
  bool joined = false;
  int64_t next_sequence = 1;
  int64_t next_control_token = 1;
  int32_t surface_generation = 1;
  int32_t context_generation = 1;
  int32_t consecutive_recovery_failures = 0;
  int64_t recovery_count = 0;
  int64_t resource_cache_bytes = 0;
  int64_t submitted = 0;
  int64_t completed = 0;
  int64_t dropped = 0;
  int64_t replaced_pending = 0;
  int64_t worker_thread_id = 0;
  uint64_t attached_handle = 0;
  uint64_t attached_auxiliary_handle = 0;
  int32_t width = 0;
  int32_t height = 0;
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
  GrDirectContext* metal_context = nullptr;
  void* metal_device = nullptr;
  void* metal_queue = nullptr;
  void* metal_layer = nullptr;
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
  GrDirectContext* d3d_context = nullptr;
  ComPtr<IDXGIAdapter1> d3d_adapter;
  ComPtr<ID3D12Device> d3d_device;
  ComPtr<ID3D12CommandQueue> d3d_queue;
  ComPtr<IDXGISwapChain3> d3d_swap_chain;
  ComPtr<ID3D12Fence> d3d_fence;
  HANDLE d3d_fence_event = nullptr;
  uint64_t d3d_fence_value = 0;
  UINT d3d_frame_index = 0;
  UINT d3d_swap_chain_width = 0;
  UINT d3d_swap_chain_height = 0;
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
  GrDirectContext* vulkan_context = nullptr;
  VkInstance vulkan_instance = VK_NULL_HANDLE;
  VkPhysicalDevice vulkan_physical_device = VK_NULL_HANDLE;
  VkDevice vulkan_device = VK_NULL_HANDLE;
  VkQueue vulkan_queue = VK_NULL_HANDLE;
  uint32_t vulkan_queue_family = 0;
  VkSurfaceKHR vulkan_surface = VK_NULL_HANDLE;
  VkSwapchainKHR vulkan_swap_chain = VK_NULL_HANDLE;
  VkFormat vulkan_format = VK_FORMAT_UNDEFINED;
  VkColorSpaceKHR vulkan_color_space = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
  VkImageUsageFlags vulkan_image_usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  VkExtent2D vulkan_extent = { 0, 0 };
  std::vector<VkImage> vulkan_images;
  std::vector<VkImageLayout> vulkan_image_layouts;
  std::vector<VkFence> vulkan_image_fences;
  std::vector<VkSemaphore> vulkan_render_finished;
  VkFence vulkan_acquire_fence = VK_NULL_HANDLE;
#if defined(__ANDROID__)
  ANativeWindow* android_native_window = nullptr;
#endif
#endif
};

namespace {

#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
class NativeGpuAutoreleasePool {
 public:
  NativeGpuAutoreleasePool() {
    using ObjcSendNoArg = void* (*)(void*, SEL);
    void* pool_class = reinterpret_cast<void*>(objc_getClass("NSAutoreleasePool"));
    void* allocated = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
      pool_class,
      sel_registerName("alloc")
    );
    pool_ = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
      allocated,
      sel_registerName("init")
    );
  }

  ~NativeGpuAutoreleasePool() {
    if (pool_ != nullptr) {
      using ObjcSendVoidNoArg = void (*)(void*, SEL);
      reinterpret_cast<ObjcSendVoidNoArg>(objc_msgSend)(
        pool_,
        sel_registerName("drain")
      );
    }
  }

 private:
  void* pool_ = nullptr;
};

void release_metal_context(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->metal_context != nullptr) {
    worker->metal_context->unref();
    worker->metal_context = nullptr;
  }
  if (worker->metal_queue != nullptr) {
    moonbit_skia_objc_release(worker->metal_queue);
    worker->metal_queue = nullptr;
  }
  if (worker->metal_device != nullptr) {
    moonbit_skia_objc_release(worker->metal_device);
    worker->metal_device = nullptr;
  }
}

void release_metal_layer(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->metal_layer != nullptr) {
    moonbit_skia_objc_release(worker->metal_layer);
    worker->metal_layer = nullptr;
  }
}

bool ensure_metal_context(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->metal_context != nullptr && !worker->metal_context->abandoned()) {
    return true;
  }
  release_metal_context(worker);
  void* device = MTLCreateSystemDefaultDevice();
  if (device == nullptr) {
    return false;
  }
  using ObjcSendNoArg = void* (*)(void*, SEL);
  void* queue = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    device,
    sel_registerName("newCommandQueue")
  );
  if (queue == nullptr) {
    moonbit_skia_objc_release(device);
    return false;
  }
  GrMtlBackendContext backend_context;
  backend_context.fDevice.retain(static_cast<GrMTLHandle>(device));
  backend_context.fQueue.retain(static_cast<GrMTLHandle>(queue));
  sk_sp<GrDirectContext> context = GrDirectContexts::MakeMetal(backend_context);
  if (!context) {
    moonbit_skia_objc_release(queue);
    moonbit_skia_objc_release(device);
    return false;
  }
  worker->metal_device = device;
  worker->metal_queue = queue;
  worker->metal_context = context.release();
  {
    std::lock_guard<std::mutex> lock(worker->mutex);
    worker->context_generation += 1;
  }
  return true;
}

bool render_metal_picture(
  MoonbitSkiaNativeGpuWorker* worker,
  const sk_sp<SkPicture>& picture
) {
  if (
    worker->metal_layer == nullptr ||
    worker->width <= 0 ||
    worker->height <= 0 ||
    !picture ||
    !ensure_metal_context(worker)
  ) {
    return false;
  }
  NativeGpuAutoreleasePool pool;
  using ObjcSendNoArg = void* (*)(void*, SEL);
  using ObjcSendSetObject = void (*)(void*, SEL, void*);
  reinterpret_cast<ObjcSendSetObject>(objc_msgSend)(
    worker->metal_layer,
    sel_registerName("setDevice:"),
    worker->metal_device
  );
  void* drawable = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    worker->metal_layer,
    sel_registerName("nextDrawable")
  );
  if (drawable == nullptr) {
    return false;
  }
  moonbit_skia_objc_retain(drawable);
  void* texture = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    drawable,
    sel_registerName("texture")
  );
  if (texture == nullptr) {
    moonbit_skia_objc_release(drawable);
    return false;
  }
  GrMtlTextureInfo texture_info;
  texture_info.fTexture.retain(static_cast<GrMTLHandle>(texture));
  GrBackendRenderTarget render_target = GrBackendRenderTargets::MakeMtl(
    worker->width,
    worker->height,
    texture_info
  );
  sk_sp<SkSurface> surface = SkSurfaces::WrapBackendRenderTarget(
    worker->metal_context,
    render_target,
    kTopLeft_GrSurfaceOrigin,
    kBGRA_8888_SkColorType,
    nullptr,
    nullptr
  );
  if (!surface) {
    moonbit_skia_objc_release(drawable);
    return false;
  }
  SkCanvas* canvas = surface->getCanvas();
  if (canvas == nullptr) {
    moonbit_skia_objc_release(drawable);
    return false;
  }
  canvas->drawPicture(picture);
  worker->metal_context->flushAndSubmit(surface.get(), GrSyncCpu::kNo);
  if (worker->metal_context->abandoned()) {
    moonbit_skia_objc_release(drawable);
    return false;
  }
  using ObjcSendVoidNoArg = void (*)(void*, SEL);
  reinterpret_cast<ObjcSendVoidNoArg>(objc_msgSend)(
    drawable,
    sel_registerName("present")
  );
  moonbit_skia_objc_release(drawable);
  return true;
}
#endif

#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
bool wait_for_d3d_gpu(MoonbitSkiaNativeGpuWorker* worker) {
  if (
    worker->d3d_queue == nullptr ||
    worker->d3d_fence == nullptr ||
    worker->d3d_fence_event == nullptr
  ) {
    return false;
  }
  const uint64_t fence_value = ++worker->d3d_fence_value;
  if (FAILED(worker->d3d_queue->Signal(worker->d3d_fence.Get(), fence_value))) {
    return false;
  }
  if (worker->d3d_fence->GetCompletedValue() >= fence_value) {
    return true;
  }
  if (FAILED(worker->d3d_fence->SetEventOnCompletion(
    fence_value,
    worker->d3d_fence_event
  ))) {
    return false;
  }
  return WaitForSingleObject(worker->d3d_fence_event, INFINITE) == WAIT_OBJECT_0;
}

void release_d3d_swap_chain(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->d3d_queue != nullptr && worker->d3d_fence != nullptr) {
    (void)wait_for_d3d_gpu(worker);
  }
  worker->d3d_swap_chain.Reset();
  worker->d3d_fence.Reset();
  if (worker->d3d_fence_event != nullptr) {
    CloseHandle(worker->d3d_fence_event);
    worker->d3d_fence_event = nullptr;
  }
  worker->d3d_fence_value = 0;
  worker->d3d_frame_index = 0;
  worker->d3d_swap_chain_width = 0;
  worker->d3d_swap_chain_height = 0;
}

void release_d3d_context(MoonbitSkiaNativeGpuWorker* worker) {
  release_d3d_swap_chain(worker);
  if (worker->d3d_context != nullptr) {
    worker->d3d_context->unref();
    worker->d3d_context = nullptr;
  }
  worker->d3d_queue.Reset();
  worker->d3d_device.Reset();
  worker->d3d_adapter.Reset();
}

bool ensure_d3d_context(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->d3d_context != nullptr && !worker->d3d_context->abandoned()) {
    return true;
  }
  release_d3d_context(worker);
  ComPtr<IDXGIFactory4> factory;
  if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) {
    return false;
  }
  for (UINT index = 0;; index += 1) {
    ComPtr<IDXGIAdapter1> candidate;
    const HRESULT enum_result = factory->EnumAdapters1(index, &candidate);
    if (enum_result == DXGI_ERROR_NOT_FOUND) {
      break;
    }
    DXGI_ADAPTER_DESC1 description = {};
    if (
      FAILED(enum_result) ||
      FAILED(candidate->GetDesc1(&description)) ||
      (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0
    ) {
      continue;
    }
    ComPtr<ID3D12Device> device;
    if (FAILED(D3D12CreateDevice(
      candidate.Get(),
      D3D_FEATURE_LEVEL_11_0,
      IID_PPV_ARGS(&device)
    ))) {
      continue;
    }
    worker->d3d_adapter = candidate;
    worker->d3d_device = device;
    break;
  }
  if (worker->d3d_device == nullptr) {
    return false;
  }
  D3D12_COMMAND_QUEUE_DESC queue_description = {};
  queue_description.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
  if (FAILED(worker->d3d_device->CreateCommandQueue(
    &queue_description,
    IID_PPV_ARGS(&worker->d3d_queue)
  ))) {
    release_d3d_context(worker);
    return false;
  }
  GrD3DBackendContext backend_context;
  backend_context.fAdapter.retain(worker->d3d_adapter.Get());
  backend_context.fDevice.retain(worker->d3d_device.Get());
  backend_context.fQueue.retain(worker->d3d_queue.Get());
  sk_sp<GrDirectContext> context = GrDirectContexts::MakeD3D(backend_context);
  if (!context) {
    release_d3d_context(worker);
    return false;
  }
  worker->d3d_context = context.release();
  {
    std::lock_guard<std::mutex> lock(worker->mutex);
    worker->context_generation += 1;
  }
  return true;
}

bool ensure_d3d_swap_chain(MoonbitSkiaNativeGpuWorker* worker) {
  if (
    worker->attached_handle == 0 ||
    worker->width <= 0 ||
    worker->height <= 0 ||
    !ensure_d3d_context(worker)
  ) {
    return false;
  }
  const UINT width = static_cast<UINT>(worker->width);
  const UINT height = static_cast<UINT>(worker->height);
  if (worker->d3d_swap_chain != nullptr) {
    if (
      worker->d3d_swap_chain_width == width &&
      worker->d3d_swap_chain_height == height
    ) {
      return true;
    }
    if (!wait_for_d3d_gpu(worker)) {
      return false;
    }
    worker->d3d_context->freeGpuResources();
    const HRESULT resize_result = worker->d3d_swap_chain->ResizeBuffers(
      3,
      width,
      height,
      DXGI_FORMAT_R8G8B8A8_UNORM,
      0
    );
    if (FAILED(resize_result)) {
      return false;
    }
    worker->d3d_swap_chain_width = width;
    worker->d3d_swap_chain_height = height;
    worker->d3d_frame_index = worker->d3d_swap_chain->GetCurrentBackBufferIndex();
    return true;
  }

  ComPtr<IDXGIFactory4> factory;
  if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) {
    return false;
  }
  DXGI_SWAP_CHAIN_DESC1 description = {};
  description.Width = width;
  description.Height = height;
  description.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  description.SampleDesc.Count = 1;
  description.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  description.BufferCount = 3;
  description.Scaling = DXGI_SCALING_STRETCH;
  description.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
  description.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
  ComPtr<IDXGISwapChain1> swap_chain;
  HWND hwnd = reinterpret_cast<HWND>(
    static_cast<uintptr_t>(worker->attached_handle)
  );
  if (FAILED(factory->CreateSwapChainForHwnd(
    worker->d3d_queue.Get(),
    hwnd,
    &description,
    nullptr,
    nullptr,
    &swap_chain
  ))) {
    return false;
  }
  (void)factory->MakeWindowAssociation(hwnd, DXGI_MWA_NO_ALT_ENTER);
  if (FAILED(swap_chain.As(&worker->d3d_swap_chain))) {
    return false;
  }
  if (FAILED(worker->d3d_device->CreateFence(
    0,
    D3D12_FENCE_FLAG_NONE,
    IID_PPV_ARGS(&worker->d3d_fence)
  ))) {
    release_d3d_swap_chain(worker);
    return false;
  }
  worker->d3d_fence_event = CreateEvent(nullptr, FALSE, FALSE, nullptr);
  if (worker->d3d_fence_event == nullptr) {
    release_d3d_swap_chain(worker);
    return false;
  }
  worker->d3d_swap_chain_width = width;
  worker->d3d_swap_chain_height = height;
  worker->d3d_frame_index = worker->d3d_swap_chain->GetCurrentBackBufferIndex();
  return true;
}

bool render_d3d_picture(
  MoonbitSkiaNativeGpuWorker* worker,
  const sk_sp<SkPicture>& picture
) {
  if (!picture || !ensure_d3d_swap_chain(worker)) {
    return false;
  }
  ComPtr<ID3D12Resource> back_buffer;
  if (FAILED(worker->d3d_swap_chain->GetBuffer(
    worker->d3d_frame_index,
    IID_PPV_ARGS(&back_buffer)
  ))) {
    return false;
  }
  GrD3DTextureResourceInfo resource_info;
  resource_info.fResource.retain(back_buffer.Get());
  resource_info.fResourceState = D3D12_RESOURCE_STATE_COMMON;
  resource_info.fFormat = DXGI_FORMAT_R8G8B8A8_UNORM;
  resource_info.fSampleCount = 1;
  GrBackendRenderTarget render_target = GrBackendRenderTargets::MakeD3D(
    worker->width,
    worker->height,
    resource_info
  );
  sk_sp<SkSurface> surface = SkSurfaces::WrapBackendRenderTarget(
    worker->d3d_context,
    render_target,
    kTopLeft_GrSurfaceOrigin,
    kRGBA_8888_SkColorType,
    nullptr,
    nullptr
  );
  if (!surface) {
    return false;
  }
  surface->getCanvas()->drawPicture(picture);
  GrFlushInfo flush_info;
  worker->d3d_context->flush(
    surface.get(),
    SkSurfaces::BackendSurfaceAccess::kPresent,
    flush_info
  );
  if (!worker->d3d_context->submit() || !wait_for_d3d_gpu(worker)) {
    return false;
  }
  const HRESULT present_result = worker->d3d_swap_chain->Present(1, 0);
  if (FAILED(present_result)) {
    (void)worker->d3d_device->GetDeviceRemovedReason();
    return false;
  }
  worker->d3d_frame_index = worker->d3d_swap_chain->GetCurrentBackBufferIndex();
  return true;
}
#endif

#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
SkColorType vulkan_color_type(VkFormat format) {
  return format == VK_FORMAT_B8G8R8A8_UNORM ||
    format == VK_FORMAT_B8G8R8A8_SRGB
    ? kBGRA_8888_SkColorType
    : kRGBA_8888_SkColorType;
}

void release_vulkan_swap_chain(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->vulkan_device != VK_NULL_HANDLE) {
    (void)vkDeviceWaitIdle(worker->vulkan_device);
    for (VkSemaphore semaphore : worker->vulkan_render_finished) {
      if (semaphore != VK_NULL_HANDLE) {
        vkDestroySemaphore(worker->vulkan_device, semaphore, nullptr);
      }
    }
    for (VkFence fence : worker->vulkan_image_fences) {
      if (fence != VK_NULL_HANDLE) {
        vkDestroyFence(worker->vulkan_device, fence, nullptr);
      }
    }
    if (worker->vulkan_acquire_fence != VK_NULL_HANDLE) {
      vkDestroyFence(worker->vulkan_device, worker->vulkan_acquire_fence, nullptr);
    }
    if (worker->vulkan_swap_chain != VK_NULL_HANDLE) {
      vkDestroySwapchainKHR(worker->vulkan_device, worker->vulkan_swap_chain, nullptr);
    }
  }
  worker->vulkan_render_finished.clear();
  worker->vulkan_image_fences.clear();
  worker->vulkan_image_layouts.clear();
  worker->vulkan_images.clear();
  worker->vulkan_acquire_fence = VK_NULL_HANDLE;
  worker->vulkan_swap_chain = VK_NULL_HANDLE;
  worker->vulkan_format = VK_FORMAT_UNDEFINED;
  worker->vulkan_image_usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  worker->vulkan_extent = { 0, 0 };
}

void release_vulkan_context(MoonbitSkiaNativeGpuWorker* worker) {
  release_vulkan_swap_chain(worker);
  if (worker->vulkan_context != nullptr) {
    worker->vulkan_context->unref();
    worker->vulkan_context = nullptr;
  }
  if (worker->vulkan_device != VK_NULL_HANDLE) {
    vkDestroyDevice(worker->vulkan_device, nullptr);
    worker->vulkan_device = VK_NULL_HANDLE;
  }
  if (
    worker->vulkan_instance != VK_NULL_HANDLE &&
    worker->vulkan_surface != VK_NULL_HANDLE
  ) {
    vkDestroySurfaceKHR(worker->vulkan_instance, worker->vulkan_surface, nullptr);
    worker->vulkan_surface = VK_NULL_HANDLE;
  }
  if (worker->vulkan_instance != VK_NULL_HANDLE) {
    vkDestroyInstance(worker->vulkan_instance, nullptr);
    worker->vulkan_instance = VK_NULL_HANDLE;
  }
  worker->vulkan_physical_device = VK_NULL_HANDLE;
  worker->vulkan_queue = VK_NULL_HANDLE;
  worker->vulkan_queue_family = 0;
}

void release_vulkan_attachment(MoonbitSkiaNativeGpuWorker* worker) {
  release_vulkan_context(worker);
#if defined(__ANDROID__)
  if (worker->android_native_window != nullptr) {
    ANativeWindow_release(worker->android_native_window);
    worker->android_native_window = nullptr;
  }
#endif
}

bool create_vulkan_surface(MoonbitSkiaNativeGpuWorker* worker) {
#if defined(__ANDROID__)
  if (worker->android_native_window == nullptr) {
    return false;
  }
  VkAndroidSurfaceCreateInfoKHR surface_info = {};
  surface_info.sType = VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR;
  surface_info.window = worker->android_native_window;
  return vkCreateAndroidSurfaceKHR(
    worker->vulkan_instance,
    &surface_info,
    nullptr,
    &worker->vulkan_surface
  ) == VK_SUCCESS;
#else
  if (worker->attached_handle == 0 || worker->attached_auxiliary_handle == 0) {
    return false;
  }
  VkWaylandSurfaceCreateInfoKHR surface_info = {};
  surface_info.sType = VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR;
  surface_info.display = reinterpret_cast<wl_display*>(
    static_cast<uintptr_t>(worker->attached_handle)
  );
  surface_info.surface = reinterpret_cast<wl_surface*>(
    static_cast<uintptr_t>(worker->attached_auxiliary_handle)
  );
  return vkCreateWaylandSurfaceKHR(
    worker->vulkan_instance,
    &surface_info,
    nullptr,
    &worker->vulkan_surface
  ) == VK_SUCCESS;
#endif
}

bool ensure_vulkan_context(MoonbitSkiaNativeGpuWorker* worker) {
  if (
    worker->vulkan_context != nullptr &&
    !worker->vulkan_context->abandoned() &&
    worker->vulkan_device != VK_NULL_HANDLE &&
    worker->vulkan_surface != VK_NULL_HANDLE
  ) {
    return true;
  }
#if defined(__ANDROID__)
  if (!moui_skia_android_vulkan_load()) {
    return false;
  }
#endif
  release_vulkan_context(worker);
  const char* instance_extensions[] = {
    VK_KHR_SURFACE_EXTENSION_NAME,
#if defined(__ANDROID__)
    VK_KHR_ANDROID_SURFACE_EXTENSION_NAME,
#else
    VK_KHR_WAYLAND_SURFACE_EXTENSION_NAME,
#endif
  };
  VkApplicationInfo app_info = {};
  app_info.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
  app_info.pApplicationName = "MoUI GPU worker";
  app_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
  app_info.pEngineName = "Skia";
  app_info.engineVersion = VK_MAKE_VERSION(1, 0, 0);
  app_info.apiVersion = VK_API_VERSION_1_1;
  VkInstanceCreateInfo instance_info = {};
  instance_info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  instance_info.pApplicationInfo = &app_info;
  instance_info.enabledExtensionCount = 2;
  instance_info.ppEnabledExtensionNames = instance_extensions;
  if (vkCreateInstance(
    &instance_info,
    nullptr,
    &worker->vulkan_instance
  ) != VK_SUCCESS) {
    release_vulkan_context(worker);
    return false;
  }
  if (!create_vulkan_surface(worker)) {
    release_vulkan_context(worker);
    return false;
  }

  uint32_t physical_device_count = 0;
  if (
    vkEnumeratePhysicalDevices(
      worker->vulkan_instance,
      &physical_device_count,
      nullptr
    ) != VK_SUCCESS ||
    physical_device_count == 0
  ) {
    release_vulkan_context(worker);
    return false;
  }
  std::vector<VkPhysicalDevice> physical_devices(physical_device_count);
  if (vkEnumeratePhysicalDevices(
    worker->vulkan_instance,
    &physical_device_count,
    physical_devices.data()
  ) != VK_SUCCESS) {
    release_vulkan_context(worker);
    return false;
  }
  bool found_queue = false;
  for (VkPhysicalDevice physical_device : physical_devices) {
    uint32_t queue_count = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_count, nullptr);
    std::vector<VkQueueFamilyProperties> queues(queue_count);
    vkGetPhysicalDeviceQueueFamilyProperties(
      physical_device,
      &queue_count,
      queues.data()
    );
    for (uint32_t index = 0; index < queue_count; index += 1) {
      VkBool32 present_supported = VK_FALSE;
      if (
        (queues[index].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0 &&
        vkGetPhysicalDeviceSurfaceSupportKHR(
          physical_device,
          index,
          worker->vulkan_surface,
          &present_supported
        ) == VK_SUCCESS &&
        present_supported == VK_TRUE
      ) {
        worker->vulkan_physical_device = physical_device;
        worker->vulkan_queue_family = index;
        found_queue = true;
        break;
      }
    }
    if (found_queue) {
      break;
    }
  }
  if (!found_queue) {
    release_vulkan_context(worker);
    return false;
  }

  const float queue_priority = 1.0f;
  VkDeviceQueueCreateInfo queue_info = {};
  queue_info.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  queue_info.queueFamilyIndex = worker->vulkan_queue_family;
  queue_info.queueCount = 1;
  queue_info.pQueuePriorities = &queue_priority;
  const char* device_extensions[] = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };
  VkDeviceCreateInfo device_info = {};
  device_info.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  device_info.queueCreateInfoCount = 1;
  device_info.pQueueCreateInfos = &queue_info;
  device_info.enabledExtensionCount = 1;
  device_info.ppEnabledExtensionNames = device_extensions;
  if (vkCreateDevice(
    worker->vulkan_physical_device,
    &device_info,
    nullptr,
    &worker->vulkan_device
  ) != VK_SUCCESS) {
    release_vulkan_context(worker);
    return false;
  }
  vkGetDeviceQueue(
    worker->vulkan_device,
    worker->vulkan_queue_family,
    0,
    &worker->vulkan_queue
  );

  skgpu::VulkanBackendContext backend_context;
  backend_context.fInstance = worker->vulkan_instance;
  backend_context.fPhysicalDevice = worker->vulkan_physical_device;
  backend_context.fDevice = worker->vulkan_device;
  backend_context.fQueue = worker->vulkan_queue;
  backend_context.fGraphicsQueueIndex = worker->vulkan_queue_family;
  backend_context.fMaxAPIVersion = VK_API_VERSION_1_1;
  backend_context.fGetProc = [](
    const char* name,
    VkInstance instance,
    VkDevice device
  ) -> PFN_vkVoidFunction {
    if (device != VK_NULL_HANDLE) {
      PFN_vkVoidFunction proc = vkGetDeviceProcAddr(device, name);
      if (proc != nullptr) {
        return proc;
      }
    }
    return vkGetInstanceProcAddr(instance, name);
  };
  backend_context.fMemoryAllocator = SkiaVMA::Make(
    backend_context,
    SkiaVMA::Options()
  );
  if (!backend_context.fMemoryAllocator) {
    release_vulkan_context(worker);
    return false;
  }
  sk_sp<GrDirectContext> context = GrDirectContexts::MakeVulkan(backend_context);
  if (!context) {
    release_vulkan_context(worker);
    return false;
  }
  worker->vulkan_context = context.release();
  {
    std::lock_guard<std::mutex> lock(worker->mutex);
    worker->context_generation += 1;
  }
  return true;
}

VkCompositeAlphaFlagBitsKHR choose_vulkan_composite_alpha(
  VkCompositeAlphaFlagsKHR supported
) {
  const VkCompositeAlphaFlagBitsKHR choices[] = {
    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR,
    VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR,
    VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR,
  };
  for (VkCompositeAlphaFlagBitsKHR choice : choices) {
    if ((supported & choice) != 0) {
      return choice;
    }
  }
  return VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
}

bool ensure_vulkan_swap_chain(MoonbitSkiaNativeGpuWorker* worker) {
  if (
    worker->width <= 0 ||
    worker->height <= 0 ||
    !ensure_vulkan_context(worker)
  ) {
    return false;
  }
  VkSurfaceCapabilitiesKHR capabilities = {};
  if (vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
    worker->vulkan_physical_device,
    worker->vulkan_surface,
    &capabilities
  ) != VK_SUCCESS) {
    return false;
  }
  VkExtent2D extent = capabilities.currentExtent;
  if (extent.width == UINT32_MAX) {
    extent.width = std::max(
      capabilities.minImageExtent.width,
      std::min(
        capabilities.maxImageExtent.width,
        static_cast<uint32_t>(worker->width)
      )
    );
    extent.height = std::max(
      capabilities.minImageExtent.height,
      std::min(
        capabilities.maxImageExtent.height,
        static_cast<uint32_t>(worker->height)
      )
    );
  }
  if (
    worker->vulkan_swap_chain != VK_NULL_HANDLE &&
    worker->vulkan_extent.width == extent.width &&
    worker->vulkan_extent.height == extent.height
  ) {
    return true;
  }
  release_vulkan_swap_chain(worker);

  uint32_t format_count = 0;
  if (
    vkGetPhysicalDeviceSurfaceFormatsKHR(
      worker->vulkan_physical_device,
      worker->vulkan_surface,
      &format_count,
      nullptr
    ) != VK_SUCCESS ||
    format_count == 0
  ) {
    return false;
  }
  std::vector<VkSurfaceFormatKHR> formats(format_count);
  if (vkGetPhysicalDeviceSurfaceFormatsKHR(
    worker->vulkan_physical_device,
    worker->vulkan_surface,
    &format_count,
    formats.data()
  ) != VK_SUCCESS) {
    return false;
  }
  VkSurfaceFormatKHR surface_format = formats[0];
  for (const VkSurfaceFormatKHR& candidate : formats) {
    if (
      candidate.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR &&
      (candidate.format == VK_FORMAT_B8G8R8A8_UNORM ||
       candidate.format == VK_FORMAT_R8G8B8A8_UNORM)
    ) {
      surface_format = candidate;
      break;
    }
  }
  uint32_t image_count = capabilities.minImageCount + 1;
  if (
    capabilities.maxImageCount > 0 &&
    image_count > capabilities.maxImageCount
  ) {
    image_count = capabilities.maxImageCount;
  }
  VkSwapchainCreateInfoKHR swap_info = {};
  swap_info.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
  swap_info.surface = worker->vulkan_surface;
  swap_info.minImageCount = image_count;
  swap_info.imageFormat = surface_format.format;
  swap_info.imageColorSpace = surface_format.colorSpace;
  swap_info.imageExtent = extent;
  swap_info.imageArrayLayers = 1;
  // Skia WrapBackendRenderTarget needs transfer bits for clear/upload paths in
  // addition to color attachment; COLOR_ATTACHMENT alone fails wrap on some
  // Android emulator drivers (observed as present fail=wrap format=37).
  VkImageUsageFlags usage =
    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
    VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
    VK_IMAGE_USAGE_TRANSFER_DST_BIT;
  usage &= capabilities.supportedUsageFlags;
  if ((usage & VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT) == 0) {
    usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  }
  swap_info.imageUsage = usage;
  swap_info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
  swap_info.preTransform = capabilities.currentTransform;
  swap_info.compositeAlpha = choose_vulkan_composite_alpha(
    capabilities.supportedCompositeAlpha
  );
  swap_info.presentMode = VK_PRESENT_MODE_FIFO_KHR;
  swap_info.clipped = VK_TRUE;
  if (vkCreateSwapchainKHR(
    worker->vulkan_device,
    &swap_info,
    nullptr,
    &worker->vulkan_swap_chain
  ) != VK_SUCCESS) {
    release_vulkan_swap_chain(worker);
    return false;
  }
  worker->vulkan_format = surface_format.format;
  worker->vulkan_color_space = surface_format.colorSpace;
  worker->vulkan_image_usage = usage;
  worker->vulkan_extent = extent;
  uint32_t actual_image_count = 0;
  if (vkGetSwapchainImagesKHR(
    worker->vulkan_device,
    worker->vulkan_swap_chain,
    &actual_image_count,
    nullptr
  ) != VK_SUCCESS || actual_image_count == 0) {
    release_vulkan_swap_chain(worker);
    return false;
  }
  worker->vulkan_images.resize(actual_image_count);
  if (vkGetSwapchainImagesKHR(
    worker->vulkan_device,
    worker->vulkan_swap_chain,
    &actual_image_count,
    worker->vulkan_images.data()
  ) != VK_SUCCESS) {
    release_vulkan_swap_chain(worker);
    return false;
  }
  worker->vulkan_image_layouts.assign(
    actual_image_count,
    VK_IMAGE_LAYOUT_UNDEFINED
  );
  worker->vulkan_image_fences.assign(actual_image_count, VK_NULL_HANDLE);
  worker->vulkan_render_finished.assign(actual_image_count, VK_NULL_HANDLE);
  VkFenceCreateInfo signaled_fence_info = {};
  signaled_fence_info.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
  signaled_fence_info.flags = VK_FENCE_CREATE_SIGNALED_BIT;
  VkSemaphoreCreateInfo semaphore_info = {};
  semaphore_info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
  for (uint32_t index = 0; index < actual_image_count; index += 1) {
    if (
      vkCreateFence(
        worker->vulkan_device,
        &signaled_fence_info,
        nullptr,
        &worker->vulkan_image_fences[index]
      ) != VK_SUCCESS ||
      vkCreateSemaphore(
        worker->vulkan_device,
        &semaphore_info,
        nullptr,
        &worker->vulkan_render_finished[index]
      ) != VK_SUCCESS
    ) {
      release_vulkan_swap_chain(worker);
      return false;
    }
  }
  VkFenceCreateInfo acquire_fence_info = {};
  acquire_fence_info.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
  if (vkCreateFence(
    worker->vulkan_device,
    &acquire_fence_info,
    nullptr,
    &worker->vulkan_acquire_fence
  ) != VK_SUCCESS) {
    release_vulkan_swap_chain(worker);
    return false;
  }
  return true;
}

enum class VulkanAcquireResult {
  Acquired,
  Recreate,
  Failed,
};

VulkanAcquireResult acquire_vulkan_image(
  MoonbitSkiaNativeGpuWorker* worker,
  uint32_t* image_index
) {
  const VkResult acquire_result = vkAcquireNextImageKHR(
    worker->vulkan_device,
    worker->vulkan_swap_chain,
    UINT64_MAX,
    VK_NULL_HANDLE,
    worker->vulkan_acquire_fence,
    image_index
  );
  if (acquire_result == VK_ERROR_OUT_OF_DATE_KHR) {
    return VulkanAcquireResult::Recreate;
  }
  if (acquire_result != VK_SUCCESS && acquire_result != VK_SUBOPTIMAL_KHR) {
    return VulkanAcquireResult::Failed;
  }
  if (vkWaitForFences(
    worker->vulkan_device,
    1,
    &worker->vulkan_acquire_fence,
    VK_TRUE,
    UINT64_MAX
  ) != VK_SUCCESS) {
    return VulkanAcquireResult::Failed;
  }
  if (vkResetFences(
    worker->vulkan_device,
    1,
    &worker->vulkan_acquire_fence
  ) != VK_SUCCESS) {
    return VulkanAcquireResult::Failed;
  }
  if (*image_index >= worker->vulkan_image_fences.size()) {
    return VulkanAcquireResult::Failed;
  }
  VkFence image_fence = worker->vulkan_image_fences[*image_index];
  if (vkWaitForFences(
    worker->vulkan_device,
    1,
    &image_fence,
    VK_TRUE,
    UINT64_MAX
  ) != VK_SUCCESS) {
    return VulkanAcquireResult::Failed;
  }
  if (vkResetFences(worker->vulkan_device, 1, &image_fence) != VK_SUCCESS) {
    return VulkanAcquireResult::Failed;
  }
  return VulkanAcquireResult::Acquired;
}

bool render_vulkan_picture(
  MoonbitSkiaNativeGpuWorker* worker,
  const sk_sp<SkPicture>& picture
) {
  if (!picture) {
#if defined(__ANDROID__)
    __android_log_print(ANDROID_LOG_WARN, "MoUIMobile", "vulkan present fail=no-picture");
#endif
    return false;
  }
  if (!ensure_vulkan_swap_chain(worker)) {
#if defined(__ANDROID__)
    __android_log_print(
      ANDROID_LOG_WARN,
      "MoUIMobile",
      "vulkan present fail=swap-chain size=%dx%d attached=%llu",
      worker->width,
      worker->height,
      static_cast<unsigned long long>(worker->attached_handle)
    );
#endif
    return false;
  }
  uint32_t image_index = 0;
  VulkanAcquireResult acquire_result = acquire_vulkan_image(worker, &image_index);
  if (acquire_result == VulkanAcquireResult::Recreate) {
    release_vulkan_swap_chain(worker);
    if (!ensure_vulkan_swap_chain(worker)) {
#if defined(__ANDROID__)
      __android_log_print(ANDROID_LOG_WARN, "MoUIMobile", "vulkan present fail=swap-recreate");
#endif
      return false;
    }
    acquire_result = acquire_vulkan_image(worker, &image_index);
  }
  if (
    acquire_result != VulkanAcquireResult::Acquired ||
    image_index >= worker->vulkan_images.size()
  ) {
#if defined(__ANDROID__)
    __android_log_print(
      ANDROID_LOG_WARN,
      "MoUIMobile",
      "vulkan present fail=acquire result=%d index=%u images=%zu",
      static_cast<int>(acquire_result),
      image_index,
      worker->vulkan_images.size()
    );
#endif
    return false;
  }
  GrVkImageInfo image_info;
  image_info.fImage = worker->vulkan_images[image_index];
  image_info.fFormat = worker->vulkan_format;
  image_info.fImageTiling = VK_IMAGE_TILING_OPTIMAL;
  // Always hand Skia UNDEFINED: after present the stored layout is PRESENT_SRC
  // and WrapBackendRenderTarget(present_src) fails on Android emulator
  // (fail=wrap format=37 after a few successful frames / heavy catalog redraw).
  image_info.fImageLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  image_info.fImageUsageFlags = worker->vulkan_image_usage != 0
    ? worker->vulkan_image_usage
    : VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  image_info.fSampleCount = 1;
  image_info.fLevelCount = 1;
  image_info.fCurrentQueueFamily = worker->vulkan_queue_family;
  image_info.fSharingMode = VK_SHARING_MODE_EXCLUSIVE;
  image_info.fProtected = skgpu::Protected::kNo;
  GrBackendRenderTarget render_target = GrBackendRenderTargets::MakeVk(
    static_cast<int>(worker->vulkan_extent.width),
    static_cast<int>(worker->vulkan_extent.height),
    image_info
  );
  if (!render_target.isValid()) {
#if defined(__ANDROID__)
    __android_log_print(
      ANDROID_LOG_WARN,
      "MoUIMobile",
      "vulkan present fail=backend-rt format=%u",
      static_cast<unsigned>(worker->vulkan_format)
    );
#endif
    return false;
  }
  sk_sp<SkSurface> surface = SkSurfaces::WrapBackendRenderTarget(
    worker->vulkan_context,
    render_target,
    kTopLeft_GrSurfaceOrigin,
    vulkan_color_type(worker->vulkan_format),
    nullptr,
    nullptr
  );
  if (!surface) {
#if defined(__ANDROID__)
    __android_log_print(
      ANDROID_LOG_WARN,
      "MoUIMobile",
      "vulkan present fail=wrap format=%u extent=%ux%u",
      static_cast<unsigned>(worker->vulkan_format),
      worker->vulkan_extent.width,
      worker->vulkan_extent.height
    );
#endif
    return false;
  }
  // Swapchain images start undefined/garbage. Always clear before replaying the
  // picture so a failed/partial draw cannot present an opaque black buffer.
  SkCanvas* canvas = surface->getCanvas();
  canvas->clear(SK_ColorWHITE);
  canvas->drawPicture(picture);
  GrFlushInfo flush_info;
  worker->vulkan_context->flush(
    surface.get(),
    SkSurfaces::BackendSurfaceAccess::kPresent,
    flush_info
  );
  // Non-blocking submit: SyncCpu::kYes on large catalog pictures can stall the
  // GPU worker for hundreds of ms and stop subsequent presents (Browse freeze /
  // landscape blank). Fence only the queue submit used for present ordering.
  if (!worker->vulkan_context->submit(GrSyncCpu::kNo)) {
#if defined(__ANDROID__)
    __android_log_print(ANDROID_LOG_WARN, "MoUIMobile", "vulkan present fail=submit");
#endif
    return false;
  }
  VkFence image_fence = worker->vulkan_image_fences[image_index];
  if (vkResetFences(worker->vulkan_device, 1, &image_fence) != VK_SUCCESS) {
#if defined(__ANDROID__)
    __android_log_print(ANDROID_LOG_WARN, "MoUIMobile", "vulkan present fail=reset-fence");
#endif
    return false;
  }
  VkSubmitInfo fence_submit = {};
  fence_submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
  if (vkQueueSubmit(
    worker->vulkan_queue,
    1,
    &fence_submit,
    image_fence
  ) != VK_SUCCESS) {
#if defined(__ANDROID__)
    __android_log_print(ANDROID_LOG_WARN, "MoUIMobile", "vulkan present fail=queue-submit");
#endif
    return false;
  }
  // Bounded wait — never hang the worker thread forever on a stuck device.
  const VkResult fence_wait = vkWaitForFences(
    worker->vulkan_device,
    1,
    &image_fence,
    VK_TRUE,
    50ull * 1000ull * 1000ull
  );
  if (fence_wait != VK_SUCCESS && fence_wait != VK_TIMEOUT) {
#if defined(__ANDROID__)
    __android_log_print(
      ANDROID_LOG_WARN,
      "MoUIMobile",
      "vulkan present fail=fence-wait result=%d",
      static_cast<int>(fence_wait)
    );
#endif
    return false;
  }
  VkPresentInfoKHR present_info = {};
  present_info.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
  present_info.waitSemaphoreCount = 0;
  present_info.pWaitSemaphores = nullptr;
  present_info.swapchainCount = 1;
  present_info.pSwapchains = &worker->vulkan_swap_chain;
  present_info.pImageIndices = &image_index;
  const VkResult present_result = vkQueuePresentKHR(
    worker->vulkan_queue,
    &present_info
  );
  if (
    present_result == VK_ERROR_OUT_OF_DATE_KHR ||
    present_result == VK_SUBOPTIMAL_KHR
  ) {
    worker->vulkan_image_layouts[image_index] = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    release_vulkan_swap_chain(worker);
    return present_result == VK_SUBOPTIMAL_KHR;
  }
  if (present_result != VK_SUCCESS) {
    return false;
  }
  worker->vulkan_image_layouts[image_index] = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
  return true;
}
#endif

#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
void retain_egl_native_window(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->egl_native_window == nullptr) {
    return;
  }
#if defined(__OHOS__)
  (void)OH_NativeWindow_NativeObjectReference(worker->egl_native_window);
#else
  ANativeWindow_acquire(worker->egl_native_window);
#endif
}

void release_egl_native_window(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->egl_native_window == nullptr) {
    return;
  }
#if defined(__OHOS__)
  (void)OH_NativeWindow_NativeObjectUnreference(worker->egl_native_window);
#else
  ANativeWindow_release(worker->egl_native_window);
#endif
  worker->egl_native_window = nullptr;
}

void release_egl_context(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->egl_display != EGL_NO_DISPLAY) {
    (void)eglMakeCurrent(
      worker->egl_display,
      EGL_NO_SURFACE,
      EGL_NO_SURFACE,
      EGL_NO_CONTEXT
    );
    if (worker->egl_window_surface != EGL_NO_SURFACE) {
      eglDestroySurface(worker->egl_display, worker->egl_window_surface);
    }
    if (worker->egl_bootstrap_surface != EGL_NO_SURFACE) {
      eglDestroySurface(worker->egl_display, worker->egl_bootstrap_surface);
    }
  }
  worker->egl_window_surface = EGL_NO_SURFACE;
  worker->egl_bootstrap_surface = EGL_NO_SURFACE;
  if (worker->egl_context != nullptr) {
    worker->egl_context->unref();
    worker->egl_context = nullptr;
  }
  if (
    worker->egl_display != EGL_NO_DISPLAY &&
    worker->egl_native_context != EGL_NO_CONTEXT
  ) {
    eglDestroyContext(worker->egl_display, worker->egl_native_context);
  }
  worker->egl_native_context = EGL_NO_CONTEXT;
  worker->egl_config = nullptr;
  if (worker->egl_display != EGL_NO_DISPLAY) {
    eglTerminate(worker->egl_display);
    worker->egl_display = EGL_NO_DISPLAY;
  }
}

void release_egl_attachment(MoonbitSkiaNativeGpuWorker* worker) {
  release_egl_context(worker);
  release_egl_native_window(worker);
}

bool ensure_egl_context(MoonbitSkiaNativeGpuWorker* worker) {
  if (
    worker->egl_context != nullptr &&
    !worker->egl_context->abandoned() &&
    worker->egl_display != EGL_NO_DISPLAY &&
    worker->egl_native_context != EGL_NO_CONTEXT
  ) {
    return true;
  }
  release_egl_context(worker);
  worker->egl_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (worker->egl_display == EGL_NO_DISPLAY) {
    return false;
  }
  EGLint major = 0;
  EGLint minor = 0;
  if (!eglInitialize(worker->egl_display, &major, &minor)) {
    release_egl_context(worker);
    return false;
  }
  const EGLint config_attributes[] = {
    EGL_RED_SIZE, 8,
    EGL_GREEN_SIZE, 8,
    EGL_BLUE_SIZE, 8,
    EGL_ALPHA_SIZE, 8,
    EGL_DEPTH_SIZE, 0,
    EGL_STENCIL_SIZE, 0,
    EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
    EGL_SURFACE_TYPE, EGL_WINDOW_BIT | EGL_PBUFFER_BIT,
    EGL_NONE,
  };
  EGLint config_count = 0;
  if (
    !eglChooseConfig(
      worker->egl_display,
      config_attributes,
      &worker->egl_config,
      1,
      &config_count
    ) ||
    config_count < 1 ||
    worker->egl_config == nullptr
  ) {
    release_egl_context(worker);
    return false;
  }
  if (!eglBindAPI(EGL_OPENGL_ES_API)) {
    release_egl_context(worker);
    return false;
  }
  const EGLint context_attributes[] = {
    EGL_CONTEXT_CLIENT_VERSION, 3,
    EGL_NONE,
  };
  worker->egl_native_context = eglCreateContext(
    worker->egl_display,
    worker->egl_config,
    EGL_NO_CONTEXT,
    context_attributes
  );
  if (worker->egl_native_context == EGL_NO_CONTEXT) {
    release_egl_context(worker);
    return false;
  }
  const EGLint pbuffer_attributes[] = {
    EGL_WIDTH, 1,
    EGL_HEIGHT, 1,
    EGL_NONE,
  };
  worker->egl_bootstrap_surface = eglCreatePbufferSurface(
    worker->egl_display,
    worker->egl_config,
    pbuffer_attributes
  );
  if (
    worker->egl_bootstrap_surface == EGL_NO_SURFACE ||
    !eglMakeCurrent(
      worker->egl_display,
      worker->egl_bootstrap_surface,
      worker->egl_bootstrap_surface,
      worker->egl_native_context
    )
  ) {
    release_egl_context(worker);
    return false;
  }
  sk_sp<GrGLInterface> gl_interface = GrGLMakeNativeInterface();
  if (!gl_interface) {
    release_egl_context(worker);
    return false;
  }
  sk_sp<GrDirectContext> context = GrDirectContexts::MakeGL(gl_interface);
  if (!context) {
    release_egl_context(worker);
    return false;
  }
  worker->egl_context = context.release();
  {
    std::lock_guard<std::mutex> lock(worker->mutex);
    worker->context_generation += 1;
  }
  return true;
}

bool ensure_egl_window_surface(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker->egl_native_window == nullptr || !ensure_egl_context(worker)) {
    return false;
  }
#if defined(__OHOS__)
  // XComponent windows need geometry + GPU usage before eglCreateWindowSurface
  // or HVD can present empty/black frames even when eglSwapBuffers succeeds.
  if (worker->width > 0 && worker->height > 0) {
    (void)OH_NativeWindow_NativeWindowHandleOpt(
      worker->egl_native_window,
      SET_BUFFER_GEOMETRY,
      worker->width,
      worker->height
    );
  }
  (void)OH_NativeWindow_NativeWindowHandleOpt(
    worker->egl_native_window,
    SET_USAGE,
    static_cast<uint64_t>(
      NATIVEBUFFER_USAGE_HW_RENDER |
      NATIVEBUFFER_USAGE_HW_TEXTURE |
      NATIVEBUFFER_USAGE_MEM_DMA
    )
  );
#endif
  if (worker->egl_window_surface == EGL_NO_SURFACE) {
    const EGLint surface_attributes[] = {
      EGL_RENDER_BUFFER, EGL_BACK_BUFFER,
      EGL_NONE,
    };
    worker->egl_window_surface = eglCreateWindowSurface(
      worker->egl_display,
      worker->egl_config,
      reinterpret_cast<EGLNativeWindowType>(worker->egl_native_window),
      surface_attributes
    );
    if (worker->egl_window_surface == EGL_NO_SURFACE) {
      return false;
    }
    (void)eglSwapInterval(worker->egl_display, 1);
  }
  return eglMakeCurrent(
    worker->egl_display,
    worker->egl_window_surface,
    worker->egl_window_surface,
    worker->egl_native_context
  ) == EGL_TRUE;
}

bool render_egl_picture(
  MoonbitSkiaNativeGpuWorker* worker,
  const sk_sp<SkPicture>& picture
) {
  if (
    !picture ||
    worker->width <= 0 ||
    worker->height <= 0 ||
    !ensure_egl_window_surface(worker)
  ) {
    return false;
  }
  GrGLFramebufferInfo framebuffer_info;
  framebuffer_info.fFBOID = 0;
  framebuffer_info.fFormat = GL_RGBA8;
  GrBackendRenderTarget render_target = GrBackendRenderTargets::MakeGL(
    worker->width,
    worker->height,
    0,
    0,
    framebuffer_info
  );
  // Match Metal/Vulkan workers: Android/OHOS native windows present top-left
  // origin content. Bottom-left here previously produced a black XComponent on
  // the HarmonyOS emulator even though configure selected egl-gpu.
  sk_sp<SkSurface> surface = SkSurfaces::WrapBackendRenderTarget(
    worker->egl_context,
    render_target,
    kTopLeft_GrSurfaceOrigin,
    kRGBA_8888_SkColorType,
    nullptr,
    nullptr
  );
  if (!surface) {
    return false;
  }
  SkCanvas* canvas = surface->getCanvas();
  canvas->clear(SK_ColorWHITE);
  canvas->drawPicture(picture);
  worker->egl_context->flushAndSubmit(surface.get(), GrSyncCpu::kNo);
  if (worker->egl_context->abandoned()) {
    return false;
  }
  const EGLBoolean swapped = eglSwapBuffers(
    worker->egl_display,
    worker->egl_window_surface
  );
  return swapped == EGL_TRUE;
}
#endif

int64_t native_gpu_resource_cache_bytes(
  MoonbitSkiaNativeGpuWorker* worker
) {
  size_t total_bytes = 0;
  int resource_count = 0;
  size_t bytes = 0;
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
  if (worker->metal_context != nullptr) {
    worker->metal_context->getResourceCacheUsage(&resource_count, &bytes);
    total_bytes += bytes;
  }
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
  if (worker->d3d_context != nullptr) {
    worker->d3d_context->getResourceCacheUsage(&resource_count, &bytes);
    total_bytes += bytes;
  }
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
  if (worker->vulkan_context != nullptr) {
    worker->vulkan_context->getResourceCacheUsage(&resource_count, &bytes);
    total_bytes += bytes;
  }
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
  if (worker->egl_context != nullptr) {
    worker->egl_context->getResourceCacheUsage(&resource_count, &bytes);
    total_bytes += bytes;
  }
#endif
  return static_cast<int64_t>(total_bytes);
}

void queue_completion(
  MoonbitSkiaNativeGpuWorker* worker,
  NativeGpuCompletion completion
) {
  static const size_t kCompletionCapacity = 256;
  if (worker->completions.size() >= kCompletionCapacity) {
    worker->completions.pop_front();
    worker->dropped += 1;
  }
  worker->completions.push_back(std::move(completion));
  worker->wake.notify_all();
}

void push_control_completion(
  MoonbitSkiaNativeGpuWorker* worker,
  const NativeGpuControl& control,
  NativeGpuCompletionStatus status = NativeGpuCompletionStatus_ControlAcknowledged
) {
  queue_completion(worker, {
    0,
    control.token,
    worker->surface_generation,
    worker->context_generation,
    0,
    0.0,
    native_gpu_now_ms(),
    native_gpu_now_ms(),
    status,
  });
}

void process_control(
  MoonbitSkiaNativeGpuWorker* worker,
  const NativeGpuControl& control
) {
  switch (control.kind) {
    case NativeGpuControlKind_Attach:
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
      release_vulkan_attachment(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
      release_egl_attachment(worker);
#endif
      worker->attached_handle = control.handle;
      worker->attached_auxiliary_handle = control.auxiliary_handle;
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN) && defined(__ANDROID__)
      worker->android_native_window = reinterpret_cast<ANativeWindow*>(
        static_cast<uintptr_t>(control.handle)
      );
      if (worker->android_native_window != nullptr) {
        ANativeWindow_acquire(worker->android_native_window);
      }
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
      worker->egl_native_window = reinterpret_cast<NativeGpuEglWindow*>(
        static_cast<uintptr_t>(control.handle)
      );
      retain_egl_native_window(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
      release_metal_layer(worker);
      worker->metal_layer = reinterpret_cast<void*>(
        static_cast<uintptr_t>(control.handle)
      );
      moonbit_skia_objc_retain(worker->metal_layer);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
      release_d3d_swap_chain(worker);
#endif
      worker->surface_generation += 1;
      push_control_completion(worker, control);
      break;
    case NativeGpuControlKind_Resize:
      worker->width = control.width;
      worker->height = control.height;
      worker->surface_generation += 1;
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
      // Rotation / size change invalidates the swapchain extent; recreate on
      // the next present instead of wrapping stale images.
      release_vulkan_swap_chain(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
      // Geometry changes require a fresh EGL window surface.
      if (
        worker->egl_display != EGL_NO_DISPLAY &&
        worker->egl_window_surface != EGL_NO_SURFACE
      ) {
        (void)eglMakeCurrent(
          worker->egl_display,
          EGL_NO_SURFACE,
          EGL_NO_SURFACE,
          EGL_NO_CONTEXT
        );
        eglDestroySurface(worker->egl_display, worker->egl_window_surface);
        worker->egl_window_surface = EGL_NO_SURFACE;
      }
#endif
      push_control_completion(worker, control);
      break;
    case NativeGpuControlKind_Detach:
      worker->attached_handle = 0;
      worker->attached_auxiliary_handle = 0;
      worker->width = 0;
      worker->height = 0;
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
      release_metal_layer(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
      release_d3d_swap_chain(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
      release_vulkan_attachment(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
      release_egl_attachment(worker);
#endif
      worker->surface_generation += 1;
      if (worker->pending != nullptr) {
        worker->pending.reset();
        worker->dropped += 1;
      }
      push_control_completion(worker, control);
      break;
    case NativeGpuControlKind_ContextLoss:
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
      release_metal_context(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
      release_d3d_context(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
      release_vulkan_context(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
      release_egl_context(worker);
#endif
      worker->consecutive_recovery_failures = 0;
      worker->recovery_count += 1;
      push_control_completion(worker, control);
      break;
    case NativeGpuControlKind_Shutdown:
      worker->shutdown_requested = true;
      if (worker->pending != nullptr) {
        worker->pending.reset();
        worker->dropped += 1;
      }
      push_control_completion(worker, control);
      break;
  }
}

void run_native_gpu_worker(MoonbitSkiaNativeGpuWorker* worker) {
  {
    std::lock_guard<std::mutex> lock(worker->mutex);
    const std::hash<std::thread::id> thread_hasher;
    worker->worker_thread_id = static_cast<int64_t>(
      thread_hasher(std::this_thread::get_id())
    );
  }
  for (;;) {
    std::unique_lock<std::mutex> lock(worker->mutex);
    worker->wake.wait(lock, [worker] {
      return worker->shutdown_requested || !worker->controls.empty() ||
        worker->pending != nullptr;
    });
    while (!worker->controls.empty()) {
      NativeGpuControl control = worker->controls.front();
      worker->controls.pop_front();
      process_control(worker, control);
    }
    if (worker->shutdown_requested) {
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
      release_metal_layer(worker);
      release_metal_context(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
      release_d3d_context(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
      release_vulkan_attachment(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
      release_egl_attachment(worker);
#endif
      return;
    }
    if (worker->pending == nullptr) {
      continue;
    }
    NativeGpuFrame frame = std::move(*worker->pending);
    worker->pending.reset();
    if (frame.surface_generation != worker->surface_generation) {
      worker->dropped += 1;
      queue_completion(worker, {
        frame.sequence,
        0,
        frame.surface_generation,
        worker->context_generation,
        frame.image_resource_revision,
        frame.submitted_at_ms,
        native_gpu_now_ms(),
        native_gpu_now_ms(),
        NativeGpuCompletionStatus_Dropped,
      });
      continue;
    }

    lock.unlock();

    NativeGpuCompletionStatus completion_status =
      NativeGpuCompletionStatus_PictureRecorded;
    bool attempted_present = false;
    bool presented = false;
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
    if (frame.picture) {
      (void)frame.picture->uniqueID();
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
      if (worker->metal_layer != nullptr && worker->width > 0 && worker->height > 0) {
        attempted_present = true;
        presented = render_metal_picture(worker, frame.picture);
      }
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
      if (worker->attached_handle != 0 && worker->width > 0 && worker->height > 0) {
        attempted_present = true;
        presented = render_d3d_picture(worker, frame.picture);
      }
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
      if (worker->attached_handle != 0 && worker->width > 0 && worker->height > 0) {
        attempted_present = true;
        presented = render_vulkan_picture(worker, frame.picture);
#if defined(__ANDROID__)
        __android_log_print(
          ANDROID_LOG_INFO,
          "MoUIMobile",
          "gpu-worker vulkan present=%d seq=%lld size=%dx%d fails=%d",
          presented ? 1 : 0,
          static_cast<long long>(frame.sequence),
          worker->width,
          worker->height,
          worker->consecutive_recovery_failures
        );
#endif
      }
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
      if (
        !presented &&
        worker->attached_handle != 0 &&
        worker->width > 0 &&
        worker->height > 0
      ) {
        attempted_present = true;
        presented = render_egl_picture(worker, frame.picture);
#if defined(__ANDROID__)
        __android_log_print(
          ANDROID_LOG_INFO,
          "MoUIMobile",
          "gpu-worker egl present=%d seq=%lld size=%dx%d fails=%d",
          presented ? 1 : 0,
          static_cast<long long>(frame.sequence),
          worker->width,
          worker->height,
          worker->consecutive_recovery_failures
        );
#endif
      }
#endif
    }
#endif
    if (attempted_present) {
      if (presented) {
        worker->consecutive_recovery_failures = 0;
        completion_status = NativeGpuCompletionStatus_Presented;
      } else {
        worker->consecutive_recovery_failures += 1;
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_METAL)
        release_metal_context(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_D3D12)
        release_d3d_context(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_VULKAN)
        release_vulkan_context(worker);
#endif
#if defined(MOUI_SKIA_NATIVE_GPU_WORKER_EGL)
        release_egl_context(worker);
#endif
        // Sticky after the first failed present. Waiting for a second failure
        // left Android emulators black when only one or two frames were drawn
        // before the UI went idle.
        if (worker->consecutive_recovery_failures >= 1) {
          completion_status = NativeGpuCompletionStatus_FallbackToRaster;
        } else {
          completion_status = NativeGpuCompletionStatus_Dropped;
        }
      }
    }
    const double completed_at_ms = native_gpu_now_ms();
    const int64_t resource_cache_bytes = native_gpu_resource_cache_bytes(worker);
    lock.lock();
    worker->resource_cache_bytes = resource_cache_bytes;
    if (presented || !attempted_present) {
      worker->completed += 1;
    } else {
      worker->dropped += 1;
    }
    queue_completion(worker, {
      frame.sequence,
      0,
      frame.surface_generation,
      worker->context_generation,
      frame.image_resource_revision,
      frame.submitted_at_ms,
      completed_at_ms,
      presented ? completed_at_ms : 0.0,
      completion_status,
    });
  }
}

void native_gpu_worker_destroy(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker == nullptr) {
    return;
  }
  {
    std::lock_guard<std::mutex> lock(worker->mutex);
    worker->shutdown_requested = true;
    worker->pending.reset();
  }
  worker->wake.notify_one();
  if (!worker->joined && worker->thread.joinable()) {
    worker->thread.join();
    worker->joined = true;
  }
  worker->~MoonbitSkiaNativeGpuWorker();
}

void native_gpu_worker_finalize(void* pointer) {
  native_gpu_worker_destroy(static_cast<MoonbitSkiaNativeGpuWorker*>(pointer));
}

MoonbitSkiaNativeGpuWorker* make_native_gpu_worker_handle() {
  auto* storage = static_cast<MoonbitSkiaNativeGpuWorker*>(
    moonbit_make_external_object(
      native_gpu_worker_finalize,
      sizeof(MoonbitSkiaNativeGpuWorker)
    )
  );
  auto* worker = new (storage) MoonbitSkiaNativeGpuWorker();
  worker->thread = std::thread(run_native_gpu_worker, worker);
  return worker;
}

int64_t native_gpu_worker_submit(
  MoonbitSkiaNativeGpuWorker* worker,
  MoonbitSkiaPicture* picture,
  int64_t image_resource_revision,
  double submitted_at_ms
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  if (worker->shutdown_requested) {
    return 0;
  }
  NativeGpuFrame frame;
  frame.sequence = worker->next_sequence++;
  frame.surface_generation = worker->surface_generation;
  frame.image_resource_revision = image_resource_revision;
  frame.submitted_at_ms = submitted_at_ms;
#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_HAS_PICTURE)
  if (picture != nullptr && picture->picture != nullptr) {
    frame.picture = sk_ref_sp(picture->picture);
  }
#else
  (void)picture;
#endif
  if (worker->pending != nullptr) {
    worker->pending.reset();
    worker->replaced_pending += 1;
    worker->dropped += 1;
  }
  const int64_t sequence = frame.sequence;
  worker->pending.reset(new NativeGpuFrame(std::move(frame)));
  worker->submitted += 1;
  worker->wake.notify_one();
  return sequence;
}

}  // namespace

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaNativeGpuWorker*
moonbit_skia_native_gpu_worker_new(void) {
  return make_native_gpu_worker_handle();
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_is_null(MoonbitSkiaNativeGpuWorker* worker) {
  return worker == nullptr;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_submit(
  MoonbitSkiaNativeGpuWorker* worker,
  MoonbitSkiaPicture* picture,
  int64_t image_resource_revision,
  double submitted_at_ms
) {
  return native_gpu_worker_submit(
    worker,
    picture,
    image_resource_revision,
    submitted_at_ms
  );
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_submit_empty(
  MoonbitSkiaNativeGpuWorker* worker,
  int64_t image_resource_revision,
  double submitted_at_ms
) {
  return native_gpu_worker_submit(
    worker,
    nullptr,
    image_resource_revision,
    submitted_at_ms
  );
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_submit_control(
  MoonbitSkiaNativeGpuWorker* worker,
  int32_t kind,
  uint64_t handle,
  uint64_t auxiliary_handle,
  int32_t width,
  int32_t height
) {
  if (worker == nullptr || kind < 1 || kind > 5) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  if (worker->shutdown_requested) {
    return 0;
  }
  NativeGpuControl control;
  control.kind = static_cast<NativeGpuControlKind>(kind);
  control.token = worker->next_control_token++;
  control.handle = handle;
  control.auxiliary_handle = auxiliary_handle;
  control.width = width;
  control.height = height;
  const int64_t token = control.token;
  worker->controls.push_back(control);
  worker->wake.notify_one();
  return token;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_completion_count(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return static_cast<int32_t>(worker->completions.size());
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_wait_completion(
  MoonbitSkiaNativeGpuWorker* worker,
  int32_t timeout_ms
) {
  if (worker == nullptr) {
    return 0;
  }
  std::unique_lock<std::mutex> lock(worker->mutex);
  const bool ready = worker->wake.wait_for(
    lock,
    std::chrono::milliseconds(std::max(0, timeout_ms)),
    [worker] { return !worker->completions.empty(); }
  );
  return ready ? 1 : 0;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_completion_sequence(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty() ? 0 : worker->completions.front().sequence;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_completion_control_token(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty() ? 0 : worker->completions.front().control_token;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_completion_status(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty()
    ? 0
    : static_cast<int32_t>(worker->completions.front().status);
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_completion_surface_generation(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty()
    ? 0
    : worker->completions.front().surface_generation;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_completion_context_generation(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty()
    ? 0
    : worker->completions.front().context_generation;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_completion_image_resource_revision(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty()
    ? 0
    : worker->completions.front().image_resource_revision;
}

extern "C" MOONBIT_FFI_EXPORT double
moonbit_skia_native_gpu_worker_completion_submitted_at_ms(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0.0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty()
    ? 0.0
    : worker->completions.front().submitted_at_ms;
}

extern "C" MOONBIT_FFI_EXPORT double
moonbit_skia_native_gpu_worker_completion_processed_at_ms(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0.0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty()
    ? 0.0
    : worker->completions.front().gpu_completed_at_ms;
}

extern "C" MOONBIT_FFI_EXPORT double
moonbit_skia_native_gpu_worker_completion_presented_at_ms(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0.0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completions.empty()
    ? 0.0
    : worker->completions.front().presented_at_ms;
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_native_gpu_worker_pop_completion(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  if (!worker->completions.empty()) {
    worker->completions.pop_front();
  }
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_thread_id(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->worker_thread_id;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_submitted(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->submitted;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_completed(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->completed;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_dropped(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->dropped;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_replaced_pending(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->replaced_pending;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_surface_generation(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->surface_generation;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_context_generation(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->context_generation;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_recovery_count(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->recovery_count;
}

extern "C" MOONBIT_FFI_EXPORT int64_t
moonbit_skia_native_gpu_worker_resource_cache_bytes(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return worker->resource_cache_bytes;
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_control_pending(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return static_cast<int32_t>(worker->controls.size());
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_native_gpu_worker_completion_pending(
  MoonbitSkiaNativeGpuWorker* worker
) {
  if (worker == nullptr) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(worker->mutex);
  return static_cast<int32_t>(worker->completions.size());
}

extern "C" MOONBIT_FFI_EXPORT void
moonbit_skia_native_gpu_worker_shutdown(MoonbitSkiaNativeGpuWorker* worker) {
  if (worker == nullptr) {
    return;
  }
  {
    std::lock_guard<std::mutex> lock(worker->mutex);
    worker->shutdown_requested = true;
    worker->pending.reset();
  }
  worker->wake.notify_one();
  if (!worker->joined && worker->thread.joinable()) {
    worker->thread.join();
    worker->joined = true;
  }
}
