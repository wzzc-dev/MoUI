///|
test "showcase app emits visual polish commands" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "MoUI View Showcase"))
  assert_true(has_text(commands, "View Catalog"))
  assert_true(has_text(commands, "Overview"))
  assert_true(has_text(commands, "Controls"))
  let renderer_runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("runtime-renderer"))
    .runtime(width=760.0, height=420.0)
  let renderer_commands = renderer_runtime.draw_commands()
  assert_true(
    renderer_commands.any(command => {
      command is @core.DrawCommand::StrokeRoundedRectBrush(_, _, _)
    }),
  )
  assert_true(
    renderer_commands.any(command => command is @core.DrawCommand::DrawPath(_)),
  )
  assert_true(has_image_fit(renderer_commands, @core.ImageFit::ScaleDown))
  assert_true(has_image_fit(renderer_commands, @core.ImageFit::FitWidth))
  assert_true(has_image_fit(renderer_commands, @core.ImageFit::FitHeight))
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawImage(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushClip(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushOpacity(_)),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::FillRoundedRectBrush(
        _,
        @core.Brush::LinearGradient(_)
      )
    }),
  )
}

///|
test "showcase state toggles theme and active copy" {
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::ToggleScheme)
    .update(@app.ShowcaseMsg::ToggleActive)
  let runtime = model.runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "State-driven visuals are active"))
  assert_true(model.dark)
  assert_true(model.active)
}

///|
test "showcase navigation dialog and sheet state are wired" {
  let dialog_model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::ShowDialog)
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
  let dialog_commands = dialog_model
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_true(has_text(dialog_commands, "Showcase dialog"))
  assert_true(has_text(dialog_commands, "Custom content shell"))
  assert_true(has_text(dialog_commands, "Host"))
  assert_true(has_text(dialog_commands, "view-level"))
  assert_true(has_text(dialog_commands, "Dismiss"))
  let sheet_model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::ShowDialog)
    .update(@app.ShowcaseMsg::ShowSheet)
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
  let sheet_commands = sheet_model
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_false(has_text(sheet_commands, "Showcase dialog"))
  assert_true(has_text(sheet_commands, "Showcase sheet"))
  assert_true(
    sheet_commands.any(command => command is @core.DrawCommand::DrawShadow(_)),
  )
  assert_true(dialog_model.dialog_visible)
  assert_false(dialog_model.sheet_visible)
  assert_false(sheet_model.dialog_visible)
  assert_true(sheet_model.sheet_visible)
  assert_true(sheet_model.selected_section == "navigation")
}

///|
test "showcase bottom sheet wraps content instead of filling viewport" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::ShowSheet)
    .runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  guard text_frame(commands, "Showcase sheet") is Some(title_frame) else {
    fail("expected sheet title")
  }
  guard smallest_rounded_brush_containing(commands, title_frame)
    is Some(sheet_frame) else {
    fail("expected sheet surface frame")
  }
  assert_true(sheet_frame.size.height < 220.0)
  assert_true(sheet_frame.origin.y > 190.0)
  assert_true(sheet_frame.origin.y + sheet_frame.size.height <= 420.0)
  guard text_frame(
      commands, "Sheet content is built with the same presentation primitives.",
    )
    is Some(subtitle_frame) else {
    fail("expected sheet subtitle")
  }
  assert_true(subtitle_frame.origin.y >= sheet_frame.origin.y)
  assert_true(
    subtitle_frame.origin.y + subtitle_frame.size.height <=
    sheet_frame.origin.y + sheet_frame.size.height,
  )
}

///|
test "showcase open sheet button presents bottom sheet" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
    .update(@app.ShowcaseMsg::TabSelected("values"))
    .runtime(width=960.0, height=900.0)
  click_text(runtime, "Open sheet")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Showcase sheet"))
  guard text_frame(commands, "Showcase sheet") is Some(title_frame) else {
    fail("expected sheet title")
  }
  guard smallest_rounded_brush_containing(commands, title_frame)
    is Some(sheet_frame) else {
    fail("expected sheet surface frame")
  }
  assert_true(sheet_frame.origin.y > 560.0)
  let sheet_center_x = sheet_frame.origin.x + sheet_frame.size.width / 2.0
  assert_true((sheet_center_x - 480.0).abs() <= 1.0)
  click_text(runtime, "Showcase sheet")
  assert_true(has_text(runtime.draw_commands(), "Showcase sheet"))
  click_point(
    runtime,
    @core.Point::new(x=sheet_center_x, y=sheet_frame.origin.y - 24.0),
  )
  assert_false(has_text(runtime.draw_commands(), "Showcase sheet"))
  click_text(runtime, "Open sheet")
  assert_true(has_text(runtime.draw_commands(), "Showcase sheet"))
  click_text(runtime, "Done")
  assert_false(has_text(runtime.draw_commands(), "Showcase sheet"))
}

///|
test "showcase dialog sheet action replaces dialog" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::ShowDialog)
    .runtime(width=760.0, height=420.0)
  click_last_text(runtime, "Sheet")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Showcase sheet"))
  assert_false(has_text(commands, "Showcase dialog"))
}

