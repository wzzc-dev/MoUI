///|
test "center card and title render simple content" {
  let root : @core.View[Unit] = @views.center(
    @views.card(@views.text("Centered").title()),
    width=400.0,
    height=300.0,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=400.0, height=300.0),
  )
  assert_true(has_text(runtime.draw_commands(), "Centered"))
}

///|
test "form field primitives build labels helper and errors" {
  let root : @core.View[Unit] = @views.form(
    [
      @views.form_section(
        [
          @views.form_field(
            label="Name",
            child=@views.text_field("Ada", on_input=_value => ()),
            helper="Shown on normal fields",
            required=true,
          ),
          @views.form_field(
            label="Email",
            child=@views.text_field("", on_input=_value => ()),
            error="Email is required",
            status=@views.FormFieldStatus::Invalid,
          ),
          @views.form_validation_summary(
            summary=@core.FormValidationSummary::from_errors([
              { name: "email", message: "Email is required" },
              { name: "token", message: "Token is expired" },
            ]),
            action=Some(
              @views.StateViewAction::new(label="Focus first", message=()),
            ),
          ),
          @views.form_field(
            label="Token",
            child=@views.text_field("readonly", on_input=_value => ()),
            status=@views.FormFieldStatus::ReadOnly,
            layout=@views.FormFieldLayout::Horizontal,
          ),
          @views.form_actions(
            primary=@views.StateViewAction::new(
              label="Save changes",
              message=(),
            ),
            secondary=Some(
              @views.StateViewAction::new(label="Cancel", message=()),
            ),
            status="Submit disabled until Email is valid",
            primary_enabled=false,
          ),
        ],
        title="Profile",
        summary="Grouped fields",
        width=420.0,
      ),
    ],
    width=440.0,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=320.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Profile"))
  assert_true(has_text(commands, "Name *"))
  assert_true(has_text(commands, "Shown on normal fields"))
  assert_true(has_text(commands, "Email is required"))
  assert_true(has_text(commands, "Review required"))
  assert_true(has_text(commands, "First invalid: email"))
  assert_true(has_text(commands, "token: Token is expired"))
  assert_true(has_text(commands, "Focus first"))
  assert_true(has_text(commands, "Submit disabled until Email is valid"))
  assert_true(has_text(commands, "Save changes"))
  assert_true(has_text(commands, "Cancel"))
  assert_true(runtime.semantics().children.length() > 0)
  guard find_semantics_label(runtime.semantics(), "Validation summary")
    is Some(summary) else {
    fail("expected validation summary semantics")
  }
  assert_true(summary.state.invalid)
  guard find_semantics_label(runtime.semantics(), "Save changes") is Some(save) else {
    fail("expected save action semantics")
  }
  assert_true(save.state.disabled)
}

///|
test "form workflow bar links validation focus and keyboard action status" {
  let focus_scope = @core.FocusScope::new(
    items=[
      @core.FocusScopeItem::new(id="name"),
      @core.FocusScopeItem::new(id="email"),
      @core.FocusScopeItem::new(id="archived", enabled=false),
      @core.FocusScopeItem::new(id="submit", focusable=false),
    ],
    current=Some("name"),
    default_action="submit",
    dismiss_action="cancel",
  )
  let invalid_summary = @core.FormValidationSummary::from_errors([
    { name: "email", message: "Email is required" },
  ])
  let invalid_runtime = @core.AppRuntime::new_view(
    root=@views.form_workflow_bar(
      summary=invalid_summary,
      primary=@views.StateViewAction::new(label="Save", message=()),
      secondary=Some(@views.StateViewAction::new(label="Cancel", message=())),
      focus_scope=Some(focus_scope),
      focus_invalid=Some(
        @views.StateViewAction::new(label="Focus first", message=()),
      ),
      width=420.0,
    ),
    size=@core.Size::new(width=480.0, height=240.0),
  )
  let invalid_draw = invalid_runtime.draw_commands()
  assert_true(has_text(invalid_draw, "Review required"))
  assert_true(has_text(invalid_draw, "First invalid: email"))
  assert_true(has_text(invalid_draw, "Focus first"))
  assert_true(has_text(invalid_draw, "Fix email before submit"))
  guard find_semantics_label(invalid_runtime.semantics(), "Form workflow")
    is Some(workflow) else {
    fail("expected form workflow semantics")
  }
  assert_true(workflow.state.invalid)
  guard find_semantics_label(invalid_runtime.semantics(), "Save") is Some(save) else {
    fail("expected disabled primary action")
  }
  assert_true(save.state.disabled)
  let valid_runtime = @core.AppRuntime::new_view(
    root=@views.form_workflow_bar(
      summary=@core.FormValidationSummary::from_errors([]),
      primary=@views.StateViewAction::new(label="Save", message=()),
      secondary=Some(@views.StateViewAction::new(label="Cancel", message=())),
      focus_scope=Some(focus_scope),
      valid_message="All required fields pass",
      width=420.0,
    ),
    size=@core.Size::new(width=480.0, height=220.0),
  )
  let valid_draw = valid_runtime.draw_commands()
  assert_true(has_text(valid_draw, "All required fields pass"))
  assert_true(has_text(valid_draw, "Enter: submit / Escape: cancel"))
  guard find_semantics_label(valid_runtime.semantics(), "Save")
    is Some(valid_save) else {
    fail("expected enabled primary action")
  }
  assert_false(valid_save.state.disabled)
}

///|
test "form validation display can hide support text" {
  let root : @core.View[Unit] = @views.form_field(
    label="Hidden",
    child=@views.text_field("", on_input=_value => ()),
    error="Should not draw",
    validation_display=@views.FormValidationDisplay::Hidden,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=360.0, height=120.0),
  )
  assert_false(has_text(runtime.draw_commands(), "Should not draw"))
}

