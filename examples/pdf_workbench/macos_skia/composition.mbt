///|
fn pdf_workbench_runtime() -> @runtime.AppRuntime {
  let app = @app.PdfWorkbenchApp::new()
  @runtime.new_program_with_dimensions(
    program=app.program(
      environment=@macos_host.app_environment(),
      raster_services=@pdfium_adapter.raster_services(),
      document_services=pdf_workbench_document_services(),
      startup_pdf_path=pdf_workbench_startup_pdf_path(),
    ),
    width=1120.0,
    height=720.0,
  )
}

///|
fn pdf_workbench_startup_pdf_path() -> String {
  match @env.get_env_var("MOUI_PDF_WORKBENCH_STARTUP_PDF") {
    Some(path) => path
    None => ""
  }
}

///|
fn pdf_workbench_document_services() -> @app.PdfWorkbenchDocumentServices {
  match
    @pdflite_transport.PdfWorkbenchPdfliteNativeTransportEnvConfig::new(
      helper_path=pdf_workbench_env_var("MOUI_PDF_WORKBENCH_PDFLITE_HELPER"),
      helper_args=pdf_workbench_env_var(
        "MOUI_PDF_WORKBENCH_PDFLITE_HELPER_ARGS",
      ),
      helper_cwd=pdf_workbench_env_var("MOUI_PDF_WORKBENCH_PDFLITE_HELPER_CWD"),
    ).transport_config() {
    Some(config) => config.document_services()
    None => @app.PdfWorkbenchDocumentServices::lightweight()
  }
}

///|
fn pdf_workbench_env_var(name : String) -> String {
  match @env.get_env_var(name) {
    Some(value) => value
    None => ""
  }
}
