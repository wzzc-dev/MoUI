///|
/// White-box tests for the promotion-claim gate arithmetic in
/// `claim_macos_gpu_promotion`. The fixtures are synthetic metrics objects; the
/// assertions cover the refresh-dependent p95 ceiling, defaulted gate values,
/// and repository-root path stripping.

///|
fn claim_metrics(
  refresh_hz : Double,
  p95_frame_ms : Double,
  readback : Double,
) -> Json {
  let template =
    #|{"promotionGates":{"readbackEliminated":true,"rendererThread":true,"mailboxOk":true,"performance":{"durationSeconds":600,"refreshHz":REFRESH_HZ,"p95FrameMs":P95_MS,"droppedFramePercent":0.5,"inputToPresentPVsyncIntervals":2},"memory":{"bounded":true,"surfaceRecreationCycles":100,"foregroundBackgroundCycles":100},"contextLoss":{"recoveredWithinVsyncs":3,"rasterFallbackPreservedAppRuntime":true},"rasterFallback":{"automaticAfterRepeatedFailure":true}},"diagnostics":{"readbackCount":READBACK,"workerThread":true}}
  let text = template
    .replace(old="REFRESH_HZ", new=refresh_hz.to_string())
    .replace(old="P95_MS", new=p95_frame_ms.to_string())
    .replace(old="READBACK", new=readback.to_string())
  @json.parse(text) catch {
    _ => abort("claim metrics fixture is not valid JSON")
  }
}

///|
test "relative_to_root strips the repository root and leaves outsiders intact" {
  assert_eq(relative_to_root("/repo", "/repo/tools/x.mbt"), "tools/x.mbt")
  assert_eq(relative_to_root("/repo/", "/repo/tools/x.mbt"), "tools/x.mbt")
  assert_eq(
    relative_to_root("/repo", "/elsewhere/tools/x.mbt"),
    "/elsewhere/tools/x.mbt",
  )
  // Windows-style paths are not normalized; a non-matching separator must not
  // silently truncate the path.
  assert_eq(
    relative_to_root("C:\\repo", "C:\\repo\\tools\\x.mbt"),
    "C:\\repo\\tools\\x.mbt",
  )
}

///|
test "boolean and number defaults apply only when a gate is missing" {
  assert_true(bool_or(Some(true), false))
  assert_false(bool_or(Some(false), true))
  assert_true(bool_or(None, true))
  assert_false(bool_or(None, false))
  assert_eq(number_or(Some(8.3), 0.0), 8.3)
  assert_eq(number_or(None, 16.7), 16.7)
}

///|
test "evaluate_claim_gates accepts metrics that clear every gate" {
  assert_eq(evaluate_claim_gates(claim_metrics(120.0, 8.3, 0.0)).length(), 0)
}

///|
test "evaluate_claim_gates applies the refresh-dependent p95 ceiling" {
  // 120 Hz raises the ceiling to 8.3 ms; 8.4 must fail with the printed limit.
  let high_refresh = evaluate_claim_gates(claim_metrics(120.0, 8.4, 0.0))
  assert_true(high_refresh.contains("performance.p95FrameMs<=8.3"))
  // Below 120 Hz the ceiling relaxes to 16.7 ms.
  assert_eq(evaluate_claim_gates(claim_metrics(60.0, 16.7, 0.0)).length(), 0)
  let low_refresh = evaluate_claim_gates(claim_metrics(60.0, 16.8, 0.0))
  assert_true(low_refresh.contains("performance.p95FrameMs<=16.7"))
}

///|
test "evaluate_claim_gates rejects non-objects and defaulted readback" {
  let not_object = evaluate_claim_gates(Json::array([]))
  assert_eq(not_object.length(), 1)
  assert_eq(not_object[0], "metrics must be an object")
  // A missing readbackCount defaults to 1.0, which is a promotion violation.
  let failures = evaluate_claim_gates(claim_metrics(120.0, 8.3, 1.0))
  assert_true(failures.contains("diagnostics.readbackCount==0"))
}
