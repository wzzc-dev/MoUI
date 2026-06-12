///|
test "host window renderer forwards lifecycle closures" {
  let resized = Ref(@core.Size::new(width=0.0, height=0.0))
  let rendered = Ref(0)
  let disposed = Ref(0)
  let presenter = Ref(3)
  let callback_sets = Ref(0)
  let callback_revisions : Array[Int] = []
  let completion_sources : Array[String] = []
  let image_records = [
    @render.ImageResourceRecord::ready("loaded.png", width=32, height=18),
    @render.ImageResourceRecord::failed(
      "missing.png",
      diagnostic="decode failed",
    ),
  ]
  let renderer = HostWindowRenderer::new(
    resize=metrics => resized.val = metrics.logical_size,
    render=commands => rendered.val = commands.length(),
    text_system=() => @core.TextSystem::fallback(),
    image_resources=() => image_records,
    image_resource_snapshot=Some(() => {
      @render.ImageResourceSnapshot::new(revision=7, records=image_records)
    }),
    apply_image_resource_load_completion=Some(completion => {
      completion_sources.push(completion.source)
      @render.ImageResourceSnapshot::new(revision=11, records=[
        @render.ImageResourceRecord::ready(
          completion.source,
          width=completion.width,
          height=completion.height,
        ),
      ])
    }),
    set_image_resource_change_callback=callback => {
      callback_sets.val = callback_sets.val + 1
      match callback {
        Some(notify) =>
          notify(@render.ImageResourceSnapshot::new(revision=9, records=[]))
        None => ()
      }
    },
    present_count=() => presenter.val,
    dispose=() => disposed.val = disposed.val + 1,
  )
  renderer.resize(
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=96.0, height=48.0),
      scale_factor=2.0,
    ),
  )
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())])
  inspect(resized.val.width, content="96")
  inspect(resized.val.height, content="48")
  inspect(rendered.val, content="1")
  inspect(renderer.text_system().id(), content="core-fallback-text-system")
  let resources = renderer.image_resources()
  inspect(resources.length(), content="2")
  assert_true(resources[0].status == @render.ImageResourceStatus::ImageReady)
  inspect(resources[0].width, content="32")
  assert_true(resources[1].status == @render.ImageResourceStatus::ImageFailed)
  assert_true(resources[1].diagnostic.contains("decode"))
  let image_snapshot = renderer.image_resource_snapshot()
  inspect(image_snapshot.revision, content="7")
  inspect(image_snapshot.records.length(), content="2")
  let completed = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("async.png", width=44, height=22),
  )
  inspect(completed.revision, content="11")
  inspect(completion_sources.length(), content="1")
  inspect(completion_sources[0], content="async.png")
  assert_true(completed.records[0].source == "async.png")
  inspect(completed.records[0].width, content="44")
  renderer.set_image_resource_change_callback(
    Some(snapshot => callback_revisions.push(snapshot.revision)),
  )
  inspect(callback_sets.val, content="1")
  assert_true(callback_revisions == [9])
  renderer.set_image_resource_change_callback(None)
  inspect(callback_sets.val, content="2")
  inspect(renderer.present_count(), content="3")
  renderer.dispose()
  inspect(disposed.val, content="1")
}

///|
test "host window renderer image resource diagnostics default empty" {
  let renderer = HostWindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  inspect(renderer.image_resources().length(), content="0")
  let image_snapshot = renderer.image_resource_snapshot()
  inspect(image_snapshot.revision, content="0")
  inspect(image_snapshot.records.length(), content="0")
  let completion_snapshot = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      "missing.png",
      diagnostic="decode failed",
    ),
  )
  inspect(completion_snapshot.revision, content="0")
  inspect(completion_snapshot.records.length(), content="0")
  renderer.set_image_resource_change_callback(Some(_snapshot => ()))
  renderer.set_image_resource_change_callback(None)
}

