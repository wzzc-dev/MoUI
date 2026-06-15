///|
fn assert_cluster_caret_movement(
  text : String,
  start : Int,
  end : Int,
) -> Unit raise {
  let from_end = move_text_caret(text, end, None, MoveLeft, extend=false)
  inspect(from_end.caret, content="\{start}")
  assert_true(from_end.selection is None)
  let from_start = move_text_caret(text, start, None, MoveRight, extend=false)
  inspect(from_start.caret, content="\{end}")
  assert_true(from_start.selection is None)
  let from_inside_left = move_text_caret(
    text,
    start + 1,
    None,
    MoveLeft,
    extend=false,
  )
  inspect(from_inside_left.caret, content="\{start}")
  let from_inside_right = move_text_caret(
    text,
    end - 1,
    None,
    MoveRight,
    extend=false,
  )
  inspect(from_inside_right.caret, content="\{end}")
  let extended = move_text_caret(text, start, None, MoveRight, extend=true)
  inspect(extended.caret, content="\{end}")
  guard extended.selection is Some(selection) else {
    fail("expected cluster selection")
  }
  let selection = selection.normalized()
  inspect(selection.start, content="\{start}")
  inspect(selection.end, content="\{end}")
}
