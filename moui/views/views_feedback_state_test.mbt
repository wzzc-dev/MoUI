///|
test "feedback and state components compose visible status surfaces" {
  let action = @views.StateViewAction::new(label="Retry", message=())
  let root : @core.View[Unit] = @views.column([
    @views.toast("Saved", tone=@views.FeedbackTone::Success),
    @views.toast_stack(
      [
        @views.ToastStackItem::new(
          id="sync",
          message="Sync complete",
          tone=@views.FeedbackTone::Success,
          dismiss=Some(()),
        ),
        @views.ToastStackItem::new(
          id="offline",
          message="Offline retry queued",
          tone=@views.FeedbackTone::Warning,
          action=Some(action),
        ),
      ],
      width=380.0,
    ),
    @views.snackbar("Offline", action=Some(action)),
    @views.banner(
      "Heads up",
      "Sync is delayed",
      tone=@views.FeedbackTone::Warning,
    ),
    @views.callout("Tip", "Use filters to narrow results"),
    @views.empty_state("No items", "Create a first item", action=Some(action)),
    @views.loading_state(),
    @views.error_state("Failed", "Try again", action=Some(action)),
    @views.inline_error("Email is already used", action=Some(action)),
    @views.progress_status(
      "Export report",
      value=0.64,
      message="Preparing CSV rows",
      status="Running",
      action=Some(action),
      width=380.0,
    ),
    @views.row([
      @views.badge("Beta", tone=@views.BadgeTone::Accent),
      @views.status_badge(
        "Ready",
        tone=@views.BadgeTone::Success,
        detail="Sync pipeline ready",
      ),
      @views.stat_card("Views", "128", caption="Today"),
    ]),
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=680.0, height=880.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Saved"))
  assert_true(has_text(commands, "Sync complete"))
  assert_true(has_text(commands, "Offline retry queued"))
  assert_true(has_text(commands, "Dismiss"))
  assert_true(has_text(commands, "Offline"))
  assert_true(has_text(commands, "Retry"))
  assert_true(has_text(commands, "Heads up"))
  assert_true(has_text(commands, "No items"))
  assert_true(has_text(commands, "Loading"))
  assert_true(has_text(commands, "Failed"))
  assert_true(has_text(commands, "Email is already used"))
  assert_true(has_text(commands, "Export report"))
  assert_true(has_text(commands, "Preparing CSV rows"))
  assert_true(has_text(commands, "Running"))
  assert_true(has_text(commands, "Beta"))
  assert_true(has_text(commands, "Ready"))
  assert_true(has_text(commands, "128"))
  guard find_semantics_label(runtime.semantics(), "Dismiss") is Some(dismiss) else {
    fail("expected toast dismiss semantics")
  }
  assert_true(
    dismiss.actions.any(action => action == @core.SemanticsAction::Dismiss),
  )
  guard find_semantics_label(runtime.semantics(), "Progress: Export report")
    is Some(progress_status) else {
    fail("expected progress status semantics")
  }
  assert_true(progress_status.role == @core.SemanticsRole::Group)
  guard find_semantics_label(runtime.semantics(), "Progress")
    is Some(progress_node) else {
    fail("expected nested progress semantics")
  }
  assert_true(progress_node.role == @core.SemanticsRole::Progress)
  guard find_semantics_label(runtime.semantics(), "Status: Ready")
    is Some(status_badge) else {
    fail("expected status badge semantics")
  }
  assert_true(status_badge.role == @core.SemanticsRole::Text)
  inspect(status_badge.description, content="Sync pipeline ready")
}

///|
test "feedback and form components use theme semantic colors" {
  let success = @core.Color::rgba(r=0.18, g=0.72, b=0.38)
  let danger = @core.Color::rgba(r=0.92, g=0.18, b=0.28)
  let semantic_colors = @core.SemanticColorScale::{
    ..@core.Theme::light().semantic_colors,
    success,
    danger,
  }
  let theme = @core.Theme::light().with_semantic_colors(semantic_colors)
  let root : @core.View[Unit] = @views.column([
    @views.badge("Ready", tone=@views.BadgeTone::Success, theme~),
    @views.badge("Broken", tone=@views.BadgeTone::Danger, theme~),
    @views.form_validation_summary(
      summary=@core.FormValidationSummary::from_errors([
        { name: "email", message: "Email required" },
      ]),
      theme~,
    ),
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=420.0, height=220.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_solid_fill(commands, success))
  assert_true(has_solid_fill(commands, danger))
  assert_true(has_solid_fill(commands, danger.multiply_alpha(0.12)))
}

///|
test "data and toast state helpers keep app owned workflow state predictable" {
  let sort = @views.DataSortState::new(column="name")
    .toggle("name")
    .toggle("status")
  inspect(sort.column(), content="status")
  inspect(sort.ascending(), content="true")
  let page = @views.PaginationState::new(page=3, page_size=10, total_count=24).clamped()
  inspect(page.page(), content="2")
  inspect(page.start_index(), content="20")
  inspect(page.end_index(), content="24")
  let columns = @views.ColumnVisibilityState::new(visible=["name", "status"], locked=[
    "name",
  ])
  inspect(
    columns.set_visible("status", false).is_visible("status"),
    content="false",
  )
  inspect(columns.set_visible("name", false).is_visible("name"), content="true")
  let table_columns = [
    @views.table_column(id="name", label="Name", width=120.0),
    @views.table_column(id="status", label="Status", width=96.0),
    @views.table_column(id="owner", label="Owner", width=112.0),
  ]
  let widths = @views.ColumnWidthState::new(
      widths=table_columns,
      min_width=80.0,
      max_width=160.0,
    )
    .resize("status", 180.0)
    .resize("new", 40.0)
  inspect(widths.width_for("status", 96.0), content="160")
  inspect(widths.width_for("new", 120.0), content="80")
  let sized = widths.apply(table_columns)
  inspect(sized[1].width, content="160")
  let order = @views.ColumnOrderState::new(order=["name", "status", "owner"])
    .move_before("owner", "name")
    .move_before("status", "name")
  let ordered = order.ordered_columns(table_columns)
  inspect(ordered[0].id, content="owner")
  inspect(ordered[1].id, content="status")
  inspect(ordered[2].id, content="name")
  let selection = @views.SelectionState::new()
    .toggle("row-1")
    .toggle("row-2")
    .toggle("row-1")
  inspect(selection.count(), content="1")
  assert_true(selection.contains("row-2"))
  let queue = @views.ToastQueue::new()
    .push(
      @views.ToastQueueItem::new(
        id="saved",
        message="Saved",
        tone=@views.FeedbackTone::Success,
        dismiss=Some("dismiss-saved"),
        created_at_ms=0.0,
        ttl_ms=100.0,
      ),
    )
    .push(
      @views.ToastQueueItem::new(
        id="sticky",
        message="Sticky",
        created_at_ms=0.0,
      ),
    )
    .expire(150.0)
  let stack_items = queue.to_stack_items()
  inspect(stack_items.length(), content="1")
  inspect(stack_items[0].message, content="Sticky")
}

///|
test "progress status optional action dispatches typed message" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.progress_status(
      "Upload bundle",
      value=0.25,
      status="Uploading",
      action=Some(@views.StateViewAction::new(label="Cancel", message="cancel")),
      width=360.0,
    ),
    size=@core.Size::new(width=420.0, height=180.0),
    on_message=Some(message => selected.val = message),
  )
  guard text_frame(runtime.draw_commands(), "Cancel") is Some(cancel_frame) else {
    fail("expected progress action")
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
  inspect(selected.val, content="cancel")
}
