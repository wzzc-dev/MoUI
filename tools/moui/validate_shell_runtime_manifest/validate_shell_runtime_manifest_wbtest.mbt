///|
fn valid_manifest() -> String {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "mode": "shell-runtime-smoke",
    #|  "generatedBy": "scripts/record-shell-runtime-smoke.mjs",
    #|  "platform": "ios",
    #|  "app": "showcase",
    #|  "status": "passed",
    #|  "build": {
    #|    "fallbackSkia": false,
    #|    "artifact": "artifacts/ios/showcase/MoUIShowcase.app",
    #|    "command": "scripts/build-shell-ios-app.sh --app showcase"
    #|  },
    #|  "artifacts": {
    #|    "screenshotBefore": "artifacts/shell-runtime/ios/showcase/screenshot-before.png",
    #|    "screenshot": "artifacts/shell-runtime/ios/showcase/screenshot.png",
    #|    "log": "artifacts/shell-runtime/ios/showcase/runtime.log"
    #|  },
    #|  "screenshot": {
    #|    "width": 390,
    #|    "height": 844,
    #|    "totalPixels": 329160,
    #|    "contentPixels": 42000,
    #|    "distinctColorBuckets": 20
    #|  },
    #|  "pixelChange": {
    #|    "comparable": true,
    #|    "changedPixels": 2400,
    #|    "changedRatio": 0.007
    #|  },
    #|  "observations": {
    #|    "lifecycleAttach": "yes",
    #|    "lifecycleDetach": "yes",
    #|    "nonblankFirstFrame": "yes",
    #|    "resize": "yes",
    #|    "representativeInput": "yes",
    #|    "scrollInput": "yes",
    #|    "cleanShutdown": "yes",
    #|    "ime": "yes",
    #|    "clipboard": "yes",
    #|    "accessibility": "yes",
    #|    "accessibilityTree": "yes",
    #|    "accessibilityFocus": "yes",
    #|    "accessibilityAction": "yes",
    #|    "asyncImage": "yes",
    #|    "platformViewCreate": "yes",
    #|    "platformViewResize": "yes",
    #|    "platformViewClip": "yes",
    #|    "platformViewEvent": "yes",
    #|    "platformViewDispose": "yes",
    #|    "hostChannelSuccess": "yes",
    #|    "hostChannelError": "yes",
    #|    "hostChannelCancel": "yes",
    #|    "hostChannelExactlyOnce": "yes",
    #|    "hostChannelLateAfterDispose": "yes",
    #|    "gpuRecovery": "yes",
    #|    "stress": "yes",
    #|    "realDeviceSigning": "pending"
    #|  },
    #|  "evidenceBoundary": "non-fallback matching-host smoke evidence; fallback builds are packaging only"
    #|}
  text
}

///|
test "valid passed manifest" {
  let failures = validate_manifest_text(valid_manifest(), true)
  inspect(failures, content="[]")
}

///|
test "fallback cannot pass" {
  let text = valid_manifest().replace(
    old="\"fallbackSkia\": false",
    new="\"fallbackSkia\": true",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("fallback Skia")))
}

///|
test "showcase requires scroll evidence" {
  let text = valid_manifest().replace(
    old="\"scrollInput\": \"yes\"",
    new="\"scrollInput\": \"pending\"",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("scrollInput")))
}

///|
test "passed evidence requires visible input change" {
  let text = valid_manifest().replace(
    old="\"changedPixels\": 2400",
    new="\"changedPixels\": 0",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("changedPixels")))
}

///|
test "passed evidence requires platform service observations" {
  let text = valid_manifest().replace(
    old="\"ime\": \"yes\"",
    new="\"ime\": \"pending\"",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("observations.ime")))
}

///|
test "passed evidence requires PlatformView and Host Channel observations" {
  let platform_view = valid_manifest().replace(
    old="\"platformViewCreate\": \"yes\"",
    new="\"platformViewCreate\": \"pending\"",
  )
  let platform_failures = validate_manifest_text(platform_view, true)
  assert_true(
    platform_failures.any(message => {
      message.contains("observations.platformViewCreate")
    }),
  )
  let host_channel = valid_manifest().replace(
    old="\"hostChannelExactlyOnce\": \"yes\"",
    new="\"hostChannelExactlyOnce\": \"pending\"",
  )
  let host_failures = validate_manifest_text(host_channel, true)
  assert_true(
    host_failures.any(message => {
      message.contains("observations.hostChannelExactlyOnce")
    }),
  )
}

