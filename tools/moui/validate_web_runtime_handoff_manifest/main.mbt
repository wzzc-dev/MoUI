///|
struct CliOptions {
  manifest_path : String
  display_path : String
  help : Bool
}

///|
struct ExpectedTarget {
  name : String
  package_path : String
  html_path : String
  wasm_path : String
}

///|
fn usage() -> String {
  "Usage: tools/moui/validate_web_runtime_handoff_manifest <web-runtime-handoff.json>"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let manifest_path = Ref("")
  let display_path = Ref("")
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--display-path" => {
        if index + 1 >= args.length() {
          return Err("missing value for --display-path")
        }
        display_path.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if value.has_prefix("-") {
          return Err("Unknown argument: " + value)
        }
        if manifest_path.val != "" {
          return Err("unexpected argument: " + value)
        }
        manifest_path.val = value
        index += 1
      }
    }
  }
  if !help.val && manifest_path.val == "" {
    return Err("missing web-runtime-handoff.json path")
  }
  let display = if display_path.val == "" {
    manifest_path.val
  } else {
    display_path.val
  }
  Ok({ manifest_path: manifest_path.val, display_path: display, help: help.val })
}

///|
fn required_exports() -> Array[String] {
  [
    "web_dispatch_event", "web_complete_async_clipboard_read", "web_complete_async_file_dialog",
  ]
}

///|
fn expected_targets() -> Array[ExpectedTarget] {
  [
    {
      name: "showcase-web-wasm",
      package_path: "examples/showcase/web_wasm",
      html_path: "examples/showcase/web_wasm/index.html",
      wasm_path: "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
    },
    {
      name: "markdown-editor-web-wasm",
      package_path: "examples/markdown_editor/web_wasm",
      html_path: "examples/markdown_editor/web_wasm/index.html",
      wasm_path: "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
    },
  ]
}

///|
fn expected_target(name : String) -> ExpectedTarget? {
  for target in expected_targets() {
    if target.name == name {
      return Some(target)
    }
  }
  None
}

///|
fn expected_target_names() -> String {
  let names : Array[String] = []
  for target in expected_targets() {
    names.push(target.name)
  }
  @tools.comma_join(names)
}

