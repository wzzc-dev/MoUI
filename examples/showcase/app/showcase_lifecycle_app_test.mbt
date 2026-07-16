///|
test "platform timer subscription survives hidden workspace" {
  let source = @host.HostTimerSource::new(start_timer=(_interval, _dispatch) => {
    None
  })
  let platform = @platform.Model::new(
    timer_source=Some(source),
    timer_running=true,
    route="host-services",
  )
  let model = {
    ..ShowcaseModel::new(route="components/welcome"),
    platform,
  }
  let plan = @runtime.subscription_plan_summary(model.subscriptions())
  assert_true(plan.source_count() >= 1)
}

///|
test "canvas route declares animation timer subscription" {
  let source = @host.HostTimerSource::new(start_timer=(_interval, _dispatch) => {
    None
  })
  let model = ShowcaseModel::new(route="platform/canvas").with_platform_host(
    timer_source=Some(source),
  )
  let plan = @runtime.subscription_plan_summary(model.subscriptions())
  assert_true(plan.source_count() >= 1)
  inspect(model.platform.route(), content="canvas")
  // Without a timer source, canvas cannot animate.
  let bare = ShowcaseModel::new(route="platform/canvas")
  let bare_plan = @runtime.subscription_plan_summary(bare.subscriptions())
  inspect(bare_plan.source_count(), content="0")
}

///|
test "platform effect maps through root" {
  let services = @host.HostAppServices::new(
    bridge=@host.HostServiceBridge::new(
      capabilities=@host.HostServiceCapabilities::new(clipboard=true),
      handle=request =>
        match request {
          @host.HostServiceRequest::Clipboard(
            @host.HostClipboardRequest::WriteText(_),
          ) => @host.HostServiceResponse::ClipboardWritten
          _ => @host.HostServiceResponse::Unavailable("unexpected")
        },
    ),
  )
  let model = {
    ..ShowcaseModel::new(route="platform/host-services"),
    platform: @platform.Model::new(services~),
  }
  let (_, effect) = model.update_with_effect(
    PlatformMsg(@platform.Msg::WriteClipboard),
  )
  let summary = @runtime.effect_plan_summary(effect)
  inspect(summary.run_count(), content="1")
}