///|
test "passed evidence requires GPU recovery and stress observations" {
  for field in ["gpuRecovery", "stress"] {
    let text = valid_manifest().replace(
      old="\"\{field}\": \"yes\"",
      new="\"\{field}\": \"pending\"",
    )
    let failures = validate_manifest_text(text, true)
    assert_true(
      failures.any(message => message.contains("observations." + field)),
    )
  }
}

///|
test "partial evidence is valid but cannot satisfy require passed" {
  let text = valid_manifest()
    .replace(old="\"status\": \"passed\"", new="\"status\": \"partial\"")
    .replace(old="\"resize\": \"yes\"", new="\"resize\": \"no\"")
  debug_inspect(validate_manifest_text(text, false), content="[]")
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("--require-passed")))
}

// ---------------------------------------------------------------------------
// Phase 2.3 (ADR 0006 § Promotion gates): `renderer` block + GPU promotion
// evidence schema. The renderer block is optional; when `gpuPromoted=true`,
// the validator requires the matching `gpuPromotionEvidence` block, and
// every gate must be satisfied when `--require-passed` is used.
// ---------------------------------------------------------------------------

///|
fn manifest_with_raster_renderer() -> String {
  let old =
    #|  "evidenceBoundary": "non-fallback matching-host smoke evidence; fallback builds are packaging only"
    #|}
  let new =
    #|  "evidenceBoundary": "non-fallback matching-host smoke evidence; fallback builds are packaging only",
    #|  "renderer": {
    #|    "requested": "skia-raster",
    #|    "selected": "SkiaRasterNative",
    #|    "surfaceRoute": "raster",
    #|    "gpuAvailable": true,
    #|    "gpuPromoted": false,
    #|    "fallbackReason": "raster-requested"
    #|  }
    #|}
  valid_manifest().replace(old~, new~)
}

///|
fn manifest_with_gpu_promoted_renderer() -> String {
  let old =
    #|  "evidenceBoundary": "non-fallback matching-host smoke evidence; fallback builds are packaging only"
    #|}
  let new =
    #|  "evidenceBoundary": "non-fallback matching-host smoke evidence; fallback builds are packaging only",
    #|  "renderer": {
    #|    "requested": "skia-gpu",
    #|    "selected": "SkiaGpuNative",
    #|    "surfaceRoute": "metal-gpu",
    #|    "gpuAvailable": true,
    #|    "gpuPromoted": true,
    #|    "fallbackReason": ""
    #|  },
    #|  "gpuPromotionEvidence": {
    #|    "claimed": true,
    #|    "readbackEliminated": true,
    #|    "rendererThread": true,
    #|    "mailboxOk": true,
    #|    "performance": {
    #|      "p95FrameMs": 12.5,
    #|      "droppedFramePercent": 0.3,
    #|      "inputToPresentPVsyncIntervals": 1.5
    #|    },
    #|    "memory": {
    #|      "bounded": true,
    #|      "surfaceRecreationCycles": 100,
    #|      "foregroundBackgroundCycles": 100
    #|    },
    #|    "contextLoss": {
    #|      "recoveredWithinVsyncs": 2.0,
    #|      "rasterFallbackPreservedAppRuntime": true
    #|    },
    #|    "rasterFallback": {
    #|      "automaticAfterRepeatedFailure": true
    #|    }
    #|  }
    #|}
  valid_manifest().replace(old~, new~)
}

///|
test "renderer block with gpuPromoted=false is valid without evidence" {
  // The renderer block is optional; gpuPromoted=false must not require
  // the gpuPromotionEvidence block.
  debug_inspect(
    validate_manifest_text(manifest_with_raster_renderer(), true),
    content="[]",
  )
}

