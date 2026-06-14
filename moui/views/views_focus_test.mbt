///|
test "shortcut button renders hint and dispatches keyboard shortcut" {
  let selected = Ref("")
  let shortcut = @core.KeyboardShortcut::new(
    key="s",
    modifiers=@core.KeyModifiers::new(meta=true),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.shortcut_button("Save", on_click="save", shortcut~, width=220.0),
    size=@core.Size::new(width=260.0, height=90.0),
    on_message=Some(message => selected.val = message),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Meta+s"))
  guard find_semantics_label(runtime.semantics(), "Save, shortcut Meta+s")
    is Some(node) else {
    fail("expected shortcut button semantics")
  }
  inspect(node.description, content="Shortcut Meta+s")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(selected.val, content="save")
}

///|
test "focus ring exposes app owned focus state" {
  let runtime = test_runtime(
    @views.column([
      @views.focus_ring(
        @views.text("Name field", width=96.0, height=24.0),
        focused=true,
        label="Focus target: name",
        width=140.0,
        height=42.0,
      ),
      @views.focus_ring(
        @views.text("Email field", width=96.0, height=24.0),
        focused=false,
        label="Focus target: email",
        width=140.0,
        height=42.0,
      ),
    ]),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Name field"))
  assert_true(has_text(commands, "Email field"))
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::StrokeRoundedRectBrush(_, _, 2.0)
    }),
  )
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Focus target: name") is Some(name) else {
    fail("expected focused ring semantics")
  }
  assert_true(name.state.selected)
  inspect(name.description, content="Focused")
  assert_true(
    name.actions.any(action => action == @core.SemanticsAction::Focus),
  )
  guard find_semantics_label(semantics, "Focus target: email") is Some(email) else {
    fail("expected unfocused ring semantics")
  }
  assert_false(email.state.selected)
  inspect(email.description, content="Not focused")
}
