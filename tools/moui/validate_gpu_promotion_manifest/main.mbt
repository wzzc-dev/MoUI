///|
struct CliOptions {
  manifest_path : String
  display_path : String
  require_passed : Bool
  help : Bool
}

///|
fn usage() -> String {
  "Usage: tools/moui/validate_gpu_promotion_manifest <manifest.json> [--require-passed]"
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
  Ok({
    manifest_path: manifest_path.val,
    display_path: if display_path.val == "" {
      manifest_path.val
    } else {
      display_path.val
    },
    require_passed: require_passed.val,
    help: help.val,
  })
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
      Map([])
    }
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
fn optional_string(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> String {
  match object.get(field) {
    Some(Json::String(value)) => value
    _ => {
      failures.push("field '" + label + "' must be a string")
      ""
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
    Some(Json::Number(value, repr=_)) => value
    _ => {
      failures.push("missing number field '" + label + "'")
      0.0
    }
  }
}

///|
fn platform_supported(platform : String) -> Bool {
  match platform {
    "macos" | "windows" | "linux" | "android" | "ios" | "harmonyos" | "web" =>
      true
    _ => false
  }
}

///|
fn platform_backend_valid(platform : String, backend : String) -> Bool {
  match platform {
    "macos" | "ios" => backend == "metal"
    "windows" => backend == "d3d12"
    "linux" => backend == "vulkan-wayland"
    "android" => backend == "vulkan" || backend == "egl-gles"
    "harmonyos" => backend == "egl-gles"
    "web" => backend == "webgpu"
    _ => false
  }
}

///|
fn platform_route_valid(platform : String, route : String) -> Bool {
  match platform {
    "macos" | "ios" => route == "metal-gpu"
    "windows" => route == "direct3d-gpu"
    "linux" => route == "vulkan-gpu"
    "android" => route == "vulkan-gpu" || route == "egl-gpu"
    "harmonyos" => route == "egl-gpu"
    "web" => route == "webgpu-canvas"
    _ => false
  }
}

///|
fn validate_manifest_fields(
  manifest : Map[String, Json],
  require_passed : Bool,
) -> Array[String] {
  let failures : Array[String] = []
  let schema_version = require_number(
    manifest, "schemaVersion", "schemaVersion", failures,
  )
  if schema_version != 1.0 {
    failures.push("schemaVersion must be 1")
  }
  let platform = require_string(manifest, "platform", "platform", failures)
  if platform != "" && !platform_supported(platform) {
    failures.push(
      "platform must be macos, windows, linux, android, ios, harmonyos, or web",
    )
  }
  let renderer = require_string(manifest, "renderer", "renderer", failures)
  let expected_renderer = if platform == "web" {
    "webgpu-wasm"
  } else {
    "skia-gpu-native"
  }
  if renderer != "" && renderer != expected_renderer {
    failures.push("renderer must be " + expected_renderer + " for " + platform)
  }
  let backend = require_string(manifest, "backend", "backend", failures)
  if platform != "" &&
    backend != "" &&
    !platform_backend_valid(platform, backend) {
    failures.push("backend '" + backend + "' is invalid for " + platform)
  }
  let route = require_string(manifest, "surfaceRoute", "surfaceRoute", failures)
  if platform != "" && route != "" && !platform_route_valid(platform, route) {
    failures.push("surfaceRoute '" + route + "' is invalid for " + platform)
  }
  ignore(require_string(manifest, "requestedMode", "requestedMode", failures))
  let gpu_promoted = require_bool(
    manifest, "gpuPromoted", "gpuPromoted", failures,
  )
  let provenance = require_object(
    manifest, "evidenceProvenance", "evidenceProvenance", failures,
  )
  let provenance_kind = require_string(
    provenance, "kind", "evidenceProvenance.kind", failures,
  )
  if provenance_kind != "pending" &&
    provenance_kind != "github-actions" &&
    provenance_kind != "matching-host-artifact" {
    failures.push(
      "evidenceProvenance.kind must be pending, github-actions, or matching-host-artifact",
    )
  }
  let runner = optional_string(
    provenance, "runner", "evidenceProvenance.runner", failures,
  )
  let artifact = optional_string(
    provenance, "artifact", "evidenceProvenance.artifact", failures,
  )
  let diagnostics = require_object(
    manifest, "diagnostics", "diagnostics", failures,
  )
  let readback_count = require_number(
    diagnostics, "readbackCount", "diagnostics.readbackCount", failures,
  )
  ignore(
    require_bool(
      diagnostics, "workerThread", "diagnostics.workerThread", failures,
    ),
  )
  for
    field in [
      "surfaceGeneration", "contextGeneration", "recoveryCount", "fallbackCount",
    ] {
    ignore(require_number(diagnostics, field, "diagnostics." + field, failures))
  }
  let gates = require_object(
    manifest, "promotionGates", "promotionGates", failures,
  )
  let readback_eliminated = require_bool(
    gates, "readbackEliminated", "promotionGates.readbackEliminated", failures,
  )
  let renderer_thread = require_bool(
    gates, "rendererThread", "promotionGates.rendererThread", failures,
  )
  let mailbox_ok = require_bool(
    gates, "mailboxOk", "promotionGates.mailboxOk", failures,
  )
  let performance = require_object(
    gates, "performance", "promotionGates.performance", failures,
  )
  let refresh_hz = require_number(
    performance, "refreshHz", "promotionGates.performance.refreshHz", failures,
  )
  let duration_seconds = require_number(
    performance, "durationSeconds", "promotionGates.performance.durationSeconds",
    failures,
  )
  let p95_frame_ms = require_number(
    performance, "p95FrameMs", "promotionGates.performance.p95FrameMs", failures,
  )
  let dropped_percent = require_number(
    performance, "droppedFramePercent", "promotionGates.performance.droppedFramePercent",
    failures,
  )
  let input_to_present = require_number(
    performance, "inputToPresentPVsyncIntervals", "promotionGates.performance.inputToPresentPVsyncIntervals",
    failures,
  )
  let memory = require_object(
    gates, "memory", "promotionGates.memory", failures,
  )
  let memory_bounded = require_bool(
    memory, "bounded", "promotionGates.memory.bounded", failures,
  )
  let surface_cycles = require_number(
    memory, "surfaceRecreationCycles", "promotionGates.memory.surfaceRecreationCycles",
    failures,
  )
  let lifecycle_cycles = require_number(
    memory, "foregroundBackgroundCycles", "promotionGates.memory.foregroundBackgroundCycles",
    failures,
  )
  let context_loss = require_object(
    gates, "contextLoss", "promotionGates.contextLoss", failures,
  )
  let recovered_vsyncs = require_number(
    context_loss, "recoveredWithinVsyncs", "promotionGates.contextLoss.recoveredWithinVsyncs",
    failures,
  )
  let runtime_preserved = require_bool(
    context_loss, "rasterFallbackPreservedAppRuntime", "promotionGates.contextLoss.rasterFallbackPreservedAppRuntime",
    failures,
  )
  let fallback = require_object(
    gates, "rasterFallback", "promotionGates.rasterFallback", failures,
  )
  let automatic_fallback = require_bool(
    fallback, "automaticAfterRepeatedFailure", "promotionGates.rasterFallback.automaticAfterRepeatedFailure",
    failures,
  )
  if require_passed || gpu_promoted {
    if !gpu_promoted {
      failures.push("gpuPromoted must be true when --require-passed is used")
    }
    if provenance_kind == "pending" ||
      runner.trim().to_owned() == "" ||
      artifact.trim().to_owned() == "" {
      failures.push(
        "passed GPU promotion requires concrete runner and artifact provenance",
      )
    }
    if readback_count != 0.0 || !readback_eliminated {
      failures.push(
        "passed GPU promotion requires readbackCount=0 and readbackEliminated=true",
      )
    }
    if !renderer_thread {
      failures.push("promotionGates.rendererThread must be true")
    }
    if !mailbox_ok {
      failures.push("promotionGates.mailboxOk must be true")
    }
    let p95_limit = if refresh_hz >= 120.0 { 8.3 } else { 16.7 }
    if refresh_hz < 60.0 {
      failures.push("promotionGates.performance.refreshHz must be at least 60")
    }
    if duration_seconds < 600.0 {
      failures.push(
        "promotionGates.performance.durationSeconds must be at least 600",
      )
    }
    if p95_frame_ms <= 0.0 || p95_frame_ms > p95_limit {
      failures.push(
        "promotionGates.performance.p95FrameMs exceeds the refresh-rate limit",
      )
    }
    if dropped_percent < 0.0 || dropped_percent >= 1.0 {
      failures.push(
        "promotionGates.performance.droppedFramePercent must be below 1",
      )
    }
    if input_to_present <= 0.0 || input_to_present > 2.0 {
      failures.push(
        "promotionGates.performance.inputToPresentPVsyncIntervals must be in (0, 2]",
      )
    }
    if !memory_bounded || surface_cycles < 100.0 || lifecycle_cycles < 100.0 {
      failures.push(
        "passed GPU promotion requires bounded memory and 100 surface/lifecycle cycles",
      )
    }
    if recovered_vsyncs <= 0.0 || recovered_vsyncs > 3.0 || !runtime_preserved {
      failures.push(
        "passed GPU promotion requires recovery within 3 VSyncs and preserved AppRuntime",
      )
    }
    if !automatic_fallback {
      failures.push("passed GPU promotion requires automatic raster fallback")
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
  match parsed {
    Json::Object(manifest) => validate_manifest_fields(manifest, require_passed)
    _ => ["manifest root must be an object"]
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let text = match
        @tools.read_required_text(
          options.manifest_path,
          "GPU promotion manifest",
        ) {
        Ok(value) => value
        Err(message) => {
          println(options.display_path + ": " + message)
          return 1
        }
      }
      let failures = validate_manifest_text(text, options.require_passed)
      if failures.is_empty() {
        println(options.display_path + ": ok (GPU promotion manifest)")
        0
      } else {
        for failure in failures {
          println(options.display_path + ": " + failure)
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
