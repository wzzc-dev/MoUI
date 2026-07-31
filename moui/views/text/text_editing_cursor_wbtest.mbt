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

///|
test "native range replacement and selection normalize grapheme boundaries" {
  let control : @core.TextControlStateContext = {
    caret: 3,
    selection: None,
    text_selection_anchor: None,
    composition: Some("pending"),
    composition_cursor: Some(@core.TextRange::collapsed(1)),
    undo_stack: [],
    redo_stack: [],
  }
  let replaced = apply_text_input(
    control,
    "a🤣b",
    @core.TextInputEvent::ReplaceText(
      @core.TextRange::new(start=1, end=2),
      "你",
    ),
    record_history=true,
  )
  inspect(replaced.text, content="a你b")
  inspect(replaced.control.caret, content="2")
  assert_true(replaced.control.composition is None)
  let selected = apply_text_input(
    replaced.control,
    replaced.text,
    @core.TextInputEvent::SetSelection(@core.TextRange::new(start=3, end=1)),
    record_history=true,
  )
  inspect(selected.control.caret, content="3")
  match selected.control.selection {
    Some(range) => {
      inspect(range.start, content="1")
      inspect(range.end, content="3")
    }
    None => fail("expected native selection range")
  }
  inspect(selected.text, content="a你b")
}
