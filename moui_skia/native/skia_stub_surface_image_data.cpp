#ifndef NOMINMAX
#define NOMINMAX
#endif
#include "skia_stub_common.h"

#include <cstdio>
#include <cstdlib>

#ifndef __has_include
#define __has_include(x) 0
#endif

#if defined(__ANDROID__) && defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  !defined(VK_NO_PROTOTYPES)
#define VK_NO_PROTOTYPES
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(__APPLE__) && \
  __has_include("include/gpu/ganesh/GrDirectContext.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlBackendContext.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlDirectContext.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlTypes.h") && \
  __has_include("include/gpu/ganesh/mtl/GrMtlBackendSurface.h") && \
  __has_include("include/gpu/ganesh/GrBackendSurface.h") && \
  __has_include("include/gpu/ganesh/SkSurfaceGanesh.h") && \
  __has_include("include/gpu/ganesh/mtl/SkSurfaceMetal.h")
#define MOUI_SKIA_HAS_GANESH_METAL_HEADERS 1
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(_WIN32) && \
  __has_include("include/gpu/ganesh/GrDirectContext.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DBackendContext.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DDirectContext.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DTypes.h") && \
  __has_include("include/gpu/ganesh/d3d/GrD3DBackendSurface.h") && \
  __has_include("include/gpu/ganesh/GrBackendSurface.h") && \
  __has_include("include/gpu/ganesh/SkSurfaceGanesh.h")
#define MOUI_SKIA_HAS_GANESH_D3D_HEADERS 1
#endif

#if defined(MOUI_SKIA_HAS_SKIA) && defined(MOUI_SKIA_ENABLE_GPU_EGL) && \
  (defined(__OHOS__) || defined(__ANDROID__))
// Opt-in GPU-EGL builds already stage Skia + link -lEGL/-lGLESv*. Trust the
// opt-in on mobile targets so a partial __has_include failure (common on the
// HarmonyOS sysroot layout) cannot compile
// moonbit_skia_surface_gpu_egl_runtime_available() as a constant 0.
#define MOUI_SKIA_HAS_GANESH_EGL_HEADERS 1
#endif

#if defined(MOUI_SKIA_ENABLE_GPU_METAL) && \
  defined(MOUI_SKIA_HAS_GANESH_METAL_HEADERS)
#include "include/gpu/ganesh/mtl/GrMtlBackendContext.h"
#include "include/gpu/ganesh/mtl/GrMtlDirectContext.h"
#include "include/gpu/ganesh/mtl/GrMtlTypes.h"
#include "include/gpu/ganesh/mtl/GrMtlBackendSurface.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include "include/gpu/ganesh/mtl/SkSurfaceMetal.h"
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

void moonbit_skia_objc_retain(void* object) {
  if (object == nullptr) {
    return;
  }
  using ObjcSendNoArg = void* (*)(void*, SEL);
  reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    object,
    sel_registerName("retain")
  );
}

static GrDirectContext* moonbit_skia_make_metal_direct_context(
  void** retained_device = nullptr,
  void** retained_queue = nullptr
) {
  if (retained_device != nullptr) {
    *retained_device = nullptr;
  }
  if (retained_queue != nullptr) {
    *retained_queue = nullptr;
  }
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

  if (!context) {
    moonbit_skia_objc_release(queue);
    moonbit_skia_objc_release(device);
    return nullptr;
  }
  if (retained_device != nullptr) {
    *retained_device = device;
  } else {
    moonbit_skia_objc_release(device);
  }
  if (retained_queue != nullptr) {
    *retained_queue = queue;
  } else {
    moonbit_skia_objc_release(queue);
  }

  return context.release();
}
#elif defined(__APPLE__)
void moonbit_skia_objc_release(void* object) {
  (void)object;
}
#endif

#if defined(MOUI_SKIA_ENABLE_GPU_D3D) && \
  defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
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

static constexpr uint64_t MOONBIT_SKIA_D3D12_SWAPCHAIN_MAGIC =
  0x4D4F554944334431ULL;

struct MoonbitSkiaD3D12SwapChain {
  uint64_t magic = MOONBIT_SKIA_D3D12_SWAPCHAIN_MAGIC;
  ComPtr<IDXGISwapChain3> swap_chain;
  ComPtr<ID3D12Device> device;
  ComPtr<ID3D12CommandQueue> queue;
  ComPtr<ID3D12Fence> fence;
  HANDLE fence_event = nullptr;
  uint64_t fence_value = 0;
  HRESULT last_device_removed_reason = S_OK;
  UINT frame_index = 0;
  UINT width = 0;
  UINT height = 0;
};

static MoonbitSkiaD3D12SwapChain* moonbit_skia_d3d12_swap_chain(
  void* object
) {
  if (object == nullptr) {
    return nullptr;
  }
  auto* candidate = static_cast<MoonbitSkiaD3D12SwapChain*>(object);
  return candidate->magic == MOONBIT_SKIA_D3D12_SWAPCHAIN_MAGIC
    ? candidate
    : nullptr;
}

void moonbit_skia_com_release(void* object) {
  if (object == nullptr) {
    return;
  }
  if (auto* swap_chain = moonbit_skia_d3d12_swap_chain(object)) {
    if (swap_chain->fence_event != nullptr) {
      CloseHandle(swap_chain->fence_event);
      swap_chain->fence_event = nullptr;
    }
    delete swap_chain;
    return;
  }
  static_cast<IUnknown*>(object)->Release();
}

