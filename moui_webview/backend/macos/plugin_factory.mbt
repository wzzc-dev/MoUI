///|
/// Build the macOS WebView plugin around the shared WebViewHost state machine.
pub fn create_macos_webview_plugin(
  host : @host.WebViewHost,
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
              callback(raw_handle, id_str, web_event.to_platform_event())
            None => ()
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
        host.drain_commands(command => {
          match host.native_config(command.controller_id) {
            Some(config) =>
              macos_webview_configure(
                handle,
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
          macos_webview_command(
            handle,
            @host.webview_encode_ffi_string(command.controller_id),
            kind,
            @host.webview_encode_ffi_string(text),
            @host.webview_encode_ffi_string(""),
          )
        }),
      )
    },
    dispose_platform_views=fn(handle) {
      macos_webview_platform_views_dispose(handle)
    },
    setup_platform_view_draw=None,
    poll_native=Some(fn() {
      host.poll_timeouts(@env.now().reinterpret_as_int64())
    }),
  )
}
