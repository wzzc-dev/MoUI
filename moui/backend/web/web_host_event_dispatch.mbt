///|
/// Dispatch a neutral event supplied by Platform Bridge. Browser pointer,
/// keyboard, IME, drag, and modifier decoding stays in `window_event_to_host`.
fn WebApp::dispatch_host_event(
  self : WebApp,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  self.apply_window_lifecycle(window_id, host_event)
  match self.runtime_slots.lookup(window_id) {
    Some(slot) =>
      match host_event {
        @host.HostEvent::Resized(metrics) => {
          self.resize_renderer(window_id, metrics)
          ignore(slot.driver.dispatch(host_event))
        }
        @host.HostEvent::Keyboard(event) =>
          ignore(
            slot.driver.dispatch_keyboard_with_services(event, self.services),
          )
        _ => ignore(slot.driver.dispatch(host_event))
      }
    None => ()
  }
  ignore(self.publish_subscription_event(window_id, host_event))
  self.drain_async_host_services()
  self.sync_text_input_session()
}
