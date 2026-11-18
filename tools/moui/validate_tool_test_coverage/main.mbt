// Tooling self-test coverage ratchet.
//
// The governance tools are the thing that validates everything else, so a tool
// package with no `*_wbtest.mbt` is an untested gate. `checks/tool-test-coverage.json`
// records the ceiling for the number of such packages under `tools/moui`; the
// ceiling is a ratchet that only moves down. Adding a tool package without tests
// fails the gate immediately, which is the point.

///|
struct CoverageCatalog {
  max_untested : Int32
  root : String
}

///|
struct Options {
  repo_root : String
  help : Bool
}

///|
fn usage() -> String {
  "usage: validate_tool_test_coverage [--repo-root PATH]\n\nCounts tool packages under the catalog root that have no *_wbtest.mbt and fails above the ceiling in checks/tool-test-coverage.json. Pass --help for this text."
}

///|
fn parse_cli(args : Array[String]) -> Result[Options, String] {
  let mut repo_root = "."
  let mut help = false
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    match arg {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help = true
        index += 1
      }
      _ => return Err("unknown argument: " + arg)
    }
  }
  Ok({ repo_root, help, })
}

///|
fn json_int_field(
  fields : Map[String, Json],
  name : String,
  fallback : Int32,
) -> Result[Int32, String] {
  match fields.get(name) {
    Some(Json::Number(value, repr=_)) => Ok(value.to_int())
    Some(_) => Err(name + " must be a number")
    None => Ok(fallback)
  }
}

///|
fn json_string_field(
  fields : Map[String, Json],
  name : String,
  fallback : String,
) -> Result[String, String] {
  match fields.get(name) {
    Some(Json::String(value)) => Ok(value)
    Some(_) => Err(name + " must be a string")
    None => Ok(fallback)
  }
}

///|
fn load_catalog(path : String) -> Result[CoverageCatalog, String] {
  let text = match
    @tools.read_required_text(path, "tool test coverage catalog") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let json = @json.parse(text) catch {
    _ => return Err(path + " is not valid JSON")
  }
  let fields = match json {
    Json::Object(fields) => fields
    _ => return Err(path + " must be an object")
  }
  let max_untested = match json_int_field(fields, "maxUntestedPackages", 0) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let root = match json_string_field(fields, "root", "tools/moui") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ max_untested, root, })
}

///|
fn collect_package_status(
  repo_root : String,
  root : String,
  untested : Array[String],
) -> Result[Int32, String] {
  let absolute_root = @tools.resolve_path(repo_root, root)
  if !@tools.directory_exists(absolute_root) {
    return Err("catalog root " + root + " does not exist")
  }
  let entries : Array[String] = @fs.read_dir(absolute_root).to_owned() catch {
    _ => return Err("could not read " + root)
  }
  entries.sort_by((left, right) => left.lexical_compare(right))
  let mut packages = 0
  for entry in entries {
    let package_dir = @tools.join_path(root, entry)
    let manifest = @tools.resolve_path(
      repo_root,
      @tools.join_path(package_dir, "moon.pkg"),
    )
    if @tools.file_exists(manifest) {
      packages += 1
      let files : Array[String] = @fs.read_dir(
        @tools.resolve_path(repo_root, package_dir),
      ).to_owned() catch {
        _ => return Err("could not read " + package_dir)
      }
      if !files.any(name => name.has_suffix("_wbtest.mbt")) {
        untested.push(package_dir)
      }
    }
  }
  Ok(packages)
}

///|
fn run_checks(repo_root : String) -> Result[String, String] {
  let catalog_path = @tools.join_path(
    repo_root, "checks/tool-test-coverage.json",
  )
  let catalog = match load_catalog(catalog_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let untested : Array[String] = []
  let packages = match
    collect_package_status(repo_root, catalog.root, untested) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if packages == 0 {
    return Err("tool test coverage: no packages found under " + catalog.root)
  }
  if untested.length() > catalog.max_untested {
    let details = untested.map(path => "  " + path).join("\n")
    return Err(
      "tool test coverage: " +
      untested.length().to_string() +
      " of " +
      packages.to_string() +
      " packages under " +
      catalog.root +
      " have no *_wbtest.mbt (ceiling " +
      catalog.max_untested.to_string() +
      ")\n" +
      details,
    )
  }
  Ok(
    "tool test coverage: ok (" +
    packages.to_string() +
    " packages under " +
    catalog.root +
    ", " +
    untested.length().to_string() +
    " without tests, ceiling " +
    catalog.max_untested.to_string() +
    ")",
  )
}

///|
fn run(args : Array[String]) -> Int32 {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match run_checks(options.repo_root) {
        Ok(message) => {
          println(message)
          0
        }
        Err(message) => {
          println(message)
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