///|
test "showcase navigation shell demos use public constructors" {
  let commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
    .runtime(width=960.0, height=620.0)
    .draw_commands()
  assert_true(has_text(commands, "Navigation"))
  assert_true(has_text(commands, "Catalog"))
  assert_true(has_text(commands, "Navigation Shell"))
  assert_true(has_text(commands, "Current route: navigation"))
  assert_true(has_text(commands, "Deep link: navigation"))
  assert_true(has_text(commands, "History: overview -> navigation"))
  assert_true(has_text(commands, "Route transition: fade + slide"))
  assert_true(has_text(commands, "Transition route: navigation"))
  assert_true(
    has_text(
      commands, "Transition state: host route subscription mirrors browser history",
    ),
  )
  assert_true(has_text(commands, "Section Nav"))
  assert_true(has_text(commands, "Shell routes"))
  assert_true(has_text(commands, "Native menu"))
  assert_true(has_text(commands, "Host gap"))
  assert_true(has_text(commands, "Dialog"))
  assert_true(has_text(commands, "Sheet"))
  assert_true(has_text(commands, "Master Detail"))
  assert_true(has_text(commands, "Wizard Step: Profile"))
  assert_true(has_text(commands, "Permissions"))
  assert_true(has_text(commands, "Review"))
  assert_true(has_text(commands, "New"))
  assert_true(has_text(commands, "Archive"))
  assert_true(has_text(commands, "Renderer neutral"))
}

///|
test "showcase route history keeps app owned deep link state" {
  let linked = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
    .update(@app.ShowcaseMsg::OpenRouteLink("navigation?panel=history"))
    .update(@app.ShowcaseMsg::SelectSection("forms"))
  inspect(linked.selected_section, content="forms")
  inspect(linked.route_history.current_route(), content="forms")
  assert_true(linked.route_history.can_go_back())
  let back = linked.update(@app.ShowcaseMsg::RouteBack)
  inspect(back.selected_section, content="navigation")
  inspect(
    back.route_history.current_route(),
    content="navigation?panel=history",
  )
  assert_true(back.route_history.can_go_back())
  assert_true(back.route_history.can_go_forward())
  let forked = back.update(@app.ShowcaseMsg::SelectSection("data"))
  inspect(forked.selected_section, content="data")
  inspect(forked.route_history.current_route(), content="data")
  assert_false(forked.route_history.can_go_forward())
  let commands = back.runtime(width=980.0, height=720.0).draw_commands()
  assert_true(has_text(commands, "Deep link: navigation?panel=history"))
  assert_true(has_text(commands, "Transition route: navigation?panel=history"))
  assert_true(
    has_text(
      commands, "History: overview -> navigation -> navigation?panel=history -> forms",
    ),
  )
}

///|
test "showcase route host emits push command for selected section" {
  let route_source = @host.HostRouteSource::new()
  let commands : Array[@app.ShowcaseRouteHistoryCommand] = []
  let route_host = @app.ShowcaseRouteHost::new(route_source~, dispatch_command=command => {
    commands.push(command)
  })
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
    .runtime_with_route_host(route_host, width=960.0, height=720.0)
  click_text(runtime, "Forms")
  inspect(commands.length(), content="1")
  match commands[0] {
    @app.ShowcaseRouteHistoryCommand::PushRoute(route) =>
      inspect(route, content="forms")
    _ => fail("expected route push command")
  }
  assert_true(has_text(runtime.draw_commands(), "Forms"))
}

///|
test "showcase route host subscription applies browser popstate route" {
  let route_source = @host.HostRouteSource::new()
  let commands : Array[@app.ShowcaseRouteHistoryCommand] = []
  let route_host = @app.ShowcaseRouteHost::new(route_source~, dispatch_command=command => {
    commands.push(command)
  })
  let runtime = @app.ShowcaseModel::new().runtime_with_route_host(
    route_host,
    width=960.0,
    height=720.0,
  )
  inspect(route_source.active_handler_count(), content="1")
  inspect(
    route_source.publish(
      @host.HostRouteEvent::from_route(
        route="navigation?panel=history",
        source="web-popstate",
      ),
    ),
    content="1",
  )
  inspect(commands.length(), content="0")
  let rendered = runtime.draw_commands()
  assert_true(has_text(rendered, "Deep link: navigation?panel=history"))
  assert_true(
    has_text(
      rendered, "Transition state: host route subscription mirrors browser history",
    ),
  )
}

///|
test "showcase sidebar catalog scrolls to lower sections" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  let size = @core.Size::new(width=760.0, height=420.0)
  assert_false(text_within(runtime.draw_commands(), "Interaction Lab", size))
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=80.0, y=330.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-260.0),
      ),
    ),
  )
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let scrolled_commands = runtime.draw_commands()
  let target_label = sidebar_visible_lower_label(scrolled_commands, size)
  assert_true(text_within(scrolled_commands, target_label, size))
  assert_true(has_sidebar_scrollbar(scrolled_commands))
  guard sidebar_scrollbar_frame(scrolled_commands) is Some(scrollbar_frame) else {
    fail("expected sidebar scrollbar frame")
  }
  guard text_frame(scrolled_commands, target_label) is Some(target) else {
    fail("expected scrolled sidebar item text")
  }
  assert_true(scrollbar_frame.origin.x > target.origin.x + target.size.width)
  assert_true(scrollbar_frame.origin.x < 236.0)
  let click_point = @core.Point::new(
    x=target.origin.x + target.size.width / 2.0,
    y=target.origin.y + target.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=click_point,
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=click_point,
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  assert_true(has_text(runtime.draw_commands(), target_label))
}

