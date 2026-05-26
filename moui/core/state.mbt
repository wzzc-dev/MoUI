///|
pub(all) struct State[T] {
  slot : StateSlot[T]
}

///|
pub(all) struct Binding[T] {
  get_value : () -> T
  set_value : (T) -> Unit
}

///|
pub(all) struct DerivedState[T] {
  get_value : () -> T
  subscribe_value : (() -> Unit) -> Array[StateSubscription]
}

///|
pub fn[T] State::new(value : T) -> State[T] {
  { slot: StateSlot::new(value) }
}

///|
pub fn[T] State::get(self : State[T]) -> T {
  self.slot.get()
}

///|
pub fn[T] State::set(self : State[T], value : T) -> Unit {
  self.slot.set(value)
}

///|
pub fn[T] State::update(self : State[T], f : (T) -> T raise?) -> Unit raise? {
  self.slot.update(f)
}

///|
pub fn[T] State::binding(self : State[T]) -> Binding[T] {
  Binding::new(get=() => self.get(), set=value => self.set(value))
}

///|
pub fn[T, U] State::derived(
  self : State[T],
  project : (T) -> U,
) -> DerivedState[U] {
  DerivedState::from_state(self, project)
}

///|
pub fn[T] State::version(self : State[T]) -> Int {
  self.slot.version
}

///|
pub fn[T] State::subscribe(
  self : State[T],
  callback : () -> Unit,
) -> StateSubscription {
  self.slot.subscribe(callback)
}

///|
pub fn[T] Binding::get(self : Binding[T]) -> T {
  (self.get_value)()
}

///|
pub fn[T] Binding::set(self : Binding[T], value : T) -> Unit {
  (self.set_value)(value)
}

///|
pub fn[T] Binding::update(
  self : Binding[T],
  f : (T) -> T raise?,
) -> Unit raise? {
  self.set(f(self.get()))
}

///|
pub fn[T] Binding::new(get~ : () -> T, set~ : (T) -> Unit) -> Binding[T] {
  { get_value: get, set_value: set }
}

///|
pub fn[T] DerivedState::new(
  get~ : () -> T,
  subscribe~ : (() -> Unit) -> Array[StateSubscription],
) -> DerivedState[T] {
  { get_value: get, subscribe_value: subscribe }
}

///|
pub fn[T] DerivedState::get(self : DerivedState[T]) -> T {
  (self.get_value)()
}

///|
pub fn[T] DerivedState::subscribe(
  self : DerivedState[T],
  callback : () -> Unit,
) -> Array[StateSubscription] {
  (self.subscribe_value)(callback)
}

///|
pub fn[T, U] DerivedState::from_state(
  state : State[T],
  project : (T) -> U,
) -> DerivedState[U] {
  DerivedState::new(get=() => project(state.get()), subscribe=callback => {
    [state.subscribe(callback)]
  })
}

///|
pub fn[A, B, T] DerivedState::combine(
  left : State[A],
  right : State[B],
  project : (A, B) -> T,
) -> DerivedState[T] {
  DerivedState::new(get=() => project(left.get(), right.get()), subscribe=callback => {
    [left.subscribe(callback), right.subscribe(callback)]
  })
}
