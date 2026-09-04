///|
/// One undo/redo step as a delta: replacing `before` with `after` at
/// `start` (character indices in the pre-edit text) produced the new
/// document; undoing re-applies the replacement backwards. Entries
/// stay the size of the edit instead of the document, so keeping the
/// whole undo stack alive — and copying it per frame in the element
/// tree — costs proportional to user keystrokes, not document size.
///
/// `caret`/`selection` restore the editor position to what it was
/// before the edit when the entry is undone. The entry is symmetric:
/// moving it onto the opposite stack (the same delta with the live
/// position written into `caret`/`selection`) is all a redo step needs,
/// because `before` and `after` already describe both directions of
/// the edit.
pub(all) struct TextHistoryEntryContext {
  start : Int
  before : String
  after : String
  caret : Int
  selection : TextRange?
} derive(Eq, Debug, ToJson)

///|
/// Current text -> text with the entry's edit applied forward (redo).
pub fn TextHistoryEntryContext::redo_text(
  self : TextHistoryEntryContext,
  text : String,
) -> String {
  text_history_apply_delta(text, self.start, self.after, self.before.length())
}

///|
/// Current text -> text with the entry's edit reverted (undo).
pub fn TextHistoryEntryContext::undo_text(
  self : TextHistoryEntryContext,
  text : String,
) -> String {
  text_history_apply_delta(text, self.start, self.before, self.after.length())
}

///|
/// Minimal prefix/suffix-anchored delta `(start, before, after)`
/// between two texts. Used by edit paths that only observe the before
/// and after documents; a single replacement stays exact, while a
/// whole-document swap degrades to the (still O(edit)) replacement of
/// the shared-affix-free middle.
pub fn text_history_delta(
  previous : String,
  next : String,
) -> (Int, String, String) {
  let before = previous.to_array()
  let after = next.to_array()
  let mut prefix = 0
  while prefix < before.length() &&
    prefix < after.length() &&
    before[prefix] == after[prefix] {
    prefix = prefix + 1
  }
  let mut suffix = 0
  while suffix < before.length() - prefix &&
    suffix < after.length() - prefix &&
    before[before.length() - 1 - suffix] ==
      after[after.length() - 1 - suffix] {
    suffix = suffix + 1
  }
  (
    prefix,
    String::from_array(before[prefix:before.length() - suffix]),
    String::from_array(after[prefix:after.length() - suffix]),
  )
}

///|
fn text_history_apply_delta(
  text : String,
  start : Int,
  replacement : String,
  removed_length : Int,
) -> String {
  let chars = text.to_array()
  let start = start.clamp(min=0, max=chars.length())
  let end = (start + removed_length).clamp(min=start, max=chars.length())
  String::from_array(chars[:start]) +
    replacement + String::from_array(chars[end:])
}

///|
test "delta entries apply and revert at their recorded position" {
  let entry : TextHistoryEntryContext = {
    start: 2,
    before: "cd",
    after: "XYZ",
    caret: 2,
    selection: None,
  }
  assert_eq(entry.redo_text("abcdefg"), "abXYZefg")
  assert_eq(entry.undo_text("abXYZefg"), "abcdefg")
}

///|
test "delta application clamps against out-of-range documents" {
  let entry : TextHistoryEntryContext = {
    start: 99,
    before: "x",
    after: "yz",
    caret: 0,
    selection: None,
  }
  assert_eq(entry.undo_text("ab"), "abx")
  assert_eq(entry.redo_text("ab"), "abyz")
}

///|
test "one delta serves both stacks across an undo-redo round trip" {
  let entry : TextHistoryEntryContext = {
    start: 0,
    before: "",
    after: "hello",
    caret: 0,
    selection: None,
  }
  // Undo reverts the typed word; the redo stack receives the same
  // delta with the position the undo is leaving behind, and redoing
  // it re-applies the forward edit exactly.
  let after_undo = entry.undo_text("hello")
  assert_eq(after_undo, "")
  let redo_entry = { ..entry, caret: 0 }
  assert_eq(redo_entry.redo_text(after_undo), "hello")
  assert_eq(redo_entry.undo_text("hello"), after_undo)
}

///|
test "prefix-suffix delta captures exactly the edited middle" {
  assert_eq(
    text_history_delta("hello world", "hello big world"),
    (6, "", "big "),
  )
  // The greedy trim may tie-align the shared "t"; the split is chosen
  // for correctness of the round trip, not for aesthetics.
  assert_eq(
    text_history_delta("one two three", "one three"),
    (5, "wo t", ""),
  )
  assert_eq(text_history_delta("", "abc"), (0, "", "abc"))
  assert_eq(text_history_delta("abc", ""), (0, "abc", ""))
  // Shared prefix and suffix must not overlap into a negative span.
  assert_eq(text_history_delta("aa", "aaa"), (2, "", "a"))
}

///|
test "delta round-trips through the entry it feeds" {
  let previous = "const answer = 41"
  let next = "const answer = 42"
  let (start, before, after) = text_history_delta(previous, next)
  let entry : TextHistoryEntryContext = {
    start,
    before,
    after,
    caret: start + 19,
    selection: None,
  }
  assert_eq(entry.undo_text(next), previous)
  assert_eq(entry.redo_text(previous), next)
  assert_true(before.length() <= 1 && after.length() <= 1)
}
