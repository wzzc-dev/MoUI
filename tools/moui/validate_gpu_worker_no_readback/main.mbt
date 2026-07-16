///|
struct ForbiddenPattern {
  label : String
  needles : Array[String]
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_gpu_worker_no_readback [--repo-root PATH]
    #|
    #|Guards the native GPU worker against CPU readback and platform pixel presenters.
    #|
  )
}

///|
fn forbidden_patterns() -> Array[ForbiddenPattern] {
  [
    {
      label: "Skia readback",
      needles: ["read_pixels", "readPixels"],
    },
    {
      label: "CPU pixel presenter",
      needles: ["present_skia_pixels", "present_rgba_pixels"],
    },
    {
      label: "renderer read-frame path",
      needles: ["read_frame("],
    },
    {
      label: "platform CPU presenter",
      needles: ["CGImage", "UIImage", "StretchDIBits", "wl_shm"],
    },
  ]
}

///|
fn line_of_offset(text : String, offset : Int) -> Int {
  let mut lines = 1
  let mut index = 0
  while index < offset && index < text.length() {
    if text[index] == '\n' {
      lines += 1
    }
    index += 1
  }
  lines
}

///|
fn first_match_offset(text : String, needle : String) -> Int? {
  match text.find(needle) {
    Some(offset) => Some(offset)
    None => None
  }
}

///|
fn validate_worker_source(worker_path : String, worker : String) -> Array[String] {
  let failures : Array[String] = []
  for pattern in forbidden_patterns() {
    for needle in pattern.needles {
      match first_match_offset(worker, needle) {
        Some(offset) => {
          let line = line_of_offset(worker, offset)
          failures.push(
            worker_path +
            ":" +
            line.to_string() +
            ": GPU worker contains forbidden " +
            pattern.label,
          )
          break
        }
        None => ()
      }
    }
  }
  failures
}

///|
fn validate_worker_api(worker_api_path : String, worker_api : String) -> Array[String] {
  if worker_api.contains("readback_count: 0L") ||
    worker_api.contains("readback_count:0L") {
    []
  } else {
    [
      worker_api_path +
      ": native worker diagnostics must report readback_count: 0L",
    ]
  }
}

///|
fn android_flags_block(build : String) -> String? {
  match build.find("platform === \"android\"") {
    None => None
    Some(android_start) =>
      match build[android_start:].find("platform === \"harmonyos\"") {
        None => None
        Some(relative_harmony) => {
          let harmony_start = android_start + relative_harmony
          if harmony_start > android_start {
            Some(build[android_start:harmony_start].to_owned())
          } else {
            None
          }
        }
      }
  }
}

///|
fn validate_build_flags(build_path : String, build : String) -> Array[String] {
  match android_flags_block(build) {
    None => [build_path + ": Android Skia platform flags block was not found"]
    Some(android_flags) =>
      if android_flags.contains("-lvulkan") {
        [
          build_path +
          ": Android minSdk 23 GPU builds must dynamically load Vulkan, not link -lvulkan",
        ]
      } else {
        []
      }
  }
}

///|
fn validate_sources(
  worker_path : String,
  worker : String,
  worker_api_path : String,
  worker_api : String,
  build_path : String,
  build : String,
) -> Array[String] {
  let failures = validate_worker_source(worker_path, worker)
  for failure in validate_worker_api(worker_api_path, worker_api) {
    failures.push(failure)
  }
  for failure in validate_build_flags(build_path, build) {
    failures.push(failure)
  }
  failures
}

///|
fn parse_repo_root(args : Array[String]) -> Result[String, String] {
  let mut repo_root = @env.current_dir().unwrap_or("")
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => return Err("help")
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  Ok(repo_root)
}

///|
fn run(args : Array[String]) -> Int {
  match parse_repo_root(args) {
    Err("help") => {
      println(usage())
      0
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok(repo_root) => {
      let worker_rel = "moui_skia/native/skia_stub_gpu_worker.cpp"
      let worker_api_rel = "moui_skia/native/native_gpu_worker_native.mbt"
      let build_rel = "moui_skia/build.js"
      let worker_path = @tools.resolve_path(repo_root, worker_rel)
      let worker_api_path = @tools.resolve_path(repo_root, worker_api_rel)
      let build_path = @tools.resolve_path(repo_root, build_rel)
      let worker = match @tools.read_required_text(worker_path, worker_rel) {
        Ok(text) => text
        Err(message) => {
          println(message)
          return 1
        }
      }
      let worker_api = match
        @tools.read_required_text(worker_api_path, worker_api_rel) {
        Ok(text) => text
        Err(message) => {
          println(message)
          return 1
        }
      }
      let build = match @tools.read_required_text(build_path, build_rel) {
        Ok(text) => text
        Err(message) => {
          println(message)
          return 1
        }
      }
      let failures = validate_sources(
        worker_path,
        worker,
        worker_api_path,
        worker_api,
        build_path,
        build,
      )
      if failures.is_empty() {
        println("GPU worker no-readback guard: ok")
        0
      } else {
        for failure in failures {
          println(failure)
        }
        1
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
