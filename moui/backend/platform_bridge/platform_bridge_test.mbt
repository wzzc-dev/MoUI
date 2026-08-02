///|
/// Table-driven tests for the platform_bridge package.
/// Covers neutral window-event transformation, logical coordinates, surface
/// lifecycle, and platform capability declarations.

// ---------------------------------------------------------------------------
// transform_cross_platform_event
// ---------------------------------------------------------------------------

///|
test "transform_cross_platform_event :: CloseRequested" {
  let event = @window_core.WindowEvent::CloseRequested
  let result = transform_cross_platform_event(event, scale_factor=2.0)
  match result {
    TransformedWindowEvent::CloseRequested => ()
    _ => fail("expected CloseRequested")
  }
}

///|
test "transform_cross_platform_event :: RedrawRequested" {
  let event = @window_core.WindowEvent::RedrawRequested
  let result = transform_cross_platform_event(event, scale_factor=2.0)
  match result {
    TransformedWindowEvent::WindowRedrawRequired => ()
    _ => fail("expected WindowRedrawRequired")
  }
}

///|
test "transform_cross_platform_event :: Focused" {
  let event = @window_core.WindowEvent::Focused(true)
  let result = transform_cross_platform_event(event, scale_factor=1.0)
  match result {
    TransformedWindowEvent::DispatchHostEvent(@host.HostEvent::Focus(focus)) =>
      assert_true(focus.focused)
    _ => fail("expected DispatchHostEvent(Focus)")
  }
}

///|
test "transform_cross_platform_event :: SurfaceResized" {
  let size = @dpi.PhysicalSize::PhysicalSize(200, 100)
  let event = @window_core.WindowEvent::SurfaceResized(size)
  let result = transform_cross_platform_event(
    event,
    scale_factor=2.0,
    surface_size=Some(size),
  )
  match result {
    TransformedWindowEvent::DispatchHostEvent(@host.HostEvent::Resized(metrics)) =>
      assert_true(metrics.scale_factor == 2.0)
    _ => fail("expected DispatchHostEvent(Resized) for SurfaceResized")
  }
}

///|
test "transform_cross_platform_event :: ScaleFactorChanged" {
  let size = @dpi.PhysicalSize::PhysicalSize(300, 150)
  let writer = @window_core.SurfaceSizeWriter(size)
  let event = @window_core.WindowEvent::ScaleFactorChanged(3.0, writer)
  let result = transform_cross_platform_event(
    event,
    scale_factor=3.0,
    surface_size=Some(size),
  )
  match result {
    TransformedWindowEvent::DispatchHostEvent(
      @host.HostEvent::Resized(_metrics)
    ) => ()
    _ => fail("expected DispatchHostEvent(Resized) from ScaleFactorChanged")
  }
}

///|
test "transform_cross_platform_event :: PointerMoved -> PlatformSpecific" {
  let event = @window_core.WindowEvent::PointerMoved(
    None,
    @dpi.PhysicalPositionF64::PhysicalPositionF64(10.0, 20.0),
    true,
    @window_core.PointerSource::Mouse,
  )
  let result = transform_cross_platform_event(event, scale_factor=1.0)
  match result {
    TransformedWindowEvent::PlatformSpecific => ()
    _ => fail("expected PlatformSpecific for PointerMoved")
  }
}

///|
test "transform_cross_platform_event :: PointerButton -> PlatformSpecific" {
  let event = @window_core.WindowEvent::PointerButton(
    None,
    @window_core.ElementState::Pressed,
    @dpi.PhysicalPositionF64::PhysicalPositionF64(10.0, 20.0),
    true,
    @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
  )
  let result = transform_cross_platform_event(event, scale_factor=1.0)
  match result {
    TransformedWindowEvent::PlatformSpecific => ()
    _ => fail("expected PlatformSpecific for PointerButton")
  }
}

// ---------------------------------------------------------------------------
// make_surface_metrics
// ---------------------------------------------------------------------------

///|
test "make_surface_metrics" {
  let size = @dpi.PhysicalSize::PhysicalSize(200, 100)
  let metrics = make_surface_metrics(size, scale_factor=2.0)
  assert_true(metrics.scale_factor == 2.0)
}

// ---------------------------------------------------------------------------
// normalize_pointer_position
// ---------------------------------------------------------------------------

