///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_guidance_consistency [options]
    #|
    #|Checks that repository guidance, docs, skills, workflows, and validation
    #|scripts stay synchronized around the current MoUI development contracts.
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
fn validate_guidance_consistency(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  push_moon_work_member_checks(repo_root, failures)
  push_daily_quality_gate_checks(repo_root, failures)
  push_release_readiness_quality_checks(repo_root, failures)
  push_agent_quality_gate_checks(repo_root, failures)
  push_theme_diagnostic_checks(repo_root, failures)
  push_window_dependency_guidance_checks(repo_root, failures)
  push_plan_index_checks(repo_root, failures)
  push_forbidden_guidance_token_checks(repo_root, failures)
  for rule in guidance_include_rules() {
    push_include_check(repo_root, rule.path, rule.token, failures)
  }
  for rule in guidance_absent_rules() {
    push_absent_check(repo_root, rule.path, rule.token, failures)
  }
  for path in guidance_file_exists_rules() {
    push_file_exists_check(repo_root, path, failures)
  }
  for path in guidance_no_workflow_file_rules() {
    push_no_workflow_files_check(repo_root, path, failures)
  }
  for path in guidance_regular_file_rules() {
    push_regular_file_check(repo_root, path, failures)
  }
  failures
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let failures = validate_guidance_consistency(options.repo_root)
      if failures.is_empty() {
        println("guidance consistency guard: ok")
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
