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
  let runtime = @runtime.AppRuntime::new_view(
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
