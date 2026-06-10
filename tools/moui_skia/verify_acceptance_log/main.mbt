///|
struct CliOptions {
  repo_root : String
  log_path : String
  require_commit : Bool
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_acceptance_log LOG_PATH [options]
    #|
    #|Checks a real Skia acceptance summary log for the required pass fields:
    #|  smoke_status=0
    #|  native_smoke_marker=passed
    #|  native_pkg_restore=passed
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve relative log paths. Defaults to cwd.
    #|  --require-commit   Also require skia_commit=<40 hex chars>.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let log_path = Ref("")
  let require_commit = Ref(false)
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
      "--require-commit" => {
        require_commit.val = true
        index += 1
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if log_path.val != "" {
          return Err("unexpected argument: " + value)
        }
        log_path.val = value
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
    require_commit: require_commit.val,
    help: help.val,
  })
}

///|
fn verify_acceptance_log(options : CliOptions) -> Result[String, String] {
  let resolved_log_path = @tools.resolve_path(
    options.repo_root,
    options.log_path,
  )
  let text = match
    @tools.read_required_text(resolved_log_path, "acceptance log") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    @skia_acceptance.verify_acceptance_log_text(text, options.require_commit) {
    Ok(_) =>
      Ok("Verified real Skia acceptance log in " + resolved_log_path + ".")
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
      match verify_acceptance_log(options) {
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
