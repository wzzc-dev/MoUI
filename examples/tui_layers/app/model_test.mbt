///|
/// Pure model transitions: no runtime, no rendering. These pin the rules the
/// projection tests then rely on.

///|
/// Arrays are compared through `join(",")` or `length()` rather than a `Debug`
/// repr, because repr spacing is a formatter detail, not a contract. `@app.`
/// qualification is required: a `_test.mbt` file compiles as its own package and
/// only sees the app's public surface.

///|
fn rows(model : @app.Model) -> String {
  @app.visible_layers(model).map(layer => layer.name).join(",")
}

///|
fn tree_rows(model : @app.Model) -> String {
  @app.visible_node_ids(model.tree, model.expanded).join(",")
}

///|
test "the pane cycle has three stops and wraps both ways" {
  let model = @app.Model::new()
  let (to_files, _) = model.update(@app.CyclePane(1))
  assert_true(to_files.pane == @app.FilesPane)
  let (to_filter, _) = to_files.update(@app.CyclePane(1))
  assert_true(to_filter.pane == @app.FilterPane)
  let (wrapped, _) = to_filter.update(@app.CyclePane(1))
  assert_true(wrapped.pane == @app.LayersPane)
  let (back, _) = model.update(@app.CyclePane(-1))
  assert_true(back.pane == @app.FilterPane)
  // A step of 0 is a no-op rather than a flip, so an unbound key cannot look
  // like a working Tab.
  let (still, _) = model.update(@app.CyclePane(0))
  assert_true(still.pane == @app.LayersPane)
}

///|
test "each keystroke of the filter reshapes the rows with no submit" {
  let model = @app.Model::new()
  inspect(@app.visible_layers(model).length(), content="8")
  let (typed_s, _) = model.update(@app.SetFilter("s"))
  inspect(@app.visible_layers(typed_s).length(), content="6")
  // Reaching the field is also what says "keys type, they do not command".
  assert_true(typed_s.pane == @app.FilterPane)
  let (typed_st, _) = typed_s.update(@app.SetFilter("st"))
  inspect(rows(typed_st), content="Strokes,Streamlines")
  let (typed_stro, _) = typed_st.update(@app.SetFilter("stro"))
  inspect(rows(typed_stro), content="Strokes")
  // Case is not part of the contract: a terminal user should not have to shift
  // to reach a layer whose name starts with a capital.
  let (upper, _) = model.update(@app.SetFilter("STR"))
  inspect(rows(upper), content="Strokes,Streamlines")
  let (cleared, _) = typed_stro.update(@app.SetFilter(""))
  inspect(@app.visible_layers(cleared).length(), content="8")
}

///|
test "selection stays attached to the layer across filtering" {
  let model = @app.Model::new()
  let (moved, _) = model.update(@app.Move(2))
  inspect(@app.selected_layer_name(moved), content="Strokes")
  // The filtered list is shorter and starts elsewhere, but the cursor must stay
  // on the layer it was on rather than on the row slot it happened to sit at.
  let (filtered, _) = moved.update(@app.SetFilter("str"))
  inspect(rows(filtered), content="Strokes,Streamlines")
  inspect(@app.selected_layer_name(filtered), content="Strokes")
  let (after_down, _) = filtered.update(@app.Move(1))
  inspect(@app.selected_layer_name(after_down), content="Streamlines")
  // A needle that matches nothing leaves the selection readable as "-": the
  // empty row list must not index out of bounds and must not invent a row.
  let (empty, _) = filtered.update(@app.SetFilter("zzz"))
  inspect(@app.visible_layers(empty).length(), content="0")
  inspect(@app.selected_layer_name(empty), content="Strokes")
  let (stuck, _) = empty.update(@app.Move(1))
  inspect(@app.selected_layer_name(stuck), content="Strokes")
}

