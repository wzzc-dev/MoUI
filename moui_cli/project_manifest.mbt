///|
fn manifest_json(manifest : ProjectManifest) -> Json {
  let root : Map[String, Json] = Map([
    ("schemaVersion", manifest.schema_version.to_json()),
    ("id", manifest.id.to_json()),
    ("title", manifest.title.to_json()),
    ("module", manifest.module_name.to_json()),
    ("mouiVersion", manifest.moui_version.to_json()),
    ("platforms", manifest.platforms.to_json()),
  ])
  match manifest.bundle_id {
    Some(value) => root["bundleId"] = value.to_json()
    None => ()
  }
  Json::object(root)
}

///|
fn ProjectManifest::to_json_text(self : ProjectManifest) -> String {
  manifest_json(self).stringify(indent=2) + "\n"
}

///|
fn required_json_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(String(value)) if value != "" => Ok(value)
    _ => Err("moui.project.json is missing string field: " + key)
  }
}

///|
fn parse_project_manifest(text : String) -> Result[ProjectManifest, String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("moui.project.json is invalid JSON")
  }
  guard parsed is Object(fields) else {
    return Err("moui.project.json root must be an object")
  }
  guard fields.get("schemaVersion") is Some(Number(1.0, repr=_)) else {
    return Err("moui.project.json schemaVersion must be 1")
  }
  let id = match required_json_string(fields, "id") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let title = match required_json_string(fields, "title") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let module_name = match required_json_string(fields, "module") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let moui_version = match required_json_string(fields, "mouiVersion") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let platforms = match fields.get("platforms") {
    Some(Array(values)) => {
      let result : Array[String] = []
      for value in values {
        match value {
          String(name) => result.push(name)
          _ => return Err("moui.project.json platforms must contain strings")
        }
      }
      result
    }
    _ => return Err("moui.project.json is missing array field: platforms")
  }
  let bundle_id = match fields.get("bundleId") {
    Some(String(value)) => Some(value)
    Some(_) => return Err("moui.project.json bundleId must be a string")
    None => None
  }
  let manifest : ProjectManifest = {
    schema_version: 1,
    id,
    title,
    module_name,
    moui_version,
    platforms,
    bundle_id,
  }
  let options : ProjectOptions = {
    target: ".",
    id: manifest.id,
    module_name: manifest.module_name,
    title: manifest.title,
    moui_version: manifest.moui_version,
    moui_skia_renderer_version: default_moui_skia_renderer_dependency_version,
    template: "counter",
    platforms: manifest.platforms,
    bundle_id: manifest.bundle_id,
  }
  match validate_project_options(options) {
    Ok(_) => ()
    Err(message) => return Err("moui.project.json is invalid: " + message)
  }
  if manifest.platforms.is_empty() {
    return Err("moui.project.json platforms must not be empty")
  }
  let seen : Map[String, Bool] = Map([])
  for platform in manifest.platforms {
    if seen.contains(platform) {
      return Err("moui.project.json contains duplicate platform: " + platform)
    }
    seen[platform] = true
  }
  Ok(manifest)
}

///|
fn read_project_manifest(
  project_root : String,
) -> Result[ProjectManifest, String] {
  let path = join_path(project_root, "moui.project.json")
  if !@fs.path_exists(path) {
    return Err("project manifest not found: " + path)
  }
  let text = @fs.read_file_to_string(path) catch {
    _ => return Err("could not read project manifest: " + path)
  }
  parse_project_manifest(text)
}
