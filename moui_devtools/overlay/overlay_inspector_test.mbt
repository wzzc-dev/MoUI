///|
/// Zero-valued trace parts for synthetic timeline entries.
fn timeline_test_entry(
  sequence~ : Int32,
  dispatched~ : Int32 = 0,
  planned~ : Int32 = 0,
  completed~ : Int32 = 0,
  timed~ : Bool = false,
  total_ms~ : Double = 0.0,
  layout_hits~ : Int32 = 0,
  layout_misses~ : Int32 = 0,
  semantics_changed~ : Int32 = 0,
) -> @devtools.DevtoolsTraceEntry {
  {
    sequence,
    messages: {
      dispatched_delta: dispatched,
      updated_delta: 0,
      ignored_delta: 0,
      enqueued_delta: 0,
      drained_delta: 0,
      pending_after: 0,
      max_pending_after: 0,
    },
    effects: {
      planned_delta: planned,
      run_delta: 0,
      send_delta: 0,
      started_delta: 0,
      completed_delta: completed,
      cancelled_delta: 0,
      ignored_delta: 0,
      active_after: 0,
      descriptors: [],
    },
    frame: {
      timed,
      rebuild_passes: if timed {
        1
      } else {
        0
      },
      layout_passes: 0,
      paint_passes: 0,
      draw_builds: 0,
      build_ms: 0.0,
      layout_ms: 0.0,
      paint_ms: 0.0,
      draw_ms: 0.0,
      total_ms,
      damage_kind: "",
      damage_rect_count: 0,
    },
    caches: {
      layout_hits_delta: layout_hits,
      layout_misses_delta: layout_misses,
      render_hits_delta: 0,
      render_misses_delta: 0,
    },
    memo: {
      available: false,
      builds_delta: 0,
      hits_delta: 0,
      misses_delta: 0,
      builds_after: 0,
      hits_after: 0,
      misses_after: 0,
    },
    semantics: {
      baseline: false,
      added_count: 0,
      removed_count: 0,
      changed_count: semantics_changed,
      dropped_count: 0,
      entries: [],
    },
  }
}

///|
test "timeline rows flag exactly the channels that carried work" {
  let rows = @overlay.trace_timeline_rows([
    timeline_test_entry(sequence=1, dispatched=3),
    timeline_test_entry(sequence=2, timed=true, total_ms=8.25),
    timeline_test_entry(sequence=3, layout_hits=4, layout_misses=1),
    timeline_test_entry(sequence=4, semantics_changed=2),
    timeline_test_entry(sequence=5),
  ])
  assert_true(rows.length() == 5)
  inspect(rows[0].channels, content="m")
  inspect(rows[0].summary, content=" msg+3")
  inspect(rows[1].channels, content="f")
  inspect(rows[1].summary, content=" frame 8.25ms b1/l0/p0")
  inspect(rows[2].channels, content="c")
  inspect(rows[2].summary, content=" cache 4/1")
  inspect(rows[3].channels, content="s")
  inspect(rows[3].summary, content=" sem +0/-0/~2")
  // An idle interaction stays honest: no invented channels or numbers.
  inspect(rows[4].channels, content="—")
  inspect(rows[4].summary, content=" idle")
  // Sequence numbers survive the mapping for stable row identity.
  inspect(rows[3].sequence, content="4")
}

///|
test "timeline window keeps the most recent interactions" {
  inspect(@overlay.trace_timeline_skip(entry_count=5, max_rows=2), content="3")
  inspect(@overlay.trace_timeline_skip(entry_count=2, max_rows=5), content="0")
  inspect(@overlay.trace_timeline_skip(entry_count=0, max_rows=2), content="0")
}

///|
test "timeline view assembles from a real runtime trace" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.text("probe") : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=40.0),
  )
  ignore(runtime.draw_frame())
  let trace = @devtools.DevtoolsTrace::new(capacity=8)
  let clock = Ref(0.0)
  for _pass in 0..<2 {
    let profiled = runtime.profile_draw_frame(() => {
      clock.val = clock.val + 1.0
      clock.val
    })
    ignore(
      trace.record_frame(runtime.inspector_snapshot(), timing=profiled.timing()),
    )
  }
  let view = @overlay.trace_timeline_view(trace.entries())
  let _ = view
  let rows = @overlay.trace_timeline_rows(trace.entries())
  inspect(rows.length(), content="2")
  // Both recorded interactions carried frame work.
  // Real traces also record cache deltas, so the frame channel may ride
  // with "c"; assert the frame channel is present rather than the exact set.
  assert_true(rows[0].channels.contains("f"))
  assert_true(rows[1].channels.contains("f"))
}

///|
test "inspector tree rows mirror the snapshot's node list" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(
      @views.column([
        (@views.text("alpha") : @core.View[Unit]),
        (@views.text("beta") : @core.View[Unit]),
      ]) : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  ignore(runtime.layout())
  let snapshot = runtime.inspector_snapshot()
  let rows = @overlay.inspector_tree_rows(snapshot)
  inspect(rows.length(), content="\{snapshot.view_tree().node_count()}")
  // The root leads at depth 0 and the outline never skips a level.
  inspect(rows[0].depth, content="0")
  let mut deepest = 0
  for row in rows {
    assert_true(row.depth <= deepest + 1)
    deepest = row.depth
  }
}

///|
test "inspector tree rows flag pending paint and clear after a frame" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.button("Press", on_click=()) : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=40.0),
  )
  ignore(runtime.layout())
  // A press dirties the button without presenting a frame.
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=60.0, y=20.0),
        phase=Down,
      ),
    ),
  )
  let dirty_rows = @overlay.inspector_tree_rows(runtime.inspector_snapshot())
  let mut dirty_count = 0
  for row in dirty_rows {
    if row.dirty_channels != "" {
      dirty_count = dirty_count + 1
    }
  }
  assert_true(dirty_count > 0)
  // Presenting the frame settles every element.
  ignore(runtime.draw_frame())
  for row in @overlay.inspector_tree_rows(runtime.inspector_snapshot()) {
    inspect(row.dirty_channels, content="")
  }
}

///|
test "inspector tree and timeline views assemble" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.text("probe") : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=40.0),
  )
  ignore(runtime.layout())
  let tree_view = @overlay.inspector_tree_view(runtime.inspector_snapshot())
  let _ = tree_view
  let trace = @devtools.DevtoolsTrace::new(capacity=4)
  ignore(trace.record(runtime.inspector_snapshot()))
  let timeline_view = @overlay.trace_timeline_view(trace.entries())
  let _ = timeline_view
  // An empty trace renders the honest placeholder.
  let empty_view = @overlay.trace_timeline_view(
    @devtools.DevtoolsTrace::new(capacity=4).entries(),
  )
  let _ = empty_view
}
