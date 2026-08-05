///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let root = Ref(@env.current_dir().unwrap_or(""))
  let help = Ref(false)
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--repo-root" => {
        if i + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        root.val = args[i + 1]
        i += 2
      }
      "-h" | "--help" => {
        help.val = true
        i += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: root.val, help: help.val })
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_window_lifecycle_boundary [--repo-root PATH]
    #|
    #|Checks the single MoUI logical window-host owner and the physical window
    #|dispatch boundary.
  )
}

///|
fn main {
  match parse_cli(@tools.args_without_program(@env.args())) {
    Ok(options) if options.help => println(usage())
    Ok(options) => {
      let failures = validate_window_lifecycle_boundary(options.repo_root)
      if failures.is_empty() {
        println("window host boundary: ok")
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
