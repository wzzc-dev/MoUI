test "counter increments" {
  let model = update(Model::new(), Increment)
  assert_eq(model.count, 1)
}

test "counter decrements" {
  let model = update(Model::new(), Decrement)
  assert_eq(model.count, -1)
}

test "counter resets" {
  let model = update(update(Model::new(), Increment), Increment)
  let model = update(model, Reset)
  assert_eq(model.count, 0)
}

test "view renders without error" {
  let _v = view(Model::new())
  assert_true(true)
}
