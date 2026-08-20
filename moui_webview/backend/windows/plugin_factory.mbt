///|
/// Build the Windows WebView2 plugin around the shared WebViewHost.
pub fn create_windows_webview_plugin(
  host : @host.WebViewHost,
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
          match
            host.accept_native_event(
              controller_id=id_str,
              kind~,
              navigation_raw=0UL,
              url=@host.webview_decode_ffi_string(url),
              detail=@host.webview_decode_ffi_string(detail),
              flag~,
            ) {
            Some(web_event) =>
              callback(hwnd, id_str, web_event.to_platform_event())
            None => ()
          }
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
            @host.webview_encode_ffi_string(""),
            @host.webview_encode_ffi_string(placement.property_or("title", "")),
            @host.webview_encode_ffi_string(
              placement.property_or("background-color", ""),
            ),
            @host.webview_encode_ffi_string(
              placement.property_or("color-scheme", ""),
            ),
            0,
            placement.frame.origin.x,
            placement.frame.origin.y,
            placement.frame.size.width,
            placement.frame.size.height,
          )
          match frame.overlay_bounds {
            Some(bounds) =>
              windows_webview_sync_overlay_mask(
                hwnd,
                1,
                bounds.origin.x,
                bounds.origin.y,
                bounds.size.width,
                bounds.size.height,
              )
            None =>
              windows_webview_sync_overlay_mask(hwnd, 0, 0.0, 0.0, 0.0, 0.0)
          }
        }
      }
      windows_webview_platform_views_end(hwnd)
    },
    drain_commands=fn(hwnd) {
      ignore(
        host.drain_commands(command => {
          match host.native_config(command.controller_id) {
            Some(config) =>
              windows_webview_configure(
                hwnd,
                @host.webview_encode_ffi_string(command.controller_id),
                config.revision,
                @host.webview_encode_ffi_string(config.allowed_origins),
                @host.webview_encode_ffi_string(config.document_start_script),
                @host.webview_encode_ffi_string(config.document_end_script),
              )
            None => ()
          }
          let (kind, _command_id, _navigation_id, text) = @host.webview_encode_native_command(
            command,
          )
          windows_webview_command(
            hwnd,
            @host.webview_encode_ffi_string(command.controller_id),
            kind,
            @host.webview_encode_ffi_string(text),
            @host.webview_encode_ffi_string(""),
          )
        }),
      )
    },
    dispose_platform_views=fn(hwnd) {
      windows_webview_platform_views_dispose(hwnd)
    },
    setup_platform_view_draw=None,
    poll_native=Some(fn() {
      host.poll_timeouts(@env.now().reinterpret_as_int64())
    }),
  )
}
