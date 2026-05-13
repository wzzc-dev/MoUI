///|
test "windows backend converts resize event" {
  let event = window_event_to_core(
    @window_core.WindowEvent::SurfaceResized(@dpi.PhysicalSize::new(10, 20)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@core.AppEvent::Resize(size)) =>
      assert_true(size == @core.Size::new(width=10.0, height=20.0))
    _ => fail("expected resize event")
  }
}

///|
test "windows backend converts pointer movement and left button" {
  let moved = window_event_to_core(
    @window_core.WindowEvent::PointerMoved(
      None,
      @dpi.PhysicalPositionF64::new(3.0, 4.0),
      true,
      @window_core.PointerSource::Mouse,
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match moved {
    Some(@core.AppEvent::Pointer(event)) => {
      assert_true(event.position == @core.Point::new(x=3.0, y=4.0))
      assert_true(event.phase == @core.PointerPhase::Move)
    }
    _ => fail("expected pointer move")
  }

  let down = window_event_to_core(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::new(5.0, 6.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match down {
    Some(@core.AppEvent::Pointer(event)) => {
      assert_true(event.position == @core.Point::new(x=5.0, y=6.0))
      assert_true(event.phase == @core.PointerPhase::Down)
    }
    _ => fail("expected pointer down")
  }
}

///|
test "windows backend converts close event" {
  let event = window_event_to_core(
    @window_core.WindowEvent::CloseRequested,
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@core.AppEvent::CloseRequested) => ()
    _ => fail("expected close event")
  }
}