///|
test "renderer block with gpuPromoted=true and full evidence passes require-passed" {
  // All seven ADR 0006 gates are satisfied; the manifest should pass
  // even under --require-passed.
  debug_inspect(
    validate_manifest_text(manifest_with_gpu_promoted_renderer(), true),
    content="[]",
  )
}

///|
test "renderer block surfaceRoute must be a known route label" {
  let text = manifest_with_raster_renderer().replace(
    old="\"surfaceRoute\": \"raster\"",
    new="\"surfaceRoute\": \"cuda-gpu\"",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("surfaceRoute")))
}

///|
test "gpuPromoted=true without gpuPromotionEvidence fails" {
  // Drop the evidence block: the validator must complain that
  // gpuPromotionEvidence is missing.
  let old =
    #|  },
    #|  "gpuPromotionEvidence": {
    #|    "claimed": true,
    #|    "readbackEliminated": true,
    #|    "rendererThread": true,
    #|    "mailboxOk": true,
    #|    "performance": {
    #|      "p95FrameMs": 12.5,
    #|      "droppedFramePercent": 0.3,
    #|      "inputToPresentPVsyncIntervals": 1.5
    #|    },
    #|    "memory": {
    #|      "bounded": true,
    #|      "surfaceRecreationCycles": 100,
    #|      "foregroundBackgroundCycles": 100
    #|    },
    #|    "contextLoss": {
    #|      "recoveredWithinVsyncs": 2.0,
    #|      "rasterFallbackPreservedAppRuntime": true
    #|    },
    #|    "rasterFallback": {
    #|      "automaticAfterRepeatedFailure": true
    #|    }
    #|  }
    #|}
  let new =
    #|  }
    #|}
  let text = manifest_with_gpu_promoted_renderer().replace(old~, new~)
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("gpuPromotionEvidence")))
}

///|
test "gpuPromoted=true under require-passed rejects readbackEliminated=false" {
  // Gate 1 (readbackEliminated) is the most important gate: GPU
  // promotion must never be claimed while readback is still present.
  let text = manifest_with_gpu_promoted_renderer().replace(
    old="\"readbackEliminated\": true,",
    new="\"readbackEliminated\": false,",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(
    failures.any(message => message.contains("readbackEliminated must be true")),
  )
}

///|
test "gpuPromoted=true under require-passed rejects p95FrameMs above 16.7" {
  // Gate 4 (performance): p95 frame must be ≤ 16.7 ms at 60 Hz.
  let text = manifest_with_gpu_promoted_renderer().replace(
    old="\"p95FrameMs\": 12.5,",
    new="\"p95FrameMs\": 20.0,",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(
    failures.any(message => message.contains("p95FrameMs must be positive")),
  )
}

///|
test "gpuPromoted=true under require-passed rejects low surface recreation cycles" {
  // Gate 5 (memory): 100 surface recreation + foreground/background cycles
  // are required. Surface recreation cycles below 100 must fail.
  let text = manifest_with_gpu_promoted_renderer().replace(
    old="\"surfaceRecreationCycles\": 100,",
    new="\"surfaceRecreationCycles\": 50,",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(
    failures.any(message => {
      message.contains("surfaceRecreationCycles must be ≥ 100")
    }),
  )
}

///|
test "gpuPromoted=true under require-passed rejects slow context loss recovery" {
  // Gate 6 (contextLoss): recovery within 3 VSyncs.
  let text = manifest_with_gpu_promoted_renderer().replace(
    old="\"recoveredWithinVsyncs\": 2.0,",
    new="\"recoveredWithinVsyncs\": 4.0,",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(
    failures.any(message => {
      message.contains("recoveredWithinVsyncs must be positive and ≤ 3.0")
    }),
  )
}

///|
test "gpuPromoted=true without require-passed accepts failing gates" {
  // Without --require-passed, the evidence gates are parsed but not
  // asserted. This allows partial manifests to carry the renderer block
  // with `gpuPromoted=true` for diagnostics while not yet satisfying
  // every gate. The manifest must still have status=passed here.
  let text = manifest_with_gpu_promoted_renderer().replace(
    old="\"readbackEliminated\": true,",
    new="\"readbackEliminated\": false,",
  )
  debug_inspect(validate_manifest_text(text, false), content="[]")
}
