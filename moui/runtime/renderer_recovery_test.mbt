///|
/// Phase 2.2 (ADR 0006 § Context-loss recovery): a fresh recovery module
/// starts in `Idle`, with zero losses and no fallback.
test "renderer recovery starts idle without fallback" {
  let recovery = RendererRecovery::new()
  assert_true(recovery.state() is RendererRecoveryState::Idle)
  inspect(recovery.loss_count(), content="0")
  inspect(recovery.last_loss_reason(), content="")
  inspect(recovery.consecutive_failures(), content="0")
  assert_false(recovery.should_fallback_to_raster())
  assert_false(recovery.should_recover(now_ms=0.0))
  assert_false(recovery.recovery_deadline_expired(now_ms=0.0))
}

///|
/// A reported context-loss transitions to `Lost` and stamps a 3-VSync
/// deadline. The renderer thread has until the deadline to begin recovery.
test "renderer recovery context loss stamps 3-vsync deadline" {
  let budget = RendererRecoveryBudget::default()
  let recovery = RendererRecovery::new(budget~)
  recovery.report_context_loss("metal-device-lost", now_ms=1000.0)
  inspect(recovery.loss_count(), content="1")
  inspect(recovery.last_loss_reason(), content="metal-device-lost")
  // Deadline is 1000.0 + 16.67 * 3 = 1050.01 ms.
  assert_true(recovery.should_recover(now_ms=1000.0))
  assert_true(recovery.should_recover(now_ms=1050.0))
  assert_false(recovery.should_recover(now_ms=1050.02))
  assert_true(recovery.recovery_deadline_expired(now_ms=1050.02))
  assert_false(recovery.recovery_deadline_expired(now_ms=1000.0))
  // Snapshot reflects the lost state.
  let snapshot = recovery.snapshot()
  inspect(snapshot.state, content="lost")
  inspect(snapshot.loss_count, content="1")
  inspect(snapshot.last_loss_reason, content="metal-device-lost")
  inspect(snapshot.recovery_deadline_ms, content="1050.01")
  inspect(snapshot.consecutive_failures, content="0")
  inspect(snapshot.fallback_reason, content="")
}

///|
/// Successful recovery: Idle -> Lost -> Recovering -> Recovered -> Idle.
/// The consecutive failure count resets to 0.
test "renderer recovery succeeds and resets failure count" {
  let recovery = RendererRecovery::new()
  recovery.report_context_loss("vulkan-device-lost", now_ms=0.0)
  recovery.report_recovery_started()
  assert_true(recovery.state() is RendererRecoveryState::Recovering)
  recovery.report_recovery_succeeded()
  assert_true(recovery.state() is RendererRecoveryState::Recovered)
  inspect(recovery.consecutive_failures(), content="0")
  recovery.acknowledge_recovered()
  assert_true(recovery.state() is RendererRecoveryState::Idle)
}

///|
/// One failed recovery leaves a retry budget; the second failure falls
/// back to raster (default budget = 2 consecutive failures).
test "renderer recovery falls back to raster after repeated failure" {
  let recovery = RendererRecovery::new()
  // First loss.
  recovery.report_context_loss("egl-context-lost", now_ms=10.0)
  recovery.report_recovery_started()
  recovery.report_recovery_failed("egl-create-context-failed", now_ms=12.0)
  inspect(recovery.consecutive_failures(), content="1")
  // First failure: retry, state goes back to Lost with a fresh deadline.
  assert_true(recovery.state() is RendererRecoveryState::Lost(_, _))
  // Second attempt.
  recovery.report_recovery_started()
  recovery.report_recovery_failed(
    "egl-create-context-failed-again",
    now_ms=14.0,
  )
  inspect(recovery.consecutive_failures(), content="2")
  // Second failure: budget exceeded, fall back to raster.
  assert_true(recovery.should_fallback_to_raster())
  match recovery.state() {
    FallbackToRaster(reason) =>
      inspect(reason, content="egl-create-context-failed-again")
    _ => fail("expected FallbackToRaster after repeated recovery failure")
  }
  // Once in fallback, new context-loss signals are ignored (renderer
  // thread is no longer on the GPU route): loss_count stays at 1.
  recovery.report_context_loss("another-loss", now_ms=20.0)
  inspect(recovery.loss_count(), content="1")
  // The terminal fallback reason persists.
  match recovery.state() {
    FallbackToRaster(reason) =>
      inspect(reason, content="egl-create-context-failed-again")
    _ => fail("expected FallbackToRaster to be terminal")
  }
  let snapshot = recovery.snapshot()
  inspect(snapshot.state, content="fallback-to-raster")
  inspect(snapshot.loss_count, content="1")
  inspect(snapshot.fallback_reason, content="egl-create-context-failed-again")
}

