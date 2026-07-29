///|
/// Platform capabilities that the shared adapter uses to adapt its behavior
/// per platform. Rather than branching on platform identity, the shared
/// transformer branches on the declared capability.
///
/// Each platform entrypoint constructs its own `PlatformCapabilities`
/// instance inline with explicit capability declarations. The struct
/// is intentionally not derived with Eq or ToJson to discourage enum-style
/// platform comparison — use the capability booleans directly.
pub(all) struct PlatformCapabilities {
  /// Whether the platform supports a client-decorated titlebar.
  has_client_titlebar : Bool
  /// Surface attach/detach lifecycle: `true` when the window surface is
  /// ephemeral and can be recreated (XComponent, Wayland, Web).
  ephemeral_surface : Bool
  /// Platform has a native event loop pacing mechanism (Choreographer,
  /// UIKit, Win32 message queue, CDP).
  has_native_event_pacing : Bool
  /// Whether the platform supports GPU surface directly (Metal, Vulkan,
  /// EGL, D3D12).
  supports_gpu_surface : Bool
}

///|
pub fn PlatformCapabilities::default() -> PlatformCapabilities {
  {
    has_client_titlebar: false,
    ephemeral_surface: false,
    has_native_event_pacing: true,
    supports_gpu_surface: true,
  }
}
