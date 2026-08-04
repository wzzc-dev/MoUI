///|
struct CliOptions {
  repo_root : String
  manifest : String
  write_docs : Bool
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: node scripts/validate-platform-matrix.mjs [options]
    #|       moon run moui/validate_platform_matrix --target native -- [options]
    #|
    #|Validates the canonical 14-route platform matrix and generated Tier tables.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root. Defaults to cwd.
    #|  --manifest PATH    Matrix path. Default: checks/platform-matrix.json.
    #|  --write-docs       Refresh generated Tier tables.
    #|  -h, --help         Show this help.
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let manifest = Ref("checks/platform-matrix.json")
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
      "--manifest" => {
        if index + 1 >= args.length() {
          return Err("missing value for --manifest")
        }
        manifest.val = args[index + 1]
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
  Ok({
    repo_root: repo_root.val,
    manifest: manifest.val,
    write_docs: write_docs.val,
    help: help.val,
  })
}

///|
fn run(options : CliOptions) -> Int {
  let path = @tools.resolve_path(options.repo_root, options.manifest)
  let text = match @tools.read_required_text(path, options.manifest) {
    Ok(text) => text
    Err(message) => {
      println(message)
      return 1
    }
  }
  let matrix = match parse_platform_matrix(text) {
    Ok(matrix) => matrix
    Err(failures) => {
      for failure in failures {
        println(failure)
      }
      return 1
    }
  }
  let failures = validate_platform_matrix(options.repo_root, matrix)
  failures.append(
    sync_generated_docs(options.repo_root, matrix, options.write_docs),
  )
  if failures.is_empty() {
    let action = if options.write_docs { "synced" } else { "current" }
    println(
      "platform matrix: 14 canonical routes valid; generated docs " + action,
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
