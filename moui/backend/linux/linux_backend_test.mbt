///|
test "linux backend reports Wayland renderer readiness with explicit gaps" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.window_backend_available, content="true")
  inspect(info.renderer_ready, content="true")
  inspect(info.capabilities.window, content="true")
  inspect(info.capabilities.renderer, content="true")
  inspect(info.capabilities.titlebar, content="true")
  inspect(info.capabilities.drag_drop, content="false")
  inspect(info.capabilities.accessibility, content="false")
  inspect(info.accessibility.kind.label(), content="at-spi")
  inspect(info.accessibility.contract_ready, content="true")
  inspect(info.accessibility.native_binding_ready, content="false")
  inspect(info.services.clipboard, content="false")
  inspect(info.services.system_theme, content="true")
  inspect(info.readiness.ready, content="true")
  assert_true(info.readiness.blocked_by.length() >= 1)
}

///|
test "linux client decoration commands reserve a titlebar" {
  let metrics = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=232.0),
  )
  let decorations = LinuxClientDecorationState::new(active=true)
  let commands = linux_client_decorated_commands(
    [
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=0.0, y=0.0, width=320.0, height=200.0),
        @core.Color::blue(),
      ),
    ],
    title="Inspector",
    metrics~,
    decorations~,
  )
  assert_true(commands.length() > 6)
  guard commands[0] is @core.DrawCommand::Clear(_) else {
    fail("expected wrapper clear")
  }
  guard commands[1]
    is @core.DrawCommand::FillRect({ size: { height, .. }, .. }, _) else {
    fail("expected titlebar fill")
  }
  inspect(height, content="32")
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Inspector", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::PushTransform({ ty: 32.0, .. })
    }),
  )
  assert_false(
    commands[1:].any(command => command is @core.DrawCommand::Clear(_)),
  )
}

///|
test "linux client decoration metrics and input stay in the content space" {
  let decorations = LinuxClientDecorationState::new(active=true)
  let content = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=200.0),
    scale_factor=2.0,
  )
  let surface = linux_surface_metrics_for_content(content, decorations)
  inspect(surface.logical_size.height, content="232")
  inspect(surface.physical_size.height, content="464")
  let recovered = linux_content_metrics_for_surface(surface, decorations)
  inspect(recovered.logical_size.height, content="200")
  inspect(recovered.physical_size.height, content="400")
  match
    linux_adjust_host_event_for_client_decorations(
      @host.HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=18.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
      decorations,
    ) {
    None => ()
    Some(_) => fail("expected titlebar pointer to stay out of app content")
  }
  match
    linux_adjust_host_event_for_client_decorations(
      @host.HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=52.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
      decorations,
    ) {
    Some(@host.HostEvent::Pointer({ position, .. })) =>
      inspect(position.y, content="20")
    _ => fail("expected content pointer to be translated")
  }
}

///|
test "linux capability summary exposes known service gaps" {
  let summary = linux_capability_summary()
  inspect(summary.label, content="Linux host")
  inspect(summary.services.system_theme, content="true")
  inspect(summary.services.clipboard, content="false")
  inspect(summary.service_count(), content="1")
  inspect(summary.input_count(), content="4")
  inspect(summary.text_input_ready, content="false")
  inspect(summary.drag_drop_ready, content="false")
  inspect(summary.has_required_app_basics(), content="true")
}

///|
test "linux scaffold exposes host contracts without owning a surface" {
  let surface = scaffold_surface_host(
    logical_width=320.0,
    logical_height=200.0,
    scale_factor=2.0,
  )
  assert_true(
    surface.logical_size() == @core.Size::new(width=320.0, height=200.0),
  )
  inspect(surface.owns_surface, content="false")
  inspect(surface.can_reconfigure, content="false")
  let input = scaffold_input_host()
  inspect(input.capabilities().text_input, content="false")
  inspect(input.capabilities().ime, content="false")
  inspect(input.capabilities().clipboard, content="false")
  inspect(input.capabilities().drag_drop, content="false")
  let services = scaffold_service_bridge()
  match
    services.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected unavailable Linux scaffold service")
  }
  let platform_services = linux_service_bridge()
  match platform_services.dispatch(@host.HostServiceRequest::QuerySystemTheme) {
    @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Light) => ()
    _ => fail("expected Linux platform system theme response")
  }
}

///|
test "linux host options construct without renderer dependencies" {
  let options = LinuxHostAppOptions::new()
  let _ = options
  assert_true(backend_info().renderer_ready)
}

///|
test "linux accessibility bridge dispatches semantics actions" {
  let invoked = Ref(0)
  let node = @core.SemanticsNode::{
    element_id: @core.ElementId::new(1),
    role: @core.SemanticsRole::Button,
    label: "Run",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=80.0, height=32.0),
    children: [],
  }
  let bridge = linux_accessibility_bridge(root=node, dispatch=(
    element_id,
    action,
    _value,
  ) => {
    if element_id == @core.ElementId::new(1) &&
      action == @core.SemanticsAction::Activate {
      invoked.val = invoked.val + 1
      true
    } else {
      false
    }
  })
  inspect(bridge.kind.label(), content="at-spi")
  inspect(bridge.available, content="true")
  match
    bridge.perform_action(
      @host.NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(1),
        action=@core.SemanticsAction::Activate,
      ),
    ) {
    @host.NativeAccessibilityActionResult::Handled =>
      inspect(invoked.val, content="1")
    _ => fail("expected Linux accessibility bridge action dispatch")
  }
}
