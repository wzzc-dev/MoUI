///|
test "harmonyos backend reports usable runtime_partial capabilities" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.capabilities.embedded_surface, content="true")
  inspect(info.capabilities.external_event_loop, content="true")
  inspect(info.capabilities.renderer_provider, content="true")
  inspect(info.capabilities.ime, content="true")
  inspect(info.capabilities.clipboard, content="true")
  inspect(info.capabilities.accessibility, content="true")
  inspect(info.capabilities.async_image, content="true")
  inspect(info.services.clipboard, content="true")
  inspect(info.readiness.ready, content="true")
  inspect(info.readiness.status, content="runtime_partial")
  assert_true(info.readiness.blocked_by.length() >= 1)
  assert_true(info.readiness.blocked_by[0].contains("signed-device"))
  let summary = harmonyos_capability_summary()
  inspect(summary.label, content="HarmonyOS host")
  inspect(summary.window_lifecycle, content="true")
  inspect(summary.multi_window, content="false")
  inspect(summary.text_input_available, content="true")
  inspect(summary.ime_available, content="true")
  inspect(summary.native_accessibility_available, content="true")
  assert_true(summary.has_required_app_basics())
}

///|
test "harmonyos runtime session renders through supplied provider" {
  let render_count = Ref(0)
  let resize_count = Ref(0)
  let sync_count = Ref(0)
  let create_count = Ref(0)
  let dispose_count = Ref(0)
  let completion_drain_count = Ref(0)
  let provider = HarmonyOsRendererProvider::new(
    create_renderer=(_surface, _metrics) => {
      create_count.val = create_count.val + 1
      Some(
        @host.HostWindowRenderer::new(
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
      surface=HarmonyOsSurfaceHandle::new(raw=42UL),
      metrics~,
      provider~,
    ) {
    Some(session) => {
      let first_generation = session.session_generation()
      assert_true(session.surface().raw() == 42UL)
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
      assert_true(session.detach_surface())
      assert_false(session.detach_surface())
      inspect(session.disposed(), content="false")
      inspect(session.surface_attached(), content="false")
      inspect(session.surface().raw(), content="0")
      inspect(session.session_generation(), content="0")
      inspect(dispose_count.val, content="1")
      assert_true(
        session.attach_surface(
          HarmonyOsSurfaceHandle::new(raw=84UL),
          resized,
          provider,
        ),
      )
      assert_true(session.surface().raw() == 84UL)
      assert_true(session.session_generation() > first_generation)
      inspect(create_count.val, content="2")
      inspect(sync_count.val, content="2")
      ignore(session.render_frame())
      inspect(render_count.val, content="2")
      session.sync_surface(provider)
      inspect(sync_count.val, content="3")
      session.dispose()
      inspect(session.disposed(), content="true")
      inspect(dispose_count.val, content="2")
    }
    None => fail("expected HarmonyOS session")
  }
}

