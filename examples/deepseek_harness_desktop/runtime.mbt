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
