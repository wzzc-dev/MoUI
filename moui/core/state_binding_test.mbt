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

///|
test "derived state projects and combines sources" {
  let left = State::new(2)
  let right = State::new(3)
  let doubled = left.derived(value => value * 2)
  inspect(doubled.get(), content="4")
  left.set(5)
  inspect(doubled.get(), content="10")
  let sum = DerivedState::combine(left, right, (a, b) => a + b)
  inspect(sum.get(), content="8")
  right.set(7)
  inspect(sum.get(), content="12")
}