///|
test "showcase detail panel scrolls long section content" {
  let size = @core.Size::new(width=760.0, height=420.0)
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("layout"))
    .runtime(width=760.0, height=420.0)
  let initial_commands = runtime.draw_commands()
  assert_true(text_within(initial_commands, "Layout", size))
  assert_false(text_within(initial_commands, "Resizable Panel", size))
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=520.0, y=330.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-680.0),
      ),
    ),
  )
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let scrolled_commands = runtime.draw_commands()
  assert_true(text_within(scrolled_commands, "Resizable Panel", size))
  let reset_model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("layout"))
    .update(@app.ShowcaseMsg::DetailScrollTo(220.0))
    .update(@app.ShowcaseMsg::SelectSection("forms"))
  assert_true(reset_model.detail_scroll_offset.y == 0.0)
  let clamped_model = @app.ShowcaseModel::new().update(
    @app.ShowcaseMsg::DetailScrollTo(-16.0),
  )
  assert_true(clamped_model.detail_scroll_offset.y == 0.0)
}

///|
fn sidebar_visible_lower_label(
  commands : Array[@core.DrawCommand],
  size : @core.Size,
) -> String {
  for label in ["Runtime/Renderer", "Diagnostics", "Feedback"] {
    if text_within(commands, label, size) {
      return label
    }
  }
  "Diagnostics"
}

///|
test "showcase covers text media controls and layout sections" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("text-media"))
    .runtime(width=760.0, height=420.0)
  let text_commands = runtime.draw_commands()
  assert_true(has_text(text_commands, "Text & Media"))
  assert_true(has_text(text_commands, "Label text"))
  let control_runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("controls"))
    .update(@app.ShowcaseMsg::TabSelected("values"))
    .runtime(width=760.0, height=420.0)
  let control_commands = control_runtime.draw_commands()
  assert_true(has_text(control_commands, "Controls"))
  assert_true(has_text(control_commands, "Preview Control Baseline"))
  assert_true(
    has_text(
      control_commands, "Workflow | status | public surface | evidence | preview gap",
    ),
  )
  assert_true(
    has_text(
      control_commands, "Forms | ready | form_workflow_bar + inputs | Showcase + Settings | app validation",
    ),
  )
  assert_true(
    has_text(
      control_commands, "Navigation | ready | sidebar/tabs/route_header + RouteFocusStore | Showcase | app routes",
    ),
  )
  assert_true(
    has_text(
      control_commands, "Dialogs/Menus | ready | view dialog/popover + host menu preview | Command Palette | native modal/a11y follow-up",
    ),
  )
  assert_true(
    has_text(
      control_commands, "Input/A11y | ready | focus_key/FocusScope/semantics | Interaction Lab | native adapters tracked",
    ),
  )
  assert_true(has_text(control_commands, "Native WGPU"))
  assert_true(has_text(control_commands, "2026-5-21"))
  let form_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("controls"))
    .update(@app.ShowcaseMsg::TabSelected("form"))
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_true(has_text(form_commands, "Toggle switch"))
  assert_true(has_text(form_commands, "Filter chip"))
  assert_true(has_text(form_commands, "Choice chip"))
  assert_true(has_text(form_commands, "Tag"))
  assert_true(has_text(form_commands, "Native"))
  assert_true(has_text(form_commands, "Web"))
  assert_true(has_text(form_commands, "Test"))
  let forms_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("forms"))
    .runtime(width=840.0, height=520.0)
    .draw_commands()
  assert_true(has_text(forms_commands, "Forms"))
  assert_true(has_text(forms_commands, "Profile"))
  assert_true(has_text(forms_commands, "Email is required"))
  assert_true(has_text(forms_commands, "Workspace slug"))
  assert_true(has_text(forms_commands, "Checking availability. Validating..."))
  assert_true(has_text(forms_commands, "Review required"))
  assert_true(has_text(forms_commands, "First invalid: email"))
  assert_true(
    has_text(
      forms_commands, "display_name: Display name must be at least 2 characters",
    ),
  )
  assert_true(has_text(forms_commands, "Focus first"))
  assert_true(has_text(forms_commands, "Submit disabled until Email is valid"))
  assert_true(has_text(forms_commands, "Save profile"))
  assert_true(has_text(forms_commands, "Cancel"))
  assert_true(has_text(forms_commands, "Standalone error message"))
  assert_true(has_text(forms_commands, "Enhanced Inputs"))
  assert_true(has_text(forms_commands, "Clear"))
  assert_true(has_text(forms_commands, "USD"))
  assert_true(has_text(forms_commands, "Show"))
  assert_true(has_text(forms_commands, "Stepper"))
  assert_true(has_text(forms_commands, "First line of notes"))
  let data_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("data"))
    .runtime(width=960.0, height=620.0)
    .draw_commands()
  assert_true(has_text(data_commands, "Data"))
  assert_true(has_text(data_commands, "Data Table"))
  assert_true(
    has_text(
      data_commands, "Data helpers: sort=status desc, page 2/4, selected 2",
    ),
  )
  assert_true(has_text(data_commands, "3 results"))
  assert_true(has_text(data_commands, "Clear"))
  assert_true(has_text(data_commands, "Project Atlas"))
  assert_true(has_text(data_commands, "Status v"))
  assert_true(has_text(data_commands, "Column visibility"))
  assert_true(has_text(data_commands, "2 of 3 columns visible"))
  assert_true(has_text(data_commands, "Hidden"))
  assert_true(has_text(data_commands, "2 of 3 selected"))
  assert_true(has_text(data_commands, "Archive"))
  assert_true(has_text(data_commands, "Export"))
  assert_true(has_text(data_commands, "Page 2 of 4"))
  assert_true(has_text(data_commands, "Selected row"))
  assert_true(has_text(data_commands, "Compact detail panel"))
  assert_true(has_text(data_commands, "Selectable List"))
  assert_true(has_text(data_commands, "Healthy pipeline"))
  assert_true(has_text(data_commands, "Review required"))
  assert_true(has_text(data_commands, "Archive Import"))
  assert_true(has_text(data_commands, "Disabled source"))
  assert_true(has_text(data_commands, "Tree View"))
  assert_true(has_text(data_commands, "Workspace"))
  assert_true(has_text(data_commands, "Mira Chen"))
  assert_true(has_text(data_commands, "+1"))
  let layout_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("layout"))
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_true(has_text(layout_commands, "Layout"))
  assert_true(has_text(layout_commands, "Aspect ratio"))
  assert_true(has_text(layout_commands, "Layout helpers"))
  assert_true(has_text(layout_commands, "Virtual lists"))
  assert_true(has_text(layout_commands, "Responsive"))
  assert_true(has_text(layout_commands, "Baseline label"))
  assert_true(has_text(layout_commands, "Intrinsic width"))
  assert_true(has_text(layout_commands, "Custom children layout"))
  assert_true(has_text(layout_commands, "Resizable Panel"))
}

