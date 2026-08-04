///|

///|
pub fn ShowcaseApp::program(
  self : ShowcaseApp,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  ignore(self)
  ShowcaseModel::new().program()
}

///|
pub fn ShowcaseApp::program_with_environment(
  self : ShowcaseApp,
  diagnostics_input? : @diagnostics.ShowcaseDiagnosticsInput = @diagnostics.ShowcaseDiagnosticsInput::fallback(),
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  route? : String = ShowcaseRoute::default().format(),
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  ignore(self)
  ShowcaseModel::new(diagnostics_input~, route~).program_with_environment(
    environment,
  )
}

///|
pub fn ShowcaseApp::program_with_initial_route(
  self : ShowcaseApp,
  route : String,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  ignore(self)
  ShowcaseModel::new(route~).program()
}

///|
pub fn ShowcaseModel::program(
  self : ShowcaseModel,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  self.program_with_environment(@services.AppEnvironment::new())
}

///|
pub fn ShowcaseModel::program_with_environment(
  self : ShowcaseModel,
  environment : @services.AppEnvironment,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  self.program_with_optional_route_host(None, environment)
}

///|
pub fn ShowcaseModel::program_with_route_host(
  self : ShowcaseModel,
  route_host : ShowcaseRouteHost,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  self.program_with_optional_route_host(Some(route_host), environment)
}

///|
fn ShowcaseModel::program_with_optional_route_host(
  self : ShowcaseModel,
  route_host : ShowcaseRouteHost?,
  environment : @services.AppEnvironment,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  @moui.Program::new_with_environment(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => {
      model.update_with_environment(message, route_host, environment.services())
    },
    view=(model, env) => model.view(env),
    subscriptions=model => {
      model.subscriptions(route_host~, timer_source=environment.timer())
    },
  ).with_commands(commands=_model => {
    @platform.program_commands().map(command => {
      command.map(msg => PlatformMsg(msg))
    })
  })
}

///|
pub fn ShowcaseModel::update_with_effect(
  self : ShowcaseModel,
  message : ShowcaseMsg,
  route_host? : ShowcaseRouteHost? = None,
) -> (ShowcaseModel, @moui.Effect[ShowcaseMsg]) {
  self.update_with_environment(
    message,
    route_host,
    @services.AppServices::unavailable(),
  )
}

///|
pub fn ShowcaseModel::subscriptions(
  self : ShowcaseModel,
  route_host? : ShowcaseRouteHost? = None,
  timer_source? : @services.TimerSource? = None,
) -> @moui.Subscription[ShowcaseMsg] {
  showcase_subscriptions(self, route_host, timer_source)
}

///|
fn showcase_subscriptions(
  model : ShowcaseModel,
  route_host : ShowcaseRouteHost?,
  timer_source : @services.TimerSource?,
) -> @moui.Subscription[ShowcaseMsg] {
  let subs = [
    @components.subscriptions(model.components).map(msg => ComponentsMsg(msg)),
    @patterns.subscriptions(model.patterns).map(msg => PatternsMsg(msg)),
    // Platform timers stay mapped even when another workspace is visible.
    @platform.subscriptions(model.platform, timer_source~).map(msg => {
      PlatformMsg(msg)
    }),
    @diagnostics.subscriptions(model.diagnostics).map(msg => DiagnosticsMsg(msg)),
  ]
  let host_route = match route_host {
    Some(host) =>
      host.route_source.subscription(
        key="showcase:host-route",
        label="Showcase host route",
        map=event => Some(HostRouteChanged(event)),
      )
    None => @moui.Subscription::none()
  }
  @moui.Subscription::batch([..subs, host_route])
}
