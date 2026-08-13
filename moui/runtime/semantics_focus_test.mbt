///|
test "runtime semantics: browsing focus is independent from input focus" {
  let semantic_id = runtime_test_semantic_id("test.browse-focus")
  let runtime = AppRuntime::new_view(
    root=(
      runtime_semantic_test_view(
        semantic_id~,
        role=@core.SemanticsRole::Button,
        label="Browse me",
        focusable=true,
      ) : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=60.0),
  )
  let initial = runtime_expect_full_semantics(runtime)
  guard runtime_semantic_node_by_id(initial, semantic_id) is Some(node) else {
    fail("missing browsing focus node")
  }
  assert_true(runtime.set_semantic_focus(Some(node.node_id)))
  let focused = runtime_expect_full_semantics(runtime)
  assert_eq(focused.semantic_focused(), Some(node.node_id))
  assert_eq(focused.focused(), None)
  assert_true(runtime.set_semantic_focus(None))
  assert_eq(runtime_expect_full_semantics(runtime).semantic_focused(), None)
}
