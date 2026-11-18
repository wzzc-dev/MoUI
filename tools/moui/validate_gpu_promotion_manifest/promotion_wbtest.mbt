// White-box tests for the GPU promotion manifest gate: platform/backend/route
// matrices, CLI parsing, required fields, and `--require-passed` gates.

///|
fn passing_manifest_text() -> String {
  (
    #|{
    #|  "schemaVersion": 1,
    #|  "platform": "macos",
    #|  "renderer": "skia-gpu-native",
    #|  "backend": "metal",
    #|  "surfaceRoute": "metal-gpu",
    #|  "requestedMode": "gpu",
    #|  "gpuPromoted": true,
    #|  "evidenceProvenance": {
    #|    "kind": "matching-host-artifact",
    #|    "runner": "macos-host",
    #|    "artifact": "gpu-promotion.json"
    #|  },
    #|  "diagnostics": {
    #|    "readbackCount": 0.0,
    #|    "workerThread": true,
    #|    "surfaceGeneration": 1.0,
    #|    "contextGeneration": 1.0,
    #|    "recoveryCount": 0.0,
    #|    "fallbackCount": 0.0
    #|  },
    #|  "promotionGates": {
    #|    "readbackEliminated": true,
    #|    "rendererThread": true,
    #|    "mailboxOk": true,
    #|    "performance": {
    #|      "refreshHz": 60.0,
    #|      "durationSeconds": 600.0,
    #|      "p95FrameMs": 16.0,
    #|      "droppedFramePercent": 0.5,
    #|      "inputToPresentPVsyncIntervals": 1.0
    #|    },
    #|    "memory": {
    #|      "bounded": true,
    #|      "surfaceRecreationCycles": 100.0,
    #|      "foregroundBackgroundCycles": 100.0
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
  )
}

///|
fn parsed_cli(args : Array[String]) -> CliOptions {
  match parse_cli(args) {
    Ok(options) => options
    Err(_) =>
      {
        manifest_path: "<error>",
        display_path: "<error>",
        require_passed: false,
        help: false,
      }
  }
}

///|
fn cli_error(args : Array[String]) -> String {
  match parse_cli(args) {
    Err(message) => message
    Ok(_) => "<ok>"
  }
}

///|
test "platform backend and surface routes only match the documented tables" {
  assert_true(platform_supported("web"))
  assert_true(platform_supported("harmonyos"))
  assert_true(!platform_supported("plan9"))
  assert_true(platform_backend_valid("macos", "metal"))
  assert_true(platform_backend_valid("android", "egl-gles"))
  assert_true(!platform_backend_valid("android", "metal"))
  assert_true(!platform_backend_valid("windows", "vulkan-wayland"))
  assert_true(platform_route_valid("web", "webgpu-canvas"))
  assert_true(platform_route_valid("ios", "metal-gpu"))
  assert_true(!platform_route_valid("harmonyos", "vulkan-gpu"))
}

///|
test "parse_cli resolves manifest, display path, and require-passed" {
  let plain = parsed_cli(["gpu.json"])
  assert_eq(plain.manifest_path, "gpu.json")
  assert_eq(plain.display_path, "gpu.json")
  assert_true(!plain.require_passed)
  let full = parsed_cli([
    "gpu.json", "--require-passed", "--display-path", "shown.json",
  ])
  assert_true(full.require_passed)
  assert_eq(full.display_path, "shown.json")
  let help = parsed_cli(["--help"])
  assert_true(help.help)
  assert_eq(help.manifest_path, "")
  assert_eq(cli_error([]), "missing manifest.json path")
  assert_eq(cli_error(["--display-path"]), "missing value for --display-path")
  assert_eq(cli_error(["a.json", "b.json"]), "unexpected argument: b.json")
  assert_eq(cli_error(["--wat"]), "Unknown argument: --wat")
}

///|
test "validate_manifest_text rejects bad JSON and incomplete manifests" {
  let invalid = validate_manifest_text("{", false)
  assert_eq(invalid.length(), 1)
  assert_eq(invalid[0], "failed to read JSON: invalid JSON")
  let not_object = validate_manifest_text("[]", false)
  assert_eq(not_object[0], "manifest root must be an object")
  let empty = validate_manifest_text("{}", false)
  // Every missing required field reports once across schema, platform,
  // renderer, backend, route, provenance, diagnostics, and promotion gates.
  assert_eq(empty.length(), 39)
  assert_true(empty.contains("missing number field 'schemaVersion'"))
  assert_true(empty.contains("schemaVersion must be 1"))
  assert_true(empty.contains("field 'gpuPromoted' must be a bool"))
  assert_true(empty.contains("field 'evidenceProvenance' must be an object"))
}

///|
test "a complete manifest passes and mutations trip the right gates" {
  let sample = passing_manifest_text()
  assert_eq(validate_manifest_text(sample, false).length(), 0)
  assert_eq(validate_manifest_text(sample, true).length(), 0)
  // Cross-field validation: the backend and route must fit the platform.
  let windows = sample.replace(old="\"macos\"", new="\"windows\"")
  let windows_failures = validate_manifest_text(windows, false)
  assert_true(
    windows_failures.contains("backend 'metal' is invalid for windows"),
  )
  assert_true(
    windows_failures.contains("surfaceRoute 'metal-gpu' is invalid for windows"),
  )
  // Web needs the WASM renderer and the WebGPU canvas route.
  let web = sample
    .replace(old="\"macos\"", new="\"web\"")
    .replace(old="\"skia-gpu-native\"", new="\"webgpu-wasm\"")
    .replace(old="\"metal\"", new="\"webgpu\"")
    .replace(old="\"metal-gpu\"", new="\"webgpu-canvas\"")
  assert_eq(validate_manifest_text(web, true).length(), 0)
  let slow = sample.replace(
    old="\"refreshHz\": 60.0",
    new="\"refreshHz\": 59.0",
  )
  assert_true(
    validate_manifest_text(slow, true).contains(
      "promotionGates.performance.refreshHz must be at least 60",
    ),
  )
  let pending = sample.replace(
    old="\"matching-host-artifact\"",
    new="\"pending\"",
  )
  assert_true(
    validate_manifest_text(pending, true).contains(
      "passed GPU promotion requires concrete runner and artifact provenance",
    ),
  )
}