///|
/// A context-loss signal arriving during in-flight recovery counts the
/// in-flight recovery as a failure (per ADR 0006) and starts a fresh
/// loss deadline.
test "renderer recovery context loss during recovery counts as failure" {
  let recovery = RendererRecovery::new()
  recovery.report_context_loss("vulkan-device-lost", now_ms=0.0)
  recovery.report_recovery_started()
  // A new loss arrives before recreation completes.
  recovery.report_context_loss("vulkan-device-lost-again", now_ms=5.0)
  inspect(recovery.consecutive_failures(), content="1")
  inspect(recovery.loss_count(), content="2")
  inspect(recovery.last_loss_reason(), content="vulkan-device-lost-again")
  // State is Lost with a fresh deadline.
  assert_true(recovery.state() is RendererRecoveryState::Lost(_, _))
}

///|
/// Calling report_recovery_started outside of the Lost state is a no-op;
/// the renderer thread must not silently re-enter Recovering.
test "renderer recovery started is a no-op outside lost state" {
  let recovery = RendererRecovery::new()
  recovery.report_recovery_started()
  assert_true(recovery.state() is RendererRecoveryState::Idle)
  recovery.report_recovery_succeeded()
  assert_true(recovery.state() is RendererRecoveryState::Idle)
  recovery.report_recovery_failed("spurious", now_ms=0.0)
  assert_true(recovery.state() is RendererRecoveryState::Idle)
}

///|
/// Once `Recovered` is acknowledged, a subsequent loss restarts the
/// state machine from `Idle -> Lost` with a fresh deadline and failure
/// count starts at 0.
test "renderer recovery subsequent loss starts fresh after recovered" {
  let recovery = RendererRecovery::new()
  recovery.report_context_loss("first-loss", now_ms=100.0)
  recovery.report_recovery_started()
  recovery.report_recovery_succeeded()
  recovery.acknowledge_recovered()
  // Subsequent loss after a successful recovery: failure count is 0.
  recovery.report_context_loss("second-loss", now_ms=200.0)
  inspect(recovery.loss_count(), content="2")
  inspect(recovery.consecutive_failures(), content="0")
  assert_true(recovery.state() is RendererRecoveryState::Lost(_, _))
}

///|
/// Custom budget with a 120 Hz VSync and a 2-VSync recovery window.
test "renderer recovery custom budget is honored" {
  let budget = RendererRecoveryBudget::new(
    vsync_ms=8.33,
    recovery_vsync_budget=2,
    max_consecutive_recovery_failures=1,
  )
  let recovery = RendererRecovery::new(budget~)
  recovery.report_context_loss("d3d12-device-removed", now_ms=0.0)
  // Deadline = 0 + 8.33 * 2 = 16.66 ms.
  assert_true(recovery.should_recover(now_ms=16.65))
  assert_false(recovery.should_recover(now_ms=16.67))
  recovery.report_recovery_started()
  // Only 1 failure allowed before fallback.
  recovery.report_recovery_failed("d3d12-create-device-failed", now_ms=5.0)
  assert_true(recovery.should_fallback_to_raster())
}
