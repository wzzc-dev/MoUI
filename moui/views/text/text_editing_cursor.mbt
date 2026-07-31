///|
fn text_editing_cursor_width() -> Double {
  1.5
}

///|
fn text_editing_visual_cursor_rect(
  caret_rect : @core.Rect,
  caret : Int,
  text_length : Int,
) -> @core.Rect {
  let width = caret_rect.size.width
  let x = if caret > 0 && caret < text_length {
    caret_rect.origin.x - width
  } else {
    caret_rect.origin.x
  }
  @core.Rect::new(
    x~,
    y=caret_rect.origin.y,
    width~,
    height=caret_rect.size.height,
  )
}

///|
fn text_editing_exact_cursor_rect(
  text_frame : @core.Rect,
  cursor_x : Double,
) -> @core.Rect {
  @core.Rect::new(
    x=cursor_x,
    y=text_frame.origin.y + 6.0,
    width=text_editing_cursor_width(),
    height=max_double(8.0, text_frame.size.height - 12.0),
  )
}
