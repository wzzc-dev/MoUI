///|
test "gesture arena keeps candidates and ownership per pointer id" {
  let arena = PointerGestureArena::new()
  let first = ElementId::new(1)
  let second = ElementId::new(2)
  arena.begin(0, [first, second])
  arena.begin(1, [second])
  assert_eq(arena.candidate_ids(0), [first, second])
  assert_eq(arena.candidate_ids(1), [second])
  assert_true(arena.has_stream(0))
  assert_true(arena.has_stream(1))
  assert_true(arena.claim(0, first))
  assert_false(arena.claim(0, second))
  assert_eq(arena.owner(0), Some(first))
  assert_eq(arena.owner(1), None)
  arena.end(0)
  assert_false(arena.has_stream(0))
  assert_eq(arena.owner(1), None)
  assert_eq(arena.candidate_ids(1), [second])
}

///|
test "gesture arena drops streams whose tracked elements left the tree" {
  let arena = PointerGestureArena::new()
  let live = ElementId::new(1)
  let removed = ElementId::new(2)
  arena.begin(0, [live, removed])
  assert_true(arena.claim(0, live))
  arena.begin(1, [removed])
  assert_true(arena.claim(1, removed))
  arena.begin(2, [live, removed])
  arena.clear_missing(id => id == live)
  assert_true(arena.has_stream(0))
  assert_eq(arena.owner(0), Some(live))
  assert_false(arena.has_stream(1))
  // A partly stale candidate list keeps only ids that still exist.
  assert_true(arena.has_stream(2))
  assert_eq(arena.candidate_ids(2), [live])
}
