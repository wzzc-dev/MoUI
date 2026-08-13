///|
test "windows menu command payload records utf8 byte lengths" {
  let encoded = @utf8.decode_lossy(
    @host_services_desktop.encode_menu_commands([
      @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Paste,
        label="粘贴",
        enabled=false,
      ),
    ])[:],
    ignore_bom=false,
  )
  inspect(encoded, content="1:4:Copy\n0:6:粘贴")
}

///|
test "windows host decodes pointer movement and clicks in logical coordinates" {
  let scale_factor = 1.5
  let physical_position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
    150.0, 120.0,
  )
  let logical_position = @core.Point::new(x=100.0, y=80.0)
  let moved = windows_window_event_to_host(
    @window_core.WindowEvent::PointerMoved(
      None,
      physical_position,
      true,
      @window_core.PointerSource::Mouse,
    ),
    logical_position,
    @core.KeyModifiers::none(),
    scale_factor~,
  )
  match moved {
    Some(
      @host.Event::Pointer({ position, phase: @core.PointerPhase::Move, .. })
    ) => assert_true(position == logical_position)
    _ => fail("expected logical Windows pointer move")
  }
  let pressed = windows_window_event_to_host(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      physical_position,
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    logical_position,
    @core.KeyModifiers::none(),
    scale_factor~,
  )
  match pressed {
    Some(
      @host.Event::Pointer({ position, phase: @core.PointerPhase::Down, .. })
    ) => assert_true(position == logical_position)
    _ => fail("expected logical Windows pointer down")
  }
}

///|
test "windows host options carry optional scene resolver and smoke options stay separate" {
  let request = @host.WindowOpenRequest::new(
    title="Inspector",
    scene=@host.WindowScene::new(scene_id="inspector"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match WindowsHostAppOptions::new().scene_resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Windows scene resolver rejection")
  }
  assert_false(WindowsHostSmokeOptions::new().first_frame_smoke_auto_exit)
  let resolver = @runtime.WindowSceneResolver::new(resolve=request => {
    @runtime.WindowSceneResolution::SceneResolved(
      @runtime.WindowSceneInstance::new(
        request~,
        runtime=@runtime.AppRuntime::new_view(
          root=(@views.empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let options = WindowsHostAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@runtime.HostPlatformEventSources::new()),
  )
  let smoke_options = WindowsHostSmokeOptions::new(
    first_frame_smoke_auto_exit=true,
  )
  assert_true(smoke_options.first_frame_smoke_auto_exit)
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured Windows platform event sources")
  }
  match options.scene_resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Windows scene resolver")
  }
}

///|
test "windows UIA actions preserve node generation and typed payload" {
  let numeric = windows_decode_accessibility_action(
    b"{\"node_id\":\"42\",\"generation\":\"7\",\"kind\":\"set_numeric_value\",\"value\":\"37.5\"}",
  )
  guard numeric
    is Some(
      {
        target: @core.SemanticsTarget::ByNodeId(node_id),
        action: @core.SemanticsAction::SetNumericValue(value),
        precondition: @runtime.SemanticsGenerationPrecondition::Exact(
          generation
        ),
      }
    ) else {
    fail("expected decoded UIA numeric action")
  }
  inspect(node_id.to_wire(), content="42")
  inspect(generation.to_wire(), content="7")
  inspect(value, content="37.5")

  let selection = windows_decode_accessibility_action(
    b"{\"node_id\":\"43\",\"generation\":\"8\",\"kind\":\"set_selection\",\"value\":\"3,9\"}",
  )
  guard selection
    is Some({ action: @core.SemanticsAction::SetSelection(range), .. }) else {
    fail("expected decoded UIA selection action")
  }
  inspect(range.start, content="3")
  inspect(range.end, content="9")
}

///|
test "windows UIA action decoder rejects malformed requests" {
  assert_eq(windows_decode_accessibility_action(b""), None)
  assert_eq(
    windows_decode_accessibility_action(
      b"{\"node_id\":\"x\",\"generation\":\"7\",\"kind\":\"activate\",\"value\":\"\"}",
    ),
    None,
  )
  assert_eq(
    windows_decode_accessibility_action(
      b"{\"node_id\":\"42\",\"generation\":\"7\",\"kind\":\"unknown\",\"value\":\"\"}",
    ),
    None,
  )
}
