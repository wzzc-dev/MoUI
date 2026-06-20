///|
/// Persisted editor preferences. Stored as JSON in a fixed settings path next
/// to the app so appearance, theme and panel state survive restarts.
pub struct MarkdownEditorSettings {
  dark_mode : Bool
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
/// The host-side path used to persist settings. Each platform backend can
/// resolve this against its own config directory; the app treats it as opaque.
let markdown_editor_settings_path : String = "moui-markdown-editor-settings.json"

///|
/// Load settings from the host. Returns the default settings when the host is
/// unavailable or the file is missing/corrupt, so the editor always starts in a
/// known state.
fn markdown_editor_load_settings(
  services : @host.HostAppServices,
) -> MarkdownEditorSettings {
  let response = services.read_text_file(markdown_editor_settings_path)
  match response {
    @host.HostServiceResponse::TextFileContent(_path, text) =>
      markdown_editor_decode_settings(text)
    _ => MarkdownEditorSettings::default()
  }
}

///|
/// Parse and decode a settings JSON string, falling back to defaults on any
/// error. Kept separate so the raise-based json API is contained in one place.
fn markdown_editor_decode_settings(
  text : String,
) -> MarkdownEditorSettings {
  let parsed = @json.parse(text) catch {
    _ => return MarkdownEditorSettings::default()
  }
  let settings : MarkdownEditorSettings = try @json.from_json(parsed) catch {
    _ => return MarkdownEditorSettings::default()
  }
  settings
}

///|
/// Serialize the app's current preferences and write them to the settings path.
/// Failures are swallowed — persistence is best-effort and must never block the
/// editor.
fn MarkdownEditorApp::save_settings(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  let settings : MarkdownEditorSettings = {
    dark_mode: self.dark_mode_enabled.get(),
    writing_appearance: self.appearance_label(),
    focus_mode: self.focus_mode_enabled.get(),
    typewriter_mode: self.typewriter_mode_enabled.get(),
    zen_mode: self.zen_mode_enabled.get(),
    source_preview: self.source_preview_visible.get(),
    outline: self.outline_visible.get(),
    files: self.file_sidebar_visible.get(),
    document_info: self.document_info_visible.get(),
  }
  let text = settings.to_json().stringify(indent=2)
  let _ = services.write_text_file(markdown_editor_settings_path, text)
}

///|
/// Apply persisted settings onto a freshly-constructed app. Called once during
/// construction when host services are available.
fn MarkdownEditorApp::apply_settings(
  self : MarkdownEditorApp,
  settings : MarkdownEditorSettings,
) -> Unit {
  self.dark_mode_enabled.set(settings.dark_mode)
  self.focus_mode_enabled.set(settings.focus_mode)
  self.typewriter_mode_enabled.set(settings.typewriter_mode)
  self.zen_mode_enabled.set(settings.zen_mode)
  self.source_preview_visible.set(settings.source_preview)
  self.outline_visible.set(settings.outline)
  self.file_sidebar_visible.set(settings.files)
  self.document_info_visible.set(settings.document_info)
  match settings.writing_appearance {
    "Warm" => self.set_writing_appearance(WarmAppearance)
    "Wide" => self.set_writing_appearance(WideAppearance)
    _ => self.set_writing_appearance(PaperAppearance)
  }
}
