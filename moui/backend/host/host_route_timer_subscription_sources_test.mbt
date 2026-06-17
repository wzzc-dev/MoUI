///|
test "host route source subscription dispatches mapped route events" {
  let source = HostRouteSource::new()
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=280.0, height=24.0),
      subscriptions=_model => {
        source.subscription(key="host:route", label="Host route adapter", map=event => {
          if event.source == "deep-link" {
            Some("route \{event.route()}")
          } else {
            None
          }
        })
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  inspect(initial.active_subscriptions[0].key(), content="host:route")
  inspect(initial.active_subscriptions[0].kind(), content="route-event")
  inspect(initial.active_subscriptions[0].label(), content="Host route adapter")
  inspect(
    source.publish(HostRouteEvent::from_route(route="/ignored", source="app")),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="0")
  let deep_link = HostRouteEvent::from_route(
    route="/docs?tab=api",
    source="deep-link",
  )
  inspect(deep_link.route(), content="/docs?tab=api")
  inspect(source.publish(deep_link), content="1")
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="1")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text, .. }) &&
      text == "route /docs?tab=api"
    }),
  )
}

///|
test "host route event constructor preserves location and source" {
  let event = HostRouteEvent::new(
    location=HostRouteLocation::parse("/docs?tab=api&lang=moonbit"),
    source="browser",
  )
  inspect(event.location.path, content="/docs")
  inspect(event.location.query.length(), content="2")
  match event.location.query_value("tab") {
    Some(tab) => inspect(tab, content="api")
    None => fail("expected tab query")
  }
  match event.location.query_value("lang") {
    Some(lang) => inspect(lang, content="moonbit")
    None => fail("expected lang query")
  }
  inspect(event.source, content="browser")
  inspect(event.route(), content="/docs?tab=api&lang=moonbit")
}

///|
test "host route source subscription cleanup removes late publishers" {
  let source = HostRouteSource::new()
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=240.0, height=24.0),
      subscriptions=_model => {
        source.subscription(key="host:route", label="Host route adapter", map=_event => {
          Some("route event")
        })
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  runtime.destroy()
  inspect(source.active_handler_count(), content="0")
  inspect(
    source.publish(HostRouteEvent::from_route(route="/late")),
    content="0",
  )
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.cancelled_subscription_count, content="1")
  inspect(destroyed.ignored_subscription_dispatch_count, content="0")
}

///|
test "host timer source subscription starts timer and dispatches mapped frames" {
  let timer_dispatch : Ref[((@core.Frame) -> Unit)?] = Ref(None)
  let captured_interval = Ref(0.0)
  let source = HostTimerSource::new(start_timer=(interval_ms, dispatch) => {
    captured_interval.val = interval_ms
    timer_dispatch.val = Some(dispatch)
    Some(() => ())
  })
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=240.0, height=24.0),
      subscriptions=_model => {
        source.subscription(
          interval_ms=250.0,
          key="host:timer",
          label="Host timer adapter",
          map=frame => "timer \{frame.time_ms.to_int().to_string()}",
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(captured_interval.val, content="250")
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  inspect(initial.active_subscriptions[0].key(), content="host:timer")
  inspect(initial.active_subscriptions[0].kind(), content="timer")
  inspect(initial.active_subscriptions[0].label(), content="Host timer adapter")
  match timer_dispatch.val {
    Some(dispatch) => dispatch(@core.Frame::new(time_ms=1000.0, delta_ms=250.0))
    None => fail("expected host timer dispatch")
  }
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="1")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text, .. }) &&
      text == "timer 1000"
    }),
  )
}

///|
test "host timer source subscription cleanup cancels timer" {
  let timer_dispatch : Ref[((@core.Frame) -> Unit)?] = Ref(None)
  let cleanup_count = Ref(0)
  let source = HostTimerSource::new(start_timer=(_interval_ms, dispatch) => {
    timer_dispatch.val = Some(dispatch)
    Some(() => cleanup_count.val = cleanup_count.val + 1)
  })
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=240.0, height=24.0),
      subscriptions=_model => {
        source.subscription(
          interval_ms=16.0,
          key="host:timer",
          label="Host timer adapter",
          map=_frame => "timer tick",
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(cleanup_count.val, content="0")
  runtime.destroy()
  inspect(cleanup_count.val, content="1")
  match timer_dispatch.val {
    Some(dispatch) => dispatch(@core.Frame::new(time_ms=16.0, delta_ms=16.0))
    None => fail("expected host timer dispatch")
  }
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.cancelled_subscription_count, content="1")
  inspect(destroyed.ignored_subscription_dispatch_count, content="1")
}
