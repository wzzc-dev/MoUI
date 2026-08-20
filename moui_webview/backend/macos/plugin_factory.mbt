///|
/// Build a `PlatformViewPlugin` (kind `"web_view"`) for the macOS native
/// WKWebView bridge. The command queue holds pending LoadUrl/Reload/etc.
/// commands enqueued by the app; the window handle is passed at call time by
/// the host. Events are decoded from the native bridge into
/// `@core.PlatformViewEvent` and handed to the host callback directly, so the
/// host never re-packs the payload.
pub fn create_macos_webview_plugin(
  commands : @host.HostWebViewCommandQueue,
) -> @moui_host.PlatformViewPlugin {
  let capabilities_summary = if macos_webview_native_available() != 0 {
    "available"
  } else {
    "unavailable"
  }
  @moui_host.PlatformViewPlugin::new(
    kind="web_view",
    capabilities_summary~,
    install_event_dispatcher=fn(callback) {
      macos_webview_prewarm()
      macos_webview_install_event_callback(
        fn(cb, raw_handle, kind, id, url, detail, flag) {
          cb(raw_handle, kind, id, url, detail, flag)
        },
        (raw_handle, kind, id, url, detail, flag) => {
          let id_str = @host.webview_decode_ffi_string(id)
          // Decode the native event to WebViewEvent, then convert to the
          // platform-neutral PlatformViewEvent to get the correct
          // name/value/detail/flag mapping (e.g. TitleChanged puts the title
          // in `value`, not `detail`; CanGoBackChanged puts the bool in
          // `flag`).
          let web_event = @host.webview_decode_native_event(
            kind, url, detail, flag,
          )
          let platform_event = @host.WebViewEvent::to_platform_event(web_event)
          callback(raw_handle, id_str, platform_event)
        },
      )
    },
    sync_platform_views=fn(handle, frame, _offset_y) {
      macos_webview_platform_views_begin(handle)
      for placement in frame.platform_views {
        if placement.kind == "web_view" {
          macos_webview_sync(
            handle,
            @host.webview_encode_ffi_string(placement.id),
            @host.webview_encode_ffi_string(placement.property_or("url", "")),
            @host.webview_encode_ffi_string(placement.property_or("title", "")),
            @host.webview_encode_ffi_string(placement.property_or("background-color", "")),
            @host.webview_encode_ffi_string(placement.property_or("color-scheme", "")),
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
            Some(bounds) =>
              macos_webview_sync_overlay_mask(
                handle,
                @host.webview_encode_ffi_string(placement.id),
                1,
                bounds.origin.x,
                bounds.origin.y,
                bounds.size.width,
                bounds.size.height,
              )
            None =>
              macos_webview_sync_overlay_mask(
                handle,
                @host.webview_encode_ffi_string(placement.id),
                0,
                0.0,
                0.0,
                0.0,
                0.0,
              )
          }
        }
      }
      macos_webview_platform_views_end(handle)
    },
    drain_commands=fn(handle) {
      ignore(
        commands.drain_with_handler(command => {
          let (kind, text, detail) = @host.webview_encode_native_command(
            command.command,
          )
          macos_webview_command(
            handle,
            @host.webview_encode_ffi_string(command.id),
            kind,
            @host.webview_encode_ffi_string(text),
            @host.webview_encode_ffi_string(detail),
          )
        }),
      )
    },
    dispose_platform_views=fn(handle) {
      macos_webview_platform_views_dispose(handle)
    },
    setup_platform_view_draw=None,
    poll_native=None,
  )
}
