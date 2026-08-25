///|
/// Wave A GPU promotion scaffold: schema-valid pending manifests, macOS
/// short-smoke log interpretation, and gap reports. Never sets
/// `gpuPromoted=true` and never flips `NativeGpuPlatform::gpu_promoted`.

///|
struct CliOptions {
  help : Bool
  platform : String
  out_dir : String
  mode : String
  smoke_log : String
  metrics_json : String
  runner : String
  artifact : String
  duration_seconds : Int
}

///|
/// Optional measured values from a future full harness. Wave A still forces
/// `gpuPromoted=false` even when metrics are present.
struct MetricsOverlay {
  has_values : Bool
  readback_count : Double?
  worker_thread : Bool?
  surface_generation : Double?
  context_generation : Double?
  recovery_count : Double?
  fallback_count : Double?
  readback_eliminated : Bool?
  renderer_thread : Bool?
  mailbox_ok : Bool?
  refresh_hz : Double?
  duration_seconds : Double?
  p95_frame_ms : Double?
  dropped_frame_percent : Double?
  input_to_present : Double?
  memory_bounded : Bool?
  surface_recreation_cycles : Double?
  foreground_background_cycles : Double?
  recovered_within_vsyncs : Double?
  runtime_preserved : Bool?
  automatic_fallback : Bool?
  notes : String
}

///|
struct PlatformMapping {
  backend : String
  surface_route : String
  renderer : String
}

///|
struct ShortSmokeObservation {
  metal_route : Bool
  surface_gpu : Bool
  gpu_smoke_passed : Bool
  present_count : Int
  worker_owned : Bool
  short_path_ok : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/gpu_promotion_scaffold --platform <id> --out-dir <path> [options]
    #|
    #|Write a schema-valid ADR 0006 GPU promotion scaffold under --out-dir:
    #|  gpu-promotion-manifest.json  (always gpuPromoted=false)
    #|  gap-report.md
    #|  gate-inventory.json
    #|
    #|Platforms: macos|windows|linux|android|ios|harmonyos|web
    #|
    #|Options:
    #|  --mode scaffold|short-smoke|full
    #|                                Recording mode label (default: scaffold)
    #|  --smoke-log PATH              Optional macOS GPU smoke log to interpret
    #|  --metrics-json PATH           Optional measured metrics overlay (full harness)
    #|  --runner TEXT                 Provenance runner string
    #|  --artifact TEXT               Provenance artifact path (relative preferred)
    #|  --duration-seconds N          Requested full-run duration (default 600);
    #|                                never claimed as measured without metrics
    #|  -h, --help                    Show this help
    #|
    #|Node/bash wrappers may run real smokes, then call this tool to emit JSON.
    #|Even with --metrics-json, this tool never sets gpuPromoted=true.
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let help = Ref(false)
  let platform = Ref("")
  let out_dir = Ref("")
  let mode = Ref("scaffold")
  let smoke_log = Ref("")
  let metrics_json = Ref("")
  let runner = Ref("")
  let artifact = Ref("")
  let duration_seconds = Ref(600)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      "--platform" => {
        if index + 1 >= args.length() {
          return Err("missing value for --platform")
        }
        platform.val = args[index + 1].to_lower()
        index += 2
      }
      "--out-dir" => {
        if index + 1 >= args.length() {
          return Err("missing value for --out-dir")
        }
        out_dir.val = args[index + 1]
        index += 2
      }
      "--mode" => {
        if index + 1 >= args.length() {
          return Err("missing value for --mode")
        }
        mode.val = args[index + 1].to_lower()
        index += 2
      }
      "--smoke-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --smoke-log")
        }
        smoke_log.val = args[index + 1]
        index += 2
      }
      "--metrics-json" => {
        if index + 1 >= args.length() {
          return Err("missing value for --metrics-json")
        }
        metrics_json.val = args[index + 1]
        index += 2
      }
      "--runner" => {
        if index + 1 >= args.length() {
          return Err("missing value for --runner")
        }
        runner.val = args[index + 1]
        index += 2
      }
      "--artifact" => {
        if index + 1 >= args.length() {
          return Err("missing value for --artifact")
        }
        artifact.val = args[index + 1]
        index += 2
      }
      "--duration-seconds" => {
        if index + 1 >= args.length() {
          return Err("missing value for --duration-seconds")
        }
        match parse_int_or_none(args[index + 1]) {
          Some(value) => {
            if value <= 0 {
              return Err("--duration-seconds must be positive")
            }
            duration_seconds.val = value
          }
          None => return Err("invalid --duration-seconds: " + args[index + 1])
        }
        index += 2
      }
      value => {
        if value.has_prefix("-") {
          return Err("Unknown argument: " + value)
        }
        return Err("unexpected argument: " + value)
      }
    }
  }
  if !help.val {
    if platform.val == "" {
      return Err("missing --platform")
    }
    if out_dir.val == "" {
      return Err("missing --out-dir")
    }
    if mode.val != "scaffold" && mode.val != "short-smoke" && mode.val != "full" {
      return Err("--mode must be scaffold, short-smoke, or full")
    }
  }
  Ok({
    help: help.val,
    platform: platform.val,
    out_dir: out_dir.val,
    mode: mode.val,
    smoke_log: smoke_log.val,
    metrics_json: metrics_json.val,
    runner: runner.val,
    artifact: artifact.val,
    duration_seconds: duration_seconds.val,
  })
}

