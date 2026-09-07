///|
/// End-to-end sequence walk of the fixed close order from
/// `docs/platform-host-contract.md` (open → present → detach → close), with
/// adverse interleavings folded in: duplicate attach, duplicate/stale
/// dispose, shared-services teardown on the last window, and cross-window
/// isolation. Complements the per-owner unit tests by asserting the whole
/// walk against one ordered trace.
test "window host sequence: open, present, close with stale and cross-window interleavings" {
  let lifecycle = workflow_test_lifecycle()
  let frames = @window_frame.WindowFrameStates::new()
  let images = @window_image.WindowImageTaskStates::new()
  let trace : Array[String] = []
  let services = @window_services.WindowServiceState::new(
    bridge=@backend_host.HostServiceBridge::unavailable(),
    dispose=() => trace.push("services"),
  )

  // open
  let first = workflow_open_window(lifecycle, "first")
  let second = workflow_open_window(lifecycle, "second")

  // attach: both accepted; a duplicate attach on second is rejected and
  // disposes only the rejected renderer session.
  let starter = @window_image.WindowImageTaskStarter::new(start=(
    _request,
    _complete,
  ) => Some(() => trace.push("image-cancel")))
  assert_true(
    attach_window_surface(
      lifecycle,
      frames,
      images,
      first,
      workflow_test_renderer(trace, with_image=true),
      workflow_test_actions(trace),
      image_task_starter=starter,
    ),
  )
  assert_true(
    attach_window_surface(
      lifecycle,
      frames,
      images,
      second,
      workflow_test_renderer(trace),
      workflow_test_actions(trace),
    ),
  )
  assert_false(
    attach_window_surface(
      lifecycle,
      frames,
      images,
      second,
      workflow_test_renderer(trace),
      workflow_test_actions(trace),
    ),
  )
  assert_eq(trace, ["renderer"])
  inspect(frames.count(), content="2")

  // present
  ignore(
    run_window_redraw(
      lifecycle,
      frames,
      images,
      @window_input.WindowInputState::new(),
      first,
      render=(renderer, _slot, submission) => renderer.render_frame(submission),
    ),
  )
  assert_eq(trace, ["renderer"])

  // close (first): teardown follows the owner order exactly once; duplicate
  // dispose calls are no-ops. The shared services stay open (second lives).
  dispose_window(lifecycle, frames, images, services, first)
  dispose_window(lifecycle, frames, images, services, first)
  assert_eq(trace, [
    "renderer", "image-cancel", "renderer", "platform-views", "native-surface",
  ])
  // present after dispose is a no-op (stale completion at workflow level).
  ignore(
    run_window_redraw(
      lifecycle,
      frames,
      images,
      @window_input.WindowInputState::new(),
      first,
      render=(renderer, _slot, submission) => renderer.render_frame(submission),
    ),
  )
  assert_eq(trace, [
    "renderer", "image-cancel", "renderer", "platform-views", "native-surface",
  ])

  // cross-window isolation: second keeps its owners and the shared services.
  assert_true(lifecycle.window_registry().lookup(first) is None)
  assert_true(lifecycle.window_registry().lookup(second) is Some(_))
  inspect(frames.count(), content="1")
  inspect(images.count(), content="1")

  // close (second, last window): shared services dispose before the renderer
  // session, per the contract order.
  dispose_window(lifecycle, frames, images, services, second)
  assert_eq(trace, [
    "renderer", "image-cancel", "renderer", "platform-views", "native-surface", "services",
    "renderer", "platform-views", "native-surface",
  ])
  assert_false(services.is_open())
  assert_true(lifecycle.runtime_slots_empty())
  inspect(frames.count(), content="0")
  inspect(images.count(), content="0")
}
