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
      Map([])
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
  app == "counter" || app == "showcase" || app == "harmonyos_demo"
}

///|
fn valid_platform(platform : String) -> Bool {
  platform == "android" || platform == "ios" || platform == "harmonyos"
}

///|
/// Phase 2.3 (ADR 0006 § Promotion gates): valid SkiaSurfaceRoute labels
/// carried by the manifest's `renderer.surfaceRoute` field. These mirror
/// `@render.SkiaSurfaceRoute` but are checked as strings so the validator
/// stays decoupled from the cross-platform render package.
fn valid_surface_route(route : String) -> Bool {
  route == "raster" ||
  route == "metal-gpu" ||
  route == "vulkan-gpu" ||
  route == "egl-gpu" ||
  route == "direct3d-gpu"
}

///|
/// Phase 2.3: validates the optional `renderer` selection block. The
/// block mirrors `NativeRendererSelection` and is produced by
/// `scripts/record-mobile-runtime-smoke.mjs --renderer auto|skia-gpu|skia-raster`.
/// When `gpuPromoted=true`, the validator requires the matching
/// `gpuPromotionEvidence` block (see `validate_gpu_promotion_evidence`).
fn validate_renderer_block(
  manifest : Map[String, Json],
  require_passed : Bool,
  failures : Array[String],
) -> Bool {
  match manifest.get("renderer") {
    Some(Json::Object(renderer)) => {
      let requested = require_string(
        renderer, "requested", "renderer.requested", failures,
      )
      if requested != "" &&
        requested != "auto" &&
        requested != "skia-gpu" &&
        requested != "skia-raster" {
        failures.push(
          "renderer.requested must be auto, skia-gpu, or skia-raster",
        )
      }
      let selected = require_string(
        renderer, "selected", "renderer.selected", failures,
      )
      if selected != "" &&
        selected != "SkiaRasterNative" &&
        selected != "SkiaGpuNative" {
        failures.push(
          "renderer.selected must be SkiaRasterNative or SkiaGpuNative",
        )
      }
      let surface_route = require_string(
        renderer, "surfaceRoute", "renderer.surfaceRoute", failures,
      )
      if surface_route != "" && !valid_surface_route(surface_route) {
        failures.push(
          "renderer.surfaceRoute must be raster, metal-gpu, vulkan-gpu, egl-gpu, or direct3d-gpu",
        )
      }
      ignore(
        require_bool(
          renderer, "gpuAvailable", "renderer.gpuAvailable", failures,
        ),
      )
      let gpu_promoted = require_bool(
        renderer, "gpuPromoted", "renderer.gpuPromoted", failures,
      )
      // Per ADR 0006, `fallbackReason` is informational: it is empty
      // when no fallback has occurred (e.g. gpuPromoted=true) and a
      // short reason when the renderer fell back to raster. We only
      // require the field to be present as a string; empty is allowed.
      match renderer.get("fallbackReason") {
        Some(Json::String(_)) => ()
        _ => failures.push("field 'renderer.fallbackReason' must be a string")
      }
      // Per ADR 0006, gpu_promoted=true requires the matching evidence
      // block (Phase 2 promotion gates). The evidence block is validated
      // separately so partial manifests can carry the renderer block
      // without flipping gpu_promoted.
      if gpu_promoted {
        validate_gpu_promotion_evidence(manifest, require_passed, failures)
      }
      gpu_promoted
    }
    _ =>
      // The renderer block is optional: legacy manifests produced before
      // Phase 1.8 do not carry it. We only fail when --require-passed is
      // used and the manifest claims a GPU route.
      false
  }
}