///|
test "host image repaint tracker routes revision changes per window" {
  let tracker = HostImageResourceRepaintTracker::new()
  let main_id = HostWindowId::new(1)
  let inspector_id = HostWindowId::new(2)
  let main_revision = Ref(0)
  let inspector_revision = Ref(0)
  let main_renderer = host_test_image_renderer(main_revision)
  let inspector_renderer = host_test_image_renderer(inspector_revision)
  let main_baseline = tracker.record_presented(main_id, main_renderer)
  let inspector_baseline = tracker.record_presented(
    inspector_id, inspector_renderer,
  )
  assert_true(
    main_baseline.status == HostImageResourceRepaintStatus::ImageRepaintRecorded,
  )
  inspect(inspector_baseline.current_revision, content="0")
  inspect(tracker.tracked_count(), content="2")
  let baseline_snapshot = tracker.snapshot()
  inspect(baseline_snapshot.tracked_window_count, content="2")
  assert_true(baseline_snapshot.tracked_windows[0].window_id == main_id)
  inspect(baseline_snapshot.tracked_windows[0].revision, content="0")
  inspect(
    baseline_snapshot.tracked_windows[0].status_counts.record_count,
    content="0",
  )
  assert_true(baseline_snapshot.tracked_windows[1].window_id == inspector_id)
  inspect(baseline_snapshot.tracked_windows[1].revision, content="0")
  inspector_revision.val = 1
  let requested : Array[HostWindowId] = []
  let inspector_result = tracker.request_redraw_if_changed(
    inspector_id,
    inspector_renderer,
    window_open=true,
    request_redraw=id => requested.push(id),
  )
  assert_true(
    inspector_result.status ==
    HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(inspector_result.previous_revision, content="0")
  inspect(inspector_result.current_revision, content="1")
  inspect(requested.length(), content="1")
  assert_true(requested[0] == inspector_id)
  let requested_snapshot = tracker.snapshot()
  inspect(requested_snapshot.tracked_window_count, content="2")
  assert_true(requested_snapshot.tracked_windows[0].window_id == main_id)
  inspect(requested_snapshot.tracked_windows[0].revision, content="0")
  assert_true(requested_snapshot.tracked_windows[1].window_id == inspector_id)
  inspect(requested_snapshot.tracked_windows[1].revision, content="1")
  inspect(
    requested_snapshot.tracked_windows[1].status_counts.record_count,
    content="0",
  )
  let unchanged = tracker.request_redraw_if_changed(
    inspector_id,
    inspector_renderer,
    window_open=true,
    request_redraw=id => requested.push(id),
  )
  assert_true(
    unchanged.status == HostImageResourceRepaintStatus::ImageRepaintUnchanged,
  )
  inspect(requested.length(), content="1")
  main_revision.val = 3
  let main_result = tracker.request_redraw_if_changed(
    main_id,
    main_renderer,
    window_open=true,
    request_redraw=id => requested.push(id),
  )
  assert_true(
    main_result.status == HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(requested.length(), content="2")
  assert_true(requested[1] == main_id)
}

///|
test "host image repaint tracker routes callback snapshots without renderer reads" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(4)
  let revision = Ref(1)
  let snapshot_reads = Ref(0)
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      snapshot_reads.val = snapshot_reads.val + 1
      @render.ImageResourceSnapshot::new(revision=revision.val, records=[])
    }),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision, content="1")
  inspect(snapshot_reads.val, content="1")
  let requested : Array[HostWindowId] = []
  let result = tracker.request_redraw_for_snapshot_if_changed(
    window_id,
    @render.ImageResourceSnapshot::new(revision=2, records=[
      @render.ImageResourceRecord::ready("late.png", width=12, height=8),
    ]),
    window_open=true,
    request_redraw=id => requested.push(id),
  )
  assert_true(
    result.status == HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(result.previous_revision, content="1")
  inspect(result.current_revision, content="2")
  inspect(result.current_status_counts.ready_count, content="1")
  inspect(snapshot_reads.val, content="1")
  inspect(requested.length(), content="1")
  assert_true(requested[0] == window_id)
}

