///|
/// Installs iOS's runtime adapter into the shell-owned embedding ABI.
/// The backend owns MoUI runtime/renderer behavior; `moui_shell` owns native
/// exports, ABI versioning, and dispatch.
pub fn install_embedding(
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> IosRendererProvider,
  renderer_configure~ : (String) -> Bool,
  renderer_status_json~ : () -> String,
) -> Unit {
  let adapter = IosEmbeddingAdapter::new(
    runtime_factory~,
    provider_factory~,
    renderer_configure~,
    renderer_status_json~,
  )
  @shell_embedding.install_runtime(
    @shell_embedding.EmbeddingRuntimeCallbacks::new(
      renderer_configure=mode => adapter.renderer_configure(mode),
      renderer_status_json=() => adapter.renderer_status_json(),
      take_host_updates_json=() => adapter.take_host_updates_json(),
      take_host_update_envelope_json=() => {
        adapter.take_host_update_envelope_json()
      },
      dispatch_host_response_envelope_json=text => {
        adapter.dispatch_host_response_envelope_json(text)
      },
      dispatch_text_input=(kind, text, start, end) => {
        adapter.dispatch_text_input(kind, text, start, end)
      },
      dispatch_command=kind => adapter.dispatch_command(kind),
      dispatch_accessibility=(element_id, action, value) => {
        adapter.dispatch_accessibility(element_id, action, value)
      },
      complete_clipboard=(id, kind, text, bytes) => {
        adapter.complete_clipboard(id, kind, text, bytes)
      },
      complete_clipboard_v1=(session_generation, id, kind, text, bytes) => {
        adapter.complete_clipboard_v1(session_generation, id, kind, text, bytes)
      },
      attach_surface=(view_handle, width, height, scale_factor) => {
        adapter.attach_view(view_handle, width, height, scale_factor)
      },
      resize=(width, height, scale_factor) => {
        adapter.resize(width, height, scale_factor)
      },
      dispatch_pointer=(phase, x, y, time_ms) => {
        adapter.dispatch_pointer(phase, x, y, time_ms)
      },
      dispatch_scroll=(x, y, delta_x, delta_y, phase) => {
        adapter.dispatch_scroll(x, y, delta_x, delta_y, phase)
      },
      frame_tick=time_ms => adapter.frame_tick(time_ms),
      render_frame=() => adapter.render_frame(),
      detach_surface=() => adapter.detach_view(),
      destroy_application=() => adapter.destroy_application(),
    ),
  )
}
