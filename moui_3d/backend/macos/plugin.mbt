///|
/// macOS composition-root plugin for a child CAMetalLayer-backed 3D surface.
/// The renderer remains independent: this package only owns native view
/// lifetime and forwards the resulting opaque layer handle to the addon host.
pub fn plugin(
  host? : @moui_3d.ThreeDViewportHost? = None,
) -> @host.PlatformViewPlugin {
  let bridge = match host {
    Some(value) => value
    None =>
      @moui_3d.ThreeDViewportHost::new(
        binding=@moui_3d.ThreeDViewportBinding::new(),
      )
  }
  let dispatcher : @ref.Ref[@host.PlatformViewEventCallback?] = @ref.Ref(None)
  let active_window : @ref.Ref[UInt64?] = @ref.Ref(None)
  let active_id : @ref.Ref[String?] = @ref.Ref(None)
  let last_status : @ref.Ref[@moui_3d.ViewportStatus?] = @ref.Ref(None)
  let notify_status = () => {
    match (dispatcher.val, active_window.val, active_id.val) {
      (Some(callback), Some(window), Some(id)) => {
        let status = bridge.binding().status()
        if last_status.val != Some(status) {
          last_status.val = Some(status)
          callback(
            window,
            id,
            @core.PlatformViewEvent::Named(
              name="renderer_status",
              value="",
              detail="",
              flag=false,
            ),
          )
        }
      }
      _ => ()
    }
  }
  bridge.set_invalidate_handler(notify_status)
  @host.PlatformViewPlugin::new(
    kind="moui_3d_viewport",
    capabilities_summary=macos_3d_capabilities(),
    install_event_dispatcher=callback => {
      dispatcher.val = Some(callback)
      install_macos_3d_event_dispatcher(callback)
    },
    sync_platform_views=(window, frame, offset) => {
      let mut found = false
      macos_3d_platform_views_begin(window)
      for placement in frame.platform_views {
        if placement.kind == "moui_3d_viewport" {
          found = true
          active_window.val = Some(window)
          active_id.val = Some(placement.id)
          let layer = macos_3d_sync(
            window,
            @utf8.encode(placement.id[:], bom=false),
            placement.frame.origin.x,
            placement.frame.origin.y + offset,
            placement.frame.size.width,
            placement.frame.size.height,
            1.0,
          )
          if layer != 0UL {
            match frame.overlay_bounds {
              Some(bounds) =>
                macos_3d_sync_overlay_mask(
                  window,
                  @utf8.encode(placement.id[:], bom=false),
                  1,
                  bounds.origin.x,
                  bounds.origin.y,
                  bounds.size.width,
                  bounds.size.height,
                )
              None =>
                macos_3d_sync_overlay_mask(
                  window,
                  @utf8.encode(placement.id[:], bom=false),
                  0,
                  0.0,
                  0.0,
                  0.0,
                  0.0,
                )
            }
            bridge.sync_platform_view(
              window,
              placement,
              layer,
              frame,
              offset,
              scale_factor=macos_3d_surface_scale(layer),
            )
            notify_status()
          }
        }
      }
      macos_3d_platform_views_end(window)
      if !found {
        active_window.val = None
        active_id.val = None
        bridge.dispose_platform_views(window)
      }
    },
    drain_commands=_window => (),
    dispose_platform_views=window => {
      bridge.dispose_platform_views(window)
      active_window.val = None
      active_id.val = None
      macos_3d_platform_views_dispose(window)
    },
  )
}
