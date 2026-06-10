///|
fn host_test_runtime(
  root~ : @core.View[Unit],
  size~ : @core.Size,
) -> @core.AppRuntime {
  @core.AppRuntime::new_view(root~, size~)
}

///|
fn host_test_text_field(
  value : @core.Binding[String],
  width? : Double = 240.0,
  height? : Double = 40.0,
  outlined? : Bool = false,
) -> @core.View[Unit] {
  let normal_border = if outlined {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(@core.Color::gray()),
        width=1.0,
      ),
    )
  } else {
    None
  }
  let focused_border = if outlined {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(@core.Color::blue()),
        width=2.0,
      ),
    )
  } else {
    None
  }
  @core.View::text_field(
    value~,
    placeholder="Type",
    size=@core.Size::new(width~, height~),
    font=@core.FontSpec::new(size=16.0, weight=400),
    foreground=@core.Color::black(),
    placeholder_color=@core.Color::gray(),
    background=@core.Brush::solid(@core.Color::white()),
    border=normal_border,
    focused_border~,
    cursor_color=@core.Color::blue(),
    corner_radius=0.0,
  )
}

///|
fn host_test_image_renderer(revision : Ref[Int]) -> HostWindowRenderer {
  HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      @render.ImageResourceSnapshot::new(revision=revision.val, records=[])
    }),
  )
}

///|
test "host surface metrics tracks logical physical and dpr" {
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
    scale_factor=2.0,
  )
  assert_true(metrics.logical_size == @core.Size::new(width=120.0, height=80.0))
  assert_true(
    metrics.physical_size == @core.Size::new(width=240.0, height=160.0),
  )
  inspect(metrics.scale_factor, content="2")
}

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

///|
test "host app info records shared model boundaries" {
  let info = HostAppInfo::new(
    backend=HostBackendKind::Native,
    description="native host",
  )
  assert_true(info.backend == HostBackendKind::Native)
  inspect(info.uses_shared_event_model, content="true")
  inspect(info.uses_shared_surface_model, content="true")
  inspect(info.uses_shared_input_model, content="true")
}

///|
test "host capability summary combines service input and window readiness" {
  let summary = HostCapabilitySummary::from_contracts(
    info=HostAppInfo::new(
      backend=HostBackendKind::Web,
      description="browser host",
    ),
    services=HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      open_url=true,
      system_theme=true,
    ),
    input=HostInputCapabilities::new(
      pointer=true,
      keyboard=true,
      focus=true,
      text_input=true,
      drag_drop=true,
    ),
    label="Web host",
    window_lifecycle=true,
    multi_window=true,
    async_services=true,
  )
  inspect(summary.backend.label(), content="Web")
  inspect(summary.label, content="Web host")
  inspect(summary.service_count(), content="4")
  inspect(summary.input_count(), content="6")
  inspect(summary.has_required_app_basics(), content="true")
  inspect(summary.multi_window, content="true")
  inspect(summary.async_services, content="true")
  inspect(summary.services.enabled_labels().length(), content="4")
  assert_true(summary.input.enabled_labels().any(label => label == "drag/drop"))
  let preflight = summary.preflight_fields()
  assert_true(preflight.contains("host=Web host"))
  assert_true(
    preflight.contains(
      "host_services=clipboard,file dialogs,open URL,system theme",
    ),
  )
  assert_true(preflight.contains("clipboard=ready"))
  assert_true(preflight.contains("menu_service=gap"))
  assert_true(preflight.contains("file_dialogs=ready"))
  assert_true(preflight.contains("open_url=ready"))
  assert_true(preflight.contains("system_theme=ready"))
  assert_true(preflight.contains("async_services=ready"))
  assert_true(preflight.contains("window_lifecycle=ready"))
  assert_true(preflight.contains("multi_window=ready"))
  assert_true(preflight.contains("text_input=ready"))
  assert_true(preflight.contains("ime=gap"))
  assert_true(preflight.contains("drag_drop=ready"))
  assert_true(preflight.contains("native_context_menu=gap"))
  assert_true(preflight.contains("host_modal=ready"))
  assert_true(preflight.contains("native_accessibility=gap"))
}

///|
test "host capability summary reports unavailable host" {
  let summary = HostCapabilitySummary::unavailable()
  inspect(summary.backend.label(), content="Test")
  inspect(summary.service_count(), content="0")
  inspect(summary.input_count(), content="0")
  inspect(summary.has_required_app_basics(), content="false")
  inspect(summary.services.enabled_labels().length(), content="0")
  let preflight = summary.preflight_fields()
  assert_true(preflight.contains("host=Unavailable host"))
  assert_true(preflight.contains("host_services=none"))
  assert_true(preflight.contains("host_input=none"))
  assert_true(preflight.contains("clipboard=gap"))
  assert_true(preflight.contains("window_lifecycle=gap"))
  assert_true(preflight.contains("native_accessibility=gap"))
}

///|
test "input host owns capabilities focus modifiers and text input gating" {
  let input = InputHostState::new()
  let capabilities = input.capabilities()
  inspect(capabilities.pointer, content="true")
  inspect(capabilities.scroll, content="true")
  inspect(capabilities.ime, content="false")
  inspect(capabilities.drag_drop, content="false")
  inspect(input.coordinate_policy().scale_factor_applied, content="true")
  match input.insert_text("a") {
    None => ()
    Some(_) => fail("unfocused input host should not emit text")
  }
  match input.focus_event(focused=true) {
    Some(HostEvent::Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
  input.set_modifiers(@core.KeyModifiers::new(shift=true))
  let key_event = input.keyboard_event(key="A", text=Some("A"))
  match key_event {
    Some(HostEvent::Keyboard(event)) => {
      inspect(event.key, content="A")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
  match input.insert_text("A") {
    Some(HostEvent::TextInput(@core.TextInputEvent::InsertText(text))) =>
      inspect(text, content="A")
    _ => fail("expected focused text input")
  }
  match input.focus_event(focused=false) {
    Some(HostEvent::Focus({ focused: false, .. })) => ()
    _ => fail("expected blur event")
  }
  match input.insert_text("b") {
    None => ()
    Some(_) => fail("blurred input host should not emit text")
  }
}

///|
test "host converts window drag drop events to logical core events" {
  let event = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::DragDropped(
      ["/tmp/note.md"],
      @dpi.PhysicalPositionF64::PhysicalPositionF64(24.0, 48.0),
    ),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::none(),
    scale_factor=2.0,
  )
  match event {
    Some(
      HostEvent::DragDrop(
        {
          phase: @core.DragDropPhase::Dropped,
          paths,
          position: Some({ x: 12.0, y: 24.0 }),
        }
      )
    ) => inspect(paths[0], content="/tmp/note.md")
    _ => fail("expected logical file drop")
  }
  match event {
    Some(host_event) =>
      match host_event.to_core() {
        Some(
          @core.AppEvent::DragDrop({ phase: @core.DragDropPhase::Dropped, .. })
        ) => ()
        _ => fail("expected drag drop app event")
      }
    _ => fail("expected drag drop app event")
  }
  let left = window_event_to_host(
    @window_core.WindowEvent::DragLeft(None),
    @core.Point::new(x=0.0, y=0.0),
  )
  match left {
    Some(
      HostEvent::DragDrop(
        { phase: @core.DragDropPhase::Left, position: None, .. }
      )
    ) => ()
    _ => fail("expected drag left without position")
  }
}

///|
test "host recognizes secondary pointer context menu requests" {
  let right_down = @window_core.WindowEvent::PointerButton(
    None,
    @window_core.ElementState::Pressed,
    @dpi.PhysicalPositionF64::PhysicalPositionF64(3.0, 4.0),
    true,
    @window_core.ButtonSource::Mouse(@window_core.MouseButton::Right),
  )
  inspect(window_event_is_context_menu_trigger(right_down), content="true")
  inspect(window_event_is_context_menu_button(right_down), content="true")
  let right_up = @window_core.WindowEvent::PointerButton(
    None,
    @window_core.ElementState::Released,
    @dpi.PhysicalPositionF64::PhysicalPositionF64(3.0, 4.0),
    true,
    @window_core.ButtonSource::Mouse(@window_core.MouseButton::Right),
  )
  inspect(window_event_is_context_menu_trigger(right_up), content="false")
  inspect(window_event_is_context_menu_button(right_up), content="true")
  let left_down = @window_core.WindowEvent::PointerButton(
    None,
    @window_core.ElementState::Pressed,
    @dpi.PhysicalPositionF64::PhysicalPositionF64(3.0, 4.0),
    true,
    @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
  )
  inspect(window_event_is_context_menu_button(left_down), content="false")
}

///|
test "surface host resizes through host event" {
  let surface = SurfaceHostState::new(
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=10.0, height=10.0),
    ),
    owns_surface=true,
  )
  let event = surface.resize(
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=20.0, height=12.0),
      scale_factor=2.0,
    ),
  )
  match event {
    HostEvent::Resized(metrics) => {
      assert_true(
        surface.logical_size() == @core.Size::new(width=20.0, height=12.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=40.0, height=24.0),
      )
      inspect(surface.owns_surface, content="true")
      inspect(surface.can_reconfigure, content="true")
    }
    _ => fail("expected resize event")
  }
}

///|
test "window theme change maps to host theme event" {
  let event = window_event_to_host(
    @window_core.WindowEvent::ThemeChanged(@window_core.Theme::Dark),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(HostEvent::ThemeChanged(@core.ColorScheme::Dark)) => ()
    _ => fail("expected dark host theme event")
  }
  match event.unwrap().to_core() {
    None => ()
    Some(_) => fail("theme changes are handled by the host runtime driver")
  }
}

