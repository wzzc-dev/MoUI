///|
fn workflow_test_lifecycle() -> @window_lifecycle.WindowLifecycle {
  @window_lifecycle.WindowLifecycle::new(
    requests=@window_lifecycle.WindowRequestQueue::new().requests(),
    scene_resolver=@runtime.WindowSceneResolver::unavailable(),
  )
}

///|
fn workflow_open_window(
  lifecycle : @window_lifecycle.WindowLifecycle,
  title : String,
) -> @backend_host.WindowId {
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let id = lifecycle.window_registry().open(title~, metrics~)
  let record = match lifecycle.window_registry().lookup(id) {
    Some(record) => record
    None => abort("test window must be registered")
  }
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=metrics.logical_size,
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  if !lifecycle.register_runtime_slot(
      @window_lifecycle.WindowRuntimeSlot::from_driver(record~, driver~),
    ) {
    abort("test runtime slot must be registered")
  }
  id
}

///|
fn workflow_test_actions(
  trace : Array[String],
) -> @window_lifecycle.WindowSurfaceActions {
  @window_lifecycle.WindowSurfaceActions::new(
    focus=() => (),
    request_resize=metrics => metrics,
    sync_observed_resize=metrics => metrics,
    set_minimized=_ => (),
    set_visible=_ => (),
    request_redraw=() => (),
    request_ime_update=_ => (),
    drop=() => trace.push("native-surface"),
    native_view_handle=() => None,
    dispose_platform_views=() => trace.push("platform-views"),
  )
}

///|
fn workflow_test_renderer(
  trace : Array[String],
  with_image? : Bool = false,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    image_records=() => if with_image {
      [@render.ImageResourceRecord::loading("asset.png")]
    } else {
      []
    },
    apply_image_load_completion=_ => true,
    image_decoder=if with_image {
      Some(
        @render.RendererImageDecoder::new(decode=(source, _bytes) => {
          @render.ImageResourceLoadCompletion::ready(source, width=1, height=1)
        }),
      )
    } else {
      None
    },
    dispose=() => trace.push("renderer"),
  )
}

///|
test "duplicate window attach disposes only the rejected renderer session" {
  let lifecycle = workflow_test_lifecycle()
  let frames = @window_frame.WindowFrameStates::new()
  let images = @window_image.WindowImageTaskStates::new()
  let id = workflow_open_window(lifecycle, "main")
  let accepted_trace : Array[String] = []
  let rejected_trace : Array[String] = []
  assert_true(
    attach_window_surface(
      lifecycle,
      frames,
      images,
      id,
      workflow_test_renderer(accepted_trace),
      workflow_test_actions(accepted_trace),
    ),
  )
  assert_false(
    attach_window_surface(
      lifecycle,
      frames,
      images,
      id,
      workflow_test_renderer(rejected_trace),
      workflow_test_actions(rejected_trace),
    ),
  )
  assert_eq(accepted_trace, [])
  assert_eq(rejected_trace, ["renderer"])
  inspect(frames.count(), content="1")
  inspect(images.count(), content="1")
}

///|
test "last window close follows owner teardown order exactly once" {
  let lifecycle = workflow_test_lifecycle()
  let frames = @window_frame.WindowFrameStates::new()
  let images = @window_image.WindowImageTaskStates::new()
  let trace : Array[String] = []
  let renderer = workflow_test_renderer(trace, with_image=true)
  let starter = @window_image.WindowImageTaskStarter::new(
    start=(_request, _complete) => Some(() => trace.push("image-cancel")),
  )
  let services = @window_services.WindowServiceState::new(
    bridge=@backend_host.HostServiceBridge::unavailable(),
    dispose=() => trace.push("services"),
  )
  let id = workflow_open_window(lifecycle, "main")
  assert_true(
    attach_window_surface(
      lifecycle,
      frames,
      images,
      id,
      renderer,
      workflow_test_actions(trace),
      image_task_starter=starter,
    ),
  )
  ignore(
    run_window_redraw(
      lifecycle,
      frames,
      images,
      @window_input.WindowInputState::new(),
      id,
      render=(renderer, _slot, submission) => renderer.render_frame(submission),
    ),
  )
  trace.clear()
  dispose_window(lifecycle, frames, images, services, id)
  dispose_window(lifecycle, frames, images, services, id)
  assert_eq(trace, [
    "image-cancel", "services", "renderer", "platform-views", "native-surface",
  ])
  assert_false(services.is_open())
  assert_true(lifecycle.runtime_slots_empty())
  inspect(frames.count(), content="0")
  inspect(images.count(), content="0")
}

///|
test "closing one of two windows preserves the other owners and services" {
  let lifecycle = workflow_test_lifecycle()
  let frames = @window_frame.WindowFrameStates::new()
  let images = @window_image.WindowImageTaskStates::new()
  let services = @window_services.WindowServiceState::new(
    bridge=@backend_host.HostServiceBridge::unavailable(),
  )
  let first = workflow_open_window(lifecycle, "first")
  let second = workflow_open_window(lifecycle, "second")
  let first_trace : Array[String] = []
  let second_trace : Array[String] = []
  assert_true(
    attach_window_surface(
      lifecycle,
      frames,
      images,
      first,
      workflow_test_renderer(first_trace),
      workflow_test_actions(first_trace),
    ),
  )
  assert_true(
    attach_window_surface(
      lifecycle,
      frames,
      images,
      second,
      workflow_test_renderer(second_trace),
      workflow_test_actions(second_trace),
    ),
  )
  dispose_window(lifecycle, frames, images, services, first)
  assert_true(services.is_open())
  inspect(frames.count(), content="1")
  inspect(images.count(), content="1")
  assert_true(frames.lookup(second) is Some(_))
  assert_eq(second_trace, [])
}
