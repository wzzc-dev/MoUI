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
pub fn application_menus() -> Array[@services.ApplicationMenu] {
  @app.markdown_editor_application_menus()
}
