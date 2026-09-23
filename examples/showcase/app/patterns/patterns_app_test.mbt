///|
test "pattern route aliases normalize" {
  inspect(@patterns.Model::new(route="examples").route(), content="counter")
  inspect(@patterns.Model::new(route="feedback").route(), content="workflow")
  inspect(@patterns.Model::new(route="layout").route(), content="workflow")
  inspect(@patterns.Model::new(route="todo").route(), content="todo")
}

///|
test "open keeps other pattern state" {
  let model = @patterns.update(@patterns.Model::new(route="counter"), Increment)
  inspect(model.counter, content="1")
  let opened = model.open("todo")
  inspect(opened.route(), content="todo")
  inspect(opened.counter, content="1")
}