///|
test "host window registry tracks primary focus resize and close lifecycle" {
  let registry = HostWindowRegistry::new()
  let first = registry.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  let second = registry.open(
    title="Inspector",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=480.0),
    ),
  )
  inspect(registry.open_window_count(), content="2")
  match registry.primary_window() {
    Some({ id, title, .. }) => {
      assert_true(id == first)
      inspect(title, content="Main")
    }
    None => fail("expected first window to become primary")
  }
  assert_true(registry.focus(second))
  match registry.focused_window() {
    Some({ id, phase, .. }) => {
      assert_true(id == second)
      assert_true(phase == HostWindowLifecyclePhase::WindowFocused)
    }
    None => fail("expected focused window")
  }
  assert_true(
    registry.resize(
      second,
      HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=400.0, height=500.0),
        scale_factor=2.0,
      ),
    ),
  )
  match registry.lookup(second) {
    Some({ metrics, .. }) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=400.0, height=500.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=800.0, height=1000.0),
      )
    }
    None => fail("expected resized window")
  }
  assert_true(registry.close(first))
  match registry.primary_window() {
    Some({ id, .. }) => assert_true(id == second)
    None => fail("expected primary reassigned after close")
  }
  inspect(registry.remove_closed(), content="1")
  inspect(registry.open_window_count(), content="1")
  inspect(
    registry.resize(
      first,
      HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=1.0, height=1.0),
      ),
    ),
    content="false",
  )
  inspect(registry.close(first), content="false")
}

///|
test "host window registry applies shared lifecycle host events" {
  let registry = HostWindowRegistry::new()
  let window_id = registry.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  assert_true(
    registry.apply_host_event(
      window_id,
      HostEvent::Resized(
        HostSurfaceMetrics::from_logical(
          size=@core.Size::new(width=640.0, height=480.0),
          scale_factor=2.0,
        ),
      ),
    ),
  )
  match registry.lookup(window_id) {
    Some({ metrics, .. }) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=1280.0, height=960.0),
      )
    }
    None => fail("expected lifecycle window")
  }
  assert_true(
    registry.apply_host_event(
      window_id,
      HostEvent::Focus(HostFocusEvent::new(focused=true)),
    ),
  )
  match registry.focused_window() {
    Some({ id, .. }) => assert_true(id == window_id)
    None => fail("expected focused window")
  }
  assert_true(
    registry.apply_host_event(
      window_id,
      HostEvent::Focus(HostFocusEvent::new(focused=false)),
    ),
  )
  match registry.lookup(window_id) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowVisible)
    None => fail("expected blurred window")
  }
  assert_true(registry.apply_host_event(window_id, HostEvent::CloseRequested))
  match registry.lookup(window_id) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowCloseRequested)
    None => fail("expected close-requested window")
  }
  inspect(
    registry.apply_host_event(window_id, HostEvent::RedrawRequested),
    content="false",
  )
}

///|
test "host window open requests default to main scene" {
  let request = HostWindowOpenRequest::new(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  inspect(request.scene.scene_id, content="main")
  inspect(request.scene.payload, content="")
}

///|
test "host window request queue drains platform-neutral window requests" {
  let queue = HostWindowRequestQueue::new()
  inspect(queue.is_empty(), content="true")
  queue.open_window(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="right-pane"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
    primary=true,
  )
  let window_id = HostWindowId::new(7)
  queue.focus_window(window_id)
  queue.resize_window(
    window_id,
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  queue.minimize_window(window_id)
  queue.show_window(window_id)
  queue.set_primary_window(window_id)
  queue.close_window(window_id)
  inspect(queue.pending_count(), content="7")
  let requests = queue.drain()
  inspect(queue.pending_count(), content="0")
  match requests[0] {
    HostWindowRequest::OpenWindow({ title, scene, primary, .. }) => {
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="right-pane")
      inspect(primary, content="true")
    }
    _ => fail("expected open window request")
  }
  match requests[1] {
    HostWindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected focus window request")
  }
  match requests[2] {
    HostWindowRequest::ResizeWindow(id, metrics) => {
      assert_true(id == window_id)
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
    }
    _ => fail("expected resize window request")
  }
  match requests[3] {
    HostWindowRequest::MinimizeWindow(id) => assert_true(id == window_id)
    _ => fail("expected minimize window request")
  }
  match requests[4] {
    HostWindowRequest::ShowWindow(id) => assert_true(id == window_id)
    _ => fail("expected show window request")
  }
  match requests[5] {
    HostWindowRequest::SetPrimaryWindow(id) => assert_true(id == window_id)
    _ => fail("expected set primary window request")
  }
  match requests[6] {
    HostWindowRequest::CloseWindow(id) => assert_true(id == window_id)
    _ => fail("expected close window request")
  }
}

///|
test "host window request queue records ordered platform completions" {
  let queue = HostWindowRequestQueue::new()
  queue.open_window(
    title="Inspector",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  let window_id = HostWindowId::new(2)
  queue.focus_window(window_id)
  let drained = queue.drain()
  queue.record_result(
    drained[0],
    HostWindowRequestResult::WindowRejected(
      "open window requests require multi-window host support",
    ),
  )
  queue.record_result(
    drained[1],
    HostWindowRequestResult::WindowUpdated(window_id),
  )
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="2")
  let completed = queue.drain_completed()
  inspect(queue.completed_count(), content="0")
  match completed[0].request {
    HostWindowRequest::OpenWindow({ title, .. }) =>
      inspect(title, content="Inspector")
    _ => fail("expected completed open-window request")
  }
  match completed[0].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(
        message,
        content="open window requests require multi-window host support",
      )
    _ => fail("expected completed open-window rejection")
  }
  match completed[1].request {
    HostWindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected completed focus-window request")
  }
  match completed[1].result {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == window_id)
    _ => fail("expected completed focus-window update")
  }
}

///|
test "host window request queue drains with shared completion handler" {
  let queue = HostWindowRequestQueue::new()
  let existing = HostWindowId::new(1)
  queue.focus_window(existing)
  queue.close_window(HostWindowId::new(404))
  let completions = queue.drain_with_handler(request => {
    match request {
      HostWindowRequest::FocusWindow(id) =>
        HostWindowRequestResult::WindowUpdated(id)
      HostWindowRequest::CloseWindow(_) =>
        HostWindowRequestResult::WindowRejected("missing window")
      _ => HostWindowRequestResult::WindowRejected("unexpected request")
    }
  })
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="2")
  inspect(completions.length(), content="2")
  match completions[0].result {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == existing)
    _ => fail("expected focus completion")
  }
  match completions[1].request {
    HostWindowRequest::CloseWindow(id) => inspect(id.value, content="404")
    _ => fail("expected close request completion")
  }
  match queue.drain_completed()[1].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="missing window")
    _ => fail("expected recorded close rejection")
  }
  inspect(queue.completed_count(), content="0")
}

///|
test "host window commands wrap queue request helpers" {
  let commands = HostWindowCommands::new()
  inspect(commands.is_empty(), content="true")
  commands.open(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="debug"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
    primary=true,
  )
  let window_id = HostWindowId::new(9)
  commands.focus(window_id)
  commands.resize(
    window_id,
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  commands.minimize(window_id)
  commands.show(window_id)
  commands.set_primary(window_id)
  commands.close(window_id)
  inspect(commands.pending_count(), content="7")
  let requests = commands.drain()
  inspect(commands.pending_count(), content="0")
  match requests[0] {
    HostWindowRequest::OpenWindow({ title, scene, primary, .. }) => {
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="debug")
      inspect(primary, content="true")
    }
    _ => fail("expected open request")
  }
  match requests[1] {
    HostWindowRequest::FocusWindow(id) => assert_true(id == window_id)
    _ => fail("expected focus request")
  }
  match requests[2] {
    HostWindowRequest::ResizeWindow(id, metrics) => {
      assert_true(id == window_id)
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
    }
    _ => fail("expected resize request")
  }
  match requests[6] {
    HostWindowRequest::CloseWindow(id) => assert_true(id == window_id)
    _ => fail("expected close request")
  }
}

///|
test "host window commands drain to registry with ordered completions" {
  let registry = HostWindowRegistry::new()
  let commands = HostWindowCommands::new()
  commands.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=480.0, height=320.0),
    ),
  )
  let missing = HostWindowId::new(404)
  commands.focus(missing)
  let completions = commands.drain_to_registry(registry)
  inspect(commands.pending_count(), content="0")
  inspect(commands.completed_count(), content="2")
  inspect(completions.length(), content="2")
  match completions[0].result {
    HostWindowRequestResult::WindowOpened(id) => inspect(id.value, content="1")
    _ => fail("expected opened window")
  }
  match completions[1].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 404")
    _ => fail("expected missing-window rejection")
  }
  inspect(registry.open_window_count(), content="1")
  let completed = commands.drain_completed()
  inspect(completed.length(), content="2")
  inspect(commands.completed_count(), content="0")
}

///|
test "host window commands can drain through runtime slots" {
  let registry = HostWindowRegistry::new()
  let opened = registry.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  let slots = HostWindowRuntimeSlots::new()
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  assert_true(
    slots.insert_from_registry(
      registry,
      opened,
      driver=HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    ),
  )
  let commands = HostWindowCommands::new()
  commands.resize(
    opened,
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  commands.close(HostWindowId::new(404))
  let completions = commands.drain_to_runtime_slots(registry, slots)
  inspect(completions.length(), content="2")
  match completions[0].result {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == opened)
    _ => fail("expected resize update")
  }
  match slots.lookup(opened) {
    Some({ record: { metrics, .. }, .. }) =>
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
    None => fail("expected synced runtime slot")
  }
  match completions[1].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot close window: 404")
    _ => fail("expected close rejection")
  }
}

