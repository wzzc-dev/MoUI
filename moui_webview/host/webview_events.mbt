///|
/// HostWebViewEvent and HostWebViewEventSource use Int for window_id rather
/// than moui/backend/host.HostWindowId so the host package does not need a
/// compile-time dependency on moui/backend/host. Platform backends convert
/// their HostWindowId to Int with .value before publishing.

///|
pub(all) struct HostWebViewEvent {
  window_id : Int
  id : String
  event : WebViewEvent
} derive(Eq, Debug, ToJson)

///|
pub struct HostWebViewEventSource {
  priv mut next_handler_value : Int
  priv mut handlers : Array[HostWebViewEventSubscriptionHandler]
}

///|
priv struct HostWebViewEventSubscriptionHandler {
  token : Int
  handle : (HostWebViewEvent) -> Unit
}

///|
pub fn HostWebViewEvent::new(
  window_id~ : Int,
  id~ : String,
  event~ : WebViewEvent,
) -> HostWebViewEvent {
  { window_id, id, event }
}

///|
pub fn HostWebViewEventSource::new() -> HostWebViewEventSource {
  { next_handler_value: 1, handlers: [] }
}

///|
pub fn HostWebViewEventSource::active_handler_count(
  self : HostWebViewEventSource,
) -> Int {
  self.handlers.length()
}

///|
pub fn HostWebViewEventSource::publish(
  self : HostWebViewEventSource,
  event : HostWebViewEvent,
) -> Int {
  let handlers = self.handlers.copy()
  for handler in handlers {
    (handler.handle)(event)
  }
  handlers.length()
}

///|
pub fn[Msg] HostWebViewEventSource::subscription(
  self : HostWebViewEventSource,
  key? : String = "host:web-view",
  label? : String = "Host WebView event",
  map~ : (HostWebViewEvent) -> Msg?,
) -> @core.Subscription[Msg] {
  let start = dispatch => {
    let token = self.add_handler(event => {
      match map(event) {
        Some(message) => dispatch(message)
        None => ()
      }
    })
    Some(() => ignore(self.remove_handler(token)))
  }
  @core.Subscription::host_event(key~, label~, start~)
}

///|
fn HostWebViewEventSource::add_handler(
  self : HostWebViewEventSource,
  handle : (HostWebViewEvent) -> Unit,
) -> Int {
  let token = self.next_handler_value
  self.next_handler_value = self.next_handler_value + 1
  self.handlers.push({ token, handle })
  token
}

///|
fn HostWebViewEventSource::remove_handler(
  self : HostWebViewEventSource,
  token : Int,
) -> Bool {
  let before = self.handlers.length()
  let remaining : Array[HostWebViewEventSubscriptionHandler] = []
  for handler in self.handlers {
    if handler.token != token {
      remaining.push(handler)
    }
  }
  self.handlers = remaining
  self.handlers.length() != before
}
