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
  let runtime = @core.AppRuntime::new_view(
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
  let runtime = @core.AppRuntime::new_view(
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
test "public view gesture wrappers can be composed from views" {
  let log = Ref("")
  let root = @views.surface(
      @views.text("Gesture", width=120.0),
      width=160.0,
      height=80.0,
    )
    .on_double_tap("double")
    .on_long_press("long")
    .on_drag(event => event.phase.label())
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=120.0),
    on_message=Some(message => log.val = log.val + message + ";"),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
        time_ms=0.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Up,
        time_ms=20.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=11.0, y=10.0),
        phase=@core.PointerPhase::Down,
        time_ms=160.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=11.0, y=10.0),
        phase=@core.PointerPhase::Up,
        time_ms=180.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
        time_ms=400.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Move,
        time_ms=920.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
        time_ms=940.0,
      ),
    ),
  )
  inspect(log.val, content="double;long;")
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
  let runtime = @core.AppRuntime::new_view(
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
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=400.0, height=120.0),
  )
  let layout = runtime.layout()
  inspect(layout.children[0].frame.size.width, content="240")
}

///|
test "drop zone maps dropped files to app message" {
  let seen = Ref("")
  let root : @core.View[Array[String]] = @views.drop_zone(
    title="Drop files here",
    on_drop=paths => paths,
    width=240.0,
    height=80.0,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=320.0, height=160.0),
    on_message=Some(paths => if paths.length() > 0 { seen.val = paths[0] }),
  )
  runtime.dispatch_event(
    @core.AppEvent::DragDrop(
      @core.DragDropEvent::new(
        phase=@core.DragDropPhase::Dropped,
        paths=["/tmp/import.csv"],
        position=Some(@core.Point::new(x=12.0, y=12.0)),
      ),
    ),
  )
  inspect(seen.val, content="/tmp/import.csv")
}

///|
test "file import panel renders empty and unavailable states" {
  let empty = @core.AppRuntime::new_view(
    root=@views.file_import_panel(
      selection=@views.FileSelection::new(paths=[]),
      on_drop=_paths => (),
      on_browse=Some(()),
      empty_message="No file chosen",
      width=320.0,
    ),
    size=@core.Size::new(width=360.0, height=280.0),
  ).draw_commands()
  assert_true(has_text(empty, "No file chosen"))
  assert_true(has_text(empty, "Browse"))

  let unavailable = @core.AppRuntime::new_view(
    root=@views.file_import_panel(
      selection=@views.FileSelection::new(paths=["/tmp/a.txt"]),
      on_drop=_paths => (),
      availability=@views.FileImportAvailability::Unavailable(
        "File dialog unavailable",
      ),
      width=320.0,
    ),
    size=@core.Size::new(width=360.0, height=280.0),
  ).draw_commands()
  assert_true(has_text(unavailable, "File dialog unavailable"))
  assert_true(has_text(unavailable, "/tmp/a.txt"))
}

///|
test "menu bar and command menu render enabled disabled items" {
  let sections = [
    @views.CommandMenuSection::new(title="File", commands=[
      @core.ActionCommand::new(intent=@core.CommandIntent::Submit, label="Save"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Cancel,
        label="Close",
        enabled=false,
      ),
    ]),
  ]
  let runtime = test_runtime(
    @views.column([
      @views.menu_bar(
        [
          @views.MenuItem::new(id="file", label="File", message=()),
          @views.MenuItem::new(
            id="edit",
            label="Edit",
            message=(),
            enabled=false,
          ),
        ],
        active="file",
      ),
      @views.command_menu(sections, on_select=_intent => (), width=280.0),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "File"))
  assert_true(has_text(draw, "Edit"))
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Close"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Menu bar") is Some(menu_bar) else {
    fail("expected menu bar semantics")
  }
  assert_true(menu_bar.role == @core.SemanticsRole::Menu)
  guard find_semantics_label(semantics, "File") is Some(file) else {
    fail("expected selected menu item")
  }
  assert_true(file.state.selected)
  guard find_semantics_label(semantics, "Edit") is Some(edit) else {
    fail("expected disabled menu item")
  }
  assert_true(edit.state.disabled)
  guard find_semantics_label(semantics, "Command menu") is Some(command_menu) else {
    fail("expected command menu semantics")
  }
  assert_true(command_menu.role == @core.SemanticsRole::Menu)
}

///|
test "command menu dispatches enabled command and ignores disabled command" {
  let selected = Ref("")
  let sections = [
    @views.CommandMenuSection::new(title="", commands=[
      @core.ActionCommand::new(intent=@core.CommandIntent::Submit, label="Save"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Cancel,
        label="Cancel",
        enabled=false,
      ),
    ]),
  ]
  let runtime = @core.AppRuntime::new_view(
    root=@views.command_menu(sections, on_select=intent => intent, width=280.0),
    size=@core.Size::new(width=320.0, height=220.0),
    on_message=Some(intent => selected.val = intent.display_label()),
  )
  guard text_frame(runtime.draw_commands(), "Save") is Some(save_frame) else {
    fail("expected enabled command row")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=save_frame.origin.x + 4.0,
          y=save_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=save_frame.origin.x + 4.0,
          y=save_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="Submit")
  selected.val = ""
  guard text_frame(runtime.draw_commands(), "Cancel") is Some(cancel_frame) else {
    fail("expected disabled command row")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=cancel_frame.origin.x + 4.0,
          y=cancel_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=cancel_frame.origin.x + 4.0,
          y=cancel_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="")
}

///|
test "context menu region can render fallback view menu" {
  let runtime = test_runtime(
    @views.context_menu_region(
      child=@views.text("Region"),
      menu=@views.command_menu(
        [
          @views.CommandMenuSection::new(title="Actions", commands=[
            @core.ActionCommand::new(
              intent=@core.CommandIntent::Copy,
              label="Copy Item",
            ),
          ]),
        ],
        on_select=_intent => (),
        width=240.0,
      ),
      visible=true,
    ),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Region"))
  assert_true(has_text(draw, "Copy Item"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Context menu region") is Some(node) else {
    fail("expected context menu region semantics")
  }
  assert_true(node.state.expanded)
  assert_true(
    node.actions.any(action => action == @core.SemanticsAction::Collapse),
  )
  let hidden_runtime = test_runtime(
    @views.context_menu_region(
      child=@views.text("Region"),
      menu=@views.command_menu(
        [
          @views.CommandMenuSection::new(title="Actions", commands=[
            @core.ActionCommand::new(
              intent=@core.CommandIntent::Copy,
              label="Copy Item",
            ),
          ]),
        ],
        on_select=_intent => (),
        width=240.0,
      ),
      visible=false,
    ),
  )
  guard find_semantics_label(hidden_runtime.semantics(), "Context menu region")
    is Some(hidden_node) else {
    fail("expected hidden context menu region semantics")
  }
  assert_false(hidden_node.state.expanded)
  assert_true(
    hidden_node.actions.any(action => action == @core.SemanticsAction::Expand),
  )
}
