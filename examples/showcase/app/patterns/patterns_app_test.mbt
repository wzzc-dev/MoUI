///|
test "pattern route aliases normalize" {
  inspect(Model::new(route="examples").route(), content="counter")
  inspect(Model::new(route="feedback").route(), content="workflow")
  inspect(Model::new(route="layout").route(), content="workflow")
  inspect(Model::new(route="todo").route(), content="todo")
}

///|
test "open keeps other pattern state" {
  let model = update(Model::new(route="counter"), Increment)
  inspect(model.counter, content="1")
  let opened = model.open("todo")
  inspect(opened.route(), content="todo")
  inspect(opened.counter, content="1")
}
