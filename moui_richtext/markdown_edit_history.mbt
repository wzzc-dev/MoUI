///|
/// What kind of edit produced one undo entry.
///
/// Only the three single-character kinds are mergeable; `Other` covers
/// pastes, command transforms, IME commits and every multi-character edit,
/// each of which always starts a fresh undo group.
#derive(Eq, Debug)
pub(all) enum MarkdownEditKind {
  Insert
  Backspace
  ForwardDelete
  Other
}

///|
pub extend MarkdownEditKind with Debug::{to_repr}

///|
pub extend MarkdownEditKind with Eq::{not_equal, equal}

///|
/// The document text, caret and selection to restore, as returned by
/// `undo`/`redo`. `selection` is `None` when the edit was recorded without
/// one, and the caller then falls back to a collapsed caret.
#derive(Eq, Debug)
pub(all) struct MarkdownEditOutcome {
  source : String
  caret : Int32
  selection : MarkdownEditorSelection?
}

///|
pub extend MarkdownEditOutcome with Debug::{to_repr}

///|
pub extend MarkdownEditOutcome with Eq::{not_equal, equal}

///|
/// One undo entry. Full before/after text is stored instead of a delta:
/// the caller feeds complete sources in and gets a complete source back,
/// so a stale entry can be rejected by comparing text rather than by
/// trusting offsets that a diverged document would silently accept.
priv struct MarkdownEditEntry {
  before : String
  after : String
  caret_before : Int32
  caret_after : Int32
  selection_before : MarkdownEditorSelection?
  selection_after : MarkdownEditorSelection?
}

///|
/// The changed span of one edit, derived from the old and new source.
priv struct MarkdownEditDelta {
  start : Int32
  removed : Int32
  inserted : Int32
}

///|
/// State of the still-open typing group. It is dropped as soon as an edit
/// that cannot merge arrives, and after any undo/redo or clear, so a group
/// never rewrites an entry that is no longer on top of the stack.
priv struct MarkdownEditGroupState {
  kind : MarkdownEditKind
  mut last_start : Int32
  mut last_push_ms : Int64
  expected_stack_length : Int32
}

///|
/// Consecutive single-character edits of the same kind within this window
/// merge into one undo entry (MoMark parity).
let markdown_edit_history_merge_window_ms : Int64 = 500L

///|
/// Undo depth cap. Each entry holds two full document sources, so a long
/// session would otherwise keep every keystroke's snapshot alive.
let markdown_edit_history_max_entries : Int32 = 100

///|
/// Grouping undo history over complete document sources.
///
/// The clock is passed into `record`, so the merge window is testable and
/// the history never reads `@env` itself.
pub(all) struct MarkdownEditHistory {
  priv undo : Array[MarkdownEditEntry]
  priv redo : Array[MarkdownEditEntry]
  priv mut group : MarkdownEditGroupState?
}

///|
pub fn MarkdownEditHistory::new() -> MarkdownEditHistory {
  { undo: [], redo: [], group: None, }
}

///|
fn markdown_edit_delta(before : String, after : String) -> MarkdownEditDelta {
  let before_chars = before.to_array()
  let after_chars = after.to_array()
  let before_length = before_chars.length()
  let after_length = after_chars.length()
  let shorter = if before_length < after_length {
    before_length
  } else {
    after_length
  }
  let mut prefix = 0
  while prefix < shorter && before_chars[prefix] == after_chars[prefix] {
    prefix = prefix + 1
  }
  let tail_before = before_length - prefix
  let tail_after = after_length - prefix
  let tail_limit = if tail_before < tail_after {
    tail_before
  } else {
    tail_after
  }
  let mut suffix = 0
  while suffix < tail_limit &&
        before_chars[before_length - suffix - 1] ==
        after_chars[after_length - suffix - 1] {
    suffix = suffix + 1
  }
  {
    start: prefix,
    removed: before_length - prefix - suffix,
    inserted: after_length - prefix - suffix,
  }
}

///|
/// Whether this edit has the one-character shape that may join a typing
/// group. Replacing a character is not a typing edit, and neither is
/// inserting or deleting a newline.
fn markdown_edit_is_single(
  before : String,
  after : String,
  delta : MarkdownEditDelta,
  kind : MarkdownEditKind,
) -> Bool {
  match kind {
    Insert =>
      delta.removed == 0 &&
      delta.inserted == 1 &&
      after.to_array()[delta.start] != '\n'
    Backspace | ForwardDelete =>
      delta.removed == 1 &&
      delta.inserted == 0 &&
      before.to_array()[delta.start] != '\n'
    Other => false
  }
}

///|
/// Caret immediately before the edit. A backspace removes the character to
/// the left of the caret, so the pre-edit caret sat one past the change.
fn markdown_edit_caret_before(
  kind : MarkdownEditKind,
  delta : MarkdownEditDelta,
) -> Int32 {
  match kind {
    Insert | ForwardDelete | Other => delta.start
    Backspace => delta.start + delta.removed
  }
}