///|
test "normalize_pointer_position :: identity scale" {
  let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(100.0, 50.0)
  let point = normalize_pointer_position(position, scale_factor=1.0)
  assert_true(point.x == 100.0)
  assert_true(point.y == 50.0)
}

///|
test "normalize_pointer_position :: 2x scale" {
  let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(200.0, 100.0)
  let point = normalize_pointer_position(position, scale_factor=2.0)
  assert_true(point.x == 100.0)
  assert_true(point.y == 50.0)
}

// ---------------------------------------------------------------------------
// PlatformCapabilities::default
// ---------------------------------------------------------------------------

///|
test "PlatformCapabilities :: default values" {
  let caps = PlatformCapabilities::default()
  assert_true(!caps.has_client_titlebar)
  assert_true(!caps.ephemeral_surface)
  assert_true(caps.has_native_event_pacing)
  assert_true(caps.supports_gpu_surface)
}

///|
test "PlatformSurfaceLifecycle carries only neutral metrics" {
  let size = @dpi.PhysicalSize::PhysicalSize(300, 150)
  let metrics = make_surface_metrics(size, scale_factor=2.0)
  let attached = PlatformSurfaceLifecycle::attach(metrics)
  guard attached.metrics() is Some(current) else {
    fail("expected an attached surface")
  }
  assert_true(current.logical_size.width == 150.0)
  assert_true(attached.detach().metrics() is None)
}

// ---------------------------------------------------------------------------
// service wire encoding (menu / file dialog)
// ---------------------------------------------------------------------------

///|
test "encode_menu_commands keeps the shared byte layout" {
  let encoded = @utf8.decode_lossy(
    encode_menu_commands([
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
test "menu_command_response maps native selection indices" {
  let commands = [
    @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Paste,
      label="Paste",
      enabled=false,
    ),
  ]
  match menu_command_response(commands, 0) {
    @host.HostServiceResponse::MenuAction(command) =>
      assert_eq(command.label, "Copy")
    _ => fail("expected MenuAction for enabled command")
  }
  match menu_command_response(commands, 1) {
    @host.HostServiceResponse::Unavailable(reason) =>
      assert_eq(reason, "menu command is disabled")
    _ => fail("expected Unavailable for disabled command")
  }
  match menu_command_response(commands, 5) {
    @host.HostServiceResponse::Unavailable(reason) =>
      assert_eq(reason, "menu selection cancelled")
    _ => fail("expected Unavailable for out-of-range index")
  }
}

///|
test "menu_command_response_with_unavailable maps the linux -2 sentinel" {
  let commands = [
    @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
  ]
  match menu_command_response_with_unavailable(commands, -2) {
    @host.HostServiceResponse::Unavailable(reason) =>
      assert_eq(reason, "menu service is unavailable")
    _ => fail("expected Unavailable for -2 sentinel")
  }
  match menu_command_response_with_unavailable(commands, -1) {
    @host.HostServiceResponse::Unavailable(reason) =>
      assert_eq(reason, "menu selection cancelled")
    _ => fail("expected Unavailable for negative index")
  }
}

///|
test "host_file_dialog_kind_code keeps the wire codes" {
  assert_eq(host_file_dialog_kind_code(@host.HostFileDialogKind::OpenFile), 0)
  assert_eq(host_file_dialog_kind_code(@host.HostFileDialogKind::SaveFile), 1)
  assert_eq(
    host_file_dialog_kind_code(@host.HostFileDialogKind::PickDirectory),
    2,
  )
}

///|
test "encode_host_string and encode_host_filter_list keep byte layout" {
  let text = @utf8.decode_lossy(encode_host_string("标题")[:], ignore_bom=false)
  assert_eq(text, "标题")
  let filters = @utf8.decode_lossy(
    encode_host_filter_list(["PNG", "JPEG"])[:],
    ignore_bom=false,
  )
  inspect(filters, content="PNG\nJPEG")
}

///|
test "decode_file_dialog_selection trims only when asked" {
  let bytes = @utf8.encode("/a \n /b\n"[:], bom=false)
  let raw = decode_file_dialog_selection(bytes)
  debug_inspect(raw, content="[/a ,  /b]")
  let trimmed = decode_file_dialog_selection(bytes, trim_paths=true)
  debug_inspect(trimmed, content="[/a, /b]")
}
