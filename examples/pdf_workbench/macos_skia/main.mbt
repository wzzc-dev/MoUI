///|
fn main {
  let app = @app.PdfWorkbenchApp::new()
  let services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )
  let runtime = app.runtime_with_services(
    services,
    raster_services=@pdfium_adapter.raster_services(),
    document_services=pdf_workbench_document_services(),
    startup_pdf_path=pdf_workbench_startup_pdf_path(),
    width=1120.0,
    height=720.0,
  )
  let exit_after_first_present = @env.get_env_var(
      "MOUI_PDF_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  let font_resolution = if exit_after_first_present {
    @skia_renderer.SkiaFontResolution::EmptyTypeface
  } else {
    @skia_renderer.SkiaFontResolution::SystemFontMgr
  }
  @macos_skia_backend.run_app_with_options(
    "MoUI PDF Workbench",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      font_resolution~,
      exit_after_first_present~,
    ),
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
    Some(config) => {
      println("pdf workbench: pdflite helper " + config.command_label())
      config.document_services()
    }
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
