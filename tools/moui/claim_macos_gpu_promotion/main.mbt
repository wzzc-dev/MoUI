///|
fn usage() -> String {
  (
    #|Usage: tools/moui/claim_macos_gpu_promotion --metrics <metrics.json> --out-dir <dir>
    #|  [--runner TEXT] [--artifact TEXT] [--repo-root PATH]
    #|
    #|Builds a gpuPromoted claim when ADR 0006 gates are numerically satisfied.
    #|
  )
}

///|
fn json_object(value : Json?, _label : String) -> Map[String, Json] {
  match value {
    Some(Json::Object(fields)) => fields
    _ => Map([])
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
    Some(Json::Number(number, repr=_)) => Some(number)
    _ => None
  }
}

///|
fn bool_or(value : Bool?, default : Bool) -> Bool {
  match value {
    Some(v) => v
    None => default
  }
}

///|
fn number_or(value : Double?, default : Double) -> Double {
  match value {
    Some(v) => v
    None => default
  }
}

///|
fn evaluate_claim_gates(metrics : Json) -> Array[String] {
  let root = match metrics {
    Json::Object(fields) => fields
    _ => return ["metrics must be an object"]
  }
  let gates = json_object(root.get("promotionGates"), "promotionGates")
  let perf = json_object(gates.get("performance"), "performance")
  let memory = json_object(gates.get("memory"), "memory")
  let context_loss = json_object(gates.get("contextLoss"), "contextLoss")
  let raster_fallback = json_object(
    gates.get("rasterFallback"),
    "rasterFallback",
  )
  let diagnostics = json_object(root.get("diagnostics"), "diagnostics")
  let failures : Array[String] = []
  if !bool_or(json_bool(gates, "readbackEliminated"), false) {
    failures.push("readbackEliminated")
  }
  if !bool_or(json_bool(gates, "rendererThread"), false) {
    failures.push("rendererThread")
  }
  if !bool_or(json_bool(gates, "mailboxOk"), false) {
    failures.push("mailboxOk")
  }
  let duration = number_or(json_number(perf, "durationSeconds"), 0.0)
  if !(duration >= 600.0) {
    failures.push("performance.durationSeconds>=600")
  }
  let refresh = number_or(json_number(perf, "refreshHz"), 60.0)
  let p95_limit = if refresh >= 120.0 { 8.3 } else { 16.7 }
  let p95 = number_or(json_number(perf, "p95FrameMs"), 0.0)
  if !(p95 > 0.0 && p95 <= p95_limit) {
    failures.push("performance.p95FrameMs<=\{p95_limit}")
  }
  let dropped = number_or(json_number(perf, "droppedFramePercent"), -1.0)
  if !(dropped >= 0.0 && dropped < 1.0) {
    failures.push("performance.droppedFramePercent<1")
  }
  let input_vsync = number_or(
    json_number(perf, "inputToPresentPVsyncIntervals"),
    0.0,
  )
  if !(input_vsync > 0.0 && input_vsync <= 2.0) {
    failures.push("performance.inputToPresentPVsyncIntervals<=2")
  }
  if !bool_or(json_bool(memory, "bounded"), false) {
    failures.push("memory.bounded")
  }
  let surface_cycles = number_or(
    json_number(memory, "surfaceRecreationCycles"),
    0.0,
  )
  if !(surface_cycles >= 100.0) {
    failures.push("memory.surfaceRecreationCycles>=100")
  }
  let fg_bg = number_or(json_number(memory, "foregroundBackgroundCycles"), 0.0)
  if !(fg_bg >= 100.0) {
    failures.push("memory.foregroundBackgroundCycles>=100")
  }
  let recovered = number_or(
    json_number(context_loss, "recoveredWithinVsyncs"),
    0.0,
  )
  if !(recovered > 0.0 && recovered <= 3.0) {
    failures.push("contextLoss.recoveredWithinVsyncs in 1..3")
  }
  if !bool_or(json_bool(context_loss, "rasterFallbackPreservedAppRuntime"), false) {
    failures.push("contextLoss.rasterFallbackPreservedAppRuntime")
  }
  if !bool_or(
    json_bool(raster_fallback, "automaticAfterRepeatedFailure"),
    false,
  ) {
    failures.push("rasterFallback.automaticAfterRepeatedFailure")
  }
  let readback = number_or(json_number(diagnostics, "readbackCount"), 1.0)
  if readback != 0.0 {
    failures.push("diagnostics.readbackCount==0")
  }
  if !bool_or(json_bool(diagnostics, "workerThread"), false) {
    failures.push("diagnostics.workerThread")
  }
  failures
}

///|
fn relative_to_root(repo_root : String, path : String) -> String {
  let root = if repo_root.has_suffix("/") {
    repo_root
  } else {
    repo_root + "/"
  }
  if path.has_prefix(root) {
    path[root.length():].to_owned()
  } else {
    path
  }
}

