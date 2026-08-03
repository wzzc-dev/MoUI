///|
/// Platform-agnostic platform-view plugin contract.
///
/// Each platform backend holds a list of `PlatformViewPlugin`s to support
/// native platform-view embedding (web views, video, maps, …) without a
/// compile-time dependency on the addon package that implements them. The
/// concrete plugin factory lives in `<addon>/backend/<platform>` and is wired
/// in by the user at startup through the platform host options'
/// `platform_view_plugins`
/// list.
///
/// All data flows through `@core` types (`DrawFrame`, `PlatformViewEvent`,
/// `PlatformViewPlacement`) plus the native window handle (`UInt64`), keeping
/// this contract free of addon-specific types. A plugin matches a placement by
/// `kind` (e.g. `"web_view"`); placements with other `kind`s are ignored.

///|
/// Callback invoked by the native event dispatcher when a platform view fires
/// an event. Parameters: (native window handle, platform-view id, event).
/// The host converts the handle to a `HostWindowId`, then dispatches the event
/// as `@core.AppEvent::PlatformView(id, event)`.
pub type PlatformViewEventCallback = (UInt64, String, @core.PlatformViewEvent) -> Unit

///|
/// Platform-agnostic platform-view host plugin. Holds callbacks for every
/// touchpoint between the MoUI rendering loop and a native platform view.
///
/// - `kind` – the `PlatformViewPlacement.kind` this plugin owns (e.g.
///   `"web_view"`). Used to filter `frame.platform_views` and to route
///   native events. Two plugins must not share a `kind`.
/// - `capabilities_summary` – human-readable description of the backend
///   (e.g. `"available"` / `"unavailable"`).
/// - `install_event_dispatcher` – called once at app startup to wire the
///   native event callback.
/// - `sync_platform_views` – called each redraw to position/resize native
///   views to match the current layout frame. The plugin filters
///   `frame.platform_views` by its own `kind`.
/// - `drain_commands` – called each redraw to flush queued commands
///   (LoadUrl, Reload, etc.) to the native bridge.
/// - `dispose_platform_views` – called when a window is torn down.
/// - `setup_platform_view_draw` – optional callback used by the Linux
///   offscreen-rendering path to inject a pixel-draw function between
///   command rendering and buffer flush. Receives the native window handle,
///   the renderer, the current frame, and the content offset. `None` on
///   macOS/Windows.
/// - `poll_native` – optional native event-pump probe used by backends whose
///   platform view runs a nested event loop (Linux WebKitGTK). Returns the
///   absolute deadline (ms) of the next outstanding native work, or `None`
///   when there is nothing pending. The host uses the earliest non-`None`
///   deadline to keep the event loop spinning via `ControlFlow::wait_until`;
///   `None` on macOS/Windows.
pub struct PlatformViewPlugin {
  kind : String
  capabilities_summary : String
  install_event_dispatcher : (PlatformViewEventCallback) -> Unit
  sync_platform_views : (UInt64, @core.DrawFrame, Double) -> Unit
  drain_commands : (UInt64) -> Unit
  dispose_platform_views : (UInt64) -> Unit
  setup_platform_view_draw : ((
    UInt64,
    @core.DrawFrame,
    Double,
    ((@core.PlatformViewPixelSink) -> Unit) -> Unit,
  ) -> Unit)?
  poll_native : (() -> Int64?)?
}

///|
pub fn PlatformViewPlugin::new(
  kind~ : String,
  capabilities_summary~ : String,
  install_event_dispatcher~ : (PlatformViewEventCallback) -> Unit,
  sync_platform_views~ : (UInt64, @core.DrawFrame, Double) -> Unit,
  drain_commands~ : (UInt64) -> Unit,
  dispose_platform_views~ : (UInt64) -> Unit,
  setup_platform_view_draw? : ((
    UInt64,
    @core.DrawFrame,
    Double,
    ((@core.PlatformViewPixelSink) -> Unit) -> Unit,
  ) -> Unit)? = None,
  poll_native? : (() -> Int64?)? = None,
) -> PlatformViewPlugin {
  {
    kind,
    capabilities_summary,
    install_event_dispatcher,
    sync_platform_views,
    drain_commands,
    dispose_platform_views,
    setup_platform_view_draw,
    poll_native,
  }
}

///|
/// Earliest next-work deadline reported by any plugin's `poll_native`, in ms.
/// `None` when no plugin has pending native work. Backends use this to pick
/// between `ControlFlow::Wait` and `ControlFlow::wait_until(deadline)` (e.g.
/// Linux `about_to_wait`).
pub fn platform_view_plugins_next_deadline(
  plugins : Array[PlatformViewPlugin],
) -> Int64? {
  let mut earliest : Int64? = None
  for plugin in plugins {
    match plugin.poll_native {
      Some(poll) =>
        match poll() {
          Some(deadline) =>
            match earliest {
              Some(current) =>
                if deadline < current {
                  earliest = Some(deadline)
                }
              None => earliest = Some(deadline)
            }
          None => ()
        }
      None => ()
    }
  }
  earliest
}
