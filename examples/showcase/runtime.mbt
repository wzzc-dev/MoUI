///|
/// Integration-only Showcase assembly. Platform entrypoints provide concrete
/// environment and diagnostic DTO sources; app state remains platform-neutral.
pub fn runtime(
  host_summary~ : @host.HostCapabilitySummary,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  renderer_providers? : Array[@render.RendererProvider] = [],
  route? : String = @app.ShowcaseRoute::default().format(),
  route_host? : @app.ShowcaseRouteHost? = None,
  initial_section_code? : Int = 0,
  width? : Double = 1100.0,
  height? : Double = 680.0,
) -> @runtime.AppRuntime {
  let diagnostics_input = diagnostics_input(host_summary, renderer_providers)
  let model = @app.ShowcaseModel::new(diagnostics_input~, route~)
  let model = if initial_section_code == 1 {
    model.update(@app.ShowcaseMsg::Navigate("diagnostics/advanced-rendering"))
  } else if initial_section_code == 2 {
    model.update(@app.ShowcaseMsg::Navigate("components/accessibility-probe"))
  } else {
    model
  }
  let program = match route_host {
    Some(host) => model.program_with_route_host(host, environment~)
    None => model.program_with_environment(environment)
  }
  @runtime.new_program_with_dimensions(program~, width~, height~)
}

///|
pub fn route_host(
  source~ : @services.RouteSource,
  push~ : (String) -> Unit,
  replace~ : (String) -> Unit,
  back~ : () -> Unit,
  forward~ : () -> Unit,
) -> @app.ShowcaseRouteHost {
  @app.ShowcaseRouteHost::new(route_source=source, dispatch_command=command => {
    match command {
      @app.ShowcaseRouteHistoryCommand::PushRoute(route) => push(route)
      @app.ShowcaseRouteHistoryCommand::ReplaceRoute(route) => replace(route)
      @app.ShowcaseRouteHistoryCommand::BackRoute => back()
      @app.ShowcaseRouteHistoryCommand::ForwardRoute => forward()
    }
  })
}

///|
pub fn env_flag(name : String) -> Bool {
  @env.get_env_var(name) == Some("1")
}
