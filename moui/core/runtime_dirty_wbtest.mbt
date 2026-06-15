///|
test "button press batches paint without build or layout flush" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Press",
      size: Size::new(width=100.0, height=44.0),
      font: FontSpec::new(size=16.0),
      foreground: Color::black(),
      background: Brush::solid(Color::gray()),
      hovered_background: Brush::solid(Color::gray()),
      pressed_background: Brush::solid(Color::blue()),
      border: None,
      shadow: None,
      corner_radius: 0.0,
      on_click: None,
    }),
    size=Size::new(width=120.0, height=60.0),
  )
  inspect(runtime.rebuild_pass_count, content="0")
  inspect(runtime.layout_pass_count, content="1")
  inspect(runtime.paint_pass_count, content="1")
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.needs_rebuild(), content="false")
  inspect(runtime.needs_layout(), content="false")
  inspect(runtime.needs_paint(), content="true")
  inspect(runtime.dirty_build_elements.length(), content="0")
  inspect(runtime.dirty_layout_elements.length(), content="0")
  inspect(runtime.dirty_paint_elements.length(), content="1")
  inspect(runtime.rebuild_pass_count, content="0")
  inspect(runtime.layout_pass_count, content="1")
  inspect(runtime.paint_pass_count, content="1")
  ignore(runtime.draw_commands())
  inspect(runtime.rebuild_pass_count, content="0")
  inspect(runtime.layout_pass_count, content="1")
  inspect(runtime.paint_pass_count, content="2")
  inspect(runtime.dirty_paint_elements.length(), content="0")
}
