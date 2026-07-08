///|
test "host async image loader schedules loading records and completes redraw" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(12)
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("late.png"))
  ignore(lifecycle.mark_ready("ready.png", width=10, height=5))
  let applied_sources : Array[String] = []
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
    apply_image_resource_load_completion=Some(completion => {
      applied_sources.push(completion.source)
      lifecycle.apply_load_completion(completion)
    }),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision(), content="2")
  inspect(baseline.current_status_counts().loading_count(), content="1")
  inspect(baseline.current_status_counts().ready_count(), content="1")
  let requested : Array[HostWindowId] = []
  let completion_source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => requested.push(id),
  )
  let started_sources : Array[String] = []
  let started_windows : Array[HostWindowId] = []
  let captured_completion : Ref[
    ((@render.ImageResourceLoadCompletion) -> Unit)?,
  ] = Ref(None)
  let loader = HostAsyncImageLoader::new(start_load=(id, source, complete) => {
    started_windows.push(id)
    started_sources.push(source)
    captured_completion.val = Some(complete)
    Some(() => ())
  })
  let scheduled = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(scheduled.snapshot_revision(), content="2")
  inspect(scheduled.loading_count(), content="1")
  inspect(scheduled.scheduled_count(), content="1")
  inspect(scheduled.already_in_flight_count(), content="0")
  inspect(started_windows.length(), content="1")
  assert_true(started_windows[0] == window_id)
  inspect(started_sources.length(), content="1")
  inspect(started_sources[0], content="late.png")
  let duplicate = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(duplicate.loading_count(), content="1")
  inspect(duplicate.scheduled_count(), content="0")
  inspect(duplicate.already_in_flight_count(), content="1")
  match captured_completion.val {
    Some(complete) =>
      complete(
        @render.ImageResourceLoadCompletion::ready(
          "late.png",
          width=80,
          height=40,
        ),
      )
    None => fail("expected captured async image completion callback")
  }
  inspect(applied_sources.length(), content="1")
  inspect(applied_sources[0], content="late.png")
  inspect(requested.length(), content="1")
  assert_true(requested[0] == window_id)
  match lifecycle.lookup("late.png") {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageReady)
      inspect(record.width, content="80")
      inspect(record.height, content="40")
    }
    None => fail("expected completed async image record")
  }
  let loader_diagnostics = loader.diagnostics()
  inspect(loader_diagnostics.scheduled_count(), content="1")
  inspect(loader_diagnostics.completed_count(), content="1")
  inspect(loader_diagnostics.already_in_flight_count(), content="1")
  inspect(loader_diagnostics.in_flight_count(), content="0")
  let completion_diagnostics = completion_source.diagnostics()
  inspect(completion_diagnostics.publish_count(), content="1")
  inspect(completion_diagnostics.redraw_requested_count(), content="1")
}

///|
test "host async image loader cancels window loads and ignores late completions" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(13)
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("cancelled.png"))
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
    apply_image_resource_load_completion=Some(completion => {
      lifecycle.apply_load_completion(completion)
    }),
  )
  ignore(tracker.record_presented(window_id, renderer))
  let redraws = Ref(0)
  let completion_source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  let cancelled = Ref(0)
  let captured_completion : Ref[
    ((@render.ImageResourceLoadCompletion) -> Unit)?,
  ] = Ref(None)
  let loader = HostAsyncImageLoader::new(start_load=(_id, _source, complete) => {
    captured_completion.val = Some(complete)
    Some(() => {
      cancelled.val = cancelled.val + 1
      complete(
        @render.ImageResourceLoadCompletion::ready(
          "cancelled.png",
          width=40,
          height=20,
        ),
      )
    })
  })
  let scheduled = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(scheduled.scheduled_count(), content="1")
  inspect(loader.cancel_window(window_id), content="1")
  inspect(cancelled.val, content="1")
  match captured_completion.val {
    Some(complete) =>
      complete(
        @render.ImageResourceLoadCompletion::failed(
          "cancelled.png",
          diagnostic="late decode failed",
        ),
      )
    None => fail("expected captured async image completion callback")
  }
  inspect(redraws.val, content="0")
  match lifecycle.lookup("cancelled.png") {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected cancelled async image record to remain loading")
  }
  let diagnostics = loader.diagnostics()
  inspect(diagnostics.scheduled_count(), content="1")
  inspect(diagnostics.completed_count(), content="0")
  inspect(diagnostics.cancelled_count(), content="1")
  inspect(diagnostics.in_flight_count(), content="0")
  inspect(completion_source.diagnostics().publish_count(), content="0")
}

