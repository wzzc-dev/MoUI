///|
test "data display components compose tables trees descriptions and avatars" {
  let columns = [
    @views.table_column(id="name", label="Name", width=120.0),
    @views.table_column(id="state", label="State", width=96.0),
  ]
  let tree = [
    @views.tree_item(id="root", label="Root", children=[
      @views.tree_item(id="leaf", label="Leaf"),
    ]),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.description_list([
      @views.description_item("Owner", "Mira"),
      @views.description_item("Status", "Active"),
    ]),
    @views.data_filter_bar(
      query="atlas",
      on_query=_value => (),
      filters=[
        @views.data_filter(
          id="active",
          label="Active",
          selected=true,
          message=(),
        ),
        @views.data_filter(
          id="paused",
          label="Paused",
          selected=false,
          message=(),
          enabled=false,
        ),
      ],
      result_count=2,
      on_clear=Some(()),
      width=420.0,
    ),
    @views.table(
      columns,
      [["Atlas", "Active"], ["Billing", "Review"]],
      selected_row=Some(1),
      sort_column="state",
      sort_ascending=false,
      on_sort=Some(_id => ()),
    ),
    @views.selectable_list(
      [
        @views.SelectableListItem::new(
          id="pipeline",
          title="Pipeline Alpha",
          subtitle="Healthy",
          detail="Owner Mira",
          message=(),
        ),
        @views.SelectableListItem::new(
          id="queue",
          title="Queue Beta",
          subtitle="Review required",
          detail="Owner Noah",
          message=(),
        ),
        @views.SelectableListItem::new(
          id="archive",
          title="Archive Locked",
          subtitle="Read only",
          detail="Owner Iris",
          message=(),
          enabled=false,
        ),
      ],
      selected="queue",
      width=420.0,
      row_height=58.0,
    ),
    @views.selection_toolbar(
      selected_count=2,
      total_count=5,
      actions=[
        @views.MenuItem::new(id="archive", label="Archive", message=()),
        @views.MenuItem::new(id="export", label="Export", message=()),
      ],
      on_clear=Some(()),
      width=420.0,
    ),
    @views.column_visibility_panel(
      columns,
      visible=["name"],
      locked=["name"],
      on_toggle=(_id, _visible) => (),
      width=420.0,
    ),
    @views.pagination(page=1, page_count=3, on_previous=(), on_next=()),
    @views.detail_panel(
      "Selected row",
      [
        @views.description_item("Project", "Billing"),
        @views.description_item("Owner", "Noah"),
      ],
      subtitle="Compact detail panel",
    ),
    @views.selectable_list([], empty=Some(@views.text("No list items"))),
    @views.table(columns, [], empty=Some(@views.text("No data"))),
    @views.tree_view(tree, expanded=["root"], selected="leaf"),
    @views.avatar("Mira", size=32.0),
    @views.avatar_group(["Mira", "Noah", "Iris", "Ava", "Kai"], size=28.0),
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=720.0, height=680.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Owner"))
  assert_true(has_text(commands, "Mira"))
  assert_true(has_text(commands, "atlas"))
  assert_true(has_text(commands, "2 results"))
  assert_true(has_text(commands, "Active"))
  assert_true(has_text(commands, "Paused"))
  assert_true(has_text(commands, "Clear"))
  assert_true(has_text(commands, "Name"))
  assert_true(has_text(commands, "State v"))
  assert_true(has_text(commands, "Atlas"))
  assert_true(has_text(commands, "Billing"))
  assert_true(has_text(commands, "Pipeline Alpha"))
  assert_true(has_text(commands, "Review required"))
  assert_true(has_text(commands, "Owner Noah"))
  assert_true(has_text(commands, "Archive Locked"))
  assert_true(has_text(commands, "2 of 5 selected"))
  assert_true(has_text(commands, "Archive"))
  assert_true(has_text(commands, "Export"))
  assert_true(has_text(commands, "Column visibility"))
  assert_true(has_text(commands, "1 of 2 columns visible"))
  assert_true(has_text(commands, "Hidden"))
  assert_true(has_text(commands, "Page 2 of 3"))
  assert_true(has_text(commands, "Selected row"))
  assert_true(has_text(commands, "Compact detail panel"))
  assert_true(has_text(commands, "Noah"))
  assert_true(has_text(commands, "No list items"))
  assert_true(has_text(commands, "No data"))
  assert_true(has_text(commands, "Root"))
  assert_true(has_text(commands, "Leaf"))
  assert_true(has_text(commands, "+1"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Selectable list") is Some(list) else {
    fail("expected selectable list semantics")
  }
  assert_true(list.role == @core.SemanticsRole::List)
  guard find_semantics_label(
      semantics, "Queue Beta, Review required, Owner Noah",
    )
    is Some(selected_item) else {
    fail("expected selected list item semantics")
  }
  assert_true(selected_item.role == @core.SemanticsRole::ListItem)
  assert_true(selected_item.state.selected)
  guard find_semantics_label(semantics, "Archive Locked, Read only, Owner Iris")
    is Some(disabled_item) else {
    fail("expected disabled list item semantics")
  }
  assert_true(disabled_item.state.disabled)
}

///|
test "data filter bar dispatches filters and disables unavailable actions" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.data_filter_bar(
      query="atlas",
      on_query=value => "query:" + value,
      filters=[
        @views.data_filter(
          id="active",
          label="Active",
          selected=true,
          message="active",
        ),
        @views.data_filter(
          id="review",
          label="Review",
          selected=false,
          message="review",
        ),
        @views.data_filter(
          id="paused",
          label="Paused",
          selected=false,
          message="paused",
          enabled=false,
        ),
      ],
      result_count=2,
      on_clear=Some("clear"),
      width=420.0,
    ),
    size=@core.Size::new(width=460.0, height=140.0),
    on_message=Some(message => selected.val = message),
  )
  guard find_semantics_label(runtime.semantics(), "Active") is Some(active) else {
    fail("expected active filter semantics")
  }
  assert_true(active.state.selected)
  assert_false(active.state.disabled)
  guard find_semantics_label(runtime.semantics(), "Review") is Some(review) else {
    fail("expected review filter semantics")
  }
  assert_false(review.state.selected)
  assert_false(review.state.disabled)
  guard find_semantics_label(runtime.semantics(), "Paused") is Some(paused) else {
    fail("expected disabled paused filter semantics")
  }
  assert_true(paused.state.disabled)
  guard find_semantics_label(runtime.semantics(), "Clear") is Some(clear) else {
    fail("expected clear filter semantics")
  }
  assert_false(clear.state.disabled)
  click_text(runtime, "Review")
  inspect(selected.val, content="review")
  selected.val = ""
  click_text(runtime, "Paused")
  inspect(selected.val, content="")
  click_text(runtime, "Clear")
  inspect(selected.val, content="clear")
  selected.val = ""
  let empty_runtime = @core.AppRuntime::new_view(
    root=@views.data_filter_bar(
      query="",
      on_query=value => "query:" + value,
      filters=[
        @views.data_filter(
          id="active",
          label="Active",
          selected=false,
          message="active",
        ),
      ],
      result_count=10,
      on_clear=Some("clear"),
      width=420.0,
    ),
    size=@core.Size::new(width=460.0, height=140.0),
    on_message=Some(message => selected.val = message),
  )
  guard find_semantics_label(empty_runtime.semantics(), "Clear")
    is Some(disabled_clear) else {
    fail("expected disabled clear filter semantics")
  }
  assert_true(disabled_clear.state.disabled)
  click_text(empty_runtime, "Clear")
  inspect(selected.val, content="")
}

