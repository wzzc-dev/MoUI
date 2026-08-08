///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_release_module_closures [--repo-root PATH]
    #|
    #|Validates the release-module catalog, module dependency direction, and
    #|the base/renderer/test dependency-closure invariants.
    #|
  )
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
fn read_text(repo_root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(repo_root, path), path)
}

///|
fn duplicate_values(values : Array[String]) -> Array[String] {
  let duplicates : Array[String] = []
  for index, value in values {
    if values[index + 1:].contains(value) && !duplicates.contains(value) {
      duplicates.push(value)
    }
  }
  duplicates
}

///|
fn validate_catalog_shape(
  repo_root : String,
  catalog : ReleaseCatalog,
  failures : Array[String],
) -> Unit {
  let names = catalog.modules.map(entry => entry.name)
  let directories = catalog.modules.map(entry => entry.directory)
  for duplicate in duplicate_values(names) {
    failures.push(
      "release catalog contains duplicate module name: " + duplicate,
    )
  }
  for duplicate in duplicate_values(directories) {
    failures.push("release catalog contains duplicate directory: " + duplicate)
  }
  for entry in catalog.modules {
    let label = "release module " + entry.name
    if entry.name == "" || entry.directory == "" {
      continue
    }
    let manifest_path = entry.directory + "/moon.mod"
    let manifest_text = match read_text(repo_root, manifest_path) {
      Ok(text) => text
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    let manifest = parse_module_manifest(manifest_text)
    if manifest.name != entry.name {
      failures.push(
        label + " name does not match " + manifest_path + ": " + manifest.name,
      )
    }
    if entry.publication != "public" && entry.publication != "internal" {
      failures.push(label + " publication must be public or internal")
    }
    if entry.publication == "public" {
      if entry.release_stage == "" ||
        release_stage_index(catalog, entry.release_stage) < 0 {
        failures.push(label + " has an unknown releaseStage")
      }
      if manifest.version == "" {
        failures.push(label + " must declare a version")
      }
    }
    if entry.publication == "internal" &&
      entry.role == "tests" &&
      manifest.version != "" {
      failures.push(label + " test module must not declare a version")
    }
    if !@tools.directory_exists(@tools.resolve_path(repo_root, entry.directory)) {
      failures.push(label + " directory does not exist: " + entry.directory)
    }
  }
}

///|
fn base_forbidden_tokens() -> Array[String] {
  [
    "wzzc-dev/moui_skia_renderer", "wzzc-dev/moui_web_renderer", "wzzc-dev/moui_wgpu_renderer",
    "wzzc-dev/moui_sun_renderer", "wzzc-dev/moui_skia", "wzzc-dev/moui_sun", "Milky2018/wgpu_mbt",
    "Milky2018/moon_cosmic", "Milky2018/moon_swash", "mizchi/image", "moonbitlang/quickcheck",
    "mizchi/pixelmatch",
  ]
}

///|
fn validate_base_closure(repo_root : String, failures : Array[String]) -> Unit {
  let paths = ["moui/moon.mod", "moui/build.js"]
  for path in paths {
    match read_text(repo_root, path) {
      Ok(text) =>
        for token in base_forbidden_tokens() {
          if text.contains(token) {
            failures.push(
              path + ": base closure contains forbidden token '" + token + "'",
            )
          }
        }
      Err(message) => failures.push(message)
    }
  }
  for
    stale in [
      "moui/render/skia", "moui/render/webgpu_adapter", "moui/render/wgpu", "moui/render/sun",
      "moui/tests",
    ] {
    if @tools.directory_exists(@tools.resolve_path(repo_root, stale)) {
      failures.push("base archive still contains extracted directory: " + stale)
    }
  }
}

///|
fn validate_renderer_closure(
  catalog : ReleaseCatalog,
  entry : ReleaseModule,
  manifest : ModuleManifest,
  failures : Array[String],
) -> Unit {
  if entry.role != "renderer" {
    return
  }
  let base = catalog_module(catalog, "wzzc-dev/moui")
  if base is None || !manifest.imports.any(item => item.0 == "wzzc-dev/moui") {
    failures.push(entry.name + " must depend directly on wzzc-dev/moui")
  }
  for dependency in manifest.imports {
    match catalog_module(catalog, dependency.0) {
      Some(target) if target.role == "renderer" =>
        failures.push(
          entry.name +
          " may not depend on another renderer module: " +
          dependency.0,
        )
      _ => ()
    }
  }
}

///|
fn validate_internal_tests(
  repo_root : String,
  catalog : ReleaseCatalog,
  failures : Array[String],
) -> Unit {
  match catalog_module(catalog, "wzzc-dev/moui_tester") {
    Some(_) =>
      failures.push(
        "wzzc-dev/moui_tester must not be a release module; tester harnesses belong in moui_tests/tester",
      )
    None => ()
  }
  match catalog_module(catalog, "wzzc-dev/moui_tests") {
    Some(entry) =>
      if entry.publication != "internal" || entry.role != "tests" {
        failures.push(
          "wzzc-dev/moui_tests must be cataloged as the internal tests module",
        )
      }
    None => failures.push("release catalog is missing wzzc-dev/moui_tests")
  }
  match read_text(repo_root, "moui_tests/moon.mod") {
    Ok(text) => {
      if !text.contains("name = \"wzzc-dev/moui_tests\"") {
        failures.push(
          "moui_tests/moon.mod must name the unpublished wzzc-dev/moui_tests module",
        )
      }
      if text.contains("wzzc-dev/moui_tester") {
        failures.push(
          "moui_tests/moon.mod must not depend on the removed wzzc-dev/moui_tester module",
        )
      }
    }
    Err(message) => failures.push(message)
  }
}

///|
fn validate_dependency_direction(
  catalog : ReleaseCatalog,
  entry : ReleaseModule,
  manifest : ModuleManifest,
  failures : Array[String],
) -> Unit {
  let source_stage = release_stage_index(catalog, entry.release_stage)
  for dependency in manifest.imports {
    match catalog_module(catalog, dependency.0) {
      Some(target) if target.publication == "public" => {
        let target_stage = release_stage_index(catalog, target.release_stage)
        if source_stage >= 0 && target_stage > source_stage {
          failures.push(
            entry.name + " depends on a later release stage: " + dependency.0,
          )
        }
      }
      _ => ()
    }
  }
}

///|
fn validate_catalog_modules(
  repo_root : String,
  catalog : ReleaseCatalog,
  failures : Array[String],
) -> Map[String, String] {
  let versions : Map[String, String] = Map([])
  for entry in catalog.modules {
    match read_text(repo_root, entry.directory + "/moon.mod") {
      Ok(text) => {
        let manifest = parse_module_manifest(text)
        if manifest.version != "" {
          versions[entry.name] = manifest.version
        }
        validate_renderer_closure(catalog, entry, manifest, failures)
        validate_dependency_direction(catalog, entry, manifest, failures)
      }
      Err(message) => failures.push(message)
    }
  }
  versions
}

///|
fn workspace_members(
  repo_root : String,
  failures : Array[String],
) -> Array[String] {
  let members : Array[String] = []
  let text = match read_text(repo_root, "moon.work") {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return members
    }
  }
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if line.has_prefix("\"./") {
      match first_quoted(line) {
        Some(value) => members.push(value[2:].to_owned())
        None => ()
      }
    }
  }
  members
}

