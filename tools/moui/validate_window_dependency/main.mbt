///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct ConsumerText {
  path : String
  text : String?
}

///|
struct ConsumerVersions {
  path : String
  versions : Array[String]
}

///|
struct ValidationResult {
  errors : Array[String]
  pinned : String
  uses_provider_phase_e_local_window : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_window_dependency [options]
    #|
    #|Checks that wzzc-dev/window resolves from mooncakes.io and that every
    #|repository-owned moon.mod consumer pins the same published version.
    #|
    #|Enforces docs/invariants.md R4 (no local window modules in moon.work) and A6
    #|(shared pin across every dynamically discovered consumer).
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
fn skipped_scan_directory(name : String) -> Bool {
  name == ".git" ||
  name == ".mooncakes" ||
  name == "_build" ||
  name == "artifacts" ||
  name == "node_modules" ||
  name == "output" ||
  name == "window"
}

///|
fn collect_moon_mod_paths(
  repo_root : String,
  relative_dir : String,
  paths : Array[String],
  errors : Array[String],
) -> Unit {
  let absolute_dir = if relative_dir == "" {
    repo_root
  } else {
    @tools.resolve_path(repo_root, relative_dir)
  }
  let entries : Array[String] = @fs.read_dir(absolute_dir) catch {
    _ => {
      errors.push(
        "directory could not be read while scanning moon.mod: " + absolute_dir,
      )
      return
    }
  }
  entries.sort()
  for entry in entries {
    let relative = if relative_dir == "" {
      entry
    } else {
      relative_dir + "/" + entry
    }
    let absolute = @tools.resolve_path(repo_root, relative)
    if @tools.directory_exists(absolute) {
      if !skipped_scan_directory(entry) {
        collect_moon_mod_paths(repo_root, relative, paths, errors)
      }
    } else if entry == "moon.mod" && @tools.file_exists(absolute) {
      paths.push(relative)
    }
  }
}

///|
fn discover_window_consumers(
  repo_root : String,
) -> (Array[ConsumerText], Array[String]) {
  let paths : Array[String] = []
  let errors : Array[String] = []
  collect_moon_mod_paths(repo_root, "", paths, errors)
  let consumers : Array[ConsumerText] = []
  for path in paths {
    match read_optional_text(repo_root, path) {
      Some(text) if text.contains("\"wzzc-dev/window@") =>
        consumers.push({ path, text: Some(text) })
      Some(_) => ()
      None => errors.push("missing file after discovery: " + path)
    }
  }
  (consumers, errors)
}

///|
fn count_window_workspace_members(work : String) -> Int {
  let mut count = 0
  for line in work.split("\n") {
    let workspace_entry = line.trim().to_owned()
    if workspace_entry == "\"./window\"," ||
      workspace_entry == "\"./window/modules/window\"," ||
      workspace_entry == "\"./window/modules/windowing\"," {
      count += 1
    }
  }
  count
}

///|
let provider_phase_e_local_window_exception = "provider-phase-e-local-window"

///|
fn has_provider_phase_e_local_window_exception(exception : String?) -> Bool {
  match exception {
    Some(value) => value.trim() == provider_phase_e_local_window_exception
    None => false
  }
}

///|
fn is_provider_phase_e_local_window_exception(
  work : String,
  exception : String?,
) -> Bool {
  if !has_provider_phase_e_local_window_exception(exception) ||
    count_window_workspace_members(work) != 2 {
    return false
  }
  let mut has_window = false
  let mut has_windowing = false
  for line in work.split("\n") {
    match line.trim().to_owned() {
      "\"./window/modules/window\"," => has_window = true
      "\"./window/modules/windowing\"," => has_windowing = true
      _ => ()
    }
  }
  has_window && has_windowing
}

///|
fn extract_window_versions(text : String) -> Array[String] {
  let marker = "\"wzzc-dev/window@"
  let versions : Array[String] = []
  let mut cursor = 0
  while cursor < text.length() {
    let rest = text[cursor:]
    match rest.find(marker) {
      Some(relative_start) => {
        let version_start = cursor + relative_start + marker.length()
        let version_rest = text[version_start:]
        match version_rest.find("\"") {
          Some(relative_end) => {
            versions.push(
              text[version_start:version_start + relative_end].to_owned(),
            )
            cursor = version_start + relative_end + 1
          }
          None => cursor = text.length()
        }
      }
      None => cursor = text.length()
    }
  }
  versions
}

///|
fn array_contains(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn unique_strings(values : Array[String]) -> Array[String] {
  let unique : Array[String] = []
  for value in values {
    if !array_contains(unique, value) {
      unique.push(value)
    }
  }
  unique
}

///|
fn version_list(versions : Array[String]) -> String {
  @tools.comma_join(versions)
}

///|
fn mismatch_detail(entries : Array[ConsumerVersions]) -> String {
  let builder = StringBuilder()
  for index in 0..<entries.length() {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string("  - ")
    builder.write_string(entries[index].path)
    builder.write_string(": ")
    builder.write_string(version_list(entries[index].versions))
  }
  builder.to_string()
}

///|
fn validate_window_dependency_inputs(
  moon_work : String?,
  consumers : Array[ConsumerText],
  exception : String?,
) -> ValidationResult {
  let errors : Array[String] = []
  let versions_by_consumer : Array[ConsumerVersions] = []
  let all_versions : Array[String] = []
  let uses_provider_phase_e_local_window = Ref(false)
  match moon_work {
    Some(work) => {
      let member_count = count_window_workspace_members(work)
      let is_provider_phase_e_exception = is_provider_phase_e_local_window_exception(
        work, exception,
      )
      uses_provider_phase_e_local_window.val = is_provider_phase_e_exception
      if member_count > 0 && !is_provider_phase_e_exception {
        errors.push(
          "moon.work lists local window workspace member(s) (\{member_count} occurrence(s)).\n" +
          "  This shadows the published wzzc-dev/window dependency for all workspace consumers.\n" +
          "  Fix: run `sh scripts/window-dev-mode.sh off` to restore mooncakes.io resolution.\n" +
          "  The sole committed exception is checks/window-dependency-exception.txt plus both nested members.\n" +
          "  See: docs/invariants.md#R4",
        )
      } else if member_count == 0 &&
        has_provider_phase_e_local_window_exception(exception) {
        errors.push(
          "checks/window-dependency-exception.txt enables the Provider Phase E local-window exception without both local members.\n" +
          "  Fix: remove that file after `sh scripts/window-dev-mode.sh off`.\n" +
          "  See: docs/invariants.md#R4",
        )
      }
    }
    None => errors.push("missing file: moon.work")
  }
  for consumer in consumers {
    match consumer.text {
      Some(text) => {
        let versions = extract_window_versions(text)
        if versions.is_empty() {
          errors.push(
            consumer.path +
            ": expected a \"wzzc-dev/window@<version>\" declaration but found none.\n" +
            "  Fix: restore a versioned import or remove the incomplete window dependency declaration.\n" +
            "  See: docs/invariants.md#A6",
          )
        } else {
          versions_by_consumer.push({ path: consumer.path, versions })
          for version in versions {
            all_versions.push(version)
          }
          if unique_strings(versions).length() > 1 {
            errors.push(
              consumer.path +
              ": declares wzzc-dev/window at multiple versions: " +
              version_list(versions) +
              ".\n  Fix: pin exactly one window version in this moon.mod.\n" +
              "  See: docs/invariants.md#A6",
            )
          }
        }
      }
      None => errors.push("missing file: " + consumer.path)
    }
  }
  let unique_versions = unique_strings(all_versions)
  if unique_versions.length() > 1 {
    errors.push(
      "wzzc-dev/window version mismatch across consumers:\n" +
      mismatch_detail(versions_by_consumer) +
      "\n  Fix: align every listed consumer to one published version, then run `moon update`.\n" +
      "  See: docs/invariants.md#A6",
    )
  }
  let pinned = if unique_versions.length() == 1 {
    unique_versions[0]
  } else {
    "(none)"
  }
  {
    errors,
    pinned,
    uses_provider_phase_e_local_window: uses_provider_phase_e_local_window.val,
  }
}

///|
fn read_optional_text(repo_root : String, path : String) -> String? {
  match @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn validate_window_dependency(repo_root : String) -> ValidationResult {
  let (consumers, discovery_errors) = discover_window_consumers(repo_root)
  let result = validate_window_dependency_inputs(
    read_optional_text(repo_root, "moon.work"),
    consumers,
    read_optional_text(repo_root, "checks/window-dependency-exception.txt"),
  )
  for error in discovery_errors {
    result.errors.push(error)
  }
  if consumers.is_empty() {
    result.errors.push(
      "no repository-owned moon.mod declares wzzc-dev/window; dependency scan is unexpectedly empty",
    )
  }
  result
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let result = validate_window_dependency(options.repo_root)
      if result.errors.is_empty() {
        let resolution_mode = if result.uses_provider_phase_e_local_window {
          "Provider Phase E local-window exception"
        } else {
          "mooncakes mode"
        }
        println(
          "validate-window-dependency: OK (" +
          resolution_mode +
          ", wzzc-dev/window@" +
          result.pinned +
          ")",
        )
        0
      } else {
        println("validate-window-dependency: FAIL")
        for error in result.errors {
          println("\n" + error)
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