static bool moonbit_skia_make_d3d12_objects(
  ComPtr<IDXGIAdapter1>& adapter,
  ComPtr<ID3D12Device>& device,
  ComPtr<ID3D12CommandQueue>& queue
) {
  ComPtr<IDXGIFactory4> factory;
  HRESULT hr = CreateDXGIFactory1(IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    return false;
  }

  for (UINT index = 0;; index += 1) {
    ComPtr<IDXGIAdapter1> candidate;
    hr = factory->EnumAdapters1(index, &candidate);
    if (hr == DXGI_ERROR_NOT_FOUND) {
      break;
    }
    if (FAILED(hr)) {
      continue;
    }
    DXGI_ADAPTER_DESC1 description;
    if (FAILED(candidate->GetDesc1(&description)) ||
      (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0) {
      continue;
    }
    if (FAILED(D3D12CreateDevice(
      candidate.Get(),
      D3D_FEATURE_LEVEL_11_0,
      IID_PPV_ARGS(&device)
    ))) {
      device.Reset();
      continue;
    }
    adapter = candidate;
    break;
  }
  if (adapter == nullptr || device == nullptr) {
    return false;
  }

  D3D12_COMMAND_QUEUE_DESC queue_description = {};
  queue_description.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
  queue_description.Priority = D3D12_COMMAND_QUEUE_PRIORITY_NORMAL;
  queue_description.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
  queue_description.NodeMask = 0;
  return SUCCEEDED(device->CreateCommandQueue(
    &queue_description,
    IID_PPV_ARGS(&queue)
  ));
}

static GrDirectContext* moonbit_skia_make_d3d_direct_context(
  ComPtr<IDXGIAdapter1>& adapter,
  ComPtr<ID3D12Device>& device,
  ComPtr<ID3D12CommandQueue>& queue
) {
  if (!moonbit_skia_make_d3d12_objects(adapter, device, queue)) {
    return nullptr;
  }
  GrD3DBackendContext backend_context;
  backend_context.fAdapter.retain(adapter.Get());
  backend_context.fDevice.retain(device.Get());
  backend_context.fQueue.retain(queue.Get());
  sk_sp<GrDirectContext> context = GrDirectContexts::MakeD3D(
    backend_context
  );
  return context.release();
}
#elif defined(_WIN32)
void moonbit_skia_com_release(void* object) { (void)object; }
#endif

static const int32_t MOONBIT_SKIA_GPU_BACKEND_METAL = 1;
static const int32_t MOONBIT_SKIA_GPU_BACKEND_D3D = 2;
static const int32_t MOONBIT_SKIA_GPU_BACKEND_VULKAN = 3;
static const int32_t MOONBIT_SKIA_GPU_BACKEND_EGL = 4;

#if defined(MOUI_SKIA_HAS_GANESH_DIRECT_CONTEXT)
static GrSurfaceOrigin moonbit_skia_surface_origin(int32_t origin) {
  return origin == 1 ? kBottomLeft_GrSurfaceOrigin : kTopLeft_GrSurfaceOrigin;
}
#endif

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
  void* device = nullptr;
  void* queue = nullptr;
  GrDirectContext* context = moonbit_skia_make_metal_direct_context(
    &device,
    &queue
  );
  if (context == nullptr) {
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }
  return moonbit_skia_make_gpu_context_wrapper(
    context,
    device,
    queue,
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
  ComPtr<IDXGIAdapter1> adapter;
  ComPtr<ID3D12Device> device;
  ComPtr<ID3D12CommandQueue> queue;
  GrDirectContext* context = moonbit_skia_make_d3d_direct_context(
    adapter,
    device,
    queue
  );
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
  ComPtr<IDXGIAdapter1> adapter;
  ComPtr<ID3D12Device> device;
  ComPtr<ID3D12CommandQueue> queue;
  if (!moonbit_skia_make_d3d12_objects(adapter, device, queue)) {
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }

  GrD3DBackendContext backend_context;
  backend_context.fAdapter.retain(adapter.Get());
  backend_context.fDevice.retain(device.Get());
  backend_context.fQueue.retain(queue.Get());
  sk_sp<GrDirectContext> context = GrDirectContexts::MakeD3D(
    backend_context
  );
  if (!context) {
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }

  // The wrapper owns independent COM references so the native context can be
  // destroyed without invalidating the provider-owned device and queue.
  ID3D12Device* device_ptr = device.Get();
  device_ptr->AddRef();
  ID3D12CommandQueue* queue_ptr = queue.Get();
  queue_ptr->AddRef();

  return moonbit_skia_make_gpu_context_wrapper(
    context.release(),
    device_ptr,
    queue_ptr,
    MOONBIT_SKIA_GPU_BACKEND_D3D
  );
#else
  return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
#endif
}

#if defined(MOUI_SKIA_ENABLE_GPU_D3D) && \
  defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
static bool moonbit_skia_d3d12_wait_for_frame(
  MoonbitSkiaD3D12SwapChain* swap_chain
) {
  if (swap_chain == nullptr || swap_chain->queue == nullptr ||
    swap_chain->fence == nullptr || swap_chain->fence_event == nullptr) {
    return false;
  }
  const uint64_t fence_value = ++swap_chain->fence_value;
  if (FAILED(swap_chain->queue->Signal(
    swap_chain->fence.Get(),
    fence_value
  ))) {
    return false;
  }
  if (swap_chain->fence->GetCompletedValue() < fence_value) {
    if (FAILED(swap_chain->fence->SetEventOnCompletion(
      fence_value,
      swap_chain->fence_event
    ))) {
      return false;
    }
    return WaitForSingleObject(swap_chain->fence_event, INFINITE) == WAIT_OBJECT_0;
  }
  return true;
}

static MoonbitSkiaSurface* moonbit_skia_d3d12_wrap_back_buffer(
  GrDirectContext* gpu_context,
  MoonbitSkiaD3D12SwapChain* swap_chain,
  int32_t width,
  int32_t height,
  int32_t origin
) {
  if (gpu_context == nullptr ||
    swap_chain == nullptr || swap_chain->swap_chain == nullptr ||
    width <= 0 || height <= 0) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  ComPtr<ID3D12Resource> back_buffer;
  if (FAILED(swap_chain->swap_chain->GetBuffer(
    swap_chain->frame_index,
    IID_PPV_ARGS(&back_buffer)
  ))) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  GrD3DTextureResourceInfo resource_info;
  resource_info.fResource.retain(back_buffer.Get());
  resource_info.fResourceState = D3D12_RESOURCE_STATE_COMMON;
  resource_info.fFormat = DXGI_FORMAT_R8G8B8A8_UNORM;
  resource_info.fSampleCount = 1;

  GrBackendRenderTarget backend_rt = GrBackendRenderTargets::MakeD3D(
    width,
    height,
    resource_info
  );
  sk_sp<SkSurface> surface = SkSurfaces::WrapBackendRenderTarget(
    gpu_context,
    backend_rt,
    moonbit_skia_surface_origin(origin),
    kRGBA_8888_SkColorType,
    nullptr,
    nullptr
  );
  if (!surface) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  MoonbitSkiaSurface* wrapper = moonbit_skia_surface_wrapper_with_gpu_context(
    surface.release(),
    gpu_context
  );
  wrapper->host_present_handle = swap_chain;
  return wrapper;
}
#endif

#if defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  defined(MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS)
#include "include/gpu/ganesh/vk/GrVkBackendSurface.h"
#include "include/gpu/ganesh/vk/GrVkDirectContext.h"
#include "include/gpu/ganesh/vk/GrVkTypes.h"
#include "include/gpu/vk/VulkanBackendContext.h"
#include "include/android/vk/AndroidVulkanMemoryAllocator.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"

#include <vulkan/vulkan.h>
#if defined(__ANDROID__)
#include <vulkan/vulkan_android.h>
#include <android/native_window.h>
#include "android_vulkan_loader.h"
#elif defined(__linux__)
#include <vulkan/vulkan_wayland.h>
#include <wayland-client.h>
#endif

static SkColorType moonbit_skia_vulkan_color_type(VkFormat format) {
  switch (format) {
    case VK_FORMAT_B8G8R8A8_UNORM:
    case VK_FORMAT_B8G8R8A8_SRGB:
      return kBGRA_8888_SkColorType;
    default:
      return kRGBA_8888_SkColorType;
  }
}

/// Heap-allocated Vulkan context state. Stored as the `device` field of
/// MoonbitSkiaGpuContext. The finalizer calls
/// moonbit_skia_vulkan_release_context which destroys the VkDevice and
/// VkInstance in that order.
struct MoonbitSkiaVulkanContext {
  VkInstance instance;
  VkPhysicalDevice physical_device;
  VkDevice device;
  VkQueue queue;
  uint32_t queue_family_index;
};

/// Heap-allocated Vulkan swapchain state. Stored as the `host_present_handle`
/// of MoonbitSkiaSurface. The finalizer calls
/// moonbit_skia_vulkan_release_swapchain which destroys the swapchain and
/// surface. The VkDevice, VkInstance, VkQueue are borrowed from the context
/// and not released here.
struct MoonbitSkiaVulkanSwapChain {
  VkDevice device;
  VkInstance instance;
  VkQueue queue;
  VkSwapchainKHR swapchain;
  VkSurfaceKHR surface;
  VkFormat image_format;
  uint32_t queue_family_index;
  std::vector<VkImage> images;
  std::vector<VkFence> image_fences;
  VkFence acquire_fence;
  VkSemaphore render_finished;
  uint32_t current_image_index;
};

void moonbit_skia_vulkan_release_context(void* object) {
  if (object == nullptr) {
    return;
  }
  auto* ctx = static_cast<MoonbitSkiaVulkanContext*>(object);
  if (ctx->device != VK_NULL_HANDLE) {
    vkDestroyDevice(ctx->device, nullptr);
  }
  if (ctx->instance != VK_NULL_HANDLE) {
    vkDestroyInstance(ctx->instance, nullptr);
  }
  delete ctx;
}

void moonbit_skia_vulkan_release_swapchain(void* object) {
  if (object == nullptr) {
    return;
  }
  auto* sc = static_cast<MoonbitSkiaVulkanSwapChain*>(object);
  if (sc->device != VK_NULL_HANDLE) {
    if (sc->render_finished != VK_NULL_HANDLE) {
      vkDestroySemaphore(sc->device, sc->render_finished, nullptr);
      sc->render_finished = VK_NULL_HANDLE;
    }
    if (sc->acquire_fence != VK_NULL_HANDLE) {
      vkDestroyFence(sc->device, sc->acquire_fence, nullptr);
      sc->acquire_fence = VK_NULL_HANDLE;
    }
    for (VkFence fence : sc->image_fences) {
      if (fence != VK_NULL_HANDLE) {
        vkDestroyFence(sc->device, fence, nullptr);
      }
    }
    if (sc->swapchain != VK_NULL_HANDLE) {
      vkDestroySwapchainKHR(sc->device, sc->swapchain, nullptr);
    }
  }
  if (sc->instance != VK_NULL_HANDLE && sc->surface != VK_NULL_HANDLE) {
    vkDestroySurfaceKHR(sc->instance, sc->surface, nullptr);
  }
  delete sc;
}

static bool moonbit_skia_vulkan_prepare_swapchain(
  MoonbitSkiaVulkanSwapChain* sc
) {
  if (sc == nullptr || sc->device == VK_NULL_HANDLE ||
    sc->swapchain == VK_NULL_HANDLE || sc->images.empty()) {
    return false;
  }
  VkSemaphoreCreateInfo semaphore_info = {};
  semaphore_info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
  if (vkCreateSemaphore(
    sc->device,
    &semaphore_info,
    nullptr,
    &sc->render_finished
  ) != VK_SUCCESS) {
    return false;
  }

  VkFenceCreateInfo acquire_fence_info = {};
  acquire_fence_info.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
  if (vkCreateFence(
    sc->device,
    &acquire_fence_info,
    nullptr,
    &sc->acquire_fence
  ) != VK_SUCCESS) {
    return false;
  }
  VkFenceCreateInfo fence_info = acquire_fence_info;
  fence_info.flags = VK_FENCE_CREATE_SIGNALED_BIT;
  sc->image_fences.resize(sc->images.size(), VK_NULL_HANDLE);
  for (VkFence& fence : sc->image_fences) {
    if (vkCreateFence(sc->device, &fence_info, nullptr, &fence) != VK_SUCCESS) {
      return false;
    }
  }
  VkResult acquire = vkAcquireNextImageKHR(
    sc->device,
    sc->swapchain,
    UINT64_MAX,
    VK_NULL_HANDLE,
    sc->acquire_fence,
    &sc->current_image_index
  );
  if (acquire != VK_SUCCESS && acquire != VK_SUBOPTIMAL_KHR) {
    return false;
  }
  if (vkWaitForFences(sc->device, 1, &sc->acquire_fence, VK_TRUE, UINT64_MAX) !=
    VK_SUCCESS) {
    return false;
  }
  vkResetFences(sc->device, 1, &sc->acquire_fence);
  VkFence current_fence = sc->image_fences[sc->current_image_index];
  if (vkWaitForFences(sc->device, 1, &current_fence, VK_TRUE, UINT64_MAX) !=
    VK_SUCCESS) {
    return false;
  }
  vkResetFences(sc->device, 1, &current_fence);
  return true;
}

static bool moonbit_skia_vulkan_acquire_next(
  MoonbitSkiaVulkanSwapChain* sc
) {
  if (sc == nullptr || sc->image_fences.empty()) {
    return false;
  }
  VkResult acquire = vkAcquireNextImageKHR(
    sc->device,
    sc->swapchain,
    UINT64_MAX,
    VK_NULL_HANDLE,
    sc->acquire_fence,
    &sc->current_image_index
  );
  if (acquire != VK_SUCCESS && acquire != VK_SUBOPTIMAL_KHR) {
    return false;
  }
  if (vkWaitForFences(sc->device, 1, &sc->acquire_fence, VK_TRUE, UINT64_MAX) !=
    VK_SUCCESS) {
    return false;
  }
  vkResetFences(sc->device, 1, &sc->acquire_fence);
  VkFence current_fence = sc->image_fences[sc->current_image_index];
  if (vkWaitForFences(sc->device, 1, &current_fence, VK_TRUE, UINT64_MAX) !=
    VK_SUCCESS) {
    return false;
  }
  vkResetFences(sc->device, 1, &current_fence);
  return true;
}

static GrDirectContext* moonbit_skia_make_vulkan_direct_context(
  MoonbitSkiaVulkanContext** out_context
) {
#if defined(__ANDROID__)
  if (!moui_skia_android_vulkan_load()) {
    return nullptr;
  }
#endif
  const char* instance_extensions[] = {
    VK_KHR_SURFACE_EXTENSION_NAME,
#if defined(__ANDROID__)
    VK_KHR_ANDROID_SURFACE_EXTENSION_NAME,
#elif defined(__linux__)
    VK_KHR_WAYLAND_SURFACE_EXTENSION_NAME,
#endif
  };
  VkApplicationInfo application_info = {};
  application_info.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
  application_info.pApplicationName = "MoUI";
  application_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
  application_info.pEngineName = "Skia";
  application_info.engineVersion = VK_MAKE_VERSION(1, 0, 0);
  application_info.apiVersion = VK_API_VERSION_1_1;
  VkInstanceCreateInfo instance_info = {};
  instance_info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  instance_info.pApplicationInfo = &application_info;
  instance_info.enabledExtensionCount = static_cast<uint32_t>(
    sizeof(instance_extensions) / sizeof(instance_extensions[0])
  );
  instance_info.ppEnabledExtensionNames = instance_extensions;
  VkInstance instance = VK_NULL_HANDLE;
  VkResult err = vkCreateInstance(&instance_info, nullptr, &instance);
  if (err != VK_SUCCESS || instance == VK_NULL_HANDLE) {
    return nullptr;
  }

  uint32_t gpu_count = 0;
  err = vkEnumeratePhysicalDevices(instance, &gpu_count, nullptr);
  if (err != VK_SUCCESS || gpu_count == 0) {
    vkDestroyInstance(instance, nullptr);
    return nullptr;
  }
  std::vector<VkPhysicalDevice> gpus(gpu_count);
  err = vkEnumeratePhysicalDevices(instance, &gpu_count, gpus.data());
  if (err != VK_SUCCESS || gpus.empty()) {
    vkDestroyInstance(instance, nullptr);
    return nullptr;
  }
  VkPhysicalDevice physical_device = gpus[0];

  uint32_t queue_family_count = 0;
  vkGetPhysicalDeviceQueueFamilyProperties(
    physical_device, &queue_family_count, nullptr
  );
  if (queue_family_count == 0) {
    vkDestroyInstance(instance, nullptr);
    return nullptr;
  }
  std::vector<VkQueueFamilyProperties> queue_families(queue_family_count);
  vkGetPhysicalDeviceQueueFamilyProperties(
    physical_device, &queue_family_count, queue_families.data()
  );
  uint32_t queue_family_index = 0;
  bool found_graphics = false;
  for (uint32_t i = 0; i < queue_family_count; ++i) {
    if (queue_families[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
      queue_family_index = i;
      found_graphics = true;
      break;
    }
  }
  if (!found_graphics) {
    vkDestroyInstance(instance, nullptr);
    return nullptr;
  }

  float queue_priority = 1.0f;
  VkDeviceQueueCreateInfo queue_info = {};
  queue_info.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  queue_info.queueFamilyIndex = queue_family_index;
  queue_info.queueCount = 1;
  queue_info.pQueuePriorities = &queue_priority;

  const char* device_extensions[] = {
    VK_KHR_SWAPCHAIN_EXTENSION_NAME,
  };
  VkDeviceCreateInfo device_info = {};
  device_info.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  device_info.queueCreateInfoCount = 1;
  device_info.pQueueCreateInfos = &queue_info;
  device_info.enabledExtensionCount = 1;
  device_info.ppEnabledExtensionNames = device_extensions;
  VkDevice device = VK_NULL_HANDLE;
  err = vkCreateDevice(physical_device, &device_info, nullptr, &device);
  if (err != VK_SUCCESS || device == VK_NULL_HANDLE) {
    vkDestroyInstance(instance, nullptr);
    return nullptr;
  }
  VkQueue queue;
  vkGetDeviceQueue(device, queue_family_index, 0, &queue);

  skgpu::VulkanBackendContext backend_context;
  backend_context.fInstance = instance;
  backend_context.fPhysicalDevice = physical_device;
  backend_context.fDevice = device;
  backend_context.fQueue = queue;
  backend_context.fGraphicsQueueIndex = queue_family_index;
  backend_context.fMaxAPIVersion = VK_API_VERSION_1_1;
  backend_context.fGetProc = [](
    const char* name,
    VkInstance proc_instance,
    VkDevice proc_device
  ) -> PFN_vkVoidFunction {
    if (proc_device != VK_NULL_HANDLE) {
      PFN_vkVoidFunction proc = vkGetDeviceProcAddr(proc_device, name);
      if (proc != nullptr) {
        return proc;
      }
    }
    return vkGetInstanceProcAddr(proc_instance, name);
  };
  // AndroidVulkanMemoryAllocator (SkiaVMA) is packaged/linked for Android GPU
// builds. Desktop Linux packages ship the header but not the object, so only
// wire VMA on Android and let GrDirectContexts use its default allocator.
#if defined(__ANDROID__)
  backend_context.fMemoryAllocator = SkiaVMA::Make(
    backend_context,
    SkiaVMA::Options()
  );
  if (!backend_context.fMemoryAllocator) {
    vkDestroyDevice(device, nullptr);
    vkDestroyInstance(instance, nullptr);
    return nullptr;
  }
#endif

  sk_sp<GrDirectContext> context = GrDirectContexts::MakeVulkan(
    backend_context
  );
  if (!context) {
    vkDestroyDevice(device, nullptr);
    vkDestroyInstance(instance, nullptr);
    return nullptr;
  }

  auto* vk_context = new MoonbitSkiaVulkanContext();
  vk_context->instance = instance;
  vk_context->physical_device = physical_device;
  vk_context->device = device;
  vk_context->queue = queue;
  vk_context->queue_family_index = queue_family_index;
  *out_context = vk_context;
  return context.release();
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_vulkan_opt_in_enabled(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  (defined(__ANDROID__) || defined(__linux__))
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_vulkan_headers_available(void) {
#if defined(MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS)
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_vulkan_runtime_available(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  defined(MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS)
  MoonbitSkiaVulkanContext* vk_context = nullptr;
  GrDirectContext* context = moonbit_skia_make_vulkan_direct_context(
    &vk_context
  );
  if (context == nullptr) {
    return 0;
  }
  context->unref();
  if (vk_context != nullptr) {
    moonbit_skia_vulkan_release_context(vk_context);
  }
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaGpuContext*
moonbit_skia_gpu_context_vulkan(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  defined(MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS)
  MoonbitSkiaVulkanContext* vk_context = nullptr;
  GrDirectContext* context = moonbit_skia_make_vulkan_direct_context(
    &vk_context
  );
  if (!context || vk_context == nullptr) {
    if (vk_context != nullptr) {
      moonbit_skia_vulkan_release_context(vk_context);
    }
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }
  return moonbit_skia_make_gpu_context_wrapper(
    context,
    vk_context,
    nullptr,
    MOONBIT_SKIA_GPU_BACKEND_VULKAN
  );
#else
  return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
#endif
}

// Release function stubs for HarmonyOS when EGL is not opted in. The real
// definitions live in the opt-in block below. These are safe because no EGL
// objects are ever allocated when the opt-in is disabled, so the finalizers
// in skia_stub_common.cpp only call these with nullptr.
#if (defined(__OHOS__) || defined(__ANDROID__)) && \
  (!defined(MOUI_SKIA_ENABLE_GPU_EGL) || \
   !defined(MOUI_SKIA_HAS_GANESH_EGL_HEADERS))
void moonbit_skia_egl_release_context(void* object) { (void)object; }
void moonbit_skia_egl_release_window(void* object) { (void)object; }
#endif

#if defined(MOUI_SKIA_ENABLE_GPU_EGL) && \
  defined(MOUI_SKIA_HAS_GANESH_EGL_HEADERS)
// GrGLBackendContext.h is not shipped in every Skia package (HarmonyOS cache
// omits it). GrGLDirectContext.h + GrGLInterface/Types + GrGLBackendSurface
// are enough for MakeGL / MakeGL framebuffer targets.
#include "include/gpu/ganesh/gl/GrGLDirectContext.h"
#include "include/gpu/ganesh/gl/GrGLInterface.h"
#include "include/gpu/ganesh/gl/GrGLTypes.h"
#include "include/gpu/ganesh/gl/GrGLBackendSurface.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#if __has_include("include/gpu/ganesh/gl/egl/GrGLMakeEGLInterface.h")
#include "include/gpu/ganesh/gl/egl/GrGLMakeEGLInterface.h"
#endif
#if __has_include("include/gpu/ganesh/gl/GrGLAssembleInterface.h")
#include "include/gpu/ganesh/gl/GrGLAssembleInterface.h"
#endif
// Some Skia builds still expose GrGLMakeNativeInterface via GrGLInterface.h
// without a separate assemble header.

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#if defined(__OHOS__)
#include <native_buffer/native_buffer.h>
#include <native_window/external_window.h>
#if defined(__has_include)
#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define MOUI_SKIA_EGL_HAS_HILOG 1
#endif
#endif
#else
#include <android/native_window.h>
#endif

#if defined(__OHOS__)
using MoonbitSkiaEglNativeWindow = OHNativeWindow;
#else
using MoonbitSkiaEglNativeWindow = ANativeWindow;
#endif

/// Heap-allocated EGL context state. Stored as the `device` field of
/// MoonbitSkiaGpuContext. The finalizer calls
/// moonbit_skia_egl_release_context which destroys the EGLContext and
/// terminates the EGLDisplay in that order.
struct MoonbitSkiaEglContext {
  EGLDisplay display;
  EGLContext context;
  EGLConfig config;
  EGLSurface bootstrap_surface;
};

/// Heap-allocated EGL window surface state. Stored as the
/// `host_present_handle` of MoonbitSkiaSurface. The finalizer calls
/// moonbit_skia_egl_release_window which destroys the EGLSurface. The
/// EGLDisplay and EGLContext are borrowed from the context and not released
/// here.
struct MoonbitSkiaEglWindow {
  EGLDisplay display;
  EGLContext context;
  EGLSurface surface;
};

void moonbit_skia_egl_release_context(void* object) {
  if (object == nullptr) {
    return;
  }
  auto* ctx = static_cast<MoonbitSkiaEglContext*>(object);
  // Keep a current context only long enough to tear down cleanly. Destroy the
  // bootstrap surface before the context so the display is not left current on
  // a deleted surface (observed as main-thread THREAD_BLOCK_6S on OHOS HVD).
  if (
    ctx->display != EGL_NO_DISPLAY &&
    ctx->context != EGL_NO_CONTEXT
  ) {
    if (ctx->bootstrap_surface != EGL_NO_SURFACE) {
      (void)eglMakeCurrent(
        ctx->display,
        ctx->bootstrap_surface,
        ctx->bootstrap_surface,
        ctx->context
      );
    }
    (void)eglMakeCurrent(
      ctx->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT
    );
  }
  if (
    ctx->display != EGL_NO_DISPLAY &&
    ctx->bootstrap_surface != EGL_NO_SURFACE
  ) {
    eglDestroySurface(ctx->display, ctx->bootstrap_surface);
    ctx->bootstrap_surface = EGL_NO_SURFACE;
  }
  if (ctx->display != EGL_NO_DISPLAY && ctx->context != EGL_NO_CONTEXT) {
    eglDestroyContext(ctx->display, ctx->context);
    ctx->context = EGL_NO_CONTEXT;
  }
  if (ctx->display != EGL_NO_DISPLAY) {
    eglTerminate(ctx->display);
    ctx->display = EGL_NO_DISPLAY;
  }
  delete ctx;
}

void moonbit_skia_egl_release_window(void* object) {
  if (object == nullptr) {
    return;
  }
  auto* win = static_cast<MoonbitSkiaEglWindow*>(object);
  if (win->display != EGL_NO_DISPLAY && win->surface != EGL_NO_SURFACE) {
    eglDestroySurface(win->display, win->surface);
  }
  delete win;
}

static GrDirectContext* moonbit_skia_make_egl_direct_context(
  MoonbitSkiaEglContext** out_context
) {
  EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (display == EGL_NO_DISPLAY) {
    return nullptr;
  }
  EGLint major = 0;
  EGLint minor = 0;
  if (!eglInitialize(display, &major, &minor)) {
    return nullptr;
  }
  if (major < 1 || (major == 1 && minor < 4)) {
    eglTerminate(display);
    return nullptr;
  }

  const EGLint config_attribs[] = {
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
  EGLConfig config = nullptr;
  EGLint num_configs = 0;
  if (!eglChooseConfig(display, config_attribs, &config, 1, &num_configs) ||
      num_configs < 1 || config == nullptr) {
    eglTerminate(display);
    return nullptr;
  }

  eglBindAPI(EGL_OPENGL_ES_API);

  const EGLint context_attribs[] = {
    EGL_CONTEXT_CLIENT_VERSION, 3,
    EGL_NONE,
  };
  EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attribs);
  if (context == EGL_NO_CONTEXT) {
    eglTerminate(display);
    return nullptr;
  }

  const EGLint pbuffer_attribs[] = {
    EGL_WIDTH, 1,
    EGL_HEIGHT, 1,
    EGL_NONE,
  };
  EGLSurface bootstrap_surface = eglCreatePbufferSurface(
    display,
    config,
    pbuffer_attribs
  );
  if (bootstrap_surface == EGL_NO_SURFACE) {
    eglDestroyContext(display, context);
    eglTerminate(display);
    return nullptr;
  }

  // The bootstrap pbuffer lets API 23 devices initialize the GL interface
  // even when surfaceless contexts are unavailable.
  if (!eglMakeCurrent(display, bootstrap_surface, bootstrap_surface, context)) {
    eglDestroySurface(display, bootstrap_surface);
    eglDestroyContext(display, context);
    eglTerminate(display);
    return nullptr;
  }

  sk_sp<const GrGLInterface> gl_interface;
#if defined(SK_GL) || 1
  // Prefer EGL-specific assembler when present; fall back to native interface.
#if defined(GrGLMakeEGLInterface_DEFINED) || \
  __has_include("include/gpu/ganesh/gl/egl/GrGLMakeEGLInterface.h")
  gl_interface = GrGLInterfaces::MakeEGL();
#endif
  if (!gl_interface) {
    gl_interface = GrGLMakeNativeInterface();
  }
#endif
  if (!gl_interface) {
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroySurface(display, bootstrap_surface);
    eglDestroyContext(display, context);
    eglTerminate(display);
    return nullptr;
  }

  GrDirectContext* gpu_context = GrDirectContexts::MakeGL(gl_interface).release();
  if (!gpu_context) {
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroySurface(display, bootstrap_surface);
    eglDestroyContext(display, context);
    eglTerminate(display);
    return nullptr;
  }

  auto* egl_context = new MoonbitSkiaEglContext();
  egl_context->display = display;
  egl_context->context = context;
  egl_context->config = config;
  egl_context->bootstrap_surface = bootstrap_surface;
  *out_context = egl_context;
  return gpu_context;
}
#endif

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_egl_opt_in_enabled(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_EGL) && \
  (defined(__OHOS__) || defined(__ANDROID__))
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_egl_headers_available(void) {
#if defined(MOUI_SKIA_HAS_GANESH_EGL_HEADERS)
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT int32_t
moonbit_skia_surface_gpu_egl_runtime_available(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_EGL) && \
  defined(MOUI_SKIA_HAS_GANESH_EGL_HEADERS)
  // Do not allocate a temporary GrDirectContext just to answer this probe.
  // Creating + destroying a probe context on the HarmonyOS main/XComponent
  // thread has hung inside GrDirectContext::~GrDirectContext → glGetError
  // (THREAD_BLOCK_6S / app freeze). Opt-in mobile builds already link EGL/GLES
  // and force HAS_GANESH_EGL_HEADERS; real availability is proven when
  // GpuContext::egl / window surface creation succeeds.
  return 1;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaGpuContext*
moonbit_skia_gpu_context_egl(void) {
#if defined(MOUI_SKIA_ENABLE_GPU_EGL) && \
  defined(MOUI_SKIA_HAS_GANESH_EGL_HEADERS)
  MoonbitSkiaEglContext* egl_context = nullptr;
  GrDirectContext* context = moonbit_skia_make_egl_direct_context(&egl_context);
  if (!context || egl_context == nullptr) {
    if (egl_context != nullptr) {
      moonbit_skia_egl_release_context(egl_context);
    }
    return moonbit_skia_make_gpu_context_wrapper(nullptr, nullptr, nullptr, 0);
  }
  return moonbit_skia_make_gpu_context_wrapper(
    context,
    egl_context,
    nullptr,
    MOONBIT_SKIA_GPU_BACKEND_EGL
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
static sk_sp<SkSurface> moonbit_skia_wrap_metal_layer(
  GrDirectContext* context,
  void* layer,
  int32_t width,
  int32_t height,
  int32_t origin,
  GrMTLHandle* drawable_handle
) {
  if (drawable_handle != nullptr) {
    *drawable_handle = nullptr;
  }
  using ObjcSendNoArg = void* (*)(void*, SEL);
  void* drawable = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    layer,
    sel_registerName("nextDrawable")
  );
  if (drawable == nullptr) {
    if (std::getenv("MOUI_SKIA_GPU_DIAGNOSTICS") != nullptr) {
      std::fprintf(stderr, "MoUI macOS Metal acquire failed: nextDrawable returned nil\n");
    }
    return nullptr;
  }
  void* texture = reinterpret_cast<ObjcSendNoArg>(objc_msgSend)(
    drawable,
    sel_registerName("texture")
  );
  if (texture == nullptr) {
    if (std::getenv("MOUI_SKIA_GPU_DIAGNOSTICS") != nullptr) {
      std::fprintf(stderr, "MoUI macOS Metal acquire failed: drawable texture was nil\n");
    }
    return nullptr;
  }

  GrMtlTextureInfo texture_info;
  texture_info.fTexture.retain(static_cast<GrMTLHandle>(texture));
  GrBackendRenderTarget render_target = GrBackendRenderTargets::MakeMtl(
    width,
    height,
    texture_info
  );
  sk_sp<SkSurface> surface = SkSurfaces::WrapBackendRenderTarget(
    context,
    render_target,
    moonbit_skia_surface_origin(origin),
    kBGRA_8888_SkColorType,
    nullptr,
    nullptr
  );
  if (!surface) {
    if (std::getenv("MOUI_SKIA_GPU_DIAGNOSTICS") != nullptr) {
      std::fprintf(stderr, "MoUI macOS Metal acquire failed: Skia backend wrap returned null\n");
    }
    return nullptr;
  }
  if (drawable_handle != nullptr) {
    *drawable_handle = static_cast<GrMTLHandle>(drawable);
  }
  return surface;
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
    context->context == nullptr
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  // Offscreen GPU placeholders are used before the host window surface is
  // attached (HostGpuPresentTarget path). Metal historically owned this entry
  // point; EGL/Vulkan also need RenderTarget placeholders or
  // create_with_present_target_and_route fails on first attach.
  const bool backend_supported =
    context->backend == MOONBIT_SKIA_GPU_BACKEND_METAL ||
    context->backend == MOONBIT_SKIA_GPU_BACKEND_EGL ||
    context->backend == MOONBIT_SKIA_GPU_BACKEND_VULKAN ||
    context->backend == MOONBIT_SKIA_GPU_BACKEND_D3D;
  if (!backend_supported) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
// Only call SkSurfaces::RenderTarget when a GPU backend is actually enabled
// and linked. Headers alone are not enough: CPU-only Skia packages ship the
// Ganesh headers without the RenderTarget symbol.
#if defined(MOUI_SKIA_HAS_GANESH_SURFACE) && \
  (defined(MOUI_SKIA_ENABLE_GPU_METAL) || defined(MOUI_SKIA_ENABLE_GPU_EGL) || \
   defined(MOUI_SKIA_ENABLE_GPU_VULKAN) || defined(MOUI_SKIA_ENABLE_GPU_D3D) || \
   defined(MOUI_SKIA_ENABLE_GPU_D3D12))
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
  (void)stencil_bits;

  void* layer = reinterpret_cast<void*>(static_cast<uintptr_t>(layer_ptr));
  if (context->device != nullptr) {
    using ObjcSendSetObject = void (*)(void*, SEL, void*);
    reinterpret_cast<ObjcSendSetObject>(objc_msgSend)(
      layer,
      sel_registerName("setDevice:"),
      context->device
    );
  }
  GrMTLHandle drawable_handle = nullptr;
  sk_sp<SkSurface> surface = moonbit_skia_wrap_metal_layer(
    context->context,
    layer,
    width,
    height,
    origin,
    &drawable_handle
  );
  (void)sample_count;
  if (!surface || drawable_handle == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  void* drawable = const_cast<void*>(drawable_handle);
  moonbit_skia_objc_retain(drawable);
  MoonbitSkiaSurface* wrapper = moonbit_skia_surface_wrapper_with_gpu_context(
    surface.release(),
    context->context
  );
  wrapper->host_present_handle = drawable;
  return wrapper;
#else
  (void)layer_ptr;
  (void)origin;
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

  // Acquire and wrap the next drawable using Skia's current Ganesh Metal API.
  GrMTLHandle next_drawable_handle = nullptr;
  sk_sp<SkSurface> next_surface = moonbit_skia_wrap_metal_layer(
    gpu_context,
    layer,
    width,
    height,
    origin,
    &next_drawable_handle
  );
  if (!next_surface || next_drawable_handle == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  void* next_drawable = const_cast<void*>(next_drawable_handle);
  moonbit_skia_objc_retain(next_drawable);
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
  ID3D12Device* device = static_cast<ID3D12Device*>(context->device);
  ID3D12CommandQueue* queue = static_cast<ID3D12CommandQueue*>(context->queue);
  if (device == nullptr || queue == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  ComPtr<IDXGIFactory4> factory;
  HRESULT hr = CreateDXGIFactory1(IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  DXGI_SWAP_CHAIN_DESC1 description = {};
  description.Width = static_cast<UINT>(width);
  description.Height = static_cast<UINT>(height);
  description.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  description.Stereo = FALSE;
  description.SampleDesc.Count = 1;
  description.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  description.BufferCount = 3;
  description.Scaling = DXGI_SCALING_STRETCH;
  description.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
  description.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
  description.Flags = 0;

  ComPtr<IDXGISwapChain1> swap_chain_v1;
  hr = factory->CreateSwapChainForHwnd(
    queue,
    hwnd,
    &description,
    nullptr,
    nullptr,
    &swap_chain_v1
  );
  if (FAILED(hr)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  factory->MakeWindowAssociation(hwnd, DXGI_MWA_NO_ALT_ENTER);

  auto* swap_chain = new MoonbitSkiaD3D12SwapChain();
  hr = swap_chain_v1.As(&swap_chain->swap_chain);
  if (FAILED(hr)) {
    delete swap_chain;
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  swap_chain->device = device;
  swap_chain->queue = queue;
  swap_chain->width = static_cast<UINT>(width);
  swap_chain->height = static_cast<UINT>(height);
  swap_chain->frame_index = swap_chain->swap_chain->GetCurrentBackBufferIndex();
  hr = device->CreateFence(
    0,
    D3D12_FENCE_FLAG_NONE,
    IID_PPV_ARGS(&swap_chain->fence)
  );
  if (FAILED(hr)) {
    delete swap_chain;
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  swap_chain->fence_event = CreateEvent(nullptr, FALSE, FALSE, nullptr);
  if (swap_chain->fence_event == nullptr) {
    delete swap_chain;
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  MoonbitSkiaSurface* wrapper = moonbit_skia_d3d12_wrap_back_buffer(
    context->context,
    swap_chain,
    width,
    height,
    origin
  );
  if (wrapper->surface == nullptr) {
    moonbit_skia_com_release(swap_chain);
  }
  return wrapper;
#else
  (void)hwnd_ptr;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

// extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
// moonbit_skia_surface_direct3d_resize_window_surface(
//   MoonbitSkiaSurface* wrapper,
//   MoonbitSkiaGpuContext* context,
//   uint64_t hwnd_ptr,
//   int32_t width,
//   int32_t height,
//   int32_t origin,
//   int32_t sample_count,
//   int32_t stencil_bits
// ) {
//   if (
//     wrapper == nullptr ||
//     wrapper->surface == nullptr ||
//     wrapper->host_present_handle == nullptr ||
//     context == nullptr ||
//     context->context == nullptr ||
//     context->backend != MOONBIT_SKIA_GPU_BACKEND_D3D
//   ) {
//     return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
//   }
// #if defined(MOUI_SKIA_ENABLE_GPU_D3D) && \
//   defined(MOUI_SKIA_HAS_GANESH_D3D_HEADERS)
//   (void)hwnd_ptr;
//   (void)sample_count;
//   (void)stencil_bits;

//   auto* swap_chain = moonbit_skia_d3d12_swap_chain(wrapper->host_present_handle);
//   GrDirectContext* gpu_context = wrapper->gpu_context_owner;
//   if (
//     swap_chain == nullptr ||
//     gpu_context == nullptr ||
//     gpu_context != context->context ||
//     width <= 0 ||
//     height <= 0
//   ) {
//     return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
//   }

//   // Win32 resize callbacks can run while the previous frame is still queued.
//   // Wait before releasing the wrapped back buffer, then ResizeBuffers only
//   // after Ganesh has dropped its resource references.
//   if (!moonbit_skia_d3d12_wait_for_frame(swap_chain)) {
//     return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
//   }
//   wrapper->surface->unref();
//   wrapper->surface = nullptr;
//   wrapper->host_present_handle = nullptr;
//   gpu_context->freeGpuResources();

//   HRESULT hr = S_OK;
//   if (
//     swap_chain->width != static_cast<UINT>(width) ||
//     swap_chain->height != static_cast<UINT>(height)
//   ) {
//     hr = swap_chain->swap_chain->ResizeBuffers(
//       3,
//       static_cast<UINT>(width),
//       static_cast<UINT>(height),
//       DXGI_FORMAT_R8G8B8A8_UNORM,
//       0
//     );
//     if (FAILED(hr)) {
//       swap_chain->last_device_removed_reason = swap_chain->device->GetDeviceRemovedReason();
//       moonbit_skia_com_release(swap_chain);
//       return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
//     }
//     swap_chain->width = static_cast<UINT>(width);
//     swap_chain->height = static_cast<UINT>(height);
//   }
//   swap_chain->frame_index = swap_chain->swap_chain->GetCurrentBackBufferIndex();
//   MoonbitSkiaSurface* new_wrapper = moonbit_skia_d3d12_wrap_back_buffer(
//     gpu_context,
//     swap_chain,
//     width,
//     height,
//     origin
//   );
//   if (new_wrapper->surface == nullptr) {
//     moonbit_skia_com_release(swap_chain);
//     return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
//   }
//   return new_wrapper;
// #else
//   (void)hwnd_ptr;
//   (void)width;
//   (void)height;
//   (void)origin;
//   (void)sample_count;
//   (void)stencil_bits;
//   return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
// #endif
// }

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

  auto* swap_chain = moonbit_skia_d3d12_swap_chain(wrapper->host_present_handle);
  GrDirectContext* gpu_context = wrapper->gpu_context_owner;
  if (swap_chain == nullptr || gpu_context == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  GrFlushInfo flush_info;
  gpu_context->flush(
    wrapper->surface,
    SkSurfaces::BackendSurfaceAccess::kPresent,
    flush_info
  );
  if (!gpu_context->submit()) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }
  if (!moonbit_skia_d3d12_wait_for_frame(swap_chain)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  HRESULT hr = swap_chain->swap_chain->Present(1, 0);
  if (FAILED(hr)) {
    swap_chain->last_device_removed_reason = swap_chain->device->GetDeviceRemovedReason();
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  // Transfer the swap-chain state to the next surface wrapper. The old
  // back-buffer resource must be released before ResizeBuffers.
  wrapper->surface->unref();
  wrapper->surface = nullptr;
  wrapper->host_present_handle = nullptr;

  if (width <= 0 || height <= 0) {
    moonbit_skia_com_release(swap_chain);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }
  if (swap_chain->width != static_cast<UINT>(width) ||
    swap_chain->height != static_cast<UINT>(height)) {
    gpu_context->freeGpuResources();
    // Push deferred D3D12 resource releases through the queue and wait for
    // the GPU to go idle before touching the swap chain.
    gpu_context->flush();
    (void)gpu_context->submit();
    (void)moonbit_skia_d3d12_wait_for_frame(swap_chain);
    // DXGI allows only one flip-model swap chain per HWND, and ResizeBuffers
    // keeps failing with DXGI_ERROR_INVALID_CALL while any wrapper still
    // references a back buffer, so release this swap chain and recreate it at
    // the new size; by this point every Skia wrapper has dropped its
    // back-buffer surface and the only COM reference left is ours.
    swap_chain->swap_chain.Reset();
    HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(hwnd_ptr));
    ComPtr<IDXGIFactory4> resize_factory;
    if (SUCCEEDED(CreateDXGIFactory1(IID_PPV_ARGS(&resize_factory)))) {
      DXGI_SWAP_CHAIN_DESC1 resize_description = {};
      resize_description.Width = static_cast<UINT>(width);
      resize_description.Height = static_cast<UINT>(height);
      resize_description.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
      resize_description.SampleDesc.Count = 1;
      resize_description.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
      resize_description.BufferCount = 3;
      resize_description.Scaling = DXGI_SCALING_STRETCH;
      resize_description.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
      resize_description.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
      ComPtr<IDXGISwapChain1> recreated;
      if (SUCCEEDED(resize_factory->CreateSwapChainForHwnd(
        swap_chain->queue.Get(),
        hwnd,
        &resize_description,
        nullptr,
        nullptr,
        &recreated
      ))) {
        if (FAILED(recreated.As(&swap_chain->swap_chain))) {
          swap_chain->swap_chain.Reset();
        }
      }
    }
    if (swap_chain->swap_chain == nullptr) {
      swap_chain->last_device_removed_reason = swap_chain->device->GetDeviceRemovedReason();
      moonbit_skia_com_release(swap_chain);
      return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
    }
    swap_chain->width = static_cast<UINT>(width);
    swap_chain->height = static_cast<UINT>(height);
  }
  swap_chain->frame_index = swap_chain->swap_chain->GetCurrentBackBufferIndex();
  MoonbitSkiaSurface* new_wrapper = moonbit_skia_d3d12_wrap_back_buffer(
    gpu_context,
    swap_chain,
    width,
    height,
    origin
  );
  if (new_wrapper->surface == nullptr) {
    moonbit_skia_com_release(swap_chain);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }
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

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_vulkan_window(
  MoonbitSkiaGpuContext* context,
  uint64_t anw_ptr,
  int32_t width,
  int32_t height,
  int32_t origin,
  int32_t sample_count,
  int32_t stencil_bits
) {
  if (
    width <= 0 ||
    height <= 0 ||
    anw_ptr == 0 ||
    context == nullptr ||
    context->context == nullptr ||
    context->backend != MOONBIT_SKIA_GPU_BACKEND_VULKAN
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
#if defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  defined(MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS) && defined(__ANDROID__)
  (void)sample_count;
  (void)stencil_bits;

  auto* vk_context = static_cast<MoonbitSkiaVulkanContext*>(
    context->device
  );
  if (vk_context == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  ANativeWindow* window = reinterpret_cast<ANativeWindow*>(
    static_cast<uintptr_t>(anw_ptr)
  );

  // Create VkSurfaceKHR from the ANativeWindow
  VkAndroidSurfaceCreateInfoKHR surface_info = {};
  surface_info.sType = VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR;
  surface_info.window = window;
  VkSurfaceKHR surface = VK_NULL_HANDLE;
  VkResult err = vkCreateAndroidSurfaceKHR(
    vk_context->instance,
    &surface_info,
    nullptr,
    &surface
  );
  if (err != VK_SUCCESS || surface == VK_NULL_HANDLE) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  VkBool32 present_supported = VK_FALSE;
  err = vkGetPhysicalDeviceSurfaceSupportKHR(
    vk_context->physical_device,
    vk_context->queue_family_index,
    surface,
    &present_supported
  );
  if (err != VK_SUCCESS || present_supported != VK_TRUE) {
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Query surface capabilities
  VkSurfaceCapabilitiesKHR capabilities;
  err = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
    vk_context->physical_device,
    surface,
    &capabilities
  );
  if (err != VK_SUCCESS) {
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Select surface format (prefer RGBA8)
  uint32_t format_count = 0;
  vkGetPhysicalDeviceSurfaceFormatsKHR(
    vk_context->physical_device, surface, &format_count, nullptr
  );
  if (format_count == 0) {
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  std::vector<VkSurfaceFormatKHR> formats(format_count);
  vkGetPhysicalDeviceSurfaceFormatsKHR(
    vk_context->physical_device, surface, &format_count, formats.data()
  );
  VkFormat chosen_format = formats[0].format;
  VkColorSpaceKHR chosen_color_space = formats[0].colorSpace;
  for (const auto& f : formats) {
    if (
      f.format == VK_FORMAT_R8G8B8A8_UNORM &&
      f.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
    ) {
      chosen_format = f.format;
      chosen_color_space = f.colorSpace;
      break;
    }
  }

  // Create the swapchain
  VkSwapchainCreateInfoKHR swap_info = {};
  swap_info.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
  swap_info.surface = surface;
  swap_info.minImageCount = 2;
  swap_info.imageFormat = chosen_format;
  swap_info.imageColorSpace = chosen_color_space;
  swap_info.imageExtent.width = static_cast<uint32_t>(width);
  swap_info.imageExtent.height = static_cast<uint32_t>(height);
  swap_info.imageArrayLayers = 1;
  swap_info.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  swap_info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
  swap_info.preTransform = capabilities.currentTransform;
  swap_info.compositeAlpha = VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR;
  swap_info.presentMode = VK_PRESENT_MODE_FIFO_KHR;
  swap_info.clipped = VK_TRUE;
  VkSwapchainKHR swapchain = VK_NULL_HANDLE;
  err = vkCreateSwapchainKHR(vk_context->device, &swap_info, nullptr, &swapchain);
  if (err != VK_SUCCESS || swapchain == VK_NULL_HANDLE) {
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Get the first swapchain image
  uint32_t image_count = 0;
  vkGetSwapchainImagesKHR(vk_context->device, swapchain, &image_count, nullptr);
  if (image_count == 0) {
    vkDestroySwapchainKHR(vk_context->device, swapchain, nullptr);
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  std::vector<VkImage> images(image_count);
  vkGetSwapchainImagesKHR(
    vk_context->device, swapchain, &image_count, images.data()
  );
  auto* sc = new MoonbitSkiaVulkanSwapChain();
  sc->device = vk_context->device;
  sc->instance = vk_context->instance;
  sc->queue = vk_context->queue;
  sc->swapchain = swapchain;
  sc->surface = surface;
  sc->image_format = chosen_format;
  sc->queue_family_index = vk_context->queue_family_index;
  sc->images = std::move(images);
  if (!moonbit_skia_vulkan_prepare_swapchain(sc)) {
    moonbit_skia_vulkan_release_swapchain(sc);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  VkImage swapchain_image = sc->images[sc->current_image_index];

  // Wrap as GrVkImageInfo
  GrVkImageInfo image_info;
  image_info.fImage = swapchain_image;
  image_info.fFormat = chosen_format;
  image_info.fImageTiling = VK_IMAGE_TILING_OPTIMAL;
  image_info.fImageLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
  image_info.fImageUsageFlags = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  image_info.fSampleCount = 1;
  image_info.fLevelCount = 1;
  image_info.fCurrentQueueFamily = vk_context->queue_family_index;

  GrBackendRenderTarget backend_rt = GrBackendRenderTargets::MakeVk(
    width, height, image_info
  );

  sk_sp<SkSurface> surface_obj = SkSurfaces::WrapBackendRenderTarget(
    context->context,
    backend_rt,
    moonbit_skia_surface_origin(origin),
    moonbit_skia_vulkan_color_type(chosen_format),
    nullptr,
    nullptr
  );
  if (!surface_obj) {
    moonbit_skia_vulkan_release_swapchain(sc);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  MoonbitSkiaSurface* wrapper = moonbit_skia_surface_wrapper_with_gpu_context(
    surface_obj.release(),
    context->context
  );
  wrapper->host_present_handle = sc;
  return wrapper;
#else
  (void)anw_ptr;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

/// Create a Vulkan window surface for Linux Wayland. Takes the raw
/// `wl_display*` and `wl_surface*` handles (as UInt64) from the window
/// package's `Window::display_handle()` / `Window::window_handle()`.
/// The swapchain and SkSurface wrapping follow the same pattern as the
/// Android path; only the VkSurfaceKHR creation differs
/// (`vkCreateWaylandSurfaceKHR` vs `vkCreateAndroidSurfaceKHR`).
extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_vulkan_wayland_window(
  MoonbitSkiaGpuContext* context,
  uint64_t display_ptr,
  uint64_t surface_ptr,
  int32_t width,
  int32_t height,
  int32_t origin,
  int32_t sample_count,
  int32_t stencil_bits
) {
  if (
    width <= 0 ||
    height <= 0 ||
    display_ptr == 0 ||
    surface_ptr == 0 ||
    context == nullptr ||
    context->context == nullptr ||
    context->backend != MOONBIT_SKIA_GPU_BACKEND_VULKAN
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
#if defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  defined(MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS) && defined(__linux__) && \
  !defined(__ANDROID__)
  (void)sample_count;
  (void)stencil_bits;

  auto* vk_context = static_cast<MoonbitSkiaVulkanContext*>(
    context->device
  );
  if (vk_context == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  wl_display* wl_dpy = reinterpret_cast<wl_display*>(
    static_cast<uintptr_t>(display_ptr)
  );
  wl_surface* wl_surf = reinterpret_cast<wl_surface*>(
    static_cast<uintptr_t>(surface_ptr)
  );

  // Create VkSurfaceKHR from the Wayland display and surface
  VkWaylandSurfaceCreateInfoKHR surface_info = {};
  surface_info.sType = VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR;
  surface_info.display = wl_dpy;
  surface_info.surface = wl_surf;
  VkSurfaceKHR surface = VK_NULL_HANDLE;
  VkResult err = vkCreateWaylandSurfaceKHR(
    vk_context->instance,
    &surface_info,
    nullptr,
    &surface
  );
  if (err != VK_SUCCESS || surface == VK_NULL_HANDLE) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  VkBool32 present_supported = VK_FALSE;
  err = vkGetPhysicalDeviceSurfaceSupportKHR(
    vk_context->physical_device,
    vk_context->queue_family_index,
    surface,
    &present_supported
  );
  if (err != VK_SUCCESS || present_supported != VK_TRUE) {
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Query surface capabilities
  VkSurfaceCapabilitiesKHR capabilities;
  err = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
    vk_context->physical_device,
    surface,
    &capabilities
  );
  if (err != VK_SUCCESS) {
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Select surface format (prefer RGBA8)
  uint32_t format_count = 0;
  vkGetPhysicalDeviceSurfaceFormatsKHR(
    vk_context->physical_device, surface, &format_count, nullptr
  );
  if (format_count == 0) {
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  std::vector<VkSurfaceFormatKHR> formats(format_count);
  vkGetPhysicalDeviceSurfaceFormatsKHR(
    vk_context->physical_device, surface, &format_count, formats.data()
  );
  VkFormat chosen_format = formats[0].format;
  VkColorSpaceKHR chosen_color_space = formats[0].colorSpace;
  for (const auto& f : formats) {
    if (
      f.format == VK_FORMAT_R8G8B8A8_UNORM &&
      f.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
    ) {
      chosen_format = f.format;
      chosen_color_space = f.colorSpace;
      break;
    }
  }

  // Create the swapchain
  VkSwapchainCreateInfoKHR swap_info = {};
  swap_info.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
  swap_info.surface = surface;
  swap_info.minImageCount = 2;
  swap_info.imageFormat = chosen_format;
  swap_info.imageColorSpace = chosen_color_space;
  swap_info.imageExtent.width = static_cast<uint32_t>(width);
  swap_info.imageExtent.height = static_cast<uint32_t>(height);
  swap_info.imageArrayLayers = 1;
  swap_info.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  swap_info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
  swap_info.preTransform = capabilities.currentTransform;
  swap_info.compositeAlpha = VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR;
  swap_info.presentMode = VK_PRESENT_MODE_FIFO_KHR;
  swap_info.clipped = VK_TRUE;
  VkSwapchainKHR swapchain = VK_NULL_HANDLE;
  err = vkCreateSwapchainKHR(vk_context->device, &swap_info, nullptr, &swapchain);
  if (err != VK_SUCCESS || swapchain == VK_NULL_HANDLE) {
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Get the first swapchain image
  uint32_t image_count = 0;
  vkGetSwapchainImagesKHR(vk_context->device, swapchain, &image_count, nullptr);
  if (image_count == 0) {
    vkDestroySwapchainKHR(vk_context->device, swapchain, nullptr);
    vkDestroySurfaceKHR(vk_context->instance, surface, nullptr);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  std::vector<VkImage> images(image_count);
  vkGetSwapchainImagesKHR(
    vk_context->device, swapchain, &image_count, images.data()
  );
  auto* sc = new MoonbitSkiaVulkanSwapChain();
  sc->device = vk_context->device;
  sc->instance = vk_context->instance;
  sc->queue = vk_context->queue;
  sc->swapchain = swapchain;
  sc->surface = surface;
  sc->image_format = chosen_format;
  sc->queue_family_index = vk_context->queue_family_index;
  sc->images = std::move(images);
  if (!moonbit_skia_vulkan_prepare_swapchain(sc)) {
    moonbit_skia_vulkan_release_swapchain(sc);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  VkImage swapchain_image = sc->images[sc->current_image_index];

  // Wrap as GrVkImageInfo
  GrVkImageInfo image_info;
  image_info.fImage = swapchain_image;
  image_info.fFormat = chosen_format;
  image_info.fImageTiling = VK_IMAGE_TILING_OPTIMAL;
  image_info.fImageLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
  image_info.fImageUsageFlags = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  image_info.fSampleCount = 1;
  image_info.fLevelCount = 1;
  image_info.fCurrentQueueFamily = vk_context->queue_family_index;

  GrBackendRenderTarget backend_rt = GrBackendRenderTargets::MakeVk(
    width, height, image_info
  );

  sk_sp<SkSurface> surface_obj = SkSurfaces::WrapBackendRenderTarget(
    context->context,
    backend_rt,
    moonbit_skia_surface_origin(origin),
    moonbit_skia_vulkan_color_type(chosen_format),
    nullptr,
    nullptr
  );
  if (!surface_obj) {
    moonbit_skia_vulkan_release_swapchain(sc);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  MoonbitSkiaSurface* wrapper = moonbit_skia_surface_wrapper_with_gpu_context(
    surface_obj.release(),
    context->context
  );
  wrapper->host_present_handle = sc;
  return wrapper;
#else
  (void)display_ptr;
  (void)surface_ptr;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_vulkan_present_and_acquire_next(
  MoonbitSkiaSurface* wrapper,
  uint64_t anw_ptr,
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
#if defined(MOUI_SKIA_ENABLE_GPU_VULKAN) && \
  defined(MOUI_SKIA_HAS_GANESH_VULKAN_HEADERS)
  (void)anw_ptr;
  (void)sample_count;
  (void)stencil_bits;

  auto* sc = static_cast<MoonbitSkiaVulkanSwapChain*>(
    wrapper->host_present_handle
  );
  GrDirectContext* gpu_context = wrapper->gpu_context_owner;

  // Skia has queued rendering work on the same graphics queue. Submit a
  // lightweight signal-only batch so presentation waits for that work without
  // reading pixels back to the CPU.
  GrFlushInfo flush_info;
  gpu_context->flush(
    wrapper->surface,
    SkSurfaces::BackendSurfaceAccess::kPresent,
    flush_info
  );
  if (!gpu_context->submit()) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }
  if (sc == nullptr || sc->images.empty() ||
    sc->current_image_index >= sc->images.size() ||
    sc->render_finished == VK_NULL_HANDLE) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }
  VkFence current_fence = sc->image_fences[sc->current_image_index];
  vkResetFences(sc->device, 1, &current_fence);
  VkSubmitInfo submit_info = {};
  submit_info.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
  submit_info.signalSemaphoreCount = 1;
  submit_info.pSignalSemaphores = &sc->render_finished;
  VkResult err = vkQueueSubmit(sc->queue, 1, &submit_info, current_fence);
  if (err != VK_SUCCESS) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  // Present the image that was acquired before rendering. The semaphore is
  // signaled by the queue after Skia's submitted work.
  VkPresentInfoKHR present_info = {};
  present_info.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
  present_info.waitSemaphoreCount = 1;
  present_info.pWaitSemaphores = &sc->render_finished;
  present_info.swapchainCount = 1;
  present_info.pSwapchains = &sc->swapchain;
  uint32_t image_index = sc->current_image_index;
  present_info.pImageIndices = &image_index;
  err = vkQueuePresentKHR(sc->queue, &present_info);
  if (err == VK_ERROR_OUT_OF_DATE_KHR || err == VK_ERROR_DEVICE_LOST) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }
  if (err != VK_SUCCESS && err != VK_SUBOPTIMAL_KHR) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  // Acquire and fence the next image before wrapping its backend resource.
  if (!moonbit_skia_vulkan_acquire_next(sc)) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }
  image_index = sc->current_image_index;
  if (image_index >= sc->images.size()) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }
  VkImage next_image = sc->images[image_index];

  // Release the old surface; the swapchain state is moved to the new wrapper.
  wrapper->surface->unref();
  wrapper->surface = nullptr;
  wrapper->host_present_handle = nullptr;

  // Wrap the next swapchain image as a new SkSurface
  GrVkImageInfo image_info;
  image_info.fImage = next_image;
  image_info.fFormat = sc->image_format;
  image_info.fImageTiling = VK_IMAGE_TILING_OPTIMAL;
  image_info.fImageLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
  image_info.fImageUsageFlags = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  image_info.fSampleCount = 1;
  image_info.fLevelCount = 1;
  image_info.fCurrentQueueFamily = sc->queue_family_index;

  GrBackendRenderTarget backend_rt = GrBackendRenderTargets::MakeVk(
    width, height, image_info
  );

  sk_sp<SkSurface> next_surface = SkSurfaces::WrapBackendRenderTarget(
    gpu_context,
    backend_rt,
    moonbit_skia_surface_origin(origin),
    moonbit_skia_vulkan_color_type(sc->image_format),
    nullptr,
    nullptr
  );
  if (!next_surface) {
    moonbit_skia_vulkan_release_swapchain(sc);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  MoonbitSkiaSurface* new_wrapper =
    moonbit_skia_surface_wrapper_with_gpu_context(
      next_surface.release(),
      gpu_context
    );
  new_wrapper->host_present_handle = sc;
  return new_wrapper;
#else
  (void)anw_ptr;
  (void)width;
  (void)height;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_egl_window(
  MoonbitSkiaGpuContext* context,
  uint64_t native_window_ptr,
  int32_t width,
  int32_t height,
  int32_t origin,
  int32_t sample_count,
  int32_t stencil_bits
) {
  if (
    width <= 0 ||
    height <= 0 ||
    native_window_ptr == 0 ||
    context == nullptr ||
    context->context == nullptr ||
    context->backend != MOONBIT_SKIA_GPU_BACKEND_EGL
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
#if defined(MOUI_SKIA_ENABLE_GPU_EGL) && \
  defined(MOUI_SKIA_HAS_GANESH_EGL_HEADERS)
  (void)sample_count;
  (void)stencil_bits;

  auto* egl_context = static_cast<MoonbitSkiaEglContext*>(context->device);
  if (egl_context == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  MoonbitSkiaEglNativeWindow* window = reinterpret_cast<MoonbitSkiaEglNativeWindow*>(
    static_cast<uintptr_t>(native_window_ptr)
  );
  if (window == nullptr) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

#if defined(__OHOS__)
  // XComponent native windows need geometry + GPU usage flags before
  // eglCreateWindowSurface; without them HVD often presents pure black.
  (void)OH_NativeWindow_NativeWindowHandleOpt(
    window, SET_BUFFER_GEOMETRY, width, height
  );
  (void)OH_NativeWindow_NativeWindowHandleOpt(
    window, SET_FORMAT, NATIVEBUFFER_PIXEL_FMT_RGBA_8888
  );
  (void)OH_NativeWindow_NativeWindowHandleOpt(
    window,
    SET_USAGE,
    static_cast<uint64_t>(
      NATIVEBUFFER_USAGE_HW_RENDER |
      NATIVEBUFFER_USAGE_HW_TEXTURE |
      NATIVEBUFFER_USAGE_MEM_DMA
    )
  );
#endif

  // Create an EGL window surface from the platform native window.
  const EGLint surface_attribs[] = {
    EGL_RENDER_BUFFER, EGL_BACK_BUFFER,
    EGL_NONE,
  };
  EGLSurface egl_surface = eglCreateWindowSurface(
    egl_context->display,
    egl_context->config,
    reinterpret_cast<EGLNativeWindowType>(window),
    surface_attribs
  );
  if (egl_surface == EGL_NO_SURFACE) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  // Make the new surface current so Skia can issue GL commands against it.
  if (!eglMakeCurrent(
        egl_context->display, egl_surface, egl_surface, egl_context->context
      )) {
    eglDestroySurface(egl_context->display, egl_surface);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }
  (void)eglSwapInterval(egl_context->display, 1);

  // Query the framebuffer object id that Skia will render into. On EGL with
  // a window surface, the default framebuffer is 0 (the window surface's
  // back buffer).
  GrGLFramebufferInfo fb_info;
  fb_info.fFBOID = 0;
  fb_info.fFormat = GL_RGBA8;

  // Skia signature: MakeGL(width, height, sampleCnt, stencilBits, info).
  // Stencil must be 0/8/16 when wrapping; default FBO uses 0 samples/stencil
  // (match skia_stub_gpu_worker.cpp).
  int32_t actual_samples = sample_count > 0 ? sample_count : 0;
  int32_t actual_stencil = stencil_bits;
  if (actual_stencil != 0 && actual_stencil != 8 && actual_stencil != 16) {
    actual_stencil = 0;
  }
  GrBackendRenderTarget backend_rt = GrBackendRenderTargets::MakeGL(
    width, height, actual_samples, actual_stencil, fb_info
  );

  // GLES window default FBO is bottom-left. TopLeft on HostGpu presented
  // upside-down on HVD once eglSwapBuffers was actually working.
  const GrSurfaceOrigin wrap_origin = kBottomLeft_GrSurfaceOrigin;
  (void)origin;
  sk_sp<SkSurface> surface_obj = SkSurfaces::WrapBackendRenderTarget(
    context->context,
    backend_rt,
    wrap_origin,
    kRGBA_8888_SkColorType,
    nullptr,
    nullptr
  );
  if (!surface_obj) {
    eglMakeCurrent(
      egl_context->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT
    );
    eglDestroySurface(egl_context->display, egl_surface);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
  }

  MoonbitSkiaSurface* wrapper = moonbit_skia_surface_wrapper_with_gpu_context(
    surface_obj.release(),
    context->context
  );
  auto* egl_win = new MoonbitSkiaEglWindow();
  egl_win->display = egl_context->display;
  egl_win->context = egl_context->context;
  egl_win->surface = egl_surface;
  wrapper->host_present_handle = egl_win;
  return wrapper;
#else
  (void)native_window_ptr;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;
  return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, nullptr);
#endif
}

extern "C" MOONBIT_FFI_EXPORT MoonbitSkiaSurface*
moonbit_skia_surface_egl_present_and_acquire_next(
  MoonbitSkiaSurface* wrapper,
  uint64_t native_window_ptr,
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
#if defined(MOUI_SKIA_ENABLE_GPU_EGL) && \
  defined(MOUI_SKIA_HAS_GANESH_EGL_HEADERS)
  (void)native_window_ptr;
  (void)width;
  (void)height;
  (void)origin;
  (void)sample_count;
  (void)stencil_bits;

  auto* egl_win = static_cast<MoonbitSkiaEglWindow*>(
    wrapper->host_present_handle
  );
  GrDirectContext* gpu_context = wrapper->gpu_context_owner;

  // Keep the window surface current across present; some OHOS drivers reject
  // eglSwapBuffers when the context is not current on that surface.
  if (
    egl_win->context != EGL_NO_CONTEXT &&
    !eglMakeCurrent(
      egl_win->display, egl_win->surface, egl_win->surface, egl_win->context
    )
  ) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  // eglSwapBuffers swaps the back buffer to the window surface's front
  // buffer. The same EGLSurface is reused across frames; no need to acquire
  // a new one. Return a fresh SkSurface wrapper around the same back buffer.
  EGLBoolean swapped = eglSwapBuffers(egl_win->display, egl_win->surface);
#if defined(MOUI_SKIA_EGL_HAS_HILOG)
  // Distinguish true GPU direct present from CPU "present flushed native window".
  static int s_egl_present_log_count = 0;
  if (s_egl_present_log_count < 4) {
    s_egl_present_log_count += 1;
    OH_LOG_Print(
      LOG_APP,
      swapped == EGL_TRUE ? LOG_INFO : LOG_WARN,
      0x4D4F,
      "MoUIHarmony",
      "egl present ok=%{public}d swap=%{public}d w=%{public}d h=%{public}d",
      swapped == EGL_TRUE ? 1 : 0,
      static_cast<int>(swapped),
      width,
      height
    );
  }
#endif
  if (swapped != EGL_TRUE) {
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  // Release the old SkSurface. Transfer host_present_handle ownership to the
  // next wrapper BEFORE the MoonBit finalizer runs on this wrapper — otherwise
  // moonbit_skia_egl_release_window destroys the live EGL window surface and
  // the XComponent goes black after the first frame.
  wrapper->surface->unref();
  wrapper->surface = nullptr;
  wrapper->host_present_handle = nullptr;

  // Re-wrap the new back buffer as a fresh SkSurface. The framebuffer id
  // remains 0 (window surface default framebuffer).
  GrGLFramebufferInfo fb_info;
  fb_info.fFBOID = 0;
  fb_info.fFormat = GL_RGBA8;

  int32_t actual_samples = sample_count > 0 ? sample_count : 0;
  int32_t actual_stencil = stencil_bits;
  if (actual_stencil != 0 && actual_stencil != 8 && actual_stencil != 16) {
    actual_stencil = 0;
  }
  GrBackendRenderTarget backend_rt = GrBackendRenderTargets::MakeGL(
    width, height, actual_samples, actual_stencil, fb_info
  );

  const GrSurfaceOrigin wrap_origin = kBottomLeft_GrSurfaceOrigin;
  (void)origin;
  sk_sp<SkSurface> next_surface = SkSurfaces::WrapBackendRenderTarget(
    gpu_context,
    backend_rt,
    wrap_origin,
    kRGBA_8888_SkColorType,
    nullptr,
    nullptr
  );
  if (!next_surface) {
    moonbit_skia_egl_release_window(egl_win);
    return moonbit_skia_surface_wrapper_with_gpu_context(nullptr, gpu_context);
  }

  // Re-bind so subsequent Skia draws target the window back buffer.
  (void)eglMakeCurrent(
    egl_win->display, egl_win->surface, egl_win->surface, egl_win->context
  );

  MoonbitSkiaSurface* new_wrapper =
    moonbit_skia_surface_wrapper_with_gpu_context(
      next_surface.release(),
      gpu_context
    );
  new_wrapper->host_present_handle = egl_win;
  return new_wrapper;
#else
  (void)native_window_ptr;
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
#if (defined(MOUI_SKIA_ENABLE_GPU_METAL) || defined(MOUI_SKIA_ENABLE_GPU_D3D) || defined(MOUI_SKIA_ENABLE_GPU_VULKAN) || defined(MOUI_SKIA_ENABLE_GPU_EGL)) && \
  defined(MOUI_SKIA_HAS_GANESH_DIRECT_CONTEXT)
#if defined(MOUI_SKIA_ENABLE_GPU_EGL) && defined(MOUI_SKIA_HAS_GANESH_EGL_HEADERS)
  // HostGpu EGL draws must target the window surface. If anything uncurrented
  // the context (bootstrap pbuffer, other GL), flush would hit the wrong FBO.
  if (wrapper->host_present_handle != nullptr) {
    auto* egl_win = static_cast<MoonbitSkiaEglWindow*>(
      wrapper->host_present_handle
    );
    if (
      egl_win != nullptr &&
      egl_win->display != EGL_NO_DISPLAY &&
      egl_win->surface != EGL_NO_SURFACE &&
      egl_win->context != EGL_NO_CONTEXT
    ) {
      (void)eglMakeCurrent(
        egl_win->display, egl_win->surface, egl_win->surface, egl_win->context
      );
    }
  }
#endif
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
