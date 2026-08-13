///|
fn probe_node_with_id(
  snapshot : @runtime.SemanticsSnapshot,
  id : String,
) -> @core.SemanticsNode? {
  for node in snapshot.nodes() {
    match node.semantic_id {
      Some(semantic_id) if semantic_id.value() == id => return Some(node)
      _ => ()
    }
  }
  None
}

///|
fn require_probe_node(
  snapshot : @runtime.SemanticsSnapshot,
  id : String,
) -> @core.SemanticsNode {
  probe_node_with_id(snapshot, id).unwrap_or_else(() => {
    abort("missing semantic node: " + id)
  })
}

///|
test "accessibility probe publishes contracts and modal lifecycle" {
  let app = ShowcaseApp::new().program_with_initial_route(
    "showcase/accessibility-probe",
  )
  let runtime = @runtime.AppRuntime::new_program(
    program=app,
    size=@geometry.Size::new(width=1024.0, height=1200.0),
  )
  let snapshot = match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => snapshot
    _ => fail("expected full accessibility probe snapshot")
  }
  let required = [
    "a11y.button", "a11y.checkbox", "a11y.slider", "a11y.textfield", "a11y.tree",
    "a11y.grid", "a11y.scroll", "a11y.status", "a11y.alert", "a11y.image", "a11y.separator",
  ]
  let seen : Array[String] = []
  for node in snapshot.nodes() {
    match node.semantic_id {
      Some(id) => seen.push(id.value())
      None => ()
    }
  }
  for id in required {
    assert_true(seen.contains(id))
  }
  assert_false(seen.contains("a11y.dialog"))
  assert_eq(snapshot.issues(), [])

  let button = require_probe_node(snapshot, "a11y.button")
  assert_eq(button.role, @core.SemanticsRole::Button)
  assert_eq(button.label, "Open probe dialog")
  assert_true(button.actions.contains(@core.SemanticsActionKind::Activate))
  let checkbox = require_probe_node(snapshot, "a11y.checkbox")
  assert_eq(checkbox.role, @core.SemanticsRole::Checkbox)
  assert_eq(checkbox.state.checked, Some(@core.SemanticsCheckedState::Checked))
  let slider = require_probe_node(snapshot, "a11y.slider")
  assert_eq(slider.role, @core.SemanticsRole::Slider)
  guard slider.numeric is Some(numeric) else {
    fail("slider missing numeric metadata")
  }
  assert_eq(numeric.min, Some(0.0))
  assert_eq(numeric.max, Some(1.0))
  assert_eq(numeric.step, Some(0.1))
  assert_true(slider.actions.contains(@core.SemanticsActionKind::Increment))
  assert_true(slider.actions.contains(@core.SemanticsActionKind::Decrement))
  assert_true(
    slider.actions.contains(@core.SemanticsActionKind::SetNumericValue),
  )
  let textfield = require_probe_node(snapshot, "a11y.textfield")
  assert_eq(textfield.role, @core.SemanticsRole::TextField)
  assert_eq(textfield.value, "mobile-service-probe")
  guard textfield.text is Some(text) else {
    fail("textfield missing text metadata")
  }
  assert_true(text.editable)
  assert_true(
    textfield.actions.contains(@core.SemanticsActionKind::SetSelection),
  )

  let after_toggle = match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(
        @core.SemanticId::parse("a11y.checkbox").unwrap(),
      ),
      action: @core.SemanticsAction::Activate,
      precondition: @runtime.SemanticsGenerationPrecondition::Exact(
        snapshot.generation(),
      ),
    }) {
    Ok(receipt) =>
      match runtime.read_semantics(since=snapshot.generation()) {
        Ok(@runtime.SemanticsRead::Delta(delta)) => {
          assert_eq(delta.to(), receipt.after)
          assert_true(
            delta
            .announcements()
            .any(announcement => {
              announcement.text.contains("Actions: 1") &&
              announcement.live == @core.SemanticsLive::Polite &&
              announcement.is_atomic
            }),
          )
          runtime_expect_probe_snapshot(runtime, receipt.after)
        }
        _ => fail("expected checkbox semantics delta")
      }
    Err(_) => fail("probe checkbox action rejected")
  }

  let after_open = match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(
        @core.SemanticId::parse("a11y.button").unwrap(),
      ),
      action: @core.SemanticsAction::Activate,
      precondition: @runtime.SemanticsGenerationPrecondition::Exact(
        after_toggle.generation(),
      ),
    }) {
    Ok(receipt) => runtime_expect_probe_snapshot(runtime, receipt.after)
    Err(_) => fail("probe button action rejected")
  }
  let dialog = require_probe_node(after_open, "a11y.dialog")
  assert_eq(dialog.role, @core.SemanticsRole::Dialog)
  assert_true(dialog.state.modal)
  assert_true(dialog.actions.contains(@core.SemanticsActionKind::Dismiss))
  let after_close = match
    runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(
        @core.SemanticId::parse("a11y.dialog").unwrap(),
      ),
      action: @core.SemanticsAction::Dismiss,
      precondition: @runtime.SemanticsGenerationPrecondition::Exact(
        after_open.generation(),
      ),
    }) {
    Ok(receipt) => runtime_expect_probe_snapshot(runtime, receipt.after)
    Err(_) => fail("probe dialog dismiss rejected")
  }
  assert_eq(probe_node_with_id(after_close, "a11y.dialog"), None)
}

///|
fn runtime_expect_probe_snapshot(
  runtime : @runtime.AppRuntime,
  generation : @core.SemanticsGeneration,
) -> @runtime.SemanticsSnapshot {
  match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => {
      if snapshot.generation() != generation {
        abort("probe snapshot generation mismatch")
      }
      snapshot
    }
    _ => abort("expected probe snapshot")
  }
}