///|
test "column visibility panel dispatches controlled column toggles" {
  let toggled = Ref("")
  let columns = [
    @views.table_column(id="name", label="Name", width=120.0),
    @views.table_column(id="status", label="Status", width=96.0),
    @views.table_column(id="owner", label="Owner", width=112.0),
  ]
  let runtime = @core.AppRuntime::new_view(
    root=@views.column_visibility_panel(
      columns,
      visible=["name", "owner"],
      locked=["name"],
      on_toggle=(id, next_visible) => {
        let state = if next_visible { "shown" } else { "hidden" }
        id + ":" + state
      },
      width=360.0,
    ),
    size=@core.Size::new(width=400.0, height=220.0),
    on_message=Some(message => toggled.val = message),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Column visibility"))
  assert_true(has_text(commands, "2 of 3 columns visible"))
  assert_true(has_text(commands, "Name"))
  assert_true(has_text(commands, "Status"))
  assert_true(has_text(commands, "Owner"))
  assert_true(has_text(commands, "Shown"))
  assert_true(has_text(commands, "Hidden"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Column visibility") is Some(panel) else {
    fail("expected column visibility panel semantics")
  }
  assert_true(panel.role == @core.SemanticsRole::Group)
  inspect(panel.description, content="2 of 3 columns visible")
  guard find_semantics_label(semantics, "Name, Shown") is Some(name) else {
    fail("expected locked visible column semantics")
  }
  assert_true(name.state.selected)
  assert_true(name.state.disabled)
  guard find_semantics_label(semantics, "Status, Hidden") is Some(status) else {
    fail("expected hidden column semantics")
  }
  assert_false(status.state.selected)
  guard text_frame(commands, "Status") is Some(status_frame) else {
    fail("expected status column row")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=status_frame.origin.y + 4.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=status_frame.origin.y + 4.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(toggled.val, content="status:shown")
}

///|
test "selectable list dispatches item messages" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.selectable_list(
      [
        @views.SelectableListItem::new(
          id="alpha",
          title="Pipeline Alpha",
          subtitle="Healthy",
          message="alpha",
        ),
        @views.SelectableListItem::new(
          id="beta",
          title="Queue Beta",
          subtitle="Review required",
          message="beta",
        ),
      ],
      selected="alpha",
      width=360.0,
    ),
    size=@core.Size::new(width=400.0, height=180.0),
    on_message=Some(message => selected.val = message),
  )
  guard text_frame(runtime.draw_commands(), "Queue Beta") is Some(beta_frame) else {
    fail("expected selectable list item")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=beta_frame.origin.x + 4.0,
          y=beta_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=beta_frame.origin.x + 4.0,
          y=beta_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="beta")
}

///|
test "table row selection dispatches row index" {
  let selected = Ref(-1)
  let columns = [
    @views.table_column(id="name", label="Name", width=120.0),
    @views.table_column(id="state", label="State", width=96.0),
  ]
  let runtime = @core.AppRuntime::new_view(
    root=@views.table(
      columns,
      [["Atlas", "Active"], ["Billing", "Review"]],
      on_row_select=Some(index => index),
    ),
    size=@core.Size::new(width=260.0, height=140.0),
    on_message=Some(index => selected.val = index),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=88.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=88.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="1")
}

///|
test "selection toolbar dispatches enabled bulk action and disables empty selection" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.selection_toolbar(
      selected_count=2,
      total_count=4,
      actions=[
        @views.MenuItem::new(id="archive", label="Archive", message="archive"),
        @views.MenuItem::new(
          id="delete",
          label="Delete",
          message="delete",
          enabled=false,
        ),
      ],
      on_clear=Some("clear"),
      width=420.0,
    ),
    size=@core.Size::new(width=460.0, height=120.0),
    on_message=Some(message => selected.val = message),
  )
  assert_true(has_text(runtime.draw_commands(), "2 of 4 selected"))
  guard text_frame(runtime.draw_commands(), "Archive") is Some(archive_frame) else {
    fail("expected enabled bulk action")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=archive_frame.origin.x + 4.0,
          y=archive_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=archive_frame.origin.x + 4.0,
          y=archive_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="archive")
  selected.val = ""
  let empty_runtime = @core.AppRuntime::new_view(
    root=@views.selection_toolbar(
      selected_count=0,
      actions=[
        @views.MenuItem::new(id="archive", label="Archive", message="archive"),
      ],
      on_clear=Some("clear"),
      width=420.0,
    ),
    size=@core.Size::new(width=460.0, height=120.0),
    on_message=Some(message => selected.val = message),
  )
  assert_true(has_text(empty_runtime.draw_commands(), "No rows selected"))
  guard find_semantics_label(empty_runtime.semantics(), "Selection toolbar")
    is Some(toolbar) else {
    fail("expected selection toolbar semantics")
  }
  assert_false(toolbar.state.selected)
  guard find_semantics_label(empty_runtime.semantics(), "Archive")
    is Some(empty_archive) else {
    fail("expected disabled empty selection action")
  }
  assert_true(empty_archive.state.disabled)
}

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
      selection=@views.FileSelection::empty(),
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
