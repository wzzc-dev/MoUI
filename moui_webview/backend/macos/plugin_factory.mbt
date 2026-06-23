///|
/// Build a `WebviewPlugin` for the macOS native WKWebView bridge.
/// The command queue holds pending LoadUrl/Reload/etc. commands enqueued
/// by the app. The window handle is passed at call time by the host.
pub fn create_macos_webview_plugin(
  commands : @host.HostWebViewCommandQueue,
) -> @moui_host.WebviewPlugin {
  let capabilities_summary = if macos_webview_native_available() != 0 {
    "available"
  } else {
    "unavailable"
  }
  @moui_host.WebviewPlugin::new(
    capabilities_summary~,
    install_event_dispatcher=fn(callback) {
      macos_webview_install_event_callback(
        fn(cb, raw_handle, kind, id, url, detail, flag) {
          cb(raw_handle, kind, id, url, detail, flag)
        },
        (raw_handle, kind, id, url, detail, flag) => {
          let id_str = @host.webview_decode_ffi_string(id)
          // Decode native event to WebViewEvent, then convert to
          // PlatformViewEvent to get the correct name/value/detail/flag
          // mapping (e.g. TitleChanged puts the title in `value`, not
          // `detail`; CanGoBackChanged puts the bool in `flag`).
          let web_event = @host.webview_decode_native_event(
            kind, url, detail, flag,
          )
          let platform_event = @host.WebViewEvent::to_platform_event(
            web_event,
          )
          match platform_event {
            @core.PlatformViewEvent::Named(
              name~,
              value~,
              detail~,
              flag~,
            ) =>
              callback(raw_handle, id_str, name, value, detail, flag)
          }
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
            @host.webview_native_policy_code(
              @host.WebViewNavigationPolicy::from_revision_key(
                placement.property_or("policy", "http-https-file"),
              ),
            ),
            placement.frame.origin.x,
            placement.frame.origin.y,
            placement.frame.size.width,
            placement.frame.size.height,
          )
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
  )
}
