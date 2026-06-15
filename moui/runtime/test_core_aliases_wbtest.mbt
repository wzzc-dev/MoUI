///|
fn draw_text_frame(commands : Array[DrawCommand], text : String) -> Rect? {
  for command in commands {
    match command {
      DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn draw_text_index(commands : Array[DrawCommand], text : String) -> Int {
  for index, command in commands {
    match command {
      DrawCommand::DrawText({ text: value, .. }) =>
        if value == text {
          return index
        }
      _ => ()
    }
  }
  -1
}

///|
fn runtime_wbtest_click(runtime : AppRuntime, x~ : Double, y~ : Double) -> Unit {
  let position = Point::new(x~, y~)
  runtime.dispatch_event(
    AppEvent::Pointer(PointerEvent::new(position~, phase=PointerPhase::Down)),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(PointerEvent::new(position~, phase=PointerPhase::Up)),
  )
}

///|
fn runtime_wbtest_click_draw_text(
  runtime : AppRuntime,
  text : String,
) -> Unit raise {
  guard draw_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  runtime_wbtest_click(
    runtime,
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
}
