///|
struct OwnershipPolicy {
  runtime_forbidden : Array[String]
  app_forbidden : Array[String]
  backend_forbidden : Array[String]
  global_forbidden : Array[String]
}

///|
fn json_strings(
  fields : Map[String, Json],
  key : String,
  failures : Array[String],
) -> Array[String] {
  match fields.get(key) {
    Some(Json::Array(values)) => {
      let result : Array[String] = []
      for index, value in values {
        match value {
          Json::String(item) if item.trim().to_owned() != "" => result.push(item)
          _ => failures.push(
            "checks/runtime-state-render-ownership.json." +
            key + "[" + index.to_string() + "] must be a non-empty string",
          )
        }
      }
      result
    }
    _ => {
      failures.push(
        "checks/runtime-state-render-ownership.json." + key +
        " must be an array",
      )
      []
    }
  }
}

///|
fn load_policy(repo_root : String) -> Result[OwnershipPolicy, Array[String]] {
  let path = @tools.resolve_path(
    repo_root,
    "checks/runtime-state-render-ownership.json",
  )
  let text = match @tools.read_required_text(path, "ownership policy") {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(["checks/runtime-state-render-ownership.json: invalid JSON"])
  }
  let fields = match parsed {
    Json::Object(value) => value
    _ => return Err(["checks/runtime-state-render-ownership.json must be an object"])
  }
  let failures : Array[String] = []
  match fields.get("schemaVersion") {
    Some(Json::Number(value, repr=_)) if value == 1.0 => ()
    _ => failures.push(
      "checks/runtime-state-render-ownership.json.schemaVersion must be 1",
    )
  }
  let policy = {
    runtime_forbidden: json_strings(fields, "runtimeForbiddenTokens", failures),
    app_forbidden: json_strings(fields, "appForbiddenTokens", failures),
    backend_forbidden: json_strings(fields, "backendForbiddenTokens", failures),
    global_forbidden: json_strings(fields, "globalForbiddenTokens", failures),
  }
  if failures.is_empty() { Ok(policy) } else { Err(failures) }
}

///|
fn is_source_file(path : String) -> Bool {
  path.has_suffix(".mbt") || path.has_suffix(".mbti") || path.has_suffix("moon.pkg")
}

///|
fn is_test_file(path : String) -> Bool {
  path.has_suffix("_test.mbt") || path.has_suffix("_wbtest.mbt")
}

///|
fn collect_files(
  repo_root : String,
  relative_dir : String,
  files : Array[String],
) -> Unit {
  let absolute = @tools.resolve_path(repo_root, relative_dir)
  if !@tools.directory_exists(absolute) {
    return
  }
  let entries : Array[String] = @fs.read_dir(absolute) catch { _ => return }
  entries.sort()
  for entry in entries {
    if entry == "_build" || entry == "node_modules" || entry.has_prefix(".") {
      continue
    }
    let relative = relative_dir + "/" + entry
    let child = @tools.resolve_path(repo_root, relative)
    if @tools.directory_exists(child) {
      collect_files(repo_root, relative, files)
    } else if @tools.file_exists(child) && is_source_file(relative) {
      files.push(relative)
    }
  }
}

///|
fn first_token_offset(text : String, token : String) -> Int? {
  text.find(token)
}

///|
fn scan_files(
  repo_root : String,
  files : Array[String],
  tokens : Array[String],
  label : String,
  skip_tests : Bool,
  failures : Array[String],
) -> Unit {
  for relative in files {
    if skip_tests && is_test_file(relative) {
      continue
    }
    let path = @tools.resolve_path(repo_root, relative)
    let text = match @tools.read_required_text(path, relative) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    for token in tokens {
      match first_token_offset(text, token) {
        Some(offset) => {
          let line = text[:offset].split("\n").length()
          failures.push(
            label + ": " + relative + ":" + line.to_string() +
            " contains forbidden token '" + token + "'",
          )
        }
        None => ()
      }
    }
  }
}

///|
fn validate_repository(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  let policy = match load_policy(repo_root) {
    Ok(value) => value
    Err(messages) => {
      for message in messages { failures.push(message) }
      return failures
    }
  }

  let runtime_files : Array[String] = []
  collect_files(repo_root, "moui/runtime", runtime_files)
  scan_files(
    repo_root, runtime_files, policy.runtime_forbidden, "runtime neutrality",
    false, failures,
  )

  let app_files : Array[String] = []
  collect_files(repo_root, "examples", app_files)
  collect_files(repo_root, "website/playground/app", app_files)
  scan_files(
    repo_root, app_files, policy.app_forbidden, "app state ownership", true,
    failures,
  )

  let backend_files : Array[String] = []
  collect_files(repo_root, "moui/backend/common", backend_files)
  scan_files(
    repo_root, backend_files, policy.backend_forbidden,
    "backend renderer-resource ownership", true, failures,
  )

  let global_files : Array[String] = []
  for root in [
    "moui", "moui_skia_renderer", "moui_web_renderer", "moui_wgpu_renderer",
    "moui_sun_renderer", "moui_tests",
  ] {
    collect_files(repo_root, root, global_files)
  }
  scan_files(
    repo_root, global_files, policy.global_forbidden,
    "removed lifecycle contract", false, failures,
  )

  if !@tools.directory_exists(@tools.resolve_path(repo_root, "moui/backend/accesskit")) {
    failures.push("backend accessibility adapter directory is missing")
  }
  failures
}
