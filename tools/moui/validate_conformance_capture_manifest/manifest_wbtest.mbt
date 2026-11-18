// White-box tests for tools/moui/validate_conformance_capture_manifest.
// They pin the expected evidence tables, required counter/metric coverage,
// mode-dependent target handling, and manifest failure reporting.

///|
test "expected evidence tables are complete" {
  let targets = expected_benchmark_targets()
  assert_eq(targets.length(), 1)
  match expected_benchmark_target("showcase-web-wasm") {
    Some(target) => {
      assert_eq(target.target, "examples/showcase/web_wasm")
      assert_eq(
        target.url,
        "http://127.0.0.1:18080/examples/showcase/web_wasm/",
      )
      assert_eq(
        target.metrics_path,
        "artifacts/benchmarks/showcase-web-wasm.json",
      )
    }
    None => fail("showcase target must exist")
  }
  assert_true(expected_benchmark_target("missing") is None)
  assert_eq(expected_screenshots().length(), 3)
  match expected_screenshot("tablet") {
    Some(screenshot) => {
      assert_eq(screenshot.viewport, "1024x768")
      assert_eq(
        screenshot.path,
        "artifacts/golden/showcase-web-wasm/tablet.png",
      )
    }
    None => fail("tablet screenshot must exist")
  }
  assert_true(expected_screenshot("missing") is None)
}

///|
test "required counters and metrics list the inspector contract" {
  let counters = required_counters()
  assert_eq(counters.length(), 12)
  assert_true(counters.any(value => value == "unbalanced_pop_count"))
  assert_true(counters.any(value => value == "open_layer_depth"))
  assert_false(counters.any(value => value == "present_count"))
  let metrics = required_metrics()
  assert_eq(metrics.length(), 6)
  assert_true(metrics.any(value => value == "render_inspector_counters"))
  assert_true(metrics.any(value => value == "memory_bytes"))
}

///|
test "benchmark_targets_for_mode only requires targets in benchmark mode" {
  let golden : Map[String, Json] = Map([])
  let golden_failures : Array[String] = []
  assert_eq(benchmark_targets_for_mode(golden, "golden", golden_failures), [])
  assert_eq(golden_failures.length(), 0)
  let with_targets : Map[String, Json] = Map([])
  with_targets["benchmarkTargets"] = Json::array([Json::object(Map([]))])
  assert_eq(benchmark_targets_for_mode(with_targets, "golden", []).length(), 1)
  let benchmark_failures : Array[String] = []
  assert_eq(
    benchmark_targets_for_mode(golden, "benchmark", benchmark_failures),
    [],
  )
  assert_eq(benchmark_failures.length(), 1)
  assert_eq(benchmark_failures[0], "field 'benchmarkTargets' must be an array")
}

///|
test "benchmark targets validate known and unknown names" {
  let unknown : Map[String, Json] = Map([])
  unknown["name"] = Json::string("custom")
  unknown["target"] = Json::string("examples/custom")
  unknown["url"] = Json::string("http://127.0.0.1:1/custom/")
  unknown["metricsPath"] = Json::string("artifacts/custom.json")
  let unknown_failures = validate_benchmark_target(
    Json::object(unknown),
    0,
    Map([]),
  )
  assert_eq(unknown_failures.length(), 1)
  assert_eq(
    unknown_failures[0],
    "benchmarkTargets[0].metricsPath must stay under artifacts/benchmarks/",
  )
  let known : Map[String, Json] = Map([])
  known["name"] = Json::string("showcase-web-wasm")
  known["target"] = Json::string("examples/showcase/web_wasm")
  known["url"] = Json::string("http://127.0.0.1:18080/wrong/")
  known["metricsPath"] = Json::string(
    "artifacts/benchmarks/showcase-web-wasm.json",
  )
  let seen : Map[String, Bool] = Map([])
  let known_failures = validate_benchmark_target(Json::object(known), 1, seen)
  assert_eq(known_failures.length(), 1)
  assert_eq(
    known_failures[0],
    "benchmarkTargets[1].url must be 'http://127.0.0.1:18080/examples/showcase/web_wasm/' for 'showcase-web-wasm'",
  )
  let duplicate_failures = validate_benchmark_target(
    Json::object(known),
    2,
    seen,
  )
  assert_true(
    duplicate_failures.any(message => {
      message == "duplicate benchmark target 'showcase-web-wasm'"
    }),
  )
}