///|
test "showcase layout demos avoid overlapping labels" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("layout"))
    .runtime(width=1400.0, height=760.0)
  let commands = runtime.draw_commands()
  guard text_frame(commands, "Base: Padding") is Some(padding) else {
    fail("expected padding base demo label")
  }
  guard text_frame(commands, "Custom children layout") is Some(custom) else {
    fail("expected custom children demo label")
  }
  guard text_frame(commands, "Keyboard shortcut") is Some(shortcut) else {
    fail("expected lazy grid shortcut label")
  }
  guard text_frame(commands, "State holders") is Some(state_holders) else {
    fail("expected lazy grid state holder label")
  }
  assert_false(rects_overlap(padding, custom))
  assert_true(shortcut.size.width >= 128.0)
  guard text_frame(commands, "Aspect ratio") is Some(aspect) else {
    fail("expected aspect ratio label")
  }
  guard text_frame(commands, "Intrinsic height") is Some(intrinsic_height) else {
    fail("expected intrinsic height label")
  }
  inspect((intrinsic_height.origin.y - aspect.origin.y).to_int(), content="48")
  assert_true(state_holders.origin.y - intrinsic_height.origin.y < 120.0)
  assert_true(padding.origin.y - shortcut.origin.y < 120.0)
  assert_true(layout_tile_marker_count(commands) >= 8)
}

///|
test "showcase embeds reusable example apps and renderer report" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .runtime(width=760.0, height=420.0)
  let example_commands = runtime.draw_commands()
  assert_true(has_text(example_commands, "Examples"))
  assert_true(has_text(example_commands, "Counter Preview"))
  assert_true(has_text(example_commands, "MoUI Counter"))
  assert_true(has_text(example_commands, "Todo Preview"))
  assert_true(has_text(example_commands, "MoUI Todo"))
  assert_false(has_text(example_commands, "Markdown Preview"))
  let markdown_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("text-media"))
    .update(
      @app.ShowcaseMsg::DraftChanged("# Local Markdown\n\nA **bold** word"),
    )
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_true(has_text(markdown_commands, "Text & Media"))
  assert_true(has_text(markdown_commands, "Local Markdown"))
  let renderer_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("runtime-renderer"))
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_true(has_text(renderer_commands, "Runtime & Renderer"))
  assert_true(has_text(renderer_commands, "Host capability"))
  assert_true(has_text(renderer_commands, "Showcase test host / Test"))
  assert_true(has_text(renderer_commands, "Renderer capability"))
}