///|
test "host platform window map routes platform window ids" {
  let map = HostPlatformWindowMap::new()
  inspect(map.is_empty(), content="true")
  let platform_main = @window_core.WindowId::from_raw(11)
  let platform_inspector = @window_core.WindowId::from_raw(12)
  let main = HostWindowId::new(1)
  let inspector = HostWindowId::new(2)
  assert_true(map.bind(platform_id=platform_main, host_id=main))
  inspect(
    map.bind(platform_id=platform_main, host_id=inspector),
    content="false",
  )
  inspect(
    map.bind(platform_id=platform_inspector, host_id=main),
    content="false",
  )
  assert_true(map.bind(platform_id=platform_inspector, host_id=inspector))
  inspect(map.count(), content="2")
  match map.lookup_host(platform_main) {
    Some(id) => assert_true(id == main)
    None => fail("expected main host id")
  }
  match map.lookup_platform(inspector) {
    Some(id) => assert_true(id == platform_inspector)
    None => fail("expected inspector platform id")
  }
  match map.remove_host(main) {
    Some(id) => assert_true(id == platform_main)
    None => fail("expected removed main platform id")
  }
  match map.lookup_host(platform_main) {
    Some(_) => fail("expected removed main host lookup")
    None => ()
  }
  match map.remove_platform(platform_inspector) {
    Some(id) => assert_true(id == inspector)
    None => fail("expected removed inspector host id")
  }
  inspect(map.is_empty(), content="true")
}

///|
test "host window scene resolver maps open requests to runtimes" {
  let resolver = HostWindowSceneResolver::new(resolve=request => {
    if request.scene.scene_id == "inspector" {
      HostWindowSceneResolution::SceneResolved(
        HostWindowSceneInstance::new(
          request~,
          runtime=host_test_runtime(
            root=@core.View::empty(),
            size=request.metrics.logical_size,
          ),
        ),
      )
    } else {
      HostWindowSceneResolution::SceneRejected(
        "unknown window scene: " + request.scene.scene_id,
      )
    }
  })
  let request = HostWindowOpenRequest::new(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
  )
  match resolver.resolve(request) {
    HostWindowSceneResolution::SceneResolved({ request, runtime }) => {
      inspect(request.title, content="Inspector")
      inspect(request.scene.payload, content="outline")
      assert_true(runtime.size() == @core.Size::new(width=360.0, height=480.0))
    }
    _ => fail("expected resolved inspector scene")
  }
  let unknown = HostWindowOpenRequest::new(
    title="Unknown",
    scene=HostWindowScene::new(scene_id="unknown"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match resolver.resolve(unknown) {
    HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="unknown window scene: unknown")
    _ => fail("expected unknown scene rejection")
  }
  match HostWindowSceneResolver::unavailable().resolve(request) {
    HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected unavailable resolver rejection")
  }
}

///|
test "host window registry resolves scenes before registering opened windows" {
  let registry = HostWindowRegistry::new()
  let resolver = HostWindowSceneResolver::new(resolve=request => {
    if request.scene.scene_id == "inspector" {
      HostWindowSceneResolution::SceneResolved(
        HostWindowSceneInstance::new(
          request~,
          runtime=host_test_runtime(
            root=@core.View::empty(),
            size=request.metrics.logical_size,
          ),
        ),
      )
    } else {
      HostWindowSceneResolution::SceneRejected(
        "unknown window scene: " + request.scene.scene_id,
      )
    }
  })
  let rejected = HostWindowOpenRequest::new(
    title="Unknown",
    scene=HostWindowScene::new(scene_id="unknown"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match registry.resolve_open_request(rejected, resolver) {
    HostWindowOpenResolution::OpenRejected(message) =>
      inspect(message, content="unknown window scene: unknown")
    _ => fail("expected rejected window scene")
  }
  inspect(registry.open_window_count(), content="0")

  let request = HostWindowOpenRequest::new(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
    primary=true,
  )
  match registry.resolve_open_request(request, resolver) {
    HostWindowOpenResolution::OpenResolved({ id, record, instance }) => {
      assert_true(id == record.id)
      inspect(record.title, content="Inspector")
      inspect(record.scene.scene_id, content="inspector")
      inspect(record.primary, content="true")
      assert_true(
        instance.runtime.size() == @core.Size::new(width=360.0, height=480.0),
      )
      let redraws = Ref(0)
      let slot = HostWindowRuntimeSlot::from_resolved_open(
        { id, record, instance },
        schedule_redraw=() => redraws.val = redraws.val + 1,
      )
      assert_true(slot.id == id)
      inspect(slot.record.scene.payload, content="outline")
      assert_true(
        slot.driver.size() == @core.Size::new(width=360.0, height=480.0),
      )
      slot.driver.request_redraw()
      inspect(redraws.val, content="1")
      let driver_backed = HostWindowRuntimeSlot::from_driver(
        record~,
        driver=slot.driver,
      )
      assert_true(driver_backed.id == id)
      assert_true(driver_backed.driver.size() == slot.driver.size())
    }
    _ => fail("expected resolved open window")
  }
  inspect(registry.open_window_count(), content="1")
}

///|
test "host window runtime slots manage multiple window drivers" {
  let registry = HostWindowRegistry::new()
  let slots = HostWindowRuntimeSlots::new()
  inspect(slots.is_empty(), content="true")
  let resolver = HostWindowSceneResolver::new(resolve=request => {
    HostWindowSceneResolution::SceneResolved(
      HostWindowSceneInstance::new(
        request~,
        runtime=host_test_runtime(
          root=@core.View::empty(),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let main_request = HostWindowOpenRequest::new(
    title="Main",
    scene=HostWindowScene::main(),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=800.0, height=600.0),
    ),
    primary=true,
  )
  let main_redraws = Ref(0)
  let main_slot = match registry.resolve_open_request(main_request, resolver) {
    HostWindowOpenResolution::OpenResolved(resolved) =>
      HostWindowRuntimeSlot::from_resolved_open(resolved, schedule_redraw=() => {
        main_redraws.val = main_redraws.val + 1
      })
    _ => fail("expected main runtime slot")
  }
  assert_true(
    slots.insert_from_registry(registry, main_slot.id, driver=main_slot.driver),
  )
  inspect(
    slots.insert_from_registry(registry, main_slot.id, driver=main_slot.driver),
    content="false",
  )

  let inspector_request = HostWindowOpenRequest::new(
    title="Inspector",
    scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
  )
  let inspector_redraws = Ref(0)
  let inspector_slot = match
    registry.resolve_open_request(inspector_request, resolver) {
    HostWindowOpenResolution::OpenResolved(resolved) =>
      HostWindowRuntimeSlot::from_resolved_open(resolved, schedule_redraw=() => {
        inspector_redraws.val = inspector_redraws.val + 1
      })
    _ => fail("expected inspector runtime slot")
  }
  assert_true(slots.insert(inspector_slot))
  inspect(slots.count(), content="2")
  match slots.primary_slot() {
    Some({ record: { title, .. }, .. }) => inspect(title, content="Main")
    None => fail("expected primary slot")
  }

  assert_true(
    slots.apply_host_event(
      registry,
      inspector_slot.id,
      HostEvent::Focus(HostFocusEvent::new(focused=true)),
    ),
  )
  match slots.focused_slot() {
    Some({ id, record, .. }) => {
      assert_true(id == inspector_slot.id)
      assert_true(record.phase == HostWindowLifecyclePhase::WindowFocused)
    }
    None => fail("expected focused inspector slot")
  }
  match slots.lookup(main_slot.id) {
    Some({ record: { phase, .. }, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowVisible)
    None => fail("expected main slot")
  }
  inspect(
    slots.apply_host_event(
      registry,
      inspector_slot.id,
      HostEvent::RedrawRequested,
    ),
    content="false",
  )
  match slots.lookup(inspector_slot.id) {
    Some(slot) => slot.driver.request_redraw()
    None => fail("expected inspector slot")
  }
  inspect(inspector_redraws.val, content="1")

  match
    slots.apply_request(
      registry,
      HostWindowRequest::ResizeWindow(
        inspector_slot.id,
        HostSurfaceMetrics::from_logical(
          size=@core.Size::new(width=420.0, height=500.0),
        ),
      ),
    ) {
    HostWindowRequestResult::WindowUpdated(id) =>
      assert_true(id == inspector_slot.id)
    _ => fail("expected resize request to update inspector slot")
  }
  match slots.lookup(inspector_slot.id) {
    Some({ record: { metrics, .. }, .. }) =>
      assert_true(
        metrics.logical_size == @core.Size::new(width=420.0, height=500.0),
      )
    None => fail("expected resized inspector slot")
  }
  match
    slots.apply_request(
      registry,
      HostWindowRequest::SetPrimaryWindow(inspector_slot.id),
    ) {
    HostWindowRequestResult::WindowUpdated(id) =>
      assert_true(id == inspector_slot.id)
    _ => fail("expected set-primary request to update inspector slot")
  }
  match slots.lookup(main_slot.id) {
    Some({ record: { primary, .. }, .. }) => inspect(primary, content="false")
    None => fail("expected main slot")
  }
  match slots.primary_slot() {
    Some({ id, record: { primary, .. }, .. }) => {
      assert_true(id == inspector_slot.id)
      inspect(primary, content="true")
    }
    None => fail("expected primary inspector slot")
  }
  match
    slots.apply_request(
      registry,
      HostWindowRequest::FocusWindow(HostWindowId::new(404)),
    ) {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 404")
    _ => fail("expected missing request rejection")
  }

  assert_true(registry.close(main_slot.id))
  assert_true(slots.sync_from_registry(registry, main_slot.id))
  inspect(slots.remove_closed(), content="1")
  inspect(slots.count(), content="1")
  match slots.remove(inspector_slot.id) {
    Some(slot) => inspect(slot.record.title, content="Inspector")
    None => fail("expected removed inspector slot")
  }
  inspect(slots.count(), content="0")
  inspect(
    slots.insert_from_registry(
      registry,
      HostWindowId::new(404),
      driver=main_slot.driver,
    ),
    content="false",
  )
  inspect(
    slots.sync_from_registry(registry, HostWindowId::new(404)),
    content="false",
  )
  inspect(main_redraws.val, content="0")
}

///|
test "host runtime driver exposes runtime state for platform slots" {
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let dark = runtime.environment().with_color_scheme(@core.ColorScheme::Dark)
  driver.set_environment(dark)
  assert_true(driver.environment().color_scheme == @core.ColorScheme::Dark)
  assert_true(runtime.environment().color_scheme == @core.ColorScheme::Dark)
  driver.set_text_system(@core.TextSystem::fallback())
  assert_true(driver.focused_text_input() == runtime.focused_text_input())
}

///|
test "host event source subscription dispatches mapped host events" {
  let source = HostEventSource::new()
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=240.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
      subscriptions=_model => {
        source.subscription(key="host:event", label="Host event adapter", map=event => {
          match event {
            HostEvent::ThemeChanged(_) => Some("theme changed")
            _ => None
          }
        })
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  inspect(initial.active_subscriptions[0].key, content="host:event")
  inspect(initial.active_subscriptions[0].kind, content="host-event")
  inspect(initial.active_subscriptions[0].label, content="Host event adapter")
  inspect(source.publish(HostEvent::RedrawRequested), content="1")
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="0")
  inspect(
    source.publish(HostEvent::ThemeChanged(@core.ColorScheme::Dark)),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="1")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text, .. }) &&
      text == "theme changed"
    }),
  )
}

///|
test "host event source subscription cleanup removes late publishers" {
  let source = HostEventSource::new()
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=240.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
      subscriptions=_model => {
        source.subscription(key="host:event", label="Host event adapter", map=event => {
          match event {
            HostEvent::ThemeChanged(_) => Some("theme changed")
            _ => None
          }
        })
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  runtime.destroy()
  inspect(source.active_handler_count(), content="0")
  inspect(
    source.publish(HostEvent::ThemeChanged(@core.ColorScheme::Dark)),
    content="0",
  )
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.cancelled_subscription_count, content="1")
  inspect(destroyed.ignored_subscription_dispatch_count, content="0")
}

///|
test "host platform event sources publish host and window subscriptions" {
  let sources = HostPlatformEventSources::new()
  let window_id = HostWindowId::new(9)
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=280.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
      subscriptions=_model => {
        @core.Subscription::batch([
          sources
          .host_events()
          .subscription(key="host:event", label="Host event adapter", map=event => {
            match event {
              HostEvent::ThemeChanged(_) => Some("host theme")
              _ => None
            }
          }),
          sources
          .window_events()
          .subscription(
            key="host:window-event",
            label="Host window event adapter",
            map=event => {
              if event.window_id == window_id {
                Some("window \{event.window_id.value.to_string()}")
              } else {
                None
              }
            },
          ),
        ])
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(sources.host_events().active_handler_count(), content="1")
  inspect(sources.window_events().active_handler_count(), content="1")
  let result = sources.publish(
    window_id~,
    event=HostEvent::ThemeChanged(@core.ColorScheme::Dark),
  )
  inspect(result.host_event_count, content="1")
  inspect(result.window_event_count, content="1")
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="2")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text, .. }) && text == "window 9"
    }),
  )
}