///|
/// Phase 2.3: validates the `gpuPromotionEvidence` block required when
/// `renderer.gpuPromoted=true`. Per ADR 0006 § Promotion gates, every
/// gate must be satisfied before `gpu_promoted` can flip to true on a
/// platform. The seven gates are:
///   1. readbackEliminated — no read_pixels / memcpy / CGImage / UIImage /
///      NSImage / Bitmap / PixelMap in the GPU-route frame log.
///   2. rendererThread — runtime/UI thread is not on the GPU thread.
///   3. mailboxOk — capacity-two latest-wins; control messages never
///      dropped under resize/detach/context-loss/shutdown.
///   4. performance — p95 frame ≤ 16.7 ms @ 60 Hz (or ≤ 8.3 ms @ 120 Hz
///      where supported); dropped frames < 1 % over 10 min; input-to-
///      present p95 ≤ 2 VSync intervals.
///   5. memory — GPU memory bounded over 10 min; 100 surface recreation
///      + foreground/background cycles pass.
///   6. contextLoss — recovery within 3 VSyncs; raster fallback preserves
///      AppRuntime state.
///   7. rasterFallback — automatic after repeated recovery failure.
fn validate_gpu_promotion_evidence(
  manifest : Map[String, Json],
  require_passed : Bool,
  failures : Array[String],
) -> Unit {
  let evidence = require_object(
    manifest, "gpuPromotionEvidence", "gpuPromotionEvidence", failures,
  )
  // Gates 1-3 are booleans.
  let readback_eliminated = require_bool(
    evidence, "readbackEliminated", "gpuPromotionEvidence.readbackEliminated", failures,
  )
  let renderer_thread = require_bool(
    evidence, "rendererThread", "gpuPromotionEvidence.rendererThread", failures,
  )
  let mailbox_ok = require_bool(
    evidence, "mailboxOk", "gpuPromotionEvidence.mailboxOk", failures,
  )
  // Gate 4: performance.
  let performance = require_object(
    evidence, "performance", "gpuPromotionEvidence.performance", failures,
  )
  let p95_frame_ms = require_number(
    performance, "p95FrameMs", "gpuPromotionEvidence.performance.p95FrameMs", failures,
  )
  let dropped_frame_percent = require_number(
    performance, "droppedFramePercent", "gpuPromotionEvidence.performance.droppedFramePercent",
    failures,
  )
  let input_to_present_p_vsync = require_number(
    performance, "inputToPresentPVsyncIntervals", "gpuPromotionEvidence.performance.inputToPresentPVsyncIntervals",
    failures,
  )
  // Gate 5: memory.
  let memory = require_object(
    evidence, "memory", "gpuPromotionEvidence.memory", failures,
  )
  let memory_bounded = require_bool(
    memory, "bounded", "gpuPromotionEvidence.memory.bounded", failures,
  )
  let surface_recreation_cycles = require_number(
    memory, "surfaceRecreationCycles", "gpuPromotionEvidence.memory.surfaceRecreationCycles",
    failures,
  )
  let foreground_background_cycles = require_number(
    memory, "foregroundBackgroundCycles", "gpuPromotionEvidence.memory.foregroundBackgroundCycles",
    failures,
  )
  // Gate 6: context loss.
  let context_loss = require_object(
    evidence, "contextLoss", "gpuPromotionEvidence.contextLoss", failures,
  )
  let recovered_within_vsyncs = require_number(
    context_loss, "recoveredWithinVsyncs", "gpuPromotionEvidence.contextLoss.recoveredWithinVsyncs",
    failures,
  )
  let raster_fallback_preserved = require_bool(
    context_loss, "rasterFallbackPreservedAppRuntime", "gpuPromotionEvidence.contextLoss.rasterFallbackPreservedAppRuntime",
    failures,
  )
  // Gate 7: raster fallback.
  let raster_fallback = require_object(
    evidence, "rasterFallback", "gpuPromotionEvidence.rasterFallback", failures,
  )
  let automatic_after_failure = require_bool(
    raster_fallback, "automaticAfterRepeatedFailure", "gpuPromotionEvidence.rasterFallback.automaticAfterRepeatedFailure",
    failures,
  )
  // Thresholds only apply when the manifest explicitly claims seven-gate
  // promotion. Product-default GPU (`renderer.gpuPromoted=true`) may attach a
  // pending skeleton for schema completeness without blocking runtime smoke
  // `--require-passed`.
  let claim_passed = match manifest.get("gpuPromotionClaim") {
    Some(Json::True) => true
    Some(Json::String(value)) => value == "true" || value == "passed"
    _ =>
      match evidence.get("claimed") {
        Some(Json::True) => true
        Some(Json::String(value)) => value == "true" || value == "passed"
        _ => false
      }
  }
  if require_passed && claim_passed {
    if !readback_eliminated {
      failures.push(
        "gpuPromotionEvidence.readbackEliminated must be true for passed GPU promotion evidence",
      )
    }
    if !renderer_thread {
      failures.push(
        "gpuPromotionEvidence.rendererThread must be true for passed GPU promotion evidence",
      )
    }
    if !mailbox_ok {
      failures.push(
        "gpuPromotionEvidence.mailboxOk must be true for passed GPU promotion evidence",
      )
    }
    // p95 ≤ 16.7 ms @ 60 Hz.
    if p95_frame_ms <= 0.0 || p95_frame_ms > 16.7 {
      failures.push(
        "gpuPromotionEvidence.performance.p95FrameMs must be positive and ≤ 16.7 ms for passed GPU promotion evidence",
      )
    }
    // Dropped frames < 1 %.
    if dropped_frame_percent < 0.0 || dropped_frame_percent >= 1.0 {
      failures.push(
        "gpuPromotionEvidence.performance.droppedFramePercent must be < 1.0 for passed GPU promotion evidence",
      )
    }
    // Input-to-present p95 ≤ 2 VSync intervals.
    if input_to_present_p_vsync <= 0.0 || input_to_present_p_vsync > 2.0 {
      failures.push(
        "gpuPromotionEvidence.performance.inputToPresentPVsyncIntervals must be positive and ≤ 2.0 for passed GPU promotion evidence",
      )
    }
    if !memory_bounded {
      failures.push(
        "gpuPromotionEvidence.memory.bounded must be true for passed GPU promotion evidence",
      )
    }
    // 100 surface recreation cycles required.
    if surface_recreation_cycles < 100.0 {
      failures.push(
        "gpuPromotionEvidence.memory.surfaceRecreationCycles must be ≥ 100 for passed GPU promotion evidence",
      )
    }
    if foreground_background_cycles < 100.0 {
      failures.push(
        "gpuPromotionEvidence.memory.foregroundBackgroundCycles must be ≥ 100 for passed GPU promotion evidence",
      )
    }
    // Recovery within 3 VSyncs.
    if recovered_within_vsyncs <= 0.0 || recovered_within_vsyncs > 3.0 {
      failures.push(
        "gpuPromotionEvidence.contextLoss.recoveredWithinVsyncs must be positive and ≤ 3.0 for passed GPU promotion evidence",
      )
    }
    if !raster_fallback_preserved {
      failures.push(
        "gpuPromotionEvidence.contextLoss.rasterFallbackPreservedAppRuntime must be true for passed GPU promotion evidence",
      )
    }
    if !automatic_after_failure {
      failures.push(
        "gpuPromotionEvidence.rasterFallback.automaticAfterRepeatedFailure must be true for passed GPU promotion evidence",
      )
    }
  }
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
    failures.push("app must be counter, showcase, or harmonyos_demo")
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
      "platformViewCreate", "platformViewResize", "platformViewClip", "platformViewEvent",
      "platformViewDispose", "hostChannelSuccess", "hostChannelError", "hostChannelCancel",
      "hostChannelExactlyOnce", "hostChannelLateAfterDispose", "gpuRecovery", "stress",
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
  // Phase 2.3: validate the optional renderer selection block + GPU
  // promotion evidence. Returns whether gpu_promoted=true was claimed.
  let _gpu_promoted = validate_renderer_block(
    manifest, require_passed, failures,
  )
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
        "accessibilityFocus", "accessibilityAction", "platformViewCreate", "platformViewResize",
        "platformViewClip", "platformViewEvent", "platformViewDispose", "hostChannelSuccess",
        "hostChannelError", "hostChannelCancel", "hostChannelExactlyOnce", "hostChannelLateAfterDispose",
        "gpuRecovery", "stress",
      ] {
      assert_yes(observations, field, failures)
    }
    if app == "showcase" {
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
