///|
/// Forward one adjusted host event to the plugin. Events that the core app
/// event protocol cannot represent stay on the host side.
pub fn forward_host_event(event : @backend_host.Event) -> Bool {
  match event.to_core() {
    Some(core_event) => dispatch_event(core_event)
    None => false
  }
}

///|
/// Wrap a native platform-view plugin so a hot generation swap destroys the old
/// generation's native views before the new frame's placements are synced.
///
/// The host backend itself only disposes platform views when a window closes;
/// without this wrapper a swap would leave the previous generation's native
/// views alive (macOS merely hides placements the new frame does not mention),
/// leaking windows and keeping stale z-order. Native events are forwarded to the
/// plugin app in addition to the host runtime's own dispatch path.
pub fn wrap_platform_view_plugin(
  plugin : @backend_host.PlatformViewPlugin,
  forward~ : (String, @core.PlatformViewEvent) -> Unit,
) -> @backend_host.PlatformViewPlugin {
  let last_generation : Ref[Int32] = Ref(-1)
  @backend_host.PlatformViewPlugin::new(
    kind=plugin.kind,
    capabilities_summary=plugin.capabilities_summary,
    install_event_dispatcher=dispatch => {
      (plugin.install_event_dispatcher)((window_ptr, id, event) => {
        dispatch(window_ptr, id, event)
        forward(id, event)
      })
    },
    sync_platform_views=(handle, frame, content_offset) => {
      let generation = host_reloads.val
      if last_generation.val != generation {
        (plugin.dispose_platform_views)(handle)
        last_generation.val = generation
      }
      (plugin.sync_platform_views)(handle, frame, content_offset)
    },
    drain_commands=plugin.drain_commands,
    dispose_platform_views=handle => {
      (plugin.dispose_platform_views)(handle)
      last_generation.val = host_reloads.val
    },
    setup_platform_view_draw=plugin.setup_platform_view_draw,
    poll_native=plugin.poll_native,
  )
}
