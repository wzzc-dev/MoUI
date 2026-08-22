///|
struct PerformanceBudgetCliOptions {
  repo_root : String
  catalog : String
  results : String
  help : Bool
}

///|
fn performance_budget_usage() -> String {
  let text =
    #|Usage: node scripts/validate-performance-budgets.mjs [options]
    #|       moon run tools/moui/validate_performance_budgets --target native -- [options]
    #|
    #|Options:
    #|  --repo-root PATH  Repository root. Defaults to cwd.
    #|  --catalog PATH    Budget catalog. Default: checks/performance-budgets.json
    #|  --results PATH    Optional measured result JSON to compare with baselines.
    #|  -h, --help        Show this help.
    #|
  text
}

///|
fn performance_parse_cli(
  args : Array[String],
) -> Result[PerformanceBudgetCliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let catalog = Ref("checks/performance-budgets.json")
  let results = Ref("")
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" | "--catalog" | "--results" as flag => {
        if index + 1 >= args.length() {
          return Err("missing value for " + flag)
        }
        match flag {
          "--repo-root" => repo_root.val = args[index + 1]
          "--catalog" => catalog.val = args[index + 1]
          _ => results.val = args[index + 1]
        }
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({
    repo_root: repo_root.val,
    catalog: catalog.val,
    results: results.val,
    help: help.val,
  })
}

///|
fn performance_budget_run(args : Array[String]) -> Int {
  let options = match performance_parse_cli(args) {
    Ok(options) => options
    Err(message) => {
      println(message)
      println(performance_budget_usage())
      return 2
    }
  }
  if options.help {
    println(performance_budget_usage())
    return 0
  }
  let catalog_path = @tools.resolve_path(options.repo_root, options.catalog)
  let catalog_text = match
    @tools.read_required_text(catalog_path, "performance budget catalog") {
    Ok(text) => text
    Err(message) => {
      println(message)
      return 1
    }
  }
  let budgets = match performance_parse_catalog(catalog_text) {
    Ok(budgets) => budgets
    Err(failures) => {
      for failure in failures {
        println(options.catalog + ": " + failure)
      }
      return 1
    }
  }
  if options.results == "" {
    println(
      options.catalog + ": ok (5 performance budget scenarios, catalog only)",
    )
    return 0
  }
  let result_path = @tools.resolve_path(options.repo_root, options.results)
  let result_text = match
    @tools.read_required_text(result_path, "performance results") {
    Ok(text) => text
    Err(message) => {
      println(message)
      return 1
    }
  }
  let failures = performance_validate_results(result_text, budgets)
  if failures.is_empty() {
    println(options.results + ": ok (performance budgets)")
    0
  } else {
    for failure in failures {
      println(options.results + ": " + failure)
    }
    1
  }
}

///|
fn main {
  let code = performance_budget_run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
