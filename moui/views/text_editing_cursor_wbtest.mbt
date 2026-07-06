///|
test "text editing visual cursor avoids covering following glyph" {
  let exact = @core.Rect::new(x=12.0, y=4.0, width=1.5, height=20.0)
  let middle = text_editing_visual_cursor_rect(exact, 1, 2)
  inspect(middle.origin.x, content="10.5")
  inspect(middle.size.width, content="1.5")
  inspect(middle.origin.x + middle.size.width, content="12")
  let start = text_editing_visual_cursor_rect(exact, 0, 2)
  inspect(start.origin.x, content="12")
  let end = text_editing_visual_cursor_rect(exact, 2, 2)
  inspect(end.origin.x, content="12")
}