///|
test "showcase navigates to system gallery sections" {
  let diagnostics_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("diagnostics"))
    .runtime(width=960.0, height=620.0)
    .draw_commands()
  assert_true(has_text(diagnostics_commands, "Diagnostics"))
  assert_true(has_text(diagnostics_commands, "Inspector Snapshot"))
  assert_true(has_text(diagnostics_commands, "View nodes"))
  assert_true(has_text(diagnostics_commands, "Layout bounds"))
  assert_true(has_text(diagnostics_commands, "Semantics nodes"))
  assert_true(has_text(diagnostics_commands, "Render commands"))
  assert_true(has_text(diagnostics_commands, "Program messages"))
  assert_true(has_text(diagnostics_commands, "Effect runs"))
  assert_true(has_text(diagnostics_commands, "Subscription plans"))
  assert_true(has_text(diagnostics_commands, "Active subscriptions"))
  assert_true(
    has_text(diagnostics_commands, "Dirty: redraw requested; elements 0"),
  )
  assert_true(
    has_text_containing(
      diagnostics_commands, "Render scopes: max clip/layer/filter",
    ),
  )
  assert_true(
    has_text(
      diagnostics_commands, "TEA subscriptions: messages 1; effect runs 1; subscription plans 2; active 2; kinds animation 1, host-event 1",
    ),
  )
  assert_true(
    has_text(
      diagnostics_commands, "TEA tasks: active 1; completed 0; cancelled 0",
    ),
  )
  assert_true(
    has_text(
      diagnostics_commands, "TEA descriptors: effect Inspector boot; subscription Inspector tick",
    ),
  )
  assert_true(
    has_text(
      diagnostics_commands, "TEA duplicate keys: effects none; subscriptions diagnostics:tick",
    ),
  )
  assert_true(has_text_containing(diagnostics_commands, "unbalanced pops 0"))
  assert_true(has_text(diagnostics_commands, "Interaction Lab"))
  assert_true(has_text(diagnostics_commands, "Text Diagnostics"))
  assert_true(has_text(diagnostics_commands, "Advanced Rendering"))
  assert_true(has_text(diagnostics_commands, "Examples"))
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("advanced-rendering"))
    .runtime(width=960.0, height=620.0)
  let advanced_commands = runtime.draw_commands()
  assert_true(has_text(advanced_commands, "Advanced Rendering"))
  assert_true(has_text(advanced_commands, "Layer + Blend"))
  assert_true(has_text(advanced_commands, "Filter"))
  assert_true(has_text(advanced_commands, "Shader"))
  assert_true(has_text(advanced_commands, "Path + Transform"))
  assert_true(has_text(advanced_commands, "Transform Pixel"))
  assert_true(
    advanced_commands.any(command => {
      command
      is @core.DrawCommand::FillRoundedRectBrush(
        _,
        @core.Brush::RadialGradient(_)
      )
    }),
  )
  let text_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("text-diagnostics"))
    .runtime(width=960.0, height=620.0)
    .draw_commands()
  assert_true(has_text(text_commands, "Text Diagnostics"))
  assert_true(has_text(text_commands, "CJK"))
  assert_true(has_text(text_commands, "RTL / Bidi"))
  assert_true(has_text(text_commands, "Emoji"))
  assert_true(has_text(text_commands, "Wrapping"))
  let interaction_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("interaction-lab"))
    .runtime(width=960.0, height=620.0)
    .draw_commands()
  assert_true(has_text(interaction_commands, "Interaction Lab"))
  assert_true(has_text(interaction_commands, "Tooltip"))
  assert_true(has_text(interaction_commands, "File Drop"))
  assert_true(has_text(interaction_commands, "Focus + Shortcut"))
  assert_true(has_text(interaction_commands, "Focusable action"))
  assert_true(has_text(interaction_commands, "Meta+k"))
  assert_true(has_text(interaction_commands, "Name field"))
  assert_true(has_text(interaction_commands, "Email field"))
  assert_true(has_text(interaction_commands, "Focus ring: name"))
  assert_true(
    has_text(interaction_commands, "Semantic states: pressed selected disabled"),
  )
  assert_true(has_text(interaction_commands, "Focus order: name -> email"))
  assert_true(has_text(interaction_commands, "Runtime trap: active"))
  assert_true(has_text(interaction_commands, "Tab next: email"))
  assert_true(has_text(interaction_commands, "First invalid: email"))
  assert_true(has_text(interaction_commands, "Enter target: save"))
  assert_true(has_text(interaction_commands, "Escape target: cancel"))
  assert_true(has_text(interaction_commands, "Popover + Dropdown"))
  assert_true(
    has_text(
      interaction_commands, "Expanded semantics: selected + disabled options",
    ),
  )
  assert_true(has_text(interaction_commands, "Renderer: Native"))
  assert_true(has_text(interaction_commands, "Inline popover"))
  assert_true(has_text(interaction_commands, "Popover content"))
  assert_true(has_text(interaction_commands, "Variants"))
  assert_true(has_text(interaction_commands, "Image Lifecycle"))
  let feedback_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("feedback"))
    .runtime(width=980.0, height=720.0)
    .draw_commands()
  assert_true(has_text(feedback_commands, "Feedback"))
  assert_true(has_text(feedback_commands, "Saved settings"))
  assert_true(
    has_text(
      feedback_commands, "ToastQueue helper: 2 active items; app timers own ttl",
    ),
  )
  assert_true(has_text(feedback_commands, "Workspace saved"))
  assert_true(has_text(feedback_commands, "Sync queued for retry"))
  assert_true(has_text(feedback_commands, "Dismiss"))
  assert_true(has_text(feedback_commands, "Connection interrupted"))
  assert_true(
    has_text(
      feedback_commands, "Email is already used by another workspace member.",
    ),
  )
  assert_true(has_text(feedback_commands, "Exporting report"))
  assert_true(
    has_text(feedback_commands, "Preparing CSV rows from the current filter."),
  )
  assert_true(has_text(feedback_commands, "Running"))
  assert_true(has_text(feedback_commands, "No files"))
  assert_true(has_text(feedback_commands, "Loading preview"))
  assert_true(has_text(feedback_commands, "Import failed"))
  assert_true(has_text(feedback_commands, "Status Badge"))
  assert_true(has_text(feedback_commands, "Beta"))
  assert_true(has_text(feedback_commands, "Ready"))
  assert_true(has_text(feedback_commands, "Queued"))
  assert_true(has_text(feedback_commands, "Failed"))
  assert_true(has_text(feedback_commands, "Disclosure Details"))
  assert_true(has_text(feedback_commands, "Inline Disclosure"))
  assert_true(has_text(feedback_commands, "Collapsible Panel"))
  let navigation_commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
    .runtime(width=980.0, height=720.0)
    .draw_commands()
  assert_true(has_text(navigation_commands, "Save Showcase"))
  assert_true(has_text(navigation_commands, "Meta+s"))
  assert_true(
    has_text(navigation_commands, "File - Persist local showcase state."),
  )
  assert_true(has_text(navigation_commands, "Close Overlay"))
  assert_true(
    has_text(
      navigation_commands, "Route focus restore: section-nav-button-navigation",
    ),
  )
  assert_true(
    has_text(
      navigation_commands, "Restore call: runtime.focus_key(\"section-nav-button-navigation\")",
    ),
  )
}

