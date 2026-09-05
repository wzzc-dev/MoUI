///|
/// Undo-history merge window for the rich-text editors.
///
/// Consecutive single-character edits of the same kind at contiguous
/// positions keep the current undo group open: instead of skipping the
/// push and trusting the group's first entry to cover them, the merge
/// rewrites the stack-top delta so one undo still reverts the whole
/// run. Multi-character edits (pastes, IME commits), newline
/// insertions, edits behind an active selection, and edits after a
/// history restore always start a fresh group.
priv struct RichTextHistoryGroupState {
  mut kind : Int
  mut start : Int
  mut after_length : Int
  mut last_push_ms : Int
  mut expected_stack_length : Int
}

///|
let rich_text_history_group : Ref[RichTextHistoryGroupState] = Ref({
  kind: 0,
  start: -1,
  after_length: -1,
  last_push_ms: -1,
  expected_stack_length: -1,
})

///|
/// Optional fake millisecond clock for the merge window. A negative
/// value falls back to the real wall clock; tests install a fake tick
/// so grouping never depends on wall time.
let rich_text_history_fake_clock_ms : Ref[Int] = Ref(-1)

///|
fn rich_text_history_now_ms() -> Int {
  let fake = rich_text_history_fake_clock_ms.val
  if fake >= 0 {
    fake
  } else {
    @env.now().to_int()
  }
}

///|
/// Consecutive edits landing within this many milliseconds of each
/// other extend the open undo group.
let rich_text_history_merge_window_ms : Int = 500

///|
/// What the caller must do with the undo stack for an accepted edit:
/// push a fresh entry, or merge — rewriting the stack-top delta with
/// `kind` and the single affected character (kind `1` appends it to
/// `after`, kinds `2`/`3` extend `before`, backspace at the group's
/// left edge also shifts `start`).
priv enum RichTextHistoryAction {
  PushHistory
  MergeHistory(Int, Char)
}

///|
/// Classify an accepted edit as a single-character text change, or
/// `None` when it is anything else. Kinds: `1` inserts `character` at
/// `start` (caret typed just before it), `2` backspaces `character` at
/// `start` (caret sat right after it), `3` forward-deletes `character`
/// at `start`. Newline changes never merge, so they report `None` and
/// force their own undo entry.
fn rich_text_history_single_edit(
  previous : String,
  next : String,
  caret : Int,
  selection_active~ : Bool,
) -> (Int, Int, Char)? {
  if selection_active {
    return None
  }
  // Codepoint-length gate plus an allocation-free aligned scan: while the
  // two documents agree their UTF-16 offsets advance in lockstep, so the
  // first divergence is the edit point and its character is one
  // `get_char` away. No char-array copy of either document.
  let before_length = text_length(previous)
  let after_length = text_length(next)
  let before_units = previous.length()
  let next_units = next.length()
  if before_length + 1 == after_length {
    let mut index = 0
    let mut offset = 0
    while index < before_length &&
          offset < before_units &&
          previous.get_char(offset) == next.get_char(offset) {
      match previous.get_char(offset) {
        Some(ch) => {
          offset = offset + ch.utf16_len()
          index = index + 1
        }
        None => break
      }
    }
    match next.get_char(offset) {
      Some(inserted) =>
        if inserted == '\n' || caret != index {
          None
        } else {
          Some((1, index, inserted))
        }
      None => None
    }
  } else if after_length + 1 == before_length {
    let mut index = 0
    let mut offset = 0
    while index < after_length &&
          offset < next_units &&
          previous.get_char(offset) == next.get_char(offset) {
      match next.get_char(offset) {
        Some(ch) => {
          offset = offset + ch.utf16_len()
          index = index + 1
        }
        None => break
      }
    }
    match previous.get_char(offset) {
      Some(deleted) =>
        if deleted == '\n' {
          None
        } else if caret == index + 1 {
          Some((2, index, deleted))
        } else if caret == index {
          Some((3, index, deleted))
        } else {
          None
        }
      None => None
    }
  } else {
    None
  }
}

