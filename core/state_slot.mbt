///|
pub(all) struct StateSlot[T] {
  mut value : T
  mut version : Int
  mut listeners : Array[StateListener]
}

///|
pub(all) struct StateListener {
  mut active : Bool
  callback : () -> Unit
}

///|
pub(all) struct StateSubscription {
  listener : StateListener
}

pub fn[T] StateSlot::new(value : T) -> StateSlot[T] {
  { value, version: 0, listeners: [] }
}

///|
pub fn[T] StateSlot::get(self : StateSlot[T]) -> T {
  self.value
}

///|
pub fn[T] StateSlot::set(self : StateSlot[T], value : T) -> Unit {
  self.value = value
  self.version = self.version + 1
  self.notify()
}

///|
pub fn[T] StateSlot::update(
  self : StateSlot[T],
  f : (T) -> T raise?,
) -> Unit raise? {
  self.set(f(self.value))
}

///|
pub fn[T] StateSlot::subscribe(
  self : StateSlot[T],
  callback : () -> Unit,
) -> StateSubscription {
  self.prune_inactive_listeners()
  let listener = StateListener::new(callback)
  self.listeners.push(listener)
  { listener, }
}

///|
fn[T] StateSlot::notify(self : StateSlot[T]) -> Unit {
  for listener in self.listeners {
    if listener.active {
      (listener.callback)()
    }
  }
}

///|
fn[T] StateSlot::prune_inactive_listeners(self : StateSlot[T]) -> Unit {
  self.listeners = self.listeners.filter(listener => listener.active)
}

///|
pub fn StateListener::new(callback : () -> Unit) -> StateListener {
  { active: true, callback }
}

///|
pub fn StateSubscription::cancel(self : StateSubscription) -> Unit {
  self.listener.active = false
}

///|
pub fn StateSubscription::is_active(self : StateSubscription) -> Bool {
  self.listener.active
}