///|
fn json_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn json_object_value(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn require_string(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> String {
  match object.get(field) {
    Some(Json::String(value)) if value.trim().to_owned() != "" => value
    _ => {
      failures.push("missing non-empty string field '" + label + "'")
      ""
    }
  }
}

///|
fn require_number(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Double {
  match object.get(field) {
    Some(Json::Number(number, repr=_)) => number
    _ => {
      failures.push("missing finite number field '" + label + "'")
      0.0
    }
  }
}

///|
fn require_array(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Array[Json] {
  match object.get(field) {
    Some(Json::Array(values)) => values
    _ => {
      failures.push("field '" + label + "' must be an array")
      []
    }
  }
}

///|
fn assert_string_array(
  values : Array[Json],
  label : String,
  failures : Array[String],
) -> Unit {
  for index in 0..<values.length() {
    match values[index] {
      Json::String(value) if value.trim().to_owned() != "" => ()
      _ => failures.push(label + "[\{index}] must be a non-empty string")
    }
  }
}

///|
fn json_string_array_contains(values : Array[Json], expected : String) -> Bool {
  values.any(value => {
    match value {
      Json::String(text) => text == expected
      _ => false
    }
  })
}

///|
fn assert_includes_all(
  values : Array[Json],
  expected : Array[String],
  label : String,
  failures : Array[String],
) -> Unit {
  for value in expected {
    if !json_string_array_contains(values, value) {
      failures.push(label + " must include '" + value + "'")
    }
  }
}

///|
fn validate_target(
  target_json : Json,
  index : Int,
  seen : Map[String, Bool],
) -> Array[String] {
  let failures : Array[String] = []
  let target = match json_object_value(target_json) {
    Some(fields) => fields
    None => {
      failures.push("targets[\{index}] must be an object")
      return failures
    }
  }
  let label = "targets[\{index}]"
  let name = require_string(target, "name", label + ".name", failures)
  if seen.contains(name) {
    failures.push("duplicate target '" + name + "'")
  }
  seen[name] = true
  let expected = match expected_target(name) {
    Some(value) => value
    None => {
      failures.push(label + ".name must be one of " + expected_target_names())
      return failures
    }
  }
  validate_target_expected_field(
    target,
    "packagePath",
    expected.package_path,
    name,
    label,
    failures,
  )
  validate_target_expected_field(
    target,
    "htmlPath",
    expected.html_path,
    name,
    label,
    failures,
  )
  validate_target_expected_field(
    target,
    "wasmPath",
    expected.wasm_path,
    name,
    label,
    failures,
  )
  let required_wasm_exports = require_array(
    target,
    "requiredWasmExports",
    label + ".requiredWasmExports",
    failures,
  )
  let compiled_wasm_exports = require_array(
    target,
    "compiledWasmExports",
    label + ".compiledWasmExports",
    failures,
  )
  assert_string_array(
    required_wasm_exports,
    label + ".requiredWasmExports",
    failures,
  )
  assert_string_array(
    compiled_wasm_exports,
    label + ".compiledWasmExports",
    failures,
  )
  assert_includes_all(
    required_wasm_exports,
    required_exports(),
    label + ".requiredWasmExports",
    failures,
  )
  assert_includes_all(
    compiled_wasm_exports,
    required_exports(),
    label + ".compiledWasmExports",
    failures,
  )
  if require_string(
      target,
      "htmlRuntimeImport",
      label + ".htmlRuntimeImport",
      failures,
    ) !=
    "../../../moui_web_renderer/runtime.js" {
    failures.push(
      label +
      ".htmlRuntimeImport must be '../../../moui_web_renderer/runtime.js'",
    )
  }
  if require_string(
      target,
      "canvasHostSelector",
      label + ".canvasHostSelector",
      failures,
    ) !=
    "#canvas-host" {
    failures.push(label + ".canvasHostSelector must be '#canvas-host'")
  }
  let wasm_bytes = require_number(
    target,
    "wasmBytes",
    label + ".wasmBytes",
    failures,
  )
  if wasm_bytes < 1024.0 {
    failures.push(label + ".wasmBytes must be at least 1024")
  }
  failures
}

///|
fn validate_target_expected_field(
  target : Map[String, Json],
  field : String,
  expected_value : String,
  name : String,
  label : String,
  failures : Array[String],
) -> Unit {
  let value = require_string(target, field, label + "." + field, failures)
  if value != expected_value {
    failures.push(
      label +
      "." +
      field +
      " must be '" +
      expected_value +
      "' for '" +
      name +
      "'",
    )
  }
}

///|
fn allowed_file_check_path(path : String) -> Bool {
  if path == "moui_web_renderer/runtime.js" ||
    path == "moui/backend/web/browser_runtime.js" {
    return true
  }
  for target in expected_targets() {
    if path == target.wasm_path {
      return true
    }
  }
  false
}

///|
fn local_http_url(url : String) -> Bool {
  url.has_prefix("http://127.0.0.1:") || url.has_prefix("http://localhost:")
}

///|
fn validate_check(check_json : Json, index : Int) -> Array[String] {
  let failures : Array[String] = []
  let check = match json_object_value(check_json) {
    Some(fields) => fields
    None => {
      failures.push("checks[\{index}] must be an object")
      return failures
    }
  }
  let label = "checks[\{index}]"
  let kind = require_string(check, "kind", label + ".kind", failures)
  if kind != "file" && kind != "http" {
    failures.push(label + ".kind must be file or http")
  }
  let path = require_string(check, "path", label + ".path", failures)
  let bytes = require_number(check, "bytes", label + ".bytes", failures)
  if bytes <= 0.0 {
    failures.push(label + ".bytes must be positive")
  }
  if kind == "file" && !allowed_file_check_path(path) {
    failures.push(label + ".path is not an expected file check path")
  }
  if kind == "http" {
    ignore(require_string(check, "label", label + ".label", failures))
    let url = require_string(check, "url", label + ".url", failures)
    if !local_http_url(url) {
      failures.push(label + ".url must be a local HTTP URL")
    }
  }
  failures
}

///|
fn json_number_is_one(value : Json?) -> Bool {
  match value {
    Some(Json::Number(number, repr=_)) => number == 1.0
    _ => false
  }
}

///|
fn validate_manifest_fields(manifest : Map[String, Json]) -> Array[String] {
  let failures : Array[String] = []
  if !json_number_is_one(manifest.get("schemaVersion")) {
    failures.push("schemaVersion must be 1")
  }
  let mode = require_string(manifest, "mode", "mode", failures)
  if mode != "web-runtime-handoff" {
    failures.push("mode must be 'web-runtime-handoff'")
  }
  let generated_by = require_string(
    manifest, "generatedBy", "generatedBy", failures,
  )
  if generated_by != "scripts/validate-web-runtime-handoff.mjs" {
    failures.push(
      "generatedBy must be scripts/validate-web-runtime-handoff.mjs",
    )
  }
  ignore(require_string(manifest, "root", "root", failures))
  match manifest.get("baseUrl") {
    Some(Json::String(_)) => ()
    _ => failures.push("baseUrl must be a string")
  }
  let observation_boundary = require_string(
    manifest, "observationBoundary", "observationBoundary", failures,
  )
  if !observation_boundary.contains("not browser WebGPU device") ||
    !observation_boundary.contains("wasm instantiation") ||
    !observation_boundary.contains("pixel observations") {
    failures.push(
      "observationBoundary must explicitly exclude browser WebGPU device, wasm instantiation, and pixel observations",
    )
  }
  let runtime_assets = require_array(
    manifest, "runtimeAssets", "runtimeAssets", failures,
  )
  assert_string_array(runtime_assets, "runtimeAssets", failures)
  assert_includes_all(
    runtime_assets,
    ["moui_web_renderer/runtime.js", "moui/backend/web/browser_runtime.js"],
    "runtimeAssets",
    failures,
  )
  let targets = require_array(manifest, "targets", "targets", failures)
  let seen_targets : Map[String, Bool] = Map([])
  for index in 0..<targets.length() {
    for failure in validate_target(targets[index], index, seen_targets) {
      failures.push(failure)
    }
  }
  for target in expected_targets() {
    if !seen_targets.contains(target.name) {
      failures.push("targets must include '" + target.name + "'")
    }
  }
  let checks = require_array(manifest, "checks", "checks", failures)
  if checks.is_empty() {
    failures.push("checks must include at least one file or http check")
  }
  for index in 0..<checks.length() {
    for failure in validate_check(checks[index], index) {
      failures.push(failure)
    }
  }
  failures
}

///|
fn validate_manifest_text(text : String) -> Array[String] {
  let parsed = @json.parse(text) catch {
    _ => return ["failed to read JSON: invalid JSON"]
  }
  let manifest = match json_object(Some(parsed)) {
    Some(fields) => fields
    None => return ["manifest root must be an object"]
  }
  validate_manifest_fields(manifest)
}

///|
fn validate_web_runtime_handoff_manifest(
  options : CliOptions,
) -> Result[String, Array[String]] {
  let text = match
    @tools.read_required_text(
      options.manifest_path,
      "web runtime handoff manifest",
    ) {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let failures = validate_manifest_text(text)
  if failures.is_empty() {
    Ok(options.display_path + ": ok (web runtime handoff manifest)")
  } else {
    Err(failures)
  }
}

///|
fn print_prefixed_failures(path : String, failures : Array[String]) -> Unit {
  for failure in failures {
    println(path + ": " + failure)
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match validate_web_runtime_handoff_manifest(options) {
        Ok(message) => {
          println(message)
          0
        }
        Err(failures) => {
          print_prefixed_failures(options.display_path, failures)
          1
        }
      }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
