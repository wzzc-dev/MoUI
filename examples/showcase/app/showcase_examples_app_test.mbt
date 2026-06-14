///|
test "showcase embeds reusable example apps and renderer report" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .runtime(width=760.0, height=420.0)
  let example_commands = runtime.draw_commands()
  assert_true(has_text(example_commands, "Examples"))
  assert_true(has_text(example_commands, "Counter Preview"))
  assert_true(has_text(example_commands, "MoUI Counter"))
  assert_true(has_text(example_commands, "Todo Preview"))
  assert_true(has_text(example_commands, "MoUI Todo"))
  assert_false(has_text(example_commands, "Markdown Preview"))
  let markdown_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("text-media"))
    .update(
      @app.ShowcaseMsg::DraftChanged("# Local Markdown\n\nA **bold** word"),
    )
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_true(has_text(markdown_commands, "Text & Media"))
  assert_true(has_text(markdown_commands, "Local Markdown"))
  let renderer_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("runtime-renderer"))
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_true(has_text(renderer_commands, "Runtime & Renderer"))
  assert_true(has_text(renderer_commands, "Host capability"))
  assert_true(has_text(renderer_commands, "Showcase test host / Test"))
  assert_true(has_text(renderer_commands, "Renderer capability"))
}

///|
test "showcase counter preview increments through shared runtime" {
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .update(@app.ShowcaseMsg::CounterIncrement)
  let runtime = model.runtime(width=760.0, height=420.0)
  inspect(model.counter_count, content="1")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Count: 1"))
}

///|
test "showcase todo model updates add toggle and remove" {
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::TodoDraftChanged("Write tests"))
    .update(@app.ShowcaseMsg::TodoSubmitDraft)
  inspect(model.todo_count(), content="3")
  let toggled = model.update(@app.ShowcaseMsg::TodoToggled(2, true))
  guard toggled.todo_items is [_, _, { id: 2, completed: true, .. }] else {
    fail("expected added item toggled")
  }
  inspect(
    toggled.update(@app.ShowcaseMsg::TodoRemove(2)).todo_count(),
    content="2",
  )
}

///|
test "showcase todo preview keeps keyed rows after toggle" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .runtime(width=960.0, height=760.0)
  let before = runtime.draw_commands()
  assert_true(has_text(before, "Reuse Todo state"))
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .update(@app.ShowcaseMsg::TodoToggled(0, true))
  let after = model.runtime(width=960.0, height=760.0).draw_commands()
  assert_true(has_text(after, "Reuse Todo state"))
  guard model.todo_items is [{ completed: true, .. }, ..] else {
    fail("expected first built-in todo item toggled")
  }
}

///|
test "showcase todo preview accepts draft submission" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .runtime(width=760.0, height=420.0)
  assert_true(has_text(runtime.draw_commands(), "New todo"))
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .update(@app.ShowcaseMsg::TodoDraftChanged("ab"))
    .update(@app.ShowcaseMsg::TodoSubmitDraft)
  let submitted_runtime = model.runtime(width=760.0, height=420.0)
  guard model.todo_items is [_, _, { id: 2, text: "ab", completed: false }] else {
    fail("expected draft text submitted as next todo item")
  }
  inspect(model.todo_draft, content="")
  assert_true(has_text(submitted_runtime.draw_commands(), "ab"))
}
