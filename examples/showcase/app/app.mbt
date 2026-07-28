///|

///|
/// Host keyboard shortcut map from the Platform workspace (meta/ctrl+T demo).
pub fn action_command_map() -> @views.ActionCommandMap {
  @platform.action_command_map()
}

///|
pub fn ShowcaseApp::program(
  self : ShowcaseApp,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  ignore(self)
  ShowcaseModel::new().program()
}

///|
pub fn ShowcaseApp::program_with_host_summary(
  self : ShowcaseApp,
  host_summary : @host.HostCapabilitySummary,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  ignore(self)
  ShowcaseModel::new(host_summary~).with_host_summary(host_summary).program()
}

///|
/// Preferred desktop host assembly: capability summary + platform adapters.
pub fn ShowcaseApp::program_with_host(
  self : ShowcaseApp,
  host_summary : @host.HostCapabilitySummary,
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
  timer_source? : @runtime.HostTimerSource? = None,
  window_events? : @runtime.HostWindowEventSource? = None,
  route? : String = ShowcaseRoute::default().format(),
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  ignore(self)
  ShowcaseModel::new(host_summary~, route~)
  .with_host_summary(host_summary)
  .with_platform_host(services~, timer_source~, window_events~)
  .program()
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
  self.program_with_optional_route_host(None)
}

///|
pub fn ShowcaseModel::program_with_route_host(
  self : ShowcaseModel,
  route_host : ShowcaseRouteHost,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  self.program_with_optional_route_host(Some(route_host))
}

///|
fn ShowcaseModel::program_with_optional_route_host(
  self : ShowcaseModel,
  route_host : ShowcaseRouteHost?,
) -> @moui.Program[ShowcaseModel, ShowcaseMsg] {
  @moui.Program::new_with_environment(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => model.update_with_effect(message, route_host~),
    view=(model, env) => model.view(env),
    subscriptions=model => model.subscriptions(route_host~),
  )
}

///|
pub fn ShowcaseModel::update_with_effect(
  self : ShowcaseModel,
  message : ShowcaseMsg,
  route_host? : ShowcaseRouteHost? = None,
) -> (ShowcaseModel, @moui.Effect[ShowcaseMsg]) {
  self.update_with_route_host(message, route_host)
}

///|
pub fn ShowcaseModel::subscriptions(
  self : ShowcaseModel,
  route_host? : ShowcaseRouteHost? = None,
) -> @moui.Subscription[ShowcaseMsg] {
  showcase_subscriptions(self, route_host)
}

///|
fn showcase_subscriptions(
  model : ShowcaseModel,
  route_host : ShowcaseRouteHost?,
) -> @moui.Subscription[ShowcaseMsg] {
  let subs = [
    @components.subscriptions(model.components).map(msg => ComponentsMsg(msg)),
    @patterns.subscriptions(model.patterns).map(msg => PatternsMsg(msg)),
    // Platform timer / pending-service subscriptions stay mapped even when
    // another workspace is visible so lifecycle is package-owned.
    @platform.subscriptions(model.platform).map(msg => PlatformMsg(msg)),
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
