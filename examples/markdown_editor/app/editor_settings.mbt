///|
/// Persisted editor preferences. Stored as JSON in a fixed settings path next
/// to the app so appearance, theme and panel state survive restarts.
pub struct MarkdownEditorSettings {
  dark_mode : Bool
  font_family : String
  writing_appearance : String
  focus_mode : Bool
  typewriter_mode : Bool
  zen_mode : Bool
  source_preview : Bool
  outline : Bool
  files : Bool
  document_info : Bool
} derive(Eq, Debug, ToJson, FromJson)

///|
fn MarkdownEditorSettings::default() -> MarkdownEditorSettings {
  {
    dark_mode: false,
    font_family: "Sans",
    writing_appearance: "Paper",
    focus_mode: false,
    typewriter_mode: false,
    zen_mode: false,
    source_preview: false,
    outline: false,
    files: false,
    document_info: false,
  }
}

///|
/// App-facing settings key. Platform adapters own its persistent location.
let markdown_editor_settings_key : String = "markdown-editor/preferences"

///|
/// Load settings through the typed app-facing service boundary.
fn markdown_editor_request_settings_load(
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  services
  .settings()
  .read(markdown_editor_settings_key)
  .effect(map=result => ServiceCompleted(SettingsLoaded(result)))
}

///|
/// Parse and decode a settings JSON string, falling back to defaults on any
/// error. Kept separate so the raise-based json API is contained in one place.
fn markdown_editor_decode_settings(text : String) -> MarkdownEditorSettings {
  let parsed = @json.parse(text) catch {
    _ => return MarkdownEditorSettings::default()
  }
  let settings : MarkdownEditorSettings = @json.from_json(parsed) catch {
    _ => return MarkdownEditorSettings::default()
  }
  settings
}

///|
/// Serialize the current preferences as a typed, cancellable service effect.
fn MarkdownEditorApp::request_settings_save(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let settings : MarkdownEditorSettings = {
    dark_mode: self.dark_mode_enabled,
    font_family: markdown_editor_font_family_label(self.font_family),
    writing_appearance: self.appearance_label(),
    focus_mode: self.focus_mode_enabled,
    typewriter_mode: self.typewriter_mode_enabled,
    zen_mode: self.zen_mode_enabled,
    source_preview: self.source_preview_visible,
    outline: self.outline_visible,
    files: self.file_sidebar_visible,
    document_info: self.document_info_visible,
  }
  let text = ToJson::to_json(settings).stringify(indent=2)
  services
  .settings()
  .write(markdown_editor_settings_key, text)
  .effect(map=result => ServiceCompleted(SettingsSaved(result)))
}

///|
/// Apply persisted settings onto a freshly-constructed app. Called once during
/// construction when host services are available.
fn MarkdownEditorApp::apply_settings(
  self : MarkdownEditorApp,
  settings : MarkdownEditorSettings,
) -> Unit {
  self.dark_mode_enabled = settings.dark_mode
  self.font_family = markdown_editor_font_family_from_label(
    settings.font_family,
  )

  self.focus_mode_enabled = settings.focus_mode
  self.typewriter_mode_enabled = settings.typewriter_mode
  self.zen_mode_enabled = settings.zen_mode
  self.source_preview_visible = settings.source_preview
  self.outline_visible = settings.outline
  self.file_sidebar_visible = settings.files
  self.document_info_visible = settings.document_info
  match settings.writing_appearance {
    "Warm" => self.set_writing_appearance(WarmAppearance)
    "Wide" => self.set_writing_appearance(WideAppearance)
    _ => self.set_writing_appearance(PaperAppearance)
  }
}

///|
fn markdown_editor_font_family_label(
  family : MarkdownEditorFontFamily,
) -> String {
  match family {
    SansFont => "Sans"
    SerifFont => "Serif"
    MonoFont => "Mono"
  }
}

///|
fn markdown_editor_font_family_from_label(
  label : String,
) -> MarkdownEditorFontFamily {
  match label {
    "Serif" => SerifFont
    "Mono" => MonoFont
    _ => SansFont
  }
}
