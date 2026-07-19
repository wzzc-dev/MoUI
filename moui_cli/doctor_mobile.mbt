///|
priv struct EjectedShellLock {
  platform : String
  shell_api_version : Int
  runtime_abi_version : Int
  moui_version : String
  moui_shell_version : String
  capability_snapshot_digest : String
  source_digest : String
  config_digest : String
  plugin_digest : String
  content_digest : String
  files : Map[String, String]
}

///|
fn sha256_value(value : String, label : String) -> Result[String, String] {
  if !value.has_prefix("sha256:") || value.length() != 71 {
    return Err(label + " must be a sha256:<64 lowercase hex> digest")
  }
  let digest = value[7:].to_owned()
  if !digest.all(char => {
      (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f')
    }) {
    return Err(label + " must be a sha256:<64 lowercase hex> digest")
  }
  Ok(digest)
}

///|
fn parse_ejected_shell_lock(text : String) -> Result[EjectedShellLock, String] {
  let parsed = @json.parse(text) catch {
    _ => return Err(".moui-shell.json is invalid JSON")
  }
  let fields = match
    doctor_exact_object(
      parsed,
      [
        "schemaVersion", "mode", "platform", "shellApiVersion", "embeddingApiVersion",
        "mouiVersion", "mouiShellVersion", "capabilitySnapshotDigest", "sourceTemplate",
        "sourceTemplateDigest", "configDigest", "pluginDigest", "pluginManifests",
        "contentDigest", "files",
      ],
      [
        "schemaVersion", "mode", "platform", "shellApiVersion", "embeddingApiVersion",
        "mouiVersion", "mouiShellVersion", "capabilitySnapshotDigest", "sourceTemplate",
        "sourceTemplateDigest", "configDigest", "pluginDigest", "pluginManifests",
        "contentDigest", "files",
      ],
      ".moui-shell.json",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let schema = match
    doctor_required_int(fields, "schemaVersion", ".moui-shell.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if schema != 1 {
    return Err(".moui-shell.json schemaVersion must be 1")
  }
  let mode = match doctor_required_string(fields, "mode", ".moui-shell.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if mode != "ejected" {
    return Err(".moui-shell.json mode must be ejected")
  }
  let platform = match
    doctor_required_string(fields, "platform", ".moui-shell.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !eject_platforms.contains(platform) {
    return Err(".moui-shell.json platform is unsupported: " + platform)
  }
  let shell_api_version = match
    doctor_required_int(fields, "shellApiVersion", ".moui-shell.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let runtime_abi_version = match
    doctor_required_int(fields, "embeddingApiVersion", ".moui-shell.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let moui_version = match
    doctor_required_string(fields, "mouiVersion", ".moui-shell.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let moui_shell_version = match
    doctor_required_string(fields, "mouiShellVersion", ".moui-shell.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let capability_snapshot_digest = match
    fields.get("capabilitySnapshotDigest") {
    Some(String(value)) =>
      match sha256_value(value, ".moui-shell.json.capabilitySnapshotDigest") {
        Ok(result) => result
        Err(message) => return Err(message)
      }
    _ =>
      return Err(".moui-shell.json.capabilitySnapshotDigest must be a string")
  }
  match doctor_required_string(fields, "sourceTemplate", ".moui-shell.json") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let source_digest = match fields.get("sourceTemplateDigest") {
    Some(String(value)) =>
      match sha256_value(value, ".moui-shell.json.sourceTemplateDigest") {
        Ok(result) => result
        Err(message) => return Err(message)
      }
    _ => return Err(".moui-shell.json.sourceTemplateDigest must be a string")
  }
  let config_digest = match fields.get("configDigest") {
    Some(String(value)) =>
      match sha256_value(value, ".moui-shell.json.configDigest") {
        Ok(result) => result
        Err(message) => return Err(message)
      }
    _ => return Err(".moui-shell.json.configDigest must be a string")
  }
  let plugin_digest = match fields.get("pluginDigest") {
    Some(String(value)) =>
      match sha256_value(value, ".moui-shell.json.pluginDigest") {
        Ok(result) => result
        Err(message) => return Err(message)
      }
    _ => return Err(".moui-shell.json.pluginDigest must be a string")
  }
  let content_digest = match fields.get("contentDigest") {
    Some(String(value)) =>
      match sha256_value(value, ".moui-shell.json.contentDigest") {
        Ok(result) => result
        Err(message) => return Err(message)
      }
    _ => return Err(".moui-shell.json.contentDigest must be a string")
  }
  let _plugin_manifests = match
    doctor_unique_strings(
      fields.get("pluginManifests").unwrap(),
      ".moui-shell.json.pluginManifests",
      paths=true,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  guard fields.get("files") is Some(Array(file_entries)) else {
    return Err(".moui-shell.json.files must be an array")
  }
  let files : Map[String, String] = Map([])
  for index, entry in file_entries {
    let label = ".moui-shell.json.files[" + index.to_string() + "]"
    let file = match
      doctor_exact_object(entry, ["path", "sha256"], ["path", "sha256"], label) {
      Ok(result) => result
      Err(message) => return Err(message)
    }
    let path = match doctor_required_string(file, "path", label) {
      Ok(result) => result
      Err(message) => return Err(message)
    }
    match validate_relative_path(path) {
      Ok(_) => ()
      Err(_) => return Err(label + ".path is unsafe: " + path)
    }
    if files.contains(path) {
      return Err(".moui-shell.json.files contains duplicate path: " + path)
    }
    let digest = match file.get("sha256") {
      Some(String(value)) =>
        match sha256_value(value, label + ".sha256") {
          Ok(result) => result
          Err(message) => return Err(message)
        }
      _ => return Err(label + ".sha256 must be a string")
    }
    files[path] = digest
  }
  Ok({
    platform,
    shell_api_version,
    runtime_abi_version,
    moui_version,
    moui_shell_version,
    capability_snapshot_digest,
    source_digest,
    config_digest,
    plugin_digest,
    content_digest,
    files,
  })
}

///|
fn read_ejected_shell_lock(root : String) -> Result[EjectedShellLock, String] {
  let path = join_path(root, ".moui-shell.json")
  let text = @fs.read_file_to_string(path) catch {
    _ => return Err("ejected shell lock not found: " + path)
  }
  parse_ejected_shell_lock(text)
}

///|
fn find_ejected_shell_root(
  project_root : String,
  platform : String,
) -> Result[String, String] {
  let preferred = join_path(project_root, default_eject_directory(platform))
  if path_is_nonempty_file(join_path(preferred, ".moui-shell.json")) {
    return Ok(preferred)
  }
  let matches : Array[String] = []
  let entries : Array[String] = @fs.read_dir(project_root) catch { _ => [] }
  for entry in entries {
    if entry == ".git" || entry == ".mooncakes" || entry == "_build" {
      continue
    }
    let candidate = join_path(project_root, entry)
    if path_is_dir(candidate) &&
      path_is_nonempty_file(join_path(candidate, ".moui-shell.json")) {
      match read_ejected_shell_lock(candidate) {
        Ok(lock) if lock.platform == platform => matches.push(candidate)
        _ => ()
      }
    }
  }
  match matches {
    [root] => Ok(root)
    [] =>
      Err(
        "no ejected " + platform + " shell lock was found under " + project_root,
      )
    _ =>
      Err(
        "multiple ejected " +
        platform +
        " shell locks were found: " +
        matches.join(", "),
      )
  }
}

///|
fn ejected_shell_content_plan(
  root : String,
) -> Result[Array[PlannedFile], String] {
  let files = match collect_template_files(root) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  Ok(files.filter(file => file.path != ".moui-shell.json"))
}

///|
fn validate_ejected_file_digests(
  lock : EjectedShellLock,
  files : Array[PlannedFile],
) -> Array[String] {
  let drift : Array[String] = []
  let actual : Map[String, String] = Map([])
  for file in files {
    actual[file.path] = sha256_hex(file.bytes)
    match lock.files.get(file.path) {
      Some(expected) if expected == actual[file.path] => ()
      Some(_) => drift.push("modified:" + file.path)
      None => drift.push("added:" + file.path)
    }
  }
  for path, _ in lock.files {
    if !actual.contains(path) {
      drift.push("removed:" + path)
    }
  }
  drift
}

///|
fn doctor_temp_target(label : String) -> String {
  let root = match @env.get_env_var("TMPDIR") {
    Some(value) => value
    None =>
      match @env.get_env_var("TEMP") {
        Some(value) => value
        None => @env.get_env_var("TMP").unwrap_or(".")
      }
  }
  join_path(root, "moui-doctor-" + label + "-" + @env.now().to_string())
}

///|
fn managed_shell_staging_check(
  shell_root : String,
  platform : String,
  plugins : Array[DoctorPlugin],
) -> DoctorCheck {
  let source_files = match canonical_shell_source_plan(shell_root, platform) {
    Ok(result) => result
    Err(message) =>
      return doctor_check(
        "shell." + platform + ".managed-staging",
        Fail,
        true,
        "Managed canonical shell is incomplete",
        detail=message,
        remediation="Resolve a MoUI package that contains the complete shell API v1 template and source overlays.",
      )
  }
  let files = source_files +
    plugin_snapshot_plan(
      plugins.filter(plugin => plugin.platforms.contains(platform)),
    )
  match validate_file_plan(files) {
    Err(message) =>
      return doctor_check(
        "shell." + platform + ".managed-staging",
        Fail,
        true,
        "Managed shell staging plan is invalid",
        detail=message,
      )
    Ok(_) => ()
  }
  let target = doctor_temp_target(platform)
  let staged = match stage_file_plan(target, files) {
    Ok(result) => result
    Err(message) =>
      return doctor_check(
        "shell." + platform + ".managed-staging",
        Fail,
        true,
        "Managed shell could not be staged",
        detail=message,
      )
  }
  remove_tree(staged)
  doctor_check(
    "shell." + platform + ".managed-staging",
    Pass,
    true,
    "Managed canonical shell can be staged",
    detail="files=" +
      files.length().to_string() +
      " templateDigest=sha256:" +
      file_plan_digest(source_files),
  )
}

///|
fn ejected_shell_doctor_check(
  project_root : String,
  platform : String,
  plugins : Array[DoctorPlugin],
  moui_root : String?,
  shell_root : String?,
) -> DoctorCheck {
  let id = "shell." + platform + ".ejected"
  let root = match find_ejected_shell_root(project_root, platform) {
    Ok(result) => result
    Err(message) =>
      return doctor_check(
        id,
        Fail,
        true,
        "Ejected shell lock is missing",
        detail=message,
        remediation="Restore the versioned ejected shell directory and its .moui-shell.json lock.",
      )
  }
  let lock = match read_ejected_shell_lock(root) {
    Ok(result) => result
    Err(message) =>
      return doctor_check(
        id,
        Fail,
        true,
        "Ejected shell lock is invalid",
        detail=message,
      )
  }
  if lock.platform != platform ||
    lock.shell_api_version != 1 ||
    lock.runtime_abi_version != 1 {
    return doctor_check(
      id,
      Fail,
      true,
      "Ejected shell is incompatible with shell API/runtime ABI v1",
      detail="platform=" +
        lock.platform +
        " shellApi=" +
        lock.shell_api_version.to_string() +
        " runtimeAbi=" +
        lock.runtime_abi_version.to_string(),
    )
  }
  let files = match ejected_shell_content_plan(root) {
    Ok(result) => result
    Err(message) =>
      return doctor_check(
        id,
        Fail,
        true,
        "Ejected shell could not be read",
        detail=message,
      )
  }
  let drift = validate_ejected_file_digests(lock, files)
  if file_plan_digest(files) != lock.content_digest {
    drift.push("contentDigest")
  }
  let shell_bytes = @fs.read_file_to_bytes(
    join_path(project_root, "shell.json"),
  ) catch {
    _ => b""
  }
  let config_bytes = project_shell_config_bytes(
    project_root, shell_bytes, platform,
  )
  match config_bytes {
    Ok(value) if sha256_hex(value) != lock.config_digest =>
      drift.push("configDigest")
    Err(message) => drift.push("config-unreadable:" + message)
    _ => ()
  }
  if doctor_plugins_digest(plugins) != lock.plugin_digest {
    drift.push("pluginDigest")
  }
  if lock.capability_snapshot_digest !=
    shell_capability_snapshot_digest(platform) {
    drift.push("capabilitySnapshotDigest")
  }
  match (moui_root, shell_root) {
    (Some(moui_root), Some(shell_root)) => {
      match package_version(moui_root, "moui") {
        Ok(version) if version != lock.moui_version => drift.push("mouiVersion")
        Err(message) => drift.push("moui-version-unreadable:" + message)
        _ => ()
      }
      match package_version(shell_root, "moui_shell") {
        Ok(version) if version != lock.moui_shell_version =>
          drift.push("mouiShellVersion")
        Err(message) => drift.push("moui-shell-version-unreadable:" + message)
        _ => ()
      }
      match canonical_shell_source_plan(shell_root, platform) {
        Ok(files) if file_plan_digest(files) != lock.source_digest =>
          drift.push("upstreamTemplate")
        Err(message) => drift.push("upstream-unreadable:" + message)
        _ => ()
      }
    }
    _ => drift.push("upstream-unavailable")
  }
  if drift.is_empty() {
    doctor_check(
      id,
      Pass,
      true,
      "Ejected shell is compatible and matches its recorded digests",
      detail=root +
        " | moui=" +
        lock.moui_version +
        " moui_shell=" +
        lock.moui_shell_version,
    )
  } else {
    doctor_check(
      id,
      Warn,
      true,
      "Ejected shell is compatible but has recorded drift",
      detail=drift.join(", "),
      remediation="Review local changes and upstream drift; re-eject only into a new empty directory when intentionally upgrading.",
    )
  }
}

///|
fn mobile_project_doctor_checks(
  project_root : String,
  platforms : Array[String],
) -> Array[DoctorCheck] {
  let selected = platforms.filter(is_mobile_platform)
  if selected.is_empty() {
    return [
      skipped_check("shell.config", "No shell platform is selected"),
      skipped_check("shell.protocol", "No shell platform is selected"),
      skipped_check("shell.plugins", "No shell platform is selected"),
    ]
  }
  let checks : Array[DoctorCheck] = []
  let config = match read_shell_doctor_config(project_root) {
    Ok(result) => {
      checks.push(
        doctor_check(
          "shell.config",
          Pass,
          true,
          "shell.json schema v1 structure is valid",
          detail=join_path(project_root, "shell.json"),
        ),
      )
      result
    }
    Err(message) => {
      checks.push(
        doctor_check(
          "shell.config",
          Fail,
          true,
          "shell.json is invalid",
          detail=message,
        ),
      )
      checks.push(
        skipped_check("shell.protocol", "shell.json could not be parsed"),
      )
      checks.push(
        skipped_check("shell.plugins", "shell.json could not be parsed"),
      )
      return checks
    }
  }
  let protocol_ok = config.schema_version == 1 &&
    config.shell_api_version == 1 &&
    config.runtime_abi_version == 1
  checks.push(
    doctor_check(
      "shell.protocol",
      if protocol_ok {
        Pass
      } else {
        Fail
      },
      true,
      if protocol_ok {
        "Shell schema, shell API, and runtime ABI are compatible"
      } else {
        "Shell schema, shell API, or runtime ABI is incompatible"
      },
      detail="schema=" +
        config.schema_version.to_string() +
        " shellApi=" +
        config.shell_api_version.to_string() +
        " runtimeAbi=" +
        config.runtime_abi_version.to_string(),
      remediation=if protocol_ok {
        ""
      } else {
        "Use schemaVersion 1, shell.profile=handheld, shellApiVersion 1, and embeddingApiVersion 1."
      },
    ),
  )
  let plugins = match read_doctor_plugins(project_root, config) {
    Ok(result) => {
      checks.push(
        doctor_check(
          "shell.plugins",
          Pass,
          true,
          "Managed plugin manifests and permissions are valid",
          detail="count=" +
            result.length().to_string() +
            " digest=sha256:" +
            doctor_plugins_digest(result),
        ),
      )
      result
    }
    Err(message) => {
      checks.push(
        doctor_check(
          "shell.plugins",
          Fail,
          true,
          "Managed plugin manifest or permission validation failed",
          detail=message,
        ),
      )
      []
    }
  }
  let moui_root = match
    resolve_moui_root({
      project_root,
      platform: "android",
      output: "",
      moui_root: None,
    }) {
    Ok(result) => Some(result)
    Err(_) => None
  }
  let shell_root = match
    resolve_shell_root({
      project_root,
      platform: "android",
      output: "",
      moui_root: None,
    }) {
    Ok(result) => Some(result)
    Err(_) => None
  }
  for platform in selected {
    match config.shell_modes.get(platform) {
      None =>
        checks.push(
          doctor_check(
            "shell." + platform + ".shell",
            Fail,
            true,
            "Selected platform is missing from shell.json",
          ),
        )
      Some("managed") =>
        match (moui_root, shell_root) {
          (Some(_), Some(shell_root)) if protocol_ok =>
            checks.push(
              managed_shell_staging_check(shell_root, platform, plugins),
            )
          (Some(_), Some(_)) =>
            checks.push(
              skipped_check(
                "shell." + platform + ".managed-staging",
                "Managed staging requires a compatible shell protocol",
              ),
            )
          _ =>
            checks.push(
              doctor_check(
                "shell." + platform + ".managed-staging",
                Fail,
                true,
                "MoUI package root for managed staging was not found",
                remediation="Run moon update or set MOUI_PACKAGE_ROOT to the resolved wzzc-dev/moui package.",
              ),
            )
        }
      Some("ejected") =>
        checks.push(
          ejected_shell_doctor_check(
            project_root, platform, plugins, moui_root, shell_root,
          ),
        )
      Some(mode) =>
        checks.push(
          doctor_check(
            "shell." + platform + ".shell",
            Fail,
            true,
            "Unsupported shell mode: " + mode,
          ),
        )
    }
  }
  checks
}
