///|
test "reusable control package paths are classified separately" {
  assert_true(
    is_control_package_source(
      "examples/custom_control/widgets/editable_counter.mbt",
    ),
  )
  assert_true(is_control_package_source("examples/example/widgets/button.mbt"))
  assert_false(is_control_package_source("examples/custom_control/app/app.mbt"))
  assert_false(is_control_package_source("website/playground/app/main.mbt"))
}

///|
test "control package allowance removes only declared protocol tokens" {
  let forbidden = [
    "TextControlStateContext", "ComponentContext", "State[", "ViewStateSlot",
  ]
  let control_tokens = control_package_forbidden_tokens(forbidden, [
    "TextControlStateContext",
  ])
  assert_false(string_array_contains(control_tokens, "TextControlStateContext"))
  assert_true(string_array_contains(control_tokens, "ComponentContext"))
  assert_true(string_array_contains(control_tokens, "State["))
  assert_true(string_array_contains(control_tokens, "ViewStateSlot"))
}
