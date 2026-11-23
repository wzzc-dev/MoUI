///|
/// One undo entry per keystroke-run: two single-character inserts inside the
/// merge window and at contiguous positions collapse into one entry, so one
/// undo removes both characters.
test "markdown_edit_history merges consecutive inserts inside the window" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Insert, at_ms=0L)
  history.record(before="a", after="ab", kind=Insert, at_ms=100L)
  history.record(before="ab", after="abc", kind=Insert, at_ms=200L)
  assert_eq(
    history.undo(source="abc"),
    Some({ source: "", caret: 0, selection: None, }),
  )
  assert_false(history.can_undo())
  assert_true(history.can_redo())
}

///|
/// The merge window is 500 ms; an edit one millisecond past it starts a new
/// entry, so two undos are needed to get back to the empty source.
test "markdown_edit_history does not merge across the window" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Insert, at_ms=0L)
  history.record(before="a", after="ab", kind=Insert, at_ms=501L)
  assert_eq(
    history.undo(source="ab"),
    Some({ source: "a", caret: 1, selection: None, }),
  )
  assert_eq(
    history.undo(source="a"),
    Some({ source: "", caret: 0, selection: None, }),
  )
  assert_false(history.can_undo())
}

///|
/// A caret jump breaks the group: inserting two characters in a row at
/// different, non-contiguous spots keeps two entries.
test "markdown_edit_history does not merge non-contiguous edits" {
  let history = MarkdownEditHistory::new()
  history.record(before="ab", after="xab", kind=Insert, at_ms=0L)
  history.record(before="xab", after="xaby", kind=Insert, at_ms=10L)
  assert_eq(
    history.undo(source="xaby"),
    Some({ source: "xab", caret: 3, selection: None, }),
  )
  assert_true(history.can_undo())
}

///|
/// Kinds never cross-merge: an insert followed by a forward delete opens a
/// second entry.
test "markdown_edit_history does not merge different kinds" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Insert, at_ms=0L)
  history.record(before="a", after="ab", kind=Insert, at_ms=10L)
  history.record(before="ab", after="b", kind=ForwardDelete, at_ms=20L)
  assert_eq(
    history.undo(source="b"),
    Some({ source: "ab", caret: 0, selection: None, }),
  )
  assert_eq(
    history.undo(source="ab"),
    Some({ source: "", caret: 0, selection: None, }),
  )
  assert_false(history.can_undo())
}

///|
/// Multi-character edits are never mergeable, even at the same position and
/// inside the window.
test "markdown_edit_history keeps a paste as its own entry" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Insert, at_ms=0L)
  history.record(before="a", after="axy", kind=Other, at_ms=10L)
  history.record(before="axy", after="axyz", kind=Insert, at_ms=20L)
  assert_eq(
    history.undo(source="axyz"),
    Some({ source: "axy", caret: 3, selection: None, }),
  )
  assert_eq(
    history.undo(source="axy"),
    Some({ source: "a", caret: 1, selection: None, }),
  )
  assert_eq(
    history.undo(source="a"),
    Some({ source: "", caret: 0, selection: None, }),
  )
}

///|
/// Inserting a newline is a structural edit, not typing, so it stays in its
/// own entry.
test "markdown_edit_history does not merge newline insertion" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Insert, at_ms=0L)
  history.record(before="a", after="a\n", kind=Insert, at_ms=10L)
  assert_eq(
    history.undo(source="a\n"),
    Some({ source: "a", caret: 1, selection: None, }),
  )
  assert_true(history.can_undo())
}

///|
/// A backspace undoes to the caret position it had before the delete: one
/// past the removed character.
test "markdown_edit_history restores the pre-backspace caret" {
  let history = MarkdownEditHistory::new()
  history.record(before="ab", after="a", kind=Backspace, at_ms=0L)
  assert_eq(
    history.undo(source="a"),
    Some({ source: "ab", caret: 2, selection: None, }),
  )
  assert_eq(history.undo(source="a"), None)
}

///|
/// Consecutive backspaces within the window merge and undo removes the whole
/// run, with the caret back where the run started.
test "markdown_edit_history merges consecutive backspaces" {
  let history = MarkdownEditHistory::new()
  history.record(before="abc", after="ab", kind=Backspace, at_ms=0L)
  history.record(before="ab", after="a", kind=Backspace, at_ms=100L)
  assert_eq(
    history.undo(source="a"),
    Some({ source: "abc", caret: 3, selection: None, }),
  )
  assert_false(history.can_undo())
}

///|
/// A repeated forward delete at the same position merges.
test "markdown_edit_history merges consecutive forward deletes" {
  let history = MarkdownEditHistory::new()
  history.record(before="abc", after="bc", kind=ForwardDelete, at_ms=0L)
  history.record(before="bc", after="c", kind=ForwardDelete, at_ms=100L)
  assert_eq(
    history.undo(source="c"),
    Some({ source: "abc", caret: 0, selection: None, }),
  )
  assert_false(history.can_undo())
}

