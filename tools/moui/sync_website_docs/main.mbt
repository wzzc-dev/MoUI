///|
struct CliOptions {
  check : Bool
  repo_root : String
  out_dir : String?
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/sync_website_docs [--check] [--out <dir>] [--root <dir>]
    #|
    #|Validates website/docs-catalog.json, copies only cataloged public Markdown into
    #|the website docs directory, removes stale Markdown, and generates catalog.json,
    #|robots.txt, and sitemap.xml.
    #|
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut check = false
  let mut repo_root = @env.current_dir().unwrap_or("")
  let mut out_dir : String? = None
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--check" => {
        check = true
        index += 1
      }
      "--root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      "--out" => {
        if index + 1 >= args.length() {
          return Err("missing value for --out")
        }
        out_dir = Some(args[index + 1])
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  Ok({ check, repo_root, out_dir, help })
}

///|
fn resolve_out_dir(repo_root : String, out_arg : String?) -> String {
  match out_arg {
    Some(value) => @tools.resolve_path(repo_root, value)
    None => @tools.resolve_path(repo_root, "website/web_wasm/docs")
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok(options) => {
      if options.help {
        println(usage())
        return 0
      }
      let catalog_path = "website/docs-catalog.json"
      let catalog_text = match
        @tools.read_required_text(
          @tools.resolve_path(options.repo_root, catalog_path),
          catalog_path,
        ) {
        Ok(text) => text
        Err(message) => {
          println("website docs catalog invalid: " + message)
          return 1
        }
      }
      let catalog = match parse_catalog(catalog_text) {
        Ok(value) => value
        Err(message) => {
          println("website docs catalog invalid: " + message)
          return 1
        }
      }
      let validated = match validate_catalog_against_repo(
        options.repo_root,
        catalog,
      ) {
        Ok(value) => value
        Err(message) => {
          println("website docs catalog invalid: " + message)
          return 1
        }
      }
      let out_dir = resolve_out_dir(options.repo_root, options.out_dir)
      match sync_or_check(options.repo_root, out_dir, validated, options.check) {
        Ok(_) => {
          if options.check {
            println(
              "website docs catalog and generated files are in sync: " +
              relative_to_repo(options.repo_root, out_dir),
            )
          } else {
            println(
              "website docs synced (" +
              validated.entries.length().to_string() +
              " public entries): " +
              relative_to_repo(options.repo_root, out_dir),
            )
          }
          0
        }
        Err(failures) => {
          for failure in failures {
            println(failure)
          }
          if options.check {
            println("Run: node scripts/sync-website-docs.mjs")
          }
          1
        }
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
