///|
test "harmonyos window-hosted host-sim creates session and presents" {
  let render_count = Ref(0)
  let dispose_count = Ref(0)
  let pointer_count = Ref(0)
  let binding = HarmonyOSSurfaceBinding::new(create_renderer=(
    _surface,
    _metrics,
  ) => {
    Some(
      @render.RendererSession::new(
        resize=_ => (),
        render_frame=_frame => {
          render_count.val = render_count.val + 1
          @render.RenderFrameResult::new(presented=true)
        },
        drain_events=Some(() => []),
        text_system=() => @core.TextSystem::fallback(),
        present_count=() => render_count.val,
        dispose=() => dispose_count.val = dispose_count.val + 1,
      ),
    )
  })
  let app = new_harmonyos_embedded_runtime(
    title="window-hosted-test",
    runtime_factory=metrics => {
      let runtime = @runtime.AppRuntime::new_view(
        root=(@views.empty() : @core.View[Unit]),
        size=metrics.logical_size,
      )
      runtime.set_event_observer(event => {
        match event {
          Pointer(_) => pointer_count.val = pointer_count.val + 1
          _ => ()
        }
      })
      runtime
    },
    surface_binding_factory=() => binding,
    auto_exit_after_frames=None,
  )
  harmonyos_window_hosted_pump_host_sim(app, surface_handle=0x55UL)
  assert_true(app.frames_presented() >= 1)
  assert_true(render_count.val >= 1)
  assert_true(app.surface_generation() > 0)
  assert_true(app.has_session())
  assert_false(app.session_attached())
  assert_true(pointer_count.val >= 2)
}

///|
test "accessibility pump records the published generation and keeps it across unchanged pumps" {
  if not(harmonyos_a11y_pump_enabled) {
    return
  }
  let binding = HarmonyOSSurfaceBinding::new(create_renderer=(
    _surface,
    _metrics,
  ) => {
    Some(
      @render.RendererSession::new(
        resize=_ => (),
        render_frame=_frame => @render.RenderFrameResult::new(presented=true),
        text_system=() => @core.TextSystem::fallback(),
      ),
    )
  })
  let app = new_harmonyos_embedded_runtime(
    title="a11y-cursor-test",
    runtime_factory=metrics => {
      @runtime.AppRuntime::new_view(
        root=(@views.empty() : @core.View[Unit]),
        size=metrics.logical_size,
      )
    },
    surface_binding_factory=() => binding,
    auto_exit_after_frames=None,
  )
  harmonyos_window_hosted_pump_host_sim(app, surface_handle=0x56UL)
  // The first pump publishes a full snapshot and records its generation.
  app.pump_accessibility()
  guard app.accessibility_cursor is Some(published) else {
    fail("expected the accessibility cursor to record the published generation")
  }
  // Nothing changed: the next pump reads back `Unchanged` and keeps the
  // cursor instead of projecting the tree again.
  app.pump_accessibility()
  guard app.accessibility_cursor is Some(after) else {
    fail("expected the accessibility cursor to survive an unchanged pump")
  }
  assert_true(after == published)
}

