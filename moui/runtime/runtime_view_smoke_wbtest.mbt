///|
test "view runtime dispatches events and draws through AppRuntime" {
  let root : View[Unit] = View::primitive_button_view(
    text="Click",
    size=Size::new(width=100.0, height=50.0),
    font=FontSpec::new(size=16.0, weight=600),
    foreground=Color::black(),
    background=Brush::solid(Color::gray()),
    hovered_background=Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
    pressed_background=Brush::solid(Color::blue()),
    on_click=None,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=Size::new(width=120.0, height=80.0),
  )
  inspect(runtime.draw_commands().length(), content="3")
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=240.0, height=160.0)))
  assert_true(runtime.size() == Size::new(width=240.0, height=160.0))
  inspect(runtime.dirty_count(), content="1")
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Move,
      ),
    ),
  )
  inspect(runtime.needs_redraw(), content="true")
  ignore(runtime.draw_commands())
  inspect(runtime.dirty_count(), content="0")
}
