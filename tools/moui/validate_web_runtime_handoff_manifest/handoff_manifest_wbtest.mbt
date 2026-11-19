// White-box tests for the Web runtime handoff manifest validator: CLI, pinned
// target/export tables, check-path safety, and manifest shape errors.

///|
fn parsed_cli(args : Array[String]) -> CliOptions {
  match parse_cli(args) {
    Ok(options) => options
    Err(_) =>
      { manifest_path: "<error>", display_path: "<error>", help: false, }
  }
}

///|
test "expected target and export pins match the handoff contract" {
  assert_eq(expected_target_names(), "showcase-web-wasm")
  match expected_target("showcase-web-wasm") {
    Some(target) => {
      assert_eq(target.package_path, "examples/showcase/web_wasm")
      assert_eq(target.html_path, "examples/showcase/web_wasm/index.html")
      assert_true(target.wasm_path.has_suffix("web_wasm.wasm"))
    }
    None => assert_true(false)
  }
  assert_true(expected_target("missing") is None)
  let exports = required_exports()
  assert_eq(exports.length(), 3)
  assert_true(exports.contains("web_dispatch_event"))
  assert_true(exports.contains("web_complete_async_file_dialog"))
}

///|
test "check paths and local HTTP URLs are restricted" {
  assert_true(allowed_file_check_path("moui_web_renderer/runtime.js"))
  assert_true(allowed_file_check_path("moui/backend/web/browser_runtime.js"))
  assert_true(
    allowed_file_check_path(
      "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
    ),
  )
  assert_true(!allowed_file_check_path("moui/backend/web/other.js"))
  assert_true(local_http_url("http://127.0.0.1:8080/runtime.js"))
  assert_true(local_http_url("http://localhost:3000/"))
  assert_true(!local_http_url("https://example.com/runtime.js"))
  assert_true(!local_http_url("http://192.168.0.1/runtime.js"))
}

///|
test "parse_cli requires the manifest path and resolves display paths" {
  let plain = parsed_cli(["artifacts/web-runtime-handoff.json"])
  assert_eq(plain.manifest_path, "artifacts/web-runtime-handoff.json")
  assert_eq(plain.display_path, "artifacts/web-runtime-handoff.json")
  assert_true(!plain.help)
  let displayed = parsed_cli(["a.json", "--display-path", "shown.json"])
  assert_eq(displayed.display_path, "shown.json")
  let help = parsed_cli(["--help"])
  assert_true(help.help)
  assert_eq(help.manifest_path, "")
  match parse_cli([]) {
    Err(message) => assert_eq(message, "missing web-runtime-handoff.json path")
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
}

///|
test "validate_manifest_text rejects non-JSON, non-object, and incomplete input" {
  let invalid = validate_manifest_text("{")
  assert_eq(invalid.length(), 1)
  assert_eq(invalid[0], "failed to read JSON: invalid JSON")
  assert_eq(validate_manifest_text("[]")[0], "manifest root must be an object")
  let empty = validate_manifest_text("{}")
  assert_true(empty.contains("schemaVersion must be 1"))
  assert_true(empty.contains("mode must be 'web-runtime-handoff'"))
  assert_true(
    empty.contains("checks must include at least one file or http check"),
  )
  assert_true(empty.contains("targets must include 'showcase-web-wasm'"))
}