///|
test "hiding a layer moves it out of the rows and the marker follows" {
  let model = @app.Model::new()
  inspect(@app.hidden_count(model), content="2")
  assert_true(@app.layer_marker(model, "l-stroke") == "[x]")
  let (hidden, _) = model.update(@app.ToggleLayer("l-stroke"))
  inspect(@app.hidden_count(hidden), content="3")
  assert_true(@app.layer_marker(hidden, "l-stroke") == "[ ]")
  let (shown, _) = hidden.update(@app.ToggleLayer("l-stroke"))
  inspect(@app.hidden_count(shown), content="2")
  // Folds are per-layer, so an id that names nothing stays visibly wrong instead
  // of silently reading as hidden.
  assert_true(@app.layer_marker(model, "l-gone") == "[?]")
  // `only-visible` is the other switch: it hides by rule, not by flipping facts.
  let (only, _) = model.update(@app.SetOnlyVisible(true))
  inspect(
    rows(only),
    content="Background,Grid,Strokes,Streamlines,Labels,Shadows",
  )
}

///|
test "a head insert shifts every row and keeps the cursor on its layer" {
  let model = @app.Model::new()
  let (moved, _) = model.update(@app.Move(1))
  inspect(@app.selected_layer_name(moved), content="Grid")
  let (inserted, _) = moved.update(@app.AddLayer)
  inspect(inserted.layers.length(), content="9")
  inspect(inserted.layers[0].name, content="Layer 0")
  inspect(inserted.layers[1].name, content="Background")
  inspect(@app.selected_layer_name(inserted), content="Grid")
  let (deleted, _) = inserted.update(@app.RemoveLayer)
  inspect(deleted.layers.length(), content="8")
  // The row that took the deleted slot keeps the cursor.
  inspect(@app.selected_layer_name(deleted), content="Strokes")
}

///|
test "folding a folder hides only its descendants" {
  let model = @app.Model::new()
  inspect(
    tree_rows(model),
    content="src,src/core,src/core/program.mbt,src/core/view.mbt,src/runtime,src/runtime/runtime.mbt,examples,examples/tui_split,examples/tui_layers,moon.mod",
  )
  let (folded, _) = model.update(@app.ToggleNode("src"))
  inspect(
    tree_rows(folded),
    content="src,examples,examples/tui_split,examples/tui_layers,moon.mod",
  )
  // Closing a leaf is a no-op on rows: the id expands nothing.
  let (leaf, _) = model.update(@app.ToggleNode("moon.mod"))
  inspect(tree_rows(leaf), content=tree_rows(model))
}

///|
test "scroll requests are per pane and clamped at zero" {
  let model = @app.Model::new()
  let (down, _) = model.update(@app.ScrollBy(@app.LayersPane, @app.scroll_line))
  inspect(down.layer_scroll, content="16")
  inspect(down.tree_scroll, content="0")
  let (up, _) = down.update(@app.ScrollBy(@app.LayersPane, 0.0 - 48.0))
  inspect(up.layer_scroll, content="0")
  let (set, _) = model.update(@app.SetScroll(@app.FilesPane, 32.0))
  inspect(set.tree_scroll, content="32")
  inspect(set.layer_scroll, content="0")
  // The filter line has no viewport, so a stray wheel over it must not scroll a
  // pane the user is not pointing at.
  let (nowhere, _) = model.update(@app.SetScroll(@app.FilterPane, 64.0))
  inspect(nowhere.layer_scroll, content="0")
  inspect(nowhere.tree_scroll, content="0")
}

///|
/// The shortcut key each declared command binds, read through the public command
/// accessors: this is the app's own key map, so a claim added in `program.mbt`
/// shows up here without the test having to restate it.
fn claimed_keys(model : @app.Model) -> Array[String] {
  let out : Array[String] = []
  for command in @app.program_commands(model) {
    match command.command().shortcut {
      Some(shortcut) => out.push(shortcut.key)
      None => ()
    }
  }
  out
}

///|
test "the typing pane releases the keys that type a space" {
  let model = @app.Model::new()
  let keys = claimed_keys(model)
  assert_true(keys.any(key => key == " "))
  let (typing, _) = model.update(@app.SetFilter("s"))
  let while_typing = claimed_keys(typing)
  assert_true(!while_typing.any(key => key == " "))
  assert_true(!while_typing.any(key => key == "Enter"))
  // Arrow keys stay claimed: a caret must not walk out of the field the user is
  // typing into, because the pane border is what says who owns the keyboard.
  assert_true(while_typing.any(key => key == "ArrowDown"))
  assert_true(while_typing.any(key => key == "Tab"))
}