///|
test "host async image loader ignores mismatched completion sources" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(14)
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("expected.png"))
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
    apply_image_resource_load_completion=Some(completion => {
      lifecycle.apply_load_completion(completion)
    }),
  )
  ignore(tracker.record_presented(window_id, renderer))
  let redraws = Ref(0)
  let completion_source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  let captured_completion : Ref[
    ((@render.ImageResourceLoadCompletion) -> Unit)?,
  ] = Ref(None)
  let loader = HostAsyncImageLoader::new(start_load=(_id, _source, complete) => {
    captured_completion.val = Some(complete)
    Some(() => ())
  })
  inspect(
    loader
    .schedule_loading_resources(window_id, renderer, completion_source)
    .scheduled_count(),
    content="1",
  )
  match captured_completion.val {
    Some(complete) =>
      complete(
        @render.ImageResourceLoadCompletion::ready(
          "unexpected.png",
          width=20,
          height=10,
        ),
      )
    None => fail("expected captured async image completion callback")
  }
  inspect(redraws.val, content="0")
  match lifecycle.lookup("expected.png") {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected original async image record")
  }
  inspect(loader.diagnostics().completed_count(), content="0")
  inspect(loader.diagnostics().in_flight_count(), content="0")
  inspect(completion_source.diagnostics().publish_count(), content="0")
  inspect(
    loader
    .schedule_loading_resources(window_id, renderer, completion_source)
    .scheduled_count(),
    content="1",
  )
}

///|
test "host native async image source defers completion until platform callback" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(15)
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("deferred.png"))
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
    apply_image_resource_load_completion=Some(completion => {
      lifecycle.apply_load_completion(completion)
    }),
  )
  ignore(tracker.record_presented(window_id, renderer))
  let redraws : Array[HostWindowId] = []
  let completion_source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => redraws.push(id),
  )
  let native_source = HostNativeAsyncImageSource::new()
  let loader = native_source.loader()
  let scheduled = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(scheduled.loading_count(), content="1")
  inspect(scheduled.scheduled_count(), content="1")
  inspect(redraws.length(), content="0")
  match lifecycle.lookup("deferred.png") {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected deferred image record")
  }
  let requests = native_source.pending_requests()
  inspect(requests.length(), content="1")
  assert_true(requests[0].window_id() == window_id)
  inspect(requests[0].source(), content="deferred.png")
  let delivered = native_source.complete(
    window_id,
    @render.ImageResourceLoadCompletion::ready(
      "deferred.png",
      width=44,
      height=22,
    ),
  )
  assert_true(
    delivered.status() ==
    HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered,
  )
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
  match lifecycle.lookup("deferred.png") {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageReady)
      inspect(record.width, content="44")
      inspect(record.height, content="22")
    }
    None => fail("expected completed deferred image record")
  }
  let native_diagnostics = native_source.diagnostics()
  inspect(native_diagnostics.requested_count(), content="1")
  inspect(native_diagnostics.completed_count(), content="1")
  inspect(native_diagnostics.pending_count(), content="0")
  let loader_diagnostics = loader.diagnostics()
  inspect(loader_diagnostics.completed_count(), content="1")
  inspect(loader_diagnostics.in_flight_count(), content="0")
  inspect(completion_source.diagnostics().redraw_requested_count(), content="1")
}