///|
test "showcase advanced rendering emits low level draw commands" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("advanced-rendering"))
    .runtime(width=960.0, height=620.0)
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushLayer(_)),
  )
  assert_true(commands.any(command => command is @core.DrawCommand::PopLayer))
  assert_true(has_layer_blend(commands, @core.BlendMode::Multiply))
  assert_true(has_layer_blend(commands, @core.BlendMode::Screen))
  assert_true(has_layer_blend(commands, @core.BlendMode::Overlay))
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushFilter(_)),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(_))
    }),
  )
  assert_true(commands.any(command => command is @core.DrawCommand::PopFilter))
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawShaderEffect(_)),
  )
  assert_true(has_shader_effect(commands, "checker"))
  assert_true(has_shader_effect(commands, "vignette"))
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawPath(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushOpacity(_)),
  )
  assert_true(commands.any(command => command is @core.DrawCommand::PopOpacity))
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushTransform(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PopTransform),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushClip(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawImage(_)),
  )
  assert_true(has_text(commands, "PX"))
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::PushFilter(@core.FilterEffect::Saturate(_))
    }),
  )
  assert_false(
    commands.any(command => {
      command
      is @core.DrawCommand::PushLayer({ mask: @core.LayerMask::NoMask, .. })
    }),
  )
}

///|
fn has_layer_blend(
  commands : Array[@core.DrawCommand],
  blend : @core.BlendMode,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::PushLayer({ blend_mode, .. }) &&
    blend_mode == blend
  })
}

///|
fn has_shader_effect(
  commands : Array[@core.DrawCommand],
  name : String,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawShaderEffect({ name: value, .. }) &&
    value == name
  })
}

///|
test "showcase text diagnostics keeps key labels and frame clip sample bounded" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("text-diagnostics"))
    .runtime(width=960.0, height=620.0)
  let commands = runtime.draw_commands()
  let size = @core.Size::new(width=960.0, height=620.0)
  assert_true(text_within(commands, "Text Diagnostics", size))
  assert_true(text_within(commands, "CJK", size))
  assert_true(text_within(commands, "RTL / Bidi", size))
  assert_true(has_text(commands, "Emoji"))
  assert_true(has_text_containing(commands, "native partial"))
  assert_true(has_text_containing(commands, "web partial"))
  assert_true(has_text_containing(commands, "中文混排"))
  assert_true(has_text_containing(commands, "שלום עולם"))
  assert_true(has_text(commands, "Wrapping"))
  assert_true(has_text(commands, "Text Frame Clip"))
  guard text_frame(
      commands, "Sphinx of black quartz, judge my vexing MoUI layout preview.",
    )
    is Some(frame) else {
    fail("expected bounded TextRun sample frame")
  }
  assert_true(frame.size.width <= 88.0)
  assert_true(frame.size.height <= 28.0)
  assert_true(frame.origin.x + frame.size.width <= size.width)
  assert_true(frame.origin.y + frame.size.height <= size.height)
}