///|
test "host image repaint tracker snapshots lifecycle status counts" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(5)
  let revision = Ref(1)
  let records : Ref[Array[@render.ImageResourceRecord]] = Ref([
    @render.ImageResourceRecord::loading("loading.png"),
    @render.ImageResourceRecord::ready("ready.png", width=64, height=48),
    @render.ImageResourceRecord::failed("failed.png", diagnostic="decode"),
  ])
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      @render.ImageResourceSnapshot::new(
        revision=revision.val,
        records=records.val,
      )
    }),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision, content="1")
  inspect(baseline.previous_status_counts.record_count, content="0")
  inspect(baseline.current_status_counts.record_count, content="3")
  inspect(baseline.current_status_counts.loading_count, content="1")
  inspect(baseline.current_status_counts.ready_count, content="1")
  inspect(baseline.current_status_counts.failed_count, content="1")
  let baseline_snapshot = tracker.snapshot()
  inspect(baseline_snapshot.tracked_window_count, content="1")
  let baseline_counts = baseline_snapshot.tracked_windows[0].status_counts
  inspect(baseline_counts.record_count, content="3")
  inspect(baseline_counts.loading_count, content="1")
  inspect(baseline_counts.ready_count, content="1")
  inspect(baseline_counts.failed_count, content="1")
  inspect(baseline_counts.disposed_count, content="0")
  revision.val = 2
  records.val = [
    @render.ImageResourceRecord::ready("loading.png", width=12, height=8),
    @render.ImageResourceRecord::ready("ready.png", width=64, height=48),
    @render.ImageResourceRecord::failed("failed.png", diagnostic="decode"),
    @render.ImageResourceRecord::disposed("old.png"),
  ]
  let redraws = Ref(0)
  let result = tracker.request_redraw_if_changed(
    window_id,
    renderer,
    window_open=true,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  assert_true(
    result.status == HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(redraws.val, content="1")
  inspect(result.previous_status_counts.record_count, content="3")
  inspect(result.previous_status_counts.loading_count, content="1")
  inspect(result.current_status_counts.record_count, content="4")
  inspect(result.current_status_counts.loading_count, content="0")
  inspect(result.current_status_counts.ready_count, content="2")
  inspect(result.current_status_counts.failed_count, content="1")
  inspect(result.current_status_counts.disposed_count, content="1")
  let updated_snapshot = tracker.snapshot()
  inspect(updated_snapshot.tracked_windows[0].revision, content="2")
  let updated_counts = updated_snapshot.tracked_windows[0].status_counts
  inspect(updated_counts.record_count, content="4")
  inspect(updated_counts.loading_count, content="0")
  inspect(updated_counts.ready_count, content="2")
  inspect(updated_counts.failed_count, content="1")
  inspect(updated_counts.disposed_count, content="1")
}

///|
test "host image repaint tracker ignores stale snapshot revisions" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(6)
  let revision = Ref(5)
  let records : Ref[Array[@render.ImageResourceRecord]] = Ref([
    @render.ImageResourceRecord::ready("ready.png", width=64, height=48),
  ])
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      @render.ImageResourceSnapshot::new(
        revision=revision.val,
        records=records.val,
      )
    }),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision, content="5")
  revision.val = 3
  records.val = [@render.ImageResourceRecord::disposed("ready.png")]
  let redraws = Ref(0)
  let stale = tracker.request_redraw_if_changed(
    window_id,
    renderer,
    window_open=true,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  assert_true(
    stale.status == HostImageResourceRepaintStatus::ImageRepaintUnchanged,
  )
  inspect(stale.previous_revision, content="5")
  inspect(stale.current_revision, content="5")
  inspect(stale.previous_status_counts.ready_count, content="1")
  inspect(stale.current_status_counts.ready_count, content="1")
  inspect(stale.current_status_counts.disposed_count, content="0")
  inspect(redraws.val, content="0")
  let stale_snapshot = tracker.snapshot()
  inspect(stale_snapshot.tracked_windows[0].revision, content="5")
  let stale_counts = stale_snapshot.tracked_windows[0].status_counts
  inspect(stale_counts.ready_count, content="1")
  inspect(stale_counts.disposed_count, content="0")
  revision.val = 6
  let fresh = tracker.request_redraw_if_changed(
    window_id,
    renderer,
    window_open=true,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  assert_true(
    fresh.status == HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(fresh.previous_revision, content="5")
  inspect(fresh.current_revision, content="6")
  inspect(redraws.val, content="1")
}

///|
test "host image repaint tracker discards closed window changes" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(7)
  let revision = Ref(1)
  let records : Ref[Array[@render.ImageResourceRecord]] = Ref([
    @render.ImageResourceRecord::loading("late.png"),
  ])
  let snapshot_reads = Ref(0)
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      snapshot_reads.val = snapshot_reads.val + 1
      @render.ImageResourceSnapshot::new(
        revision=revision.val,
        records=records.val,
      )
    }),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision, content="1")
  inspect(baseline.current_status_counts.loading_count, content="1")
  inspect(snapshot_reads.val, content="1")
  revision.val = 2
  records.val = [
    @render.ImageResourceRecord::ready("late.png", width=10, height=6),
  ]
  let redraws = Ref(0)
  let result = tracker.request_redraw_if_changed(
    window_id,
    renderer,
    window_open=false,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  assert_true(
    result.status == HostImageResourceRepaintStatus::ImageRepaintDiscardedClosed,
  )
  inspect(result.previous_revision, content="1")
  inspect(result.current_revision, content="1")
  inspect(result.previous_status_counts.record_count, content="1")
  inspect(result.previous_status_counts.loading_count, content="1")
  inspect(result.current_status_counts.record_count, content="0")
  inspect(redraws.val, content="0")
  inspect(snapshot_reads.val, content="1")
  inspect(tracker.tracked_count(), content="0")
  let snapshot = tracker.snapshot()
  inspect(snapshot.tracked_window_count, content="0")
  inspect(snapshot.tracked_windows.length(), content="0")
}

