// Ejected shell lock validator. Migrates
// `moui_shell/scripts/validate-ejected-lock.mjs` (153 lines) into MoonBit.
//
// `validate_ejected_lock` reads the `.moui-shell.json` lock produced by
// `moui shell eject`, enforces the v1 schema, verifies the capability
// snapshot digest matches the current platform, and optionally cross-checks
// the project manifest + app config.

///|
priv struct EjectedLock {
  schema_version : Int
  mode : String
  platform : String
  shell_api_version : Int
  embedding_api_version : Int
  moui_version : String
  moui_shell_version : String
  source_template : String
  capability_snapshot_digest : String
  source_template_digest : String
  config_digest : String
  plugin_digest : String
  content_digest : String
  plugin_manifests : Array[String]
  files : Array[EjectedLockFile]
} derive(Eq)

///|
priv struct EjectedLockFile {
  path : String
  sha256 : String
} derive(Eq)

///|
/// Returns the canonical capability snapshot digest for the requested
/// platform. The digest must match `shell_capability_snapshot_digest` in
// `eject.mbt` — both encode the same surface/pointer/scroll/... capabilities.
fn expected_capability_snapshot_digest(platform : String) -> String {
  let snapshot = "shellApi=1\nembeddingApi=1\nplatform=" +
    platform +
    "\ncapabilities=surface,pointer,scroll,frame-scheduling,text-input,clipboard,accessibility,platform-views,host-channel\n"
  sha256_hex(@utf8.encode(snapshot[:], bom=false))
}