///|
test "host window event source subscription dispatches mapped window events" {
  let source = HostWindowEventSource::new()
  let target = HostWindowId::new(7)
  let other = HostWindowId::new(8)
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=240.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
      subscriptions=_model => {
        source.subscription(
          key="host:window-event",
          label="Host window event adapter",
          map=window_event => {
            if window_event.window_id == target {
              match window_event.event {
                HostEvent::CloseRequested =>
                  Some(
                    "window \{window_event.window_id.value.to_string()} close",
                  )
                _ => None
              }
            } else {
              None
            }
          },
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  inspect(initial.active_subscriptions[0].key, content="host:window-event")
  inspect(initial.active_subscriptions[0].kind, content="window-event")
  inspect(
    initial.active_subscriptions[0].label,
    content="Host window event adapter",
  )
  inspect(
    source.publish(window_id=other, event=HostEvent::CloseRequested),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="0")
  inspect(
    source.publish(window_id=target, event=HostEvent::RedrawRequested),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="0")
  inspect(
    source.publish(window_id=target, event=HostEvent::CloseRequested),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count, content="1")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text, .. }) &&
      text == "window 7 close"
    }),
  )
}

///|
test "host window event source subscription cleanup removes late publishers" {
  let source = HostWindowEventSource::new()
  let window_id = HostWindowId::new(1)
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=240.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
      subscriptions=_model => {
        source.subscription(
          key="host:window-event",
          label="Host window event adapter",
          map=_window_event => Some("window event"),
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  runtime.destroy()
  inspect(source.active_handler_count(), content="0")
  inspect(
    source.publish(window_id~, event=HostEvent::CloseRequested),
    content="0",
  )
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.cancelled_subscription_count, content="1")
  inspect(destroyed.ignored_subscription_dispatch_count, content="0")
}

///|
test "host route source subscription dispatches mapped route events" {
  let source = HostRouteSource::new()
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=280.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
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
  inspect(initial.active_subscriptions[0].key, content="host:route")
  inspect(initial.active_subscriptions[0].kind, content="route-event")
  inspect(initial.active_subscriptions[0].label, content="Host route adapter")
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
    location=@core.RouteLocation::parse("/docs?tab=api&lang=moonbit"),
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
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=240.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
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
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=240.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
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
  inspect(initial.active_subscriptions[0].key, content="host:timer")
  inspect(initial.active_subscriptions[0].kind, content="timer")
  inspect(initial.active_subscriptions[0].label, content="Host timer adapter")
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
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => {
        @core.View::text(
          text=model,
          size=@core.Size::new(width=240.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
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

///|
test "host window registry applies platform-neutral window requests" {
  let registry = HostWindowRegistry::new()
  let main = registry.open(
    title="Main",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=800.0, height=600.0),
    ),
  )
  let request = HostWindowRequest::OpenWindow(
    HostWindowOpenRequest::new(
      title="Inspector",
      scene=HostWindowScene::new(scene_id="inspector", payload="outline"),
      metrics=HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=320.0, height=600.0),
      ),
      primary=true,
    ),
  )
  let inspector = match registry.apply_request(request) {
    HostWindowRequestResult::WindowOpened(id) => id
    _ => fail("expected opened inspector window")
  }
  match registry.primary_window() {
    Some({ id, title, scene, .. }) => {
      assert_true(id == inspector)
      inspect(title, content="Inspector")
      inspect(scene.scene_id, content="inspector")
      inspect(scene.payload, content="outline")
    }
    None => fail("expected primary inspector window")
  }
  match registry.apply_request(HostWindowRequest::FocusWindow(main)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected focus request to update main window")
  }
  match registry.focused_window() {
    Some({ id, .. }) => assert_true(id == main)
    None => fail("expected focused main window")
  }
  let resized = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=900.0, height=700.0),
    scale_factor=2.0,
  )
  match registry.apply_request(HostWindowRequest::ResizeWindow(main, resized)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected resize request to update main window")
  }
  match registry.lookup(main) {
    Some({ metrics, .. }) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=900.0, height=700.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=1800.0, height=1400.0),
      )
    }
    None => fail("expected resized main window")
  }
  match registry.apply_request(HostWindowRequest::MinimizeWindow(main)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected minimize request to update main window")
  }
  match registry.lookup(main) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowMinimized)
    None => fail("expected minimized main window")
  }
  match registry.apply_request(HostWindowRequest::ShowWindow(main)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected show request to update main window")
  }
  match registry.lookup(main) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowVisible)
    None => fail("expected visible main window")
  }
  match registry.apply_request(HostWindowRequest::SetPrimaryWindow(main)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == main)
    _ => fail("expected set-primary request to update main window")
  }
  match registry.primary_window() {
    Some({ id, title, .. }) => {
      assert_true(id == main)
      inspect(title, content="Main")
    }
    None => fail("expected primary main window")
  }
  match registry.apply_request(HostWindowRequest::CloseWindow(inspector)) {
    HostWindowRequestResult::WindowUpdated(id) => assert_true(id == inspector)
    _ => fail("expected close request to update inspector")
  }
  match registry.lookup(inspector) {
    Some({ phase, .. }) =>
      assert_true(phase == HostWindowLifecyclePhase::WindowCloseRequested)
    None => fail("expected inspector close request phase")
  }
  match
    registry.apply_request(
      HostWindowRequest::FocusWindow(HostWindowId::new(404)),
    ) {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 404")
    _ => fail("expected rejected missing window request")
  }
}

///|
test "host window lifecycle rejects queued commands after platform close" {
  let registry = HostWindowRegistry::new()
  let closed = registry.open(
    title="Inspector",
    metrics=HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  assert_true(registry.close(closed))
  match registry.lookup(closed) {
    Some({ phase, primary, .. }) => {
      assert_true(phase == HostWindowLifecyclePhase::WindowClosed)
      inspect(primary, content="false")
    }
    None => fail("expected closed window record before cleanup")
  }

  let queue = HostWindowRequestQueue::new()
  queue.focus_window(closed)
  queue.resize_window(
    closed,
    HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
    ),
  )
  queue.minimize_window(closed)
  queue.show_window(closed)
  queue.set_primary_window(closed)
  queue.close_window(closed)

  let completions = queue.drain_with_handler(request => {
    registry.apply_request(request)
  })
  inspect(queue.pending_count(), content="0")
  inspect(completions.length(), content="6")
  inspect(queue.completed_count(), content="6")
  match completions[0].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot focus window: 1")
    _ => fail("expected focus rejection for closed window")
  }
  match completions[1].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot resize window: 1")
    _ => fail("expected resize rejection for closed window")
  }
  match completions[5].result {
    HostWindowRequestResult::WindowRejected(message) =>
      inspect(message, content="cannot close window: 1")
    _ => fail("expected close rejection for closed window")
  }
  inspect(registry.remove_closed(), content="1")
  match registry.lookup(closed) {
    Some(_) => fail("expected closed window cleanup")
    None => ()
  }
}

