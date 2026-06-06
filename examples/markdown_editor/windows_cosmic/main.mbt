///|
fn main {
  let app = @markdown_app.MarkdownEditorApp::new()
  let services = @host.HostAppServices::new(
    bridge=@windows_host.windows_service_bridge(),
  )
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)
  @windows_wgpu.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@windows_wgpu.WindowsWgpuAppOptions::new(
      text_engine=@wgpu_renderer.NativeTextEngineSetting::MoonCosmic,
    ),
  )
}
