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
  inspect(baseline.current_revision(), content="1")
  inspect(baseline.current_status_counts().loading_count(), content="1")
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
    result.status() == HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(result.previous_revision(), content="1")
  inspect(result.current_revision(), content="2")
  inspect(result.previous_status_counts().loading_count(), content="1")
  inspect(result.current_status_counts().ready_count(), content="1")
  inspect(result.current_status_counts().failed_count(), content="1")
  inspect(requested.length(), content="1")
  assert_true(requested[0] == window_id)
  let diagnostics = source.diagnostics()
  inspect(diagnostics.publish_count(), content="1")
  inspect(diagnostics.recorded_count(), content="0")
  inspect(diagnostics.redraw_requested_count(), content="1")
  inspect(diagnostics.unchanged_count(), content="0")
  inspect(diagnostics.discarded_closed_count(), content="0")
  inspect(diagnostics.tracked_window_count(), content="1")
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
  inspect(baseline.current_revision(), content="3")
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
    result.status() ==
    HostImageResourceRepaintStatus::ImageRepaintDiscardedClosed,
  )
  inspect(result.previous_revision(), content="3")
  inspect(result.current_revision(), content="3")
  inspect(result.previous_status_counts().loading_count(), content="1")
  inspect(result.current_status_counts().record_count(), content="0")
  inspect(redraws.val, content="0")
  inspect(tracker.tracked_count(), content="0")
  let diagnostics = source.diagnostics()
  inspect(diagnostics.publish_count(), content="1")
  inspect(diagnostics.discarded_closed_count(), content="1")
  inspect(diagnostics.redraw_requested_count(), content="0")
  inspect(diagnostics.tracked_window_count(), content="0")
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
  inspect(baseline.current_revision(), content="6")
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
    stale.status() == HostImageResourceRepaintStatus::ImageRepaintUnchanged,
  )
  inspect(stale.previous_revision(), content="6")
  inspect(stale.current_revision(), content="6")
  inspect(stale.previous_status_counts().ready_count(), content="1")
  inspect(stale.current_status_counts().ready_count(), content="1")
  inspect(stale.current_status_counts().failed_count(), content="0")
  inspect(redraws.val, content="0")
  let diagnostics = source.diagnostics()
  inspect(diagnostics.publish_count(), content="1")
  inspect(diagnostics.unchanged_count(), content="1")
  inspect(diagnostics.redraw_requested_count(), content="0")
  inspect(diagnostics.tracked_window_count(), content="1")
  let snapshot = tracker.snapshot()
  inspect(snapshot.tracked_windows()[0].revision(), content="6")
  inspect(
    snapshot.tracked_windows()[0].status_counts().ready_count(),
    content="1",
  )
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
  inspect(baseline.current_revision(), content="1")
  inspect(baseline.current_status_counts().loading_count(), content="1")
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
    result.status() == HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(result.previous_revision(), content="1")
  inspect(result.current_revision(), content="2")
  inspect(result.previous_status_counts().loading_count(), content="1")
  inspect(result.current_status_counts().ready_count(), content="1")
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
  inspect(diagnostics.publish_count(), content="1")
  inspect(diagnostics.redraw_requested_count(), content="1")
}