///|
fn validate_workspace_pins(
  repo_root : String,
  versions : Map[String, String],
  failures : Array[String],
) -> Unit {
  for directory in workspace_members(repo_root, failures) {
    let path = directory + "/moon.mod"
    let text = match read_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    let manifest = parse_module_manifest(text)
    for dependency in manifest.imports {
      match versions.get(dependency.0) {
        Some(expected) if dependency.1 != expected =>
          failures.push(
            path +
            " pins " +
            dependency.0 +
            "@" +
            dependency.1 +
            " but workspace manifest is at " +
            expected,
          )
        _ => ()
      }
    }
  }
}

///|
fn run_checks(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  let text = match read_text(repo_root, "checks/release-modules.json") {
    Ok(value) => value
    Err(message) => return [message]
  }
  let catalog = match parse_catalog(text) {
    Ok(value) => value
    Err(messages) => return messages
  }
  validate_catalog_shape(repo_root, catalog, failures)
  validate_base_closure(repo_root, failures)
  validate_internal_tests(repo_root, catalog, failures)
  let versions = validate_catalog_modules(repo_root, catalog, failures)
  validate_workspace_pins(repo_root, versions, failures)
  failures
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let failures = run_checks(options.repo_root)
      if failures.is_empty() {
        println("release module dependency closures: ok")
        0
      } else {
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
