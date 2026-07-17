///|
fn sample_metrics(
  duration? : Double = 600.0,
  p95? : Double = 10.0,
  readback? : Double = 0.0,
) -> Json {
  {
    "diagnostics": {
      "readbackCount": readback,
      "workerThread": true,
      "surfaceGeneration": 1,
      "contextGeneration": 1,
      "recoveryCount": 1,
      "fallbackCount": 0,
    },
    "promotionGates": {
      "readbackEliminated": true,
      "rendererThread": true,
      "mailboxOk": true,
      "performance": {
        "refreshHz": 60,
        "durationSeconds": duration,
        "p95FrameMs": p95,
        "droppedFramePercent": 0.1,
        "inputToPresentPVsyncIntervals": 1.0,
      },
      "memory": {
        "bounded": true,
        "surfaceRecreationCycles": 100,
        "foregroundBackgroundCycles": 100,
      },
      "contextLoss": {
        "recoveredWithinVsyncs": 2,
        "rasterFallbackPreservedAppRuntime": true,
      },
      "rasterFallback": { "automaticAfterRepeatedFailure": true },
    },
  }
}

///|
test "accepts gates that meet ADR thresholds" {
  let failures = evaluate_claim_gates(sample_metrics())
  debug_inspect(failures.length(), content="0")
}

///|
test "rejects short duration and high p95" {
  let failures = evaluate_claim_gates(sample_metrics(duration=10.0, p95=30.0))
  debug_inspect(
    failures.any(item => item.contains("durationSeconds>=600")),
    content="true",
  )
  debug_inspect(
    failures.any(item => item.contains("p95FrameMs")),
    content="true",
  )
}

///|
test "rejects nonzero readback" {
  let failures = evaluate_claim_gates(sample_metrics(readback=1.0))
  debug_inspect(
    failures.any(item => item.contains("readbackCount==0")),
    content="true",
  )
}

///|
test "builds promoted claim payload" {
  match build_claim(sample_metrics(), "runner", "artifact", "metrics.json") {
    Json::Object(fields) => {
      debug_inspect(fields.get("gpuPromoted"), content="Some(True)")
      debug_inspect(fields.get("platform"), content="Some(String(\"macos\"))")
      debug_inspect(
        fields.get("surfaceRoute"),
        content="Some(String(\"metal-gpu\"))",
      )
    }
    _ => fail("expected claim object")
  }
}
