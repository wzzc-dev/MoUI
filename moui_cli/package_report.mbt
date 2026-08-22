///|
fn package_report_text(
  options : PackageReportOptions,
) -> Result[String, String] {
  let manifest = match read_project_manifest(options.project_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let builder = StringBuilder::new()
  builder.write_string("MoUI package report\n")
  builder.write_string("projectRoot: " + options.project_root + "\n")
  builder.write_string("id: " + manifest.id + "\n")
  builder.write_string("module: " + manifest.module_name + "\n")
  builder.write_string("title: " + manifest.title + "\n")
  builder.write_string("mouiVersion: " + manifest.moui_version + "\n")
  builder.write_string("platforms: " + manifest.platforms.join(", ") + "\n")
  match manifest.bundle_id {
    Some(value) => builder.write_string("bundleId: " + value + "\n")
    None => builder.write_string("bundleId: (none)\n")
  }
  let mobile_path = join_path(options.project_root, "moui.mobile.json")
  if @fs.path_exists(mobile_path) {
    let text = @fs.read_file_to_string(mobile_path) catch {
      _ => return Err("could not read moui.mobile.json: " + mobile_path)
    }
    let parsed = @json.parse(text) catch {
      _ => return Err("moui.mobile.json is invalid JSON")
    }
    guard parsed is Object(root) else {
      return Err("moui.mobile.json root must be an object")
    }
    match root.get("schemaVersion") {
      Some(Number(value, repr=_)) =>
        builder.write_string(
          "mobileConfigSchemaVersion: " + value.to_int().to_string() + "\n",
        )
      _ => builder.write_string("mobileConfigSchemaVersion: (missing)\n")
    }
  } else {
    builder.write_string("moui.mobile.json: (absent)\n")
  }
  Ok(builder.to_string())
}

///|
fn package_report_json(
  options : PackageReportOptions,
) -> Result[String, String] {
  let manifest = match read_project_manifest(options.project_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let root : Map[String, Json] = Map([
    ("schemaVersion", (1 : Int).to_json()),
    ("ok", true.to_json()),
    ("command", "package".to_json()),
    ("projectRoot", options.project_root.to_json()),
    ("id", manifest.id.to_json()),
    ("module", manifest.module_name.to_json()),
    ("title", manifest.title.to_json()),
    ("mouiVersion", manifest.moui_version.to_json()),
    ("platforms", manifest.platforms.to_json()),
  ])
  match manifest.bundle_id {
    Some(value) => root["bundleId"] = value.to_json()
    None => ()
  }
  let mobile_path = join_path(options.project_root, "moui.mobile.json")
  if @fs.path_exists(mobile_path) {
    let text = @fs.read_file_to_string(mobile_path) catch {
      _ => return Err("could not read moui.mobile.json: " + mobile_path)
    }
    let parsed = @json.parse(text) catch {
      _ => return Err("moui.mobile.json is invalid JSON")
    }
    root["mobile"] = parsed
  }
  Ok(Json::object(root).stringify(indent=2) + "\n")
}

///|
fn package_output_kind(platform : String) -> String {
  match platform {
    "web" => "web-bundle"
    "macos" => "app-bundle"
    "windows" => "portable-directory"
    "linux" => "native-bundle"
    "android" => "apk"
    "ios" => "app-bundle"
    "harmonyos" => "hap"
    _ => "unknown"
  }
}

///|
fn package_platform_is_supported(platform : String) -> Bool {
  ["web", "macos", "windows", "linux", "android", "ios", "harmonyos"].contains(
    platform,
  )
}

///|
fn package_manifest_json(
  options : PackageReportOptions,
) -> Result[Json, String] {
  let project = match read_project_manifest(options.project_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let platforms = if options.platforms.is_empty() {
    project.platforms.copy()
  } else {
    options.platforms.copy()
  }
  let seen : Map[String, Bool] = Map([])
  for platform in platforms {
    if !project.platforms.contains(platform) {
      return Err("platform is not declared by project: " + platform)
    }
    if !package_platform_is_supported(platform) {
      return Err("unsupported package platform: " + platform)
    }
    if seen.contains(platform) {
      return Err("duplicate package platform: " + platform)
    }
    seen[platform] = true
  }
  let version = match options.version {
    Some(value) if value != "" => value
    Some(_) => return Err("--version must not be empty")
    None => project.moui_version
  }
  let output_root = match options.output_dir {
    Some(value) if value != "" => value
    Some(_) => return Err("--output must not be empty")
    None => join_path(options.project_root, "dist")
  }
  let artifacts : Array[Json] = []
  for platform in platforms {
    let output_path = join_path(output_root, platform)
    artifacts.push(
      Json::object(
        Map([
          ("platform", platform.to_json()),
          ("outputKind", package_output_kind(platform).to_json()),
          ("outputPath", output_path.to_json()),
          ("buildRequested", options.build.to_json()),
          (
            "signing",
            Json::object(
              Map([
                ("status", "host-required".to_json()),
                ("signature", Json::null()),
              ]),
            ),
          ),
          (
            "notarization",
            Json::object(Map([("status", "host-required".to_json())])),
          ),
          (
            "installer",
            Json::object(Map([("status", "host-specific".to_json())])),
          ),
          (
            "updateManifest",
            Json::object(Map([("status", "not-configured".to_json())])),
          ),
        ]),
      ),
    )
  }
  Ok(
    Json::object(
      Map([
        ("schemaVersion", (1 : Int).to_json()),
        ("ok", true.to_json()),
        ("command", "package".to_json()),
        (
          "status",
          (if options.dry_run {
            "dry-run"
          } else if options.build {
            "build-requested"
          } else {
            "planned"
          }).to_json(),
        ),
        ("projectRoot", options.project_root.to_json()),
        (
          "project",
          Json::object(
            Map([
              ("id", project.id.to_json()),
              ("title", project.title.to_json()),
              ("module", project.module_name.to_json()),
              ("mouiVersion", project.moui_version.to_json()),
              (
                "bundleId",
                match project.bundle_id {
                  Some(value) => value.to_json()
                  None => Json::null()
                },
              ),
            ]),
          ),
        ),
        ("version", version.to_json()),
        ("platforms", platforms.to_json()),
        ("artifacts", artifacts.to_json()),
        (
          "release",
          Json::object(
            Map([
              ("signing", "host-required".to_json()),
              ("notarization", "host-required".to_json()),
              ("installers", "host-specific".to_json()),
              ("updateManifest", "not-configured".to_json()),
            ]),
          ),
        ),
      ]),
    ),
  )
}

///|
fn package_manifest_outcome(
  options : PackageReportOptions,
  json : Bool,
) -> Result[CliOutcome, String] {
  let manifest = match package_manifest_json(options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let text = manifest.stringify(indent=2) + "\n"
  match options.manifest_path {
    Some(path) if !options.dry_run => {
      match mkdir_p(parent_dir(path)) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      match write_file_bytes_result(path, @utf8.encode(text[:], bom=false)) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
    _ => ()
  }
  let output = if json {
    text
  } else {
    let status = match manifest {
      Object(fields) =>
        match fields.get("status") {
          Some(String(value)) => value
          _ => "planned"
        }
      _ => "planned"
    }
    let builder = StringBuilder::new()
    builder.write_string("MoUI package manifest (" + status + ")\n")
    builder.write_string("projectRoot: " + options.project_root + "\n")
    builder.write_string(
      "manifest: " + options.manifest_path.unwrap_or("(stdout)") + "\n",
    )
    builder.write_string("artifacts:\n")
    match manifest {
      Object(fields) =>
        match fields.get("artifacts") {
          Some(Array(items)) =>
            for item in items {
              match item {
                Object(values) =>
                  builder.write_string(
                    "- " +
                    values
                    .get("platform")
                    .map_or("unknown", item => item.stringify()) +
                    " -> " +
                    values
                    .get("outputPath")
                    .map_or("", item => item.stringify()) +
                    "\n",
                  )
                _ => ()
              }
            }
          _ => ()
        }
      _ => ()
    }
    builder.to_string()
  }
  Ok(stdout_outcome(output))
}
