///|
test "showcase app emits visual polish commands" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "MoUI View Showcase"))
  assert_true(has_text(commands, "View Catalog"))
  assert_true(has_text(commands, "Overview"))
  assert_true(has_text(commands, "Controls"))
  app.select_section("theme-renderer")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let renderer_commands = runtime.draw_commands()
  assert_true(
    renderer_commands.any(command => command is @core.DrawCommand::DrawShadow(_)),
  )
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
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.toggle_scheme()
  app.toggle_active()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "State-driven visuals are active"))
  assert_true(app.dark.get())
  assert_true(app.active.get())
}

///|
test "showcase navigation dialog and sheet state are wired" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.show_dialog()
  app.show_sheet()
  app.select_section("navigation")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Showcase dialog"))
  assert_true(has_text(commands, "Showcase sheet"))
  assert_true(app.dialog_visible.get())
  assert_true(app.sheet_visible.get())
  assert_true(app.navigation.current() == "navigation")
  assert_true(app.selected_section.get() == "navigation")
}

///|
test "showcase covers text media controls and layout sections" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.select_section("text-media")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let text_commands = runtime.draw_commands()
  assert_true(has_text(text_commands, "Text & Media"))
  assert_true(has_text(text_commands, "Label text"))
  app.select_section("controls")
  app.tab.set("values")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let control_commands = runtime.draw_commands()
  assert_true(has_text(control_commands, "Controls"))
  assert_true(has_text(control_commands, "Native WGPU"))
  assert_true(has_text(control_commands, "2026-5-21"))
  app.tab.set("form")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let form_commands = runtime.draw_commands()
  assert_true(has_text(form_commands, "Toggle switch"))
  app.select_section("layout")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let layout_commands = runtime.draw_commands()
  assert_true(has_text(layout_commands, "Layout"))
  assert_true(has_text(layout_commands, "Aspect ratio"))
  assert_true(has_text(layout_commands, "Intrinsic width"))
  assert_true(has_text(layout_commands, "Custom children layout"))
}

///|
test "showcase embeds reusable example apps and renderer report" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.select_section("examples")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let example_commands = runtime.draw_commands()
  assert_true(has_text(example_commands, "Examples"))
  assert_true(has_text(example_commands, "Counter Preview"))
  assert_true(has_text(example_commands, "MoUI Counter"))
  assert_true(has_text(example_commands, "Todo Preview"))
  assert_true(has_text(example_commands, "MoUI Todo"))
  assert_false(has_text(example_commands, "Markdown Preview"))
  app.select_section("text-media")
  app.draft.set("# Local Markdown\n\nA **bold** word")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let markdown_commands = runtime.draw_commands()
  assert_true(has_text(markdown_commands, "Text & Media"))
  assert_true(has_text(markdown_commands, "Local Markdown"))
  app.select_section("theme-renderer")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let renderer_commands = runtime.draw_commands()
  assert_true(has_text(renderer_commands, "Theme & Renderer"))
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
    let app = @app.ShowcaseApp::new()
    let runtime = app.runtime(width=size.width, height=size.height)
    let commands = runtime.draw_commands()
    assert_true(text_within(commands, "Dialog", size))
    assert_true(text_within(commands, "Renderer capability", size))
    assert_true(text_within(commands, "Keyboard: Meta+K", size))
    assert_false(has_text(commands, "🔍"))
    assert_false(has_text(commands, "?"))
  }
}

///|
test "showcase renderer section clips long capability content" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.select_section("theme-renderer")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(
    text_within(
      commands,
      "Theme & Renderer",
      @core.Size::new(width=760.0, height=420.0),
    ),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushClip(_)),
  )
}

///|
test "showcase counter preview increments through shared runtime" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.select_section("examples")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  app.counter_increment()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  inspect(app.counter_count.get(), content="1")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Count: 1"))
}

///|
test "showcase todo model updates add toggle and remove" {
  let app = @app.ShowcaseApp::new()
  app.todo_add("Write tests")
  inspect(app.todo_count(), content="3")
  app.todo_toggle(2)
  guard app.todo_items() is [_, _, { id: 2, completed: true, .. }] else {
    fail("expected added item toggled")
  }
  app.todo_remove(2)
  inspect(app.todo_count(), content="2")
}

///|
test "showcase todo preview keeps keyed rows after toggle" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=960.0, height=760.0)
  app.select_section("examples")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let before = runtime.draw_commands()
  assert_true(has_text(before, "Reuse Todo state"))
  app.todo_toggle(0)
  runtime.state.needs_rebuild = true
  let after = runtime.draw_commands()
  assert_true(has_text(after, "Reuse Todo state"))
  guard app.todo_items() is [{ completed: true, .. }, ..] else {
    fail("expected first built-in todo item toggled")
  }
}

///|
test "showcase todo preview accepts draft submission" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.select_section("examples")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  assert_true(has_text(runtime.draw_commands(), "New todo"))
  app.todo_set_draft("ab")
  app.todo_submit_draft()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  guard app.todo_items() is [_, _, { id: 2, text: "ab", completed: false }] else {
    fail("expected draft text submitted as next todo item")
  }
  inspect(app.todo_draft.get(), content="")
  assert_true(has_text(runtime.draw_commands(), "ab"))
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
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