///|
/// undo/redo refuse to touch a source the history did not produce instead of
/// corrupting the stack.
test "markdown_edit_history rejects a diverged source" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Other, at_ms=0L)
  assert_eq(history.undo(source="xyz"), None)
  assert_true(history.can_undo())
  assert_eq(
    history.undo(source="a"),
    Some({ source: "", caret: 0, selection: None, }),
  )
  assert_eq(history.redo(source="xyz"), None)
  assert_true(history.can_redo())
}

///|
/// A new edit drops the redo branch.
test "markdown_edit_history clears the redo branch on a new edit" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Other, at_ms=0L)
  let _ = history.undo(source="a")
  assert_true(history.can_redo())
  history.record(before="", after="b", kind=Other, at_ms=10L)
  assert_false(history.can_redo())
}

///|
/// An edit after undo starts a fresh group rather than rewriting the restored
/// entry.
test "markdown_edit_history does not merge into an undone entry" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Insert, at_ms=0L)
  let _ = history.undo(source="a")
  history.record(before="", after="b", kind=Insert, at_ms=10L)
  assert_eq(
    history.undo(source="b"),
    Some({ source: "", caret: 0, selection: None, }),
  )
  assert_false(history.can_undo())
  assert_eq(
    history.redo(source=""),
    Some({ source: "b", caret: 1, selection: None, }),
  )
}

///|
/// The depth cap drops the oldest entries so a long session cannot keep every
/// snapshot alive.
test "markdown_edit_history caps its depth" {
  let history = MarkdownEditHistory::new()
  let mut source = ""
  let mut index = 0
  while index < 150 {
    let before = source
    source = source + "ab"
    history.record(before~, after=source, kind=Other, at_ms=index.to_int64())
    index = index + 1
  }
  let mut undone = 0
  while history.can_undo() {
    match history.undo(source~) {
      Some(outcome) => {
        source = outcome.source
        undone = undone + 1
      }
      None => break
    }
  }
  assert_eq(undone, 100)
}

///|
/// clear drops both stacks.
test "markdown_edit_history clear resets both stacks" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Other, at_ms=0L)
  let _ = history.undo(source="a")
  history.clear()
  assert_false(history.can_undo())
  assert_false(history.can_redo())
}

///|
/// A no-op record leaves the history untouched and closes the open group, so
/// the next single edit starts fresh.
test "markdown_edit_history ignores an equal-source record" {
  let history = MarkdownEditHistory::new()
  history.record(before="", after="a", kind=Insert, at_ms=0L)
  history.record(before="a", after="a", kind=Insert, at_ms=10L)
  history.record(before="a", after="ab", kind=Insert, at_ms=20L)
  assert_eq(
    history.undo(source="ab"),
    Some({ source: "a", caret: 1, selection: None, }),
  )
  assert_eq(
    history.undo(source="a"),
    Some({ source: "", caret: 0, selection: None, }),
  )
}

///|
/// Undo and redo hand the recorded selections back: undo restores the
/// pre-edit caret and range, redo the post-edit one.
test "markdown_edit_history restores selections on undo and redo" {
  let history = MarkdownEditHistory::new()
  let before_sel : MarkdownEditorSelection = { caret: 0, selection: None, }
  let after_sel : MarkdownEditorSelection = {
    caret: 3,
    selection: Some({ start: 0, end: 3, }),
  }
  history.record(
    before="",
    after="abc",
    kind=Other,
    at_ms=0L,
    selection_before=Some(before_sel),
    selection_after=Some(after_sel),
  )
  assert_eq(
    history.undo(source="abc"),
    Some({ source: "", caret: 0, selection: Some(before_sel), }),
  )
  assert_eq(
    history.redo(source=""),
    Some({ source: "abc", caret: 3, selection: Some(after_sel), }),
  )
}

///|
/// A merged run keeps the selection from before the first keystroke and the
/// one after the last, so one undo/redo round-trips the outer range.
test "markdown_edit_history merges keep the outer selections" {
  let history = MarkdownEditHistory::new()
  let start : MarkdownEditorSelection = { caret: 0, selection: None, }
  let after_a : MarkdownEditorSelection = { caret: 1, selection: None, }
  let after_ab : MarkdownEditorSelection = { caret: 2, selection: None, }
  history.record(
    before="",
    after="a",
    kind=Insert,
    at_ms=0L,
    selection_before=Some(start),
    selection_after=Some(after_a),
  )
  history.record(
    before="a",
    after="ab",
    kind=Insert,
    at_ms=10L,
    selection_before=Some(after_a),
    selection_after=Some(after_ab),
  )
  assert_eq(
    history.undo(source="ab"),
    Some({ source: "", caret: 0, selection: Some(start), }),
  )
  assert_eq(
    history.redo(source=""),
    Some({ source: "ab", caret: 2, selection: Some(after_ab), }),
  )
}