///|
fn build_claim(
  metrics : Json,
  runner : String,
  artifact : String,
  metrics_path : String,
) -> Json {
  let root = match metrics {
    Json::Object(fields) => fields
    _ => Map([])
  }
  let gates = root.get("promotionGates").unwrap_or(Json::object(Map([])))
  let diagnostics_in = json_object(root.get("diagnostics"), "diagnostics")
  let diagnostics : Map[String, Json] = Map([])
  diagnostics["readbackCount"] = Json::number(
    number_or(json_number(diagnostics_in, "readbackCount"), 0.0),
  )
  diagnostics["workerThread"] = Json::boolean(true)
  diagnostics["surfaceGeneration"] = Json::number(
    number_or(json_number(diagnostics_in, "surfaceGeneration"), 0.0),
  )
  diagnostics["contextGeneration"] = Json::number(
    number_or(json_number(diagnostics_in, "contextGeneration"), 0.0),
  )
  diagnostics["recoveryCount"] = Json::number(
    number_or(json_number(diagnostics_in, "recoveryCount"), 0.0),
  )
  diagnostics["fallbackCount"] = Json::number(
    number_or(json_number(diagnostics_in, "fallbackCount"), 0.0),
  )
  let provenance : Map[String, Json] = Map([])
  provenance["kind"] = Json::string("matching-host-artifact")
  provenance["runner"] = Json::string(runner)
  provenance["artifact"] = Json::string(artifact)
  let claim_meta : Map[String, Json] = Map([])
  claim_meta["notes"] = Json::string(
    "Generated by claim-macos-gpu-promotion.mjs after matching-host gates. Source flip is separate.",
  )
  claim_meta["metricsPath"] = Json::string(metrics_path)
  let object : Map[String, Json] = Map([])
  object["schemaVersion"] = Json::number(1.0, repr="1")
  object["renderer"] = Json::string("skia-gpu-native")
  object["platform"] = Json::string("macos")
  object["backend"] = Json::string("metal")
  object["gpuPromoted"] = Json::boolean(true)
  object["requestedMode"] = Json::string("auto")
  object["surfaceRoute"] = Json::string("metal-gpu")
  object["evidenceProvenance"] = Json::object(provenance)
  object["diagnostics"] = Json::object(diagnostics)
  object["promotionGates"] = gates
  object["claim"] = Json::object(claim_meta)
  Json::object(object)
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
struct CliOptions {
  metrics : String
  out_dir : String
  runner : String
  artifact : String
  repo_root : String
  help : Bool
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut metrics = ""
  let mut out_dir = ""
  let mut runner = "scripts/run-macos-gpu-performance-smoke.mjs --promotion-lifecycle"
  let mut artifact = ""
  let mut repo_root = @env.current_dir().unwrap_or("")
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--metrics" => {
        if index + 1 >= args.length() {
          return Err("missing value for --metrics")
        }
        metrics = args[index + 1]
        index += 2
      }
      "--out-dir" => {
        if index + 1 >= args.length() {
          return Err("missing value for --out-dir")
        }
        out_dir = args[index + 1]
        index += 2
      }
      "--runner" => {
        if index + 1 >= args.length() {
          return Err("missing value for --runner")
        }
        runner = args[index + 1]
        index += 2
      }
      "--artifact" => {
        if index + 1 >= args.length() {
          return Err("missing value for --artifact")
        }
        artifact = args[index + 1]
        index += 2
      }
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      value => return Err("unknown argument: " + value)
    }
  }
  Ok({ metrics, out_dir, runner, artifact, repo_root, help })
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok(options) => {
      if options.help {
        println(usage())
        return 0
      }
      if options.metrics == "" || options.out_dir == "" {
        println(usage())
        return 2
      }
      let metrics_path = @tools.resolve_path(options.repo_root, options.metrics)
      let out_dir = @tools.resolve_path(options.repo_root, options.out_dir)
      let metrics_text = match
        @tools.read_required_text(metrics_path, options.metrics) {
        Ok(text) => text
        Err(message) => {
          println(message)
          return 1
        }
      }
      let metrics = @json.parse(metrics_text) catch {
        _ => {
          println("metrics JSON is invalid")
          return 1
        }
      }
      let failures = evaluate_claim_gates(metrics)
      if !failures.is_empty() {
        println("cannot claim promotion; failing gates:")
        for failure in failures {
          println("  - " + failure)
        }
        return 1
      }
      match mkdir_p(out_dir) {
        Ok(_) => ()
        Err(message) => {
          println(message)
          return 1
        }
      }
      let artifact = if options.artifact != "" {
        options.artifact
      } else {
        relative_to_root(options.repo_root, out_dir)
      }
      let metrics_rel = relative_to_root(options.repo_root, metrics_path)
      let claim = build_claim(metrics, options.runner, artifact, metrics_rel)
      let claim_path = @tools.join_path(out_dir, "gpu-promotion-claim.json")
      match @tools.write_text_file(
        claim_path,
        claim.stringify(indent=2) + "\n",
        claim_path,
      ) {
        Ok(_) => {
          println("wrote " + claim_path)
          0
        }
        Err(message) => {
          println(message)
          1
        }
      }
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
