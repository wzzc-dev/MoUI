///|
struct CliOptions {
  manifest_path : String
  display_path : String
  require_passed : Bool
  help : Bool
}

///|
fn usage() -> String {
  "Usage: tools/moui/validate_mobile_runtime_manifest <manifest.json> [--require-passed]"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let manifest_path = Ref("")
  let display_path = Ref("")
  let require_passed = Ref(false)
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--require-passed" => {
        require_passed.val = true
        index += 1
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
    require_passed: require_passed.val,
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
fn require_object(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Map[String, Json] {
  match object.get(field) {
    Some(Json::Object(fields)) => fields
    _ => {
      failures.push("field '" + label + "' must be an object")
      {}
    }
  }
}

///|
fn require_bool(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Bool {
  match object.get(field) {
    Some(Json::True) => true
    Some(Json::False) => false
    _ => {
      failures.push("field '" + label + "' must be a bool")
      false
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
fn valid_observation(value : String) -> Bool {
  value == "yes" || value == "no" || value == "pending"
}

///|
fn observation(
  observations : Map[String, Json],
  field : String,
  failures : Array[String],
) -> String {
  let value = require_string(
    observations,
    field,
    "observations." + field,
    failures,
  )
  if value != "" && !valid_observation(value) {
    failures.push("observations." + field + " must be yes, no, or pending")
  }
  value
}

///|
fn assert_yes(
  observations : Map[String, Json],
  field : String,
  failures : Array[String],
) -> Unit {
  if observation(observations, field, failures) != "yes" {
    failures.push(
      "observations." +
      field +
      " must be yes for passed mobile runtime evidence",
    )
  }
}

///|
fn assert_observation_present(
  observations : Map[String, Json],
  field : String,
  failures : Array[String],
) -> Unit {
  ignore(observation(observations, field, failures))
}

///|
fn valid_app(app : String) -> Bool {
  app == "counter" || app == "component_gallery" || app == "harmonyos_demo"
}

///|
fn valid_platform(platform : String) -> Bool {
  platform == "android" || platform == "ios" || platform == "harmonyos"
}

///|
fn validate_manifest_fields(
  manifest : Map[String, Json],
  require_passed : Bool,
) -> Array[String] {
  let failures : Array[String] = []
  if !json_number_is_one(manifest.get("schemaVersion")) {
    failures.push("schemaVersion must be 1")
  }
  if require_string(manifest, "mode", "mode", failures) !=
    "mobile-runtime-smoke" {
    failures.push("mode must be 'mobile-runtime-smoke'")
  }
  if require_string(manifest, "generatedBy", "generatedBy", failures) !=
    "scripts/record-mobile-runtime-smoke.mjs" {
    failures.push("generatedBy must be scripts/record-mobile-runtime-smoke.mjs")
  }
  let platform = require_string(manifest, "platform", "platform", failures)
  if platform != "" && !valid_platform(platform) {
    failures.push("platform must be android, ios, or harmonyos")
  }
  let app = require_string(manifest, "app", "app", failures)
  if app != "" && !valid_app(app) {
    failures.push("app must be counter, component_gallery, or harmonyos_demo")
  }
  let status = require_string(manifest, "status", "status", failures)
  if status != "passed" && status != "partial" && status != "failed" {
    failures.push("status must be passed, partial, or failed")
  }
  let build = require_object(manifest, "build", "build", failures)
  let fallback = require_bool(
    build, "fallbackSkia", "build.fallbackSkia", failures,
  )
  ignore(require_string(build, "artifact", "build.artifact", failures))
  ignore(require_string(build, "command", "build.command", failures))
  let artifacts = require_object(manifest, "artifacts", "artifacts", failures)
  ignore(
    require_string(
      artifacts, "screenshotBefore", "artifacts.screenshotBefore", failures,
    ),
  )
  ignore(
    require_string(artifacts, "screenshot", "artifacts.screenshot", failures),
  )
  ignore(require_string(artifacts, "log", "artifacts.log", failures))
  let screenshot = require_object(
    manifest, "screenshot", "screenshot", failures,
  )
  let width = require_number(screenshot, "width", "screenshot.width", failures)
  let height = require_number(
    screenshot, "height", "screenshot.height", failures,
  )
  let total_pixels = require_number(
    screenshot, "totalPixels", "screenshot.totalPixels", failures,
  )
  let content_pixels = require_number(
    screenshot, "contentPixels", "screenshot.contentPixels", failures,
  )
  let distinct = require_number(
    screenshot, "distinctColorBuckets", "screenshot.distinctColorBuckets", failures,
  )
  let pixel_change = require_object(
    manifest, "pixelChange", "pixelChange", failures,
  )
  let comparable = require_bool(
    pixel_change, "comparable", "pixelChange.comparable", failures,
  )
  let changed_pixels = require_number(
    pixel_change, "changedPixels", "pixelChange.changedPixels", failures,
  )
  ignore(
    require_number(
      pixel_change, "changedRatio", "pixelChange.changedRatio", failures,
    ),
  )
  let observations = require_object(
    manifest, "observations", "observations", failures,
  )
  for
    field in [
      "lifecycleAttach", "lifecycleDetach", "nonblankFirstFrame", "resize", "representativeInput",
      "scrollInput", "cleanShutdown", "ime", "clipboard", "accessibility", "asyncImage",
      "accessibilityTree", "accessibilityFocus", "accessibilityAction", "realDeviceSigning",
    ] {
    assert_observation_present(observations, field, failures)
  }
  let boundary = require_string(
    manifest, "evidenceBoundary", "evidenceBoundary", failures,
  )
  if !boundary.contains("non-fallback") || !boundary.contains("fallback") {
    failures.push(
      "evidenceBoundary must mention non-fallback evidence and fallback limits",
    )
  }
  if require_passed || status == "passed" {
    if status != "passed" {
      failures.push("status must be passed when --require-passed is used")
    }
    if fallback {
      failures.push("passed mobile runtime evidence cannot use fallback Skia")
    }
    if width <= 0.0 || height <= 0.0 || total_pixels <= 0.0 {
      failures.push(
        "passed screenshot dimensions and totalPixels must be positive",
      )
    }
    if content_pixels < 1024.0 {
      failures.push("passed screenshot.contentPixels must be at least 1024")
    }
    if distinct < 4.0 {
      failures.push("passed screenshot.distinctColorBuckets must be at least 4")
    }
    if !comparable {
      failures.push("passed pixelChange.comparable must be true")
    }
    if changed_pixels < 16.0 {
      failures.push("passed pixelChange.changedPixels must be at least 16")
    }
    for
      field in [
        "lifecycleAttach", "lifecycleDetach", "nonblankFirstFrame", "resize", "representativeInput",
        "cleanShutdown", "ime", "clipboard", "accessibility", "asyncImage", "accessibilityTree",
        "accessibilityFocus", "accessibilityAction",
      ] {
      assert_yes(observations, field, failures)
    }
    if app == "component_gallery" {
      assert_yes(observations, "scrollInput", failures)
    }
  }
  failures
}

///|
fn validate_manifest_text(
  text : String,
  require_passed : Bool,
) -> Array[String] {
  let parsed = @json.parse(text) catch {
    _ => return ["failed to read JSON: invalid JSON"]
  }
  let manifest = match json_object(Some(parsed)) {
    Some(fields) => fields
    None => return ["manifest root must be an object"]
  }
  validate_manifest_fields(manifest, require_passed)
}

///|
fn validate_mobile_runtime_manifest(
  options : CliOptions,
) -> Result[String, Array[String]] {
  let text = match
    @tools.read_required_text(options.manifest_path, "mobile runtime manifest") {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let failures = validate_manifest_text(text, options.require_passed)
  if failures.is_empty() {
    Ok(options.display_path + ": ok (mobile runtime manifest)")
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
      match validate_mobile_runtime_manifest(options) {
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
