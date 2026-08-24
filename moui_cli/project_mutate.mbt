///|
fn platform_entrypoint_directory(platform : String) -> String {
  if platform == "web" {
    "web_wasm"
  } else if is_mobile_platform(platform) {
    platform + "_window_hosted"
  } else {
    platform + "_skia"
  }
}

///|
fn platform_files_for(
  options : ProjectOptions,
  platform : String,
) -> Result[Array[PlannedFile], String] {
  if !is_platform(platform) {
    return Err("unsupported platform: " + platform)
  }
  if platform == "web" {
    return Ok([
      text_file("web_wasm/moon.pkg", web_pkg_text(options.module_name)),
      text_file("web_wasm/main.mbt", web_main_text(options.title)),
      text_file("web_wasm/index.html", web_html_text(options.title)),
    ])
  }
  if platform == "macos" || platform == "windows" || platform == "linux" {
    let directory = platform_entrypoint_directory(platform)
    return Ok([
      text_file(
        directory + "/moon.pkg",
        desktop_pkg_text(options.module_name, platform),
      ),
      text_file(
        directory + "/main.mbt",
        desktop_main_text(options.title, platform),
      ),
    ])
  }
  if is_mobile_platform(platform) {
    let directory = platform_entrypoint_directory(platform)
    return Ok([
      text_file(
        directory + "/moon.pkg",
        mobile_entrypoint_pkg_text(options.module_name, platform),
      ),
      text_file(directory + "/main.mbt", mobile_entrypoint_main_text(platform)),
    ])
  }
  Err("unsupported platform: " + platform)
}

///|
fn merge_platform_lists(
  existing : Array[String],
  requested : Array[String],
) -> Result[(Array[String], Array[String]), String] {
  let selected : Map[String, Bool] = Map([])
  for platform in existing {
    if !is_platform(platform) {
      return Err("existing project contains unsupported platform: " + platform)
    }
    selected[platform] = true
  }
  let added : Array[String] = []
  for requested_platform in requested {
    let platform = requested_platform.to_lower()
    if platform == "all" {
      for value in platform_order {
        if !selected.contains(value) {
          selected[value] = true
          added.push(value)
        }
      }
    } else if is_platform(platform) {
      if !selected.contains(platform) {
        selected[platform] = true
        added.push(platform)
      }
    } else {
      return Err(
        "unsupported platform: " +
        requested_platform +
        " (expected web|macos|windows|linux|android|ios|harmonyos|all)",
      )
    }
  }
  let merged : Array[String] = []
  for platform in platform_order {
    if selected.contains(platform) {
      merged.push(platform)
    }
  }
  Ok((merged, added))
}

///|
fn merge_mobile_config_for_platforms(
  existing_text : String?,
  options : ProjectOptions,
) -> Result[String, String] {
  if !options.platforms.any(is_mobile_platform) {
    return Ok(existing_text.unwrap_or(""))
  }
  match existing_text {
    None | Some("") => Ok(mobile_config_text(options))
    Some(text) => {
      let parsed = @json.parse(text) catch {
        _ => return Err("moui.mobile.json is invalid JSON")
      }
      guard parsed is Object(root) else {
        return Err("moui.mobile.json root must be an object")
      }
      let generated = @json.parse(mobile_config_text(options)) catch {
        _ => return Err("could not build mobile platform defaults")
      }
      guard generated is Object(generated_root) else {
        return Err("generated mobile config must be an object")
      }
      for platform in ["android", "ios", "harmonyos"] {
        if options.platforms.contains(platform) && !root.contains(platform) {
          match generated_root.get(platform) {
            Some(value) => root[platform] = value
            None => ()
          }
        }
      }
      if !root.contains("schemaVersion") {
        root["schemaVersion"] = (1 : Int).to_json()
      }
      Ok(Json::object(root).stringify(indent=2) + "\n")
    }
  }
}

///|
fn write_planned_files_into(
  project_root : String,
  files : Array[PlannedFile],
) -> Result[Array[String], String] {
  match validate_file_plan(files) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let written : Array[String] = []
  for file in files {
    let destination = join_path(project_root, file.path)
    if @fs.path_exists(destination) {
      return Err("refusing to overwrite existing file: " + file.path)
    }
    match mkdir_p(parent_dir(destination)) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    @fs.write_bytes_to_file(destination, file.bytes) catch {
      _ => return Err("could not write generated file: " + file.path)
    }
    written.push(file.path)
  }
  Ok(written)
}

///|
fn add_platforms_to_project(
  options : AddPlatformOptions,
) -> Result[(Array[String], Array[String]), String] {
  let manifest = match read_project_manifest(options.project_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let (merged, added) = match
    merge_platform_lists(manifest.platforms, options.platforms) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if added.is_empty() {
    return Err("project already includes the requested platforms")
  }
  let bundle_id = match options.bundle_id {
    Some(value) => Some(value)
    None => manifest.bundle_id
  }
  let project_options : ProjectOptions = {
    target: options.project_root,
    id: manifest.id,
    module_name: manifest.module_name,
    title: manifest.title,
    moui_version: manifest.moui_version,
    moui_skia_renderer_version: default_moui_skia_renderer_dependency_version,
    template: "counter",
    platforms: merged,
    bundle_id,
  }
  match validate_project_options(project_options) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let files : Array[PlannedFile] = []
  for platform in added {
    match platform_files_for(project_options, platform) {
      Ok(platform_files) =>
        for file in platform_files {
          files.push(file)
        }
      Err(message) => return Err(message)
    }
  }
  let updated_manifest : ProjectManifest = {
    schema_version: 1,
    id: manifest.id,
    title: manifest.title,
    module_name: manifest.module_name,
    moui_version: manifest.moui_version,
    platforms: merged.copy(),
    bundle_id,
  }
  match
    replace_file_atomic(
      join_path(options.project_root, "moui.project.json"),
      @utf8.encode(updated_manifest.to_json_text()[:], bom=false),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  if merged.any(is_mobile_platform) {
    let mobile_path = join_path(options.project_root, "moui.mobile.json")
    let existing = if @fs.path_exists(mobile_path) {
      let text = @fs.read_file_to_string(mobile_path) catch {
        _ => return Err("could not read moui.mobile.json: " + mobile_path)
      }
      Some(text)
    } else {
      None
    }
    let mobile_text = match
      merge_mobile_config_for_platforms(existing, project_options) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if mobile_text != "" {
      match
        replace_file_atomic(
          mobile_path,
          @utf8.encode(mobile_text[:], bom=false),
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  let written = match write_planned_files_into(options.project_root, files) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  // Keep README current when present or create it when absent.
  let readme_path = join_path(options.project_root, "README.md")
  let readme = readme_text(project_options)
  if @fs.path_exists(readme_path) {
    match replace_file_atomic(readme_path, @utf8.encode(readme[:], bom=false)) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  } else {
    match
      write_planned_files_into(options.project_root, [
        text_file("README.md", readme),
      ]) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok((added, written))
}
