///|
pub fn runtime(
  commands~ : @webview_host.HostWebViewCommandQueue,
  capabilities~ : @webview_host.HostWebViewCapabilities,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@app.program(
      command_sink=command => dispatch_command(commands, command),
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
fn dispatch_command(
  commands : @webview_host.HostWebViewCommandQueue,
  command : @app.WebViewCommand,
) -> Unit {
  match command {
    LoadUrl(url) => commands.load_url(id="webview-demo-main", url~)
    Reload => commands.reload(id="webview-demo-main")
    Stop => commands.stop(id="webview-demo-main")
    GoBack => commands.go_back(id="webview-demo-main")
    GoForward => commands.go_forward(id="webview-demo-main")
    EvaluateJavaScript(script, request_id) =>
      commands.evaluate_javascript(id="webview-demo-main", script~, request_id~)
  }
}
