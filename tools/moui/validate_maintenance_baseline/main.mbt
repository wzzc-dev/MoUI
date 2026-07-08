///|
fn run_checks(repo_root : String, scope : String) -> Array[String] {
  let failures : Array[String] = []
  let overflows = collect_line_budget_overflows(repo_root, scope, failures)
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
      let failures = run_checks(options.repo_root, options.scope)
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
