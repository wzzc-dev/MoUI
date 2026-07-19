///|
struct M5Finding {
  rule : String
  ok : Bool
  path : String
  hint : String
}

///|
struct M5Result {
  findings : Array[M5Finding]
  ets_file_count : Int
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_harmonyos_shell [--repo-root PATH] [--json]
    #|
    #|Validates the HarmonyOS managed shell M5 contract (XComponent-only surface/pointer).
    #|
  )
}

///|
fn template_root_rel() -> String {
  "moui_shell/harmonyos/runner/template"
}

///|
fn root_ets_rel() -> String {
  "moui_shell/harmonyos/runner/template/entry/src/main/ets/moui/MoUIRoot.ets"
}

///|
fn bridge_rel() -> String {
  "moui_shell/harmonyos/embedder/src/main/cpp/moui_embedding_harmonyos_napi.cpp"
}

///|
fn forbidden_in_template_ets() -> Array[String] {
  [
    ".onTouch", "onAreaChange", "attachSurface", "dispatchPointer", "detachSurface",
  ]
}

///|
fn required_in_root() -> Array[String] {
  ["libraryname: 'moui_embedding_harmonyos'", "XComponent", "displaySync"]
}

///|
fn required_in_bridge() -> Array[String] {
  ["OH_NativeXComponent_RegisterCallback", "source=native-xcomponent"]
}

///|
fn forbidden_in_bridge() -> Array[String] {
  [
    "napi_attach_surface", "napi_dispatch_pointer", "napi_resize", "MOUI_EMBEDDING_ATTACH_SURFACE",
  ]
}

///|
fn failure(path : String, hint : String) -> M5Finding {
  { rule: "M5", ok: false, path, hint }
}

///|
fn skipped_directory(name : String) -> Bool {
  name == ".git" ||
  name == "node_modules" ||
  name == "_build" ||
  name == "build" ||
  name == "target" ||
  name == ".hvigor" ||
  name == "oh_modules"
}

///|
fn collect_ets_files(
  repo_root : String,
  relative_path : String,
  files : Array[String],
  failures : Array[M5Finding],
) -> Unit {
  let absolute = @tools.resolve_path(repo_root, relative_path)
  if @tools.directory_exists(absolute) {
    let entries : Array[String] = @fs.read_dir(absolute) catch {
      _ => {
        failures.push(
          failure(
            relative_path, "directory could not be read. Fix: restore managed shell template. See docs/invariants.md#M5",
          ),
        )
        return
      }
    }
    entries.sort_by((left, right) => left.lexical_compare(right))
    for entry in entries {
      if !skipped_directory(entry) {
        collect_ets_files(
          repo_root,
          relative_path + "/" + entry,
          files,
          failures,
        )
      }
    }
  } else if @tools.file_exists(absolute) && relative_path.has_suffix(".ets") {
    files.push(relative_path)
  }
}

///|
fn validate_root_text(path : String, root : String) -> Array[M5Finding] {
  let findings : Array[M5Finding] = []
  for token in required_in_root() {
    if !root.contains(token) {
      findings.push(
        failure(
          path,
          "missing required token " +
          Json::string(token).stringify() +
          ". Fix: keep XComponent + displaySync managed shell. See docs/invariants.md#M5",
        ),
      )
    }
  }
  findings
}

///|
fn validate_template_text(path : String, text : String) -> Array[M5Finding] {
  let findings : Array[M5Finding] = []
  for token in forbidden_in_template_ets() {
    if text.contains(token) {
      findings.push(
        failure(
          path,
          "forbidden " +
          Json::string(token).stringify() +
          ". Fix: use native XComponent callbacks only for surface/pointer/resize/detach; do not restore ArkTS .onTouch paths. See docs/invariants.md#M5",
        ),
      )
    }
  }
  findings
}

