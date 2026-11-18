// White-box tests for tools/moui/gpu_promotion_scaffold decision logic.
// They pin platform mappings, short-smoke log interpretation, metrics overlay
// field extraction, fallbacks, and CLI validation.

///|
test "platform_mapping covers GPU platforms and rejects unknown ones" {
  match platform_mapping("macos") {
    Some(mapping) => {
      assert_eq(mapping.backend, "metal")
      assert_eq(mapping.surface_route, "metal-gpu")
      assert_eq(mapping.renderer, "skia-gpu-native")
    }
    None => fail("macos must have a mapping")
  }
  match platform_mapping("windows") {
    Some(mapping) => {
      assert_eq(mapping.backend, "d3d12")
      assert_eq(mapping.surface_route, "direct3d-gpu")
    }
    None => fail("windows must have a mapping")
  }
  match platform_mapping("web") {
    Some(mapping) => {
      assert_eq(mapping.backend, "webgpu")
      assert_eq(mapping.renderer, "webgpu-wasm")
    }
    None => fail("web must have a mapping")
  }
  match platform_mapping("plan9") {
    Some(_) => fail("unknown platform must not have a mapping")
    None => ()
  }
}

///|
test "platform_type_label labels known platforms and passes through others" {
  assert_eq(platform_type_label("macos"), "MacOS")
  assert_eq(platform_type_label("windows"), "Windows")
  assert_eq(platform_type_label("ios"), "IOS")
  assert_eq(platform_type_label("harmonyos"), "HarmonyOS")
  assert_eq(platform_type_label("web"), "Web")
  assert_eq(platform_type_label("plan9"), "plan9")
}

///|
test "parse_present_count reads the first decimal run after the marker" {
  assert_eq(parse_present_count("present_count=12"), 12)
  assert_eq(parse_present_count("PRESENT_COUNT=0003"), 3)
  assert_eq(parse_present_count("present_count="), 0)
  assert_eq(parse_present_count("present_count=abc"), 0)
  assert_eq(parse_present_count("no marker here"), 0)
  assert_true(contains_ci("Surface_Route=METAL-GPU", "surface_route=metal-gpu"))
}

///|
test "interpret_macos_gpu_smoke_log recognizes the short GPU path" {
  let success = interpret_macos_gpu_smoke_log(
    "surface_route=metal-gpu surface_gpu=true present_count=4 worker-owned",
  )
  assert_true(success.metal_route)
  assert_true(success.surface_gpu)
  assert_false(success.gpu_smoke_passed)
  assert_eq(success.present_count, 4)
  assert_true(success.worker_owned)
  assert_true(success.short_path_ok)
  let passed = interpret_macos_gpu_smoke_log(
    "MoUI Skia GPU Metal renderer smoke passed",
  )
  assert_true(passed.gpu_smoke_passed)
  assert_true(passed.worker_owned)
  assert_true(passed.short_path_ok)
  let route_only = interpret_macos_gpu_smoke_log("surface_route=metal-gpu")
  assert_true(route_only.metal_route)
  assert_false(route_only.surface_gpu)
  assert_false(route_only.short_path_ok)
  let empty = interpret_macos_gpu_smoke_log("")
  assert_false(empty.metal_route)
  assert_eq(empty.present_count, 0)
  assert_false(empty.worker_owned)
  assert_false(empty.short_path_ok)
}

///|
test "parse_metrics_overlay reads diagnostics and promotion gates" {
  let text =
    #|{"diagnostics":{"readbackCount":0,"workerThread":true,"surfaceGeneration":3},
    #|"promotionGates":{"readbackEliminated":true,"performance":{"refreshHz":120,"p95FrameMs":8.3},
    #|"memory":{"bounded":true},"contextLoss":{"rasterFallbackPreservedAppRuntime":true}},
    #|"notes":"measured"}
  match parse_metrics_overlay(text) {
    Ok(metrics) => {
      assert_true(metrics.has_values)
      assert_eq(metrics.readback_count, Some(0.0))
      assert_eq(metrics.worker_thread, Some(true))
      assert_eq(metrics.surface_generation, Some(3.0))
      assert_eq(metrics.readback_eliminated, Some(true))
      assert_eq(metrics.refresh_hz, Some(120.0))
      assert_eq(metrics.p95_frame_ms, Some(8.3))
      assert_eq(metrics.memory_bounded, Some(true))
      assert_eq(metrics.runtime_preserved, Some(true))
      assert_eq(metrics.automatic_fallback, None)
      assert_eq(metrics.notes, "measured")
    }
    Err(message) => fail(message)
  }
}

///|
test "parse_metrics_overlay defaults missing sections and rejects bad roots" {
  match parse_metrics_overlay("{}") {
    Ok(metrics) => {
      assert_true(metrics.has_values)
      assert_eq(metrics.readback_count, None)
      assert_eq(metrics.notes, "")
    }
    Err(message) => fail(message)
  }
  match parse_metrics_overlay("[]") {
    Ok(_) => fail("array root must be rejected")
    Err(message) => assert_eq(message, "metrics JSON root must be an object")
  }
  match parse_metrics_overlay("{") {
    Ok(_) => fail("invalid JSON must be rejected")
    Err(message) => assert_eq(message, "metrics JSON is invalid")
  }
}

///|
test "bool_or and number_or apply fallbacks for unmeasured values" {
  assert_true(bool_or(Some(true), false))
  assert_false(bool_or(Some(false), true))
  assert_true(bool_or(None, true))
  assert_eq(number_or(Some(8.5), 16.7), 8.5)
  assert_eq(number_or(None, 16.7), 16.7)
}

///|
test "parse_cli validates platform, mode, and duration" {
  match parse_cli(["--help"]) {
    Ok(options) => {
      assert_true(options.help)
      assert_eq(options.mode, "scaffold")
      assert_eq(options.duration_seconds, 600)
    }
    Err(message) => fail(message)
  }
  match
    parse_cli([
      "--platform", "MacOS", "--out-dir", "out", "--mode", "Full", "--duration-seconds",
      "90",
    ]) {
    Ok(options) => {
      assert_eq(options.platform, "macos")
      assert_eq(options.mode, "full")
      assert_eq(options.duration_seconds, 90)
    }
    Err(message) => fail(message)
  }
  match
    parse_cli(["--platform", "macos", "--out-dir", "out", "--mode", "wat"]) {
    Ok(_) => fail("unknown mode must be rejected")
    Err(message) =>
      assert_eq(message, "--mode must be scaffold, short-smoke, or full")
  }
  match
    parse_cli([
      "--platform", "macos", "--out-dir", "out", "--duration-seconds", "0",
    ]) {
    Ok(_) => fail("non-positive duration must be rejected")
    Err(message) => assert_eq(message, "--duration-seconds must be positive")
  }
  match parse_cli(["--platform", "macos", "--out-dir", "out"]) {
    Ok(options) => assert_eq(options.mode, "scaffold")
    Err(message) => fail(message)
  }
  match parse_cli([]) {
    Ok(_) => fail("missing platform must be rejected")
    Err(message) => assert_eq(message, "missing --platform")
  }
  match parse_cli(["--platform", "macos"]) {
    Ok(_) => fail("missing out dir must be rejected")
    Err(message) => assert_eq(message, "missing --out-dir")
  }
  match parse_cli(["-x"]) {
    Ok(_) => fail("unknown option must be rejected")
    Err(message) => assert_eq(message, "Unknown argument: -x")
  }
}
