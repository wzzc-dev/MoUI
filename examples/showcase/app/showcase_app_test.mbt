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
  assert_true(model.scheme == @core.ColorScheme::Dark)
  assert_true(model.active)
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
  assert_true(has_text(control_commands, "Native Skia"))
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
  let data_runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("data"))
    .runtime(width=960.0, height=620.0)
  assert_false(
    has_text(data_runtime.draw_commands(), "State-driven visuals are active"),
  )
  click_text(data_runtime, "Active")
  let active_commands = data_runtime.draw_commands()
  assert_false(has_text(active_commands, "State-driven visuals are active"))
  assert_true(has_text(active_commands, "4 results"))
  click_text(data_runtime, "Review")
  let review_commands = data_runtime.draw_commands()
  assert_false(has_text(review_commands, "State-driven visuals are active"))
  assert_true(has_text(review_commands, "2 results"))
  click_text(data_runtime, "Clear")
  let cleared_commands = data_runtime.draw_commands()
  assert_false(has_text(cleared_commands, "State-driven visuals are active"))
  assert_true(has_text(cleared_commands, "10 results"))
  let table_runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("data"))
    .runtime(width=960.0, height=620.0)
  click_text(table_runtime, "Status v")
  let after_header_click = table_runtime.draw_commands()
  assert_false(has_text(after_header_click, "State-driven visuals are active"))
  assert_true(has_text(after_header_click, "3 results"))
  click_text(table_runtime, "Billing Flow")
  let after_row_click = table_runtime.draw_commands()
  assert_false(has_text(after_row_click, "State-driven visuals are active"))
  assert_true(has_text(after_row_click, "3 results"))
  let host_runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("data"))
    .runtime(width=960.0, height=620.0)
  let scheduled = Ref(0)
  let driver = @host.HostRuntimeDriver::new(runtime=host_runtime, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  guard text_frame(driver.draw_commands(), "Active") is Some(active_frame) else {
    fail("expected Active frame")
  }
  let active_scheduled = scheduled.val
  host_click_frame(driver, active_frame)
  let after_active_click = driver.event_result()
  assert_true(after_active_click.redraw_requested)
  assert_true(scheduled.val > active_scheduled)
  driver.begin_redraw()
  let active_host_commands = driver.draw_commands()
  assert_true(has_text(active_host_commands, "4 results"))
  driver.finish_redraw()
  let after_active_redraw = driver.event_result()
  assert_false(after_active_redraw.needs_redraw)
  assert_false(after_active_redraw.redraw_requested)
  guard text_frame(driver.draw_commands(), "Review") is Some(review_frame) else {
    fail("expected Review frame")
  }
  let review_scheduled = scheduled.val
  host_click_frame(driver, review_frame)
  let after_review_click = driver.event_result()
  assert_true(after_review_click.redraw_requested)
  assert_true(scheduled.val > review_scheduled)
  driver.begin_redraw()
  let review_host_commands = driver.draw_commands()
  assert_true(has_text(review_host_commands, "2 results"))
  driver.finish_redraw()
  let after_review_redraw = driver.event_result()
  assert_false(after_review_redraw.needs_redraw)
  assert_false(after_review_redraw.redraw_requested)
  guard text_frame(driver.draw_commands(), "Clear") is Some(clear_frame) else {
    fail("expected Clear frame")
  }
  let clear_scheduled = scheduled.val
  host_click_frame(driver, clear_frame)
  let after_clear_click = driver.event_result()
  assert_true(after_clear_click.redraw_requested)
  assert_true(scheduled.val > clear_scheduled)
  driver.begin_redraw()
  let clear_host_commands = driver.draw_commands()
  assert_true(has_text(clear_host_commands, "10 results"))
  driver.finish_redraw()
  let after_clear_redraw = driver.event_result()
  assert_false(after_clear_redraw.needs_redraw)
  assert_false(after_clear_redraw.redraw_requested)
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
fn host_click_frame(
  driver : @host.HostRuntimeDriver,
  frame : @core.Rect,
) -> Unit {
  let position = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  ignore(
    driver.dispatch(
      @host.HostEvent::Pointer(
        @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      @host.HostEvent::Pointer(
        @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
      ),
    ),
  )
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