///|
fn platform_mapping(platform : String) -> PlatformMapping? {
  match platform {
    "macos" =>
      Some({
        backend: "metal",
        surface_route: "metal-gpu",
        renderer: "skia-gpu-native",
      })
    "windows" =>
      Some({
        backend: "d3d12",
        surface_route: "direct3d-gpu",
        renderer: "skia-gpu-native",
      })
    "linux" =>
      Some({
        backend: "vulkan-wayland",
        surface_route: "vulkan-gpu",
        renderer: "skia-gpu-native",
      })
    "android" =>
      Some({
        backend: "vulkan",
        surface_route: "vulkan-gpu",
        renderer: "skia-gpu-native",
      })
    "ios" =>
      Some({
        backend: "metal",
        surface_route: "metal-gpu",
        renderer: "skia-gpu-native",
      })
    "harmonyos" =>
      Some({
        backend: "egl-gles",
        surface_route: "egl-gpu",
        renderer: "skia-gpu-native",
      })
    "web" =>
      Some({
        backend: "webgpu",
        surface_route: "webgpu-canvas",
        renderer: "webgpu-wasm",
      })
    _ => None
  }
}

///|
fn platform_type_label(platform : String) -> String {
  match platform {
    "macos" => "MacOS"
    "windows" => "Windows"
    "linux" => "Linux"
    "android" => "Android"
    "ios" => "IOS"
    "harmonyos" => "HarmonyOS"
    "web" => "Web"
    _ => platform
  }
}

///|
fn contains_ci(text : String, needle : String) -> Bool {
  text.to_lower().contains(needle.to_lower())
}

