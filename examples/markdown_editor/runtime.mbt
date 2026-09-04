///|
pub fn runtime(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  width? : Double = 1000.0,
  height? : Double = 640.0,
  initial_document_path? : String? = None,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@app.MarkdownEditorApp::new().program(
      environment~,
      initial_document_path~,
    ),
    width~,
    height~,
  )
}

///|
/// Shared environment-flag convention for the platform entrypoints, matching
/// the other desktop examples (e.g. `MOUI_FIRST_FRAME_EXIT=1` smoke runs).
pub fn env_flag(name : String) -> Bool {
  @env.get_env_var(name) == Some("1")
}

///|
pub fn application_menus() -> Array[@services.ApplicationMenu] {
  @app.markdown_editor_application_menus()
}
