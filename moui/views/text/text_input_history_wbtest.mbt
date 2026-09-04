///|
/// Behavioural coverage for the plain text input history in views,
/// which has no merge window: every recorded edit is exactly one delta
/// entry, and undo/redo move that same entry between the stacks.
fn history_view_control() -> @core.TextControlStateContext {
  {
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
fn history_view_type(
  control : @core.TextControlStateContext,
  text : String,
  inserted : String,
) -> TextInputApplyResult {
  apply_text_input(
    control,
    text,
    @core.TextInputEvent::InsertText(inserted),
    record_history=true,
  )
}

///|
test "typing records one exact delta per character" {
  let mut control = history_view_control()
  let mut text = ""
  for ch in "abc".to_array() {
    let inserted = ch.to_string()
    let result = history_view_type(control, text, inserted)
    text = result.text
    control = result.control
  }
  assert_eq(text, "abc")
  assert_eq(control.undo_stack.length(), 3)
  assert_eq(control.redo_stack.length(), 0)
  for index, entry in control.undo_stack {
    assert_eq(entry.start, index)
    assert_eq(entry.before, "")
    assert_eq(
      entry.after,
      String::from_array("abc".to_array()[index:index + 1]),
    )
    assert_eq(entry.caret, index)
  }
}

///|
test "undo reverts one entry and redoes it exactly" {
  let mut control = history_view_control()
  let mut text = ""
  for ch in "ab".to_array() {
    let result = history_view_type(control, text, ch.to_string())
    text = result.text
    control = result.control
  }
  let undone = restore_text_history(control, text, undo=true)
  assert_eq(undone.text, "a")
  assert_eq(undone.changed, true)
  assert_eq(undone.control.caret, 1)
  assert_eq(undone.control.undo_stack.length(), 1)
  assert_eq(undone.control.redo_stack.length(), 1)
  // The redo entry is the same delta with the left-behind position.
  let redo_entry = undone.control.redo_stack[0]
  assert_eq(redo_entry.start, 1)
  assert_eq(redo_entry.after, "b")
  assert_eq(redo_entry.caret, 2)
  let redone = restore_text_history(undone.control, "a", undo=false)
  assert_eq(redone.text, "ab")
  assert_eq(redone.control.redo_stack.length(), 0)
  assert_eq(restore_text_history(redone.control, "ab", undo=true).text, "a")
}

///|
test "typing after an undo clears the redo branch" {
  let base = history_view_type(history_view_control(), "", "ab")
  let undone = restore_text_history(base.control, "ab", undo=true)
  assert_eq(undone.text, "")
  let typed = history_view_type(undone.control, "", "x")
  assert_eq(typed.text, "x")
  assert_eq(typed.control.redo_stack.length(), 0)
  assert_eq(typed.control.undo_stack.length(), 1)
}

///|
test "a paste is one entry and undo reverts all of it" {
  let caret_at_end = { ..history_view_control(), caret: 3 }
  let base = history_view_type(caret_at_end, "hi ", "there")
  assert_eq(base.text, "hi there")
  assert_eq(base.control.undo_stack.length(), 1)
  let entry = base.control.undo_stack[0]
  assert_eq(entry.start, 3)
  assert_eq(entry.before, "")
  assert_eq(entry.after, "there")
  let undone = restore_text_history(base.control, "hi there", undo=true)
  assert_eq(undone.text, "hi ")
}

///|
test "deleting a selection records the removed text exactly" {
  let control = history_view_control()
  let with_selection : @core.TextControlStateContext = {
    ..control,
    caret: 4,
    selection: Some(@core.TextRange::new(start=1, end=4)),
  }
  let result = apply_text_input(
    with_selection,
    "abcdef",
    @core.TextInputEvent::DeleteRange(@core.TextRange::new(start=1, end=4)),
    record_history=true,
  )
  assert_eq(result.text, "aef")
  let entry = result.control.undo_stack[0]
  assert_eq(entry.start, 1)
  assert_eq(entry.before, "bcd")
  assert_eq(entry.after, "")
  let undone = restore_text_history(result.control, "aef", undo=true)
  assert_eq(undone.text, "abcdef")
}

///|
test "history entries stay the size of the edit, not the document" {
  // A long document with one appended character must not push a
  // snapshot of the document onto the undo stack.
  let long_text = "x".repeat(4096)
  let result = history_view_type(history_view_control(), long_text, "!")
  assert_eq(result.control.undo_stack.length(), 1)
  let entry = result.control.undo_stack[0]
  assert_true(text_length(entry.before) + text_length(entry.after) <= 1)
}
