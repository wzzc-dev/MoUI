///|
suberror SourcePolicyError {
  Invalid(String)
} derive(Eq, Debug)

///|
struct PolicyEntry {
  path : String
  classification : String
  max_lines : Int
  reason : String
  generator : String
  check_command : String
  header : String
}

///|
struct SourcePolicy {
  roots : Array[String]
  extensions : Array[String]
  review_lines : Int
  hard_limit_lines : Int
  entries : Array[PolicyEntry]
}

///|
struct PolicyResult {
  file_count : Int
  review_paths : Array[String]
  failures : Array[String]
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_source_file_policy [--repo-root PATH]
    #|
    #|Validates first-party source files against checks/source-file-policy.json.
    #|
  )
}

///|
fn json_object(
  value : Json,
  label : String,
) -> Map[String, Json] raise SourcePolicyError {
  match value {
    Json::Object(fields) => fields
    _ => raise SourcePolicyError::Invalid(label + " must be an object")
  }
}

///|
fn json_array(
  value : Json?,
  label : String,
) -> Array[Json] raise SourcePolicyError {
  match value {
    Some(Json::Array(values)) => values
    _ => raise SourcePolicyError::Invalid(label + " must be an array")
  }
}

///|
fn json_string(value : Json?, label : String) -> String raise SourcePolicyError {
  match value {
    Some(Json::String(text)) if text.trim().to_owned() != "" => text
    _ => raise SourcePolicyError::Invalid(label + " must be a non-empty string")
  }
}

///|
fn json_int(value : Json?, label : String) -> Int raise SourcePolicyError {
  match value {
    Some(Json::Number(number, repr=_)) => number.to_int()
    _ => raise SourcePolicyError::Invalid(label + " must be a number")
  }
}

///|
fn read_json(repo_root : String, path : String) -> Json raise SourcePolicyError {
  let text = match
    @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
    Ok(value) => value
    Err(message) => raise SourcePolicyError::Invalid(message)
  }
  @json.parse(text) catch {
    _ => raise SourcePolicyError::Invalid(path + " contains invalid JSON")
  }
}

