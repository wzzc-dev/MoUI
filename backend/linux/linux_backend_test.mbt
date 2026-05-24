///|
test "linux backend scaffold is explicit" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.window_backend_available, content="false")
  inspect(info.renderer_ready, content="false")
  inspect(info.capabilities.window, content="false")
  inspect(info.capabilities.accessibility, content="false")
  inspect(info.accessibility.kind.label(), content="at-spi")
  inspect(info.accessibility.contract_ready, content="true")
  inspect(info.accessibility.native_binding_ready, content="false")
  inspect(info.services.clipboard, content="false")
  inspect(info.readiness.ready, content="false")
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
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="system theme service is unavailable")
    _ => fail("expected unavailable Linux platform service")
  }
}

///|
test "linux accessibility bridge is explicit unavailable scaffold" {
  let bridge = linux_accessibility_bridge()
  inspect(bridge.kind.label(), content="at-spi")
  inspect(bridge.available, content="false")
  match
    bridge.perform_action(
      @host.NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(1),
        action=@core.SemanticsAction::Focus,
      ),
    ) {
    @host.NativeAccessibilityActionResult::BridgeUnavailable(message) =>
      inspect(
        message,
        content="native accessibility bridge is unavailable: at-spi",
      )
    _ => fail("expected unavailable Linux accessibility bridge")
  }
}
