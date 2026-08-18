///|
pub fn runtime(
  capabilities~ : @webview_host.HostWebViewCapabilities,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  url? : String = @app.default_url,
  on_navigation_finished? : (String) -> Unit = _ => (),
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@app.program(
      capability=if capabilities.available {
        @app.WebViewCapability::available(description=capabilities.description)
      } else {
        @app.WebViewCapability::unavailable(
          description=capabilities.description,
        )
      },
      environment~,
      url~,
      on_navigation_finished~,
    ),
    width=1280.0,
    height=820.0,
  )
}

///|
pub fn application_menus() -> Array[@services.ApplicationMenu] {
  @app.application_menus()
}

///|
fn run_macos() -> Unit {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let patch = @fs.read_file_to_string(
    "examples/deepseek_harness_desktop/macos_skia/patch.js",
  ) catch {
    _ => ""
  }
  let plugin = @macos_webview.create_macos_webview_plugin(commands)
  let capabilities = @webview_host.HostWebViewCapabilities::native_available(
    description="macOS WKWebView native embedding is available.",
  )
  let environment = @macos_backend.app_environment()
  let runtime = runtime(capabilities~, environment~, on_navigation_finished=_url => {
    if !patch.is_empty() {
      commands.evaluate_javascript(id="dsh-desktop-surface", script=patch)
    }
  })
  let menus = application_menus()
  @runtime.run_app("DSH Desktop", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(
    @macos_backend.entry(
      options=@macos_backend.MacosHostAppOptions::new(
        transparent_titlebar=true,
        platform_view_plugins=[plugin],
        on_ready=Some(@macos_backend.application_menu_on_ready(menus, runtime)),
      ),
    ),
  )
  .run()
}
