// White-box tests for the Web runtime handoff gate: positive-int parsing,
// path normalization, CLI checks, and expected asset tables.

///|
fn parsed_cli(args : Array[String]) -> CliOptions {
  match parse_cli(args) {
    Ok(options) => options
    Err(_) =>
      {
        root: "<error>",
        display_root: "<error>",
        base_url: "<error>",
        manifest_path: "<error>",
        http_checks: [],
        help: false,
      }
  }
}

///|
test "parse_positive_int accepts only trimmed positive decimal numbers" {
  match parse_positive_int(" 42 ") {
    Some(value) => assert_eq(value, 42)
    None => assert_true(false)
  }
  match parse_positive_int("1024") {
    Some(value) => assert_eq(value, 1024)
    None => assert_true(false)
  }
  assert_true(parse_positive_int("") is None)
  assert_true(parse_positive_int("0") is None)
  assert_true(parse_positive_int("-1") is None)
  assert_true(parse_positive_int("12a") is None)
  assert_true(parse_positive_int("3.5") is None)
}

///|
test "parent_dir normalizes separators and handles roots" {
  assert_eq(parent_dir("a/b/c.wasm"), "a/b")
  assert_eq(parent_dir("c.wasm"), "")
  assert_eq(parent_dir("/root/c.wasm"), "/root")
  // Only the first separator is normalized, so a Windows-style path reports
  // its first segment as parent; repo-relative callers pass `/` paths.
  assert_eq(parent_dir("a\\b\\c.wasm"), "a")
  assert_eq(parent_dir("single/dir/file"), "single/dir")
}

///|
test "expected runtime exports and handoff targets stay pinned" {
  let exports = required_wasm_exports()
  assert_eq(exports.length(), 3)
  assert_true(exports.contains("web_dispatch_event"))
  assert_true(exports.contains("web_complete_async_clipboard_read"))
  let targets = handoff_targets()
  assert_eq(targets.length(), 1)
  assert_eq(targets[0].name, "showcase-web-wasm")
  assert_eq(targets[0].package_path, "examples/showcase/web_wasm")
  assert_true(targets[0].wasm_path.has_suffix("web_wasm.wasm"))
}

///|
test "parse_cli records root, URLs, manifest, and http checks" {
  let defaults = parsed_cli([])
  assert_true(defaults.root != "")
  assert_eq(defaults.display_root, "")
  assert_eq(defaults.base_url, "")
  assert_eq(defaults.manifest_path, "")
  assert_eq(defaults.http_checks.length(), 0)
  assert_true(!defaults.help)
  let full = parsed_cli([
    "--root", "/repo", "--display-root", "repo", "--base-url", "http://127.0.0.1:8080",
    "--manifest", "artifacts/handoff.json", "--http-check", "runtime", "moui_web_renderer/runtime.js",
    "http://127.0.0.1:8080/runtime.js", "120",
  ])
  assert_eq(full.root, "/repo")
  assert_eq(full.display_root, "repo")
  assert_eq(full.base_url, "http://127.0.0.1:8080")
  assert_eq(full.manifest_path, "artifacts/handoff.json")
  assert_eq(full.http_checks.length(), 1)
  assert_eq(full.http_checks[0].kind, "http")
  assert_eq(full.http_checks[0].label, "runtime")
  assert_eq(full.http_checks[0].bytes, 120)
  let help = parsed_cli(["--help"])
  assert_true(help.help)
  match parse_cli(["--root"]) {
    Err(message) => assert_eq(message, "missing value for --root")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--http-check", "a", "b", "c", "many"]) {
    Err(message) => assert_eq(message, "invalid byte count for --http-check")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--http-check", "a", "b"]) {
    Err(message) => assert_eq(message, "missing values for --http-check")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "unknown argument: --wat")
    Ok(_) => assert_true(false)
  }
}
