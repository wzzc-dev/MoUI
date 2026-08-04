///|
pub struct TimerSource {
  start_fn : (Double, (@core.Frame) -> Unit) -> (() -> Unit)?
}

///|
pub(all) struct RouteQueryParam {
  key : String
  value : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RouteLocation {
  path : String
  query : Array[RouteQueryParam]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RouteEvent {
  location : RouteLocation
  source : String
} derive(Eq, Debug, ToJson)

///|
priv struct RouteHandler {
  token : Int
  handle : (RouteEvent) -> Unit
}

///|
pub struct RouteSource {
  priv mut next_token : Int
  priv mut handlers : Array[RouteHandler]
}

///|
pub fn TimerSource::new(
  start~ : (Double, (@core.Frame) -> Unit) -> (() -> Unit)?,
) -> TimerSource {
  { start_fn: start }
}

///|
/// Adapt a native timer callback into an app-facing timer source. Platform
/// backends own the native start/cancel functions; services owns only the
/// neutral frame and cancellation semantics.
pub fn TimerSource::from_native_timer(
  start~ : (FuncRef[(() -> Unit) -> Unit], Double, () -> Unit) -> UInt64,
  cancel~ : (UInt64) -> Unit,
  clock? : (() -> Double)? = None,
) -> TimerSource {
  TimerSource::new(start=(interval_ms, dispatch) => {
    let tick = match clock {
      None =>
        () => dispatch(@core.Frame::new(time_ms=0.0, delta_ms=interval_ms))
      Some(now) => {
        let last_time_ms = Ref(now())
        () => {
          let now_ms = now()
          let delta_ms = (now_ms - last_time_ms.val).max(0.0)
          last_time_ms.val = now_ms
          dispatch(@core.Frame::new(time_ms=now_ms, delta_ms~))
        }
      }
    }
    let handle = start(fn(callback) { callback() }, interval_ms, tick)
    Some(() => cancel(handle))
  })
}

///|
pub fn[Msg] TimerSource::subscription(
  self : TimerSource,
  interval_ms~ : Double,
  map~ : (@core.Frame) -> Msg,
  key? : String = "app:timer",
  label? : String = "App timer",
) -> @core.Subscription[Msg] {
  @core.Subscription::timer(key~, label~, start=dispatch => {
    (self.start_fn)(interval_ms, frame => dispatch(map(frame)))
  })
}

///|
pub fn RouteLocation::new(
  path~ : String,
  query? : Array[RouteQueryParam] = [],
) -> RouteLocation {
  { path, query }
}

///|
pub fn RouteQueryParam::new(key~ : String, value~ : String) -> RouteQueryParam {
  { key, value }
}

///|
pub fn RouteLocation::parse(value : String) -> RouteLocation {
  match route_split_once(value, '?') {
    Some((path, query_string)) => {
      let query : Array[RouteQueryParam] = []
      for pair_view in query_string.split("&") {
        let pair = pair_view.to_owned()
        if pair != "" {
          match route_split_once(pair, '=') {
            Some((key, value)) => query.push({ key, value })
            None => query.push({ key: pair, value: "" })
          }
        }
      }
      RouteLocation::new(path~, query~)
    }
    None => RouteLocation::new(path=value)
  }
}

///|
pub fn RouteLocation::query_value(
  self : RouteLocation,
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
pub fn RouteLocation::to_route(self : RouteLocation) -> String {
  if self.query.is_empty() {
    self.path
  } else {
    self.path +
    "?" +
    self.query.map(param => "\{param.key}=\{param.value}").join("&")
  }
}

///|
pub fn RouteEvent::new(
  location~ : RouteLocation,
  source? : String = "host-route",
) -> RouteEvent {
  { location, source }
}

///|
pub fn RouteEvent::from_route(
  route~ : String,
  source? : String = "host-route",
) -> RouteEvent {
  RouteEvent::new(location=RouteLocation::parse(route), source~)
}

///|
pub fn RouteEvent::from_path(
  path : String,
  source? : String = "host-route",
) -> RouteEvent {
  RouteEvent::new(location=RouteLocation::new(path~), source~)
}

///|
pub fn RouteEvent::route(self : RouteEvent) -> String {
  self.location.to_route()
}

///|
pub fn RouteSource::new() -> RouteSource {
  { next_token: 1, handlers: [] }
}

///|
pub fn RouteSource::publish(self : RouteSource, event : RouteEvent) -> Int {
  let handlers = self.handlers.copy()
  for handler in handlers {
    (handler.handle)(event)
  }
  handlers.length()
}

///|
pub fn RouteSource::active_handler_count(self : RouteSource) -> Int {
  self.handlers.length()
}

///|
pub fn[Msg] RouteSource::subscription(
  self : RouteSource,
  map~ : (RouteEvent) -> Msg?,
  key? : String = "app:route",
  label? : String = "App route",
) -> @core.Subscription[Msg] {
  @core.Subscription::route_event(key~, label~, start=dispatch => {
    let token = self.next_token
    self.next_token = self.next_token + 1
    self.handlers.push({
      token,
      handle: event => {
        match map(event) {
          Some(message) => dispatch(message)
          None => ()
        }
      },
    })
    Some(() => {
      self.handlers = self.handlers.filter(handler => handler.token != token)
    })
  })
}

///|
pub struct AppEnvironment {
  services_value : AppServices
  timer_value : TimerSource?
  routes_value : RouteSource?
}

///|
pub fn AppEnvironment::new(
  services? : AppServices = AppServices::unavailable(),
  timer? : TimerSource? = None,
  routes? : RouteSource? = None,
) -> AppEnvironment {
  { services_value: services, timer_value: timer, routes_value: routes }
}

///|
pub fn AppEnvironment::services(self : AppEnvironment) -> AppServices {
  self.services_value
}

///|
pub fn AppEnvironment::timer(self : AppEnvironment) -> TimerSource? {
  self.timer_value
}

///|
pub fn AppEnvironment::routes(self : AppEnvironment) -> RouteSource? {
  self.routes_value
}

///|
fn route_split_once(value : String, separator : Char) -> (String, String)? {
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