///|
test "host service bridge gates typed platform requests by capability" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        Clipboard(WriteText(_)) => HostServiceResponse::ClipboardWritten
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("copied")
        ShowMenu(commands) =>
          if commands.length() > 0 {
            HostServiceResponse::MenuCommand(commands[0].intent)
          } else {
            HostServiceResponse::Unavailable("empty menu")
          }
        QuerySystemTheme =>
          HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        _ => HostServiceResponse::Unavailable("not implemented")
      }
    },
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::ReadText),
    ) {
    HostServiceResponse::ClipboardText(text) => inspect(text, content="copied")
    _ => fail("expected clipboard text")
  }
  match
    bridge.dispatch(
      HostServiceRequest::ShowMenu([
        @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      ]),
    ) {
    HostServiceResponse::MenuCommand(@core.CommandIntent::Copy) => ()
    _ => fail("expected selected menu command")
  }
  match
    bridge.dispatch(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
      ),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="file dialog service is unavailable")
    _ => fail("expected unavailable file dialog")
  }
  match
    bridge.dispatch(
      HostServiceRequest::TextFile(HostTextFileRequest::ReadText("/tmp/a.md")),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="text file service is unavailable")
    _ => fail("expected unavailable text file service")
  }
  match
    bridge.dispatch(
      HostServiceRequest::BinaryFile(
        HostBinaryFileRequest::ReadBytes("/tmp/a.pdf"),
      ),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="binary file service is unavailable")
    _ => fail("expected unavailable binary file service")
  }
}

///|
test "host service bridge applies system theme to runtime environment" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(system_theme=true),
    handle=request => {
      match request {
        QuerySystemTheme =>
          HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  match bridge.query_system_theme() {
    Some(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark system theme")
  }
  let environment = @core.Environment::default()
    .with_locale("zh-CN")
    .with_text_scale(1.25)
  let updated = bridge.environment_with_system_theme(environment)
  assert_true(updated.color_scheme == @core.ColorScheme::Dark)
  assert_true(updated.theme.scheme == @core.ColorScheme::Dark)
  inspect(updated.locale, content="zh-CN")
  inspect(updated.text_scale, content="1.25")

  let unavailable = HostServiceBridge::unavailable()
  let unchanged = unavailable.environment_with_system_theme(environment)
  assert_true(unchanged == environment)
}

///|
test "host driver dispatches command intents through runtime action map" {
  let copied = Ref(0)
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Copy),
        handle=() => copied.val = copied.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let result = driver.dispatch(HostEvent::Command(@core.CommandIntent::Copy))
  inspect(copied.val, content="1")
  inspect(result.redraw_requested, content="true")
  match HostEvent::Command(@core.CommandIntent::Copy).to_core() {
    None => ()
    Some(_) => fail("host command should dispatch through runtime action map")
  }
}

///|
test "host driver applies theme change to runtime environment" {
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let result = driver.dispatch(HostEvent::ThemeChanged(@core.ColorScheme::Dark))
  assert_true(runtime.environment().color_scheme == @core.ColorScheme::Dark)
  assert_true(runtime.environment().theme.scheme == @core.ColorScheme::Dark)
  inspect(result.redraw_requested, content="true")
}

///|
test "host driver shows context menu from action commands" {
  let submitted = Ref(0)
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Submit,
          label="Submit",
        ),
        handle=() => submitted.val = submitted.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let seen_count = Ref(0)
  let services = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          seen_count.val = commands.length()
          HostServiceResponse::MenuCommand(commands[0].intent)
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(driver.show_context_menu(services))
  inspect(seen_count.val, content="1")
  inspect(submitted.val, content="1")
}

///|
test "host service bridge routes typed platform channels" {
  let bridge = HostServiceBridge::unavailable()
  bridge.register_channel(
    PlatformChannelHandler::new(channel="clipboard.extra", handle=request => {
      if request.operation == "echo" {
        PlatformChannelResponse::Ok(request.payload)
      } else {
        PlatformChannelResponse::Error("unknown method")
      }
    }),
  )
  match
    bridge.dispatch_channel(
      PlatformChannelRequest::new(
        channel="clipboard.extra",
        operation="echo",
        payload="hello",
      ),
    ) {
    PlatformChannelResponse::Ok(value) => inspect(value, content="hello")
    _ => fail("expected platform channel response")
  }
  match
    bridge.dispatch_channel(
      PlatformChannelRequest::new(channel="missing", operation="echo"),
    ) {
    PlatformChannelResponse::Unavailable(message) =>
      inspect(message, content="platform channel is unavailable: missing")
    _ => fail("expected unavailable platform channel")
  }
}

///|
test "host service bridge routes registered typed services before fallback" {
  let fallback = Ref(0)
  let clipboard_written = Ref("")
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      fallback.val = fallback.val + 1
      HostServiceResponse::Unavailable(request.unavailable_message())
    },
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::ClipboardService, handle=request => {
      match request {
        Clipboard(WriteText(text)) => {
          clipboard_written.val = text
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("registered")
        _ => HostServiceResponse::Unavailable("wrong service")
      }
    }),
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::SystemThemeService, handle=_request => {
      HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
    }),
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::WriteText("hello")),
    ) {
    HostServiceResponse::ClipboardWritten => ()
    _ => fail("expected registered clipboard service")
  }
  inspect(clipboard_written.val, content="hello")
  match bridge.dispatch(HostServiceRequest::QuerySystemTheme) {
    HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => fail("expected registered theme service")
  }
  match bridge.dispatch(HostServiceRequest::OpenUrl("https://example.test")) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="open URL service is unavailable")
    _ => fail("expected fallback service")
  }
  inspect(fallback.val, content="1")
}

///|
test "host async service queue tracks pending and completed responses" {
  let queue = HostServiceAsyncQueue::new()
  let first = match
    queue.submit(HostServiceRequest::OpenUrl("https://example.test")) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending open-url request")
  }
  inspect(first.value, content="1")
  inspect(queue.pending_count(), content="1")
  inspect(queue.in_flight_count(), content="0")
  inspect(queue.outstanding_count(), content="1")
  inspect(queue.completed_count(), content="0")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  inspect(queue.pending_count(), content="0")
  inspect(queue.in_flight_count(), content="1")
  assert_true(queue.complete(first, HostServiceResponse::UrlOpened))
  inspect(queue.in_flight_count(), content="0")
  inspect(queue.completed_count(), content="1")
  match queue.take_completed(first) {
    Some({ request: HostServiceRequest::OpenUrl(url), response, .. }) => {
      inspect(url, content="https://example.test")
      match response {
        HostServiceResponse::UrlOpened => ()
        _ => fail("expected completed open-url response")
      }
    }
    _ => fail("expected completed open-url response")
  }
  match pending[0].request {
    HostServiceRequest::OpenUrl(url) =>
      inspect(url, content="https://example.test")
    _ => fail("expected pending open-url request")
  }

  let second = match
    queue.submit(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
      ),
    ) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file-dialog request")
  }
  assert_true(
    queue.complete(
      second,
      HostServiceResponse::FileDialogSelection(["/tmp/note.md"]),
    ),
  )
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="1")
  match queue.take_completed(second) {
    Some({ request: HostServiceRequest::FileDialog(_), response, .. }) =>
      match response {
        HostServiceResponse::FileDialogSelection(paths) =>
          inspect(paths[0], content="/tmp/note.md")
        _ => fail("expected completed file selection")
      }
    _ => fail("expected completed file-dialog response")
  }
  inspect(queue.completed_count(), content="0")
  inspect(
    queue.reject(HostServiceRequestId::new(404), "missing request"),
    content="false",
  )
}

///|
test "host async service queue rejects in-flight service requests" {
  let queue = HostServiceAsyncQueue::new()
  let request_id = match
    queue.submit(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
      ),
    ) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file-dialog request")
  }
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  inspect(queue.in_flight_count(), content="1")
  assert_true(queue.reject(request_id, "file dialog canceled"))
  inspect(queue.in_flight_count(), content="0")
  inspect(queue.completed_count(), content="1")
  match queue.take_completed(request_id) {
    Some({ request: HostServiceRequest::FileDialog(_), response, .. }) =>
      match response {
        HostServiceResponse::Unavailable(message) =>
          inspect(message, content="file dialog canceled")
        _ => fail("expected rejected file-dialog response")
      }
    _ => fail("expected rejected file-dialog completion")
  }
}