///|
/// Returns `true` when `value` matches the canonical `sha256:<64-hex>` shape.
fn is_sha256_digest(value : String) -> Bool {
  if value.length() != 71 {
    return false
  }
  if !value.has_prefix("sha256:") {
    return false
  }
  let mut i = 7
  while i < value.length() {
    let ch = value[i]
    if !((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')) {
      return false
    }
    i += 1
  }
  true
}

///|
/// Validate the `.moui-shell.json` lock for an ejected platform build.
/// Mirrors `validate-ejected-lock.mjs::run`. Returns the parsed lock on
/// success.
fn validate_ejected_lock(
  lock_path : String,
  platform : String,
  moui_root : String,
  shell_root : String,
  project_root : String,
  app_config_path : String,
) -> Result[EjectedLock, String] {
  if !["android", "ios", "harmonyos"].contains(platform) {
    return Err("unsupported shell platform: " + platform)
  }
  let text = match read_file_string_optional(lock_path) {
    Some(value) => value
    None =>
      return Err(
        "ejected lock not found: " +
        lock_path +
        "; run `moui shell eject " +
        platform +
        "` first",
      )
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(lock_path + ": invalid JSON")
  }
  guard parsed is Object(root) else {
    return Err(lock_path + ": root must be an object")
  }
  let schema_version = match root.get("schemaVersion") {
    Some(Number(value, repr=_)) if value == 1.0 => 1
    _ => return Err(lock_path + ": schemaVersion must be 1")
  }
  let mode = match root.get("mode") {
    Some(String(value)) if value == "ejected" => value
    _ => return Err(lock_path + ": mode must be ejected")
  }
  let lock_platform = match root.get("platform") {
    Some(String(value)) if value == platform => value
    _ =>
      return Err(
        lock_path +
        ": platform must be " +
        platform +
        " (lock was not generated for this platform)",
      )
  }
  let shell_api_version = match root.get("shellApiVersion") {
    Some(Number(value, repr=_)) if value == 1.0 => 1
    _ => return Err(lock_path + ": shellApiVersion must be 1")
  }
  let embedding_api_version = match root.get("embeddingApiVersion") {
    Some(Number(value, repr=_)) if value == 1.0 => 1
    _ => return Err(lock_path + ": embeddingApiVersion must be 1")
  }
  let moui_version = match root.get("mouiVersion") {
    Some(String(value)) if value != "" => value
    _ => return Err(lock_path + ": mouiVersion must be a non-empty string")
  }
  let moui_shell_version = match root.get("mouiShellVersion") {
    Some(String(value)) if value != "" => value
    _ => return Err(lock_path + ": mouiShellVersion must be a non-empty string")
  }
  let source_template = match root.get("sourceTemplate") {
    Some(String(value)) if value == platform + "/runner/template" => value
    _ =>
      return Err(
        lock_path + ": sourceTemplate must be " + platform + "/runner/template",
      )
  }
  let capability_snapshot_digest = match root.get("capabilitySnapshotDigest") {
    Some(String(value)) if is_sha256_digest(value) => value
    _ =>
      return Err(
        lock_path + ": capabilitySnapshotDigest must be a sha256 digest",
      )
  }
  let source_template_digest = match root.get("sourceTemplateDigest") {
    Some(String(value)) if is_sha256_digest(value) => value
    _ =>
      return Err(lock_path + ": sourceTemplateDigest must be a sha256 digest")
  }
  let config_digest = match root.get("configDigest") {
    Some(String(value)) if is_sha256_digest(value) => value
    _ => return Err(lock_path + ": configDigest must be a sha256 digest")
  }
  let plugin_digest = match root.get("pluginDigest") {
    Some(String(value)) if is_sha256_digest(value) => value
    _ => return Err(lock_path + ": pluginDigest must be a sha256 digest")
  }
  let content_digest = match root.get("contentDigest") {
    Some(String(value)) if is_sha256_digest(value) => value
    _ => return Err(lock_path + ": contentDigest must be a sha256 digest")
  }
  let plugin_manifests : Array[String] = []
  match root.get("pluginManifests") {
    Some(Array(values)) =>
      for value in values {
        match value {
          String(text) => plugin_manifests.push(text)
          _ =>
            return Err(lock_path + ": pluginManifests must be a string array")
        }
      }
    _ => return Err(lock_path + ": pluginManifests must be a string array")
  }
  let files : Array[EjectedLockFile] = []
  match root.get("files") {
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(file) =>
            match (file.get("path"), file.get("sha256")) {
              (Some(String(path)), Some(String(sha))) if is_sha256_digest(sha) =>
                files.push({ path, sha256: sha })
              _ =>
                return Err(
                  lock_path + ": files must contain path and sha256 entries",
                )
            }
          _ => return Err(lock_path + ": files must be an array of objects")
        }
      }
    _ => return Err(lock_path + ": files must be an array")
  }
  // Capability snapshot digest must match the canonical embedding API v1 digest.
  let expected = expected_capability_snapshot_digest(platform)
  if capability_snapshot_digest != expected {
    return Err(
      lock_path +
      ": capabilitySnapshotDigest does not match embedding API v1 for " +
      platform,
    )
  }
  // Resolved package versions must match the lock.
  let installed_moui = match package_version(moui_root, "moui") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let installed_shell = match package_version(shell_root, "moui_shell") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if moui_version != installed_moui {
    return Err(
      lock_path +
      ": mouiVersion (" +
      moui_version +
      ") does not match resolved package (" +
      installed_moui +
      ")",
    )
  }
  if moui_shell_version != installed_shell {
    return Err(
      lock_path +
      ": mouiShellVersion (" +
      moui_shell_version +
      ") does not match resolved package (" +
      installed_shell +
      ")",
    )
  }
  // Optional cross-checks against project manifest + app config.
  if project_root != "" {
    let manifest_path = join_path(project_root, "moui.project.json")
    let manifest_text = match read_file_string_optional(manifest_path) {
      Some(value) => value
      None =>
        return Err(manifest_path + ": required for an ejected shell build")
    }
    let manifest = @json.parse(manifest_text) catch {
      _ => return Err(manifest_path + ": invalid JSON")
    }
    guard manifest is Object(fields) else {
      return Err(manifest_path + ": root must be an object")
    }
    match fields.get("schemaVersion") {
      Some(Number(value, repr=_)) if value == 1.0 => ()
      _ => return Err(manifest_path + ": schemaVersion=1 is required")
    }
    match fields.get("mouiVersion") {
      Some(String(value)) if value == moui_version => ()
      _ =>
        return Err(
          manifest_path +
          ": mouiVersion must match " +
          basename(lock_path) +
          ".mouiVersion",
        )
    }
    let platforms : Array[String] = []
    match fields.get("platforms") {
      Some(Array(values)) =>
        for value in values {
          match value {
            String(text) => platforms.push(text)
            _ => ()
          }
        }
      _ => ()
    }
    if !platforms.contains(platform) {
      return Err(manifest_path + ": platforms must include " + platform)
    }
  }
  if app_config_path != "" {
    let config_text = match read_file_string_optional(app_config_path) {
      Some(value) => value
      None => return Err(app_config_path + ": not found")
    }
    let config = @json.parse(config_text) catch {
      _ => return Err(app_config_path + ": invalid JSON")
    }
    guard config is Object(config_root) else {
      return Err(app_config_path + ": root must be an object")
    }
    match config_root.get("schemaVersion") {
      Some(Number(value, repr=_)) if value == 1.0 => ()
      _ => return Err(app_config_path + ": schemaVersion must be 1")
    }
    match config_root.get("shellApiVersion") {
      Some(Number(value, repr=_)) if value == 1.0 => ()
      _ => return Err(app_config_path + ": shellApiVersion must be 1")
    }
    match config_root.get("embeddingApiVersion") {
      Some(Number(value, repr=_)) if value == 1.0 => ()
      _ => return Err(app_config_path + ": embeddingApiVersion must be 1")
    }
    match config_root.get("shell") {
      Some(Object(shell)) =>
        match shell.get("profile") {
          Some(String("handheld")) => ()
          _ => return Err(app_config_path + ": shell.profile must be handheld")
        }
      _ => return Err(app_config_path + ": shell.profile must be handheld")
    }
    match config_root.get(platform) {
      Some(Object(platform_config)) =>
        match platform_config.get("runnerMode") {
          Some(String("ejected")) => ()
          _ =>
            return Err(
              app_config_path + ": " + platform + ".runnerMode must be ejected",
            )
        }
      _ =>
        return Err(
          app_config_path + ": " + platform + ".runnerMode must be ejected",
        )
    }
  }
  Ok({
    schema_version,
    mode,
    platform: lock_platform,
    shell_api_version,
    embedding_api_version,
    moui_version,
    moui_shell_version,
    source_template,
    capability_snapshot_digest,
    source_template_digest,
    config_digest,
    plugin_digest,
    content_digest,
    plugin_manifests,
    files,
  })
}

///|
/// Read a file as a string, returning `None` when the read fails so callers
/// can produce a domain-specific error message.
fn read_file_string_optional(path : String) -> String? {
  Some(@fs.read_file_to_string(path)) catch {
    _ => None
  }
}

///|
/// Return the trailing path component of `path`.
fn basename(path : String) -> String {
  let arr = path.split("/").to_array()
  if arr.is_empty() {
    return path
  }
  arr[arr.length() - 1].to_string()
}
