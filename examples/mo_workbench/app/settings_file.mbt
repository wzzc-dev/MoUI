// Portable on-disk settings document (`settings.json.example` template).

///|
pub struct MoWorkbenchSettingsFile {
  openai_api_key : String
  openai_base_url : String
  deepseek_api_key : String
  mo_workbench_workspace : String
  mo_workbench_session_root : String
  approval_policy : String
  sandbox_mode : String
  font_size : Int
  appearance : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn mo_workbench_default_settings_file() -> MoWorkbenchSettingsFile {
  {
    openai_api_key: "",
    openai_base_url: "https://api.deepseek.com/v1",
    deepseek_api_key: "",
    mo_workbench_workspace: ".",
    mo_workbench_session_root: "./.openseek",
    approval_policy: "write",
    sandbox_mode: "workspace",
    font_size: 14,
    appearance: "system",
  }
}

///|
pub type SettingsLoadFn = () -> MoWorkbenchSettingsFile?

///|
pub type SettingsPersistFn = (MoWorkbenchSettingsFile) -> Unit

///|
fn mo_workbench_settings_file_from_workspace(
  settings : SettingsWorkspace,
  appearance : AppearanceMode,
) -> MoWorkbenchSettingsFile {
  {
    openai_api_key: settings.api_key,
    openai_base_url: settings.base_url,
    deepseek_api_key: "",
    mo_workbench_workspace: settings.working_dir,
    mo_workbench_session_root: settings.session_root,
    approval_policy: approval_policy_id(settings.approval_policy),
    sandbox_mode: sandbox_mode_id(settings.sandbox_mode),
    font_size: settings.font_size,
    appearance: appearance_mode_id(appearance),
  }
}

///|
pub fn mo_workbench_decode_settings_file(
  text : String,
) -> MoWorkbenchSettingsFile? {
  let parsed = @json.parse(text) catch { _ => return None }
  let file : MoWorkbenchSettingsFile = @json.from_json(parsed) catch {
    _ => return None
  }
  Some(file)
}

///|
fn SettingsWorkspace::merge_settings_file(
  self : SettingsWorkspace,
  file : MoWorkbenchSettingsFile,
) -> SettingsWorkspace {
  let api_key = if !file.openai_api_key.is_empty() {
    file.openai_api_key
  } else if !file.deepseek_api_key.is_empty() {
    file.deepseek_api_key
  } else {
    self.api_key
  }
  let base_url = if file.openai_base_url.is_empty() {
    self.base_url
  } else {
    file.openai_base_url
  }
  let working_dir = if file.mo_workbench_workspace.is_empty() {
    self.working_dir
  } else {
    file.mo_workbench_workspace
  }
  let session_root = if file.mo_workbench_session_root.is_empty() {
    self.session_root
  } else {
    file.mo_workbench_session_root
  }
  let approval_policy = if file.approval_policy.is_empty() {
    self.approval_policy
  } else {
    approval_policy_from_id(file.approval_policy)
  }
  let sandbox_mode = if file.sandbox_mode.is_empty() {
    self.sandbox_mode
  } else {
    sandbox_mode_from_id(file.sandbox_mode)
  }
  let font_size = if file.font_size < 10 {
    10
  } else if file.font_size > 24 {
    24
  } else {
    file.font_size
  }
  {
    ..self,
    api_key,
    base_url,
    working_dir,
    session_root,
    approval_policy,
    sandbox_mode,
    font_size,
  }
}

///|
fn AppearanceMode::merge_settings_file(
  self : AppearanceMode,
  file : MoWorkbenchSettingsFile,
) -> AppearanceMode {
  if file.appearance.is_empty() {
    self
  } else {
    appearance_mode_from_id(file.appearance)
  }
}

///|
fn appearance_mode_id(mode : AppearanceMode) -> String {
  match mode {
    System => "system"
    Light => "light"
    Dark => "dark"
  }
}

///|
fn appearance_mode_from_id(id : String) -> AppearanceMode {
  match id {
    "light" => AppearanceMode::Light
    "dark" => AppearanceMode::Dark
    _ => AppearanceMode::System
  }
}
