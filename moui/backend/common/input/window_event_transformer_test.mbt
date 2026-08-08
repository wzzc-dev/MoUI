///|
test "resize payload is authoritative over observed surface state" {
  let event_size = @dpi.PhysicalSize::PhysicalSize(200, 100)
  let stale_size = @dpi.PhysicalSize::PhysicalSize(800, 600)
  let event = @window_core.WindowEvent::SurfaceResized(event_size)
  let result = transform_cross_platform_event(
    event,
    scale_factor=2.0,
    surface_size=Some(stale_size),
  )
  match result {
    TransformedWindowEvent::DispatchHostEvent(
      @backend_host.Event::Resized(metrics)
    ) => {
      assert_true(
        metrics.physical_size == @core.Size::new(width=200.0, height=100.0),
      )
      assert_true(
        metrics.logical_size == @core.Size::new(width=100.0, height=50.0),
      )
    }
    _ => fail("expected resize event")
  }
}

///|
test "scale change uses writer payload and scale payload" {
  let payload_size = @dpi.PhysicalSize::PhysicalSize(300, 150)
  let writer = @window_core.SurfaceSizeWriter::SurfaceSizeWriter(payload_size)
  let event = @window_core.WindowEvent::ScaleFactorChanged(1.5, writer)
  let result = transform_cross_platform_event(
    event,
    scale_factor=2.0,
    surface_size=None,
  )
  match result {
    TransformedWindowEvent::DispatchHostEvent(
      @backend_host.Event::Resized(metrics)
    ) => assert_true(metrics.scale_factor == 1.5)
    _ => fail("expected scale change resize event")
  }
}
