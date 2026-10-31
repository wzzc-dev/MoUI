///|
/// Black-box coverage for the `ImageResourceLifecycle` generation
/// counter: it advances exactly when the record set actually changes,
/// which is what lets per-frame consumers skip re-scans.

///|
test "lifecycle generation advances only when records actually change" {
  let lifecycle = @common.ImageResourceLifecycle::new()
  assert_eq(lifecycle.generation(), 0L)
  assert_true(lifecycle.mark_loading("a.png"))
  let after_loading = lifecycle.generation()
  assert_true(after_loading > 0L)
  // Re-storing an identical record changes nothing and must not
  // advance the generation — consumers rely on that to skip re-scans.
  assert_false(lifecycle.mark_loading("a.png"))
  assert_eq(lifecycle.generation(), after_loading)
  assert_true(lifecycle.mark_ready("a.png", width=1, height=1))
  assert_true(lifecycle.generation() > after_loading)
  let after_ready = lifecycle.generation()
  // A completion for a record that is not loading mutates nothing.
  assert_false(
    lifecycle.apply_load_completion(
      @render.ImageResourceLoadCompletion::ready("a.png", width=2, height=2),
    ),
  )
  assert_eq(lifecycle.generation(), after_ready)
  assert_true(lifecycle.dispose("a.png"))
  let after_dispose = lifecycle.generation()
  assert_true(after_dispose > after_ready)
  // Evicting the disposed record advances the generation once; a
  // second eviction removes nothing and must not advance it.
  assert_eq(lifecycle.evict_disposed(), 1)
  let after_evict = lifecycle.generation()
  assert_true(after_evict > after_dispose)
  assert_eq(lifecycle.evict_disposed(), 0)
  assert_eq(lifecycle.generation(), after_evict)
  assert_true(lifecycle.lookup("a.png") is None)
}

///|
test "lifecycle generation tracks independent sources" {
  let lifecycle = @common.ImageResourceLifecycle::new()
  assert_true(lifecycle.mark_loading("a.png"))
  assert_true(lifecycle.mark_loading("b.png"))
  let after_both = lifecycle.generation()
  // Completing one source advances the generation and leaves the
  // other source untouched and still loading.
  assert_true(
    lifecycle.apply_load_completion(
      @render.ImageResourceLoadCompletion::ready("a.png", width=4, height=4),
    ),
  )
  assert_true(lifecycle.generation() > after_both)
  assert_true(
    lifecycle.lookup("b.png") is Some(record) && record.status is ImageLoading,
  )
  // Failure path advances it too.
  let before_failure = lifecycle.generation()
  assert_true(
    lifecycle.apply_load_completion(
      @render.ImageResourceLoadCompletion::failed(
        "b.png",
        diagnostic="decode error",
      ),
    ),
  )
  assert_true(lifecycle.generation() > before_failure)
  assert_true(
    lifecycle.lookup("b.png") is Some(record) && record.status is ImageFailed,
  )
}