///|
/// Position the next same-kind edit must land on to stay in the open
/// group: one past the previous insertion, one before the previous
/// backspace, or the same spot for a repeated forward delete.
fn rich_text_history_group_delta(kind : Int) -> Int {
  if kind == 1 {
    1
  } else if kind == 2 {
    -1
  } else {
    0
  }
}

///|
/// Decide what an accepted edit does to the undo stack, updating the
/// open-group bookkeeping either way. Merging requires the group's
/// kind, expected stack length, running text length, time window, and
/// contiguity to all line up, so an undo, redo, or foreign edit in
/// between breaks the merge even without an explicit reset.
fn rich_text_history_record_edit(
  control : @core.TextControlStateContext,
  previous : String,
  next : String,
  caret : Int,
  // Classification computed from the applied edit's known range. Absent
  // means "rescan the documents"; `Some(None)` means "known to be not a
  // single-character edit".
  shape? : ((Int, Int, Char)?)? = None,
) -> RichTextHistoryAction {
  let now = rich_text_history_now_ms()
  let selection_active = @core.active_text_selection(control.selection)
    is Some(_)
  let edit_shape = match shape {
    Some(known) => known
    None =>
      rich_text_history_single_edit(
        previous,
        next,
        caret,
        selection_active~,
      )
  }
  let state = rich_text_history_group.val
  let stack_length = control.undo_stack.length()
  let merges = match edit_shape {
    Some((kind, start, _)) =>
      state.kind == kind &&
      stack_length == state.expected_stack_length &&
      text_length(previous) == state.after_length &&
      state.last_push_ms >= 0 &&
      state.last_push_ms <= now &&
      now - state.last_push_ms <= rich_text_history_merge_window_ms &&
      start == state.start + rich_text_history_group_delta(kind)
    None => false
  }
  if merges {
    match edit_shape {
      Some((kind, start, character)) => {
        state.start = start
        state.after_length = text_length(next)
        state.last_push_ms = now
        MergeHistory(kind, character)
      }
      None => PushHistory
    }
  } else {
    match edit_shape {
      Some((kind, start, _)) => {
        state.kind = kind
        state.start = start
      }
      None => {
        state.kind = 0
        state.start = -1
      }
    }
    state.after_length = text_length(next)
    state.last_push_ms = now
    state.expected_stack_length = stack_length + 1
    PushHistory
  }
}

///|
/// Apply a history action to the undo stack the caller is building.
/// Merging rewrites the group's stack-top delta in place so the stack
/// keeps one entry per run while still describing the whole run
/// exactly. The merge guards guarantee a non-empty stack whose top is
/// the group entry; an empty stack defensively takes the fresh entry.
fn rich_text_history_extend_stack(
  undo_stack : Array[@core.TextHistoryEntryContext],
  action : RichTextHistoryAction,
  entry : @core.TextHistoryEntryContext,
) -> Unit {
  match action {
    PushHistory => undo_stack.push(entry)
    MergeHistory(kind, character) =>
      if undo_stack.is_empty() {
        undo_stack.push(entry)
      } else {
        let top_index = undo_stack.length() - 1
        let top = undo_stack[top_index]
        let character_text = character.to_string()
        undo_stack[top_index] = if kind == 1 {
          { ..top, after: top.after + character_text }
        } else if kind == 2 {
          { ..top, start: top.start - 1, before: character_text + top.before }
        } else {
          { ..top, before: top.before + character_text }
        }
      }
  }
}

///|
/// Forget the open undo group, so the next edit starts a new one.
/// Called after a history restore: undoing must not let the following
/// edit coalesce into the group that was just undone.
fn rich_text_history_reset_group() -> Unit {
  let state = rich_text_history_group.val
  state.kind = 0
  state.start = -1
  state.after_length = -1
  state.last_push_ms = -1
  state.expected_stack_length = -1
}
