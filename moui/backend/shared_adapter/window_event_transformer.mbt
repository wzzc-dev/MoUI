///|
/// Shared transformer for a subset of `@window_core.WindowEvent` variants
/// that have fully cross-platform semantics. Events carrying platform-
/// specific payloads (Pointer, Keyboard, Ime, Drag, Modifiers) are
/// dispatched through `@host.window_event_to_host_event` directly by
/// each platform's app_handler and are NOT transformed here.
///
/// This keeps the shared adapter focused on truly shared logic and avoids
/// losing semantic information in the translation.

///|
/// Result of transforming a cross-platform `WindowEvent`.
pub(all) enum TransformedWindowEvent {
  /// Forward a `HostEvent` to the runtime driver.
  DispatchHostEvent(@host.HostEvent)
  /// Request a full window redraw (from `RedrawRequested`).
  WindowRedrawRequired
  /// Window should be closed and its resources released.
  CloseRequested
  /// No action needed or event was platform-specific.
  PlatformSpecific
}

///|
/// Transform a cross-platform `WindowEvent` that carries no platform-
/// specific payload. Events that require native decode (pointer, keyboard,
/// IME, drag, modifiers) return `PlatformSpecific` — the caller's
/// platform-local handler should process them directly via
/// `@host.window_event_to_host_event`.
///
/// The `scale_factor` and `surface_size` parameters are only meaningful
/// for `SurfaceResized` and `ScaleFactorChanged` events; they are ignored
/// for other event types.
pub fn transform_cross_platform_event(
  event : @window_core.WindowEvent,
  scale_factor~ : Double,
  surface_size? : @dpi.PhysicalSize? = None,
) -> TransformedWindowEvent {
  match event {
    @window_core.WindowEvent::CloseRequested =>
      TransformedWindowEvent::CloseRequested
    @window_core.WindowEvent::SurfaceResized(_) =>
      make_resized_event(scale_factor, surface_size)
    @window_core.WindowEvent::ScaleFactorChanged(_, _) =>
      make_resized_event(scale_factor, surface_size)
    @window_core.WindowEvent::Focused(focused) =>
      TransformedWindowEvent::DispatchHostEvent(
        @host.HostEvent::Focus(@host.HostFocusEvent::new(focused~)),
      )
    @window_core.WindowEvent::RedrawRequested =>
      TransformedWindowEvent::WindowRedrawRequired
    // Platform-specific events: the caller must dispatch via
    // `@host.window_event_to_host_event` for proper handling.
    @window_core.WindowEvent::PointerMoved(_)
    | @window_core.WindowEvent::PointerButton(_)
    | @window_core.WindowEvent::DragEntered(_)
    | @window_core.WindowEvent::DragMoved(_)
    | @window_core.WindowEvent::DragDropped(_)
    | @window_core.WindowEvent::DragLeft(_)
    | @window_core.WindowEvent::KeyboardInput(_)
    | @window_core.WindowEvent::Ime(_)
    | @window_core.WindowEvent::ModifiersChanged(_) =>
      TransformedWindowEvent::PlatformSpecific
    _ => TransformedWindowEvent::PlatformSpecific
  }
}

///|
fn make_resized_event(
  scale_factor : Double,
  surface_size : @dpi.PhysicalSize?,
) -> TransformedWindowEvent {
  match surface_size {
    Some(size) =>
      TransformedWindowEvent::DispatchHostEvent(
        @host.HostEvent::Resized(
          @host.surface_metrics_from_physical(size, scale_factor~),
        ),
      )
    None => TransformedWindowEvent::PlatformSpecific
  }
}

///|
/// Compute `HostSurfaceMetrics` from a physical size and scale factor.
/// Convenience wrapper for callers that need the metrics outside of
/// the event transformer.
pub fn make_surface_metrics(
  size : @dpi.PhysicalSize,
  scale_factor~ : Double,
) -> @host.HostSurfaceMetrics {
  @host.surface_metrics_from_physical(size, scale_factor~)
}

///|
/// Cross-platform handler for pointer position normalization.
/// Every platform normalizes native pointer positions to logical
/// coordinates for the runtime.
pub fn normalize_pointer_position(
  position : @dpi.PhysicalPositionF64,
  scale_factor~ : Double,
) -> @core.Point {
  @host.physical_position_to_core(position, scale_factor~)
}
