#if defined(__ANDROID__) && defined(MOUI_SKIA_ENABLE_GPU_VULKAN)
#include "android_vulkan_loader.h"

#include <dlfcn.h>
#include <mutex>

PFN_vkAcquireNextImageKHR vkAcquireNextImageKHR = nullptr;
PFN_vkCreateAndroidSurfaceKHR vkCreateAndroidSurfaceKHR = nullptr;
PFN_vkCreateDevice vkCreateDevice = nullptr;
PFN_vkCreateFence vkCreateFence = nullptr;
PFN_vkCreateInstance vkCreateInstance = nullptr;
PFN_vkCreateSemaphore vkCreateSemaphore = nullptr;
PFN_vkCreateSwapchainKHR vkCreateSwapchainKHR = nullptr;
PFN_vkDestroyDevice vkDestroyDevice = nullptr;
PFN_vkDestroyFence vkDestroyFence = nullptr;
PFN_vkDestroyInstance vkDestroyInstance = nullptr;
PFN_vkDestroySemaphore vkDestroySemaphore = nullptr;
PFN_vkDestroySurfaceKHR vkDestroySurfaceKHR = nullptr;
PFN_vkDestroySwapchainKHR vkDestroySwapchainKHR = nullptr;
PFN_vkDeviceWaitIdle vkDeviceWaitIdle = nullptr;
PFN_vkEnumeratePhysicalDevices vkEnumeratePhysicalDevices = nullptr;
PFN_vkGetDeviceProcAddr vkGetDeviceProcAddr = nullptr;
PFN_vkGetDeviceQueue vkGetDeviceQueue = nullptr;
PFN_vkGetInstanceProcAddr vkGetInstanceProcAddr = nullptr;
PFN_vkGetPhysicalDeviceQueueFamilyProperties vkGetPhysicalDeviceQueueFamilyProperties = nullptr;
PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR vkGetPhysicalDeviceSurfaceCapabilitiesKHR = nullptr;
PFN_vkGetPhysicalDeviceSurfaceFormatsKHR vkGetPhysicalDeviceSurfaceFormatsKHR = nullptr;
PFN_vkGetPhysicalDeviceSurfaceSupportKHR vkGetPhysicalDeviceSurfaceSupportKHR = nullptr;
PFN_vkGetSwapchainImagesKHR vkGetSwapchainImagesKHR = nullptr;
PFN_vkQueuePresentKHR vkQueuePresentKHR = nullptr;
PFN_vkQueueSubmit vkQueueSubmit = nullptr;
PFN_vkResetFences vkResetFences = nullptr;
PFN_vkWaitForFences vkWaitForFences = nullptr;

namespace {

std::once_flag vulkan_load_once;
bool vulkan_loaded = false;
void* vulkan_library = nullptr;

template <typename T>
bool load_vulkan_symbol(T* target, const char* name) {
  *target = reinterpret_cast<T>(dlsym(vulkan_library, name));
  return *target != nullptr;
}

void load_vulkan() {
  vulkan_library = dlopen("libvulkan.so", RTLD_NOW | RTLD_LOCAL);
  if (vulkan_library == nullptr) {
    return;
  }
#define MOUI_LOAD_VULKAN(name) load_vulkan_symbol(&name, #name)
  vulkan_loaded =
    MOUI_LOAD_VULKAN(vkAcquireNextImageKHR) &&
    MOUI_LOAD_VULKAN(vkCreateAndroidSurfaceKHR) &&
    MOUI_LOAD_VULKAN(vkCreateDevice) &&
    MOUI_LOAD_VULKAN(vkCreateFence) &&
    MOUI_LOAD_VULKAN(vkCreateInstance) &&
    MOUI_LOAD_VULKAN(vkCreateSemaphore) &&
    MOUI_LOAD_VULKAN(vkCreateSwapchainKHR) &&
    MOUI_LOAD_VULKAN(vkDestroyDevice) &&
    MOUI_LOAD_VULKAN(vkDestroyFence) &&
    MOUI_LOAD_VULKAN(vkDestroyInstance) &&
    MOUI_LOAD_VULKAN(vkDestroySemaphore) &&
    MOUI_LOAD_VULKAN(vkDestroySurfaceKHR) &&
    MOUI_LOAD_VULKAN(vkDestroySwapchainKHR) &&
    MOUI_LOAD_VULKAN(vkDeviceWaitIdle) &&
    MOUI_LOAD_VULKAN(vkEnumeratePhysicalDevices) &&
    MOUI_LOAD_VULKAN(vkGetDeviceProcAddr) &&
    MOUI_LOAD_VULKAN(vkGetDeviceQueue) &&
    MOUI_LOAD_VULKAN(vkGetInstanceProcAddr) &&
    MOUI_LOAD_VULKAN(vkGetPhysicalDeviceQueueFamilyProperties) &&
    MOUI_LOAD_VULKAN(vkGetPhysicalDeviceSurfaceCapabilitiesKHR) &&
    MOUI_LOAD_VULKAN(vkGetPhysicalDeviceSurfaceFormatsKHR) &&
    MOUI_LOAD_VULKAN(vkGetPhysicalDeviceSurfaceSupportKHR) &&
    MOUI_LOAD_VULKAN(vkGetSwapchainImagesKHR) &&
    MOUI_LOAD_VULKAN(vkQueuePresentKHR) &&
    MOUI_LOAD_VULKAN(vkQueueSubmit) &&
    MOUI_LOAD_VULKAN(vkResetFences) &&
    MOUI_LOAD_VULKAN(vkWaitForFences);
#undef MOUI_LOAD_VULKAN
  if (!vulkan_loaded) {
    dlclose(vulkan_library);
    vulkan_library = nullptr;
  }
}

}  // namespace

bool moui_skia_android_vulkan_load() {
  std::call_once(vulkan_load_once, load_vulkan);
  return vulkan_loaded;
}
#endif
