///|
test "mobile runtime core owns shared render resize and dispose lifecycle" {
  let render_count = Ref(0)
  let resize_count = Ref(0)
  let completion_drain_count = Ref(0)
  let dispose_count = Ref(0)
  let renderer = @host.HostWindowRenderer::new(
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
  )
  let metrics = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=metrics.logical_size,
  )
  let core = MobileRuntimeSessionCore::new(runtime~, renderer~, metrics~)
  assert_true(core.session_generation() > 0)
  assert_true(core.take_redraw_requested())
  core.advance_time(16.0)
  assert_true(core.drain_host_updates().length() > 0)
  let submit = @host.mobile_command_response(3).unwrap()
  assert_false(
    core.dispatch_host_response_envelope(
      @host.MobileHostResponseEnvelope::new(
        session_generation=core.session_generation() + 1,
        response=submit,
      ),
    ),
  )
  assert_true(core.dispatch_host_response(submit))
  ignore(core.render_frame())
  inspect(render_count.val, content="1")
  inspect(completion_drain_count.val, content="1")
  inspect(core.present_count(), content="1")
  let resized = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=160.0, height=120.0),
  )
  ignore(core.resize(resized))
  inspect(resize_count.val, content="1")
  inspect(core.metrics().logical_size.width, content="160")
  inspect(core.host_service_bridge().capabilities().clipboard, content="true")
  let envelope_json = core.drain_host_update_envelope_json()
  assert_true(envelope_json.contains("\"schemaVersion\":1"))
  assert_true(envelope_json.contains("\"sessionGeneration\":"))
  core.dispose()
  core.dispose()
  inspect(core.disposed(), content="true")
  inspect(core.dispatch_host_response(submit), content="false")
  inspect(dispose_count.val, content="1")
}
