///|
test "linux backend reports Wayland renderer readiness with explicit gaps" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.window_backend_available, content="true")
  inspect(info.renderer_ready, content="true")
  inspect(info.capabilities.window, content="true")
  inspect(info.capabilities.renderer, content="true")
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
test "linux accessibility bridge dispatches semantics actions" {
  let invoked = Ref(0)
  let node = @core.SemanticsNode::{
    element_id: @core.ElementId::new(1),
    role: @core.SemanticsRole::Button,
    label: "Run",
    value: "",
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
