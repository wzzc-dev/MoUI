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
  let text_a : @core.View[Unit] = text("ab")
  let text_b : @core.View[Unit] = text("cd")
  debug_inspect(
    declaration_policy_changes(text_b.declaration(), text_a.declaration()),
    content="(false, true, true, false)",
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
  assert_true(
    before.semantics().checked == Some(@core.SemanticsCheckedState::Unchecked),
  )
  assert_true(
    after.semantics().checked == Some(@core.SemanticsCheckedState::Checked),
  )
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
