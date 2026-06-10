///|
struct CliOptions {
  repo_root : String
  log_path : String
  marker : String
  status_file : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_native_smoke_log LOG_PATH [MARKER] [options]
    #|
    #|Checks that a native smoke executable log contains every stage marker
    #|declared in skia-platform-status.json, every exact expected marker value,
    #|the required conditional markers for enabled optional capabilities, and
    #|the final success marker.
    #|
    #|Options:
    #|  --repo-root PATH     Repository root used to resolve relative paths. Defaults to cwd.
    #|  --status-file PATH   Platform status JSON file. Defaults to skia-platform-status.json.
    #|  -h, --help           Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let log_path = Ref("")
  let marker = Ref(@smoke_contract.default_success_marker)
  let status_file = Ref("skia-platform-status.json")
  let help = Ref(false)
  let custom_marker = Ref(false)
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
      "--status-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --status-file")
        }
        status_file.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if log_path.val == "" {
          log_path.val = value
        } else if !custom_marker.val {
          marker.val = value
          custom_marker.val = true
        } else {
          return Err("unexpected argument: " + value)
        }
        index += 1
      }
    }
  }
  if !help.val && log_path.val == "" {
    return Err("missing LOG_PATH")
  }
  Ok({
    repo_root: repo_root.val,
    log_path: log_path.val,
    marker: marker.val,
    status_file: status_file.val,
    help: help.val,
  })
}

///|
fn verify_native_smoke_log(options : CliOptions) -> Result[String, String] {
  let resolved_log_path = @tools.resolve_path(
    options.repo_root,
    options.log_path,
  )
  let resolved_status_file = @tools.resolve_path(
    options.repo_root,
    options.status_file,
  )
  let log_text = match
    @tools.read_required_text(resolved_log_path, "native smoke executable log") {
    Ok(text) => text
    Err(message) => return Err(message)
  }
  let status_text = match
    @tools.read_required_text(resolved_status_file, "Skia platform status JSON") {
    Ok(text) => text
    Err(message) => return Err(message)
  }
  match
    @smoke_contract.verify_smoke_log_contract(
      log_text,
      status_text,
      options.marker,
    ) {
    Ok(_) =>
      Ok(
        "Verified native smoke stage markers and success marker in " +
        resolved_log_path +
        ".",
      )
    Err(message) => Err(message)
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
      match verify_native_smoke_log(options) {
        Ok(message) => {
          println(message)
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
