///|
pub struct ScrollState {
  offset_slot : State[Point]
}

///|
pub struct FocusState {
  key_slot : State[String?]
}

///|
pub struct NavigationState {
  stack_slot : State[Array[String]]
}

///|
pub fn ScrollState::new(
  offset? : Point = Point::new(x=0.0, y=0.0),
) -> ScrollState {
  { offset_slot: State::new(offset) }
}

///|
pub fn ScrollState::offset(self : ScrollState) -> Point {
  self.offset_slot.get()
}

///|
pub fn ScrollState::set_offset(self : ScrollState, offset : Point) -> Unit {
  self.offset_slot.set(offset)
}

///|
pub fn ScrollState::binding(self : ScrollState) -> Binding[Point] {
  self.offset_slot.binding()
}

///|
pub fn ScrollState::scroll_to(
  self : ScrollState,
  x~ : Double,
  y~ : Double,
) -> Unit {
  self.set_offset(Point::new(x~, y~))
}

///|
pub fn FocusState::new(key? : String? = None) -> FocusState {
  { key_slot: State::new(key) }
}

///|
pub fn FocusState::focused_key(self : FocusState) -> String? {
  self.key_slot.get()
}

///|
pub fn FocusState::focus(self : FocusState, key : String) -> Unit {
  self.key_slot.set(Some(key))
}

///|
pub fn FocusState::clear(self : FocusState) -> Unit {
  self.key_slot.set(None)
}

///|
pub fn FocusState::binding(self : FocusState) -> Binding[String?] {
  self.key_slot.binding()
}

///|
pub fn NavigationState::new(initial? : String = "root") -> NavigationState {
  { stack_slot: State::new([initial]) }
}

///|
pub fn NavigationState::stack(self : NavigationState) -> Array[String] {
  self.stack_slot.get()
}

///|
pub fn NavigationState::current(self : NavigationState) -> String {
  let stack = self.stack()
  if stack.length() == 0 {
    ""
  } else {
    stack[stack.length() - 1]
  }
}

///|
pub fn NavigationState::push(self : NavigationState, route : String) -> Unit {
  self.stack_slot.update(stack => {
    let next = stack.copy()
    next.push(route)
    next
  })
}

///|
pub fn NavigationState::pop(self : NavigationState) -> Bool {
  let stack = self.stack()
  if stack.length() <= 1 {
    false
  } else {
    let next : Array[String] = []
    for index, route in stack {
      if index + 1 < stack.length() {
        next.push(route)
      }
    }
    self.stack_slot.set(next)
    true
  }
}

///|
pub fn NavigationState::replace(self : NavigationState, route : String) -> Unit {
  self.stack_slot.set([route])
}

///|
pub fn NavigationState::binding(
  self : NavigationState,
) -> Binding[Array[String]] {
  self.stack_slot.binding()
}

///|
pub fn BuildContext::watch_scroll(
  self : BuildContext,
  state : ScrollState,
) -> Point {
  self.watch(state.offset_slot)
}

///|
pub fn BuildContext::watch_focus(
  self : BuildContext,
  state : FocusState,
) -> String? {
  self.watch(state.key_slot)
}

///|
pub fn BuildContext::watch_navigation(
  self : BuildContext,
  state : NavigationState,
) -> Array[String] {
  self.watch(state.stack_slot)
}
