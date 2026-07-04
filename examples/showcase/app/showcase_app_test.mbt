///|
test "showcase app emits visual polish commands" {
  let runtime = @app.ShowcaseModel::new().runtime(width=760.0, height=420.0)
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
  match text_color(commands, "MoUI View Showcase") {
    Some(color) => assert_true(color == @views.dark_theme().palette.foreground)
    None => fail("expected dark-themed showcase title text")
  }
  assert_true(model.scheme == @state.ColorScheme::Dark)
  assert_true(model.active)
}

///|
test "showcase overview text stays legible in dark theme" {
  let commands = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::ToggleScheme)
    .runtime(width=1400.0, height=760.0)
    .draw_commands()
  let theme = @views.dark_theme()
  for
    label in [
      "Overview", "Layered card with image", "Renderer capability", "Keyboard: Meta+K",
      "gradient", "transform", "text-shaping",
    ] {
    assert_true(has_text_color(commands, label, theme.palette.foreground))
  }
  for label in ["webgpu partial", "wgpu partial"] {
    assert_true(has_text_color(commands, label, theme.palette.primary))
  }
  assert_true(has_text_color(commands, "skia supported", theme.palette.muted))
  assert_true(
    has_text_color(
      commands,
      "Showcase is now a data-driven catalog of MoUI views.",
      theme.palette.muted,
    ),
  )
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
  assert_true(has_text(form_commands, "Secondary toggle"))
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
  settle_redraw(driver)
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
  settle_redraw(driver)
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
  settle_redraw(driver)
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
test "showcase keeps header and overview content bounded across viewport sizes" {
  for
    size in [
      @geometry.Size::new(width=760.0, height=420.0),
      @geometry.Size::new(width=960.0, height=560.0),
      @geometry.Size::new(width=1400.0, height=760.0),
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
