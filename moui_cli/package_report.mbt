///|
fn package_report_text(
  options : PackageReportOptions,
) -> Result[String, String] {
  let manifest = match read_project_manifest(options.project_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let builder = StringBuilder()
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
    ("schemaVersion", Json((1 : Int32))),
    ("ok", Json(true)),
    ("command", Json("package")),
    ("projectRoot", Json(options.project_root)),
    ("id", Json(manifest.id)),
    ("module", Json(manifest.module_name)),
    ("title", Json(manifest.title)),
    ("mouiVersion", Json(manifest.moui_version)),
    ("platforms", Json(manifest.platforms)),
  ])
  match manifest.bundle_id {
    Some(value) => root["bundleId"] = Json(value)
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
          ("platform", Json(platform)),
          ("outputKind", Json(package_output_kind(platform))),
          ("outputPath", Json(output_path)),
          ("buildRequested", Json(options.build)),
          (
            "signing",
            Json::object(
              Map([
                ("status", Json("host-required")),
                ("signature", Json::null()),
              ]),
            ),
          ),
          (
            "notarization",
            Json::object(Map([("status", Json("host-required"))])),
          ),
          ("installer", Json::object(Map([("status", Json("host-specific"))]))),
          (
            "updateManifest",
            Json::object(Map([("status", Json("not-configured"))])),
          ),
        ]),
      ),
    )
  }
  Ok(
    Json::object(
      Map([
        ("schemaVersion", Json((1 : Int32))),
        ("ok", Json(true)),
        ("command", Json("package")),
        (
          "status",
          Json(
            if options.dry_run {
              "dry-run"
            } else if options.build {
              "build-requested"
            } else {
              "planned"
            },
          ),
        ),
        ("projectRoot", Json(options.project_root)),
        (
          "project",
          Json::object(
            Map([
              ("id", Json(project.id)),
              ("title", Json(project.title)),
              ("module", Json(project.module_name)),
              ("mouiVersion", Json(project.moui_version)),
              (
                "bundleId",
                match project.bundle_id {
                  Some(value) => Json(value)
                  None => Json::null()
                },
              ),
            ]),
          ),
        ),
        ("version", Json(version)),
        ("platforms", Json(platforms)),
        ("artifacts", Json(artifacts)),
        (
          "release",
          Json::object(
            Map([
              ("signing", Json("host-required")),
              ("notarization", Json("host-required")),
              ("installers", Json("host-specific")),
              ("updateManifest", Json("not-configured")),
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
    let builder = StringBuilder()
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
