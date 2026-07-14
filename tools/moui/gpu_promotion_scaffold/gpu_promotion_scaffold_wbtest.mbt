///|
test "platform mappings match promotion validator strings" {
  inspect(platform_mapping("macos").unwrap().backend, content="metal")
  inspect(platform_mapping("windows").unwrap().backend, content="d3d12")
  inspect(platform_mapping("linux").unwrap().backend, content="vulkan-wayland")
  inspect(platform_mapping("harmonyos").unwrap().backend, content="egl-gles")
  inspect(
    platform_mapping("web").unwrap().surface_route,
    content="webgpu-canvas",
  )
  inspect(platform_mapping("web").unwrap().renderer, content="webgpu-wasm")
  assert_true(platform_mapping("serenity") is None)
}

///|
test "macos gpu smoke log interpretation" {
  let sample =
    #|macOS Skia renderer route diagnostics: surface_route=metal-gpu; surface_gpu=true
    #|MoUI Skia GPU Metal renderer smoke passed route=metal-gpu surface_gpu=true present_count=1 pixel-markers
    #|worker-owned Metal first frame
  let ok = interpret_macos_gpu_smoke_log(sample)
  assert_true(ok.short_path_ok)
  assert_true(ok.worker_owned)
  assert_eq(ok.present_count, 1)
  let bad = interpret_macos_gpu_smoke_log(
    "surface_route=cpu-raster; surface_gpu=false",
  )
  assert_true(!bad.short_path_ok)
}

///|
test "pending manifest stays unpromoted" {
  let mapping = platform_mapping("macos").unwrap()
  let manifest = build_pending_manifest(
    "macos",
    mapping,
    "scaffold",
    "scripts/record-gpu-promotion-smoke.mjs --mode scaffold",
    "artifacts/gpu-promotion/macos/test",
    600,
    empty_observation(),
    empty_metrics(),
  )
  match manifest {
    Json::Object(fields) => {
      match fields.get("gpuPromoted") {
        Some(Json::False) => ()
        _ => fail("gpuPromoted must be false")
      }
      match fields.get("backend") {
        Some(Json::String(value)) => assert_eq(value, "metal")
        _ => fail("backend missing")
      }
      match fields.get("evidenceProvenance") {
        Some(Json::Object(provenance)) =>
          match provenance.get("kind") {
            Some(Json::String(kind)) => assert_eq(kind, "pending")
            _ => fail("provenance kind missing")
          }
        _ => fail("evidenceProvenance missing")
      }
    }
    _ => fail("manifest must be object")
  }
}

///|
test "gap report mentions promotion flip barrier" {
  let report = build_gap_report(
    "macos",
    "artifacts/gpu-promotion/macos/x",
    empty_observation(),
    false,
  )
  assert_true(report.contains("NativeGpuPlatform::Macos.gpu_promoted()"))
  assert_true(report.contains("readbackEliminated"))
  assert_true(report.contains("Not run"))
}

///|
test "metrics overlay merges without promoting" {
  let sample =
    #|{
    #|  "notes": "synthetic full harness draft",
    #|  "diagnostics": {
    #|    "readbackCount": 0,
    #|    "workerThread": true,
    #|    "surfaceGeneration": 12,
    #|    "contextGeneration": 1,
    #|    "recoveryCount": 0,
    #|    "fallbackCount": 0
    #|  },
    #|  "promotionGates": {
    #|    "readbackEliminated": true,
    #|    "rendererThread": true,
    #|    "mailboxOk": false,
    #|    "performance": {
    #|      "refreshHz": 60,
    #|      "durationSeconds": 12,
    #|      "p95FrameMs": 14.0,
    #|      "droppedFramePercent": 0.2,
    #|      "inputToPresentPVsyncIntervals": 1.0
    #|    },
    #|    "memory": {
    #|      "bounded": true,
    #|      "surfaceRecreationCycles": 3,
    #|      "foregroundBackgroundCycles": 1
    #|    },
    #|    "contextLoss": {
    #|      "recoveredWithinVsyncs": 0,
    #|      "rasterFallbackPreservedAppRuntime": false
    #|    },
    #|    "rasterFallback": {
    #|      "automaticAfterRepeatedFailure": false
    #|    }
    #|  }
    #|}
  let metrics = parse_metrics_overlay(sample).unwrap()
  assert_true(metrics.has_values)
  assert_true(metrics.worker_thread is Some(true))
  let mapping = platform_mapping("macos").unwrap()
  let manifest = build_pending_manifest(
    "macos",
    mapping,
    "full",
    "scripts/record-gpu-promotion-smoke.mjs --mode full",
    "artifacts/gpu-promotion/macos/full-draft",
    600,
    empty_observation(),
    metrics,
  )
  match manifest {
    Json::Object(fields) => {
      match fields.get("gpuPromoted") {
        Some(Json::False) => ()
        _ => fail("metrics must not set gpuPromoted")
      }
      match fields.get("promotionGates") {
        Some(Json::Object(gates)) =>
          match gates.get("performance") {
            Some(Json::Object(perf)) =>
              match perf.get("durationSeconds") {
                Some(Json::Number(value, ..)) => assert_eq(value, 12.0)
                _ => fail("durationSeconds missing")
              }
            _ => fail("performance missing")
          }
        _ => fail("promotionGates missing")
      }
      match fields.get("recording") {
        Some(Json::Object(recording)) =>
          match recording.get("metricsMerged") {
            Some(Json::True) => ()
            _ => fail("metricsMerged should be true")
          }
        _ => fail("recording missing")
      }
    }
    _ => fail("manifest must be object")
  }
}
