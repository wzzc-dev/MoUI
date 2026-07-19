///|
test "surface detach cancels pending host service exactly once" {
  let metrics = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=metrics.logical_size,
  )
  let renderer = @host.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    present_count=() => 0,
  )
  let core = EmbeddedSessionCore::new(runtime~, renderer~, metrics~)
  let request = @host.PlatformChannelRequest::new(
    channel="camera.control",
    operation="start",
  )
  let id = match
    core
    .host_service_bridge()
    .dispatch(@host.HostServiceRequest::PlatformChannel(request)) {
    @host.HostServiceResponse::Pending(id) => id
    _ => fail("expected pending platform channel request")
  }
  let completion_count = Ref(0)
  let cancellation_reason = Ref("")
  let unexpected_completion = Ref(false)
  guard core.host_bridge is Some(channel) else {
    fail("expected attached host channel")
  }
  assert_true(
    channel.service_queue.on_completed(id, completion => {
      completion_count.val = completion_count.val + 1
      match completion.response {
        @host.HostServiceResponse::Unavailable(reason) =>
          cancellation_reason.val = reason
        _ => unexpected_completion.val = true
      }
    }),
  )
  assert_true(core.detach_surface())
  inspect(completion_count.val, content="1")
  assert_false(unexpected_completion.val)
  inspect(cancellation_reason.val, content="shell surface epoch detached")
  assert_false(
    channel.service_queue.complete(
      id,
      @host.HostServiceResponse::PlatformChannel(
        @host.PlatformChannelResponse::Ok("late"),
      ),
    ),
  )
  inspect(completion_count.val, content="1")
  core.dispose()
}