///|
/// Caret immediately after the edit, at the end of whatever was inserted.
fn markdown_edit_caret_after(
  kind : MarkdownEditKind,
  delta : MarkdownEditDelta,
) -> Int32 {
  match kind {
    Insert | Other => delta.start + delta.inserted
    Backspace | ForwardDelete => delta.start
  }
}

///|
/// Where a following same-kind single edit has to start to stay in the open
/// group: one past an insertion, one before a backspace, the same spot for a
/// repeated forward delete.
fn markdown_edit_group_delta(kind : MarkdownEditKind) -> Int32 {
  match kind {
    Insert => 1
    Backspace => -1
    ForwardDelete | Other => 0
  }
}

///|
/// Record one completed edit. `before` must be the source the editor had
/// before the edit and `after` the source it has now; a call where both are
/// equal is a no-op that also closes the open group.
///
/// `selection_before` and `selection_after` are optional so existing callers
/// keep compiling; when given, `undo`/`redo` hand the matching selection back
/// in the outcome. A merged single-character group keeps the selection from
/// the first edit and the caret/selection from the last one.
pub fn MarkdownEditHistory::record(
  self : MarkdownEditHistory,
  before~ : String,
  after~ : String,
  kind~ : MarkdownEditKind,
  at_ms~ : Int64,
  selection_before~ : MarkdownEditorSelection? = None,
  selection_after~ : MarkdownEditorSelection? = None,
) -> Unit {
  if before == after {
    self.group = None
    return
  }
  let delta = markdown_edit_delta(before, after)
  let single = markdown_edit_is_single(before, after, delta, kind)
  let stack_length = self.undo.length()
  let continuous = stack_length > 0 &&
    self.undo[stack_length - 1].after == before
  let merges = match self.group {
    Some(group) =>
      single &&
      continuous &&
      group.kind == kind &&
      group.expected_stack_length == stack_length &&
      at_ms >= group.last_push_ms &&
      at_ms - group.last_push_ms <= markdown_edit_history_merge_window_ms &&
      delta.start == group.last_start + markdown_edit_group_delta(kind)
    None => false
  }
  if merges {
    let index = stack_length - 1
    let top = self.undo[index]
    self.undo[index] = {
      before: top.before,
      after,
      caret_before: top.caret_before,
      caret_after: markdown_edit_caret_after(kind, delta),
      selection_before: top.selection_before,
      selection_after,
    }
    match self.group {
      Some(group) => {
        group.last_start = delta.start
        group.last_push_ms = at_ms
      }
      None => ()
    }
    self.redo.clear()
    return
  }
  self.undo.push({
    before,
    after,
    caret_before: markdown_edit_caret_before(kind, delta),
    caret_after: markdown_edit_caret_after(kind, delta),
    selection_before,
    selection_after,
  })
  if self.undo.length() > markdown_edit_history_max_entries {
    let _ = self.undo.remove(0)
  }
  self.redo.clear()
  self.group = if single {
    Some({
      kind,
      last_start: delta.start,
      last_push_ms: at_ms,
      expected_stack_length: self.undo.length(),
    })
  } else {
    None
  }
}

///|
/// Step back one undo entry. Returns `None` when there is nothing to undo
/// or when `source` no longer matches the entry's post-edit text, which can
/// only happen when the document moved outside this history.
pub fn MarkdownEditHistory::undo(
  self : MarkdownEditHistory,
  source~ : String,
) -> MarkdownEditOutcome? {
  let length = self.undo.length()
  if length == 0 {
    return None
  }
  let entry = self.undo[length - 1]
  if entry.after != source {
    return None
  }
  let _ = self.undo.pop()
  self.redo.push(entry)
  self.group = None
  Some({
    source: entry.before,
    caret: entry.caret_before,
    selection: entry.selection_before,
  })
}

///|
/// Step forward one undone entry, under the same source check as `undo`.
pub fn MarkdownEditHistory::redo(
  self : MarkdownEditHistory,
  source~ : String,
) -> MarkdownEditOutcome? {
  let length = self.redo.length()
  if length == 0 {
    return None
  }
  let entry = self.redo[length - 1]
  if entry.before != source {
    return None
  }
  let _ = self.redo.pop()
  self.undo.push(entry)
  self.group = None
  Some({
    source: entry.after,
    caret: entry.caret_after,
    selection: entry.selection_after,
  })
}

///|
pub fn MarkdownEditHistory::can_undo(self : MarkdownEditHistory) -> Bool {
  self.undo.length() > 0
}

///|
pub fn MarkdownEditHistory::can_redo(self : MarkdownEditHistory) -> Bool {
  self.redo.length() > 0
}

///|
/// Drop the whole history and the open group.
pub fn MarkdownEditHistory::clear(self : MarkdownEditHistory) -> Unit {
  self.undo.clear()
  self.redo.clear()
  self.group = None
}
