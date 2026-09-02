///|
/// Deterministic coverage for the undo-history merge window. All tests
/// install a fake millisecond clock so the grouping never depends on
/// wall time, and hand the clock back to the real source afterwards.
fn history_start_fake_clock() -> Unit {
  rich_text_history_fake_clock_ms.val = 0
}

///|
fn history_stop_fake_clock() -> Unit {
  rich_text_history_fake_clock_ms.val = -1
}

///|
fn history_advance(ms : Int) -> Unit {
  rich_text_history_fake_clock_ms.val = rich_text_history_fake_clock_ms.val + ms
}

///|
fn history_test_control(caret? : Int = 0) -> @core.TextControlStateContext {
  rich_text_history_reset_group()
  {
    caret,
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
/// Records an accepted edit exactly like the editor apply paths do:
/// classification uses the pre-edit caret from the control, and the
/// entry is pushed only when the merge window declines to absorb it.
fn history_apply(
  control : @core.TextControlStateContext,
  previous : String,
  next : String,
) -> @core.TextControlStateContext {
  let push = rich_text_history_record_edit(
    control,
    previous,
    next,
    control.caret,
  )
  let undo_stack = control.undo_stack.copy()
  if push {
    undo_stack.push({
      text: previous,
      caret: control.caret,
      selection: control.selection,
    })
  }
  let caret = control.caret + text_length(next) - text_length(previous)
  { ..control, caret, undo_stack, redo_stack: [] }
}

///|
test "undo merge window: one undo reverts a typed word" {
  history_start_fake_clock()
  let mut control = history_test_control()
  let mut text = ""
  for ch in "hello".to_array() {
    let next = text + ch.to_string()
    control = history_apply(control, text, next)
    text = next
    history_advance(30)
  }
  // Typing a word must open a single undo group.
  assert_eq(control.undo_stack.length(), 1)
  let group_entry = control.undo_stack[0]
  assert_eq(group_entry.text, "")
  assert_eq(group_entry.caret, 0)
  let restored = restore_text_history(control, text, undo=true)
  // One undo must revert the whole run.
  assert_eq(restored.text, "")
  assert_eq(restored.control.undo_stack.length(), 0)
  assert_eq(restored.control.redo_stack.length(), 1)
  history_stop_fake_clock()
}

///|
test "undo merge window: a pause longer than the window splits the group" {
  history_start_fake_clock()
  let mut control = history_test_control()
  control = history_apply(control, "", "a")
  control = history_apply(control, "a", "ab")
  history_advance(rich_text_history_merge_window_ms + 1)
  control = history_apply(control, "ab", "abc")
  assert_eq(control.undo_stack.length(), 2)
  assert_eq(control.undo_stack[1].text, "ab")
  history_stop_fake_clock()
}

///|
test "undo merge window: newlines and pastes always start their own group" {
  history_start_fake_clock()
  let mut control = history_test_control()
  control = history_apply(control, "", "a")
  control = history_apply(control, "a", "a\n")
  // The newline must push its own entry.
  assert_eq(control.undo_stack.length(), 2)
  control = history_apply(control, "a\n", "a\nbc")
  // The paste must push its own entry.
  assert_eq(control.undo_stack.length(), 3)
  control = history_apply(control, "a\nbc", "a\nbcd")
  // An insert after a paste must start a new group.
  assert_eq(control.undo_stack.length(), 4)
  history_stop_fake_clock()
}

///|
test "undo merge window: backspaces group, switches of kind push" {
  history_start_fake_clock()
  let mut control = history_test_control()
  control = history_apply(control, "", "abcdef")
  // The paste baseline pushes.
  assert_eq(control.undo_stack.length(), 1)
  control = history_apply(control, "abcdef", "abcde")
  control = history_apply(control, "abcde", "abcd")
  // The backspaces must share one undo group.
  assert_eq(control.undo_stack.length(), 2)
  control = history_apply(control, "abcd", "abcde")
  // An insert after backspaces must start a new group.
  assert_eq(control.undo_stack.length(), 3)
  history_stop_fake_clock()
}

///|
test "undo merge window: repeated forward deletes group at one position" {
  history_start_fake_clock()
  let mut control = history_test_control(caret=1)
  control = history_apply(control, "abcd", "acd")
  // A forward delete leaves the caret at the same column.
  control = { ..control, caret: 1 }
  control = history_apply(control, "acd", "ad")
  // Forward deletes at one caret must share a group.
  assert_eq(control.undo_stack.length(), 1)
  history_stop_fake_clock()
}

///|
test "undo merge window: active selections never merge" {
  history_start_fake_clock()
  let base = history_test_control(caret=2)
  let mut control = {
    ..base,
    selection: Some(@core.TextRange::new(start=1, end=2)),
  }
  control = history_apply(control, "xyz", "ayz")
  control = history_apply(control, "ayz", "byz")
  // Each selection-replacing edit must push its own entry.
  assert_eq(control.undo_stack.length(), 2)
  history_stop_fake_clock()
}

///|
test "undo merge window: history restores reset the group" {
  history_start_fake_clock()
  let mut control = history_test_control()
  control = history_apply(control, "", "a")
  control = history_apply(control, "a", "ab")
  assert_eq(control.undo_stack.length(), 1)
  let restored = restore_text_history(control, "ab", undo=true)
  control = restored.control
  let redone = restore_text_history(control, "", undo=false)
  control = redone.control
  assert_eq(control.undo_stack.length(), 1)
  control = history_apply(control, "ab", "abc")
  // The edit after a redo must open a fresh group even though the
  // stack length, text length, and caret all line up with the old group.
  assert_eq(control.undo_stack.length(), 2)
  history_stop_fake_clock()
}

///|
test "undo merge window: foreign stack changes break the merge" {
  history_start_fake_clock()
  let mut control = history_test_control()
  control = history_apply(control, "", "a")
  control.undo_stack.push({ text: "foreign", caret: 0, selection: None })
  control = history_apply(control, "a", "ab")
  // A stack change outside the group must force a push.
  assert_eq(control.undo_stack.length(), 3)
  history_stop_fake_clock()
}

///|
test "undo merge window: applied input edits flow through the window" {
  history_start_fake_clock()
  let control = history_test_control()
  let first = apply_rich_text_input_transform(
    control,
    "",
    { text: "h", caret: 1, selection: None },
    record_history=true,
  )
  history_advance(40)
  let second = apply_rich_text_input_transform(
    first.control,
    "h",
    { text: "he", caret: 2, selection: None },
    record_history=true,
  )
  assert_eq(second.changed, true)
  // The editor apply path must honor the merge window.
  assert_eq(second.control.undo_stack.length(), 1)
  history_stop_fake_clock()
}
