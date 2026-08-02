///|
/// Dispatch a neutral event supplied by Platform Bridge through the shared
/// coordinator. Browser pointer, keyboard, IME, drag, and modifier decoding
/// stays in `window_event_to_host`; async service draining and renderer
/// resize tracking are Web-specific.
fn WebApp::dispatch_host_event(
  self : WebApp,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  match host_event {
    @host.HostEvent::Resized(metrics) =>
      self.resize_renderer(window_id, metrics)
    _ => ()
  }
  self.coordinator.dispatch_host_event(window_id, host_event, adjust=event => {
    Some(event)
  })
  self.drain_async_host_services()
}
