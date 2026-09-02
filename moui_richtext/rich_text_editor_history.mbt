///|
/// Undo-history merge window for the rich-text editors.
///
/// Every accepted text edit used to push one undo entry, so undoing a
/// typed word took as many presses as it took to type. Consecutive
/// single-character edits of the same kind at contiguous positions keep
/// the current undo group open instead: the group's original pre-edit
/// entry already covers them, so one undo reverts the whole run.
/// Multi-character edits (pastes, IME commits), newline insertions,
/// edits behind an active selection, and edits after a history restore
/// always start a fresh group.
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
/// Classify an accepted edit as a single-character text change, or
/// `None` when it is anything else. Kinds: `1` inserts at `start`
/// (caret typed just before it), `2` backspaces the character at
/// `start` (caret sat right after it), `3` forward-deletes the
/// character at `start`. Newline changes never merge, so they report
/// `None` and force their own undo entry.
fn rich_text_history_single_edit(
  previous : String,
  next : String,
  caret : Int,
  selection_active~ : Bool,
) -> (Int, Int)? {
  if selection_active {
    return None
  }
  let before = previous.to_array()
  let after = next.to_array()
  let before_length = before.length()
  let after_length = after.length()
  if before_length + 1 == after_length {
    let mut index = 0
    while index < before_length && before[index] == after[index] {
      index = index + 1
    }
    if after[index] == '\n' || caret != index {
      return None
    }
    return Some((1, index))
  }
  if after_length + 1 == before_length {
    let mut index = 0
    while index < after_length && before[index] == after[index] {
      index = index + 1
    }
    if before[index] == '\n' {
      return None
    }
    if caret == index + 1 {
      return Some((2, index))
    }
    if caret == index {
      return Some((3, index))
    }
    return None
  }
  None
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
/// Decide whether an accepted edit should push a new undo entry,
/// updating the open-group bookkeeping either way. Returning `false`
/// means the edit is covered by the group entry already on the undo
/// stack, so the caller must not push. The group is identified by its
/// expected stack length and running text length, so an undo, redo, or
/// foreign edit in between breaks the merge even without an explicit
/// reset.
fn rich_text_history_record_edit(
  control : @core.TextControlStateContext,
  previous : String,
  next : String,
  caret : Int,
) -> Bool {
  let now = rich_text_history_now_ms()
  let selection_active = @core.active_text_selection(control.selection)
    is Some(_)
  let edit_shape = rich_text_history_single_edit(
    previous,
    next,
    caret,
    selection_active~,
  )
  let state = rich_text_history_group.val
  let stack_length = control.undo_stack.length()
  let merges = match edit_shape {
    Some((kind, start)) =>
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
      Some((_, start)) => state.start = start
      None => ()
    }
    state.after_length = text_length(next)
    state.last_push_ms = now
    return false
  }
  match edit_shape {
    Some((kind, start)) => {
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
  return true
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