///|
fn validate_bridge_text(path : String, bridge : String) -> Array[M5Finding] {
  let findings : Array[M5Finding] = []
  for token in required_in_bridge() {
    if !bridge.contains(token) {
      findings.push(
        failure(
          path,
          "missing required token " +
          Json::string(token).stringify() +
          ". Fix: register OH_NativeXComponent callbacks and log source=native-xcomponent. See docs/invariants.md#M5",
        ),
      )
    }
  }
  for token in forbidden_in_bridge() {
    if bridge.contains(token) {
      findings.push(
        failure(
          path,
          "forbidden " +
          Json::string(token).stringify() +
          ". Fix: do not reintroduce JS-driven attach/pointer/resize NAPI entrypoints. See docs/invariants.md#M5",
        ),
      )
    }
  }
  findings
}

///|
fn validate_repo(repo_root : String) -> M5Result {
  let findings : Array[M5Finding] = []
  let root_path = root_ets_rel()
  match
    @tools.read_required_text(
      @tools.resolve_path(repo_root, root_path),
      root_path,
    ) {
    Ok(root) =>
      for item in validate_root_text(root_path, root) {
        findings.push(item)
      }
    Err(message) =>
      findings.push(
        failure(
          root_path,
          "missing canonical shell root: " +
          message +
          ". Fix: restore managed shell template. See docs/invariants.md#M5",
        ),
      )
  }
  let ets_files : Array[String] = []
  collect_ets_files(repo_root, template_root_rel(), ets_files, findings)
  if ets_files.is_empty() {
    findings.push(
      failure(
        template_root_rel(),
        "no .ets files under managed shell template. Fix: restore moui_shell/harmonyos/runner/template. See docs/invariants.md#M5",
      ),
    )
  }
  for path in ets_files {
    match
      @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
      Ok(text) =>
        for item in validate_template_text(path, text) {
          findings.push(item)
        }
      Err(message) =>
        findings.push(failure(path, "could not read template file: " + message))
    }
  }
  let bridge_path = bridge_rel()
  match
    @tools.read_required_text(
      @tools.resolve_path(repo_root, bridge_path),
      bridge_path,
    ) {
    Ok(bridge) =>
      for item in validate_bridge_text(bridge_path, bridge) {
        findings.push(item)
      }
    Err(message) =>
      findings.push(
        failure(
          bridge_path,
          "missing NAPI bridge: " + message + ". See docs/invariants.md#M5",
        ),
      )
  }
  { findings, ets_file_count: ets_files.length() }
}

///|
fn finding_to_json(finding : M5Finding) -> Json {
  let object : Map[String, Json] = Map([])
  object["rule"] = Json::string(finding.rule)
  object["ok"] = Json::boolean(finding.ok)
  object["path"] = Json::string(finding.path)
  object["hint"] = Json::string(finding.hint)
  Json::object(object)
}

///|
fn result_to_json(result : M5Result) -> Json {
  let report = if result.findings.is_empty() {
    [{ rule: "M5", ok: true, path: "moui_shell/harmonyos", hint: "" }]
  } else {
    result.findings
  }
  let failures = report.filter(item => !item.ok)
  let object : Map[String, Json] = Map([])
  object["schemaVersion"] = Json::number(1.0, repr="1")
  object["failures"] = Json::array(failures.map(finding_to_json))
  object["results"] = Json::array(report.map(finding_to_json))
  Json::object(object)
}

///|
struct CliOptions {
  repo_root : String
  json : Bool
  help : Bool
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut repo_root = @env.current_dir().unwrap_or("")
  let mut json = false
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--json" => {
        json = true
        index += 1
      }
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  Ok({ repo_root, json, help })
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
      let result = validate_repo(options.repo_root)
      if options.json {
        println(result_to_json(result).stringify(indent=2))
      } else if result.findings.is_empty() {
        println(
          "validate-harmonyos-shell: OK (scanned " +
          result.ets_file_count.to_string() +
          " template .ets file(s); XComponent-only contract)",
        )
      } else {
        println("validate-harmonyos-shell: FAIL")
        for item in result.findings {
          println("")
          println("[" + item.rule + "] " + item.path)
          println("  " + item.hint)
        }
      }
      if result.findings.is_empty() {
        0
      } else {
        1
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
