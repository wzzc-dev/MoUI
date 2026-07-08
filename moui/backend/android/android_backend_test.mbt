///|
test "android backend reports embedded scaffold capabilities" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.capabilities.embedded_surface, content="true")
  inspect(info.capabilities.external_event_loop, content="true")
  inspect(info.capabilities.renderer_provider, content="true")
  inspect(info.capabilities.ime, content="false")
  inspect(info.services.clipboard, content="false")
  inspect(info.readiness.ready, content="false")
  assert_true(info.readiness.blocked_by.length() >= 1)
  let summary = android_capability_summary()
  inspect(summary.label, content="Android host")
  inspect(summary.window_lifecycle, content="true")
  inspect(summary.multi_window, content="false")
  inspect(summary.text_input_available, content="true")
  inspect(summary.ime_available, content="false")
  assert_true(summary.has_required_app_basics())
}

///|
test "android runtime session renders through supplied provider" {
  let render_count = Ref(0)
  let resize_count = Ref(0)
  let provider = AndroidRendererProvider::new(create_renderer=(
    _surface,
    _metrics,
  ) => {
    Some(
      @host.HostWindowRenderer::new(
        resize=_ => resize_count.val = resize_count.val + 1,
        render=_ => (),
        render_frame=Some(_frame => {
          render_count.val = render_count.val + 1
          @render.RenderFrameResult::new(presented=true)
        }),
        text_system=() => @core.TextSystem::fallback(),
        present_count=() => render_count.val,
      ),
    )
  })
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
      provider~,
    ) {
    Some(session) => {
      assert_true(session.surface().raw() == 42UL)
      assert_true(session.take_redraw_requested())
      ignore(session.render_frame())
      inspect(render_count.val, content="1")
      inspect(session.present_count(), content="1")
      let resized = @host.HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=160.0, height=120.0),
      )
      ignore(session.resize(resized))
      inspect(resize_count.val, content="1")
      inspect(session.metrics().logical_size.width, content="160")
      session.dispose()
      inspect(session.disposed(), content="true")
    }
    None => fail("expected Android session")
  }
}
