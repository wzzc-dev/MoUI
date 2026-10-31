///|
/// C1 (plan hot-path-invalidation-boilerplate-convergence): interned
/// environment identities are content-stable and monotonic — equal
/// environments share an id, a changed environment gets a fresh id, and ids
/// are never reused.
test "environment identity is content-stable and monotonic" {
  let neutral = @core.Environment::neutral()
  let scaled = neutral.with_text_scale(1.25)
  let a = environment_identity(neutral)
  assert_true(a == environment_identity(@core.Environment::neutral()))
  let c = environment_identity(scaled)
  assert_true(c != a)
  assert_true(c == environment_identity(scaled))
}

///|
/// C1: measure/place cache checks compare the interned environment identity —
/// the same environment hits, a changed environment misses (global
/// invalidation), and the changed environment re-hits on the next pass.
test "layout cache keys on interned environment identity" {
  let app = AppRuntime::new_view(
    root=runtime_state_probe_view(kind="env-identity", declaration_token="one"),
    size=@core.Size::new(width=40.0, height=20.0),
  )
  ignore(app.layout())
  let root = app.state.element_tree.root
  let hits_before = root.layout_cache.hit_count
  let misses_before = root.layout_cache.miss_count
  // Same environment: the measure/place caches hit by identity.
  app.state.layout_current_tree()
  assert_true(root.layout_cache.hit_count > hits_before)
  assert_true(root.layout_cache.miss_count == misses_before)
  // A changed environment invalidates globally and misses.
  app.set_environment(@core.Environment::neutral().with_text_scale(1.25))
  app.state.layout_current_tree()
  assert_true(root.layout_cache.miss_count > misses_before)
  // The changed environment is stable: its identity re-hits.
  let misses_mid = root.layout_cache.miss_count
  app.state.layout_current_tree()
  assert_true(root.layout_cache.miss_count == misses_mid)
}
