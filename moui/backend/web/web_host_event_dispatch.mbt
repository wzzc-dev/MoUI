///|
/// Dispatch a neutral event supplied by backend/common through the shared
/// owner workflows. Browser pointer, keyboard, IME, drag, and modifier decoding
/// stays in `window_event_to_host`; async service draining and renderer
/// resize tracking are Web-specific.
fn WebApp::dispatch_host_event(
  self : WebApp,
  window_id : @host.WindowId,
  host_event : @host.Event,
) -> Unit {
  match host_event {
    @host.Event::Resized(metrics) => self.resize_renderer(window_id, metrics)
    _ => ()
  }
  @window_host.dispatch_host_event(
    self.lifecycle,
    self.input,
    self.services,
    window_id,
    host_event,
    adjust=event => Some(event),
  )
  self.drain_async_host_services()
}
