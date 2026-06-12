///|
test "popover dropdown combobox and autocomplete compose menu surfaces" {
  let items = [
    @views.MenuItem::new(id="one", label="One", message=()),
    @views.MenuItem::new(id="two", label="Two", message=(), enabled=false),
  ]
  let dropdown_state = @views.DropdownState::new(expanded=true, selected="one")
  let root : @core.View[Unit] = @views.column([
    @views.popover(
      anchor=@views.button("Anchor", on_click=()),
      content=@views.text("Popover content", width=160.0),
      expanded=true,
    ),
    @views.dropdown("Mode", items, state=dropdown_state, on_toggle=()),
    @views.combobox(
      "O",
      on_input=_value => (),
      items,
      expanded=true,
      on_toggle=(),
    ),
    @views.autocomplete("T", on_input=_value => (), items, expanded=true),
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=640.0, height=520.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Anchor"))
  assert_true(has_text(commands, "Popover content"))
  assert_true(has_text(commands, "Mode: One"))
  assert_true(has_text(commands, "One"))
  assert_true(has_text(commands, "Two"))
  assert_true(has_text(commands, "Open"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Mode: One") is Some(dropdown) else {
    fail("expected dropdown anchor semantics")
  }
  assert_true(dropdown.role == @core.SemanticsRole::Menu)
  assert_true(dropdown.state.expanded)
  assert_true(
    dropdown.actions.any(action => action == @core.SemanticsAction::Collapse),
  )
  guard find_semantics_label(semantics, "Mode options") is Some(options) else {
    fail("expected dropdown menu semantics")
  }
  assert_true(options.role == @core.SemanticsRole::Menu)
  guard find_semantics_label(semantics, "One") is Some(one) else {
    fail("expected selected dropdown option")
  }
  assert_true(one.state.selected)
  guard find_semantics_label(semantics, "Two") is Some(two) else {
    fail("expected disabled dropdown option")
  }
  assert_true(two.state.disabled)
}

///|
test "alert composes dialog content and actions" {
  let primary = @views.StateViewAction::new(label="Confirm", message=())
  let secondary = @views.StateViewAction::new(label="Cancel", message=())
  let runtime = test_runtime(
    @views.alert(
      "Delete project",
      "This action cannot be undone.",
      primary_action=primary,
      secondary_action=Some(secondary),
      tone=@views.FeedbackTone::Danger,
    ),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Delete project"))
  assert_true(has_text(draw, "This action cannot be undone."))
  assert_true(has_text(draw, "Confirm"))
  assert_true(has_text(draw, "Cancel"))
  guard find_semantics_label(runtime.semantics(), "Delete project")
    is Some(alert) else {
    fail("expected alert dialog semantics")
  }
  assert_true(alert.role == @core.SemanticsRole::Dialog)
}

///|
test "dialog composes custom content dismiss and action messages" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.dialog(
      "Edit project",
      content=@views.description_list([
        @views.description_item("Owner", "Mira"),
        @views.description_item("Status", "Active"),
      ]),
      subtitle="Custom dialog content",
      primary_action=Some(
        @views.StateViewAction::new(label="Save", message="save"),
      ),
      secondary_action=Some(
        @views.StateViewAction::new(label="Cancel", message="cancel"),
      ),
      dismiss_action=Some(
        @views.StateViewAction::new(label="Dismiss", message="dismiss"),
      ),
      width=420.0,
      height=260.0,
    ),
    size=@core.Size::new(width=480.0, height=320.0),
    on_message=Some(message => selected.val = message),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Edit project"))
  assert_true(has_text(draw, "Custom dialog content"))
  assert_true(has_text(draw, "Owner"))
  assert_true(has_text(draw, "Mira"))
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Cancel"))
  guard text_frame(draw, "Edit project") is Some(title_frame) else {
    fail("expected dialog title")
  }
  guard text_frame(draw, "Custom dialog content") is Some(subtitle_frame) else {
    fail("expected dialog subtitle")
  }
  guard text_frame(draw, "Owner") is Some(owner_frame) else {
    fail("expected dialog body term")
  }
  guard text_frame(draw, "Active") is Some(active_frame) else {
    fail("expected dialog body detail")
  }
  guard text_frame(draw, "Cancel") is Some(cancel_frame) else {
    fail("expected secondary action")
  }
  guard text_frame(draw, "Save") is Some(save_frame) else {
    fail("expected primary action")
  }
  guard text_frame(draw, "Dismiss") is Some(dismiss_frame) else {
    fail("expected dismiss action")
  }
  guard smallest_rounded_brush_containing(draw, title_frame)
    is Some(dialog_frame) else {
    fail("expected dialog surface frame")
  }
  for
    frame in [
      title_frame, subtitle_frame, owner_frame, active_frame, cancel_frame, save_frame,
      dismiss_frame,
    ] {
    assert_true(rect_contains_rect(dialog_frame, frame))
  }
  assert_true(owner_frame.origin.y > subtitle_frame.origin.y)
  assert_true(cancel_frame.origin.y > active_frame.origin.y)
  assert_true(save_frame.origin.x > cancel_frame.origin.x)
  assert_true(dismiss_frame.origin.x > title_frame.origin.x)
  guard find_semantics_label(runtime.semantics(), "Edit project")
    is Some(dialog) else {
    fail("expected custom dialog semantics")
  }
  assert_true(dialog.role == @core.SemanticsRole::Dialog)
  guard find_semantics_label(runtime.semantics(), "Dismiss") is Some(close) else {
    fail("expected dismiss action semantics")
  }
  assert_true(
    close.actions.any(action => action == @core.SemanticsAction::Dismiss),
  )
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
  inspect(selected.val, content="save")
}

///|
test "dialog host uses transparent scrim and keeps modal boundary visible" {
  let runtime = @core.AppRuntime::new_view(
    root=@views.dialog_host(
      @views.text("Background", width=180.0, height=32.0),
      dialog=Some(
        @views.dialog(
          "Visible dialog",
          content=@views.text("Bounded modal content", width=300.0, height=40.0),
          subtitle="Clear boundary",
          primary_action=Some(
            @views.StateViewAction::new(label="Close", message=()),
          ),
          width=360.0,
          height=260.0,
        ),
      ),
      presented=true,
    ),
    size=@core.Size::new(width=640.0, height=480.0),
  )
  let draw = runtime.draw_commands()
  inspect(full_frame_solid_fill_count(draw), content="1")
  assert_true(has_full_frame_solid_fill(draw, alpha=0.22))
  assert_true(has_text(draw, "Visible dialog"))
  assert_true(has_text(draw, "Bounded modal content"))
  assert_true(has_text(draw, "Close"))
  assert_true(draw.any(command => command is @core.DrawCommand::DrawShadow(_)))
  assert_true(
    draw.any(command => {
      command is @core.DrawCommand::StrokeRoundedRectBrush(_, _, 1.0)
    }),
  )
}

///|
test "navigation shell components compose sidebar breadcrumb split and wizard" {
  let nav_items = [
    @views.SidebarItem::new(id="home", label="Home", message=()),
    @views.SidebarItem::new(id="settings", label="Settings", message=()),
  ]
  let section_items = [
    @views.SectionNavItem::new(
      id="builder",
      label="Builder",
      summary="App setup",
      message=(),
    ),
    @views.SectionNavItem::new(
      id="runtime",
      label="Runtime",
      summary="Renderer and host state",
      message=(),
    ),
    @views.SectionNavItem::new(
      id="billing",
      label="Billing",
      summary="Disabled section",
      message=(),
      enabled=false,
    ),
  ]
  let crumbs = [
    @views.BreadcrumbItem::new(id="root", label="Root", message=Some(())),
    @views.BreadcrumbItem::new(id="current", label="Current"),
  ]
  let steps = [
    @views.WizardStep::new(
      id="first",
      title="First",
      content=@views.text("First content", width=180.0),
    ),
    @views.WizardStep::new(
      id="second",
      title="Second",
      content=@views.text("Second content", width=180.0),
      enabled=false,
    ),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.route_header("Settings", subtitle="Manage workspace preferences", actions=[
      @views.MenuItem::new(id="save", label="Save", message=()),
      @views.MenuItem::new(
        id="export",
        label="Export",
        message=(),
        enabled=false,
      ),
    ]),
    @views.breadcrumb(crumbs),
    @views.section_nav(
      "Product Areas",
      section_items,
      selected="runtime",
      orientation=@core.Axis::Vertical,
      width=220.0,
    ),
    @views.split_view(
      primary=@views.sidebar("Sections", nav_items, selected="settings"),
      detail=@views.master_detail(
        master=@views.text("Master", width=120.0),
        detail=@views.text("Detail", width=160.0),
        master_width=120.0,
        detail_width=160.0,
        height=80.0,
      ),
      primary_width=220.0,
      detail_width=300.0,
      height=180.0,
    ),
    @views.wizard(steps, current="first", on_select=_route => ()),
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=620.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Settings"))
  assert_true(has_text(commands, "Manage workspace preferences"))
  assert_true(has_text(commands, "Save"))
  assert_true(has_text(commands, "Export"))
  assert_true(has_text(commands, "Root"))
  assert_true(has_text(commands, "Current"))
  assert_true(has_text(commands, "Product Areas"))
  assert_true(has_text(commands, "Builder"))
  assert_true(has_text(commands, "Renderer and host state"))
  assert_true(has_text(commands, "Disabled section"))
  assert_true(has_text(commands, "Sections"))
  assert_true(has_text(commands, "Home"))
  assert_true(has_text(commands, "Settings"))
  assert_true(has_text(commands, "Master"))
  assert_true(has_text(commands, "Detail"))
  assert_true(has_text(commands, "First"))
  assert_true(has_text(commands, "Second"))
  assert_true(has_text(commands, "First content"))
  guard find_semantics_label(
      runtime.semantics(),
      "Runtime, Renderer and host state",
    )
    is Some(runtime_section) else {
    fail("expected selected section navigation item semantics")
  }
  assert_true(runtime_section.role == @core.SemanticsRole::ListItem)
  assert_true(runtime_section.state.selected)
  guard find_semantics_label(runtime.semantics(), "Billing, Disabled section")
    is Some(disabled_section) else {
    fail("expected disabled section navigation item semantics")
  }
  assert_true(disabled_section.state.disabled)
}

///|
test "resizable split view drag handle emits controlled primary width" {
  let last_width = Ref(0.0)
  let runtime = @core.AppRuntime::new_view(
    root=@views.resizable_split_view(
      primary=@views.text("Primary", width=120.0, height=24.0),
      detail=@views.text("Detail", width=160.0, height=24.0),
      primary_width=180.0,
      detail_width=180.0,
      height=96.0,
      min_primary_width=140.0,
      max_primary_width=220.0,
      on_drag=width => width,
    ),
    size=@core.Size::new(width=420.0, height=140.0),
    on_message=Some(width => last_width.val = width),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Primary"))
  assert_true(has_text(commands, "Detail"))
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
        position=@core.Point::new(x=245.0, y=12.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  inspect(last_width.val, content="220")
}

///|
test "slider drag emits controlled value" {
  let last_value = Ref(0.0)
  let runtime = @core.AppRuntime::new_view(
    root=@views.slider(0.4, width=200.0, on_change=Some(value => value)),
    size=@core.Size::new(width=240.0, height=80.0),
    on_message=Some(value => last_value.val = value),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=80.0, y=14.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=140.0, y=14.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  assert_true(last_value.val >= 0.69)
  assert_true(last_value.val <= 0.71)
}

///|
test "slider drag remains stable across program rebuilds" {
  let seen = Ref(0.4)
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init=0.4,
      update=(_model, message) => {
        seen.val = message
        message
      },
      view=value => {
        @views.slider(value, width=200.0, on_change=Some(next => next))
      },
    ),
    size=@core.Size::new(width=240.0, height=80.0),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=80.0, y=14.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=140.0, y=14.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=180.0, y=14.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  assert_true(seen.val >= 0.89)
  assert_true(seen.val <= 0.91)
}

///|
test "section nav dispatches selected item messages" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.section_nav(
      "Areas",
      [
        @views.SectionNavItem::new(
          id="builder",
          label="Builder",
          summary="App setup",
          message="builder",
        ),
        @views.SectionNavItem::new(
          id="runtime",
          label="Runtime",
          summary="Renderer host",
          message="runtime",
        ),
        @views.SectionNavItem::new(
          id="billing",
          label="Billing",
          summary="Disabled",
          message="billing",
          enabled=false,
        ),
      ],
      selected="builder",
      width=480.0,
    ),
    size=@core.Size::new(width=520.0, height=140.0),
    on_message=Some(message => selected.val = message),
  )
  guard text_frame(runtime.draw_commands(), "Runtime") is Some(runtime_frame) else {
    fail("expected runtime section item")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=runtime_frame.origin.x + 4.0,
          y=runtime_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=runtime_frame.origin.x + 4.0,
          y=runtime_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="runtime")
}

///|
test "router stack selects route location path and preserves query params" {
  let router = @core.RouterState::new(
    initial=@core.RouteLocation::parse("/detail?id=42"),
  )
  let root : @core.View[Unit] = @views.router_stack(
    router,
    [
      @views.navigation_destination(
        route="/home",
        view=@views.text("Home route", width=120.0),
      ),
      @views.navigation_destination(
        route="/detail",
        view=@views.text("Detail route", width=120.0),
      ),
    ],
    fallback=@views.text("Missing route", width=120.0),
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=320.0, height=120.0),
  )
  assert_true(has_text(runtime.draw_commands(), "Detail route"))
  inspect(router.current().param_value("id").unwrap_or(""), content="42")
}
