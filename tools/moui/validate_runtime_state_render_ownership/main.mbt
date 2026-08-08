///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_runtime_state_render_ownership [--repo-root PATH]
    #|
    #|Checks runtime accessibility neutrality, app state ownership, backend
    #|image/cache ownership, and removal of superseded renderer contracts.
  )
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
fn main {
  match parse_cli(@tools.args_without_program(@env.args())) {
    Ok(options) if options.help => println(usage())
    Ok(options) => {
      let failures = validate_repository(options.repo_root)
      if failures.is_empty() {
        println("runtime state/render ownership: ok")
      } else {
        for failure in failures {
          println(failure)
        }
        @sys.exit(1)
      }
    }
    Err(message) => {
      println(message)
      println(usage())
      @sys.exit(2)
    }
  }
}
