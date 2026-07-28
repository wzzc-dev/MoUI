///|
/// Table-driven tests for the shared_adapter package.
/// Covers window_event_transformer, render_lifecycle, and platform_capability.

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
    TransformedWindowEvent::DispatchHostEvent(
      @host.HostEvent::Focus(focus),
    ) =>
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
    TransformedWindowEvent::DispatchHostEvent(
      @host.HostEvent::Resized(metrics),
    ) =>
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
      @host.HostEvent::Resized(_metrics),
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
