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
  assert_true(has_text(advanced_commands, "Renderer Smoke"))
  assert_true(has_text(advanced_commands, "👩‍💻"))
  assert_true(has_text(advanced_commands, "ABC אבג 123"))
  assert_true(has_text(advanced_commands, "Smoke wrap line 1"))
  assert_true(has_text(advanced_commands, "Smoke wrap line 2"))
  assert_true(has_text(advanced_commands, "Smoke wrap line 3"))
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
  let size = @moui.Size::new(width=960.0, height=620.0)
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
          @moui.Point::new(
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
test "showcase renderer section clips long capability content" {
  let runtime = @app.ShowcaseModel::new()
    .update(@app.ShowcaseMsg::SelectSection("runtime-renderer"))
    .runtime(width=760.0, height=420.0)
  let commands = runtime.draw_commands()
  assert_true(
    text_within(
      commands,
      "Runtime & Renderer",
      @moui.Size::new(width=760.0, height=420.0),
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
    text_input_available=true,
    ime_available=true,
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
