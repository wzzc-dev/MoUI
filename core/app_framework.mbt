///|
pub(all) struct RouteLocation {
  path : String
  query : Array[RouteQueryParam]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RouteQueryParam {
  key : String
  value : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RouterState {
  navigation : NavigationState
}

///|
pub(all) struct FormFieldState {
  name : String
  value : State[String]
  validator : (String) -> String?
}

///|
pub(all) struct FormValidationResult {
  valid : Bool
  errors : Array[FormFieldError]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FormFieldError {
  name : String
  message : String
} derive(Eq, Debug, ToJson)

///|
pub fn RouteLocation::new(
  path~ : String,
  query? : Array[RouteQueryParam] = [],
) -> RouteLocation {
  { path, query }
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
pub fn RouteLocation::query_value(self : RouteLocation, key : String) -> String? {
  for param in self.query {
    if param.key == key {
      return Some(param.value)
    }
  }
  None
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
pub fn RouterState::new(initial? : RouteLocation = RouteLocation::new(path="/")) -> RouterState {
  { navigation: NavigationState::new(initial=initial.to_route()) }
}

///|
pub fn RouterState::current(self : RouterState) -> RouteLocation {
  RouteLocation::parse(self.navigation.current())
}

///|
pub fn RouterState::push(self : RouterState, location : RouteLocation) -> Unit {
  self.navigation.push(location.to_route())
}

///|
pub fn RouterState::replace(self : RouterState, location : RouteLocation) -> Unit {
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
pub fn FormFieldState::new(
  name~ : String,
  initial? : String = "",
  validator? : (String) -> String? = _value => None,
) -> FormFieldState {
  { name, value: State::new(initial), validator }
}

///|
pub fn FormFieldState::binding(self : FormFieldState) -> Binding[String] {
  self.value.binding()
}

///|
pub fn FormFieldState::validate(self : FormFieldState) -> FormFieldError? {
  match (self.validator)(self.value.get()) {
    Some(message) => Some({ name: self.name, message })
    None => None
  }
}

///|
pub fn validate_form(fields : Array[FormFieldState]) -> FormValidationResult {
  let errors : Array[FormFieldError] = []
  for field in fields {
    match field.validate() {
      Some(error) => errors.push(error)
      None => ()
    }
  }
  { valid: errors.length() == 0, errors }
}

///|
pub fn required_field(message? : String = "Required") -> (String) -> String? {
  value => if value == "" { Some(message) } else { None }
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