///|
test "host image completion source routes native loader completions" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(8)
  let revision = Ref(1)
  let records : Ref[Array[@render.ImageResourceRecord]] = Ref([
    @render.ImageResourceRecord::loading("late.png"),
  ])
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      @render.ImageResourceSnapshot::new(
        revision=revision.val,
        records=records.val,
      )
    }),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision, content="1")
  inspect(baseline.current_status_counts.loading_count, content="1")
  let requested : Array[HostWindowId] = []
  let source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => requested.push(id),
  )
  let result = source.publish(
    window_id,
    @render.ImageResourceSnapshot::new(revision=2, records=[
      @render.ImageResourceRecord::ready("late.png", width=18, height=10),
      @render.ImageResourceRecord::failed(
        "missing.png",
        diagnostic="decode failed",
      ),
    ]),
  )
  assert_true(
    result.status == HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(result.previous_revision, content="1")
  inspect(result.current_revision, content="2")
  inspect(result.previous_status_counts.loading_count, content="1")
  inspect(result.current_status_counts.ready_count, content="1")
  inspect(result.current_status_counts.failed_count, content="1")
  inspect(requested.length(), content="1")
  assert_true(requested[0] == window_id)
  let diagnostics = source.diagnostics()
  inspect(diagnostics.publish_count, content="1")
  inspect(diagnostics.recorded_count, content="0")
  inspect(diagnostics.redraw_requested_count, content="1")
  inspect(diagnostics.unchanged_count, content="0")
  inspect(diagnostics.discarded_closed_count, content="0")
  inspect(diagnostics.tracked_window_count, content="1")
}

