///|
fn test_selection_highlight_color(commands : Array[DrawCommand]) -> Color? {
  for command in commands {
    match command {
      FillRect(_, color) => if color.a == 0.18 { return Some(color) }
      _ => ()
    }
  }
  None
}

///|
fn test_text_field_caret_rect(commands : Array[DrawCommand]) -> Rect? {
  for command in commands {
    match command {
      FillRect(rect, _) => if rect.size.width == 1.5 { return Some(rect) }
      _ => ()
    }
  }
  None
}

///|
fn test_draw_text_frame(commands : Array[DrawCommand], text : String) -> Rect? {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn has_draw_text(commands : Array[DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

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
