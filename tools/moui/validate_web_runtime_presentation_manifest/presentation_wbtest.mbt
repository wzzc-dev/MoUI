// White-box tests for the Web runtime presentation manifest validator: CLI,
// pinned targets/observation keys, local URL rules, and shape errors.

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
test "presentation target and observation keys stay pinned" {
  assert_eq(expected_target_names(), "showcase-web-wasm")
  match expected_target("showcase-web-wasm") {
    Some(target) => {
      assert_eq(target.package_path, "examples/showcase/web_wasm")
      assert_eq(target.path, "examples/showcase/web_wasm/index.html")
    }
    None => assert_true(false)
  }
  assert_true(expected_target("missing") is None)
  let keys = observation_keys()
  assert_eq(keys.length(), 27)
  assert_true(keys.contains("pageLoaded"))
  assert_true(keys.contains("targetClosed"))
  let smoke_keys = renderer_smoke_keys()
  assert_eq(smoke_keys.length(), 10)
  assert_true(smoke_keys.contains("radialGradient"))
  assert_true(!smoke_keys.contains("pageLoaded"))
}

///|
test "renderer smoke markers and scoping rules per target" {
  assert_eq(renderer_smoke_marker_requirements("bidiLayout"), ["visual-order"])
  assert_eq(renderer_smoke_marker_requirements("asyncImageSecondFrame"), [
    "late-completion", "repaint-request", "second-frame-pixels",
  ])
  assert_eq(renderer_smoke_marker_requirements("pageLoaded"), [])
  assert_true(renderer_smoke_observation_key("colorEmojiPixels"))
  assert_true(!renderer_smoke_observation_key("pageLoaded"))
  // Renderer-only and transform observations are waived for other targets.
  assert_true(
    !observation_required_for_passed_target("transformPixels", "other-web"),
  )
  assert_true(
    !observation_required_for_passed_target("radialGradient", "other-web"),
  )
  assert_true(
    observation_required_for_passed_target(
      "radialGradient", "showcase-web-wasm",
    ),
  )
  assert_true(
    observation_required_for_passed_target(
      "transformPixels", "showcase-web-wasm",
    ),
  )
  assert_true(observation_required_for_passed_target("pageLoaded", "other-web"))
}

///|
test "local_http_url requires a localhost host and numeric port" {
  assert_true(local_http_url("http://127.0.0.1:9222/json"))
  assert_true(local_http_url("http://localhost:3000/"))
  assert_true(!local_http_url("http://127.0.0.1:/json"))
  assert_true(!local_http_url("http://127.0.0.1:abc/json"))
  assert_true(!local_http_url("https://127.0.0.1:9222/json"))
  assert_true(!local_http_url("http://example.com:9222/json"))
}

///|
test "json_yes_no_value only accepts explicit yes and no" {
  let object : Map[String, Json] = Map([
    ("yes_field", Json::string("yes")),
    ("no_field", Json::string("no")),
    ("other_field", Json::string("maybe")),
  ])
  assert_eq(json_yes_no_value(object, "yes_field"), "yes")
  assert_eq(json_yes_no_value(object, "no_field"), "no")
  assert_eq(json_yes_no_value(object, "other_field"), "")
  assert_eq(json_yes_no_value(object, "missing_field"), "")
}

///|
test "parse_cli and manifest shape errors guard the gate" {
  let plain = parsed_cli(["artifacts/presentation.json"])
  assert_eq(plain.manifest_path, "artifacts/presentation.json")
  assert_eq(plain.display_path, "artifacts/presentation.json")
  assert_true(!plain.require_passed)
  let full = parsed_cli([
    "a.json", "--display-path", "shown.json", "--require-passed",
  ])
  assert_eq(full.display_path, "shown.json")
  assert_true(full.require_passed)
  let help = parsed_cli(["--help"])
  assert_true(help.help)
  match parse_cli([]) {
    Err(message) =>
      assert_eq(message, "missing presentation smoke manifest path")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--display-path"]) {
    Err(message) => assert_eq(message, "missing value for --display-path")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["a.json", "b.json"]) {
    Err(message) => assert_eq(message, "unexpected argument: b.json")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "Unknown argument: --wat")
    Ok(_) => assert_true(false)
  }
  let invalid = validate_manifest_text("{")
  assert_eq(invalid[0], "failed to read JSON: invalid JSON")
  assert_eq(validate_manifest_text("[]")[0], "manifest root must be an object")
  let empty = validate_manifest_text("{}")
  assert_true(empty.contains("schemaVersion must be 1"))
  assert_true(empty.contains("mode must be 'web-runtime-presentation'"))
  assert_true(empty.contains("targets must include 'showcase-web-wasm'"))
  assert_true(
    validate_manifest_text_with_options("{}", true).contains(
      "overallStatus must be passed when --require-passed is used",
    ),
  )
}
