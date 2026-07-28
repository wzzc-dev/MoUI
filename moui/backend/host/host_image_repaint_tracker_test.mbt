///|
test "host image repaint tracker routes revision changes per window" {
  let tracker = @render.HostImageResourceRepaintTracker::new()
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
    main_baseline.status() ==
    @render.HostImageResourceRepaintStatus::ImageRepaintRecorded,
  )
  inspect(inspector_baseline.current_revision(), content="0")
  inspect(tracker.tracked_count(), content="2")
  let baseline_snapshot = tracker.snapshot()
  inspect(baseline_snapshot.tracked_window_count(), content="2")
  assert_true(baseline_snapshot.tracked_windows()[0].window_id() == main_id)
  inspect(baseline_snapshot.tracked_windows()[0].revision(), content="0")
  inspect(
    baseline_snapshot.tracked_windows()[0].status_counts().record_count(),
    content="0",
  )
  assert_true(
    baseline_snapshot.tracked_windows()[1].window_id() == inspector_id,
  )
  inspect(baseline_snapshot.tracked_windows()[1].revision(), content="0")
  inspector_revision.val = 1
  let requested : Array[HostWindowId] = []
  let inspector_result = tracker.request_redraw_if_changed(
    inspector_id,
    inspector_renderer,
    window_open=true,
    request_redraw=id => requested.push(id),
  )
  assert_true(
    inspector_result.status() ==
    @render.HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(inspector_result.previous_revision(), content="0")
  inspect(inspector_result.current_revision(), content="1")
  inspect(requested.length(), content="1")
  assert_true(requested[0] == inspector_id)
  let requested_snapshot = tracker.snapshot()
  inspect(requested_snapshot.tracked_window_count(), content="2")
  assert_true(requested_snapshot.tracked_windows()[0].window_id() == main_id)
  inspect(requested_snapshot.tracked_windows()[0].revision(), content="0")
  assert_true(
    requested_snapshot.tracked_windows()[1].window_id() == inspector_id,
  )
  inspect(requested_snapshot.tracked_windows()[1].revision(), content="1")
  inspect(
    requested_snapshot.tracked_windows()[1].status_counts().record_count(),
    content="0",
  )
  let unchanged = tracker.request_redraw_if_changed(
    inspector_id,
    inspector_renderer,
    window_open=true,
    request_redraw=id => requested.push(id),
  )
  assert_true(
    unchanged.status() == @render.HostImageResourceRepaintStatus::ImageRepaintUnchanged,
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
    main_result.status() ==
    @render.HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(requested.length(), content="2")
  assert_true(requested[1] == main_id)
}

///|
test "host image repaint tracker routes callback snapshots without renderer reads" {
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(4)
  let revision = Ref(1)
  let snapshot_reads = Ref(0)
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(
      image_resource_snapshot=Some(() => {
        snapshot_reads.val = snapshot_reads.val + 1
        @render.ImageResourceSnapshot::new(revision=revision.val, records=[])
      }),
    ),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision(), content="1")
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
    result.status() == @render.HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(result.previous_revision(), content="1")
  inspect(result.current_revision(), content="2")
  inspect(result.current_status_counts().ready_count(), content="1")
  inspect(snapshot_reads.val, content="1")
  inspect(requested.length(), content="1")
  assert_true(requested[0] == window_id)
}

