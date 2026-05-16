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
