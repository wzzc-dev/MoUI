///|
/// White-box tests for the capture-scaffold decision rules in
/// `conformance_capture_scaffold`: CLI mode selection, output defaults, path
/// normalization, and the golden/benchmark manifest shape difference.

///|
test "default_output maps each capture mode to its artifact path" {
  assert_eq(
    default_output("golden"),
    "artifacts/conformance/showcase-golden-capture.json",
  )
  assert_eq(
    default_output("benchmark"),
    "artifacts/conformance/showcase-benchmark-capture.json",
  )
  // Unknown modes fall through to the benchmark scaffold path.
  assert_eq(
    default_output("other"),
    "artifacts/conformance/showcase-benchmark-capture.json",
  )
}

///|
test "parent_dir normalizes separators and handles roots" {
  assert_eq(parent_dir("artifacts/conformance/x.json"), "artifacts/conformance")
  assert_eq(parent_dir("x.json"), ".")
  assert_eq(parent_dir("/x.json"), "/")
  // A Windows-style separator is normalized for a single directory level.
  // Known limitation (reported, not locked in): `String::replace` rewrites only
  // the first match, so deeper Windows paths are not fully normalized.
  assert_eq(parent_dir("artifacts\\capture.json"), "artifacts")
}

///|
test "parse_cli defaults the output and rejects bad invocations" {
  match parse_cli(["--mode", "golden"]) {
    Ok((mode, output)) => {
      assert_eq(mode, "golden")
      assert_eq(output, "artifacts/conformance/showcase-golden-capture.json")
    }
    Err(message) => fail(message)
  }
  match parse_cli(["--mode", "benchmark", "--output", "out/capture.json"]) {
    Ok((mode, output)) => {
      assert_eq(mode, "benchmark")
      assert_eq(output, "out/capture.json")
    }
    Err(message) => fail(message)
  }
  match parse_cli(["--mode", "other"]) {
    Ok(_) => fail("unknown mode must be rejected")
    Err(message) => assert_eq(message, "mode must be golden or benchmark")
  }
  match parse_cli(["--mode"]) {
    Ok(_) => fail("missing value must be rejected")
    Err(message) => assert_eq(message, "missing value for --mode")
  }
  match parse_cli(["--wat"]) {
    Ok(_) => fail("unknown flag must be rejected")
    Err(message) => assert_eq(message, "Unknown argument: --wat")
  }
}

///|
test "only the benchmark manifest carries benchmarkTargets" {
  let golden = build_manifest("golden")
  match golden {
    Json::Object(fields) => {
      assert_true(fields.get("benchmarkTargets") is None)
      match fields.get("mode") {
        Some(Json::String(mode)) => assert_eq(mode, "golden")
        _ => fail("golden manifest must record its mode")
      }
      match fields.get("schemaVersion") {
        Some(Json::Number(version, repr=_)) => assert_eq(version, 1.0)
        _ => fail("scaffold manifest must record schemaVersion 1")
      }
    }
    _ => fail("golden manifest must be an object")
  }
  match build_manifest("benchmark") {
    Json::Object(fields) =>
      match fields.get("benchmarkTargets") {
        Some(Json::Array(targets)) => {
          assert_eq(targets.length(), 1)
          match targets[0] {
            Json::Object(target) =>
              match target.get("metricsPath") {
                Some(Json::String(path)) =>
                  assert_eq(path, "artifacts/benchmarks/showcase-web-wasm.json")
                _ => fail("benchmark target must declare a metrics path")
              }
            _ => fail("benchmark target must be an object")
          }
        }
        _ => fail("benchmark manifest must declare benchmarkTargets")
      }
    _ => fail("benchmark manifest must be an object")
  }
}