///|
test "form field validating state exposes preview semantics" {
  let root : @core.View[Unit] = @views.form_field(
    label="Workspace slug",
    child=@views.text_field("", on_input=_value => ()),
    helper="Checking availability.",
    status=@views.FormFieldStatus::Validating,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=480.0, height=160.0),
  )
  assert_true(
    has_text(runtime.draw_commands(), "Checking availability. Validating..."),
  )
  guard find_semantics_label(runtime.semantics(), "Workspace slug, validating")
    is Some(field) else {
    fail("expected validating form field semantics")
  }
  assert_false(field.state.invalid)
  inspect(field.description, content="Checking availability. Validating...")
}

///|
test "form field state uses core validation errors" {
  let field = @core.FormFieldState::new(name="email", label="Email", rules=[
    @core.FormValidationRule::required(message="Email required"),
  ])
  let root : @core.View[Unit] = @views.form_field_state(
    field~,
    child=@views.text_field(field.value.get(), on_input=_value => ()),
    required=true,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=420.0, height=140.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Email *"))
  assert_true(has_text(commands, "Email required"))
}

///|
test "enhanced input wrappers compose public controls" {
  let root : @core.View[Unit] = @views.form([
    @views.input_group(
      child=@views.text_field("Grouped", on_input=_value => ()),
      prefix=Some(@views.text("$", width=20.0, height=24.0)),
      suffix=Some(@views.text("USD", width=44.0, height=24.0)),
    ),
    @views.clearable_text_field("Search", on_input=_value => (), on_clear=()),
    @views.password_field(
      "secret",
      on_input=_value => (),
      revealed=false,
      on_toggle_reveal=(),
    ),
    @views.number_field("42", on_input=_value => (), on_step=Some(_delta => ())),
    @views.stepper(on_decrement=(), on_increment=(), label="Page"),
    @views.multiline_text_area_shell("Line one", on_input=_value => ()),
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=380.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Grouped"))
  assert_true(has_text(commands, "USD"))
  assert_true(has_text(commands, "Clear"))
  assert_true(has_text(commands, "Show"))
  assert_false(has_text(commands, "secret"))
  assert_true(has_text(commands, "******"))
  assert_true(has_text(commands, "42"))
  assert_true(has_text(commands, "Page"))
  assert_true(has_text(commands, "Line one"))
}

///|
test "grouped choice controls compose selections and chips" {
  let choices = [
    @views.choice_item("native", "Native"),
    @views.choice_item("web", "Web"),
    @views.choice_item("test", "Test"),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.radio_group(choices, selected="native", on_select=_id => ()),
    @views.checkbox_group(choices, selected=["native", "test"], on_change=(
      _id,
      _checked,
    ) => ()),
    @views.segmented_control(choices, selected="web", on_select=_id => ()),
    @views.row([
      @views.chip("Stable", selected=true),
      @views.tag("Tag"),
      @views.filter_chip("Filter", selected=false, on_change=_value => ()),
      @views.choice_chip("Choice", selected=true, on_select=()),
    ]),
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=560.0, height=360.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Native"))
  assert_true(has_text(commands, "Web"))
  assert_true(has_text(commands, "Test"))
  assert_true(has_text(commands, "Stable"))
  assert_true(has_text(commands, "Tag"))
  assert_true(has_text(commands, "Filter"))
  assert_true(has_text(commands, "Choice"))
}

///|
test "component semantics expose selection validation and expanded states" {
  let choices = [
    @views.choice_item("native", "Native"),
    @views.choice_item("web", "Web"),
  ]
  let tree_items = [
    @views.tree_item(id="root", label="Root", children=[
      @views.tree_item(id="leaf", label="Leaf"),
    ]),
  ]
  let commands = [
    @views.MenuItem::new(id="save", label="Save", message=()),
    @views.MenuItem::new(id="open", label="Open", message=()),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.form_field(
      label="Email",
      child=@views.text_field("", on_input=_value => ()),
      error="Email required",
      required=true,
    ),
    @views.segmented_control(choices, selected="web", on_select=_id => ()),
    @views.tree_view(tree_items, expanded=["root"], selected="leaf"),
    @views.button_group(commands, selected="save"),
    @views.button("Pressed action").semantics_pressed(),
    @views.button("Disabled action").disabled(),
    @views.inline_error("Sync failed"),
  ])
  let semantics = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=520.0),
  ).semantics()
  guard find_semantics_label(semantics, "Email, invalid, Email required")
    is Some(email) else {
    fail("expected email form field semantics")
  }
  assert_true(email.role == @core.SemanticsRole::FormField)
  assert_true(email.state.invalid)
  assert_true(email.state.required)
  inspect(email.description, content="Email required")
  guard find_semantics_label(semantics, "Web") is Some(web) else {
    fail("expected selected segment semantics")
  }
  assert_true(web.role == @core.SemanticsRole::Tab)
  assert_true(web.state.selected)
  guard find_semantics_label(semantics, "Root") is Some(root_item) else {
    fail("expected root tree item semantics")
  }
  assert_true(root_item.role == @core.SemanticsRole::TreeItem)
  assert_true(root_item.state.expanded)
  guard find_semantics_label(semantics, "Leaf") is Some(leaf_item) else {
    fail("expected leaf tree item semantics")
  }
  assert_true(leaf_item.state.selected)
  guard find_semantics_label(semantics, "Save") is Some(save) else {
    fail("expected button group selected item")
  }
  assert_true(save.state.selected)
  guard find_semantics_label(semantics, "Pressed action") is Some(pressed) else {
    fail("expected pressed semantics")
  }
  assert_true(pressed.state.pressed)
  guard find_semantics_label(semantics, "Disabled action") is Some(disabled) else {
    fail("expected disabled semantics")
  }
  assert_true(disabled.state.disabled)
  guard find_semantics_label(semantics, "Error: Sync failed")
    is Some(inline_error) else {
    fail("expected inline error semantics")
  }
  assert_true(inline_error.role == @core.SemanticsRole::Group)
  assert_true(inline_error.state.invalid)
}

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
