// Portable on-disk settings document (`settings.json.example` template).

///|
/// One persisted provider (OpenAI-compatible). Mirrors `ProviderConfig`.
pub struct MoProviderFile {
  id : String
  name : String
  base_url : String
  api_key : String
  models : Array[String]
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Portable on-disk settings document (`settings.json.example` template).
/// Providers replace the previous single `openai_api_key`/`openai_base_url`
/// pair so multiple vendors can be configured and switch between.
pub struct MoWorkbenchSettingsFile {
  providers : Array[MoProviderFile]
  active_provider_id : String?
  current_model : String
  mo_workbench_workspace : String
  mo_workbench_session_root : String
  approval_policy : String
  sandbox_mode : String
  font_size : Int
  appearance : String
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Legacy single-provider layout, kept only for migration of old files.
struct MoWorkbenchSettingsFileLegacy {
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
    providers: [
      {
        id: "deepseek",
        name: "DeepSeek",
        base_url: "https://api.deepseek.com/v1",
        api_key: "",
        models: ["deepseek-v4-flash", "deepseek-v4-pro"],
      },
      {
        id: "openai",
        name: "OpenAI",
        base_url: "https://api.openai.com/v1",
        api_key: "",
        models: ["gpt-4o", "gpt-4o-mini"],
      },
    ],
    active_provider_id: Some("deepseek"),
    current_model: "deepseek-v4-flash",
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
  current_model : String,
) -> MoWorkbenchSettingsFile {
  let providers : Array[MoProviderFile] = []
  for p in settings.providers {
    providers.push({
      id: p.id,
      name: p.name,
      base_url: p.base_url,
      api_key: p.api_key,
      models: p.models,
    })
  }
  {
    providers,
    active_provider_id: settings.active_provider_id,
    current_model,
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
  // `from_json` returns the decoded value directly and raises `JsonDecodeError`
  // on any mismatch, so we wrap each attempt in `try`. Prefer the modern
  // multi-provider layout; fall back to the legacy single-provider migration.
  try {
    let file : MoWorkbenchSettingsFile = @json.from_json(parsed)
    Some(file)
  } catch {
    _ =>
      try {
        let legacy : MoWorkbenchSettingsFileLegacy = @json.from_json(parsed)
        Some(migrate_legacy_settings(legacy))
      } catch {
        _ => None
      }
  }
}

///|
fn migrate_legacy_settings(
  legacy : MoWorkbenchSettingsFileLegacy,
) -> MoWorkbenchSettingsFile {
  let api_key = if !legacy.openai_api_key.is_empty() {
    legacy.openai_api_key
  } else {
    legacy.deepseek_api_key
  }
  let base_url = if legacy.openai_base_url.is_empty() {
    "https://api.deepseek.com/v1"
  } else {
    legacy.openai_base_url
  }
  {
    providers: [
      {
        id: "deepseek",
        name: "DeepSeek",
        base_url,
        api_key,
        models: ["deepseek-v4-flash", "deepseek-v4-pro"],
      },
    ],
    active_provider_id: Some("deepseek"),
    current_model: "deepseek-v4-flash",
    mo_workbench_workspace: legacy.mo_workbench_workspace,
    mo_workbench_session_root: legacy.mo_workbench_session_root,
    approval_policy: legacy.approval_policy,
    sandbox_mode: legacy.sandbox_mode,
    font_size: legacy.font_size,
    appearance: legacy.appearance,
  }
}

///|
fn SettingsWorkspace::merge_settings_file(
  self : SettingsWorkspace,
  file : MoWorkbenchSettingsFile,
) -> SettingsWorkspace {
  // Merge providers: file entries override matching ids, new ids are appended.
  let merged : Array[ProviderConfig] = []
  for p in self.providers {
    merged.push(p)
  }
  for fp in file.providers {
    let cfg = ProviderConfig::new(
      id=fp.id,
      name=fp.name,
      base_url=fp.base_url,
      api_key=fp.api_key,
      models=fp.models,
    )
    match self.provider_index(fp.id) {
      Some(i) => merged[i] = cfg
      None => merged.push(cfg)
    }
  }
  let providers = if merged.is_empty() { default_providers() } else { merged }
  let first_id = if providers.is_empty() { None } else { Some(providers[0].id) }
  let active_provider_id = match file.active_provider_id {
    Some(id) =>
      if !providers.filter(fn(p) { p.id == id }).is_empty() {
        Some(id)
      } else {
        first_id
      }
    None => first_id
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
    providers,
    active_provider_id,
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