///|
test "host image completion source discards closed-window completions" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(9)
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      @render.ImageResourceSnapshot::new(revision=3, records=[
        @render.ImageResourceRecord::loading("closed.png"),
      ])
    }),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision, content="3")
  inspect(tracker.tracked_count(), content="1")
  let redraws = Ref(0)
  let source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=_id => false,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  let result = source.publish(
    window_id,
    @render.ImageResourceSnapshot::new(revision=4, records=[
      @render.ImageResourceRecord::ready("closed.png", width=32, height=24),
    ]),
  )
  assert_true(
    result.status == HostImageResourceRepaintStatus::ImageRepaintDiscardedClosed,
  )
  inspect(result.previous_revision, content="3")
  inspect(result.current_revision, content="3")
  inspect(result.previous_status_counts.loading_count, content="1")
  inspect(result.current_status_counts.record_count, content="0")
  inspect(redraws.val, content="0")
  inspect(tracker.tracked_count(), content="0")
  let diagnostics = source.diagnostics()
  inspect(diagnostics.publish_count, content="1")
  inspect(diagnostics.discarded_closed_count, content="1")
  inspect(diagnostics.redraw_requested_count, content="0")
  inspect(diagnostics.tracked_window_count, content="0")
}

///|
test "host image completion source ignores stale completion revisions" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(10)
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      @render.ImageResourceSnapshot::new(revision=6, records=[
        @render.ImageResourceRecord::ready("fresh.png", width=64, height=40),
      ])
    }),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision, content="6")
  let redraws = Ref(0)
  let source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  let stale = source.publish(
    window_id,
    @render.ImageResourceSnapshot::new(revision=5, records=[
      @render.ImageResourceRecord::failed(
        "fresh.png",
        diagnostic="late failure from old loader",
      ),
    ]),
  )
  assert_true(
    stale.status == HostImageResourceRepaintStatus::ImageRepaintUnchanged,
  )
  inspect(stale.previous_revision, content="6")
  inspect(stale.current_revision, content="6")
  inspect(stale.previous_status_counts.ready_count, content="1")
  inspect(stale.current_status_counts.ready_count, content="1")
  inspect(stale.current_status_counts.failed_count, content="0")
  inspect(redraws.val, content="0")
  let diagnostics = source.diagnostics()
  inspect(diagnostics.publish_count, content="1")
  inspect(diagnostics.unchanged_count, content="1")
  inspect(diagnostics.redraw_requested_count, content="0")
  inspect(diagnostics.tracked_window_count, content="1")
  let snapshot = tracker.snapshot()
  inspect(snapshot.tracked_windows[0].revision, content="6")
  inspect(snapshot.tracked_windows[0].status_counts.ready_count, content="1")
}

