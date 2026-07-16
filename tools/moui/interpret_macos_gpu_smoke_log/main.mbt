///|
struct SmokeInterpretation {
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
    #|Usage: tools/moui/interpret_macos_gpu_smoke_log [--log-file PATH] [--log-text TEXT]
    #|
    #|Interprets macOS GPU short-smoke log heuristics as JSON.
    #|
  )
}

///|
fn contains_ci(text : String, needle : String) -> Bool {
  text.to_lower().contains(needle.to_lower())
}

///|
fn parse_present_count(text : String) -> Int {
  // look for present_count=<digits>
  let marker = "present_count="
  let lower = text.to_lower()
  match lower.find(marker) {
    None => 0
    Some(start) => {
      let rest = lower[start + marker.length():]
      let mut value = 0
      let mut seen = false
      for ch in rest {
        if ch.is_ascii_digit() {
          seen = true
          value = value * 10 + (ch.to_int() - '0'.to_int())
        } else {
          break
        }
      }
      if seen {
        value
      } else {
        0
      }
    }
  }
}

///|
fn interpret_macos_gpu_smoke_log(log_text : String) -> SmokeInterpretation {
  let text = log_text
  let metal_route = contains_ci(text, "surface_route=metal-gpu") ||
    contains_ci(text, "route=metal-gpu") ||
    contains_ci(text, "MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu")
  let surface_gpu = contains_ci(text, "surface_gpu=true")
  let gpu_smoke_passed = contains_ci(
    text,
    "MoUI Skia GPU Metal renderer smoke passed",
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
fn interpretation_to_json(value : SmokeInterpretation) -> Json {
  let object : Map[String, Json] = Map([])
  object["metalRoute"] = Json::boolean(value.metal_route)
  object["surfaceGpu"] = Json::boolean(value.surface_gpu)
  object["gpuSmokePassed"] = Json::boolean(value.gpu_smoke_passed)
  object["presentCount"] = Json::number(
    value.present_count.to_double(),
    repr=value.present_count.to_string(),
  )
  object["workerOwned"] = Json::boolean(value.worker_owned)
  object["shortPathOk"] = Json::boolean(value.short_path_ok)
  Json::object(object)
}

///|
fn parse_cli(args : Array[String]) -> Result[(String, Bool), String] {
  let mut log_text = ""
  let mut log_file = ""
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--log-text" => {
        if index + 1 >= args.length() {
          return Err("missing value for --log-text")
        }
        log_text = args[index + 1]
        index += 2
      }
      "--log-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --log-file")
        }
        log_file = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  if help {
    return Err("help")
  }
  if log_file != "" {
    match @tools.read_required_text(log_file, log_file) {
      Ok(text) => Ok((text, false))
      Err(message) => Err(message)
    }
  } else {
    Ok((log_text, false))
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err("help") => {
      println(usage())
      0
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok((log_text, _)) => {
      let interpretation = interpret_macos_gpu_smoke_log(log_text)
      println(interpretation_to_json(interpretation).stringify(indent=2))
      0
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
