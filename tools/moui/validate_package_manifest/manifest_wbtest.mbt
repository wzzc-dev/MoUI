// White-box tests for the package manifest gate: CLI parsing, ASCII lowering,
// per-platform field rules, and JSON-shape errors.

///|
fn macos_manifest_text() -> String {
  (
    #|{
    #|  "schemaVersion": 1,
    #|  "platform": "macos",
    #|  "outputKind": "app-bundle",
    #|  "appName": "Showcase",
    #|  "moonPackage": "examples/showcase/app",
    #|  "version": "1.2.3",
    #|  "buildNumber": "42",
    #|  "executable": "showcase",
    #|  "bundleName": "Showcase.app",
    #|  "bundleIdentifier": "com.example.showcase",
    #|  "runtimeFiles": []
    #|}
  )
}

///|
fn windows_manifest_text() -> String {
  (
    #|{
    #|  "schemaVersion": 1,
    #|  "platform": "windows",
    #|  "outputKind": "portable-folder",
    #|  "appName": "Showcase",
    #|  "moonPackage": "examples/showcase/app",
    #|  "version": "1.2.3",
    #|  "buildNumber": "42",
    #|  "executable": "showcase.EXE",
    #|  "bundleName": "Showcase",
    #|  "runtimeFiles": ["showcase.dll"]
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
        expected_platform: "<error>",
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
/// Extracts the `(platform, outputKind)` pair, or an error marker for failures
/// so tests can assert either shape without `Eq` on the result type.
fn manifest_outcome(result : Result[(String, String), Array[String]]) -> String {
  match result {
    Ok(pair) => pair.0 + "/" + pair.1
    Err(_) => "<error>"
  }
}

///|
/// Renders the first failure, or `<ok>`, to keep assertions precise.
fn manifest_error(text : String, platform : String) -> String {
  match validate_manifest_text(text, platform) {
    Err(failures) => if failures.is_empty() { "<empty>" } else { failures[0] }
    Ok(_) => "<ok>"
  }
}

///|
test "ascii_lower only folds ASCII letters" {
  assert_eq(ascii_lower("ShowCase.EXE"), "showcase.exe")
  assert_eq(ascii_lower("ABC-123.macos"), "abc-123.macos")
  assert_eq(ascii_lower(""), "")
}

///|
test "parse_cli resolves path, platform, and display path" {
  let plain = parsed_cli(["moui-package.json"])
  assert_eq(plain.manifest_path, "moui-package.json")
  assert_eq(plain.display_path, "moui-package.json")
  assert_eq(plain.expected_platform, "")
  let full = parsed_cli([
    "m.json", "--platform", "windows", "--display-path", "shown.json",
  ])
  assert_eq(full.expected_platform, "windows")
  assert_eq(full.display_path, "shown.json")
  assert_true(!full.help)
  let help = parsed_cli(["--help"])
  assert_true(help.help)
  assert_eq(help.manifest_path, "")
  assert_eq(cli_error([]), "missing moui-package.json path")
  assert_eq(cli_error(["--platform"]), "missing value for --platform")
  assert_eq(cli_error(["--display-path"]), "missing value for --display-path")
  assert_eq(cli_error(["a.json", "b.json"]), "unexpected argument: b.json")
  assert_eq(cli_error(["--wat"]), "Unknown argument: --wat")
}

///|
test "valid macOS and Windows manifests validate per platform" {
  assert_eq(
    manifest_outcome(validate_manifest_text(macos_manifest_text(), "")),
    "macos/app-bundle",
  )
  assert_eq(
    manifest_outcome(validate_manifest_text(windows_manifest_text(), "")),
    "windows/portable-folder",
  )
  // A mismatched expected platform is rejected before path resolution.
  assert_eq(
    manifest_error(macos_manifest_text(), "windows"),
    "platform must be 'windows'",
  )
  // Windows accepts a case-insensitive .exe suffix.
  let upper = windows_manifest_text()
  assert_eq(
    manifest_outcome(validate_manifest_text(upper, "windows")),
    "windows/portable-folder",
  )
}

///|
test "platform field rules and JSON shapes reject invalid manifests" {
  // macOS requires an app bundle and a .app suffix.
  let wrong_output_kind = macos_manifest_text().replace(
    old="\"app-bundle\"",
    new="\"portable-folder\"",
  )
  assert_eq(
    manifest_error(wrong_output_kind, ""),
    "macOS outputKind must be 'app-bundle'",
  )
  let wrong_bundle = macos_manifest_text().replace(
    old="\"Showcase.app\"",
    new="\"Showcase\"",
  )
  assert_eq(
    manifest_error(wrong_bundle, ""),
    "macOS bundleName must end with .app",
  )
  // Windows requires .exe.
  let no_exe = windows_manifest_text().replace(
    old="\"showcase.EXE\"",
    new="\"showcase\"",
  )
  assert_eq(manifest_error(no_exe, ""), "Windows executable must end with .exe")
  // Unsupported platform and non-array runtime files.
  let linux_platform = macos_manifest_text().replace(
    old="\"macos\"",
    new="\"plan9\"",
  )
  assert_eq(
    manifest_error(linux_platform, ""),
    "platform must be 'macos', 'windows', or 'linux'",
  )
  let bad_runtime = macos_manifest_text().replace(
    old="\"runtimeFiles\": []",
    new="\"runtimeFiles\": {}",
  )
  assert_eq(manifest_error(bad_runtime, ""), "runtimeFiles must be an array")
  assert_eq(manifest_error("{", ""), "failed to read JSON: invalid JSON")
  assert_eq(manifest_error("[]", ""), "manifest root must be an object")
  assert_eq(manifest_error("{}", ""), "schemaVersion must be 1")
}
