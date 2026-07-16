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
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_window_dependency [options]
    #|
    #|Checks that wzzc-dev/window resolves from mooncakes.io and that every
    #|known consumer pins the same published version.
    #|
    #|Enforces docs/invariants.md R4 (no ./window in moon.work) and A6
    #|(shared pin across moui, moui_skia, moui_webview, markdown_editor).
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
fn expected_window_consumers() -> Array[String] {
  [
    "moui/moon.mod", "moui_skia/moon.mod", "moui_webview/moon.mod", "examples/markdown_editor/moon.mod",
  ]
}

///|
fn count_window_workspace_members(work : String) -> Int {
  let mut count = 0
  for line in work.split("\n") {
    if line.trim().to_owned() == "\"./window\"," {
      count += 1
    }
  }
  count
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
  let builder = StringBuilder::new()
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
) -> ValidationResult {
  let errors : Array[String] = []
  let versions_by_consumer : Array[ConsumerVersions] = []
  let all_versions : Array[String] = []
  match moon_work {
    Some(work) => {
      let member_count = count_window_workspace_members(work)
      if member_count > 0 {
        errors.push(
          "moon.work lists \"./window\" as a workspace member (\{member_count} occurrence(s)).\n" +
          "  This shadows the published wzzc-dev/window dependency for all workspace consumers.\n" +
          "  Fix: run `sh scripts/window-dev-mode.sh off` to restore mooncakes.io resolution.\n" +
          "  Local window edits belong in a dev-mode worktree, not on the main branch.\n" +
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
            "  Fix: restore the import, or remove this path from expected_window_consumers() if it no longer depends on window.\n" +
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
      "\n  Fix: align all four consumers to one published version, then run `moon update`.\n" +
      "  Consumers: moui/, moui_skia/, moui_webview/, examples/markdown_editor/.\n" +
      "  See: docs/invariants.md#A6",
    )
  }
  let pinned = if unique_versions.length() == 1 {
    unique_versions[0]
  } else {
    "(none)"
  }
  { errors, pinned }
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
  let consumers : Array[ConsumerText] = []
  for path in expected_window_consumers() {
    consumers.push({ path, text: read_optional_text(repo_root, path) })
  }
  validate_window_dependency_inputs(
    read_optional_text(repo_root, "moon.work"),
    consumers,
  )
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
        println(
          "validate-window-dependency: OK (mooncakes mode, wzzc-dev/window@" +
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
