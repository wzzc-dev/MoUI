// Whitebox tests for `verify.mbt`.
//
// Tests focus on `parse_verify_args` (pure), `verify_manifest_to_json`
// (pure), `is_accepted_generated_by` (pure), and `verify_status_from_probe`
// (pure). Real probe / manifest writes are exercised by integration tests
// with hardware attached.

///|
test "test_parse_verify_args_basic" {
  let parsed = parse_verify_args(
    ["android", "showcase"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      assert_false(value.help)
      assert_false(value.json)
      inspect(value.platform, content="android")
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      assert_false(options.require_passed)
    }
    Err(message) => fail("parse_verify_args failed: " + message)
  }
}

///|
test "test_parse_verify_args_options" {
  let parsed = parse_verify_args(
    [
      "ios", "demo", "--device", "UUID-DEAD", "--build-dir", "/tmp/build", "--output",
      "/tmp/manifest.json", "--require-passed", "--json",
    ],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      assert_true(value.json)
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      debug_inspect(options.device, content="Some(\"UUID-DEAD\")")
      debug_inspect(options.build_dir, content="Some(\"/tmp/build\")")
      debug_inspect(options.output_path, content="Some(\"/tmp/manifest.json\")")
      assert_true(options.require_passed)
    }
    Err(message) => fail("parse_verify_args failed: " + message)
  }
}

///|
test "test_parse_verify_args_help_flag" {
  let parsed = parse_verify_args(["--help"], "/tmp", detect_host_platform())
  match parsed {
    Ok(value) => {
      assert_true(value.help)
      assert_true(value.options is None)
    }
    Err(message) => fail("parse_verify_args failed: " + message)
  }
}

///|
test "test_parse_verify_args_rejects_missing_positional" {
  let parsed = parse_verify_args(["android"], "/tmp", detect_host_platform())
  match parsed {
    Ok(_) => fail("expected parse error for missing app")
    Err(message) => assert_true(message.contains("usage"))
  }
}

///|
test "test_parse_verify_args_rejects_unknown_platform" {
  let parsed = parse_verify_args(
    ["web", "demo"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(_) => fail("expected parse error for unknown platform")
    Err(message) => assert_true(message.contains("unsupported platform"))
  }
}

///|
test "test_parse_verify_args_rejects_unknown_option" {
  let parsed = parse_verify_args(
    ["android", "demo", "--bogus"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(_) => fail("expected parse error for unknown option")
    Err(message) => assert_true(message.contains("unknown option"))
  }
}

///|
test "test_is_accepted_generated_by_recognizes_canonical" {
  assert_true(is_accepted_generated_by("moui_cli"))
}

///|
test "test_is_accepted_generated_by_rejects_unknown" {
  assert_false(is_accepted_generated_by("unknown-tool"))
  assert_false(is_accepted_generated_by(""))
}

///|
test "test_verify_status_from_probe_passed" {
  let probe : ProbeResult = { ok: true, observations: [] }
  inspect(verify_status_from_probe(probe), content="passed")
}

///|
test "test_verify_status_from_probe_failed" {
  let probe : ProbeResult = {
    ok: false,
    observations: [
      { kind: "stability", name: "crash_free", value: "fail", passed: false },
    ],
  }
  inspect(verify_status_from_probe(probe), content="failed")
}

///|
test "test_verify_manifest_to_json_emits_schema_and_generated_by" {
  let probe : ProbeResult = {
    ok: false,
    observations: [
      { kind: "lifecycle", name: "app_start", value: "ok", passed: true },
      { kind: "stability", name: "crash_free", value: "fail", passed: false },
    ],
  }
  let json = verify_manifest_to_json(
    "android", "demo", "/tmp/demo.apk", "failed", probe,
  )
  let text = json.stringify(indent=2)
  assert_true(text.contains("\"schemaVersion\": 1"))
  assert_true(text.contains("\"mode\": \"window-hosted-runtime-verify\""))
  assert_true(text.contains("\"generatedBy\": \"moui_cli\""))
  assert_true(text.contains("\"platform\": \"android\""))
  assert_true(text.contains("\"app\": \"demo\""))
  assert_true(text.contains("\"status\": \"failed\""))
  assert_true(text.contains("\"artifact\": \"/tmp/demo.apk\""))
  assert_true(text.contains("\"evidenceBoundary\""))
  // Observations are nested under "observations" array.
  assert_true(text.contains("\"app_start\""))
  assert_true(text.contains("\"crash_free\""))
  assert_true(text.contains("\"passed\": true"))
  assert_true(text.contains("\"passed\": false"))
}

///|
test "test_verify_manifest_to_json_emits_passed_when_ok" {
  let probe : ProbeResult = { ok: true, observations: [] }
  let json = verify_manifest_to_json(
    "ios", "demo", "/tmp/demo.app", "passed", probe,
  )
  let text = json.stringify(indent=2)
  assert_true(text.contains("\"status\": \"passed\""))
}

///|
test "test_find_verify_artifact_returns_platform_suffix" {
  inspect(
    find_verify_artifact("android", "/tmp/build", "demo"),
    content="/tmp/build/demo.apk",
  )
  inspect(
    find_verify_artifact("ios", "/tmp/build", "demo"),
    content="/tmp/build/demo.app",
  )
  inspect(
    find_verify_artifact("harmonyos", "/tmp/build", "demo"),
    content="/tmp/build/demo.hap",
  )
  inspect(find_verify_artifact("unknown", "/tmp", "demo"), content="")
}

///|
test "test_verify_usage_mentions_platforms" {
  let text = verify_usage()
  assert_true(text.contains("android"))
  assert_true(text.contains("ios"))
  assert_true(text.contains("harmonyos"))
  assert_true(text.contains("--require-passed"))
  assert_true(text.contains("--device"))
}

///|
test "test_parent_dir_extracts_directory" {
  // `parent_dir` is defined in path_fs.mbt and returns "." for bare names.
  inspect(parent_dir("/tmp/build/manifest.json"), content="/tmp/build")
  inspect(parent_dir("relative/path/file.json"), content="relative/path")
  inspect(parent_dir("bare.json"), content=".")
}

///|
test "test_resolve_verify_device_uses_supplied_id" {
  let options : VerifyOptions = {
    device: Some("emulator-5554"),
    build_dir: None,
    output_path: None,
    require_passed: false,
  }
  match resolve_verify_device(options, "android", detect_host_platform()) {
    Ok(device) => {
      inspect(device.id, content="emulator-5554")
      inspect(device.platform, content="android")
    }
    Err(message) => fail("expected device, got: " + message)
  }
}
