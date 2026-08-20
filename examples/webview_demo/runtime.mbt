///|
pub fn runtime(
  controller~ : @webview_host.WebViewController,
  capabilities~ : @webview_host.HostWebViewCapabilities,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@app.program(
      controller=Some(controller),
      capability=if capabilities.available {
        @app.WebViewCapability::available(description=capabilities.description)
      } else {
        @app.WebViewCapability::unavailable(
          description=capabilities.description,
        )
      },
    ),
    width=1120.0,
    height=760.0,
  )
}

///|
pub fn create_controller() -> (
  @webview_host.WebViewHost,
  @webview_host.WebViewController,
) {
  let host = @webview_host.WebViewHost::new()
  let origin = @webview_host.WebViewOrigin::parse(@app.default_url).unwrap()
  let security = @webview_host.WebViewSecurityPolicy::new(allowed_origins=[
    origin,
  ])
  let controller = host
    .create_controller(
      id="webview-demo-main",
      config=@webview_host.WebViewControllerConfig::new(security~),
    )
    .unwrap()
  (host, controller)
}
