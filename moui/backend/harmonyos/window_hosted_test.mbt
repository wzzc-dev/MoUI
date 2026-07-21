///|
test "harmonyos window-hosted host-sim creates session and presents" {
  let render_count = Ref(0)
  let dispose_count = Ref(0)
  let pointer_count = Ref(0)
  let provider = HarmonyOsRendererProvider::new(
    create_renderer=(_surface, _metrics) => {
      Some(
        @host.HostWindowRenderer::new(
          resize=_ => (),
          render=_ => (),
          render_frame=Some(_frame => {
            render_count.val = render_count.val + 1
            @render.RenderFrameResult::new(presented=true)
          }),
          drain_present_completions=Some(() => []),
          text_system=() => @core.TextSystem::fallback(),
          present_count=() => render_count.val,
          dispose=() => dispose_count.val = dispose_count.val + 1,
        ),
      )
    },
  )
  let app = HarmonyOsWindowHostedApp::new(
    title="window-hosted-test",
    runtime_factory=metrics => {
      let runtime = @runtime.AppRuntime::new_view(
        root=(@views.empty() : @core.View[Unit]),
        size=metrics.logical_size,
      )
      runtime.set_event_observer(event =>
        match event {
          @core.AppEvent::Pointer(_) => pointer_count.val = pointer_count.val + 1
          _ => ()
        }
      )
      runtime
    },
    provider_factory=() => provider,
    auto_exit_after_frames=Some(1),
  )
  harmonyos_window_hosted_pump_host_sim(app, surface_handle=0x55UL)
  assert_true(app.frames_presented() >= 1)
  assert_true(render_count.val >= 1)
  assert_true(app.surface_generation() > 0)
  assert_true(app.has_session())
  assert_false(app.session_attached())
  assert_true(pointer_count.val >= 2)
}