///|
test "host image repaint tracker snapshots lifecycle status counts" {
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(5)
  let revision = Ref(1)
  let records : Ref[Array[@render.ImageResourceRecord]] = Ref([
    @render.ImageResourceRecord::loading("loading.png"),
    @render.ImageResourceRecord::ready("ready.png", width=64, height=48),
    @render.ImageResourceRecord::failed("failed.png", diagnostic="decode"),
  ])
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(
      image_resource_snapshot=Some(() => {
        @render.ImageResourceSnapshot::new(
          revision=revision.val,
          records=records.val,
        )
      }),
    ),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision(), content="1")
  inspect(baseline.previous_status_counts().record_count(), content="0")
  inspect(baseline.current_status_counts().record_count(), content="3")
  inspect(baseline.current_status_counts().loading_count(), content="1")
  inspect(baseline.current_status_counts().ready_count(), content="1")
  inspect(baseline.current_status_counts().failed_count(), content="1")
  let baseline_snapshot = tracker.snapshot()
  inspect(baseline_snapshot.tracked_window_count(), content="1")
  let baseline_counts = baseline_snapshot.tracked_windows()[0].status_counts()
  inspect(baseline_counts.record_count(), content="3")
  inspect(baseline_counts.loading_count(), content="1")
  inspect(baseline_counts.ready_count(), content="1")
  inspect(baseline_counts.failed_count(), content="1")
  inspect(baseline_counts.disposed_count(), content="0")
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
    result.status() == @render.HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(redraws.val, content="1")
  inspect(result.previous_status_counts().record_count(), content="3")
  inspect(result.previous_status_counts().loading_count(), content="1")
  inspect(result.current_status_counts().record_count(), content="4")
  inspect(result.current_status_counts().loading_count(), content="0")
  inspect(result.current_status_counts().ready_count(), content="2")
  inspect(result.current_status_counts().failed_count(), content="1")
  inspect(result.current_status_counts().disposed_count(), content="1")
  let updated_snapshot = tracker.snapshot()
  inspect(updated_snapshot.tracked_windows()[0].revision(), content="2")
  let updated_counts = updated_snapshot.tracked_windows()[0].status_counts()
  inspect(updated_counts.record_count(), content="4")
  inspect(updated_counts.loading_count(), content="0")
  inspect(updated_counts.ready_count(), content="2")
  inspect(updated_counts.failed_count(), content="1")
  inspect(updated_counts.disposed_count(), content="1")
}

///|
test "host image repaint tracker ignores stale snapshot revisions" {
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(6)
  let revision = Ref(5)
  let records : Ref[Array[@render.ImageResourceRecord]] = Ref([
    @render.ImageResourceRecord::ready("ready.png", width=64, height=48),
  ])
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(
      image_resource_snapshot=Some(() => {
        @render.ImageResourceSnapshot::new(
          revision=revision.val,
          records=records.val,
        )
      }),
    ),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision(), content="5")
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
    stale.status() == @render.HostImageResourceRepaintStatus::ImageRepaintUnchanged,
  )
  inspect(stale.previous_revision(), content="5")
  inspect(stale.current_revision(), content="5")
  inspect(stale.previous_status_counts().ready_count(), content="1")
  inspect(stale.current_status_counts().ready_count(), content="1")
  inspect(stale.current_status_counts().disposed_count(), content="0")
  inspect(redraws.val, content="0")
  let stale_snapshot = tracker.snapshot()
  inspect(stale_snapshot.tracked_windows()[0].revision(), content="5")
  let stale_counts = stale_snapshot.tracked_windows()[0].status_counts()
  inspect(stale_counts.ready_count(), content="1")
  inspect(stale_counts.disposed_count(), content="0")
  revision.val = 6
  let fresh = tracker.request_redraw_if_changed(
    window_id,
    renderer,
    window_open=true,
    request_redraw=_id => redraws.val = redraws.val + 1,
  )
  assert_true(
    fresh.status() == @render.HostImageResourceRepaintStatus::ImageRepaintRequested,
  )
  inspect(fresh.previous_revision(), content="5")
  inspect(fresh.current_revision(), content="6")
  inspect(redraws.val, content="1")
}

///|
test "host image repaint tracker discards closed window changes" {
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let window_id = HostWindowId::new(7)
  let revision = Ref(1)
  let records : Ref[Array[@render.ImageResourceRecord]] = Ref([
    @render.ImageResourceRecord::loading("late.png"),
  ])
  let snapshot_reads = Ref(0)
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(
      image_resource_snapshot=Some(() => {
        snapshot_reads.val = snapshot_reads.val + 1
        @render.ImageResourceSnapshot::new(
          revision=revision.val,
          records=records.val,
        )
      }),
    ),
  )
  let baseline = tracker.record_presented(window_id, renderer)
  inspect(baseline.current_revision(), content="1")
  inspect(baseline.current_status_counts().loading_count(), content="1")
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
    result.status() ==
    @render.HostImageResourceRepaintStatus::ImageRepaintDiscardedClosed,
  )
  inspect(result.previous_revision(), content="1")
  inspect(result.current_revision(), content="1")
  inspect(result.previous_status_counts().record_count(), content="1")
  inspect(result.previous_status_counts().loading_count(), content="1")
  inspect(result.current_status_counts().record_count(), content="0")
  inspect(redraws.val, content="0")
  inspect(snapshot_reads.val, content="1")
  inspect(tracker.tracked_count(), content="0")
  let snapshot = tracker.snapshot()
  inspect(snapshot.tracked_window_count(), content="0")
  inspect(snapshot.tracked_windows().length(), content="0")
}
