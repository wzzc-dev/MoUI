///|
fn hosted_backend_test_renderer(
  dispose_count : Ref[Int],
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_frame => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    dispose=() => dispose_count.val = dispose_count.val + 1,
  )
}

///|
fn hosted_backend_test_window(
  redraw_count : Ref[Int],
  drop_count : Ref[Int],
) -> HostedWindow {
  HostedWindow::new(
    scale_factor=() => 2.0,
    inner_size=() => @dpi.PhysicalSize::PhysicalSize(240, 160),
    request_redraw=() => redraw_count.val = redraw_count.val + 1,
    drop=() => drop_count.val = drop_count.val + 1,
  )
}

///|
test "hosted window backend owns attach detach recreation and retry" {
  let renderer_create_count = Ref(0)
  let native_create_count = Ref(0)
  let redraw_count = Ref(0)
  let drop_count = Ref(0)
  let dispose_count = Ref(0)
  let backend = HostedWindowBackend::new(
    runtime_factory=metrics => {
      @runtime.AppRuntime::new_view(
        root=(@views.empty() : @core.View[Unit]),
        size=metrics.logical_size,
      )
    },
    surface_binding_factory=() => {
      HostSurfaceBinding::new(
        create_renderer=(_raw, _metrics) => {
          renderer_create_count.val = renderer_create_count.val + 1
          Some(hosted_backend_test_renderer(dispose_count))
        },
        sync=(_raw, _metrics) => (),
      )
    },
  )
  let create = () => {
    native_create_count.val = native_create_count.val + 1
    Some((hosted_backend_test_window(redraw_count, drop_count), 41UL))
  }
  assert_true(backend.ensure_surface(create~))
  assert_true(backend.has_window())
  assert_true(backend.session_attached())
  assert_eq(native_create_count.val, 1)
  assert_eq(renderer_create_count.val, 1)
  assert_eq(redraw_count.val, 1)
  assert_false(backend.ensure_surface(create~))
  assert_eq(native_create_count.val, 1)

  let first_generation = backend.surface_generation()
  backend.destroy_surfaces()
  assert_false(backend.has_window())
  assert_false(backend.session_attached())
  assert_eq(drop_count.val, 1)
  assert_eq(dispose_count.val, 1)
  backend.suspended()
  assert_eq(drop_count.val, 1)

  assert_true(backend.ensure_surface(create~))
  assert_true(backend.surface_generation() > first_generation)
  assert_eq(native_create_count.val, 2)
  assert_eq(renderer_create_count.val, 2)
  assert_eq(redraw_count.val, 2)
  backend.destroy_surfaces()
  assert_eq(drop_count.val, 2)
  assert_eq(dispose_count.val, 2)
}

///|
test "hosted window backend drops failed renderer window and allows retry" {
  let native_create_count = Ref(0)
  let drop_count = Ref(0)
  let backend = HostedWindowBackend::new(
    runtime_factory=metrics => {
      @runtime.AppRuntime::new_view(
        root=(@views.empty() : @core.View[Unit]),
        size=metrics.logical_size,
      )
    },
    surface_binding_factory=() => {
      HostSurfaceBinding::new(create_renderer=(_raw, _metrics) => None, sync=(
        _raw,
        _metrics,
      ) => ())
    },
  )
  let create = () => {
    native_create_count.val = native_create_count.val + 1
    Some((hosted_backend_test_window(Ref(0), drop_count), 51UL))
  }
  assert_false(backend.ensure_surface(create~))
  assert_false(backend.has_window())
  assert_false(backend.has_session())
  assert_eq(drop_count.val, 1)
  assert_false(backend.ensure_surface(create~))
  assert_eq(native_create_count.val, 2)
  assert_eq(drop_count.val, 2)
}

///|
test "application close disposes the logical surface before physical exit" {
  let redraw_count = Ref(0)
  let drop_count = Ref(0)
  let dispose_count = Ref(0)
  let exits = Ref(0)
  let backend = HostedWindowBackend::new(
    runtime_factory=metrics => {
      @runtime.AppRuntime::new_view(
        root=(@views.empty() : @core.View[Unit]),
        size=metrics.logical_size,
      )
    },
    surface_binding_factory=() => {
      HostSurfaceBinding::new(
        create_renderer=(_raw, _metrics) => {
          Some(hosted_backend_test_renderer(dispose_count))
        },
        sync=(_raw, _metrics) => (),
      )
    },
  )
  assert_true(
    backend.ensure_surface(create=() => {
      Some((hosted_backend_test_window(redraw_count, drop_count), 61UL))
    }),
  )
  backend.handle_window_event(@window_core.WindowEvent::CloseRequested, exit=() => {
    exits.val += 1
  })
  inspect(exits.val, content="1")
  inspect(dispose_count.val, content="1")
  inspect(drop_count.val, content="1")
  assert_false(backend.has_window())
  assert_false(backend.session_attached())
}
