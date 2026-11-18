///|
/// Host workflow for issue #24: app window-control intents become logical
/// `WindowRequest`s, and the lifecycle record's maximize/fullscreen state is
/// mirrored back so app-drawn chrome repaints from what the platform was asked
/// for.

///|
fn window_control_test_metrics() -> @core.SurfaceMetrics {
  @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=240.0),
  )
}

///|
test "window control intents become logical window requests" {
  let lifecycle = workflow_test_lifecycle()
  let id = lifecycle
    .window_registry()
    .open(title="controls", metrics=window_control_test_metrics())
  let source = @services.WindowControlSource::new()
  source.set_capabilities(@services.WindowControlCapabilities::all())
  // The lifecycle has no active runtime slot here, so drive the drain helper
  // through the registry-backed request path instead: intent → request.
  let requests : Array[@backend_host.WindowRequest] = []
  source.maximize()
  source.toggle_fullscreen()
  source.set_decorations(false)
  @common.apply_window_control_requests(source, lifecycle, id)
  lifecycle.drain_window_requests(request => {
    requests.push(request)
    @backend_host.WindowRequestResult::WindowUpdated(id)
  })
  assert_eq(requests, [
    @backend_host.WindowRequest::MaximizeWindow(id),
    @backend_host.WindowRequest::SetFullscreenWindow(id, true),
    @backend_host.WindowRequest::SetDecorationsWindow(id, false),
  ])
}

///|
test "window control requests update the observed window record" {
  let lifecycle = workflow_test_lifecycle()
  let id = lifecycle
    .window_registry()
    .open(title="record", metrics=window_control_test_metrics())
  let apply = request => {
    ignore(lifecycle.window_registry().apply_request(request))
  }
  let record = () => lifecycle.window_registry().lookup(id)

  apply(@backend_host.WindowRequest::MaximizeWindow(id))
  assert_true(record().unwrap().maximized)
  assert_false(record().unwrap().fullscreen)

  // Entering fullscreen implies "not maximized" for chrome purposes.
  apply(@backend_host.WindowRequest::SetFullscreenWindow(id, true))
  assert_true(record().unwrap().fullscreen)
  assert_false(record().unwrap().maximized)

  // Restore clears both.
  apply(@backend_host.WindowRequest::RestoreWindow(id))
  assert_false(record().unwrap().maximized)
  assert_false(record().unwrap().fullscreen)
}

///|
test "window control source mirrors the lifecycle record" {
  let lifecycle = workflow_test_lifecycle()
  let id = workflow_open_window(lifecycle, "mirror")
  let source = @services.WindowControlSource::new()
  @common.sync_window_controls(
    Some(source),
    lifecycle,
    @services.WindowControlCapabilities::all(),
  )
  assert_eq(source.capabilities(), @services.WindowControlCapabilities::all())
  assert_false(source.maximized())

  ignore(
    lifecycle
    .window_registry()
    .apply_request(@backend_host.WindowRequest::MaximizeWindow(id)),
  )
  @common.sync_window_controls(
    Some(source),
    lifecycle,
    @services.WindowControlCapabilities::all(),
  )
  assert_true(source.maximized())
}

///|
test "unhosted window control source never reaches a request queue" {
  let lifecycle = workflow_test_lifecycle()
  let id = workflow_open_window(lifecycle, "unhosted")
  let source = @services.WindowControlSource::unavailable()
  source.maximize()
  @common.sync_window_controls(
    Some(source),
    lifecycle,
    @services.WindowControlCapabilities::none(),
  )
  let requests : Array[@backend_host.WindowRequest] = []
  lifecycle.drain_window_requests(request => {
    requests.push(request)
    @backend_host.WindowRequestResult::WindowUpdated(id)
  })
  assert_true(requests.is_empty())
  assert_true(id == id)
}
