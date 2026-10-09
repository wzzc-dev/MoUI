///|
fn declaration_policy_changes(
  next : @core.ViewDeclaration,
  previous : @core.ViewDeclaration,
) -> (Bool, Bool, Bool, Bool) {
  let changes = next.changes_from(previous)
  (changes.layout(), changes.paint(), changes.semantics(), changes.platform())
}

///|
test "view declarations distinguish equal-length and exact numeric changes" {
  // Text layout measures the string, so swapping in different text invalidates
  // layout; a layout change in turn marks paint/semantics/platform dirty.
  let text_a : @core.View[Unit] = text("ab")
  let text_b : @core.View[Unit] = text("cd")
  debug_inspect(
    declaration_policy_changes(text_b.declaration(), text_a.declaration()),
    content="(true, true, true, true)",
  )

  let progress_a : @core.View[Unit] = progress(
    0.5,
    foreground=@core.Color::rgba(r=0.25, g=0.5, b=0.75),
  )
  let progress_b : @core.View[Unit] = progress(
    0.5000000000000001,
    foreground=@core.Color::rgba(r=0.25000000000000006, g=0.5, b=0.75),
  )
  debug_inspect(
    declaration_policy_changes(
      progress_b.declaration(),
      progress_a.declaration(),
    ),
    content="(false, true, true, false)",
  )
}

///|
test "controlled values are sampled into immutable node declarations" {
  let before : @core.View[Unit] = checkbox_control(
    label="Shared",
    checked=@core.ControlledValue::new(value=false, changed=_ => ()),
  )
  let after : @core.View[Unit] = checkbox_control(
    label="Shared",
    checked=@core.ControlledValue::new(value=true, changed=_ => ()),
  )
  debug_inspect(
    declaration_policy_changes(after.declaration(), before.declaration()),
    content="(false, true, true, false)",
  )
  assert_true(before.semantics().checked == Some(Unchecked))
  assert_true(after.semantics().checked == Some(Checked))
}

///|
test "aggregate themes and callback views declare uncacheable channels" {
  let themed : @core.View[Unit] = text("Theme", theme=@core.Theme::neutral())
  let themed_changes = themed.declaration().changes_from(themed.declaration())
  assert_false(themed_changes.layout())
  assert_true(themed_changes.paint())
  assert_false(themed_changes.semantics())
  assert_false(themed_changes.platform())

  let callback : @core.View[Unit] = canvas(
    measure=constraints => constraints.min,
    draw=(_context, _frame) => (),
    semantics_label="callback",
  )
  let callback_changes = callback
    .declaration()
    .changes_from(callback.declaration())
  assert_true(callback_changes.layout())
  assert_true(callback_changes.paint())
  assert_true(callback_changes.semantics())
  assert_true(callback_changes.platform())
}

///|
test "coordinate stage declares exact layout keys for design size and rects" {
  let leaf : @core.View[Unit] = text("go")
  let design : @core.View[Unit] = stage(width=640.0, height=480.0, [
    place(leaf, x=10.0, y=10.0, width=80.0, height=28.0),
  ])
  let wider : @core.View[Unit] = stage(width=800.0, height=480.0, [
    place(leaf, x=10.0, y=10.0, width=80.0, height=28.0),
  ])
  let moved : @core.View[Unit] = stage(width=640.0, height=480.0, [
    place(leaf, x=20.0, y=10.0, width=80.0, height=28.0),
  ])
  let resized : @core.View[Unit] = stage(width=640.0, height=480.0, [
    place(leaf, x=10.0, y=10.0, width=120.0, height=28.0),
  ])

  // A reused identity with identical inputs must stay clean.
  debug_inspect(
    declaration_policy_changes(design.declaration(), design.declaration()),
    content="(false, false, false, false)",
  )
  // Design size and placed rectangles both feed `layout()`, so each change must
  // dirty layout (and its dependents) instead of being cached as constant.
  debug_inspect(
    declaration_policy_changes(wider.declaration(), design.declaration()),
    content="(true, true, true, true)",
  )
  debug_inspect(
    declaration_policy_changes(moved.declaration(), design.declaration()),
    content="(true, true, true, true)",
  )
  debug_inspect(
    declaration_policy_changes(resized.declaration(), design.declaration()),
    content="(true, true, true, true)",
  )

  // Rect order is part of the key: swapping two equal-length entries is a change.
  let ordered : @core.View[Unit] = stage(width=640.0, height=480.0, [
    place(leaf, x=10.0, y=10.0, width=80.0, height=28.0),
    place(leaf, x=200.0, y=10.0, width=80.0, height=28.0),
  ])
  let swapped : @core.View[Unit] = stage(width=640.0, height=480.0, [
    place(leaf, x=200.0, y=10.0, width=80.0, height=28.0),
    place(leaf, x=10.0, y=10.0, width=80.0, height=28.0),
  ])
  debug_inspect(
    declaration_policy_changes(swapped.declaration(), ordered.declaration()),
    content="(true, true, true, true)",
  )
}