///|
test "wheel over scroll view dirties runtime and presents frames" {
  let scroll_messages = Ref(0)
  let binding = HarmonyOSSurfaceBinding::new(create_renderer=(
    _surface,
    _metrics,
  ) => {
    Some(
      @render.RendererSession::new(
        resize=_ => (),
        render_frame=_frame => @render.RenderFrameResult::new(presented=true),
        text_system=() => @core.TextSystem::fallback(),
      ),
    )
  })
  let rows : Array[@core.View[Unit]] = []
  for i in 0..<40 {
    rows.push(@views.text("row \{i}", height=40.0))
  }
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let app = new_harmonyos_embedded_runtime(
    title="wheel-repro",
    runtime_factory=metrics => {
      let runtime = @runtime.AppRuntime::new_view(
        root=(
          @views.scroll_view(
            @views.column(rows, spacing=4.0),
            width=280.0,
            height=560.0,
            on_scroll=Some(_ => scroll_messages.val = scroll_messages.val + 1),
          ) : @core.View[Unit]),
        size=metrics.logical_size,
      )
      runtime_ref.val = Some(runtime)
      runtime
    },
    surface_binding_factory=() => binding,
    auto_exit_after_frames=None,
  )
  let event_loop = @window_harmonyos.EventLoop::new()
  @window_harmonyos.host_reset_for_test()
  @window_harmonyos.host_push(Start)
  @window_harmonyos.host_push(Resume)
  @window_harmonyos.host_push(SurfaceInit(0x57UL, 0UL, 640, 1280, 2.0))
  ignore(event_loop.pump_app_events(None, app))
  app.backend.force_redraw()
  ignore(event_loop.pump_app_events(None, app))
  // Control arm: dispatch the wheel pointer event straight into the runtime,
  // bypassing the backend chain, and see whether the runtime goes dirty.
  guard runtime_ref.val is Some(runtime) else {
    fail("expected the runtime to be constructed")
  }
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=140.0, y=280.0),
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=-120.0),
      ),
    ),
  )
  let runtime_dirty_direct = runtime.needs_redraw()
  ignore(event_loop.pump_app_events(None, app))
  // Backend arm: the full host chain through dispatch_wheel.
  let frames_before_wheel = app.frames_presented()
  app.backend.dispatch_wheel(
    @core.Point::new(x=140.0, y=280.0),
    @window_core.MouseScrollDelta::LineDelta(0.0, -3.0),
  )
  ignore(event_loop.pump_app_events(None, app))
  let frames_after_wheel = app.frames_presented()
  inspect(runtime_dirty_direct, content="true")
  inspect(scroll_messages.val, content="2")
  // The direct arm bypasses the window redraw queue, so it presents nothing.
  // The backend arm must present: `needs_redraw()` reads the transport frame
  // flag, which `pump_redraw_requested` consumes into a pending window redraw
  // (false is the designed state), and the next pump renders it.
  assert_true(frames_after_wheel > frames_before_wheel)
  event_loop.drop()
}

///|
priv struct WheelProgramModel {
  offset : @core.Point
}

///|
priv enum WheelProgramMsg {
  WheelScrolled(@core.Point)
}

///|
test "program mode: wheel over scroll view marks redraw and presents frames" {
  let binding = HarmonyOSSurfaceBinding::new(create_renderer=(
    _surface,
    _metrics,
  ) => {
    Some(
      @render.RendererSession::new(
        resize=_ => (),
        render_frame=_frame => @render.RenderFrameResult::new(presented=true),
        text_system=() => @core.TextSystem::fallback(),
      ),
    )
  })
  let rows : Array[@core.View[WheelProgramMsg]] = []
  for i in 0..<40 {
    rows.push(@views.text("row \{i}", height=40.0))
  }
  let app = new_harmonyos_embedded_runtime(
    title="wheel-program-repro",
    runtime_factory=metrics => {
      let program = @core.Program::new(
        init=() => {
          (
            WheelProgramModel::{ offset: @core.Point::new(x=0.0, y=0.0), },
            @core.Effect::none(),
          )
        },
        update=(model, message) => {
          match message {
            WheelProgramMsg::WheelScrolled(offset) =>
              (WheelProgramModel::{ offset, }, @core.Effect::none())
          }
        },
        view=model => {
          @views.scroll_view(
            @views.column(rows, spacing=4.0),
            width=280.0,
            height=560.0,
            offset=model.offset,
            on_scroll=Some(offset => WheelProgramMsg::WheelScrolled(offset)),
          )
        },
      )
      @runtime.AppRuntime::new_program(program~, size=metrics.logical_size)
    },
    surface_binding_factory=() => binding,
    auto_exit_after_frames=None,
  )
  let event_loop = @window_harmonyos.EventLoop::new()
  @window_harmonyos.host_reset_for_test()
  @window_harmonyos.host_push(Start)
  @window_harmonyos.host_push(Resume)
  @window_harmonyos.host_push(SurfaceInit(0x58UL, 0UL, 640, 1280, 2.0))
  ignore(event_loop.pump_app_events(None, app))
  app.backend.force_redraw()
  ignore(event_loop.pump_app_events(None, app))
  let frames_before = app.frames_presented()
  app.backend.dispatch_wheel(
    @core.Point::new(x=140.0, y=280.0),
    @window_core.MouseScrollDelta::LineDelta(0.0, -3.0),
  )

  ignore(event_loop.pump_app_events(None, app))
  let frames_after = app.frames_presented()
  // `needs_redraw()` reads the transport flag, already consumed into a
  // pending window redraw by the wheel path. What must hold: the next pump
  // presents the scrolled frame.
  assert_true(frames_after > frames_before)
  event_loop.drop()
}
