///|
let eject_platforms : ReadOnlyArray[String] = ["android", "ios", "harmonyos"]

///|
fn default_eject_directory(platform : String) -> String {
  platform + "_app"
}

///|
fn resolve_moui_root(options : EjectOptions) -> Result[String, String] {
  let candidates : Array[String] = []
  match options.moui_root {
    Some(value) =>
      candidates.push(
        normalized_path(resolve_path(options.project_root, value)),
      )
    None => ()
  }
  match @env.get_env_var("MOUI_PACKAGE_ROOT") {
    Some(value) => candidates.push(normalized_path(value))
    None => ()
  }
  for root in project_search_roots(options.project_root) {
    candidates.push(join_path(root, ".mooncakes/wzzc-dev/moui"))
    candidates.push(join_path(root, "moui"))
  }
  for candidate in candidates {
    if candidate == "" {
      continue
    }
    if path_is_dir(candidate) && path_is_dir(join_path(candidate, "mobile")) {
      return Ok(candidate)
    }
  }
  Err(
    "could not resolve the MoUI package root; run moon update or pass --moui-root",
  )
}

///|
fn collect_template_files(
  root : String,
  relative? : String = "",
) -> Result[Array[PlannedFile], String] {
  let directory = if relative == "" { root } else { join_path(root, relative) }
  let entries : Array[String] = @fs.read_dir(directory) catch {
    _ => return Err("could not read shell template directory: " + directory)
  }
  entries.sort_by((left, right) => left.lexical_compare(right))
  let files : Array[PlannedFile] = []
  for name in entries {
    let child_relative = if relative == "" {
      name
    } else {
      relative + "/" + name
    }
    let child = join_path(root, child_relative)
    if path_is_dir(child) {
      match collect_template_files(root, relative=child_relative) {
        Ok(children) =>
          for file in children {
            files.push(file)
          }
        Err(message) => return Err(message)
      }
    } else if path_is_file(child) {
      let bytes = @fs.read_file_to_bytes(child) catch {
        _ => return Err("could not read shell template file: " + child)
      }
      files.push({ path: child_relative, bytes })
    }
  }
  Ok(files)
}

///|
fn apply_stable_identity_replacements(
  value : String,
  manifest : ProjectManifest,
) -> String {
  let bundle_id = manifest.bundle_id.unwrap_or("")
  value
  .replace_all(old="my_app", new=manifest.id)
  .replace_all(old="my-app", new=kebab_name(manifest.id))
  .replace_all(old="dev.example.myapp", new=bundle_id)
  .replace_all(old="dev.example.mouiapp", new=bundle_id)
}

///|
fn apply_product_identity(
  value : String,
  manifest : ProjectManifest,
  platform : String,
) -> String {
  let product = product_name(manifest.id)
  match platform {
    "android" => value.replace_all(old="MoUIMobileAndroid", new=product)
    "ios" => value.replace_all(old="MoUIMobileApp", new=product)
    _ => value
  }
}

///|
fn content_uses_product_identity(path : String, platform : String) -> Bool {
  platform == "ios" ||
  (platform == "android" && (path == "settings.gradle" || path == "README.md"))
}

///|
fn render_json_identity_strings(
  value : Json,
  manifest : ProjectManifest,
  platform : String,
  replace_product : Bool,
) -> Json {
  match value {
    String(text) => {
      let rendered = apply_stable_identity_replacements(text, manifest)
      let rendered = if replace_product {
        apply_product_identity(rendered, manifest, platform)
      } else {
        rendered
      }
      rendered.replace_all(old="My MoUI App", new=manifest.title).to_json()
    }
    Array(values) =>
      Json::array(
        values.map(value => {
          render_json_identity_strings(
            value, manifest, platform, replace_product,
          )
        }),
      )
    Object(fields) => {
      let rendered : Map[String, Json] = Map([])
      for key, field in fields {
        rendered[key] = render_json_identity_strings(
          field, manifest, platform, replace_product,
        )
      }
      Json::object(rendered)
    }
    other => other
  }
}