///|
fn parse_int_or_none(text : StringView) -> Int? {
  try @string.parse_int(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_present_count(text : String) -> Int {
  let marker = "present_count="
  let lower = text.to_lower()
  match lower.find(marker) {
    Some(start) => {
      let from = start + marker.length()
      let mut end = from
      while end < lower.length() {
        let ch = lower[end]
        if ch >= '0' && ch <= '9' {
          end += 1
        } else {
          break
        }
      }
      if end > from {
        match parse_int_or_none(lower[from:end]) {
          Some(value) => value
          None => 0
        }
      } else {
        0
      }
    }
    None => 0
  }
}

///|
fn interpret_macos_gpu_smoke_log(text : String) -> ShortSmokeObservation {
  let metal_route = contains_ci(text, "surface_route=metal-gpu") ||
    contains_ci(text, "route=metal-gpu") ||
    contains_ci(text, "MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu")
  let surface_gpu = contains_ci(text, "surface_gpu=true")
  let gpu_smoke_passed = contains_ci(
    text, "MoUI Skia GPU Metal renderer smoke passed",
  )
  let present_count = parse_present_count(text)
  let worker_owned = contains_ci(text, "worker-owned") ||
    contains_ci(text, "Picture worker") ||
    contains_ci(text, "native worker") ||
    gpu_smoke_passed
  let short_path_ok = (metal_route || gpu_smoke_passed) &&
    (surface_gpu || present_count > 0 || gpu_smoke_passed)
  {
    metal_route,
    surface_gpu,
    gpu_smoke_passed,
    present_count,
    worker_owned,
    short_path_ok,
  }
}

///|
fn empty_observation() -> ShortSmokeObservation {
  {
    metal_route: false,
    surface_gpu: false,
    gpu_smoke_passed: false,
    present_count: 0,
    worker_owned: false,
    short_path_ok: false,
  }
}

///|
fn empty_metrics() -> MetricsOverlay {
  {
    has_values: false,
    readback_count: None,
    worker_thread: None,
    surface_generation: None,
    context_generation: None,
    recovery_count: None,
    fallback_count: None,
    readback_eliminated: None,
    renderer_thread: None,
    mailbox_ok: None,
    refresh_hz: None,
    duration_seconds: None,
    p95_frame_ms: None,
    dropped_frame_percent: None,
    input_to_present: None,
    memory_bounded: None,
    surface_recreation_cycles: None,
    foreground_background_cycles: None,
    recovered_within_vsyncs: None,
    runtime_preserved: None,
    automatic_fallback: None,
    notes: "",
  }
}

///|
fn json_bool(fields : Map[String, Json], key : String) -> Bool? {
  match fields.get(key) {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
fn json_number(fields : Map[String, Json], key : String) -> Double? {
  match fields.get(key) {
    Some(Json::Number(value, repr=_)) => Some(value)
    _ => None
  }
}

///|
fn json_string(fields : Map[String, Json], key : String) -> String {
  match fields.get(key) {
    Some(Json::String(value)) => value
    _ => ""
  }
}

///|
fn parse_metrics_overlay(text : String) -> Result[MetricsOverlay, String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("metrics JSON is invalid")
  }
  match parsed {
    Json::Object(root) => {
      let diagnostics = match root.get("diagnostics") {
        Some(Json::Object(fields)) => fields
        _ => Map([])
      }
      let gates = match root.get("promotionGates") {
        Some(Json::Object(fields)) => fields
        _ => Map([])
      }
      let performance = match gates.get("performance") {
        Some(Json::Object(fields)) => fields
        _ => Map([])
      }
      let memory = match gates.get("memory") {
        Some(Json::Object(fields)) => fields
        _ => Map([])
      }
      let context_loss = match gates.get("contextLoss") {
        Some(Json::Object(fields)) => fields
        _ => Map([])
      }
      let raster_fallback = match gates.get("rasterFallback") {
        Some(Json::Object(fields)) => fields
        _ => Map([])
      }
      Ok({
        has_values: true,
        readback_count: json_number(diagnostics, "readbackCount"),
        worker_thread: json_bool(diagnostics, "workerThread"),
        surface_generation: json_number(diagnostics, "surfaceGeneration"),
        context_generation: json_number(diagnostics, "contextGeneration"),
        recovery_count: json_number(diagnostics, "recoveryCount"),
        fallback_count: json_number(diagnostics, "fallbackCount"),
        readback_eliminated: json_bool(gates, "readbackEliminated"),
        renderer_thread: json_bool(gates, "rendererThread"),
        mailbox_ok: json_bool(gates, "mailboxOk"),
        refresh_hz: json_number(performance, "refreshHz"),
        duration_seconds: json_number(performance, "durationSeconds"),
        p95_frame_ms: json_number(performance, "p95FrameMs"),
        dropped_frame_percent: json_number(performance, "droppedFramePercent"),
        input_to_present: json_number(
          performance, "inputToPresentPVsyncIntervals",
        ),
        memory_bounded: json_bool(memory, "bounded"),
        surface_recreation_cycles: json_number(
          memory, "surfaceRecreationCycles",
        ),
        foreground_background_cycles: json_number(
          memory, "foregroundBackgroundCycles",
        ),
        recovered_within_vsyncs: json_number(
          context_loss, "recoveredWithinVsyncs",
        ),
        runtime_preserved: json_bool(
          context_loss, "rasterFallbackPreservedAppRuntime",
        ),
        automatic_fallback: json_bool(
          raster_fallback, "automaticAfterRepeatedFailure",
        ),
        notes: json_string(root, "notes"),
      })
    }
    _ => Err("metrics JSON root must be an object")
  }
}

///|
fn bool_or(value : Bool?, fallback : Bool) -> Bool {
  match value {
    Some(v) => v
    None => fallback
  }
}

///|
fn number_or(value : Double?, fallback : Double) -> Double {
  match value {
    Some(v) => v
    None => fallback
  }
}

///|
fn build_pending_manifest(
  platform : String,
  mapping : PlatformMapping,
  mode : String,
  runner : String,
  artifact : String,
  duration_seconds_requested : Int,
  observation : ShortSmokeObservation,
  metrics : MetricsOverlay,
) -> Json {
  let requested_mode = if mode == "scaffold" { "auto" } else { "skia-gpu" }
  let surface_generation = if observation.short_path_ok { 1.0 } else { 0.0 }
  let worker_thread = bool_or(metrics.worker_thread, observation.worker_owned)
  let renderer_thread = bool_or(metrics.renderer_thread, worker_thread)
  let note = if metrics.has_values {
    "Partial full-harness metrics merged; gpuPromoted remains false until all gates and provenance pass --require-passed."
  } else {
    "Partial Wave A recording. Do not set gpuPromoted=true or flip auto defaults from this artifact."
  }
  {
    "schemaVersion": 1,
    "renderer": mapping.renderer,
    "platform": platform,
    "backend": mapping.backend,
    "gpuPromoted": false,
    "requestedMode": requested_mode,
    "surfaceRoute": mapping.surface_route,
    "evidenceProvenance": {
      "kind": "pending",
      "runner": runner,
      "artifact": artifact,
    },
    "diagnostics": {
      "readbackCount": number_or(metrics.readback_count, 0.0),
      "workerThread": worker_thread,
      "surfaceGeneration": number_or(
        metrics.surface_generation,
        surface_generation,
      ),
      "contextGeneration": number_or(metrics.context_generation, 0.0),
      "recoveryCount": number_or(metrics.recovery_count, 0.0),
      "fallbackCount": number_or(metrics.fallback_count, 0.0),
    },
    "promotionGates": {
      "readbackEliminated": bool_or(metrics.readback_eliminated, false),
      "rendererThread": renderer_thread,
      "mailboxOk": bool_or(metrics.mailbox_ok, false),
      "performance": {
        "refreshHz": number_or(metrics.refresh_hz, 60.0),
        "durationSeconds": number_or(metrics.duration_seconds, 0.0),
        "p95FrameMs": number_or(metrics.p95_frame_ms, 0.0),
        "droppedFramePercent": number_or(metrics.dropped_frame_percent, 100.0),
        "inputToPresentPVsyncIntervals": number_or(
          metrics.input_to_present,
          0.0,
        ),
      },
      "memory": {
        "bounded": bool_or(metrics.memory_bounded, false),
        "surfaceRecreationCycles": number_or(
          metrics.surface_recreation_cycles,
          0.0,
        ),
        "foregroundBackgroundCycles": number_or(
          metrics.foreground_background_cycles,
          0.0,
        ),
      },
      "contextLoss": {
        "recoveredWithinVsyncs": number_or(metrics.recovered_within_vsyncs, 0.0),
        "rasterFallbackPreservedAppRuntime": bool_or(
          metrics.runtime_preserved,
          false,
        ),
      },
      "rasterFallback": {
        "automaticAfterRepeatedFailure": bool_or(
          metrics.automatic_fallback,
          false,
        ),
      },
    },
    "recording": {
      "mode": mode,
      "durationSecondsRequested": duration_seconds_requested,
      "shortPathOk": observation.short_path_ok,
      "metricsMerged": metrics.has_values,
      "gatesComplete": false,
      "note": note,
      "metricsNotes": metrics.notes,
    },
  }
}

///|
fn gate_inventory_json(platform : String) -> Json {
  {
    "platform": platform,
    "gates": [
      {
        "id": "readbackEliminated",
        "status": "partial",
        "runtimeSource": "worker diagnostics readback_count; provider present path must not call read_frame",
        "staticGuard": "scripts/validate-gpu-worker-no-readback.mjs",
      },
      {
        "id": "rendererThread",
        "status": "partial",
        "runtimeSource": "diagnostics.workerThread and matching-host present logs",
        "staticGuard": "moui_skia native GPU worker + package tests",
      },
      {
        "id": "mailboxOk",
        "status": "missing-runner",
        "runtimeSource": "stress harness (not yet automated)",
        "staticGuard": "moui/render mailbox unit tests",
      },
      {
        "id": "performance",
        "status": "missing-runner",
        "runtimeSource": "long-run frame telemetry harness (not yet automated)",
        "staticGuard": "",
      },
      {
        "id": "memory",
        "status": "missing-runner",
        "runtimeSource": "lifecycle stress harness (not yet automated)",
        "staticGuard": "",
      },
      {
        "id": "contextLoss",
        "status": "missing-runner",
        "runtimeSource": "forced ContextLoss injection harness (not yet automated)",
        "staticGuard": "RendererRecovery unit/mock tests",
      },
      {
        "id": "rasterFallback",
        "status": "missing-runner",
        "runtimeSource": "repeated-failure injection harness (not yet automated)",
        "staticGuard": "hybrid renderer / recovery package tests",
      },
    ],
  }
}

///|
fn build_gap_report(
  platform : String,
  out_dir : String,
  observation : ShortSmokeObservation,
  has_observation : Bool,
) -> String {
  let builder = StringBuilder()
  builder.write_string("# GPU promotion gap report — ")
  builder.write_string(platform)
  builder.write_string("\n\n")
  builder.write_string("Generated under `")
  builder.write_string(out_dir)
  builder.write_string("`.\n\n")
  builder.write_string(
    "This report tracks what still blocks flipping `NativeGpuPlatform::",
  )
  builder.write_string(platform_type_label(platform))
  builder.write_string(".gpu_promoted()` to `true`.\n\n")
  builder.write_string("## Gate inventory\n\n")
  builder.write_string("| Gate | Tooling status |\n")
  builder.write_string("| --- | --- |\n")
  builder.write_string("| readbackEliminated | partial |\n")
  builder.write_string("| rendererThread | partial |\n")
  builder.write_string("| mailboxOk | missing-runner |\n")
  builder.write_string("| performance | missing-runner |\n")
  builder.write_string("| memory | missing-runner |\n")
  builder.write_string("| contextLoss | missing-runner |\n")
  builder.write_string("| rasterFallback | missing-runner |\n\n")
  builder.write_string("## Short-path smoke (not promotion)\n\n")
  if has_observation {
    builder.write_string("- metalRoute: ")
    builder.write_string(if observation.metal_route { "true" } else { "false" })
    builder.write_string("\n- surfaceGpu: ")
    builder.write_string(if observation.surface_gpu { "true" } else { "false" })
    builder.write_string("\n- gpuSmokePassed: ")
    builder.write_string(
      if observation.gpu_smoke_passed {
        "true"
      } else {
        "false"
      },
    )
    builder.write_string("\n- presentCount: ")
    builder.write_string(observation.present_count.to_string())
    builder.write_string("\n- workerOwned (heuristic): ")
    builder.write_string(
      if observation.worker_owned {
        "true"
      } else {
        "false"
      },
    )
    builder.write_string("\n- shortPathOk: ")
    builder.write_string(
      if observation.short_path_ok {
        "true"
      } else {
        "false"
      },
    )
    builder.write_string("\n")
  } else {
    builder.write_string(
      "- Not run / no smoke log provided in this recording.\n",
    )
  }
  builder.write_string("\n## Required before auto defaults to GPU\n\n")
  let requirements =
    #|1. Long-run performance (≥ 600s) with p95 / drop% / input latency.
    #|2. ≥ 100 surface recreation and ≥ 100 fg/bg cycles with bounded memory.
    #|3. Forced context-loss recovery within 3 VSyncs.
    #|4. Automatic raster fallback after repeated failure, AppRuntime preserved.
    #|5. Mailbox control-message stress under frame flood.
    #|6. Manifest with non-pending provenance and
    #|   `node scripts/validate-gpu-promotion-manifest.mjs <manifest> --require-passed`.
    #|7. Only then change `NativeGpuPlatform::gpu_promoted` for this platform.
    #|
  builder.write_string(requirements)
  builder.to_string()
}

///|
fn create_dir_if_missing(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  @fs.create_dir(path) catch {
    _ => return Err("could not create directory: " + path)
  }
  Ok(())
}

///|
fn mkdir_p(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  let normalized = path.replace(old="\\", new="/")
  let current = Ref(if normalized.has_prefix("/") { "/" } else { "" })
  for part in normalized.split("/") {
    if part == "" {
      continue
    }
    let part = part.to_owned()
    if current.val == "" || current.val == "/" {
      current.val = current.val + part
    } else {
      current.val = current.val + "/" + part
    }
    match create_dir_if_missing(current.val) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn write_json_file(
  path : String,
  value : Json,
  label : String,
) -> Result[Unit, String] {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let text = value.stringify(indent=2) + "\n"
  @tools.write_text_file(path, text, label)
}

///|
fn write_text(
  path : String,
  text : String,
  label : String,
) -> Result[Unit, String] {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let body = if text.has_suffix("\n") { text } else { text + "\n" }
  @tools.write_text_file(path, body, label)
}

///|
fn parent_dir(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let mut slash = -1
  for i = 0; i < normalized.length(); i = i + 1 {
    if normalized[i] == '/' {
      slash = i
    }
  }
  if slash <= 0 {
    if normalized.has_prefix("/") {
      "/"
    } else {
      "."
    }
  } else {
    normalized[:slash].to_owned()
  }
}

///|
fn join_out(out_dir : String, name : String) -> String {
  @tools.join_path(out_dir, name)
}

///|
fn default_runner(mode : String) -> String {
  match mode {
    "short-smoke" => "scripts/record-gpu-promotion-smoke.mjs --mode short-smoke"
    "full" => "scripts/record-gpu-promotion-smoke.mjs --mode full"
    _ => "scripts/record-gpu-promotion-smoke.mjs --mode scaffold"
  }
}

///|
fn run_scaffold(options : CliOptions) -> Result[Unit, String] {
  let mapping = match platform_mapping(options.platform) {
    Some(value) => value
    None =>
      return Err(
        "unsupported platform: " +
        options.platform +
        " (expected macos|windows|linux|android|ios|harmonyos|web)",
      )
  }
  let observation = if options.smoke_log != "" {
    let text = match @tools.read_required_text(options.smoke_log, "smoke log") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    interpret_macos_gpu_smoke_log(text)
  } else {
    empty_observation()
  }
  let has_observation = options.smoke_log != ""
  let metrics = if options.metrics_json != "" {
    let text = match
      @tools.read_required_text(options.metrics_json, "metrics JSON") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match parse_metrics_overlay(text) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
  } else {
    empty_metrics()
  }
  let runner = if options.runner != "" {
    options.runner
  } else {
    default_runner(options.mode)
  }
  let artifact = if options.artifact != "" {
    options.artifact
  } else {
    options.out_dir
  }
  let manifest = build_pending_manifest(
    options.platform,
    mapping,
    options.mode,
    runner,
    artifact,
    options.duration_seconds,
    observation,
    metrics,
  )
  let inventory = gate_inventory_json(options.platform)
  let gap = build_gap_report(
    options.platform,
    artifact,
    observation,
    has_observation,
  )
  match
    write_json_file(
      join_out(options.out_dir, "gpu-promotion-manifest.json"),
      manifest,
      "GPU promotion manifest",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    write_json_file(
      join_out(options.out_dir, "gate-inventory.json"),
      inventory,
      "gate inventory",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    write_text(join_out(options.out_dir, "gap-report.md"), gap, "gap report") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match run_scaffold(options) {
        Ok(_) => {
          println(
            "wrote " + join_out(options.out_dir, "gpu-promotion-manifest.json"),
          )
          println("wrote " + join_out(options.out_dir, "gap-report.md"))
          println("wrote " + join_out(options.out_dir, "gate-inventory.json"))
          println("gpuPromoted=false gatesComplete=false")
          0
        }
        Err(message) => {
          println(message)
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
