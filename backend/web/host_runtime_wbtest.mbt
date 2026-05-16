///|
test "web maps surface resize through current scale factor" {
  let event = window_event_to_host_with_scale(
    @window_core.WindowEvent::SurfaceResized(@dpi.PhysicalSize::new(800, 600)),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=400.0, height=300.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=800.0, height=600.0),
      )
      inspect(metrics.scale_factor, content="2")
    }
    _ => fail("expected scaled resize event")
  }
}

///|
test "web derives window default canvas id without host string return" {
  inspect(window_web_default_canvas_id(1), content="moonbit-window-web-1")
  inspect(window_web_default_canvas_id(42), content="moonbit-window-web-42")
}
