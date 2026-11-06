///|
/// Gesture facts observed while dispatching one pointer event through a node.
///
/// A candidate armed on `Down` may receive later samples until an arena winner
/// is selected. A winner is the first recognizer that activates, or a scroll
/// view that changes its authoritative layout; once selected it owns the rest
/// of that pointer stream.
priv struct PointerGestureTrace {
  candidates : Array[ElementId]
  winner : ElementId?
}

///|
fn PointerGestureTrace::empty() -> PointerGestureTrace {
  { candidates: [], winner: None, }
}

///|
fn PointerGestureTrace::merge(
  first : PointerGestureTrace,
  second : PointerGestureTrace,
) -> PointerGestureTrace {
  let candidates = first.candidates.copy()
  for candidate in second.candidates {
    if !candidates.contains(candidate) {
      candidates.push(candidate)
    }
  }
  {
    candidates,
    winner: match first.winner {
      Some(winner) => Some(winner)
      None => second.winner
    },
  }
}

///|
fn pointer_gesture_trace(
  event : AppEvent,
  element_id : ElementId,
  outcome : RuntimeEventOutcome,
  slots_changed : Bool,
  text_control_changed : Bool,
  is_scroll_view : Bool,
) -> PointerGestureTrace {
  match event {
    Pointer(pointer) => {
      let armed = pointer.phase == Down &&
        (outcome.captured || slots_changed || text_control_changed)
      let winner = if pointer.phase == Down {
        None
      } else if outcome.activated {
        Some(element_id)
      } else if pointer.phase == Move &&
        is_scroll_view &&
        outcome.changed &&
        outcome.dirty == ViewLayoutDirty {
        Some(element_id)
      } else {
        None
      }
      { candidates: if armed { [element_id] } else { [] }, winner, }
    }
    _ => PointerGestureTrace::empty()
  }
}

///|
/// Per-pointer gesture ownership.
///
/// The arena is transient runtime input state, not component state. Pointer
/// ids are independent: a second finger can run its own recognizer without
/// stealing or cancelling the first stream. Candidates are recorded from the
/// `Down` traversal; the first winner owns later samples and every other
/// candidate is cancelled.
priv struct PointerGestureArena {
  candidates : Map[Int32, Array[ElementId]]
  owners : Map[Int32, ElementId]
}

///|
fn PointerGestureArena::new() -> PointerGestureArena {
  { candidates: Map([]), owners: Map([]), }
}

///|
fn PointerGestureArena::begin(
  self : PointerGestureArena,
  pointer_id : Int32,
  candidates : Array[ElementId],
) -> Unit {
  self.candidates[pointer_id] = candidates.copy()
  self.owners.remove(pointer_id)
}

///|
fn PointerGestureArena::has_stream(
  self : PointerGestureArena,
  pointer_id : Int32,
) -> Bool {
  self.candidates.contains(pointer_id) || self.owners.contains(pointer_id)
}

///|
fn PointerGestureArena::candidate_ids(
  self : PointerGestureArena,
  pointer_id : Int32,
) -> Array[ElementId] {
  match self.candidates.get(pointer_id) {
    Some(candidates) => candidates.copy()
    None => []
  }
}

///|
fn PointerGestureArena::owner(
  self : PointerGestureArena,
  pointer_id : Int32,
) -> ElementId? {
  self.owners.get(pointer_id)
}

///|
/// Record the first winner for a stream. Later results cannot replace it.
fn PointerGestureArena::claim(
  self : PointerGestureArena,
  pointer_id : Int32,
  winner : ElementId,
) -> Bool {
  match self.owners.get(pointer_id) {
    Some(_) => false
    None => {
      self.owners[pointer_id] = winner
      true
    }
  }
}

///|
fn PointerGestureArena::end(
  self : PointerGestureArena,
  pointer_id : Int32,
) -> Unit {
  self.candidates.remove(pointer_id)
  self.owners.remove(pointer_id)
}

///|
fn PointerGestureArena::clear(self : PointerGestureArena) -> Unit {
  self.candidates.clear()
  self.owners.clear()
}

///|
fn PointerGestureArena::clear_missing(
  self : PointerGestureArena,
  contains : (ElementId) -> Bool,
) -> Unit {
  for stream in self.owners.to_array() {
    let (pointer_id, owner) = stream
    if !contains(owner) {
      self.candidates.remove(pointer_id)
      self.owners.remove(pointer_id)
    }
  }
  for stream in self.candidates.to_array() {
    let (pointer_id, candidates) = stream
    let live_candidates = candidates.filter(candidate => contains(candidate))
    if live_candidates.is_empty() && !self.owners.contains(pointer_id) {
      self.candidates.remove(pointer_id)
      self.owners.remove(pointer_id)
    } else {
      self.candidates[pointer_id] = live_candidates
    }
  }
}
