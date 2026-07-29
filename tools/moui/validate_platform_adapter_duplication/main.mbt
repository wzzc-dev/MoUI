///|
struct CliOptions {
  repo_root : String
  today : String?
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_platform_adapter_duplication --today YYYY-MM-DD [--repo-root PATH]
    #|
    #|Enforces the ADR 0020 Platform Bridge duplication budget. It requires the
    #|bridge package and platform imports, rejects shared helper redefinitions
    #|and budget growth, and rejects expired allowlist entries.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let today = Ref(None)
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
      "--today" => {
        if index + 1 >= args.length() {
          return Err("missing value for --today")
        }
        today.val = Some(args[index + 1])
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, today: today.val, help: help.val })
}

///|
fn main {
  match parse_cli(@tools.args_without_program(@env.args())) {
    Ok(options) if options.help => println(usage())
    Ok(options) =>
      match options.today {
        None => {
          println("--today YYYY-MM-DD is required")
          println(usage())
          @sys.exit(2)
        }
        Some(today) => {
          let failures = validate_repository(options.repo_root, today)
          if failures.is_empty() {
            println("platform bridge duplication guard: ok")
          } else {
            for failure in failures {
              println(failure)
            }
            @sys.exit(1)
          }
        }
      }
    Err(message) => {
      println(message)
      println(usage())
      @sys.exit(2)
    }
  }
}
