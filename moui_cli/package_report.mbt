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
  let mobile_path = join_path(options.project_root, "mobile.json")
  if @fs.path_exists(mobile_path) {
    let text = @fs.read_file_to_string(mobile_path) catch {
      _ => return Err("could not read mobile.json: " + mobile_path)
    }
    let parsed = @json.parse(text) catch {
      _ => return Err("mobile.json is invalid JSON")
    }
    guard parsed is Object(root) else {
      return Err("mobile.json root must be an object")
    }
    match root.get("shellApiVersion") {
      Some(Number(value, repr=_)) =>
        builder.write_string(
          "shellApiVersion: " + value.to_int().to_string() + "\n",
        )
      _ => builder.write_string("shellApiVersion: (missing)\n")
    }
    match root.get("runtimeAbiVersion") {
      Some(Number(value, repr=_)) =>
        builder.write_string(
          "runtimeAbiVersion: " + value.to_int().to_string() + "\n",
        )
      _ => builder.write_string("runtimeAbiVersion: (missing)\n")
    }
    match root.get("mobile") {
      Some(Object(mobile)) =>
        match mobile.get("plugins") {
          Some(Array(values)) =>
            builder.write_string(
              "plugins: " + values.length().to_string() + "\n",
            )
          _ => builder.write_string("plugins: 0\n")
        }
      _ => builder.write_string("plugins: 0\n")
    }
  } else {
    builder.write_string("mobile.json: (absent)\n")
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
  let mobile_path = join_path(options.project_root, "mobile.json")
  if @fs.path_exists(mobile_path) {
    let text = @fs.read_file_to_string(mobile_path) catch {
      _ => return Err("could not read mobile.json: " + mobile_path)
    }
    let parsed = @json.parse(text) catch {
      _ => return Err("mobile.json is invalid JSON")
    }
    root["mobile"] = parsed
  }
  Ok(Json::object(root).stringify(indent=2) + "\n")
}
