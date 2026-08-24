///|
fn ensure_workspace_file(project_root : String) -> Result[String?, String] {
  let path = join_path(project_root, "moon.work")
  if @fs.path_exists(path) {
    return Ok(None)
  }
  match
    replace_file_atomic(path, @utf8.encode(moon_work_text()[:], bom=false)) {
    Ok(_) => Ok(Some("created moon.work"))
    Err(message) => Err(message)
  }
}

///|
fn ensure_readme_file(project_root : String) -> Result[String?, String] {
  let path = join_path(project_root, "README.md")
  if @fs.path_exists(path) {
    return Ok(None)
  }
  let manifest = match read_project_manifest(project_root) {
    Ok(value) => value
    Err(_) => return Ok(None)
  }
  let options : ProjectOptions = {
    target: project_root,
    id: manifest.id,
    module_name: manifest.module_name,
    title: manifest.title,
    moui_version: manifest.moui_version,
    moui_skia_renderer_version: default_moui_skia_renderer_dependency_version,
    template: "counter",
    platforms: manifest.platforms.copy(),
    bundle_id: manifest.bundle_id,
  }
  match
    replace_file_atomic(path, @utf8.encode(readme_text(options)[:], bom=false)) {
    Ok(_) => Ok(Some("created README.md"))
    Err(message) => Err(message)
  }
}

///|
fn apply_doctor_fixes(options : DoctorOptions) -> Result[Array[String], String] {
  let actions : Array[String] = []
  match ensure_workspace_file(options.project_root) {
    Ok(Some(action)) => actions.push(action)
    Ok(None) => ()
    Err(message) => return Err(message)
  }
  match ensure_readme_file(options.project_root) {
    Ok(Some(action)) => actions.push(action)
    Ok(None) => ()
    Err(message) => return Err(message)
  }
  Ok(actions)
}
