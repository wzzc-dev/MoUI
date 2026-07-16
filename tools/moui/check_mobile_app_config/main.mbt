///|
fn usage() -> String {
  (
    #|Usage: tools/moui/check_mobile_app_config [--repo-root PATH]
    #|
    #|Validates example mobile.json contracts and the managed Android shell static surface.
    #|
  )
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
      println("[moui-mobile-config] " + message)
      println(usage())
      2
    }
    Ok(repo_root) => {
      let (ids, app_failures) = validate_discovered_apps(repo_root)
      let failures = app_failures
      validate_android_managed_shell(repo_root, failures)
      if failures.length() > 0 {
        for failure in failures {
          println("[moui-mobile-config] " + failure)
        }
        1
      } else {
        println(
          "[moui-mobile-config] validated " +
          ids.length().to_string() +
          " mobile app(s): " +
          ids.join(", "),
        )
        0
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
