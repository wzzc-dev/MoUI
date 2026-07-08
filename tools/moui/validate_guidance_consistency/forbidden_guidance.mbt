///|
fn forbidden_guidance_tokens() -> Array[String] {
  [
    "dev-check.sh", "dev_check.ps1", "conformance-check.sh", "--theme-diagnostics",
    "--platform-examples", "--text-diagnostic", "--platform-services", "--golden",
    "--bench", "--skia-real-smoke",
  ]
}

///|
fn legacy_workflow_guidance_tokens() -> Array[String] {
  [
    "moui-real-skia-smoke.yml", "moui-skia-real-skia-pr-smoke.yml", "moui-renderer-real-skia-ci-smoke.yml",
    "moui-macos-real-skia-smoke.yml", "moui-runtime-smoke-gates.yml", "moui-skia-fallback.yml",
    "moui-skia-macos-real-skia-smoke.yml", "moui-skia-linux-real-skia-smoke.yml",
    "moui-skia-windows-real-skia-smoke.yml", "moui-skia-real-skia-acceptance.yml",
    "MoUI Real Skia Smoke", "MoUI Skia Real-Skia Smoke", "MoUI Renderer Real Skia CI Smoke",
    "MoUI macOS Real Skia Smoke", "MoUI Runtime Smoke Gates", "MoUI Skia Fallback",
    "MoUI Skia macOS Real Skia Smoke", "MoUI Skia Linux Real Skia Smoke", "MoUI Skia Windows Real Skia Smoke",
    "MoUI Skia Real Skia Acceptance", "Platform Evidence Dispatch",
  ]
}

///|
fn historical_guidance_path(path : String) -> Bool {
  path.has_prefix("docs/ai-sessions/")
}

///|
fn guidance_scan_roots() -> Array[String] {
  [".github", "docs", "skills"]
}

///|
fn top_level_guidance_files() -> Array[String] {
  ["AGENTS.md", "README.md", "CONTRIBUTING.md", "GOVERNANCE.md"]
}

///|
fn guidance_scan_suffixes() -> Array[String] {
  [".md", ".yml", ".yaml"]
}

///|
fn path_has_any_suffix(path : String, suffixes : Array[String]) -> Bool {
  for suffix in suffixes {
    if path.has_suffix(suffix) {
      return true
    }
  }
  false
}

///|
fn guidance_scan_skipped_directory(name : String) -> Bool {
  name == ".git" ||
  name == "_build" ||
  name == "artifacts" ||
  name == ".mooncakes"
}

///|
fn read_dir_names(
  path : String,
  label : String,
) -> Result[Array[String], String] {
  if !@tools.directory_exists(path) {
    return Err(label + " is missing: " + path)
  }
  let entries : Array[String] = @fs.read_dir(path) catch {
    _ => return Err(label + " could not be read: " + path)
  }
  entries.sort()
  Ok(entries)
}

///|
fn collect_guidance_surface_files(
  repo_root : String,
  relative_dir : String,
  files : Array[String],
  failures : Array[String],
) -> Unit {
  let absolute_dir = @tools.resolve_path(repo_root, relative_dir)
  let entries = match read_dir_names(absolute_dir, relative_dir) {
    Ok(values) => values
    Err(message) => {
      failures.push(message)
      return
    }
  }
  let suffixes = guidance_scan_suffixes()
  for entry in entries {
    let relative = relative_dir + "/" + entry
    let absolute = @tools.resolve_path(repo_root, relative)
    if @tools.directory_exists(absolute) {
      if !guidance_scan_skipped_directory(entry) {
        collect_guidance_surface_files(repo_root, relative, files, failures)
      }
    } else if @tools.file_exists(absolute) &&
      path_has_any_suffix(relative, suffixes) {
      files.push(relative)
    }
  }
}

///|
fn guidance_surface_files(
  repo_root : String,
  failures : Array[String],
) -> Array[String] {
  let files : Array[String] = top_level_guidance_files()
  for root in guidance_scan_roots() {
    collect_guidance_surface_files(repo_root, root, files, failures)
  }
  files.sort()
  files
}

///|
fn forbidden_guidance_token_failures(
  path : String,
  text : String,
) -> Array[String] {
  let failures : Array[String] = []
  for token in forbidden_guidance_tokens() {
    if text.contains(token) {
      failures.push(
        path +
        ": deleted or legacy check token '" +
        token +
        "' must not be recommended; validator fixtures are the only allowed location for intentional negative tests",
      )
    }
  }
  if !historical_guidance_path(path) {
    for token in legacy_workflow_guidance_tokens() {
      if text.contains(token) {
        failures.push(
          path +
          ": legacy workflow name '" +
          token +
          "' must not be recommended; docs/ai-sessions history and validator fixtures are the only allowed locations",
        )
      }
    }
  }
  failures
}

///|
fn push_forbidden_guidance_token_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files = guidance_surface_files(repo_root, failures)
  for path in files {
    match read_repo_text(repo_root, path) {
      Ok(text) =>
        for failure in forbidden_guidance_token_failures(path, text) {
          failures.push(failure)
        }
      Err(message) => failures.push(message)
    }
  }
}
