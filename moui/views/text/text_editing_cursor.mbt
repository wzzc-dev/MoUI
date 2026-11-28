///|
fn text_editing_cursor_width() -> Double {
  1.5
}

///|
fn text_editing_visual_cursor_rect(
  caret_rect : @core.Rect,
  caret : Int32,
  text_length : Int32,
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
  line_box_height : Double,
) -> @core.Rect {
  let height = line_box_height.max(1.0)
  @core.Rect::new(
    x=cursor_x,
    y=text_frame.origin.y + (text_frame.size.height - height).max(0.0) / 2.0,
    width=text_editing_cursor_width(),
    height~,
  )
}