///|
test "host native async image source drops completions after loader cancellation" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(16)
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("cancel-source.png"))
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
    apply_image_resource_load_completion=Some(completion => {
      lifecycle.apply_load_completion(completion)
    }),
  )
  ignore(tracker.record_presented(window_id, renderer))
  let redraws = Ref(0)
  let completion_source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  let native_source = HostNativeAsyncImageSource::new()
  let loader = native_source.loader()
  inspect(
    loader
    .schedule_loading_resources(window_id, renderer, completion_source)
    .scheduled_count(),
    content="1",
  )
  inspect(native_source.pending_requests().length(), content="1")
  inspect(loader.cancel_window(window_id), content="1")
  inspect(native_source.pending_requests().length(), content="0")
  let missing = native_source.complete(
    window_id,
    @render.ImageResourceLoadCompletion::failed(
      "cancel-source.png",
      diagnostic="late native decode failed",
    ),
  )
  assert_true(
    missing.status() ==
    HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionMissing,
  )
  inspect(redraws.val, content="0")
  match lifecycle.lookup("cancel-source.png") {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected cancelled native source image record")
  }
  let native_diagnostics = native_source.diagnostics()
  inspect(native_diagnostics.requested_count(), content="1")
  inspect(native_diagnostics.cancelled_count(), content="1")
  inspect(native_diagnostics.completed_count(), content="0")
  inspect(native_diagnostics.missing_completion_count(), content="1")
  let loader_diagnostics = loader.diagnostics()
  inspect(loader_diagnostics.cancelled_count(), content="1")
  inspect(loader_diagnostics.completed_count(), content="0")
  inspect(loader_diagnostics.in_flight_count(), content="0")
  inspect(completion_source.diagnostics().publish_count(), content="0")
}

///|
test "host async image loader new_with_drain invokes drain during schedule" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(20)
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("drain-test.png"))
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
    apply_image_resource_load_completion=Some(completion => {
      lifecycle.apply_load_completion(completion)
    }),
  )
  ignore(tracker.record_presented(window_id, renderer))
  let completion_source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=_id => (),
  )
  let drain_calls = Ref(0)
  let loader = HostAsyncImageLoader::new_with_drain(
    start_load=(_id, _source, _complete) => None,
    drain=() => drain_calls.val = drain_calls.val + 1,
  )
  ignore(
    loader.schedule_loading_resources(window_id, renderer, completion_source),
  )
  inspect(drain_calls.val, content="1")
}

///|
test "host native async image source loader_with_drain spawns and drains" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(21)
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("spawn-drain.png"))
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
    apply_image_resource_load_completion=Some(completion => {
      lifecycle.apply_load_completion(completion)
    }),
  )
  ignore(tracker.record_presented(window_id, renderer))
  let completion_source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=_id => (),
  )
  let spawned : Array[String] = []
  let drain_count = Ref(0)
  let native_source = HostNativeAsyncImageSource::new()
  let loader = native_source.loader_with_drain(
    spawn=(_id, source) => spawned.push(source),
    drain=() => drain_count.val = drain_count.val + 1,
  )
  let scheduled = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(scheduled.scheduled_count(), content="1")
  inspect(spawned.length(), content="1")
  inspect(spawned[0], content="spawn-drain.png")
  inspect(drain_count.val, content="1")
  inspect(native_source.pending_requests().length(), content="1")
  let delivered = native_source.complete(
    window_id,
    @render.ImageResourceLoadCompletion::ready(
      "spawn-drain.png",
      width=50,
      height=25,
    ),
  )
  assert_true(
    delivered.status() ==
    HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered,
  )
  match lifecycle.lookup("spawn-drain.png") {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageReady)
      inspect(record.width, content="50")
      inspect(record.height, content="25")
    }
    None => fail("expected completed spawn-drain image record")
  }
}
