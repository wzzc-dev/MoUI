///|
fn promotion_manifest(
  platform? : String = "windows",
  renderer? : String = "skia-gpu-native",
  backend? : String = "d3d12",
  route? : String = "direct3d-gpu",
  promoted? : Bool = true,
  refresh_hz? : Int = 60,
  p95_frame_ms? : Double = 16.0,
) -> String {
  let provenance_kind = if promoted { "github-actions" } else { "pending" }
  let runner = if promoted { "windows-gpu-runner" } else { "" }
  let artifact = if promoted { "run-123/gpu-proof" } else { "" }
  (
    {
      "schemaVersion": 1,
      "renderer": renderer,
      "platform": platform,
      "backend": backend,
      "gpuPromoted": promoted,
      "requestedMode": "auto",
      "surfaceRoute": route,
      "evidenceProvenance": {
        "kind": provenance_kind,
        "runner": runner,
        "artifact": artifact,
      },
      "diagnostics": {
        "readbackCount": 0,
        "workerThread": platform != "web",
        "surfaceGeneration": 101,
        "contextGeneration": 2,
        "recoveryCount": 1,
        "fallbackCount": 1,
      },
      "promotionGates": {
        "readbackEliminated": promoted,
        "rendererThread": promoted,
        "mailboxOk": promoted,
        "performance": {
          "refreshHz": refresh_hz,
          "durationSeconds": 600,
          "p95FrameMs": p95_frame_ms,
          "droppedFramePercent": 0.5,
          "inputToPresentPVsyncIntervals": 1.5,
        },
        "memory": {
          "bounded": promoted,
          "surfaceRecreationCycles": if promoted {
            100
          } else {
            0
          },
          "foregroundBackgroundCycles": if promoted {
            100
          } else {
            0
          },
        },
        "contextLoss": {
          "recoveredWithinVsyncs": if promoted {
            2
          } else {
            0
          },
          "rasterFallbackPreservedAppRuntime": promoted,
        },
        "rasterFallback": { "automaticAfterRepeatedFailure": promoted },
      },
    } : Json).stringify()
}

///|
test "pending GPU promotion manifest validates without promotion claim" {
  debug_inspect(
    validate_manifest_text(promotion_manifest(promoted=false), false),
    content="[]",
  )
}

///|
test "native GPU promotion manifest passes all gates" {
  debug_inspect(
    validate_manifest_text(promotion_manifest(), true),
    content="[]",
  )
}

///|
test "Web GPU promotion uses the WebGPU route" {
  debug_inspect(
    validate_manifest_text(
      promotion_manifest(
        platform="web",
        renderer="webgpu-wasm",
        backend="webgpu",
        route="webgpu-canvas",
      ),
      true,
    ),
    content="[]",
  )
}

///|
test "120 Hz GPU promotion enforces the 8.3 ms p95 gate" {
  let failures = validate_manifest_text(
    promotion_manifest(refresh_hz=120, p95_frame_ms=9.0),
    true,
  )
  assert_true(failures.any(message => message.contains("p95FrameMs")))
}

///|
test "require-passed rejects an unpromoted manifest" {
  let failures = validate_manifest_text(
    promotion_manifest(promoted=false),
    true,
  )
  assert_true(failures.any(message => message.contains("gpuPromoted")))
  assert_true(failures.any(message => message.contains("provenance")))
}