///|
test "host async service queue invokes completion handlers" {
  let queue = HostServiceAsyncQueue::new()
  let delivered : Ref[HostCompletedServiceResponse?] = Ref(None)
  let request_id = match
    queue.submit(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(
          kind=HostFileDialogKind::OpenFile,
          title="Import files",
        ),
      ),
    ) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file-dialog request")
  }
  assert_true(
    queue.on_completed(request_id, completion => {
      delivered.val = Some(completion)
    }),
  )
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(
      request_id,
      HostServiceResponse::FileDialogSelection(["/tmp/later.csv"]),
    ),
  )
  inspect(queue.completed_count(), content="0")
  match queue.take_completed(request_id) {
    Some(_) => fail("expected handled completion to be consumed")
    None => ()
  }
  match delivered.val {
    Some(
      { request: HostServiceRequest::FileDialog({ title, .. }), response, .. }
    ) => {
      inspect(title, content="Import files")
      match response {
        HostServiceResponse::FileDialogSelection(paths) =>
          inspect(paths[0], content="/tmp/later.csv")
        _ => fail("expected file dialog selection")
      }
    }
    _ => fail("expected completion handler to receive file dialog response")
  }
  assert_false(
    queue.on_completed(HostServiceRequestId::new(404), _completion => ()),
  )
  let delivered_late : Ref[HostCompletedServiceResponse?] = Ref(None)
  let late_id = match
    queue.submit(HostServiceRequest::OpenUrl("https://late.test")) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending URL request")
  }
  assert_true(queue.complete(late_id, HostServiceResponse::UrlOpened))
  inspect(queue.completed_count(), content="1")
  assert_true(
    queue.on_completed(late_id, completion => {
      delivered_late.val = Some(completion)
    }),
  )
  match delivered_late.val {
    Some({ request: HostServiceRequest::OpenUrl(url), response, .. }) => {
      inspect(url, content="https://late.test")
      assert_true(response is HostServiceResponse::UrlOpened)
    }
    _ => fail("expected late completion registration to consume record")
  }
  inspect(queue.completed_count(), content="0")
}

///|
test "host driver applies async clipboard read completion to focused text" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  let queue = HostServiceAsyncQueue::new()
  let pending = match
    queue.submit(HostServiceRequest::Clipboard(HostClipboardRequest::ReadText)) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending clipboard read")
  }
  assert_true(
    queue.complete(pending, HostServiceResponse::ClipboardText("later")),
  )
  match queue.take_completed(pending) {
    Some(completion) =>
      ignore(
        driver.dispatch_service_completion(
          completion,
          HostServiceBridge::unavailable(),
        ),
      )
    None => fail("expected completed clipboard read")
  }
  inspect(text.get(), content="later")
}

///|
test "host service bridge gates registered services by capability" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::none(),
    handle=_request => HostServiceResponse::ClipboardWritten,
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::ClipboardService, handle=_request => {
      HostServiceResponse::ClipboardWritten
    }),
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::WriteText("blocked")),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected capability gate before registered service")
  }
}

///|
test "host app services facade routes common platform requests" {
  let clipboard_written = Ref("")
  let opened_url = Ref("")
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
      file_dialogs=true,
      file_access=true,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        Clipboard(WriteText(text)) => {
          clipboard_written.val = text
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("copied")
        FileDialog({ kind: OpenFile, title, .. }) =>
          HostServiceResponse::FileDialogSelection([title + ":open"])
        TextFile(ReadText(path)) =>
          HostServiceResponse::TextFileContent(path, "file contents")
        TextFile(WriteText(path, _text)) =>
          HostServiceResponse::TextFileWritten(path)
        BinaryFile(ReadBytes(path)) =>
          HostServiceResponse::BinaryFileContent(path, b"%PDF")
        BinaryFile(WriteBytes(path, _bytes)) =>
          HostServiceResponse::BinaryFileWritten(path)
        OpenUrl(url) => {
          opened_url.val = url
          HostServiceResponse::UrlOpened
        }
        QuerySystemTheme =>
          HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        ShowMenu(commands) =>
          HostServiceResponse::MenuCommand(commands[0].intent)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = HostAppServices::new(bridge~)
  assert_true(services.capabilities().clipboard)
  match services.write_clipboard_text("hello") {
    HostServiceResponse::ClipboardWritten => ()
    _ => fail("expected clipboard write")
  }
  inspect(clipboard_written.val, content="hello")
  match services.read_clipboard_text() {
    HostServiceResponse::ClipboardText(text) => inspect(text, content="copied")
    _ => fail("expected clipboard read")
  }
  match services.open_file(title="Document") {
    HostServiceResponse::FileDialogSelection(paths) =>
      inspect(paths[0], content="Document:open")
    _ => fail("expected file dialog selection")
  }
  match services.read_text_file("/tmp/note.md") {
    HostServiceResponse::TextFileContent(path, text) => {
      inspect(path, content="/tmp/note.md")
      inspect(text, content="file contents")
    }
    _ => fail("expected text file content")
  }
  match services.write_text_file("/tmp/note.md", "updated") {
    HostServiceResponse::TextFileWritten(path) =>
      inspect(path, content="/tmp/note.md")
    _ => fail("expected text file write")
  }
  match services.read_binary_file("/tmp/note.pdf") {
    HostServiceResponse::BinaryFileContent(path, bytes) => {
      inspect(path, content="/tmp/note.pdf")
      inspect(bytes.length(), content="4")
    }
    _ => fail("expected binary file content")
  }
  match services.write_binary_file("/tmp/note.pdf", b"%PDF") {
    HostServiceResponse::BinaryFileWritten(path) =>
      inspect(path, content="/tmp/note.pdf")
    _ => fail("expected binary file write")
  }
  match services.open_url("https://example.test") {
    HostServiceResponse::UrlOpened => ()
    _ => fail("expected URL open")
  }
  inspect(opened_url.val, content="https://example.test")
  match services.system_theme() {
    Some(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark theme")
  }
  match
    services.show_context_menu([
      @core.ActionCommand::new(intent=@core.CommandIntent::Submit),
    ]) {
    HostServiceResponse::MenuCommand(@core.CommandIntent::Submit) => ()
    _ => fail("expected context menu command")
  }
}

///|
test "host app services facade reports unavailable service responses" {
  let services = HostAppServices::unavailable()
  assert_false(services.has_async_queue())
  match services.open_url("https://example.test") {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="open URL service is unavailable")
    _ => fail("expected unavailable open-url response")
  }
  match services.open_file(title="Missing") {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="file dialog service is unavailable")
    _ => fail("expected unavailable file-dialog response")
  }
  match services.read_binary_file("/tmp/missing.pdf") {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="binary file service is unavailable")
    _ => fail("expected unavailable binary-file response")
  }
  inspect(services.pending_count(), content="0")
  inspect(services.drain_pending().length(), content="0")
  inspect(
    services.reject(HostServiceRequestId::new(404), "missing request"),
    content="false",
  )
}

///|
test "host binary file diagnostics summarize bytes without dumping payloads" {
  let request = HostBinaryFileRequest::WriteBytes("/tmp/report.pdf", b"%PDF")
  let diagnostic = request.diagnostic()
  inspect(diagnostic.path, content="/tmp/report.pdf")
  inspect(diagnostic.operation, content="write-bytes")
  inspect(diagnostic.byte_length, content="4")

  match
    HostServiceResponse::BinaryFileContent(
      "/tmp/report.pdf",
      Bytes::make(32, b'\xff'),
    ).binary_file_diagnostic() {
    Some(summary) => {
      inspect(summary.path, content="/tmp/report.pdf")
      inspect(summary.operation, content="read-bytes")
      inspect(summary.byte_length, content="32")
    }
    None => fail("expected binary content diagnostic summary")
  }
}

///|
test "host app services facade exposes pending completions" {
  let queue = HostServiceAsyncQueue::new()
  let file_dialog_completed = Ref(false)
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true, file_dialogs=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => queue.submit(request)
        FileDialog(_) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = HostAppServices::new(bridge~, async_queue=Some(queue))
  assert_true(services.has_async_queue())
  let clipboard_id = match services.read_clipboard_text() {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending clipboard read")
  }
  let file_id = match services.open_file(title="Open") {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file dialog")
  }
  assert_true(
    services.on_completed(file_id, completion => {
      match completion.response {
        HostServiceResponse::FileDialogSelection(paths) =>
          file_dialog_completed.val = paths.length() == 1
        _ => ()
      }
    }),
  )
  inspect(services.pending_count(), content="2")
  inspect(services.outstanding_count(), content="2")
  let pending = services.drain_pending()
  inspect(pending.length(), content="2")
  inspect(services.in_flight_count(), content="2")
  assert_true(
    services.complete(clipboard_id, HostServiceResponse::ClipboardText("later")),
  )
  assert_true(
    services.complete(
      file_id,
      HostServiceResponse::FileDialogSelection(["/tmp/file.txt"]),
    ),
  )
  inspect(file_dialog_completed.val, content="true")
  inspect(services.completed_count(), content="1")
  match services.take_completed(clipboard_id) {
    Some({ request: Clipboard(ReadText), response: ClipboardText(text), .. }) =>
      inspect(text, content="later")
    _ => fail("expected completed clipboard read")
  }
  let completed = services.drain_completed()
  inspect(completed.length(), content="0")
}

///|
struct HostCompletionSubscriptionModel {
  pending : HostServiceRequestId?
  selected : String
}

