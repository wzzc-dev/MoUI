///|
/// The retained element caches the previous side of the declaration diff so a
/// reconcile stops re-encoding canonical keys for a node it already holds.
/// These cases drive `reconcile_element_for_runtime` itself: dropping the
/// cache assignment in the reconcile path fails them, while calling the
/// dirty-kind helper directly would not.

///|
fn declaration_cache_probe(kind~ : String, token~ : String) -> &RuntimeViewNode {
  adapt_view_for_runtime(
    runtime_state_probe_view(kind~, declaration_token=token),
    _message => (),
  )
}

///|
test "mount leaves the declaration cache empty" {
  let mounted = mount_runtime_view_node_with_next(
    declaration_cache_probe(kind="probe", token="one"),
    1,
  )
  assert_true(mounted.node.declaration_cache is None)
}

///|
test "reconcile caches the declaration of the view node it retains" {
  let mounted = mount_runtime_view_node_with_next(
    declaration_cache_probe(kind="probe", token="one"),
    1,
  )
  let reconciled = reconcile_element_for_runtime(
    mounted.node,
    declaration_cache_probe(kind="probe", token="one"),
    None,
    mounted.next_id,
  )
  match reconciled.node.declaration_cache {
    Some(cached) =>
      assert_true(cached == reconciled.node.view_node.declaration())
    None => assert_true(false)
  }
  // An unchanged token must still read as clean through the cached side.
  assert_false(reconciled.dirty_kind.layout)
  assert_false(reconciled.dirty_kind.paint)
}

///|
test "declaration cache advances so a later change is still detected" {
  let mounted = mount_runtime_view_node_with_next(
    declaration_cache_probe(kind="probe", token="one"),
    1,
  )
  let second = reconcile_element_for_runtime(
    mounted.node,
    declaration_cache_probe(kind="probe", token="two"),
    None,
    mounted.next_id,
  )
  assert_true(second.dirty_kind.layout)
  let third = reconcile_element_for_runtime(
    second.node,
    declaration_cache_probe(kind="probe", token="three"),
    None,
    second.next_id,
  )
  // A cache stuck on the first declaration would report this as changed too,
  // so also assert the cached value tracks the newest node.
  assert_true(third.dirty_kind.layout)
  match third.node.declaration_cache {
    Some(cached) => assert_true(cached == third.node.view_node.declaration())
    None => assert_true(false)
  }
  let fourth = reconcile_element_for_runtime(
    third.node,
    declaration_cache_probe(kind="probe", token="three"),
    None,
    third.next_id,
  )
  // Re-serving the same token must be clean: a cache that never advanced past
  // "one" would keep reporting a change here.
  assert_false(fourth.dirty_kind.layout)
  assert_false(fourth.dirty_kind.paint)
}

///|
test "cached and uncached reconcile agree on the dirty kind" {
  let current = declaration_cache_probe(kind="probe", token="one")
  let next = declaration_cache_probe(kind="probe", token="two")
  let (uncached, _) = runtime_view_node_reconcile_dirty_kind(
    current,
    next,
    None,
  )
  let (cached, _) = runtime_view_node_reconcile_dirty_kind(
    current,
    next,
    Some(current.declaration()),
  )
  assert_eq(cached.layout, uncached.layout)
  assert_eq(cached.paint, uncached.paint)
  assert_eq(cached.semantics, uncached.semantics)
  assert_eq(cached.platform, uncached.platform)
}