///|
test "screenshot artifacts validate names, viewports, and paths" {
  let unknown : Map[String, Json] = Map([])
  unknown["name"] = Json::string("custom")
  unknown["viewport"] = Json::string("1x1")
  unknown["path"] = Json::string("artifacts/custom.png")
  let unknown_failures = validate_screenshot_artifact(
    Json::object(unknown),
    0,
    Map([]),
  )
  assert_eq(unknown_failures.length(), 1)
  assert_eq(
    unknown_failures[0],
    "screenshotArtifacts[0].path must stay under artifacts/golden/showcase-web-wasm/",
  )
  let known : Map[String, Json] = Map([])
  known["name"] = Json::string("desktop")
  known["viewport"] = Json::string("1x1")
  known["path"] = Json::string("artifacts/golden/showcase-web-wasm/desktop.png")
  let known_failures = validate_screenshot_artifact(
    Json::object(known),
    1,
    Map([]),
  )
  assert_eq(known_failures.length(), 1)
  assert_eq(
    known_failures[0],
    "screenshotArtifacts[1].viewport must be '1440x900' for 'desktop'",
  )
}

///|
test "empty manifest reports every missing evidence group" {
  let failures = validate_manifest_text("{}", "")
  assert_eq(failures.length(), 34)
  assert_true(failures.any(message => message == "schemaVersion must be 1"))
  assert_true(
    failures.any(message => message == "missing non-empty string field 'mode'"),
  )
  assert_true(
    failures.any(message => {
      message == "showcaseTarget must be 'examples/showcase/web_wasm'"
    }),
  )
  assert_true(
    failures.any(message => {
      message == "url must point at /examples/showcase/web_wasm/"
    }),
  )
  assert_true(
    failures.any(message => {
      message == "renderInspectorCounters must include 'unbalanced_pop_count'"
    }),
  )
  assert_true(
    failures.any(message => {
      message == "screenshotArtifacts must include 'mobile'"
    }),
  )
  assert_true(
    failures.any(message => {
      message == "benchmarkMetrics must include 'render_inspector_counters'"
    }),
  )
  assert_true(
    failures.any(message => {
      message == "notes must include at least one handoff note"
    }),
  )
}

///|
test "manifest text rejects invalid JSON and non-object roots" {
  assert_eq(validate_manifest_text("{", ""), [
    "failed to read JSON: invalid JSON",
  ])
  assert_eq(validate_manifest_text("[]", ""), [
    "manifest root must be an object",
  ])
}

///|
test "parse_cli requires the manifest path and validates mode" {
  match parse_cli(["manifest.json"]) {
    Ok(options) => {
      assert_eq(options.manifest_path, "manifest.json")
      assert_eq(options.expected_mode, "")
      assert_false(options.help)
    }
    Err(message) => fail(message)
  }
  match parse_cli(["manifest.json", "--mode", "benchmark"]) {
    Ok(options) => assert_eq(options.expected_mode, "benchmark")
    Err(message) => fail(message)
  }
  match parse_cli([]) {
    Err(message) => assert_eq(message, "missing manifest.json path")
    Ok(_) => fail("missing manifest path must be rejected")
  }
  match parse_cli(["manifest.json", "--mode"]) {
    Err(message) => assert_eq(message, "missing value for --mode")
    Ok(_) => fail("missing --mode value must be rejected")
  }
}
