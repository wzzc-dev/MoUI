// Documentation line budget validator.
//
// Counts Markdown lines under the roots declared in `checks/doc-budget.json` and
// fails when the total exceeds the ceiling. The ceiling is a ratchet: it comes
// down when documentation shrinks, and only an owner decision raises it. The
// generated website mirror and `memories/repo` are not roots, so they never
// inflate the number a contributor has to cut.

///|
struct DocFile {
  path : String
  lines : Int32
}

///|
struct DocBudgetCatalog {
  max_lines : Int32
  roots : Array[String]
  excluded : Array[String]
}

///|
struct Options {
  repo_root : String
  help : Bool
}

///|
fn usage() -> String {
  "usage: validate_doc_budget [--repo-root PATH]\n\nCounts Markdown lines under the roots named in checks/doc-budget.json and fails when the total exceeds maxLines. Pass --help for this text."
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
          return Err("--repo-root requires a path")
        }
        repo_root = args[index + 1]
        index = index + 2
      }
      "--help" | "-h" => {
        help = true
        index = index + 1
      }
      _ => return Err("unknown argument: " + arg)
    }
  }
  Ok({ repo_root, help, })
}

///|
fn json_int_field(
  fields : Map[String, Json],
  key : String,
) -> Result[Int32, String] {
  match fields.get(key) {
    Some(Json::Number(value, repr=_)) if value >= 0.0 && value <= 1000000000.0 =>
      Ok(value.to_int())
    Some(Json::Number(_, repr=_)) => Err(key + " must be a non-negative number")
    None => Err(key + " is required")
    _ => Err(key + " must be a number")
  }
}

///|
fn json_string_array_field(
  fields : Map[String, Json],
  key : String,
) -> Result[Array[String], String] {
  match fields.get(key) {
    None => Ok([])
    Some(Json::Array(values)) => {
      let out : Array[String] = []
      for value in values {
        match value {
          Json::String(text) => out.push(text)
          _ => return Err(key + " must be a string array")
        }
      }
      Ok(out)
    }
    _ => Err(key + " must be a string array")
  }
}

///|
fn load_catalog(repo_root : String) -> Result[DocBudgetCatalog, String] {
  let path = @tools.resolve_path(repo_root, "checks/doc-budget.json")
  let text = match @tools.read_required_text(path, "checks/doc-budget.json") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("checks/doc-budget.json is not valid JSON")
  }
  let fields = match parsed {
    Json::Object(fields) => fields
    _ => return Err("checks/doc-budget.json must be an object")
  }
  let max_lines = match json_int_field(fields, "maxLines") {
    Ok(value) => value
    Err(message) => return Err("checks/doc-budget.json: " + message)
  }
  let roots = match json_string_array_field(fields, "roots") {
    Ok(values) => values
    Err(message) => return Err("checks/doc-budget.json: " + message)
  }
  if roots.is_empty() {
    return Err("checks/doc-budget.json: roots must not be empty")
  }
  let excluded = match json_string_array_field(fields, "excluded") {
    Ok(values) => values
    Err(message) => return Err("checks/doc-budget.json: " + message)
  }
  Ok({ max_lines, roots, excluded, })
}

///|
fn path_is_excluded(relative : String, excluded : Array[String]) -> Bool {
  for entry in excluded {
    if relative == entry || relative.has_prefix(entry + "/") {
      return true
    }
  }
  false
}

///|
fn collect_markdown_files(
  disk_dir : String,
  relative : String,
  excluded : Array[String],
  out : Array[String],
) -> Unit {
  let entries = @fs.read_dir(disk_dir) catch { _ => return }
  for entry in entries {
    let rel = if relative.length() == 0 {
      entry
    } else {
      relative + "/" + entry
    }
    if path_is_excluded(rel, excluded) {
      continue
    }
    let path = @tools.join_path(disk_dir, entry)
    if @tools.directory_exists(path) {
      collect_markdown_files(path, rel, excluded, out)
    } else if entry.has_suffix(".md") {
      out.push(rel)
    }
  }
}

///|
fn count_lines(text : String) -> Int32 {
  let mut lines = 0
  let mut index = 0
  while index < text.length() {
    if text[index] == '\n' {
      lines = lines + 1
    }
    index = index + 1
  }
  lines
}

///|
fn measure_root(
  repo_root : String,
  root : String,
  excluded : Array[String],
) -> Result[Array[DocFile], String] {
  let disk_root = @tools.resolve_path(repo_root, root)
  if !@tools.directory_exists(disk_root) {
    return Err("doc budget root is not a directory: " + root)
  }
  let paths : Array[String] = []
  collect_markdown_files(disk_root, root, excluded, paths)
  paths.sort_by((left, right) => left.lexical_compare(right))
  let files : Array[DocFile] = []
  for path in paths {
    let text = match
      @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    files.push({ path, lines: count_lines(text), })
  }
  Ok(files)
}

///|
fn measure_roots(
  repo_root : String,
  catalog : DocBudgetCatalog,
) -> Result[Array[DocFile], Array[String]] {
  let files : Array[DocFile] = []
  let failures : Array[String] = []
  for root in catalog.roots {
    match measure_root(repo_root, root, catalog.excluded) {
      Ok(root_files) =>
        for file in root_files {
          files.push(file)
        }
      Err(message) => failures.push(message)
    }
  }
  if failures.is_empty() {
    Ok(files)
  } else {
    Err(failures)
  }
}

///|
fn total_lines(files : Array[DocFile]) -> Int32 {
  let mut total = 0
  for file in files {
    total = total + file.lines
  }
  total
}

///|
fn largest_files(files : Array[DocFile], limit : Int32) -> Array[DocFile] {
  let ranked : Array[DocFile] = []
  for file in files {
    ranked.push(file)
  }
  ranked.sort_by((left, right) => {
    if left.lines > right.lines {
      -1
    } else if left.lines < right.lines {
      1
    } else {
      left.path.lexical_compare(right.path)
    }
  })
  let out : Array[DocFile] = []
  let mut index = 0
  while index < ranked.length() && index < limit {
    out.push(ranked[index])
    index = index + 1
  }
  out
}

///|
fn budget_failures(
  files : Array[DocFile],
  catalog : DocBudgetCatalog,
) -> Array[String] {
  let total = total_lines(files)
  if total <= catalog.max_lines {
    return []
  }
  let failures : Array[String] = [
    "doc budget exceeded: " +
    total.to_string() +
    " lines > ceiling " +
    catalog.max_lines.to_string() +
    " (over by " +
    (total - catalog.max_lines).to_string() +
    ")",
  ]
  failures.push(
    "the ceiling is a ratchet: cut documentation, do not raise checks/doc-budget.json",
  )
  for file in largest_files(files, 12) {
    failures.push("  " + file.path + ": " + file.lines.to_string() + " lines")
  }
  failures
}

///|
fn run_checks(repo_root : String) -> Result[String, Array[String]] {
  let catalog = match load_catalog(repo_root) {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let files = match measure_roots(repo_root, catalog) {
    Ok(value) => value
    Err(messages) => return Err(messages)
  }
  let failures = budget_failures(files, catalog)
  if !failures.is_empty() {
    return Err(failures)
  }
  Ok(
    "doc budget: ok (" +
    total_lines(files).to_string() +
    " lines across " +
    files.length().to_string() +
    " Markdown files under " +
    @tools.comma_join(catalog.roots) +
    ", ceiling " +
    catalog.max_lines.to_string() +
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
        Err(failures) => {
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
