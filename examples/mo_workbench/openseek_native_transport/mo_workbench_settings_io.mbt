// Load / persist `.mo_workbench/settings.json` (template: `settings.json.example`).

///|
fn mo_workbench_settings_dir() -> String {
  ".mo_workbench"
}

///|
fn mo_workbench_settings_file_path() -> String {
  mo_workbench_settings_dir() + "/settings.json"
}

///|
fn mo_workbench_settings_template_paths() -> Array[String] {
  [
    mo_workbench_settings_dir() + "/settings.json.example",
    "examples/mo_workbench/settings.json.example",
    "settings.json.example",
  ]
}

///|
fn mo_workbench_settings_write_path() -> String {
  match @env.get_env_var("MO_WORKBENCH_SETTINGS_FILE") {
    Some(path) => {
      let trimmed = path.trim().to_owned()
      if trimmed.is_empty() {
        mo_workbench_settings_file_path()
      } else {
        trimmed
      }
    }
    None => mo_workbench_settings_file_path()
  }
}

///|
pub fn mo_workbench_ensure_settings_file() -> Unit {
  let path = mo_workbench_settings_file_path()
  if @fs.path_exists(path) {
    return
  }
  mo_workbench_ensure_parent_dir(path)
  let file = @app.mo_workbench_default_settings_file()
  let text = file.to_json().stringify(indent=2)
  @fs.write_string_to_file(path, text) catch {
    _ => ()
  }
}

///|
pub fn mo_workbench_load_settings_file() -> @app.MoWorkbenchSettingsFile? {
  mo_workbench_ensure_settings_file()
  let primary = mo_workbench_settings_write_path()
  if primary != mo_workbench_settings_file_path() {
    match mo_workbench_read_settings_text(primary) {
      Some(text) =>
        match @app.mo_workbench_decode_settings_file(text) {
          Some(file) => return Some(file)
          None => ()
        }
      None => ()
    }
  }
  match mo_workbench_read_settings_text(mo_workbench_settings_file_path()) {
    Some(text) =>
      match @app.mo_workbench_decode_settings_file(text) {
        Some(file) => return Some(file)
        None => ()
      }
    None => ()
  }
  for path in mo_workbench_settings_template_paths() {
    match mo_workbench_read_settings_text(path) {
      Some(text) =>
        match @app.mo_workbench_decode_settings_file(text) {
          Some(file) => return Some(file)
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
pub fn mo_workbench_persist_settings_file(
  file : @app.MoWorkbenchSettingsFile,
) -> Unit {
  let path = mo_workbench_settings_write_path()
  mo_workbench_ensure_parent_dir(path)
  let text = file.to_json().stringify(indent=2)
  @fs.write_string_to_file(path, text) catch {
    _ => ()
  }
}

///|
fn mo_workbench_ensure_parent_dir(_path : String) -> Unit {
  let dir = mo_workbench_settings_dir()
  if !@fs.path_exists(dir) {
    @fs.create_dir(dir) catch {
      _ => ()
    }
  }
}

///|
fn mo_workbench_read_settings_text(path : String) -> String? {
  if !@fs.path_exists(path) {
    return None
  }
  Some(@fs.read_file_to_string(path) catch { _ => return None })
}

///|
pub fn mo_workbench_apply_settings_file_to_process_env(
  file : @app.MoWorkbenchSettingsFile,
) -> Unit {
  let provider = match file.active_provider_id {
    Some(id) => {
      let matching = file.providers.filter(fn(p) { p.id == id })
      if matching.is_empty() {
        None
      } else {
        Some(matching[0])
      }
    }
    None =>
      if file.providers.is_empty() {
        None
      } else {
        Some(file.providers[0])
      }
  }
  match provider {
    Some(p) => {
      if !p.api_key.is_empty() {
        @env.set_env_var("OPENAI_API_KEY", p.api_key)
      }
      if !p.base_url.is_empty() {
        @env.set_env_var("OPENAI_BASE_URL", p.base_url)
      }
    }
    None => ()
  }
  if !file.mo_workbench_workspace.is_empty() {
    @env.set_env_var("MO_WORKBENCH_WORKSPACE", file.mo_workbench_workspace)
  }
  if !file.mo_workbench_session_root.is_empty() {
    @env.set_env_var(
      "MO_WORKBENCH_SESSION_ROOT",
      file.mo_workbench_session_root,
    )
  }
}
