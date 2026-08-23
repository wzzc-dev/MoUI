///|
/// Build a `PlatformViewPlugin` (kind `"web_view"`) for the Linux WebKitGTK
/// native bridge. The command queue holds pending LoadUrl/Reload/etc.
/// commands enqueued by the app; the host passes the window's `wl_surface`
/// handle at call time.
///
/// Linux WebKitGTK runs a nested GTK event loop, so this plugin supplies a
/// `poll_native` callback that pumps that loop and reports the next-work
/// deadline; the Linux host keeps the event loop spinning via
/// `ControlFlow::wait_until` instead of `Wait`. It also supplies a
/// `setup_platform_view_draw` hook that blits each webview's offscreen pixels
/// into the Skia renderer during `render_frame`.
pub fn create_linux_webview_plugin(
  host : @host.WebViewHost,
) -> @moui_host.PlatformViewPlugin {
  let capabilities_summary = if linux_webview_native_available() != 0 {
    "available"
  } else {
    "unavailable"
  }
  @moui_host.PlatformViewPlugin::new(
    kind="web_view",
    capabilities_summary~,
    install_event_dispatcher=fn(callback) {
      linux_webview_install_event_callback(
        fn(cb, wl_surface, kind, id, url, detail, flag) {
          cb(wl_surface, kind, id, url, detail, flag)
        },
        (wl_surface, kind, id, url, detail, flag) => {
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
              callback(wl_surface, id_str, web_event.to_platform_event())
            None => ()
          }
        },
      )
    },
    sync_platform_views=fn(wl_surface, frame, content_offset_y) {
      // wl_display is unused by the WebKitGTK stub (views are keyed by
      // wl_surface); pass 0 to satisfy the FFI signature.
      let wl_display = 0UL
      linux_webview_platform_views_begin(wl_surface)
      for placement in frame.platform_views {
        if placement.kind == "web_view" {
          let platform_frame = linux_webview_platform_frame(
            placement, content_offset_y,
          )
          linux_webview_sync(
            wl_display,
            wl_surface,
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
            if placement.property_or("visible", "true") == "true" {
              1
            } else {
              0
            },
            platform_frame.origin.x,
            platform_frame.origin.y,
            platform_frame.size.width,
            platform_frame.size.height,
          )
        }
      }
      linux_webview_platform_views_end(wl_surface)
    },
    drain_commands=fn(wl_surface) {
      ignore(
        host.drain_commands(command => {
          match host.native_config(command.controller_id) {
            Some(config) =>
              linux_webview_configure(
                wl_surface,
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
          linux_webview_command(
            wl_surface,
            @host.webview_encode_ffi_string(command.controller_id),
            kind,
            @host.webview_encode_ffi_string(text),
            @host.webview_encode_ffi_string(""),
          )
        }),
      )
    },
    dispose_platform_views=fn(wl_surface) {
      linux_webview_platform_views_dispose(wl_surface)
    },
    setup_platform_view_draw=Some(fn(
      wl_surface,
      frame,
      content_offset_y,
      install_draw,
    ) {
      install_draw(fn(sink) {
        draw_linux_webview_pixels_to_sink(
          wl_surface, sink, frame, content_offset_y,
        )
      })
    }),
    poll_native=Some(fn() {
      // Pump the nested GTK loop and report whether work remains. The host
      // uses the returned deadline to keep spinning instead of `Wait`.
      let _ = pump_linux_webview_runtime()
      let host_deadline = host.poll_timeouts(@env.now().reinterpret_as_int64())
      let native_deadline = if linux_webview_has_active_work() != 0 {
        Some(linux_webview_runtime_next_tick_ms(delay_ms=16))
      } else {
        None
      }
      match (host_deadline, native_deadline) {
        (Some(host_deadline), Some(native_deadline)) =>
          Some(host_deadline.min(native_deadline))
        (Some(deadline), None) | (None, Some(deadline)) => Some(deadline)
        (None, None) => None
      }
    }),
  )
}

///|
/// Blit each visible webview's offscreen pixels into the Skia renderer. Unlike
/// the macOS/Windows direct-embedding path, Linux WebKitGTK renders offscreen
/// and the host composites the pixels during `render_frame`. Views are keyed by
/// `wl_surface` on the C side, so the surface handle passed by the host
/// identifies this window's webviews.
fn draw_linux_webview_pixels_to_sink(
  wl_surface : UInt64,
  sink : @core.PlatformViewPixelSink,
  frame : @core.DrawFrame,
  content_offset_y : Double,
) -> Unit {
  for placement in frame.platform_views {
    if placement.kind == "web_view" {
      let id_bytes = @host.webview_encode_ffi_string(placement.id)
      let surface_data = linux_webview_get_surface_data(wl_surface, id_bytes)
      if surface_data.surface_ptr.compare(0UL) != 0 &&
        surface_data.width > 0 &&
        surface_data.height > 0 {
        let pixels = linux_webview_get_surface_pixels(surface_data.surface_ptr)
        let platform_frame = @core.Rect::new(
          x=placement.frame.origin.x,
          y=placement.frame.origin.y + content_offset_y,
          width=placement.frame.size.width,
          height=placement.frame.size.height,
        )
        sink.draw(
          pixels,
          surface_data.width,
          surface_data.height,
          surface_data.stride,
          platform_frame.origin.x,
          platform_frame.origin.y,
          platform_frame.size.width,
          platform_frame.size.height,
        )
      }
    }
  }
}
