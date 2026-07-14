///|
struct CliOptions {
  manifest_path : String
  display_path : String
  expected_mode : String
  help : Bool
}

///|
struct ExpectedBenchmarkTarget {
  name : String
  target : String
  url : String
  metrics_path : String
}

///|
struct ExpectedScreenshot {
  name : String
  viewport : String
  path : String
}

///|
fn usage() -> String {
  "Usage: tools/moui/validate_conformance_capture_manifest <manifest.json> [--mode golden|benchmark]"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let manifest_path = Ref("")
  let display_path = Ref("")
  let expected_mode = Ref("")
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--mode" => {
        if index + 1 >= args.length() {
          return Err("missing value for --mode")
        }
        expected_mode.val = args[index + 1]
        index += 2
      }
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
    return Err("missing manifest.json path")
  }
  let display = if display_path.val == "" {
    manifest_path.val
  } else {
    display_path.val
  }
  Ok({
    manifest_path: manifest_path.val,
    display_path: display,
    expected_mode: expected_mode.val,
    help: help.val,
  })
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
fn json_number_is_one(value : Json?) -> Bool {
  match value {
    Some(Json::Number(number, repr=_)) => number == 1.0
    _ => false
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
fn required_counters() -> Array[String] {
  [
    "command_count", "text_count", "image_count", "clip_depth", "open_clip_depth",
    "layer_depth", "open_layer_depth", "filter_depth", "open_filter_depth", "path_count",
    "shader_count", "unbalanced_pop_count",
  ]
}

///|
fn required_metrics() -> Array[String] {
  [
    "startup_ms", "frame_time_ms", "dirty_count", "draw_command_count", "memory_bytes",
    "render_inspector_counters",
  ]
}

///|
fn expected_benchmark_targets() -> Array[ExpectedBenchmarkTarget] {
  [
    {
      name: "showcase-web-wasm",
      target: "examples/showcase/web_wasm",
      url: "http://127.0.0.1:18080/examples/showcase/web_wasm/",
      metrics_path: "artifacts/benchmarks/showcase-web-wasm.json",
    },
    {
      name: "markdown-editor-web-wasm",
      target: "examples/markdown_editor/web_wasm",
      url: "http://127.0.0.1:18080/examples/markdown_editor/web_wasm/",
      metrics_path: "artifacts/benchmarks/markdown-editor-web-wasm.json",
    },
  ]
}

///|
fn expected_benchmark_target(name : String) -> ExpectedBenchmarkTarget? {
  for target in expected_benchmark_targets() {
    if target.name == name {
      return Some(target)
    }
  }
  None
}

///|
fn expected_screenshots() -> Array[ExpectedScreenshot] {
  [
    {
      name: "desktop",
      viewport: "1440x900",
      path: "artifacts/golden/showcase-web-wasm/desktop.png",
    },
    {
      name: "tablet",
      viewport: "1024x768",
      path: "artifacts/golden/showcase-web-wasm/tablet.png",
    },
    {
      name: "mobile",
      viewport: "390x844",
      path: "artifacts/golden/showcase-web-wasm/mobile.png",
    },
  ]
}

///|
fn expected_screenshot(name : String) -> ExpectedScreenshot? {
  for screenshot in expected_screenshots() {
    if screenshot.name == name {
      return Some(screenshot)
    }
  }
  None
}

///|
fn validate_benchmark_target(
  target_json : Json,
  index : Int,
  seen : Map[String, Bool],
) -> Array[String] {
  let failures : Array[String] = []
  let target = match json_object_value(target_json) {
    Some(fields) => fields
    None => {
      failures.push("benchmarkTargets[\{index}] must be an object")
      return failures
    }
  }
  let label = "benchmarkTargets[\{index}]"
  let name = require_string(target, "name", label + ".name", failures)
  let target_path = require_string(
    target,
    "target",
    label + ".target",
    failures,
  )
  let target_url = require_string(target, "url", label + ".url", failures)
  let metrics_path = require_string(
    target,
    "metricsPath",
    label + ".metricsPath",
    failures,
  )
  if seen.contains(name) {
    failures.push("duplicate benchmark target '" + name + "'")
  }
  seen[name] = true
  match expected_benchmark_target(name) {
    Some(expected) => {
      if target_path != expected.target {
        failures.push(
          label + ".target must be '" + expected.target + "' for '" + name + "'",
        )
      }
      if target_url != expected.url {
        failures.push(
          label + ".url must be '" + expected.url + "' for '" + name + "'",
        )
      }
      if metrics_path != expected.metrics_path {
        failures.push(
          label +
          ".metricsPath must be '" +
          expected.metrics_path +
          "' for '" +
          name +
          "'",
        )
      }
    }
    None =>
      if !metrics_path.has_prefix("artifacts/benchmarks/") {
        failures.push(
          label + ".metricsPath must stay under artifacts/benchmarks/",
        )
      }
  }
  failures
}

///|
fn validate_screenshot_artifact(
  artifact_json : Json,
  index : Int,
  seen : Map[String, Bool],
) -> Array[String] {
  let failures : Array[String] = []
  let artifact = match json_object_value(artifact_json) {
    Some(fields) => fields
    None => {
      failures.push("screenshotArtifacts[\{index}] must be an object")
      return failures
    }
  }
  let label = "screenshotArtifacts[\{index}]"
  let name = require_string(artifact, "name", label + ".name", failures)
  let viewport = require_string(
    artifact,
    "viewport",
    label + ".viewport",
    failures,
  )
  let path = require_string(artifact, "path", label + ".path", failures)
  if seen.contains(name) {
    failures.push("duplicate screenshot artifact '" + name + "'")
  }
  seen[name] = true
  match expected_screenshot(name) {
    Some(expected) => {
      if viewport != expected.viewport {
        failures.push(
          label +
          ".viewport must be '" +
          expected.viewport +
          "' for '" +
          name +
          "'",
        )
      }
      if path != expected.path {
        failures.push(
          label + ".path must be '" + expected.path + "' for '" + name + "'",
        )
      }
    }
    None =>
      if !path.has_prefix("artifacts/golden/showcase-web-wasm/") {
        failures.push(
          label + ".path must stay under artifacts/golden/showcase-web-wasm/",
        )
      }
  }
  failures
}

///|
fn benchmark_targets_for_mode(
  manifest : Map[String, Json],
  mode : String,
  failures : Array[String],
) -> Array[Json] {
  if mode == "benchmark" {
    return require_array(
      manifest, "benchmarkTargets", "benchmarkTargets", failures,
    )
  }
  match manifest.get("benchmarkTargets") {
    Some(Json::Array(values)) => values
    _ => []
  }
}

///|
fn validate_manifest_fields(
  manifest : Map[String, Json],
  expected_mode : String,
) -> Array[String] {
  let failures : Array[String] = []
  if !json_number_is_one(manifest.get("schemaVersion")) {
    failures.push("schemaVersion must be 1")
  }
  let mode = require_string(manifest, "mode", "mode", failures)
  if mode == "" || (mode != "golden" && mode != "benchmark") {
    failures.push("mode must be 'golden' or 'benchmark'")
  }
  if expected_mode != "" && mode != expected_mode {
    failures.push("mode must be '" + expected_mode + "'")
  }
  let showcase_target = require_string(
    manifest, "showcaseTarget", "showcaseTarget", failures,
  )
  if showcase_target != "examples/showcase/web_wasm" {
    failures.push("showcaseTarget must be 'examples/showcase/web_wasm'")
  }
  let url = require_string(manifest, "url", "url", failures)
  if !url.has_suffix("/examples/showcase/web_wasm/") {
    failures.push("url must point at /examples/showcase/web_wasm/")
  }
  let benchmark_targets = benchmark_targets_for_mode(manifest, mode, failures)
  let seen_benchmark_target_names : Map[String, Bool] = Map([])
  for index in 0..<benchmark_targets.length() {
    for
      failure in validate_benchmark_target(
        benchmark_targets[index],
        index,
        seen_benchmark_target_names,
      ) {
      failures.push(failure)
    }
  }
  if mode == "benchmark" {
    for expected in expected_benchmark_targets() {
      if !seen_benchmark_target_names.contains(expected.name) {
        failures.push("benchmarkTargets must include '" + expected.name + "'")
      }
    }
  }
  ignore(
    require_string(
      manifest, "renderInspectorSource", "renderInspectorSource", failures,
    ),
  )
  let counters = require_array(
    manifest, "renderInspectorCounters", "renderInspectorCounters", failures,
  )
  assert_string_array(counters, "renderInspectorCounters", failures)
  assert_includes_all(
    counters,
    required_counters(),
    "renderInspectorCounters",
    failures,
  )
  let screenshot_artifacts = require_array(
    manifest, "screenshotArtifacts", "screenshotArtifacts", failures,
  )
  let seen_screenshot_names : Map[String, Bool] = Map([])
  for index in 0..<screenshot_artifacts.length() {
    for
      failure in validate_screenshot_artifact(
        screenshot_artifacts[index],
        index,
        seen_screenshot_names,
      ) {
      failures.push(failure)
    }
  }
  for expected in expected_screenshots() {
    if !seen_screenshot_names.contains(expected.name) {
      failures.push("screenshotArtifacts must include '" + expected.name + "'")
    }
  }
  let metrics = require_array(
    manifest, "benchmarkMetrics", "benchmarkMetrics", failures,
  )
  assert_string_array(metrics, "benchmarkMetrics", failures)
  assert_includes_all(metrics, required_metrics(), "benchmarkMetrics", failures)
  let notes = require_array(manifest, "notes", "notes", failures)
  if notes.is_empty() {
    failures.push("notes must include at least one handoff note")
  }
  assert_string_array(notes, "notes", failures)
  failures
}

///|
fn validate_manifest_text(
  text : String,
  expected_mode : String,
) -> Array[String] {
  let parsed = @json.parse(text) catch {
    _ => return ["failed to read JSON: invalid JSON"]
  }
  let manifest = match json_object(Some(parsed)) {
    Some(fields) => fields
    None => return ["manifest root must be an object"]
  }
  validate_manifest_fields(manifest, expected_mode)
}

///|
fn validate_conformance_capture_manifest(
  options : CliOptions,
) -> Result[String, Array[String]] {
  let text = match
    @tools.read_required_text(
      options.manifest_path,
      "conformance capture manifest",
    ) {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let failures = validate_manifest_text(text, options.expected_mode)
  if failures.is_empty() {
    let parsed = @json.parse(text) catch {
      _ => return Err(["failed to read JSON: invalid JSON"])
    }
    let manifest = match json_object(Some(parsed)) {
      Some(fields) => fields
      None => return Err(["manifest root must be an object"])
    }
    let mode = require_string(manifest, "mode", "mode", [])
    Ok(
      options.display_path + ": ok (" + mode + " conformance capture manifest)",
    )
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
      match validate_conformance_capture_manifest(options) {
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
