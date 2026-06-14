///|
test "toolbar and disclosure containers compose command surfaces" {
  let commands = [
    @views.MenuItem::new(id="save", label="Save", message=()),
    @views.MenuItem::new(id="delete", label="Delete", message=(), enabled=false),
  ]
  let sections = [
    @views.WizardStep::new(
      id="one",
      title="Section One",
      content=@views.text("One content", width=180.0),
    ),
    @views.WizardStep::new(
      id="two",
      title="Section Two",
      content=@views.text("Two content", width=180.0),
    ),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.toolbar([
      @views.button_group(commands, selected="save"),
      @views.command_bar(commands, width=220.0),
    ]),
    @views.status_bar(["Ready", "2 commands"]),
    @views.accordion(sections, expanded=["one"], on_toggle=_id => ()),
    @views.disclosure(
      "Inline Disclosure",
      content=@views.text("Inline content", width=180.0),
      expanded=true,
      on_toggle=(),
    ),
    @views.collapsible_panel(
      "Panel",
      content=@views.text("Panel content", width=180.0),
      expanded=true,
      on_toggle=(),
    ),
    @views.resizable_panel(
      content=@views.text("Resizable", width=160.0),
      size=180.0,
    ),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=760.0),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Delete"))
  assert_true(has_text(draw, "Ready"))
  assert_true(has_text(draw, "Section One"))
  assert_true(has_text(draw, "One content"))
  assert_false(has_text(draw, "Two content"))
  assert_true(has_text(draw, "Inline Disclosure"))
  assert_true(has_text(draw, "Inline content"))
  assert_true(has_text(draw, "Panel content"))
  assert_true(has_text(draw, "Resizable"))
}

///|
test "resizable panel drag handle emits controlled size" {
  let last_size = Ref(0.0)
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.resizable_panel(
      content=@views.text("Drag resize", width=120.0),
      size=180.0,
      height=80.0,
      min_size=120.0,
      max_size=240.0,
      on_drag=Some(size => size),
    ),
    size=@core.Size::new(width=300.0, height=120.0),
    on_message=Some(size => last_size.val = size),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=190.0, y=12.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=210.0, y=12.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=232.0, y=12.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  inspect(last_size.val, content="222")
}

///|
test "command palette renders command metadata and filters rows" {
  let commands = [
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Submit,
      label="Save Document",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="s",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      group="File",
      description="Persist the current document.",
    ),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Cancel,
      label="Close Panel",
      enabled=false,
      group="Window",
      description="Dismiss the active panel.",
    ),
  ]
  let root : @core.View[@core.CommandIntent] = @views.command_palette(
    commands,
    query="file",
    on_select=intent => intent,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=320.0),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Save Document"))
  assert_true(has_text(draw, "Meta+s"))
  assert_true(has_text(draw, "File - Persist the current document."))
  assert_false(has_text(draw, "Close Panel"))
}

///|
test "card supports independent optional dimensions" {
  let root : @core.View[Unit] = @views.card(@views.text("Wide"), width=240.0)
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=400.0, height=120.0),
  )
  let layout = runtime.layout()
  inspect(layout.children[0].frame.size.width, content="240")
}
