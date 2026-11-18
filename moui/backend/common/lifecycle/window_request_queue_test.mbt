///|
test "effective_window_requests substitutes the fallback for an unwired port" {
  let fallback_queue = @lifecycle.WindowRequestQueue::new()
  let effective = @lifecycle.effective_window_requests(
    @backend_host.WindowRequests::unavailable(),
    fallback_queue.requests(),
  )
  assert_false(effective.is_unavailable())
  // The fallback keeps working as a queue: pushes become drainable.
  effective.push(@backend_host.MaximizeWindow(@backend_host.WindowId::new(7)))
  assert_true(fallback_queue.requests().drain().length() == 1)
}

///|
test "effective_window_requests keeps a wired port" {
  let wired_queue = @lifecycle.WindowRequestQueue::new()
  let fallback_queue = @lifecycle.WindowRequestQueue::new()
  let effective = @lifecycle.effective_window_requests(
    wired_queue.requests(),
    fallback_queue.requests(),
  )
  assert_false(effective.is_unavailable())
  effective.push(@backend_host.CloseWindow(@backend_host.WindowId::new(9)))
  assert_true(wired_queue.requests().drain().length() == 1)
  assert_true(fallback_queue.requests().drain().length() == 0)
}
