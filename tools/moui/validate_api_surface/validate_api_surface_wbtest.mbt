///|
test "line count ignores trailing generated blank lines" {
  inspect(line_count(""), content="0")
  inspect(line_count("one"), content="1")
  inspect(line_count("one\n"), content="1")
  inspect(line_count("one\n\n"), content="1")
  inspect(line_count("one\ntwo"), content="2")
  inspect(line_count("one\ntwo\n\n"), content="2")
}

///|
fn budget_by_label(label : String) -> PackageBudget raise {
  for budget in package_budgets() {
    if budget.label == label {
      return budget
    }
  }
  fail("missing package budget: " + label)
}

///|
test "root facade budget keeps runtime and diagnostics out" {
  let root = budget_by_label("root facade")
  inspect(root.max_pub_all_lines, content="0")
  assert_true(root.required_tokens.contains("pub using @core {type View}"))
  assert_true(root.required_tokens.contains("pub using @core {type Program}"))
  assert_true(
    root.forbidden_tokens.contains("pub using @core {type AppRuntime}"),
  )
  assert_true(root.forbidden_tokens.contains("DrawCommand"))
  assert_true(root.forbidden_tokens.contains("ProgramRuntimeSnapshot"))
}

///|
test "runtime facade budget pins the opaque wrapper boundary" {
  let runtime = budget_by_label("runtime facade")
  inspect(runtime.max_pub_all_lines, content="0")
  assert_true(runtime.required_tokens.contains("pub struct AppRuntime"))
  assert_true(runtime.required_tokens.contains("pub fn[Msg] new_view("))
  assert_true(
    runtime.required_tokens.contains(
      "pub fn[Model, Msg] AppRuntime::new_program(",
    ),
  )
  assert_true(runtime.forbidden_tokens.contains("RuntimeState"))
  assert_true(runtime.forbidden_tokens.contains("inner : @core.AppRuntime"))
}

///|
test "core view construction is reserved for views facade consumers" {
  inspect(core_control_consumer_roots().contains("moui/views"), content="false")
  inspect(runtime_consumer_roots().contains("moui/views"), content="true")
  let tokens = forbidden_core_control_tokens().map(rule => rule.token)
  inspect(tokens.length(), content="54")
  assert_true(tokens.contains("@core.View::empty("))
  assert_true(tokens.contains("@core.View::button("))
  assert_true(tokens.contains("@core.View::component("))
  assert_true(tokens.contains("@core.View::controlled_text_field("))
  assert_true(tokens.contains("@core.View::controlled_search_bar("))
  assert_true(tokens.contains("@core.View::primitive_button_view("))
  assert_true(tokens.contains("@core.View::primitive_component_view("))
  assert_true(
    tokens.contains("@core.View::primitive_controlled_text_field_view("),
  )
}

///|
test "views return rules cover app-facing constructors" {
  let names = view_return_rules().map(rule => rule.name)
  assert_true(names.contains("button"))
  assert_true(names.contains("column"))
  assert_true(names.contains("text_field"))
  assert_true(names.contains("markdown_editor"))
  assert_true(names.contains("navigation_stack"))
  assert_true(names.contains("web_view"))
  for rule in view_return_rules() {
    inspect(rule.return_token, content="-> @core.View[Msg]")
  }
}
