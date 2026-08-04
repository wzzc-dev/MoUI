///|
pub struct HostEventSource {
  priv mut next_handler_value : Int
  priv mut handlers : Array[HostEventSubscriptionHandler]
}

///|
pub struct HostPlatformEventSources {
  priv host_events : HostEventSource
  priv window_events : HostWindowEventSource
}

///|
pub(all) struct HostPlatformEventPublishResult {
  host_event_count : Int
  window_event_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowEvent {
  window_id : @backend_host.HostWindowId
  event : @backend_host.HostEvent
} derive(Eq, Debug, ToJson)

///|
pub struct HostWindowEventSource {
  priv mut next_handler_value : Int
  priv mut handlers : Array[HostWindowEventSubscriptionHandler]
}

///|
priv struct HostEventSubscriptionHandler {
  token : Int
  handle : (@backend_host.HostEvent) -> Unit
}

///|
priv struct HostWindowEventSubscriptionHandler {
  token : Int
  handle : (HostWindowEvent) -> Unit
}

///|
pub fn HostEventSource::new() -> HostEventSource {
  { next_handler_value: 1, handlers: [] }
}

///|
pub fn HostPlatformEventSources::new(
  host_events? : HostEventSource = HostEventSource::new(),
  window_events? : HostWindowEventSource = HostWindowEventSource::new(),
) -> HostPlatformEventSources {
  { host_events, window_events }
}

///|
pub fn HostPlatformEventSources::host_events(
  self : HostPlatformEventSources,
) -> HostEventSource {
  self.host_events
}

///|
pub fn HostPlatformEventSources::window_events(
  self : HostPlatformEventSources,
) -> HostWindowEventSource {
  self.window_events
}

///|
pub fn HostPlatformEventSources::publish(
  self : HostPlatformEventSources,
  window_id~ : @backend_host.HostWindowId,
  event~ : @backend_host.HostEvent,
) -> HostPlatformEventPublishResult {
  {
    host_event_count: self.host_events.publish(event),
    window_event_count: self.window_events.publish(window_id~, event~),
  }
}

///|
pub fn HostWindowEvent::new(
  window_id~ : @backend_host.HostWindowId,
  event~ : @backend_host.HostEvent,
) -> HostWindowEvent {
  { window_id, event }
}

///|
pub fn HostWindowEventSource::new() -> HostWindowEventSource {
  { next_handler_value: 1, handlers: [] }
}

///|
pub fn HostEventSource::active_handler_count(self : HostEventSource) -> Int {
  self.handlers.length()
}

///|
pub fn HostWindowEventSource::active_handler_count(
  self : HostWindowEventSource,
) -> Int {
  self.handlers.length()
}

///|
pub fn HostEventSource::publish(
  self : HostEventSource,
  event : @backend_host.HostEvent,
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
  map~ : (@backend_host.HostEvent) -> Msg?,
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
pub fn HostWindowEventSource::publish(
  self : HostWindowEventSource,
  window_id~ : @backend_host.HostWindowId,
  event~ : @backend_host.HostEvent,
) -> Int {
  let handlers = self.handlers.copy()
  let window_event = HostWindowEvent::new(window_id~, event~)
  for handler in handlers {
    (handler.handle)(window_event)
  }
  handlers.length()
}

///|
pub fn[Msg] HostWindowEventSource::subscription(
  self : HostWindowEventSource,
  key? : String = "host:window-event",
  label? : String = "Host window event",
  map~ : (HostWindowEvent) -> Msg?,
) -> @core.Subscription[Msg] {
  let start = dispatch => {
    let token = self.add_handler(window_event => {
      match map(window_event) {
        Some(message) => dispatch(message)
        None => ()
      }
    })
    Some(() => ignore(self.remove_handler(token)))
  }
  @core.Subscription::window_event(key~, label~, start~)
}

///|
fn HostEventSource::add_handler(
  self : HostEventSource,
  handle : (@backend_host.HostEvent) -> Unit,
) -> Int {
  let token = self.next_handler_value
  self.next_handler_value = self.next_handler_value + 1
  self.handlers.push({ token, handle })
  token
}

///|
fn HostWindowEventSource::add_handler(
  self : HostWindowEventSource,
  handle : (HostWindowEvent) -> Unit,
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

///|
fn HostWindowEventSource::remove_handler(
  self : HostWindowEventSource,
  token : Int,
) -> Bool {
  let mut removed = false
  let remaining : Array[HostWindowEventSubscriptionHandler] = []
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
