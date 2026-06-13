///|
test "showcase navigation dialog and sheet state are wired" {
  let dialog_model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::ShowDialog)
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
  let dialog_commands = dialog_model
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  let size = @core.Size::new(width=760.0, height=420.0)
  assert_true(has_text(dialog_commands, "Showcase dialog"))
  assert_true(has_text(dialog_commands, "Custom content shell"))
  assert_true(
    has_text(
      dialog_commands, "Dialog hosts custom content, focus, and actions in one modal surface.",
    ),
  )
  assert_true(has_text(dialog_commands, "Host"))
  assert_true(has_text(dialog_commands, "view-level"))
  assert_true(has_text(dialog_commands, "Focus"))
  assert_true(has_text(dialog_commands, "app-owned"))
  assert_true(has_text(dialog_commands, "Actions"))
  assert_true(has_text(dialog_commands, "footer"))
  assert_true(has_text(dialog_commands, "Dismiss"))
  assert_true(has_text(dialog_commands, "Sheet"))
  assert_true(has_text(dialog_commands, "Close"))
  for
    label in [
      "Showcase dialog", "Custom content shell", "Dialog hosts custom content, focus, and actions in one modal surface.",
      "Host", "view-level", "Focus", "app-owned", "Actions", "footer", "Dismiss",
      "Sheet", "Close",
    ] {
    assert_true(text_within(dialog_commands, label, size))
  }
  guard text_frame(dialog_commands, "Showcase dialog") is Some(title_frame) else {
    fail("expected Showcase dialog title")
  }
  guard text_frame(dialog_commands, "footer") is Some(body_frame) else {
    fail("expected Showcase dialog body")
  }
  guard last_text_frame(dialog_commands, "Sheet") is Some(sheet_frame) else {
    fail("expected Showcase dialog secondary action")
  }
  guard text_frame(dialog_commands, "Close") is Some(close_frame) else {
    fail("expected Showcase dialog primary action")
  }
  guard smallest_rounded_brush_containing(dialog_commands, title_frame)
    is Some(dialog_frame) else {
    fail("expected Showcase dialog surface frame")
  }
  assert_true(rect_contains_rect(dialog_frame, body_frame))
  assert_true(rect_contains_rect(dialog_frame, sheet_frame))
  assert_true(rect_contains_rect(dialog_frame, close_frame))
  assert_true(sheet_frame.origin.y > body_frame.origin.y)
  assert_true(close_frame.origin.x > sheet_frame.origin.x)
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
test "showcase native ime evidence points focus sidebar search" {
  let runtime = @app.ShowcaseApp::new().runtime(width=960.0, height=560.0)
  click_point(runtime, @core.Point::new(x=120.0, y=148.0))
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("moui")),
  )
  let input = runtime.focused_text_input()
  assert_true(input.focused)
  inspect(input.text, content="moui")
  assert_true(input.caret_rect.size.height > 0.0)
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::CompositionStart),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(
          text="ni",
          cursor=Some(@core.TextRange::new(start=0, end=2)),
        ),
      ),
    ),
  )
  let composing = runtime.focused_text_input()
  guard composing.composition is Some(composition) else {
    fail("expected sidebar search composition")
  }
  guard composing.composition_cursor is Some(cursor) else {
    fail("expected sidebar search composition cursor")
  }
  inspect(composition, content="ni")
  inspect(cursor.end, content="2")
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::CompositionEnd("你")),
  )
  let committed = runtime.focused_text_input()
  inspect(committed.text, content="moui你")
  assert_true(committed.composition is None)
}

///|
test "showcase detail panel scrolls long section content" {
  let size = @core.Size::new(width=760.0, height=420.0)
  let model = @app.ShowcaseModel::new().update(
    @app.ShowcaseMsg::SelectSection("layout"),
  )
  let runtime = model.runtime(width=760.0, height=420.0)
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
  assert_true(model.detail_scroll.offset().y > 0.0)
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
