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
    .update(@app.ShowcaseMsg::SelectSection("theme-renderer"))
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
  let model = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::ShowDialog)
    .update(@app.ShowcaseMsg::ShowSheet)
    .update(@app.ShowcaseMsg::SelectSection("navigation"))
  let runtime = model.runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Showcase dialog"))
  assert_true(has_text(commands, "Showcase sheet"))
  assert_true(model.dialog_visible)
  assert_true(model.sheet_visible)
  assert_true(model.selected_section == "navigation")
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
  assert_true(has_text(commands, "Master Detail"))
  assert_true(has_text(commands, "Wizard Step: Profile"))
  assert_true(has_text(commands, "Permissions"))
  assert_true(has_text(commands, "Review"))
  assert_true(has_text(commands, "New"))
  assert_true(has_text(commands, "Archive"))
  assert_true(has_text(commands, "Renderer neutral"))
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
fn sidebar_visible_lower_label(
  commands : Array[@core.DrawCommand],
  size : @core.Size,
) -> String {
  for label in ["Interaction Lab", "Text Diagnostics", "Advanced Rendering"] {
    if text_within(commands, label, size) {
      return label
    }
  }
  "Interaction Lab"
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
  assert_true(has_text(data_commands, "Project Atlas"))
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
    .update(@app.ShowcaseMsg::SelectSection("theme-renderer"))
    .runtime(width=760.0, height=420.0)
    .draw_commands()
  assert_true(has_text(renderer_commands, "Theme & Renderer"))
  assert_true(has_text(renderer_commands, "Renderer capability"))
}

///|
test "showcase navigates to system gallery sections" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("advanced-rendering"))
    .runtime(width=960.0, height=620.0)
  let advanced_commands = runtime.draw_commands()
  assert_true(has_text(advanced_commands, "Advanced Rendering"))
  assert_true(has_text(advanced_commands, "Layer + Blend"))
  assert_true(has_text(advanced_commands, "Filter"))
  assert_true(has_text(advanced_commands, "Shader"))
  assert_true(has_text(advanced_commands, "Path + Transform"))
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
  assert_true(has_text(interaction_commands, "Popover + Dropdown"))
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
  assert_true(has_text(feedback_commands, "Connection interrupted"))
  assert_true(has_text(feedback_commands, "No files"))
  assert_true(has_text(feedback_commands, "Loading preview"))
  assert_true(has_text(feedback_commands, "Import failed"))
  assert_true(has_text(feedback_commands, "Beta"))
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
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushFilter(_)),
  )
  assert_true(commands.any(command => command is @core.DrawCommand::PopFilter))
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawShaderEffect(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawPath(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushClip(_)),
  )
  assert_false(
    commands.any(command => {
      command
      is @core.DrawCommand::PushLayer({ mask: @core.LayerMask::NoMask, .. })
    }),
  )
}

///|
test "showcase text diagnostics keeps key labels bounded" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("text-diagnostics"))
    .runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  let size = @core.Size::new(width=760.0, height=420.0)
  assert_true(text_within(commands, "Text Diagnostics", size))
  assert_true(text_within(commands, "CJK", size))
  assert_true(text_within(commands, "RTL / Bidi", size))
  assert_true(has_text(commands, "Emoji"))
  assert_true(has_text_containing(commands, "native partial"))
  assert_true(has_text_containing(commands, "web partial"))
  assert_true(has_text_containing(commands, "中文混排"))
  assert_true(has_text_containing(commands, "שלום עולם"))
  assert_true(has_text(commands, "Wrapping"))
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
    for route in ["advanced-rendering", "text-diagnostics", "interaction-lab"] {
      let section_commands = @app.ShowcaseModel::new()
        .update(@app.ShowcaseMsg::SelectSection(route))
        .runtime(width=size.width, height=size.height)
        .draw_commands()
      match route {
        "advanced-rendering" =>
          assert_true(text_within(section_commands, "Advanced Rendering", size))
        "text-diagnostics" =>
          assert_true(text_within(section_commands, "Text Diagnostics", size))
        _ => assert_true(text_within(section_commands, "Interaction Lab", size))
      }
    }
  }
}

///|
test "showcase renderer section clips long capability content" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("theme-renderer"))
    .runtime(width=760.0, height=420.0)
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
  assert_true(has_text(commands, "transform"))
  assert_true(has_text(commands, "text-shaping"))
  assert_true(has_text(commands, "emoji-text"))
  assert_true(has_text(commands, "async-image"))
  assert_true(has_text(commands, "wgpu partial"))
  assert_true(has_text(commands, "skia partial"))
  assert_false(has_text(commands, "native gap"))
  assert_false(has_text(commands, "web partial"))
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
