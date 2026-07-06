///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_maintenance_baseline [--repo-root PATH]
    #|
    #|Checks the tracked maintenance ratchets for oversized files, direct
    #|source-level pub(all) counts, and root facade type forwarding. The
    #|current max values lock in previous debt so future refactors can ratchet
    #|them down after splitting files or shrinking public exposure.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  -h, --help         Show this help.
    #|
  text
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
fn run_checks(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  let overflows = collect_line_budget_overflows(repo_root, failures)
  let count_overflows = collect_count_budget_overflows(repo_root, failures)
  let wrapper_failures = collect_moonbit_tool_wrapper_failures(repo_root)
  if !failures.is_empty() {
    failures
  } else {
    let messages = line_budget_overflow_paths(overflows)
    messages.append(count_budget_overflow_messages(count_overflows))
    messages.append(wrapper_failures)
    messages
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let failures = run_checks(options.repo_root)
      if failures.is_empty() {
        println("maintenance baseline guardrails: ok")
        0
      } else {
        for failure in failures {
          println(failure)
        }
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
