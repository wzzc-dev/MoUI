///|
/// Build a `PlatformViewPlugin` (kind `"web_view"`) for the Windows WebView2
/// native bridge. The command queue holds pending LoadUrl/Reload/etc.
/// commands enqueued by the app; the host passes the window's HWND at call
/// time. Events are decoded from the native bridge into
/// `@core.PlatformViewEvent` and handed to the host callback directly.
pub fn create_windows_webview_plugin(
  commands : @host.HostWebViewCommandQueue,
) -> @moui_host.PlatformViewPlugin {
  let capabilities_summary = if windows_webview_native_available() != 0 {
    "available"
  } else {
    "unavailable"
  }
  @moui_host.PlatformViewPlugin::new(
    kind="web_view",
    capabilities_summary~,
    install_event_dispatcher=fn(callback) {
      windows_webview_install_event_callback(
        fn(cb, hwnd, kind, id, url, detail, flag) {
          cb(hwnd, kind, id, url, detail, flag)
        },
        (hwnd, kind, id, url, detail, flag) => {
          let id_str = @host.webview_decode_ffi_string(id)
          let web_event = @host.webview_decode_native_event(
            kind, url, detail, flag,
          )
          let platform_event = @host.WebViewEvent::to_platform_event(web_event)
          callback(hwnd, id_str, platform_event)
        },
      )
    },
    sync_platform_views=fn(hwnd, frame, _offset_y) {
      windows_webview_platform_views_begin(hwnd)
      for placement in frame.platform_views {
        if placement.kind == "web_view" {
          windows_webview_sync(
            hwnd,
            @host.webview_encode_ffi_string(placement.id),
            @host.webview_encode_ffi_string(placement.property_or("url", "")),
            @host.webview_encode_ffi_string(placement.property_or("title", "")),
            @host.webview_native_policy_code(
              @host.WebViewNavigationPolicy::from_wire_value(
                placement.property_or("policy", "http-https-file"),
              ),
            ),
            placement.frame.origin.x,
            placement.frame.origin.y,
            placement.frame.size.width,
            placement.frame.size.height,
          )
          match frame.overlay_bounds {
            Some(bounds) => windows_webview_sync_overlay_mask(
              hwnd,
              1,
              bounds.origin.x,
              bounds.origin.y,
              bounds.size.width,
              bounds.size.height,
            )
            None => windows_webview_sync_overlay_mask(hwnd, 0, 0.0, 0.0, 0.0, 0.0)
          }
        }
      }
      windows_webview_platform_views_end(hwnd)
    },
    drain_commands=fn(hwnd) {
      ignore(
        commands.drain_with_handler(command => {
          let (kind, text, detail) = @host.webview_encode_native_command(
            command.command,
          )
          windows_webview_command(
            hwnd,
            @host.webview_encode_ffi_string(command.id),
            kind,
            @host.webview_encode_ffi_string(text),
            @host.webview_encode_ffi_string(detail),
          )
        }),
      )
    },
    dispose_platform_views=fn(hwnd) {
      windows_webview_platform_views_dispose(hwnd)
    },
    setup_platform_view_draw=None,
    poll_native=None,
  )
}
