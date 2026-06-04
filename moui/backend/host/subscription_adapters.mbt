///|
pub struct HostEventSource {
  priv mut next_handler_value : Int
  priv mut handlers : Array[HostEventSubscriptionHandler]
}

///|
priv struct HostEventSubscriptionHandler {
  token : Int
  handle : (HostEvent) -> Unit
}

///|
pub fn HostEventSource::new() -> HostEventSource {
  { next_handler_value: 1, handlers: [] }
}

///|
pub fn HostEventSource::active_handler_count(self : HostEventSource) -> Int {
  self.handlers.length()
}

///|
pub fn HostEventSource::publish(
  self : HostEventSource,
  event : HostEvent,
) -> Int {
  let handlers = self.handlers.copy()
  for handler in handlers {
    (handler.handle)(event)
  }
  handlers.length()
}

///|
pub fn[Msg] HostEventSource::subscription(
  self : HostEventSource,
  key? : String = "host:event",
  label? : String = "Host event",
  map~ : (HostEvent) -> Msg?,
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
fn HostEventSource::add_handler(
  self : HostEventSource,
  handle : (HostEvent) -> Unit,
) -> Int {
  let token = self.next_handler_value
  self.next_handler_value = self.next_handler_value + 1
  self.handlers.push({ token, handle })
  token
}

///|
fn HostEventSource::remove_handler(self : HostEventSource, token : Int) -> Bool {
  let mut removed = false
  let remaining : Array[HostEventSubscriptionHandler] = []
  for handler in self.handlers {
    if !removed && handler.token == token {
      removed = true
    } else {
      remaining.push(handler)
    }
  }
  self.handlers = remaining
  removed
}
