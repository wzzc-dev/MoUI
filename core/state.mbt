///|
pub(all) struct State[T] {
  slot : StateSlot[T]
}

///|
pub(all) struct Binding[T] {
  state : State[T]
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
  { state: self }
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
  self.state.get()
}

///|
pub fn[T] Binding::set(self : Binding[T], value : T) -> Unit {
  self.state.set(value)
}

///|
pub fn[T] Binding::update(
  self : Binding[T],
  f : (T) -> T raise?,
) -> Unit raise? {
  self.state.update(f)
}