///|
test "host app services completion subscription dispatches typed messages" {
  let queue = HostServiceAsyncQueue::new()
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(file_dialogs=true),
    handle=request => {
      match request {
        FileDialog(_) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = HostAppServices::new(bridge~, async_queue=Some(queue))
  let pending_id = match services.open_file(title="Open") {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file dialog")
  }
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init={ pending: Some(pending_id), selected: "Pending completion" },
      update=(model, completion : HostCompletedServiceResponse) => {
        match completion.response {
          HostServiceResponse::FileDialogSelection(paths) =>
            {
              pending: None,
              selected: if paths.length() > 0 {
                paths[0]
              } else {
                "empty"
              },
            }
          HostServiceResponse::Unavailable(reason) =>
            { pending: None, selected: reason }
          _ => model
        }
      },
      view=model => {
        @core.View::text(
          text=model.selected,
          size=@core.Size::new(width=260.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
      subscriptions=model => {
        match model.pending {
          Some(id) =>
            services.completion_subscription(
              id,
              map=completion => completion,
              label="File dialog completion",
            )
          None => @core.Subscription::none()
        }
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  inspect(
    initial.active_subscriptions[0].key,
    content="host-service:completion:1",
  )
  inspect(initial.active_subscriptions[0].kind, content="host-service")
  inspect(
    initial.active_subscriptions[0].label,
    content="File dialog completion",
  )
  let pending = services.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    services.complete(
      pending_id,
      HostServiceResponse::FileDialogSelection(["/tmp/subscription.txt"]),
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: value, .. }) &&
      value == "/tmp/subscription.txt"
    }),
  )
  let completed = runtime.program_runtime_snapshot()
  inspect(completed.dispatched_count, content="1")
  inspect(completed.update_count, content="1")
  inspect(completed.active_subscription_count, content="0")
  inspect(completed.cancelled_subscription_count, content="1")
  inspect(services.completed_count(), content="0")
}

///|
test "host app services completion subscription cancels queue handler" {
  let queue = HostServiceAsyncQueue::new()
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(file_dialogs=true),
    handle=request => {
      match request {
        FileDialog(_) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = HostAppServices::new(bridge~, async_queue=Some(queue))
  let pending_id = match services.open_file(title="Open") {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file dialog")
  }
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init={ pending: Some(pending_id), selected: "Pending completion" },
      update=(model, completion : HostCompletedServiceResponse) => {
        match completion.response {
          HostServiceResponse::FileDialogSelection(paths) =>
            {
              pending: None,
              selected: if paths.length() > 0 {
                paths[0]
              } else {
                "empty"
              },
            }
          _ => model
        }
      },
      view=model => {
        @core.View::text(
          text=model.selected,
          size=@core.Size::new(width=260.0, height=24.0),
          font=@core.FontSpec::new(size=14.0),
          color=@core.Color::black(),
        )
      },
      subscriptions=model => {
        match model.pending {
          Some(id) =>
            services.completion_subscription(
              id,
              map=completion => completion,
              label="File dialog completion",
            )
          None => @core.Subscription::none()
        }
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  let pending = services.drain_pending()
  inspect(pending.length(), content="1")
  runtime.destroy()
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.active_subscription_count, content="0")
  inspect(destroyed.cancelled_subscription_count, content="1")
  assert_true(
    services.complete(
      pending_id,
      HostServiceResponse::FileDialogSelection(["/tmp/cancelled.txt"]),
    ),
  )
  inspect(services.completed_count(), content="1")
  inspect(
    runtime.program_runtime_snapshot().ignored_subscription_dispatch_count,
    content="0",
  )
  match services.take_completed(pending_id) {
    Some({ response: HostServiceResponse::FileDialogSelection(paths), .. }) =>
      inspect(paths[0], content="/tmp/cancelled.txt")
    _ => fail("expected cancelled subscription completion to remain queued")
  }
}

///|
test "native accessibility bridge snapshots semantics recursively" {
  let child = @core.SemanticsNode::{
    element_id: @core.ElementId::new(2),
    role: @core.SemanticsRole::Button,
    label: "Save",
    value: "",
    description: "Save current document",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Focus, @core.SemanticsAction::Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=8.0, y=8.0, width=80.0, height=32.0),
    children: [],
  }
  let root = @core.SemanticsNode::{
    element_id: @core.ElementId::new(1),
    role: @core.SemanticsRole::Group,
    label: "Root",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    children: [child],
  }
  let bridge = NativeAccessibilityBridge::new(
    kind=NativeAccessibilityBridgeKind::TestBridge,
  )
  match bridge.snapshot_semantics(root) {
    Some(snapshot) => {
      inspect(snapshot.nodes().length(), content="2")
      inspect(snapshot.tree() is Some(_), content="true")
      inspect(snapshot.focus(), content="NodeId(1)")
      let child_update = snapshot.nodes()[1]
      inspect(child_update.node().role(), content="Button")
      match child_update.node().label() {
        Some(label) => inspect(label, content="Save")
        None => fail("expected child accessibility label")
      }
      match child_update.node().description() {
        Some(description) =>
          inspect(description, content="Save current document")
        None => fail("expected child accessibility description")
      }
      inspect(
        child_update.node().supports_action(@accesskit.Action::Click),
        content="true",
      )
    }
    None => fail("expected accessibility snapshot")
  }
}

///|
test "native accessibility bridge validates action roundtrip" {
  let invoked = Ref(0)
  let node = @core.SemanticsNode::{
    element_id: @core.ElementId::new(42),
    role: @core.SemanticsRole::TextField,
    label: "Name",
    value: "MoUI",
    description: "Required profile name",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Focus, @core.SemanticsAction::SetText],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    children: [],
  }
  let bridge = NativeAccessibilityBridge::semantics_action_bridge(
    kind=NativeAccessibilityBridgeKind::TestBridge,
    root=node,
    dispatch=(element_id, action, value) => {
      if element_id == @core.ElementId::new(42) &&
        action == @core.SemanticsAction::SetText &&
        value == Some("Luna") {
        invoked.val = invoked.val + 1
        true
      } else {
        false
      }
    },
  )
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(42),
        action=@core.SemanticsAction::SetText,
        value=Some("Luna"),
      ),
    ) {
    NativeAccessibilityActionResult::Handled => ()
    _ => fail("expected handled action")
  }
  inspect(invoked.val, content="1")
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(42),
        action=@core.SemanticsAction::Submit,
      ),
    ) {
    NativeAccessibilityActionResult::Unsupported(message) =>
      inspect(message, content="semantics node does not expose action: submit")
    _ => fail("expected unsupported action")
  }
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(7),
        action=@core.SemanticsAction::Focus,
      ),
    ) {
    NativeAccessibilityActionResult::ElementNotFound({ value: 7 }) => ()
    _ => fail("expected missing element result")
  }
}

///|
test "host driver dispatches resize and deduplicates redraw requests" {
  let scheduled = Ref(0)
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let first = driver.dispatch(HostEvent::Resized(metrics))
  let second = driver.dispatch(HostEvent::Resized(metrics))
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  inspect(first.redraw_requested, content="true")
  inspect(second.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(driver.dispatch(HostEvent::Resized(metrics)))
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
}

///|
test "host driver coalesces dirty redraw while previous redraw is pending" {
  let scheduled = Ref(0)
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  inspect(scheduled.val, content="1")
  let pending = driver.dispatch(
    HostEvent::TextInput(@core.TextInputEvent::InsertText("a")),
  )
  inspect(text.get(), content="a")
  inspect(pending.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(
    driver.dispatch(HostEvent::TextInput(@core.TextInputEvent::InsertText("b"))),
  )
  inspect(text.get(), content="ab")
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
}

///|
test "host renderer expands cached layer updates and replays cached hits" {
  let rendered : Array[Array[@core.DrawCommand]] = []
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=commands => rendered.push(commands.copy()),
    text_system=() => @core.TextSystem::fallback(),
  )
  let spec = @core.CachedLayerSpec::new(
    key="layer:1",
    frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=24.0),
    content_revision=1,
  )
  let text = @core.DrawCommand::DrawText(
    @core.TextRun::new(
      text="cached",
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=24.0),
      font=@core.FontSpec::new(size=12.0),
      color=@core.Color::black(),
    ),
  )
  let first = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::BeginCachedLayer(spec),
        text,
        @core.DrawCommand::EndCachedLayer(spec.key),
      ],
      damage=@core.DamageRegion::full("test"),
    ),
  )
  inspect(first.cache_update_count, content="1")
  inspect(first.cache_hit_count, content="0")
  let second = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::DrawCachedLayer(spec),
      ],
      damage=@core.DamageRegion::empty(),
    ),
  )
  inspect(second.cache_hit_count, content="1")
  inspect(second.cache_miss_count, content="0")
  inspect(rendered.length(), content="2")
  assert_true(
    rendered[1].any(command =>
      command is @core.DrawCommand::DrawText({ text: "cached", .. })
    ),
  )
}

///|
test "redraw scheduler schedules follow-up requested during frame" {
  let scheduled = Ref(0)
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  driver.request_redraw()
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  driver.request_redraw()
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
  assert_true(driver.event_result().redraw_requested)
}

///|
test "host driver maps focused text input through core text input event" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(
      text.binding(),
      width=240.0,
      height=40.0,
      outlined=true,
    ),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(HostEvent::TextInput(@core.TextInputEvent::InsertText("a"))),
  )
  inspect(text.get(), content="")
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  let result = driver.dispatch(
    HostEvent::TextInput(@core.TextInputEvent::InsertText("a")),
  )
  inspect(text.get(), content="a")
  inspect(result.redraw_requested, content="true")
}

///|
test "host driver routes text clipboard commands through service bridge" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="a",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Copy, bridge),
  )
  inspect(clipboard.val, content="hello")
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Cut, bridge),
  )
  inspect(text.get(), content="")
  clipboard.val = "world"
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Paste, bridge),
  )
  inspect(text.get(), content="world")
}

///|
test "host driver routes clipboard keyboard shortcuts through service bridge" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  inspect(clipboard.val, content="hello")
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="x",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(text.get(), content="")
  clipboard.val = "world"
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="v",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(text.get(), content="world")
}

///|
test "host driver includes focused text commands in context menu" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let saw_copy_command = Ref(false)
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true, menus=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        ShowMenu(commands) => {
          saw_copy_command.val = commands.any(command => {
            command.intent == @core.CommandIntent::Copy
          })
          HostServiceResponse::MenuCommand(@core.CommandIntent::Copy)
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="a",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(bridge))
  inspect(saw_copy_command.val, content="true")
  inspect(clipboard.val, content="hello")
}

