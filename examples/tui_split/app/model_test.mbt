///|
/// Pure model transitions: no runtime, no rendering. These pin the rules the
/// projection tests then rely on.

///|
/// Two idioms are deliberate here. Array facts go through `join(",")` or
/// `length()` instead of `inspect` of a `Debug` repr, because the repr's
/// spacing is a formatter detail, not a contract. And `@app.` qualification is
/// required: a `_test.mbt` file is compiled as its own package, so it only sees
/// the app's public surface — which is also why this file cannot reach the
/// model's private helpers.

///|
test "pane and selection model transitions" {
  let model = @app.Model::new()
  let (after_tab, _) = model.update(@app.CyclePane(1))
  assert_true(after_tab.pane == @app.TreePane)
  let (after_move, _) = after_tab.update(@app.Move(1))
  inspect(after_move.selected_node, content="src/core")
  // Collapsing the root hides everything beneath it, so the next move steps
  // over the two rows that stay on screen.
  let (collapsed, _) = after_move.update(@app.ToggleNode("src"))
  inspect(collapsed.expanded.length(), content="2")
  inspect(
    @app.visible_node_ids(collapsed.tree, collapsed.expanded).join(","),
    content="src,moon.mod",
  )
  let (after_collapse_move, _) = collapsed.update(@app.Move(1))
  inspect(after_collapse_move.selected_node, content="moon.mod")
  let (expanded_again, _) = after_collapse_move.update(@app.ToggleNode("src"))
  inspect(expanded_again.expanded.length(), content="3")
  inspect(
    @app.visible_node_ids(expanded_again.tree, expanded_again.expanded).length(),
    content="7",
  )
}

///|
test "selection follows entry identity across head insert" {
  let model = @app.Model::new()
  let (moved, _) = model.update(@app.Move(4))
  inspect(@app.selected_entry_title(moved), content="Entry 4")
  let (inserted, _) = moved.update(@app.InsertEntry)
  inspect(inserted.entries.length(), content="17")
  inspect(inserted.entries[1].title, content="Entry 0")
  inspect(@app.selected_entry_title(inserted), content="Entry 4")
  let (removed, _) = inserted.update(@app.RemoveFocused)
  inspect(removed.entries.length(), content="16")
  inspect(@app.selected_entry_title(removed), content="Entry 5")
}

///|
test "tree rows flatten by expansion state" {
  let model = @app.Model::new()
  inspect(
    @app.visible_node_ids(model.tree, model.expanded).join(","),
    content="src,src/core,src/core/program.mbt,src/core/view.mbt,src/runtime,src/runtime/runtime.mbt,moon.mod",
  )
  // Folding only hides descendants: the two folders stay as rows because a
  // closed folder is still a row, and the unrelated root follows them.
  inspect(
    @app.visible_node_ids(model.tree, ["src"]).join(","),
    content="src,src/core,src/runtime,moon.mod",
  )
  // An expansion id that names nothing is ignored, so a stale id can neither
  // crash the flatten nor invent a row.
  inspect(
    @app.visible_node_ids(model.tree, ["src/core", "gone"]).join(","),
    content="src,moon.mod",
  )
}

///|
test "deleting a folder drops it and keeps a valid selection" {
  let model = @app.Model::new()
  let (moved, _) = model.update(@app.CyclePane(1))
  let (deleted, _) = moved.update(@app.RemoveFocused)
  inspect(deleted.selected_node, content="moon.mod")
  match @app.find_node(deleted.tree, "src") {
    None => ()
    Some(node) => fail("src still in the tree: " + node.label)
  }
  // The whole subtree's expansion ids go with it: a folder re-created later
  // under the same path must not silently start open.
  inspect(deleted.expanded.length(), content="0")
}
