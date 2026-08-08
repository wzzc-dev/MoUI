///|
fn frame_test_renderer(disposals : Ref[Int]) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    dispose=() => disposals.val = disposals.val + 1,
  )
}

///|
test "window frame state coalesces pending frames and ignores late completion after dispose" {
  let redraws = Ref(0)
  let ime_syncs = Ref(0)
  let finishes = Ref(0)
  let disposals = Ref(0)
  let state = WindowFrameState::new(
    renderer=frame_test_renderer(disposals),
    hooks=WindowFrameHooks::new(
      finish_presented=_ => finishes.val = finishes.val + 1,
      request_redraw=() => redraws.val = redraws.val + 1,
      sync_ime=() => ime_syncs.val = ime_syncs.val + 1,
    ),
  )
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::full("frame owner test"),
  )
  guard state.prepare_submission(frame) is Some(first) else {
    fail("expected first submission")
  }
  assert_false(
    state.finish_submission(
      @render.RenderFrameResult::new(presented=false, queued=true),
      [],
    ),
  )
  assert_true(state.pending())
  inspect(redraws.val, content="1")
  assert_true(state.prepare_submission(frame) is None)
  inspect(redraws.val, content="2")
  let stale = @render.RenderPresentCompletion::new(
    token=@render.FrameToken::new(surface_generation=1, sequence=99),
    submitted_at_ms=0.0,
    completed_at_ms=1.0,
    presented_at_ms=1.0,
    status=@render.RenderPresentStatus::Presented,
    gpu_context_generation=1,
  )
  assert_false(state.accept_present_completions([stale]))
  assert_true(state.pending())
  let completion = @render.RenderPresentCompletion::new(
    token=first.token(),
    submitted_at_ms=0.0,
    completed_at_ms=1.0,
    presented_at_ms=1.0,
    status=@render.RenderPresentStatus::Presented,
    gpu_context_generation=1,
  )
  assert_true(state.accept_present_completions([completion]))
  assert_false(state.pending())
  assert_true(state.prepare_submission(frame) is Some(_))
  state.dispose()
  state.dispose()
  inspect(disposals.val, content="1")
  assert_true(state.prepare_submission(frame) is None)
  assert_false(state.accept_present_completions([completion]))
  inspect(state.presented_count(), content="1")
  inspect(finishes.val, content="2")
  inspect(ime_syncs.val, content="3")
  inspect(redraws.val, content="3")
}

///|
test "window frame collections isolate sessions by window" {
  let states = WindowFrameStates::new()
  let first_disposals = Ref(0)
  let second_disposals = Ref(0)
  let first = @backend_host.WindowId::new(1)
  let second = @backend_host.WindowId::new(2)
  assert_true(states.attach(first, frame_test_renderer(first_disposals)))
  assert_true(states.attach(second, frame_test_renderer(second_disposals)))
  assert_false(states.attach(first, frame_test_renderer(Ref(0))))
  assert_true(states.dispose_window(first))
  assert_false(states.dispose_window(first))
  inspect(first_disposals.val, content="1")
  inspect(second_disposals.val, content="0")
  assert_true(states.lookup(second) is Some(_))
  inspect(states.count(), content="1")
}
