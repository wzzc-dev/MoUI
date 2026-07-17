///|
test "timer toggle and tick update the model" {
  let model = Model::new()
  let (running, _) = update(model, ToggleTimer)
  inspect(running.timer_running, content="true")
  let (ticked, _) = update(running, TimerTick)
  inspect(ticked.ticks, content="1")
}

///|
test "window resize records logical size" {
  let (model, _) = update(Model::new(), WindowResized(640.0, 480.0))
  inspect(model.window_width, content="640")
  inspect(model.window_height, content="480")
}

///|
test "route open preserves timer state" {
  let (running, _) = update(Model::new(), ToggleTimer)
  let opened = running.open("canvas")
  inspect(opened.route(), content="canvas")
  inspect(opened.timer_running, content="true")
  let probe = opened.open("mobile-service-probe")
  inspect(probe.route(), content="mobile-service-probe")
  inspect(probe.timer_running, content="true")
}

///|
test "normalize platform route aliases" {
  inspect(normalize_platform_route("overview"), content="host-services")
  inspect(normalize_platform_route("timer"), content="host-services")
  inspect(
    normalize_platform_route("mobile-service-probe"),
    content="mobile-service-probe",
  )
}

///|
test "subscriptions stay empty without host adapters" {
  let model = Model::new()
  let plan = @runtime.subscription_plan_summary(subscriptions(model))
  inspect(plan.source_count(), content="0")
}

///|
test "timer source is declared while running on another route" {
  let source = @host.HostTimerSource::new(start_timer=(_interval, _dispatch) => {
    None
  })
  let model = Model::new(
    timer_source=Some(source),
    timer_running=true,
    route="mobile-service-probe",
  )
  let plan = @runtime.subscription_plan_summary(subscriptions(model))
  assert_true(plan.source_count() >= 1)
}

///|
test "clipboard write effect is host_service shaped" {
  let services = @host.HostAppServices::new(
    bridge=@host.HostServiceBridge::new(
      capabilities=@host.HostServiceCapabilities::new(clipboard=true),
      handle=request => {
        match request {
          @host.HostServiceRequest::Clipboard(
            @host.HostClipboardRequest::WriteText(_)
          ) => @host.HostServiceResponse::ClipboardWritten
          _ => @host.HostServiceResponse::Unavailable("unexpected")
        }
      },
    ),
  )
  let model = Model::new(services~)
  let (_, effect) = update(model, WriteClipboard)
  let summary = @runtime.effect_plan_summary(effect)
  inspect(summary.run_count(), content="1")
}

///|
test "action command map exposes a keyboard shortcut" {
  let map = action_command_map()
  let commands = map.commands()
  inspect(commands.length(), content="1")
  inspect(commands[0].label, content="Platform tick")
  assert_true(commands[0].shortcut is Some(_))
}

///|
test "probe actions update counters" {
  let model = Model::new(route="mobile-service-probe")
  let (acted, _) = update(model, ProbeAction)
  inspect(acted.probe_action_count, content="1")
  let (submitted, _) = update(acted, ProbeSubmit)
  inspect(submitted.probe_submit_count, content="1")
}
