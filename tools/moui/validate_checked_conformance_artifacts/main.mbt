///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct ArtifactCheck {
  label : String
  path : String
  kind : String
  optional : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_checked_conformance_artifacts [--repo-root PATH]
    #|
    #|Validates checked-in conformance evidence artifacts against the current
    #|artifact boundary rules used by MoUI's release handoff.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, help: help.val })
}

///|
fn checked_artifacts() -> Array[ArtifactCheck] {
  [
    {
      label: "golden capture manifest",
      path: "artifacts/conformance/showcase-golden-capture.json",
      kind: "capture-golden",
      optional: false,
    },
    {
      label: "benchmark capture manifest",
      path: "artifacts/conformance/showcase-benchmark-capture.json",
      kind: "capture-benchmark",
      optional: false,
    },
    {
      label: "web runtime handoff manifest",
      path: "artifacts/conformance/web-runtime-handoff.json",
      kind: "web-handoff",
      optional: false,
    },
    {
      label: "web runtime presentation manifest",
      path: "artifacts/conformance/web-runtime-presentation.json",
      kind: "web-presentation",
      optional: false,
    },
    {
      label: "web platform presentation artifact copy",
      path: "artifacts/platform-evidence/web/web-runtime-presentation.json",
      kind: "web-presentation",
      optional: true,
    },
    {
      label: "platform runtime evidence manifest",
      path: "artifacts/conformance/platform-runtime-evidence.json",
      kind: "platform-evidence",
      optional: false,
    },
    {
      label: "webgpu wasm renderer proof manifest",
      path: "artifacts/conformance/renderer-proof/webgpu-wasm-web.json",
      kind: "renderer-proof",
      optional: false,
    },
    {
      label: "skia macos renderer proof manifest",
      path: "artifacts/conformance/renderer-proof/skia-native-macos.json",
      kind: "renderer-proof",
      optional: false,
    },
    {
      label: "wgpu macos renderer proof manifest",
      path: "artifacts/conformance/renderer-proof/wgpu-native-macos.json",
      kind: "renderer-proof",
      optional: false,
    },
  ]
}

///|
fn json_object_value(
  value : Json,
  label : String,
  failures : Array[String],
) -> Map[String, Json] {
  match value {
    Json::Object(fields) => fields
    _ => {
      failures.push(label + " must be an object")
      {}
    }
  }
}

