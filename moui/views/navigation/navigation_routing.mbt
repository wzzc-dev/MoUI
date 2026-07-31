///|
pub struct RouteLocation {
  path : String
  query : Array[RouteQueryParam]
} derive(Eq, Debug, ToJson)

///|
pub struct RouteQueryParam {
  key : String
  value : String
} derive(Eq, Debug, ToJson)

///|
pub struct RouteParam {
  key : String
  value : String
} derive(Eq, Debug, ToJson)

///|
pub struct RouteDescriptor {
  id : String
  path : String
  title : String
  fallback : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct RouterSnapshot {
  routes : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub struct RouteHistoryEntry {
  route : String
  title : String
  source : String
} derive(Eq, Debug, ToJson)

///|
pub struct RouteHistoryState {
  entries : Array[RouteHistoryEntry]
  cursor : Int
} derive(Eq, Debug, ToJson)

///|
priv struct RouteFocusEntry {
  route : String
  focus_key : String
}

///|
struct RouteFocusStore {
  mut entries : Array[RouteFocusEntry]
}

///|
struct RouterState {
  navigation : @core.NavigationState
}

///|
pub fn RouteLocation::new(
  path~ : String,
  query? : Array[RouteQueryParam] = [],
) -> RouteLocation {
  { path, query }
}

///|
pub fn RouteParam::new(key~ : String, value~ : String) -> RouteParam {
  { key, value }
}

///|
pub fn RouteQueryParam::new(key~ : String, value~ : String) -> RouteQueryParam {
  { key, value }
}

///|
pub fn RouteDescriptor::new(
  id~ : String,
  path~ : String,
  title? : String = "",
  fallback? : Bool = false,
) -> RouteDescriptor {
  { id, path, title, fallback }
}

///|
pub fn RouterSnapshot::new(routes~ : Array[String]) -> RouterSnapshot {
  { routes, }
}

///|
pub fn RouteHistoryEntry::new(
  route~ : String,
  title? : String = "",
  source? : String = "app",
) -> RouteHistoryEntry {
  { route, title, source }
}

///|
pub fn RouteHistoryEntry::location(self : RouteHistoryEntry) -> RouteLocation {
  RouteLocation::parse(self.route)
}

///|
pub fn RouteHistoryState::new(
  initial? : RouteLocation = RouteLocation::new(path="/"),
  title? : String = "",
  source? : String = "app",
) -> RouteHistoryState {
  {
    entries: [RouteHistoryEntry::new(route=initial.to_route(), title~, source~)],
    cursor: 0,
  }
}

///|
pub fn RouteHistoryState::from_deep_link(
  route : String,
  title? : String = "",
  source? : String = "deep-link",
) -> RouteHistoryState {
  RouteHistoryState::new(initial=RouteLocation::parse(route), title~, source~)
}

///|
pub fn RouteHistoryState::from_routes(
  routes~ : Array[String],
  cursor? : Int = -1,
  title? : String = "",
  source? : String = "app",
) -> RouteHistoryState {
  if routes.length() == 0 {
    RouteHistoryState::new(title~, source~)
  } else {
    let entries = routes.map(route => {
      RouteHistoryEntry::new(route~, title~, source~)
    })
    let selected = if cursor < 0 {
      entries.length() - 1
    } else {
      clamp_route_history_cursor(entries, cursor)
    }
    { entries, cursor: selected }
  }
}

///|
pub fn RouteHistoryState::from_snapshot(
  snapshot : RouterSnapshot,
  title? : String = "",
  source? : String = "router",
) -> RouteHistoryState {
  RouteHistoryState::from_routes(routes=snapshot.routes, title~, source~)
}

///|
pub fn RouteHistoryState::current_entry(
  self : RouteHistoryState,
) -> RouteHistoryEntry? {
  let cursor = clamp_route_history_cursor(self.entries, self.cursor)
  if cursor < 0 {
    None
  } else {
    Some(self.entries[cursor])
  }
}

///|
pub fn RouteHistoryState::current(self : RouteHistoryState) -> RouteLocation {
  match self.current_entry() {
    Some(entry) => entry.location()
    None => RouteLocation::new(path="/")
  }
}

///|
pub fn RouteHistoryState::current_route(self : RouteHistoryState) -> String {
  match self.current_entry() {
    Some(entry) => entry.route
    None => "/"
  }
}

///|
pub fn RouteHistoryState::can_go_back(self : RouteHistoryState) -> Bool {
  clamp_route_history_cursor(self.entries, self.cursor) > 0
}

///|
pub fn RouteHistoryState::can_go_forward(self : RouteHistoryState) -> Bool {
  let cursor = clamp_route_history_cursor(self.entries, self.cursor)
  cursor >= 0 && cursor + 1 < self.entries.length()
}

///|
pub fn RouteHistoryState::push(
  self : RouteHistoryState,
  location : RouteLocation,
  title? : String = "",
  source? : String = "app",
) -> RouteHistoryState {
  let entry = RouteHistoryEntry::new(route=location.to_route(), title~, source~)
  let cursor = clamp_route_history_cursor(self.entries, self.cursor)
  let entries : Array[RouteHistoryEntry] = []
  if cursor >= 0 {
    for index, current in self.entries {
      if index <= cursor {
        entries.push(current)
      }
    }
  }
  entries.push(entry)
  { entries, cursor: entries.length() - 1 }
}

///|
pub fn RouteHistoryState::replace(
  self : RouteHistoryState,
  location : RouteLocation,
  title? : String = "",
  source? : String = "app",
) -> RouteHistoryState {
  if self.entries.length() == 0 {
    RouteHistoryState::new(initial=location, title~, source~)
  } else {
    let entry = RouteHistoryEntry::new(
      route=location.to_route(),
      title~,
      source~,
    )
    let cursor = clamp_route_history_cursor(self.entries, self.cursor)
    let entries : Array[RouteHistoryEntry] = []
    for index, current in self.entries {
      if index == cursor {
        entries.push(entry)
      } else {
        entries.push(current)
      }
    }
    { entries, cursor }
  }
}

///|
pub fn RouteHistoryState::back(self : RouteHistoryState) -> RouteHistoryState {
  let cursor = clamp_route_history_cursor(self.entries, self.cursor)
  if cursor > 0 {
    { ..self, cursor: cursor - 1 }
  } else {
    { ..self, cursor, }
  }
}

///|
pub fn RouteHistoryState::forward(
  self : RouteHistoryState,
) -> RouteHistoryState {
  let cursor = clamp_route_history_cursor(self.entries, self.cursor)
  if cursor >= 0 && cursor + 1 < self.entries.length() {
    { ..self, cursor: cursor + 1 }
  } else {
    { ..self, cursor, }
  }
}

///|
pub fn RouteHistoryState::router_snapshot(
  self : RouteHistoryState,
) -> RouterSnapshot {
  let routes : Array[String] = []
  let cursor = clamp_route_history_cursor(self.entries, self.cursor)
  if cursor >= 0 {
    for index, entry in self.entries {
      if index <= cursor {
        routes.push(entry.route)
      }
    }
  }
  RouterSnapshot::new(routes~)
}

///|
pub fn RouteHistoryState::restore_router(
  self : RouteHistoryState,
  router : RouterState,
) -> Unit {
  router.restore(self.router_snapshot())
}

///|
fn RouteFocusEntry::new(
  route~ : String,
  focus_key~ : String,
) -> RouteFocusEntry {
  { route, focus_key }
}

///|
pub fn RouteFocusStore::new() -> RouteFocusStore {
  { entries: [] }
}

///|
pub fn RouteFocusStore::remember(
  self : RouteFocusStore,
  route~ : String,
  focus_key~ : String,
) -> Unit {
  self.entries = self.entries.filter(entry => entry.route != route)
  self.entries.push(RouteFocusEntry::new(route~, focus_key~))
}

///|
pub fn RouteFocusStore::remember_location(
  self : RouteFocusStore,
  location : RouteLocation,
  focus_key~ : String,
) -> Unit {
  self.remember(route=location.to_route(), focus_key~)
}

///|
pub fn RouteFocusStore::focus_key(
  self : RouteFocusStore,
  route : String,
) -> String? {
  for entry in self.entries {
    if entry.route == route {
      return Some(entry.focus_key)
    }
  }
  None
}

///|
pub fn RouteFocusStore::focus_key_for_location(
  self : RouteFocusStore,
  location : RouteLocation,
) -> String? {
  match self.focus_key(location.to_route()) {
    Some(key) => Some(key)
    None => self.focus_key(location.path)
  }
}

///|
pub fn RouteLocation::parse(value : String) -> RouteLocation {
  let parts = split_once(value, '?')
  match parts {
    Some((path, query_string)) => {
      let query : Array[RouteQueryParam] = []
      for pair_view in query_string.split("&") {
        let pair = pair_view.to_owned()
        if pair != "" {
          match split_once(pair, '=') {
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
pub fn RouteLocation::params(self : RouteLocation) -> Array[RouteParam] {
  self.query.map(param => RouteParam::new(key=param.key, value=param.value))
}

///|
pub fn RouteLocation::param_value(
  self : RouteLocation,
  key : String,
) -> String? {
  self.query_value(key)
}

///|
pub fn RouteLocation::to_route(self : RouteLocation) -> String {
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
pub fn RouterState::new(
  initial? : RouteLocation = RouteLocation::new(path="/"),
) -> RouterState {
  { navigation: @core.NavigationState::new(initial=initial.to_route()) }
}

///|
pub fn RouterState::current(self : RouterState) -> RouteLocation {
  RouteLocation::parse(self.navigation.current())
}

///|
pub fn RouterState::stack(self : RouterState) -> Array[RouteLocation] {
  self.navigation.stack().map(route => RouteLocation::parse(route))
}

///|
pub fn RouterState::snapshot(self : RouterState) -> RouterSnapshot {
  RouterSnapshot::new(routes=self.navigation.stack())
}

///|
pub fn RouterState::restore(
  self : RouterState,
  snapshot : RouterSnapshot,
) -> Unit {
  if snapshot.routes.length() == 0 {
    self.navigation.replace("/")
  } else {
    self.navigation.stack_slot.set(snapshot.routes.copy())
  }
}

///|
pub fn RouterState::push(self : RouterState, location : RouteLocation) -> Unit {
  self.navigation.push(location.to_route())
}

///|
pub fn RouterState::replace(
  self : RouterState,
  location : RouteLocation,
) -> Unit {
  self.navigation.stack_slot.update(stack => {
    if stack.length() == 0 {
      [location.to_route()]
    } else {
      let next : Array[String] = []
      for index, route in stack {
        if index + 1 < stack.length() {
          next.push(route)
        }
      }
      next.push(location.to_route())
      next
    }
  })
}

///|
pub fn RouterState::pop(self : RouterState) -> Bool {
  self.navigation.pop()
}

///|
pub fn RouterState::resolve(
  self : RouterState,
  routes : Array[RouteDescriptor],
) -> RouteDescriptor? {
  resolve_route(self.current(), routes)
}

///|
pub fn resolve_route(
  location : RouteLocation,
  routes : Array[RouteDescriptor],
) -> RouteDescriptor? {
  let mut fallback : RouteDescriptor? = None
  for route in routes {
    if route.path == location.path || route.id == location.path {
      return Some(route)
    }
    if route.fallback && fallback is None {
      fallback = Some(route)
    }
  }
  fallback
}

///|
fn split_once(value : String, separator : Char) -> (String, String)? {
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

///|
fn clamp_route_history_cursor(
  entries : Array[RouteHistoryEntry],
  cursor : Int,
) -> Int {
  if entries.length() == 0 {
    -1
  } else if cursor < 0 {
    0
  } else if cursor >= entries.length() {
    entries.length() - 1
  } else {
    cursor
  }
}

///|
pub fn RouteLocation::path(self : RouteLocation) -> String {
  self.path
}

///|
pub fn RouteLocation::query(self : RouteLocation) -> Array[RouteQueryParam] {
  self.query
}

///|
pub fn RouteQueryParam::key(self : RouteQueryParam) -> String {
  self.key
}

///|
pub fn RouteQueryParam::value(self : RouteQueryParam) -> String {
  self.value
}

///|
pub fn RouteParam::key(self : RouteParam) -> String {
  self.key
}

///|
pub fn RouteParam::value(self : RouteParam) -> String {
  self.value
}

///|
pub fn RouteDescriptor::id(self : RouteDescriptor) -> String {
  self.id
}

///|
pub fn RouteDescriptor::path(self : RouteDescriptor) -> String {
  self.path
}

///|
pub fn RouteDescriptor::title(self : RouteDescriptor) -> String {
  self.title
}

///|
pub fn RouteDescriptor::fallback(self : RouteDescriptor) -> Bool {
  self.fallback
}

///|
pub fn RouterSnapshot::routes(self : RouterSnapshot) -> Array[String] {
  self.routes
}

///|
pub fn RouteHistoryEntry::route(self : RouteHistoryEntry) -> String {
  self.route
}

///|
pub fn RouteHistoryEntry::title(self : RouteHistoryEntry) -> String {
  self.title
}

///|
pub fn RouteHistoryEntry::source(self : RouteHistoryEntry) -> String {
  self.source
}

///|
pub fn RouteHistoryState::entries(
  self : RouteHistoryState,
) -> Array[RouteHistoryEntry] {
  self.entries
}

///|
pub fn RouteHistoryState::cursor(self : RouteHistoryState) -> Int {
  self.cursor
}
