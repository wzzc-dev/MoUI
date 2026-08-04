///|
test "ServiceTask reports success failure and explicit cancellation" {
  let results : Array[@services.ServiceTaskResult[Int]] = []
  ignore(
    @services.ServiceTask::succeed(key="ok", value=7).start(result => {
      results.push(result)
    }),
  )
  let failed : @services.ServiceTask[Int] = @services.ServiceTask::fail(
    key="fail",
    error=@services.ServiceError::new(code="io", message="disk"),
  )
  ignore(failed.start(result => results.push(result)))
  let cancelled : @services.ServiceTask[Int] = @services.ServiceTask::cancelled(
    key="cancel",
  )
  ignore(cancelled.start(result => results.push(result)))
  assert_eq(results.length(), 3)
  assert_eq(results[0], @services.ServiceTaskResult::Success(7))
  assert_eq(
    results[1],
    @services.ServiceTaskResult::Failure(
      @services.ServiceError::new(code="io", message="disk"),
    ),
  )
  assert_eq(results[2], @services.ServiceTaskResult::Cancelled)
}

///|
test "ServiceTask cleanup suppresses a stale completion in an adapter" {
  let completion : Ref[((@services.ServiceTaskResult[Int]) -> Unit)?] = Ref(
    None,
  )
  let active = Ref(true)
  let task = @services.ServiceTask::new(key="deferred", start=complete => {
    completion.val = Some(complete)
    Some(() => active.val = false)
  })
  let results : Array[@services.ServiceTaskResult[Int]] = []
  let cleanup = task.start(result => if active.val { results.push(result) })
  match cleanup {
    Some(cancel) => cancel()
    None => fail("expected cleanup")
  }
  match completion.val {
    Some(complete) => complete(@services.ServiceTaskResult::Success(9))
    None => fail("expected deferred completion")
  }
  assert_true(results.is_empty())
}

///|
test "TimerSource and RouteSource produce core subscriptions" {
  let timer = @services.TimerSource::new(start=(_interval, dispatch) => {
    dispatch(@core.Frame::new(time_ms=10.0, delta_ms=10.0))
    None
  })
  let timer_subscription = timer.subscription(interval_ms=10.0, map=frame => {
    frame.time_ms.to_int()
  })
  assert_eq(timer_subscription.descriptors().length(), 1)
  let routes = @services.RouteSource::new()
  let route_subscription = routes.subscription(map=event => {
    Some(event.location.path)
  })
  assert_eq(route_subscription.descriptors().length(), 1)
}

///|
test "RouteLocation round-trips path and query values" {
  let location = @services.RouteLocation::parse("/docs?tab=api&lang=moonbit")
  assert_eq(location.query_value("tab"), Some("api"))
  assert_eq(location.query_value("lang"), Some("moonbit"))
  inspect(location.to_route(), content="/docs?tab=api&lang=moonbit")
  inspect(
    @services.RouteEvent::from_route(route="/docs?tab=api", source="deep-link").route(),
    content="/docs?tab=api",
  )
}

///|
test "native timer adapter supports interval frames and cancellation" {
  let tick_ref : Ref[(() -> Unit)?] = Ref(None)
  let cancelled : Array[UInt64] = []
  let source = @services.TimerSource::from_native_timer(
    start=(_call, _interval, tick) => {
      tick_ref.val = Some(tick)
      41UL
    },
    cancel=handle => cancelled.push(handle),
  )
  let frames : Array[@core.Frame] = []
  let runtime_sources = source
    .subscription(interval_ms=25.0, map=frame => frame)
    .runtime_sources()
  let cleanup = runtime_sources[0].start(frame => frames.push(frame))
  match tick_ref.val {
    Some(tick) => tick()
    None => fail("timer did not install a callback")
  }
  assert_eq(frames.length(), 1)
  inspect(frames[0].delta_ms, content="25")
  match cleanup {
    Some(cancel) => cancel()
    None => fail("timer did not return cancellation")
  }
  assert_eq(cancelled, [41UL])
}
