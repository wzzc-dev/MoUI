///|
test "ios window-hosted host-sim creates session and presents" {
  let render_count = Ref(0)
  let dispose_count = Ref(0)
  let pointer_count = Ref(0)
  let provider = IosRendererProvider::new(create_renderer=(_view, _metrics) => {
    Some(
      @render.HostWindowRenderer::new(
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
  })
  let app = IosWindowHostedApp::new(
    title="window-hosted-test",
    runtime_factory=metrics => {
      let runtime = @runtime.AppRuntime::new_view(
        root=(@views.empty() : @core.View[Unit]),
        size=metrics.logical_size,
      )
      runtime.set_event_observer(event => {
        match event {
          @core.AppEvent::Pointer(_) =>
            pointer_count.val = pointer_count.val + 1
          _ => ()
        }
      })
      runtime
    },
    provider_factory=() => provider,
    auto_exit_after_frames=Some(1),
  )
  ios_window_hosted_pump_host_sim(app, surface_handle=0x55UL)
  assert_true(app.frames_presented() >= 1)
  assert_true(render_count.val >= 1)
  assert_true(app.surface_generation() > 0)
  assert_true(app.has_session())
  assert_false(app.session_attached())
  // pump_host_sim presses and releases a pointer button; the host path
  // must dispatch those into the runtime (regression: previously the
  // Pointer branch only updated last_pointer and dropped the event).
  assert_true(pointer_count.val >= 2)
}