///|
fn render_ejected_files(
  source_files : Array[PlannedFile],
  manifest : ProjectManifest,
  platform : String,
) -> Result[Array[PlannedFile], String] {
  let rendered : Array[PlannedFile] = []
  for source in source_files {
    let path = apply_stable_identity_replacements(source.path, manifest)
    let path = if platform == "ios" {
      apply_product_identity(path, manifest, platform)
    } else {
      path
    }
    let replace_product = content_uses_product_identity(source.path, platform)
    let decoded : String? = try @utf8.decode(source.bytes) catch {
      _ => None
    } noraise {
      text => Some(text)
    }
    let bytes = match decoded {
      Some(text) if path.has_suffix(".json") || path.has_suffix(".json5") => {
        let parsed = @json.parse(text) catch {
          _ =>
            return Err(
              "ejectable JSON template is invalid and cannot be rendered safely: " +
              source.path,
            )
        }
        let output = render_json_identity_strings(
            parsed, manifest, platform, replace_product,
          ).stringify(indent=2) +
          "\n"
        @utf8.encode(output[:], bom=false)
      }
      Some(text) => {
        if text.contains("My MoUI App") {
          return Err(
            "display title placeholder is only supported in structured JSON templates: " +
            source.path,
          )
        }
        let output = patch_ejected_shell_text(source.path, text, platform)
        let output = apply_stable_identity_replacements(output, manifest)
        let output = if replace_product {
          apply_product_identity(output, manifest, platform)
        } else {
          output
        }
        @utf8.encode(output[:], bom=false)
      }
      None => source.bytes
    }
    rendered.push({ path, bytes })
  }
  let sorted = rendered.copy()
  sorted.sort_by((left, right) => left.path.lexical_compare(right.path))
  Ok(sorted)
}

///|
fn project_config_bytes(
  project_root : String,
  mobile_bytes : Bytes,
  platform : String,
) -> Result[Bytes, String] {
  let project_path = join_path(project_root, "moui.project.json")
  let project = @fs.read_file_to_bytes(project_path) catch {
    _ =>
      return Err(
        "could not read project manifest for ejection: " + project_path,
      )
  }
  let mobile_text = @utf8.decode(mobile_bytes) catch {
    _ => return Err("mobile.json is not valid UTF-8")
  }
  let parsed = @json.parse(mobile_text) catch {
    _ => return Err("mobile.json is invalid JSON")
  }
  guard parsed is Object(root) else {
    return Err("mobile.json root must be an object")
  }
  guard root.get(platform) is Some(platform_config) else {
    return Err("mobile.json does not configure platform: " + platform)
  }
  let scoped : Map[String, Json] = Map([])
  for
    key in [
      "schemaVersion", "id", "displayName", "artifactName", "appPackage", "shellApiVersion",
      "runtimeAbiVersion", "mobile",
    ] {
    match root.get(key) {
      Some(value) => scoped[key] = value
      None => return Err("mobile.json is missing field: " + key)
    }
  }
  scoped[platform] = platform_config
  let canonical = Json::object(scoped).stringify(indent=2) + "\n"
  Ok(project + b"\x00" + @utf8.encode(canonical[:], bom=false))
}

///|
fn updated_mobile_config_for_eject(
  project_root : String,
  platform : String,
) -> Result[Bytes, String] {
  let path = join_path(project_root, "mobile.json")
  let text = @fs.read_file_to_string(path) catch {
    _ => return Err("mobile config not found: " + path)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("mobile.json is invalid JSON")
  }
  guard parsed is Object(root) else {
    return Err("mobile.json root must be an object")
  }
  guard root.get("schemaVersion") is Some(Number(2.0, repr=_)) else {
    return Err("mobile eject requires mobile.json schemaVersion 2")
  }
  guard root.get("shellApiVersion") is Some(Number(1.0, repr=_)) else {
    return Err("mobile eject requires shellApiVersion 1")
  }
  guard root.get("runtimeAbiVersion") is Some(Number(1.0, repr=_)) else {
    return Err("mobile eject requires runtimeAbiVersion 1")
  }
  guard root.get(platform) is Some(Object(platform_config)) else {
    return Err("mobile.json does not configure platform: " + platform)
  }
  guard platform_config.get("shellMode") is Some(String(mode)) else {
    return Err("mobile.json platform is missing shellMode: " + platform)
  }
  if mode != "managed" {
    return Err(
      "mobile shell is not managed and cannot be ejected again: " + platform,
    )
  }
  platform_config["shellMode"] = "ejected".to_json()
  root[platform] = Json::object(platform_config)
  let updated = Json::object(root).stringify(indent=2) + "\n"
  Ok(@utf8.encode(updated[:], bom=false))
}

