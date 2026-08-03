///|
test "android backend reports experimental readiness" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.capabilities.embedded_surface, content="true")
  inspect(info.capabilities.external_event_loop, content="true")
  inspect(info.capabilities.surface_binding, content="true")
  inspect(info.capabilities.ime, content="true")
  inspect(info.capabilities.clipboard, content="true")
  inspect(info.capabilities.accessibility, content="true")
  inspect(info.capabilities.async_image, content="true")
  inspect(info.services.clipboard, content="true")
  inspect(info.readiness.ready, content="false")
  inspect(info.readiness.status, content="experimental")
  assert_true(info.readiness.blocked_by.length() >= 1)
  assert_true(info.readiness.blocked_by[0].contains("experimental"))
  let summary = android_capability_summary()
  inspect(summary.label, content="Android host")
  inspect(summary.window_lifecycle, content="true")
  inspect(summary.multi_window, content="false")
  inspect(summary.text_input_available, content="true")
  inspect(summary.ime_available, content="true")
  inspect(summary.native_accessibility_available, content="true")
  assert_true(summary.has_required_app_basics())
}

///|
test "android host options select status bar layout mode" {
  let normal = AndroidHostAppOptions::new()
  assert_false(normal.status_bar_immersive())
  let immersive = AndroidHostAppOptions::new(status_bar_immersive=true)
  assert_true(immersive.status_bar_immersive())
  assert_false(immersive.with_status_bar_immersive(false).status_bar_immersive())
}

///|
test "android runtime session renders through supplied surface binding" {
  let render_count = Ref(0)
  let resize_count = Ref(0)
  let sync_count = Ref(0)
  let create_count = Ref(0)
  let dispose_count = Ref(0)
  let completion_drain_count = Ref(0)
  let binding = AndroidSurfaceBinding::new(
    create_renderer=(_surface, _metrics) => {
      create_count.val = create_count.val + 1
      Some(
        @render.HostRendererResolution::new(
          renderer=@render.HostWindowRenderer::new(
            resize=_ => resize_count.val = resize_count.val + 1,
            render=_ => (),
            render_frame=Some(_frame => {
              render_count.val = render_count.val + 1
              @render.RenderFrameResult::new(presented=true)
            }),
            drain_present_completions=Some(() => {
              completion_drain_count.val = completion_drain_count.val + 1
              []
            }),
            text_system=() => @core.TextSystem::fallback(),
            present_count=() => render_count.val,
            dispose=() => dispose_count.val = dispose_count.val + 1,
          ),
          image_loader=None,
        ),
      )
    },
    sync_surface=(_surface, _metrics) => sync_count.val = sync_count.val + 1,
  )
  let metrics = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=metrics.logical_size,
  )
  match
    create_session(
      runtime~,
      surface=AndroidSurfaceHandle::new(raw=42UL),
      metrics~,
      binding~,
    ) {
    Some(session) => {
      let first_generation = session.session_generation()
      assert_true(session.raw_handle() == 42UL)
      assert_true(first_generation > 0)
      inspect(create_count.val, content="1")
      inspect(sync_count.val, content="1")
      assert_true(session.take_redraw_requested())
      ignore(session.render_frame())
      inspect(render_count.val, content="1")
      inspect(completion_drain_count.val, content="1")
      inspect(session.present_count(), content="1")
      let resized = @host.HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=160.0, height=120.0),
      )
      ignore(session.resize(resized))
      inspect(resize_count.val, content="1")
      inspect(session.metrics().logical_size.width, content="160")
      assert_true(session.detach())
      assert_false(session.detach())
      inspect(session.disposed(), content="false")
      inspect(session.surface_attached(), content="false")
      inspect(session.raw_handle(), content="0")
      inspect(session.session_generation(), content="0")
      inspect(dispose_count.val, content="1")
      assert_true(
        session.attach(
          raw_handle=84UL,
          metrics=resized,
          binding=host_surface_binding_from_android(binding),
        ),
      )
      assert_true(session.raw_handle() == 84UL)
      assert_true(session.session_generation() > first_generation)
      inspect(create_count.val, content="2")
      inspect(sync_count.val, content="2")
      ignore(session.render_frame())
      inspect(render_count.val, content="2")
      (host_surface_binding_from_android(binding).sync)(84UL, session.metrics())
      inspect(sync_count.val, content="3")
      session.dispose()
      inspect(session.disposed(), content="true")
      inspect(dispose_count.val, content="2")
    }
    None => fail("expected Android session")
  }
}
