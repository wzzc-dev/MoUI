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