///|
fn ejection_lock_text(
  manifest : ProjectManifest,
  platform : String,
  source_digest : String,
  config_digest : String,
  plugin_digest : String,
  plugin_manifests : Array[String],
  content_digest : String,
  files : Array[PlannedFile],
) -> String {
  let file_entries : Array[Json] = files.map(file => {
    let entry : Json = {
      "path": file.path,
      "sha256": "sha256:" + sha256_hex(file.bytes),
    }
    entry
  })
  let value : Json = {
    "schemaVersion": 1,
    "mode": "ejected",
    "platform": platform,
    "shellApiVersion": 1,
    "runtimeAbiVersion": 1,
    "mouiVersion": manifest.moui_version,
    "sourceTemplate": "mobile/" + platform + "/template",
    "sourceTemplateDigest": "sha256:" + source_digest,
    "configDigest": "sha256:" + config_digest,
    "pluginDigest": "sha256:" + plugin_digest,
    "pluginManifests": plugin_manifests,
    "contentDigest": "sha256:" + content_digest,
    "files": file_entries,
  }
  value.stringify(indent=2) + "\n"
}

///|
fn eject_mobile_shell(options : EjectOptions) -> Result[EjectResult, String] {
  let platform = options.platform.to_lower()
  if !eject_platforms.contains(platform) {
    return Err("mobile eject platform must be android, ios, or harmonyos")
  }
  let manifest = match read_project_manifest(options.project_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !manifest.platforms.contains(platform) {
    return Err("project manifest does not include platform: " + platform)
  }
  if manifest.bundle_id is None {
    return Err("project manifest is missing bundleId for mobile shell ejection")
  }
  let config = match read_mobile_doctor_config(options.project_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if config.schema_version != 2 ||
    config.shell_api_version != 1 ||
    config.runtime_abi_version != 1 {
    return Err(
      "mobile eject requires schemaVersion=2, shellApiVersion=1, and runtimeAbiVersion=1",
    )
  }
  let plugins = match read_doctor_plugins(options.project_root, config) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let plugin_digest = doctor_plugins_digest(plugins)
  let updated_mobile = match
    updated_mobile_config_for_eject(options.project_root, platform) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let config_bytes = match
    project_config_bytes(options.project_root, updated_mobile, platform) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let config_digest = sha256_hex(config_bytes)
  let output = if options.output == "" {
    join_path(options.project_root, default_eject_directory(platform))
  } else {
    resolve_path(options.project_root, options.output)
  }
  if @fs.path_exists(output) {
    return Err("target already exists: " + output)
  }
  let moui_root = match resolve_moui_root(options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source_files = match canonical_shell_source_plan(moui_root, platform) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let rendered = match render_ejected_files(source_files, manifest, platform) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let rendered = rendered + plugin_snapshot_plan(plugins)
  match validate_file_plan(rendered) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let source_digest = file_plan_digest(source_files)
  let content_digest = file_plan_digest(rendered)
  let files = rendered.copy()
  files.push(
    text_file(
      ".moui-shell.json",
      ejection_lock_text(
        manifest,
        platform,
        source_digest,
        config_digest,
        plugin_digest,
        config.plugin_paths,
        content_digest,
        rendered,
      ),
    ),
  )
  match write_file_plan_atomic(output, files) {
    Ok(_) => {
      let mobile_path = join_path(options.project_root, "mobile.json")
      match replace_file_atomic(mobile_path, updated_mobile) {
        Ok(_) =>
          Ok({
            platform,
            output,
            source_template_digest: source_digest,
            config_digest,
            plugin_digest,
            content_digest,
            file_count: rendered.length(),
          })
        Err(message) => {
          remove_tree(output)
          if @fs.path_exists(output) {
            Err(
              message +
              "; additionally could not remove newly ejected shell: " +
              output,
            )
          } else {
            Err(message)
          }
        }
      }
    }
    Err(message) => Err(message)
  }
}

///|
fn EjectResult::to_json_text(self : EjectResult) -> String {
  let value : Json = {
    "schemaVersion": 1,
    "platform": self.platform,
    "output": self.output,
    "sourceTemplateDigest": "sha256:" + self.source_template_digest,
    "configDigest": "sha256:" + self.config_digest,
    "pluginDigest": "sha256:" + self.plugin_digest,
    "contentDigest": "sha256:" + self.content_digest,
    "fileCount": self.file_count,
  }
  value.stringify(indent=2) + "\n"
}