///|
test "host image completion source applies renderer load completions" {
  let tracker = HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(11)
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("async.png"))
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
  inspect(baseline.current_revision, content="1")
  inspect(baseline.current_status_counts.loading_count, content="1")
  let requested : Array[HostWindowId] = []
  let source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => requested.push(id),
  )
  let result = source.complete(
    window_id,
    renderer,
    @render.ImageResourceLoadCompletion::ready("async.png", width=72, height=36),
  )
  assert_true(
    result.status == HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(result.previous_revision, content="1")
  inspect(result.current_revision, content="2")
  inspect(result.previous_status_counts.loading_count, content="1")
  inspect(result.current_status_counts.ready_count, content="1")
  inspect(applied_sources.length(), content="1")
  inspect(applied_sources[0], content="async.png")
  inspect(requested.length(), content="1")
  assert_true(requested[0] == window_id)
  match lifecycle.lookup("async.png") {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageReady)
      inspect(record.width, content="72")
      inspect(record.height, content="36")
    }
    None => fail("expected applied async image record")
  }
  let diagnostics = source.diagnostics()
  inspect(diagnostics.publish_count, content="1")
  inspect(diagnostics.redraw_requested_count, content="1")
}

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
  inspect(baseline.current_revision, content="2")
  inspect(baseline.current_status_counts.loading_count, content="1")
  inspect(baseline.current_status_counts.ready_count, content="1")
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
  inspect(scheduled.snapshot_revision, content="2")
  inspect(scheduled.loading_count, content="1")
  inspect(scheduled.scheduled_count, content="1")
  inspect(scheduled.already_in_flight_count, content="0")
  inspect(started_windows.length(), content="1")
  assert_true(started_windows[0] == window_id)
  inspect(started_sources.length(), content="1")
  inspect(started_sources[0], content="late.png")
  let duplicate = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(duplicate.loading_count, content="1")
  inspect(duplicate.scheduled_count, content="0")
  inspect(duplicate.already_in_flight_count, content="1")
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
  inspect(loader_diagnostics.scheduled_count, content="1")
  inspect(loader_diagnostics.completed_count, content="1")
  inspect(loader_diagnostics.already_in_flight_count, content="1")
  inspect(loader_diagnostics.in_flight_count, content="0")
  let completion_diagnostics = completion_source.diagnostics()
  inspect(completion_diagnostics.publish_count, content="1")
  inspect(completion_diagnostics.redraw_requested_count, content="1")
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
  inspect(scheduled.scheduled_count, content="1")
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
  inspect(diagnostics.scheduled_count, content="1")
  inspect(diagnostics.completed_count, content="0")
  inspect(diagnostics.cancelled_count, content="1")
  inspect(diagnostics.in_flight_count, content="0")
  inspect(completion_source.diagnostics().publish_count, content="0")
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
    loader.schedule_loading_resources(window_id, renderer, completion_source).scheduled_count,
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
  inspect(loader.diagnostics().completed_count, content="0")
  inspect(loader.diagnostics().in_flight_count, content="0")
  inspect(completion_source.diagnostics().publish_count, content="0")
  inspect(
    loader.schedule_loading_resources(window_id, renderer, completion_source).scheduled_count,
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
  inspect(scheduled.loading_count, content="1")
  inspect(scheduled.scheduled_count, content="1")
  inspect(redraws.length(), content="0")
  match lifecycle.lookup("deferred.png") {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected deferred image record")
  }
  let requests = native_source.pending_requests()
  inspect(requests.length(), content="1")
  assert_true(requests[0].window_id == window_id)
  inspect(requests[0].source, content="deferred.png")
  let delivered = native_source.complete(
    window_id,
    @render.ImageResourceLoadCompletion::ready(
      "deferred.png",
      width=44,
      height=22,
    ),
  )
  assert_true(
    delivered.status ==
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
  inspect(native_diagnostics.requested_count, content="1")
  inspect(native_diagnostics.completed_count, content="1")
  inspect(native_diagnostics.pending_count, content="0")
  let loader_diagnostics = loader.diagnostics()
  inspect(loader_diagnostics.completed_count, content="1")
  inspect(loader_diagnostics.in_flight_count, content="0")
  inspect(completion_source.diagnostics().redraw_requested_count, content="1")
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
    loader.schedule_loading_resources(window_id, renderer, completion_source).scheduled_count,
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
    missing.status ==
    HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionMissing,
  )
  inspect(redraws.val, content="0")
  match lifecycle.lookup("cancel-source.png") {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected cancelled native source image record")
  }
  let native_diagnostics = native_source.diagnostics()
  inspect(native_diagnostics.requested_count, content="1")
  inspect(native_diagnostics.cancelled_count, content="1")
  inspect(native_diagnostics.completed_count, content="0")
  inspect(native_diagnostics.missing_completion_count, content="1")
  let loader_diagnostics = loader.diagnostics()
  inspect(loader_diagnostics.cancelled_count, content="1")
  inspect(loader_diagnostics.completed_count, content="0")
  inspect(loader_diagnostics.in_flight_count, content="0")
  inspect(completion_source.diagnostics().publish_count, content="0")
}
