///|
test "android window-hosted host-sim creates session and presents" {
  let render_count = Ref(0)
  let dispose_count = Ref(0)
  let pointer_count = Ref(0)
  let binding = AndroidSurfaceBinding::new(create_renderer=(_surface, _metrics) => {
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
  let app = new_android_embedded_runtime(
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
    surface_binding_factory=() => binding,
    auto_exit_after_frames=None,
  )
  android_window_hosted_pump_host_sim(app, surface_handle=0x55UL)
  assert_true(app.frames_presented() >= 1)
  assert_true(render_count.val >= 1)
  assert_true(app.surface_generation() > 0)
  assert_true(app.has_session())
  assert_false(app.session_attached())
  assert_true(pointer_count.val >= 2)
}
