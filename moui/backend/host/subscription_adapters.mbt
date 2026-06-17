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
pub struct HostTimerSource {
  priv start_timer_fn : (Double, (@core.Frame) -> Unit) -> (() -> Unit)?
}

///|
pub(all) struct HostWindowEvent {
  window_id : HostWindowId
  event : HostEvent
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostRouteLocation {
  path : String
  query : Array[HostRouteQueryParam]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostRouteQueryParam {
  key : String
  value : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostRouteEvent {
  location : HostRouteLocation
  source : String
} derive(Eq, Debug, ToJson)

///|
pub struct HostWindowEventSource {
  priv mut next_handler_value : Int
  priv mut handlers : Array[HostWindowEventSubscriptionHandler]
}

///|
pub struct HostRouteSource {
  priv mut next_handler_value : Int
  priv mut handlers : Array[HostRouteSubscriptionHandler]
}

///|
priv struct HostEventSubscriptionHandler {
  token : Int
  handle : (HostEvent) -> Unit
}

///|
priv struct HostWindowEventSubscriptionHandler {
  token : Int
  handle : (HostWindowEvent) -> Unit
}

///|
priv struct HostRouteSubscriptionHandler {
  token : Int
  handle : (HostRouteEvent) -> Unit
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
  window_id~ : HostWindowId,
  event~ : HostEvent,
) -> HostPlatformEventPublishResult {
  {
    host_event_count: self.host_events.publish(event),
    window_event_count: self.window_events.publish(window_id~, event~),
  }
}

///|
pub fn HostTimerSource::new(
  start_timer~ : (Double, (@core.Frame) -> Unit) -> (() -> Unit)?,
) -> HostTimerSource {
  { start_timer_fn: start_timer }
}

///|
pub fn HostWindowEvent::new(
  window_id~ : HostWindowId,
  event~ : HostEvent,
) -> HostWindowEvent {
  { window_id, event }
}

///|
pub fn HostRouteLocation::new(
  path~ : String,
  query? : Array[HostRouteQueryParam] = [],
) -> HostRouteLocation {
  { path, query }
}

///|
pub fn HostRouteQueryParam::new(
  key~ : String,
  value~ : String,
) -> HostRouteQueryParam {
  { key, value }
}

///|
pub fn HostRouteEvent::new(
  location~ : HostRouteLocation,
  source? : String = "host-route",
) -> HostRouteEvent {
  { location, source }
}

///|
pub fn HostRouteEvent::from_route(
  route~ : String,
  source? : String = "host-route",
) -> HostRouteEvent {
  HostRouteEvent::new(location=HostRouteLocation::parse(route), source~)
}

///|
pub fn HostRouteEvent::route(self : HostRouteEvent) -> String {
  self.location.to_route()
}

///|
pub fn HostRouteLocation::parse(value : String) -> HostRouteLocation {
  let parts = host_route_split_once(value, '?')
  match parts {
    Some((path, query_string)) => {
      let query : Array[HostRouteQueryParam] = []
      for pair_view in query_string.split("&") {
        let pair = pair_view.to_owned()
        if pair != "" {
          match host_route_split_once(pair, '=') {
            Some((key, value)) => query.push({ key, value })
            None => query.push({ key: pair, value: "" })
          }
        }
      }
      HostRouteLocation::new(path~, query~)
    }
    None => HostRouteLocation::new(path=value)
  }
}

///|
pub fn HostRouteLocation::query_value(
  self : HostRouteLocation,
  key : String,
) -> String? {
  for param in self.query {
    if param.key == key {
      return Some(param.value)
    }
  }
  None
}

///|
pub fn HostRouteLocation::to_route(self : HostRouteLocation) -> String {
  if self.query.length() == 0 {
    self.path
  } else {
    let parts : Array[String] = []
    for param in self.query {
      parts.push("\{param.key}=\{param.value}")
    }
    let query_string = parts.join("&")
    "\{self.path}?\{query_string}"
  }
}

///|
pub fn HostWindowEventSource::new() -> HostWindowEventSource {
  { next_handler_value: 1, handlers: [] }
}

///|
pub fn HostRouteSource::new() -> HostRouteSource {
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
pub fn HostRouteSource::active_handler_count(self : HostRouteSource) -> Int {
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
pub fn HostWindowEventSource::publish(
  self : HostWindowEventSource,
  window_id~ : HostWindowId,
  event~ : HostEvent,
) -> Int {
  let handlers = self.handlers.copy()
  let window_event = HostWindowEvent::new(window_id~, event~)
  for handler in handlers {
    (handler.handle)(window_event)
  }
  handlers.length()
}

///|
pub fn HostRouteSource::publish(
  self : HostRouteSource,
  event : HostRouteEvent,
) -> Int {
  let handlers = self.handlers.copy()
  for handler in handlers {
    (handler.handle)(event)
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
pub fn[Msg] HostRouteSource::subscription(
  self : HostRouteSource,
  key? : String = "host:route",
  label? : String = "Host route",
  map~ : (HostRouteEvent) -> Msg?,
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
  @core.Subscription::route_event(key~, label~, start~)
}

///|
pub fn[Msg] HostTimerSource::subscription(
  self : HostTimerSource,
  interval_ms~ : Double,
  key? : String = "host:timer",
  label? : String = "Host timer",
  map~ : (@core.Frame) -> Msg,
) -> @core.Subscription[Msg] {
  let start = dispatch => {
    (self.start_timer_fn)(interval_ms, frame => dispatch(map(frame)))
  }
  @core.Subscription::timer(key~, label~, start~)
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
fn HostRouteSource::add_handler(
  self : HostRouteSource,
  handle : (HostRouteEvent) -> Unit,
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
fn HostRouteSource::remove_handler(self : HostRouteSource, token : Int) -> Bool {
  let mut removed = false
  let remaining : Array[HostRouteSubscriptionHandler] = []
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

///|
fn host_route_split_once(value : String, separator : Char) -> (String, String)? {
  let before : Array[Char] = []
  let after : Array[Char] = []
  let mut found = false
  for ch in value {
    if !found && ch == separator {
      found = true
    } else if found {
      after.push(ch)
    } else {
      before.push(ch)
    }
  }
  if found {
    Some((String::from_array(before), String::from_array(after)))
  } else {
    None
  }
}