///|
test "showcase interaction lab exposes tooltip variants and file drop wiring" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("interaction-lab"))
    .runtime(width=960.0, height=620.0)
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Tooltip: Meta+K"))
  assert_true(has_text(commands, "No files dropped"))
  assert_true(has_text(commands, "Primary"))
  assert_true(has_text(commands, "Tonal"))
  assert_true(has_text(commands, "Outline"))
  assert_true(has_text(commands, "Ready"))
  assert_true(has_text(commands, "Loading"))
  assert_true(has_text(commands, "Failed"))
  guard text_frame(commands, "Drop files here") is Some(drop_frame) else {
    fail("expected file drop zone text")
  }
  runtime.dispatch_event(
    @core.AppEvent::DragDrop(
      @core.DragDropEvent::new(
        phase=@core.DragDropPhase::Dropped,
        paths=["/tmp/showcase.txt"],
        position=Some(
          @core.Point::new(
            x=drop_frame.origin.x + 4.0,
            y=drop_frame.origin.y + 4.0,
          ),
        ),
      ),
    ),
  )
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  assert_true(has_text(runtime.draw_commands(), "Dropped 1 file(s)"))
}

///|
test "showcase keeps header and overview content bounded across viewport sizes" {
  for
    size in [
      @core.Size::new(width=760.0, height=420.0),
      @core.Size::new(width=960.0, height=560.0),
      @core.Size::new(width=1400.0, height=760.0),
    ] {
    let runtime = @app.ShowcaseModel::new().runtime(
      width=size.width,
      height=size.height,
    )
    let commands = runtime.draw_commands()
    assert_true(text_within(commands, "Dialog", size))
    assert_true(text_within(commands, "Renderer capability", size))
    assert_true(text_within(commands, "Keyboard: Meta+K", size))
    assert_true(text_within(commands, "Layered card with image", size))
    assert_false(has_text(commands, "馃攳"))
    assert_false(has_text(commands, "?"))
    for route in ["advanced-rendering", "text-diagnostics", "diagnostics"] {
      let section_commands = @app.ShowcaseModel::new()
        .update(@app.ShowcaseMsg::SelectSection(route))
        .runtime(width=size.width, height=size.height)
        .draw_commands()
      match route {
        "advanced-rendering" =>
          assert_true(text_within(section_commands, "Advanced Rendering", size))
        "text-diagnostics" =>
          assert_true(text_within(section_commands, "Text Diagnostics", size))
        _ => assert_true(text_within(section_commands, "Diagnostics", size))
      }
    }
  }
}

///|
test "showcase sidebar follows recommended catalog order" {
  let commands = @app.ShowcaseModel::new()
    .runtime(width=1400.0, height=760.0)
    .draw_commands()
  let labels = [
    "Overview", "Text & Media", "Controls", "Forms", "Data", "Layout", "Navigation Shell",
    "Feedback", "Runtime/Renderer", "Diagnostics",
  ]
  let mut previous_y = -1.0
  for label in labels {
    guard text_frame(commands, label) is Some(frame) else {
      fail("expected sidebar label " + label)
    }
    assert_true(frame.origin.y > previous_y)
    previous_y = frame.origin.y
  }
  assert_false(has_text(commands, "Interaction Lab"))
  assert_false(has_text(commands, "Advanced Rendering"))
}

///|
test "showcase renderer section clips long capability content" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("runtime-renderer"))
    .runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  assert_true(
    text_within(
      commands,
      "Runtime & Renderer",
      @core.Size::new(width=760.0, height=420.0),
    ),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushClip(_)),
  )
  assert_true(has_text(commands, "Host capability"))
  assert_true(has_text(commands, "gradient"))
  assert_true(has_text(commands, "transform"))
  assert_true(has_text(commands, "text-shaping"))
  assert_true(has_text(commands, "emoji-text"))
  assert_false(has_text(commands, "async-image"))
  assert_true(has_text(commands, "wgpu partial"))
  assert_true(has_text(commands, "skia partial"))
  assert_false(has_text(commands, "native gap"))
  assert_true(has_text(commands, "webgpu partial"))
}

///|
test "showcase host capability card surfaces web ime readiness" {
  let summary = @host.HostCapabilitySummary::new(
    backend=@host.HostBackendKind::Web,
    label="Web host",
    input=@host.HostInputCapabilities::new(
      pointer=false,
      scroll=false,
      keyboard=false,
      focus=false,
      text_input=true,
      ime=true,
      clipboard=false,
      drag_drop=false,
    ),
    text_input_ready=true,
    ime_ready=true,
  )
  let runtime = @app.ShowcaseModel::new()
    .with_host_summary(summary)
    .update(@app.ShowcaseMsg::SelectSection("runtime-renderer"))
    .runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Web host / Web"))
  assert_true(has_text(commands, "2/7"))
  assert_true(has_text(commands, "text input, IME"))
}

