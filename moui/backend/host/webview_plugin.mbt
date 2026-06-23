///|
/// Platform-agnostic webview plugin interface.
///
/// Each platform backend can hold an optional `WebviewPlugin` to support
/// native WebView embedding without a compile-time dependency on
/// `moui_webview`. The concrete plugin factory is provided by
/// `moui_webview/backend/<platform>` and wired in by the user at startup.
///
/// All webview-specific data flows through generic string/bool parameters,
/// keeping this contract free of moui_webview types.

///|
/// Callback invoked by the native event dispatcher when a WebView fires an
/// event. The parameters carry the decoded payload that the host should
/// convert into `@core.PlatformViewEvent::Named(name, value, detail, flag)`
/// and dispatch as `@core.AppEvent::PlatformView(id, ...)`.
/// Parameters: (window_ptr, id, name, value, detail, flag)
pub type WebViewEventCallback = (UInt64, String, String, String, String, Bool) -> Unit

///|
/// Platform-agnostic webview host plugin. Holds callbacks for every
/// touchpoint between the MoUI rendering loop and a native WebView.
///
/// - `capabilities_summary` – human-readable description of the webview
///   backend (e.g. `"available"` / `"unavailable"`).
/// - `install_event_dispatcher` – called once at app startup to wire the
///   native event callback.
/// - `sync_platform_views` – called each redraw to position/resize native
///   webviews to match the current layout frame.
/// - `drain_commands` – called each redraw to flush queued commands
///   (LoadUrl, Reload, etc.) to the native bridge.
/// - `dispose_platform_views` – called when a window is torn down.
/// - `setup_platform_view_draw` – optional callback used by the Linux
///   offscreen-rendering path to inject a pixel-draw function between
///   command rendering and buffer flush. Returns the previously installed
///   callback (if any) for save/restore. `None` on macOS/Windows.
pub struct WebviewPlugin {
  capabilities_summary : String
  install_event_dispatcher : (WebViewEventCallback) -> Unit
  sync_platform_views : (UInt64, @core.DrawFrame, Double) -> Unit
  drain_commands : (UInt64) -> Unit
  dispose_platform_views : (UInt64) -> Unit
  setup_platform_view_draw : ((HostWindowRenderer, @core.DrawFrame, Double) -> Unit)?
}

///|
pub fn WebviewPlugin::new(
  capabilities_summary~ : String,
  install_event_dispatcher~ : (WebViewEventCallback) -> Unit,
  sync_platform_views~ : (UInt64, @core.DrawFrame, Double) -> Unit,
  drain_commands~ : (UInt64) -> Unit,
  dispose_platform_views~ : (UInt64) -> Unit,
  setup_platform_view_draw? : ((HostWindowRenderer, @core.DrawFrame, Double) -> Unit)? = None,
) -> WebviewPlugin {
  {
    capabilities_summary,
    install_event_dispatcher,
    sync_platform_views,
    drain_commands,
    dispose_platform_views,
    setup_platform_view_draw,
  }
}
