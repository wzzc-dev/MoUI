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
