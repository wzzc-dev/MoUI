///|
struct CliOptions {
  repo_root : String
  write_docs : Bool
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_portfolio_governance [options]
    #|
    #|Validates route/module ownership and lifecycle governance, synchronized
    #|release coupling, generated status blocks, and known semantic drift.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root. Defaults to cwd.
    #|  --write-docs       Refresh generated portfolio status blocks.
    #|  -h, --help         Show this help.
    #|
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let write_docs = Ref(false)
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
      "--write-docs" => {
        write_docs.val = true
        index += 1
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, write_docs: write_docs.val, help: help.val, })
}

///|
fn read_catalog(
  repo_root : String,
  path : String,
) -> Result[String, Array[String]] {
  match @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
    Ok(text) => Ok(text)
    Err(message) => Err([message])
  }
}

///|
fn run(options : CliOptions) -> Int32 {
  let portfolio_text = match
    read_catalog(options.repo_root, "checks/portfolio-governance.json") {
    Ok(text) => text
    Err(failures) => {
      for failure in failures {
        println(failure)
      }
      return 1
    }
  }
  let matrix_text = match
    read_catalog(options.repo_root, "checks/platform-matrix.json") {
    Ok(text) => text
    Err(failures) => {
      for failure in failures {
        println(failure)
      }
      return 1
    }
  }
  let release_text = match
    read_catalog(options.repo_root, "checks/release-modules.json") {
    Ok(text) => text
    Err(failures) => {
      for failure in failures {
        println(failure)
      }
      return 1
    }
  }
  let portfolio = match parse_portfolio_catalog(portfolio_text) {
    Ok(value) => value
    Err(failures) => {
      for failure in failures {
        println(failure)
      }
      return 1
    }
  }
  let matrix = match parse_platform_facts(matrix_text) {
    Ok(value) => value
    Err(failures) => {
      for failure in failures {
        println(failure)
      }
      return 1
    }
  }
  let release = match parse_release_facts(release_text) {
    Ok(value) => value
    Err(failures) => {
      for failure in failures {
        println(failure)
      }
      return 1
    }
  }
  let failures = validate_portfolio_governance(
    options.repo_root,
    portfolio,
    matrix,
    release,
  )
  failures.append(
    sync_generated_docs(
      options.repo_root,
      portfolio,
      matrix,
      release,
      options.write_docs,
    ),
  )
  if failures.is_empty() {
    let action = if options.write_docs { "synced" } else { "current" }
    println(
      "portfolio governance: " +
      matrix.routes.length().to_string() +
      " routes/variants and " +
      release.modules
      .filter(entry => entry.publication == "public")
      .length()
      .to_string() +
      " public modules valid; generated docs " +
      action,
    )
    0
  } else {
    for failure in failures {
      println(failure)
    }
    1
  }
}

///|
fn main {
  match parse_cli(@tools.args_without_program(@env.args())) {
    Ok(options) if options.help => println(usage())
    Ok(options) => {
      let code = run(options)
      if code != 0 {
        @sys.exit(code)
      }
    }
    Err(message) => {
      println(message)
      println(usage())
      @sys.exit(2)
    }
  }
}