///|
fn require_object(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Map[String, Json] {
  match object.get(field) {
    Some(Json::Object(fields)) => fields
    _ => {
      failures.push(label + " must be an object")
      {}
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
      failures.push(label + " must be an array")
      []
    }
  }
}

///|
fn string_field(object : Map[String, Json], field : String) -> String {
  match object.get(field) {
    Some(Json::String(value)) => value
    _ => ""
  }
}

///|
fn assert_string_field(
  object : Map[String, Json],
  field : String,
  expected : String,
  label : String,
  failures : Array[String],
) -> Unit {
  let actual = string_field(object, field)
  if actual != expected {
    failures.push(label + " must be '" + expected + "'")
  }
}

///|
fn assert_schema_version_one(
  object : Map[String, Json],
  label : String,
  failures : Array[String],
) -> Unit {
  match object.get("schemaVersion") {
    Some(Json::Number(number, repr=_)) if number == 1.0 => ()
    _ => failures.push(label + ".schemaVersion must be 1")
  }
}

///|
fn assert_schema_version_two(
  object : Map[String, Json],
  label : String,
  failures : Array[String],
) -> Unit {
  match object.get("schemaVersion") {
    Some(Json::Number(number, repr=_)) if number == 2.0 => ()
    _ => failures.push(label + ".schemaVersion must be 2")
  }
}

///|
fn sorted_json_object_keys(object : Map[String, Json]) -> Array[String] {
  let keys : Array[String] = object.keys().collect()
  keys.sort()
  keys
}

///|
fn sorted_copy(values : Array[String]) -> Array[String] {
  let copy = values.copy()
  copy.sort()
  copy
}

///|
fn arrays_equal(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn assert_exact_keys(
  object : Map[String, Json],
  expected : Array[String],
  label : String,
  failures : Array[String],
) -> Unit {
  let actual = sorted_json_object_keys(object)
  let sorted_expected = sorted_copy(expected)
  if !arrays_equal(actual, sorted_expected) {
    failures.push(
      label + " must contain exactly: " + @tools.comma_join(sorted_expected),
    )
  }
}

///|
fn array_object_by_name(
  values : Array[Json],
  name : String,
) -> Map[String, Json]? {
  for value in values {
    match value {
      Json::Object(fields) =>
        if string_field(fields, "name") == name {
          return Some(fields)
        }
      _ => ()
    }
  }
  None
}

///|
fn assert_target(
  values : Array[Json],
  name : String,
  expected_package : String,
  expected_path_field : String,
  expected_path : String,
  label : String,
  failures : Array[String],
) -> Unit {
  match array_object_by_name(values, name) {
    Some(target) => {
      assert_string_field(
        target,
        "packagePath",
        expected_package,
        label + "." + name + ".packagePath",
        failures,
      )
      assert_string_field(
        target,
        expected_path_field,
        expected_path,
        label + "." + name + "." + expected_path_field,
        failures,
      )
    }
    None => failures.push(label + " must include '" + name + "'")
  }
}

///|
fn assert_status(
  value : String,
  label : String,
  failures : Array[String],
) -> Unit {
  if !(value == "passed" || value == "failed" || value == "pending") {
    failures.push(label + " must be passed, failed, or pending")
  }
}

///|
fn web_platform_observation_keys() -> Array[String] {
  [
    "windowOpened", "resizeRedraw", "representativeInput", "cleanExit", "surface",
    "redraw", "resizeScale", "consumerInput", "textInput", "rendererHandle", "cleanShutdown",
  ]
}

///|
fn web_presentation_observation_keys() -> Array[String] {
  [
    "pageLoaded", "webGpuAvailable", "adapterRequested", "deviceRequested", "wasmStarted",
    "statusRunning", "canvasCreated", "canvasSized", "nonblankScreenshot", "cleanConsole",
    "resizeEvent", "resizedCanvas", "pointerInput", "keyboardInput", "textInput",
    "radialGradient", "transformPixels", "colorEmojiPixels", "zwjGrapheme", "bidiLayout",
    "paragraphWrapping", "selectionRects", "graphemeEditing", "imeCandidateAnchor",
    "imeCompositionVisual", "asyncImageSecondFrame", "targetClosed",
  ]
}

///|
fn platform_observation_keys() -> Array[String] {
  [
    "windowOpened", "resizeRedraw", "representativeInput", "cleanExit", "surface",
    "redraw", "resizeScale", "consumerInput", "textInput", "rendererHandle", "monitorCursor",
    "cleanShutdown", "imeCandidateAnchor", "imeSurroundingText", "imeCompositionVisual",
    "imeCommitDelete", "imeCursorUpdate", "imeScrollAnchor", "imeScaleDprAnchor",
    "imeResizeAnchor",
  ]
}

///|
fn renderer_proof_observation_keys() -> Array[String] {
  [
    "radialGradient", "transformPixels", "colorEmojiPixels", "zwjGrapheme", "bidiLayout",
    "paragraphWrapping", "selectionRects", "graphemeEditing", "imeCandidateAnchor",
    "imeCompositionVisual", "asyncImageSecondFrame",
  ]
}

///|
fn validate_capture_manifest(
  manifest : Map[String, Json],
  expected_mode : String,
  failures : Array[String],
) -> Unit {
  assert_schema_version_one(manifest, "capture", failures)
  assert_string_field(manifest, "mode", expected_mode, "capture.mode", failures)
  assert_string_field(
    manifest, "showcaseTarget", "examples/showcase/web_wasm", "capture.showcaseTarget",
    failures,
  )
  let screenshots = require_array(
    manifest, "screenshotArtifacts", "capture.screenshotArtifacts", failures,
  )
  if screenshots.length() != 3 {
    failures.push("capture.screenshotArtifacts must contain 3 viewport entries")
  }
  if expected_mode == "benchmark" {
    let targets = require_array(
      manifest, "benchmarkTargets", "capture.benchmarkTargets", failures,
    )
    match array_object_by_name(targets, "showcase-web-wasm") {
      Some(_) => ()
      None =>
        failures.push(
          "capture.benchmarkTargets must include 'showcase-web-wasm'",
        )
    }
    match array_object_by_name(targets, "markdown-editor-web-wasm") {
      Some(_) => ()
      None =>
        failures.push(
          "capture.benchmarkTargets must include 'markdown-editor-web-wasm'",
        )
    }
  }
}

///|
fn validate_web_handoff_manifest(
  manifest : Map[String, Json],
  failures : Array[String],
) -> Unit {
  assert_schema_version_one(manifest, "web handoff", failures)
  assert_string_field(
    manifest, "mode", "web-runtime-handoff", "web handoff.mode", failures,
  )
  let targets = require_array(
    manifest, "targets", "web handoff.targets", failures,
  )
  assert_target(
    targets, "showcase-web-wasm", "examples/showcase/web_wasm", "htmlPath", "examples/showcase/web_wasm/index.html",
    "web handoff.targets", failures,
  )
  assert_target(
    targets, "markdown-editor-web-wasm", "examples/markdown_editor/web_wasm", "htmlPath",
    "examples/markdown_editor/web_wasm/index.html", "web handoff.targets", failures,
  )
}

///|
fn validate_web_presentation_manifest(
  manifest : Map[String, Json],
  failures : Array[String],
) -> Unit {
  assert_schema_version_one(manifest, "web presentation", failures)
  assert_string_field(
    manifest, "mode", "web-runtime-presentation", "web presentation.mode", failures,
  )
  assert_status(
    string_field(manifest, "overallStatus"),
    "web presentation.overallStatus",
    failures,
  )
  let platform_observations = require_object(
    manifest, "platformObservations", "web presentation.platformObservations", failures,
  )
  assert_exact_keys(
    platform_observations,
    web_platform_observation_keys(),
    "web presentation.platformObservations",
    failures,
  )
  let targets = require_array(
    manifest, "targets", "web presentation.targets", failures,
  )
  if targets.length() != 1 {
    failures.push("web presentation.targets must contain exactly 1 target")
  }
  match array_object_by_name(targets, "showcase-web-wasm") {
    Some(target) => {
      assert_string_field(
        target, "packagePath", "examples/showcase/web_wasm", "web presentation.showcase-web-wasm.packagePath",
        failures,
      )
      assert_string_field(
        target, "path", "examples/showcase/web_wasm/index.html", "web presentation.showcase-web-wasm.path",
        failures,
      )
      assert_status(
        string_field(target, "status"),
        "web presentation.showcase-web-wasm.status",
        failures,
      )
      let observations = require_object(
        target, "observations", "web presentation.showcase-web-wasm.observations",
        failures,
      )
      assert_exact_keys(
        observations,
        web_presentation_observation_keys(),
        "web presentation.showcase-web-wasm.observations",
        failures,
      )
    }
    None =>
      failures.push("web presentation.targets must include 'showcase-web-wasm'")
  }
}

///|
fn validate_platform_evidence_manifest(
  manifest : Map[String, Json],
  failures : Array[String],
) -> Unit {
  assert_schema_version_two(manifest, "platform evidence", failures)
  assert_string_field(
    manifest, "mode", "platform-runtime-evidence", "platform evidence.mode", failures,
  )
  assert_string_field(
    manifest, "windowEvidenceSource", "wzzc-dev/window@0.5.1-0.1.4", "platform evidence.windowEvidenceSource",
    failures,
  )
  let platforms = require_array(
    manifest, "platforms", "platform evidence.platforms", failures,
  )
  for name in ["web", "macos", "windows", "linux"] {
    match array_object_by_name(platforms, name) {
      Some(platform) => {
        assert_status(
          string_field(platform, "status"),
          "platform evidence." + name + ".status",
          failures,
        )
        let command = string_field(platform, "windowEvidenceCommand")
        if !command.contains("wzzc-dev/window@0.5.1-0.1.4") ||
          !command.contains("package evidence") ||
          !command.contains(name) {
          failures.push(
            "platform evidence." +
            name +
            ".windowEvidenceCommand must name wzzc-dev/window@0.5.1-0.1.4 package evidence",
          )
        }
        let observations = require_object(
          platform,
          "observations",
          "platform evidence." + name + ".observations",
          failures,
        )
        assert_exact_keys(
          observations,
          platform_observation_keys(),
          "platform evidence." + name + ".observations",
          failures,
        )
      }
      None =>
        failures.push("platform evidence.platforms must include '" + name + "'")
    }
  }
}

///|
fn validate_renderer_proof_manifest(
  manifest : Map[String, Json],
  failures : Array[String],
) -> Unit {
  assert_schema_version_one(manifest, "renderer proof", failures)
  assert_string_field(
    manifest, "mode", "renderer-proof", "renderer proof.mode", failures,
  )
  let backend = string_field(manifest, "backend")
  if !["wgpu-native", "skia-native", "webgpu-wasm"].contains(backend) {
    failures.push("renderer proof.backend must be a known renderer backend")
  }
  assert_status(
    string_field(manifest, "status"),
    "renderer proof.status",
    failures,
  )
  let observations = require_object(
    manifest, "observations", "renderer proof.observations", failures,
  )
  assert_exact_keys(
    observations,
    renderer_proof_observation_keys(),
    "renderer proof.observations",
    failures,
  )
  for key in renderer_proof_observation_keys() {
    let observation = require_object(
      observations,
      key,
      "renderer proof.observations." + key,
      failures,
    )
    assert_status(
      string_field(observation, "status"),
      "renderer proof.observations." + key + ".status",
      failures,
    )
    let evidence = require_array(
      observation,
      "evidence",
      "renderer proof.observations." + key + ".evidence",
      failures,
    )
    let artifacts = require_array(
      observation,
      "artifacts",
      "renderer proof.observations." + key + ".artifacts",
      failures,
    )
    let _ = evidence
    if artifacts.is_empty() {
      failures.push(
        "renderer proof.observations." + key + ".artifacts must not be empty",
      )
    }
  }
}

///|
fn validate_artifact(
  repo_root : String,
  check : ArtifactCheck,
) -> Result[String, Array[String]] {
  let absolute = @tools.resolve_path(repo_root, check.path)
  if check.optional && !@tools.file_exists(absolute) {
    return Ok("checked conformance artifact skipped: " + check.label)
  }
  let text = match @tools.read_required_text(absolute, check.label) {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let parsed = @json.parse(text) catch { _ => return Err(["invalid JSON"]) }
  let failures : Array[String] = []
  let manifest = json_object_value(parsed, check.path, failures)
  match check.kind {
    "capture-golden" => validate_capture_manifest(manifest, "golden", failures)
    "capture-benchmark" =>
      validate_capture_manifest(manifest, "benchmark", failures)
    "web-handoff" => validate_web_handoff_manifest(manifest, failures)
    "web-presentation" => validate_web_presentation_manifest(manifest, failures)
    "platform-evidence" =>
      validate_platform_evidence_manifest(manifest, failures)
    "renderer-proof" => validate_renderer_proof_manifest(manifest, failures)
    _ => failures.push("unknown checked artifact kind: " + check.kind)
  }
  if failures.is_empty() {
    Ok("checked conformance artifact: " + check.label)
  } else {
    Err(failures)
  }
}

///|
fn run_checks(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  for check in checked_artifacts() {
    match validate_artifact(repo_root, check) {
      Ok(message) => println(message)
      Err(messages) =>
        for message in messages {
          failures.push(check.path + ": " + message)
        }
    }
  }
  failures
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let failures = run_checks(options.repo_root)
      if failures.is_empty() {
        println("checked conformance artifacts: ok")
        0
      } else {
        for failure in failures {
          println(failure)
        }
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
