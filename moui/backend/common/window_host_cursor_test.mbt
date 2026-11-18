///|
/// Host-workflow coverage for cursor projection: the runtime resolves a style,
/// `sync_pointer_cursor` pushes it to the surface exactly once, and the three
/// reset paths (leave, unmount, focus loss) reach the host.

///|
fn cursor_workflow_runtime_resize() -> @apphost.AppRuntime {
  let root : @core.View[Unit] = (@views.empty() : @core.View[Unit]).cursor(
    @core.CursorStyle::Icon(@core.CursorIcon::CursorColResize),
  )
  @apphost.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )
}

///|
fn cursor_workflow_actions(
  trace : Array[String],
) -> @window_lifecycle.WindowSurfaceActions {
  @window_lifecycle.WindowSurfaceActions::new(
    focus=() => (),
    request_resize=metrics => metrics,
    sync_observed_resize=metrics => metrics,
    set_minimized=_ => (),
    set_visible=_ => (),
    set_maximized=_ => (),
    set_fullscreen=_ => (),
    set_decorations=_ => (),
    set_cursor=icon => {
      trace.push(
        match icon {
          @core.CursorIcon::CursorColResize => "cursor:col-resize"
          @core.CursorIcon::CursorDefault => "cursor:default"
          _ => "cursor:other"
        },
      )
    },
    request_redraw=() => (),
    request_ime_update=_ => (),
    drop=() => (),
    native_view_handle=() => None,
    dispose_platform_views=() => (),
  )
}

///|
/// A window whose runtime declares a resize cursor, with its surface attached.
fn cursor_workflow_open(
  lifecycle : @window_lifecycle.WindowLifecycle,
  trace : Array[String],
) -> @backend_host.WindowId {
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=300.0, height=40.0),
  )
  let id = lifecycle.window_registry().open(title="cursor", metrics~)
  let record = match lifecycle.window_registry().lookup(id) {
    Some(record) => record
    None => abort("cursor test window must be registered")
  }
  let runtime = cursor_workflow_runtime_resize()
  // One pointer sample puts the pointer inside the declaring region.
  ignore(
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=Move,
        ),
      ),
    ),
  )
  let driver = @apphost.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  ignore(
    lifecycle.register_runtime_slot(
      @window_lifecycle.WindowRuntimeSlot::from_driver(record~, driver~),
    ),
  )
  ignore(lifecycle.attach_surface(id, cursor_workflow_actions(trace)))
  id
}

///|
test "cursor projection pushes once per change and resets on focus loss" {
  let lifecycle = workflow_test_lifecycle()
  let trace : Array[String] = []
  let id = cursor_workflow_open(lifecycle, trace)
  let input = @window_input.WindowInputState::new()
  let services = @window_services.WindowServiceState::new(
    bridge=@backend_host.HostServiceBridge::unavailable(),
  )

  @common.sync_pointer_cursor(lifecycle, input, id)
  assert_eq(trace, ["cursor:col-resize"])
  // A resting pointer over the same declaration must not touch the native
  // cursor again.
  @common.sync_pointer_cursor(lifecycle, input, id)
  @common.sync_pointer_cursor(lifecycle, input, id)
  assert_eq(trace, ["cursor:col-resize"])

  // A focus loss is the reset case the runtime cannot resolve to `Default` on
  // its own: the pointer may still be inside the region.
  @common.dispatch_host_event(
    lifecycle,
    input,
    services,
    id,
    Focus(@backend_host.HostFocusEvent::{
      focused: false,
      pointer_cancel_position: None,
    }),
    adjust=event => Some(event),
  )
  assert_eq(trace, ["cursor:col-resize", "cursor:default"])
  assert_eq(input.applied_cursor(id), @core.CursorStyle::Default)

  // Gaining focus again re-resolves the declaration under the pointer.
  @common.dispatch_host_event(
    lifecycle,
    input,
    services,
    id,
    Focus(@backend_host.HostFocusEvent::{
      focused: true,
      pointer_cancel_position: None,
    }),
    adjust=event => Some(event),
  )
  assert_eq(trace, ["cursor:col-resize", "cursor:default", "cursor:col-resize"])
}

///|
test "cursor projection resets when the pointer leaves the window" {
  let lifecycle = workflow_test_lifecycle()
  let trace : Array[String] = []
  let id = cursor_workflow_open(lifecycle, trace)
  let input = @window_input.WindowInputState::new()
  let services = @window_services.WindowServiceState::new(
    bridge=@backend_host.HostServiceBridge::unavailable(),
  )
  @common.sync_pointer_cursor(lifecycle, input, id)
  assert_eq(trace, ["cursor:col-resize"])

  // The host emits a synthetic leave; the runtime clears its last pointer
  // sample and resolves to the arrow.
  @common.dispatch_host_event(
    lifecycle,
    input,
    services,
    id,
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=310.0, y=10.0),
        phase=Exit,
      ),
    ),
    adjust=event => Some(event),
  )
  assert_eq(trace, ["cursor:col-resize", "cursor:default"])
}

///|
test "cursor projection ignores unrelated host events" {
  let lifecycle = workflow_test_lifecycle()
  let trace : Array[String] = []
  let id = cursor_workflow_open(lifecycle, trace)
  let input = @window_input.WindowInputState::new()
  let services = @window_services.WindowServiceState::new(
    bridge=@backend_host.HostServiceBridge::unavailable(),
  )
  @common.sync_pointer_cursor(lifecycle, input, id)
  assert_eq(trace, ["cursor:col-resize"])

  // Resize and redraw frames leave the hit chain alone, so they must not walk
  // the tree or touch the cursor.
  @common.dispatch_host_event(
    lifecycle,
    input,
    services,
    id,
    Resized(
      @core.SurfaceMetrics::from_logical(
        size=@core.Size::new(width=320.0, height=40.0),
      ),
    ),
    adjust=event => Some(event),
  )
  assert_eq(trace, ["cursor:col-resize"])
}
