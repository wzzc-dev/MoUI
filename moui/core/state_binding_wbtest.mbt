///|
test "state slot version increments on set and update" {
  let slot = StateSlot::new(1)
  inspect(slot.version, content="0")
  slot.set(2)
  inspect(slot.get(), content="2")
  inspect(slot.version, content="1")
  slot.update(value => value + 1)
  inspect(slot.get(), content="3")
  inspect(slot.version, content="2")
}

///|
test "state and binding share updates" {
  let state = State::new(1)
  let binding = state.binding()
  binding.set(2)
  inspect(state.get(), content="2")
  binding.update(value => value + 3)
  inspect(state.get(), content="5")
  inspect(state.version(), content="2")
}

///|
test "custom binding delegates get and set" {
  let value = Ref(false)
  let binding = Binding::new(get=() => value.val, set=next => value.val = next)
  inspect(binding.get(), content="false")
  binding.set(true)
  inspect(value.val, content="true")
  binding.update(current => !current)
  inspect(value.val, content="false")
}