///|
test "host driver context menu pastes unicode into focused text input" {
  let text = @core.State::new("")
  let clipboard = Ref("你🙂")
  let saw_paste_command = Ref(false)
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true, menus=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        ShowMenu(commands) => {
          saw_paste_command.val = commands.any(command => {
            command.intent == @core.CommandIntent::Paste
          })
          HostServiceResponse::MenuCommand(@core.CommandIntent::Paste)
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(bridge))
  inspect(saw_paste_command.val, content="true")
  inspect(text.get(), content="你🙂")
  inspect(driver.focused_text_input().caret, content="2")
}

///|
test "host driver keyboard paste replaces selection with extended emoji" {
  let text = @core.State::new("")
  let clipboard = Ref("☕️👩‍💻")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("replace")),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="a",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="v",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  inspect(text.get(), content="☕️👩‍💻")
  inspect(driver.focused_text_input().caret, content="5")
}

///|
test "host driver falls back clipboard shortcuts to action commands" {
  let copied = Ref(0)
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Copy),
        handle=() => copied.val = copied.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=_request => HostServiceResponse::ClipboardWritten,
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(copied.val, content="1")
}

///|
test "host driver defers paste action command while clipboard read is pending" {
  let pasted = Ref(0)
  let queue = HostServiceAsyncQueue::new()
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Paste),
        handle=() => pasted.val = pasted.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Paste, bridge),
  )
  inspect(pasted.val, content="0")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(pending[0].id, HostServiceResponse::ClipboardText("delayed")),
  )
  for completion in queue.drain_completed() {
    ignore(driver.dispatch_service_completion(completion, bridge))
  }
  inspect(pasted.val, content="1")
}

///|
test "host driver dispatches ime composition text input events" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(
      text.binding(),
      width=240.0,
      height=40.0,
      outlined=true,
    ),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionStart),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionEnd("你")),
    ),
  )
  inspect(text.get(), content="你")
}

///|
test "host driver keeps unicode composition update in focused text state" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("ab")),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionStart),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(
        @core.TextInputEvent::CompositionUpdate(
          @core.CompositionUpdate::new(
            text="你☕️",
            cursor=Some(@core.TextRange::new(start=3, end=3)),
          ),
        ),
      ),
    ),
  )
  let composing = driver.focused_text_input()
  guard composing.composition is Some(composition) else {
    fail("expected host-routed composition text")
  }
  inspect(composition, content="你☕️")
  guard composing.composition_cursor is Some(cursor) else {
    fail("expected host-routed composition cursor")
  }
  inspect(cursor.start, content="3")
  inspect(cursor.end, content="3")
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::CompositionEnd("你☕️")),
    ),
  )
  inspect(text.get(), content="ab你☕️")
  inspect(driver.focused_text_input().caret, content="5")
}

///|
test "text input session enables updates and disables ime requests" {
  let text = @core.State::new("ab")
  let runtime = host_test_runtime(
    root=@core.View::flex(
      children=[host_test_text_field(text.binding(), width=120.0, height=40.0)],
      axis=@core.Axis::Vertical,
      spacing=4.0,
      main_axis_alignment=@core.MainAxisAlignment::MainStart,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let session = TextInputSession::new()
  match session.sync(runtime.focused_text_input()) {
    NoImeChange => ()
    _ => fail("unfocused runtime should not change ime")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  match session.sync(runtime.focused_text_input()) {
    EnableIme(@window_core.ImeRequest::Enable(_)) => ()
    _ => fail("focused text field should enable ime")
  }
  match session.sync(runtime.focused_text_input()) {
    NoImeChange => ()
    _ => fail("unchanged focused text field should not repeat ime updates")
  }
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("c")),
  )
  match session.sync(runtime.focused_text_input()) {
    UpdateIme(@window_core.ImeRequest::Update(data)) => {
      match data.cursor_area() {
        Some((_, size)) => assert_true(size.to_logical(1.0).height() > 0.0)
        None => fail("expected cursor area")
      }
      match data.surrounding_text() {
        Some(surrounding) => inspect(surrounding.text(), content="abc")
        None => fail("expected surrounding text")
      }
    }
    _ => fail("changed focused text field should update active ime")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=230.0, y=55.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  match session.sync(runtime.focused_text_input()) {
    DisableIme(@window_core.ImeRequest::Disable) => ()
    _ => fail("blur should disable ime")
  }
  match session.sync(runtime.focused_text_input()) {
    NoImeChange => ()
    _ => fail("unfocused runtime should stay idle after disabling ime")
  }
}

///|
test "text input session enables ime when surrounding text is too long" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    element_id: None,
    text: "a".repeat(@window_core.ImeSurroundingText::max_text_bytes() + 1),
    caret: 0,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) => {
      assert_true(!request.capabilities().surrounding_text())
      assert_true(!request.request_data().has_surrounding_text())
      match session.last_diagnostics() {
        Some(diagnostics) => {
          assert_false(diagnostics.has_surrounding_text)
          assert_true(
            diagnostics.surrounding_text_utf8_length >
            @window_core.ImeSurroundingText::max_text_bytes(),
          )
        }
        None => fail("expected ime diagnostics")
      }
    }
    _ => fail("focused text field should still enable ime")
  }
}

///|
test "text input ime diagnostics normalize grapheme cursor and candidate anchor" {
  let state = @core.TextInputState::{
    focused: true,
    element_id: None,
    text: "A👩‍💻B",
    caret: 2,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=12.0, y=18.0, width=0.0, height=-4.0),
  }
  let diagnostics = text_input_ime_request_diagnostics(state)
  inspect(diagnostics.cursor, content="1")
  inspect(diagnostics.anchor, content="1")
  inspect(diagnostics.cursor_utf8, content="1")
  inspect(diagnostics.anchor_utf8, content="1")
  inspect(diagnostics.text_length, content="5")
  inspect(diagnostics.text_utf8_length, content="13")
  assert_true(diagnostics.cursor_is_grapheme_boundary)
  assert_true(diagnostics.anchor_is_grapheme_boundary)
  inspect(diagnostics.candidate_anchor.origin.x, content="12")
  inspect(diagnostics.candidate_anchor.origin.y, content="18")
  inspect(diagnostics.candidate_anchor.size.width, content="1")
  inspect(diagnostics.candidate_anchor.size.height, content="1")
  let request = text_input_ime_request_data(state)
  match request.surrounding_text() {
    Some(surrounding) => {
      inspect(surrounding.cursor(), content="1")
      inspect(surrounding.anchor(), content="1")
    }
    None => fail("expected surrounding text")
  }
  match request.cursor_area() {
    Some((position, size)) => {
      inspect(position.to_logical(1.0).x(), content="12")
      inspect(position.to_logical(1.0).y(), content="18")
      inspect(size.to_logical(1.0).width(), content="1")
      inspect(size.to_logical(1.0).height(), content="1")
    }
    None => fail("expected cursor area")
  }
}

///|
test "text input session preserves selection anchor in ime surrounding text" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    element_id: None,
    text: "你ab好",
    caret: 3,
    selection: Some(@core.TextRange::new(start=1, end=3)),
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) =>
      match request.request_data().surrounding_text() {
        Some(surrounding) => {
          inspect(surrounding.cursor(), content="5")
          inspect(surrounding.anchor(), content="3")
          match session.last_diagnostics() {
            Some(diagnostics) => {
              inspect(diagnostics.cursor, content="3")
              inspect(diagnostics.anchor, content="1")
              inspect(diagnostics.cursor_utf8, content="5")
              inspect(diagnostics.anchor_utf8, content="3")
            }
            None => fail("expected ime diagnostics")
          }
        }
        None => fail("expected surrounding text")
      }
    _ => fail("focused text field should enable ime")
  }
}

///|
test "text input session preserves reverse selection anchor in ime surrounding text" {
  let session = TextInputSession::new()
  let state = @core.TextInputState::{
    focused: true,
    element_id: None,
    text: "你ab好",
    caret: 1,
    selection: Some(@core.TextRange::new(start=3, end=1)),
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    caret_rect: @core.Rect::new(x=8.0, y=8.0, width=1.0, height=20.0),
  }
  match session.sync(state) {
    EnableIme(@window_core.ImeRequest::Enable(request)) =>
      match request.request_data().surrounding_text() {
        Some(surrounding) => {
          inspect(surrounding.cursor(), content="3")
          inspect(surrounding.anchor(), content="5")
        }
        None => fail("expected surrounding text")
      }
    _ => fail("focused text field should enable ime")
  }
}

///|
test "host event converts to current core event model" {
  let event = HostEvent::TextInput(@core.TextInputEvent::InsertText("x")).to_core()
  match event {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::InsertText(text))) =>
      inspect(text, content="x")
    _ => fail("expected text input event")
  }
  let composition = HostEvent::TextInput(
    @core.TextInputEvent::CompositionEnd("你"),
  ).to_core()
  match composition {
    Some(@core.AppEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="你")
    _ => fail("expected composition text input event")
  }
  let scroll = HostEvent::Scroll(
    HostScrollEvent::new(
      position=@core.Point::new(x=8.0, y=9.0),
      delta=HostScrollDelta::Lines(@core.Point::new(x=1.0, y=-2.0)),
    ),
  ).to_core()
  match scroll {
    Some(@core.AppEvent::Pointer({ wheel_delta: { x: 40.0, y: -80.0 }, .. })) =>
      ()
    _ => fail("expected scroll pointer event")
  }
  let blur = HostEvent::Focus(
    HostFocusEvent::new(
      focused=false,
      pointer_cancel_position=Some(@core.Point::new(x=2.0, y=3.0)),
    ),
  ).to_core()
  match blur {
    Some(@core.AppEvent::Pointer({ phase: @core.PointerPhase::Cancel, .. })) =>
      ()
    _ => fail("expected blur cancel pointer event")
  }
}