///|
fn string_array(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Array[String] raise SourcePolicyError {
  let result : Array[String] = []
  for index, value in json_array(fields.get(key), label + "." + key) {
    result.push(json_string(Some(value), label + "." + key + "[\{index}]"))
  }
  result
}

///|
fn parse_entry(
  value : Json,
  classification : String,
  label : String,
) -> PolicyEntry raise SourcePolicyError {
  let fields = json_object(value, label)
  {
    path: json_string(fields.get("path"), label + ".path"),
    classification,
    max_lines: json_int(fields.get("maxLines"), label + ".maxLines"),
    reason: match fields.get("reason") {
      Some(Json::String(value)) => value
      _ => ""
    },
    generator: match fields.get("generator") {
      Some(Json::String(value)) => value
      _ => ""
    },
    check_command: match fields.get("checkCommand") {
      Some(Json::String(value)) => value
      _ => ""
    },
    header: match fields.get("header") {
      Some(Json::String(value)) => value
      _ => ""
    },
  }
}

///|
fn append_entries(
  target : Array[PolicyEntry],
  fields : Map[String, Json],
  key : String,
  classification : String,
  label : String,
) -> Unit raise SourcePolicyError {
  for index, value in json_array(fields.get(key), label + "." + key) {
    target.push(
      parse_entry(value, classification, label + "." + key + "[\{index}]"),
    )
  }
}

///|
fn load_policy(repo_root : String) -> SourcePolicy raise SourcePolicyError {
  let path = "checks/source-file-policy.json"
  let fields = json_object(read_json(repo_root, path), path)
  if json_int(fields.get("schemaVersion"), path + ".schemaVersion") != 1 {
    raise SourcePolicyError::Invalid(path + ".schemaVersion must be 1")
  }
  let logic = match fields.get("logic") {
    Some(value) => json_object(value, path + ".logic")
    None => raise SourcePolicyError::Invalid(path + ".logic must be an object")
  }
  let entries : Array[PolicyEntry] = []
  append_entries(entries, fields, "ratchets", "logic", path)
  append_entries(entries, fields, "data", "data", path)
  append_entries(entries, fields, "generated", "generated", path)
  {
    roots: string_array(fields, "roots", path),
    extensions: string_array(fields, "extensions", path),
    review_lines: json_int(
      logic.get("reviewLines"),
      path + ".logic.reviewLines",
    ),
    hard_limit_lines: json_int(
      logic.get("hardLimitLines"),
      path + ".logic.hardLimitLines",
    ),
    entries,
  }
}

///|
fn skipped_directory(name : String) -> Bool {
  name == ".git" ||
  name == ".mooncakes" ||
  name == ".skia-cache" ||
  name == "_build" ||
  name == "artifacts" ||
  name == "dist" ||
  name == "node_modules" ||
  name == "output"
}

///|
fn repository_relative_path(path : String) -> Bool {
  path != "" &&
  !path.has_prefix("/") &&
  !path.has_prefix("\\") &&
  !path.contains("\\") &&
  !path.contains(":") &&
  path != ".." &&
  !path.has_prefix("../") &&
  !path.has_suffix("/..") &&
  !path.contains("/../")
}

///|
fn has_source_extension(path : String, extensions : Array[String]) -> Bool {
  extensions.any(extension => path.has_suffix(extension))
}

///|
fn collect_source_files(
  repo_root : String,
  relative_path : String,
  extensions : Array[String],
  files : Array[String],
) -> Unit raise SourcePolicyError {
  let absolute = @tools.resolve_path(repo_root, relative_path)
  if @tools.directory_exists(absolute) {
    let entries : Array[String] = @fs.read_dir(absolute) catch {
      _ =>
        raise SourcePolicyError::Invalid(relative_path + " could not be read")
    }
    entries.sort_by((left, right) => left.lexical_compare(right))
    for entry in entries {
      if !skipped_directory(entry) {
        collect_source_files(
          repo_root,
          relative_path + "/" + entry,
          extensions,
          files,
        )
      }
    }
  } else if @tools.file_exists(absolute) &&
    has_source_extension(relative_path, extensions) {
    files.push(relative_path)
  }
}

///|
fn source_line_count(text : String) -> Int {
  if text == "" {
    return 0
  }
  let mut lines = 1
  for byte in text {
    if byte == '\n' {
      lines += 1
    }
  }
  if text.has_suffix("\n") {
    lines - 1
  } else {
    lines
  }
}

///|
fn entry_for_path(entries : Array[PolicyEntry], path : String) -> PolicyEntry? {
  for entry in entries {
    if entry.path == path {
      return Some(entry)
    }
  }
  None
}

///|
fn unregistered_logic_classification(
  lines : Int,
  review_lines : Int,
  hard_limit_lines : Int,
) -> String {
  if lines > hard_limit_lines {
    "hard-limit"
  } else if lines >= review_lines {
    "review"
  } else {
    "ok"
  }
}

///|
fn validate_policy(repo_root : String, policy : SourcePolicy) -> PolicyResult {
  let failures : Array[String] = []
  let review_paths : Array[String] = []
  if policy.review_lines <= 0 || policy.hard_limit_lines <= policy.review_lines {
    failures.push(
      "logic thresholds must satisfy 0 < reviewLines < hardLimitLines",
    )
  }
  for index, root in policy.roots {
    if policy.roots[:index].contains(root) {
      failures.push("duplicate source policy root: " + root)
    }
    if !repository_relative_path(root) {
      failures.push("source policy root must be repository-relative: " + root)
    } else if !@tools.directory_exists(@tools.resolve_path(repo_root, root)) {
      failures.push("source policy root is missing: " + root)
    }
  }
  for index, extension in policy.extensions {
    if policy.extensions[:index].contains(extension) {
      failures.push("duplicate source policy extension: " + extension)
    }
    if !extension.has_prefix(".") || extension.length() < 2 {
      failures.push("invalid source policy extension: " + extension)
    }
  }
  for index, entry in policy.entries {
    if policy.entries[:index].any(previous => previous.path == entry.path) {
      failures.push("duplicate source policy entry: " + entry.path)
    }
    if entry.max_lines <= 0 {
      failures.push(entry.path + ": maxLines must be positive")
    }
    if !repository_relative_path(entry.path) {
      failures.push(
        "source policy entry must be repository-relative: " + entry.path,
      )
    }
    if !has_source_extension(entry.path, policy.extensions) {
      failures.push(
        entry.path + ": source policy entry has an uncovered extension",
      )
    }
    if entry.classification == "logic" &&
      entry.max_lines <= policy.hard_limit_lines {
      failures.push(
        entry.path + ": logic ratchets are only valid above hardLimitLines",
      )
    }
    if entry.classification != "generated" && entry.reason == "" {
      failures.push(entry.path + ": classified source requires a reason")
    }
    if entry.classification == "generated" &&
      (entry.generator == "" || entry.check_command == "" || entry.header == "") {
      failures.push(
        entry.path +
        ": generated source requires generator, checkCommand, and header",
      )
    }
    if entry.classification == "generated" &&
      repository_relative_path(entry.generator) &&
      !@tools.file_exists(@tools.resolve_path(repo_root, entry.generator)) {
      failures.push(entry.path + ": declared generator is missing")
    }
    if entry.classification == "generated" &&
      entry.generator != "" &&
      !entry.check_command.contains(entry.generator) {
      failures.push(
        entry.path + ": checkCommand must invoke the declared generator",
      )
    }
  }
  let files : Array[String] = []
  for root in policy.roots {
    collect_source_files(repo_root, root, policy.extensions, files) catch {
      SourcePolicyError::Invalid(message) => failures.push(message)
    }
  }
  for entry in policy.entries {
    if !files.contains(entry.path) {
      failures.push(
        "source policy entry is missing or outside roots: " + entry.path,
      )
    }
  }
  for path in files {
    let text = match
      @tools.read_required_text(
        @tools.resolve_path(repo_root, path),
        "source file",
      ) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    let lines = source_line_count(text)
    match entry_for_path(policy.entries, path) {
      Some(entry) => {
        if lines > entry.max_lines {
          failures.push(
            path +
            ": \{entry.classification} lines=\{lines} exceeds registered budget \{entry.max_lines}",
          )
        }
        if entry.classification == "logic" && lines < entry.max_lines {
          failures.push(
            path +
            ": logic ratchet can lower from \{entry.max_lines} to \{lines}",
          )
        }
        if entry.classification == "generated" && !text.contains(entry.header) {
          failures.push(path + ": generated header is missing")
        }
      }
      None =>
        match
          unregistered_logic_classification(
            lines,
            policy.review_lines,
            policy.hard_limit_lines,
          ) {
          "hard-limit" =>
            failures.push(
              path +
              ": logic lines=\{lines} exceeds new-file hard limit \{policy.hard_limit_lines}; classify data/generated or register an existing ratchet",
            )
          "review" => review_paths.push(path + " (\{lines})")
          _ => ()
        }
    }
  }
  review_paths.sort_by((left, right) => left.lexical_compare(right))
  { file_count: files.length(), review_paths, failures }
}

///|
fn run(args : Array[String]) -> Int {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          println("missing value for --repo-root")
          return 2
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        println(usage())
        return 0
      }
      other => {
        println("unknown argument: " + other)
        return 2
      }
    }
  }
  let policy = load_policy(repo_root.val) catch {
    SourcePolicyError::Invalid(message) => {
      println(message)
      return 2
    }
  }
  let result = validate_policy(repo_root.val, policy)
  if !result.failures.is_empty() {
    for failure in result.failures {
      println(failure)
    }
    1
  } else {
    println(
      "source file policy: files=\{result.file_count} review=\{result.review_paths.length()} ratchets=\{policy.entries.length()}",
    )
    if !result.review_paths.is_empty() {
      println("source file review queue: " + result.review_paths.join(", "))
    }
    0
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