///|
test "showcase counter preview increments through shared runtime" {
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .update(@app.ShowcaseMsg::CounterIncrement)
  let runtime = model.runtime(width=760.0, height=420.0)
  inspect(model.counter_count, content="1")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Count: 1"))
}

///|
test "showcase todo model updates add toggle and remove" {
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::TodoDraftChanged("Write tests"))
    .update(@app.ShowcaseMsg::TodoSubmitDraft)
  inspect(model.todo_count(), content="3")
  let toggled = model.update(@app.ShowcaseMsg::TodoToggled(2, true))
  guard toggled.todo_items is [_, _, { id: 2, completed: true, .. }] else {
    fail("expected added item toggled")
  }
  inspect(
    toggled.update(@app.ShowcaseMsg::TodoRemove(2)).todo_count(),
    content="2",
  )
}

///|
test "showcase todo preview keeps keyed rows after toggle" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .runtime(width=960.0, height=760.0)
  let before = runtime.draw_commands()
  assert_true(has_text(before, "Reuse Todo state"))
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .update(@app.ShowcaseMsg::TodoToggled(0, true))
  let after = model.runtime(width=960.0, height=760.0).draw_commands()
  assert_true(has_text(after, "Reuse Todo state"))
  guard model.todo_items is [{ completed: true, .. }, ..] else {
    fail("expected first built-in todo item toggled")
  }
}

///|
test "showcase todo preview accepts draft submission" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .runtime(width=760.0, height=420.0)
  assert_true(has_text(runtime.draw_commands(), "New todo"))
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("examples"))
    .update(@app.ShowcaseMsg::TodoDraftChanged("ab"))
    .update(@app.ShowcaseMsg::TodoSubmitDraft)
  let submitted_runtime = model.runtime(width=760.0, height=420.0)
  guard model.todo_items is [_, _, { id: 2, text: "ab", completed: false }] else {
    fail("expected draft text submitted as next todo item")
  }
  inspect(model.todo_draft, content="")
  assert_true(has_text(submitted_runtime.draw_commands(), "ab"))
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_text_containing(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) &&
    value.contains(text)
  })
}

///|
fn has_image_fit(
  commands : Array[@core.DrawCommand],
  fit : @core.ImageFit,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawImage({ fit: image_fit, .. }) &&
    image_fit == fit
  })
}

///|
fn text_within(
  commands : Array[@core.DrawCommand],
  text : String,
  size : @core.Size,
) -> Bool {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text &&
          frame.origin.x >= 0.0 &&
          frame.origin.y >= 0.0 &&
          frame.origin.x + frame.size.width <= size.width &&
          frame.origin.y + frame.size.height <= size.height {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn click_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  click_frame(runtime, frame)
}

///|
fn click_last_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard last_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  click_frame(runtime, frame)
}

///|
fn click_frame(runtime : @core.AppRuntime, frame : @core.Rect) -> Unit {
  let position = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  click_point(runtime, position)
}

///|
fn click_point(runtime : @core.AppRuntime, position : @core.Point) -> Unit {
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn last_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  let mut frame : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame: next, .. }) =>
        if value == text {
          frame = Some(next)
        }
      _ => ()
    }
  }
  frame
}

///|
fn smallest_rounded_brush_containing(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
) -> @core.Rect? {
  let mut candidate : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect_contains_rect(rect, frame) {
          candidate = match candidate {
            Some(existing) =>
              if rect_area(rect) < rect_area(existing) {
                Some(rect)
              } else {
                Some(existing)
              }
            None => Some(rect)
          }
        }
      _ => ()
    }
  }
  candidate
}

///|
fn rect_contains_rect(container : @core.Rect, child : @core.Rect) -> Bool {
  child.origin.x >= container.origin.x &&
  child.origin.y >= container.origin.y &&
  child.origin.x + child.size.width <= container.origin.x + container.size.width &&
  child.origin.y + child.size.height <=
  container.origin.y + container.size.height
}

///|
fn rect_area(rect : @core.Rect) -> Double {
  rect.size.width * rect.size.height
}

///|
fn rects_overlap(a : @core.Rect, b : @core.Rect) -> Bool {
  let a_right = a.origin.x + a.size.width
  let b_right = b.origin.x + b.size.width
  let a_bottom = a.origin.y + a.size.height
  let b_bottom = b.origin.y + b.size.height
  a.origin.x < b_right &&
  a_right > b.origin.x &&
  a.origin.y < b_bottom &&
  a_bottom > b.origin.y
}

///|
fn layout_tile_marker_count(commands : Array[@core.DrawCommand]) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRect({ rect, radius }, _) =>
        if rect.size.width == 4.0 && rect.size.height == 22.0 && radius == 2.0 {
          count = count + 1
        }
      _ => ()
    }
  }
  count
}

///|
fn has_sidebar_scrollbar(commands : Array[@core.DrawCommand]) -> Bool {
  sidebar_scrollbar_frame(commands) is Some(_)
}

///|
fn sidebar_scrollbar_frame(commands : Array[@core.DrawCommand]) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.size.width == 4.0 && rect.size.height >= 32.0 {
          return Some(rect)
        }
      _ => ()
    }
  }
  None
}

///|
