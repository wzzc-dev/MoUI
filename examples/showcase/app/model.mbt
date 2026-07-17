///|
pub struct ShowcaseApp {
  unit : Unit
}

///|
/// Root TEA model: owns four workspace models and the single product shell.
pub(all) struct ShowcaseModel {
  workspace : Workspace
  route_id : String
  route_history : @views.RouteHistoryState
  nav_query : String
  /// Mobile list/detail: false shows the catalog list for the workspace.
  mobile_showing_detail : Bool
  /// Left-rail story list scroll (desktop) / mobile catalog scroll.
  sidebar_scroll : @state.ScrollState
  /// Right-hand detail canvas scroll.
  detail_scroll : @state.ScrollState
  host_summary : @host.HostCapabilitySummary
  components : @components.ComponentGalleryModel
  patterns : @patterns.Model
  platform : @platform.Model
  diagnostics : @diagnostics.ShowcaseModel
}

///|
pub(all) enum ShowcaseMsg {
  Navigate(String)
  RouteBack
  RouteForward
  OpenRouteLink(String)
  HostRouteChanged(@host.HostRouteEvent)
  SelectWorkspace(Workspace)
  NavQueryChanged(String)
  ShowMobileCatalog
  ComponentsMsg(@components.ComponentGalleryMsg)
  PatternsMsg(@patterns.Msg)
  PlatformMsg(@platform.Msg)
  DiagnosticsMsg(@diagnostics.ShowcaseMsg)
}

///|
pub(all) enum ShowcaseRouteHistoryCommand {
  PushRoute(String)
  ReplaceRoute(String)
  BackRoute
  ForwardRoute
} derive(Eq, Debug, ToJson)

///|
pub struct ShowcaseRouteHost {
  route_source : @host.HostRouteSource
  dispatch_command : (ShowcaseRouteHistoryCommand) -> Unit
}

///|
pub fn ShowcaseApp::new() -> ShowcaseApp {
  { unit: () }
}

///|
pub fn ShowcaseRouteHost::new(
  route_source~ : @host.HostRouteSource,
  dispatch_command~ : (ShowcaseRouteHistoryCommand) -> Unit,
) -> ShowcaseRouteHost {
  { route_source, dispatch_command }
}

///|
pub fn ShowcaseModel::new(
  host_summary? : @host.HostCapabilitySummary = @host.HostCapabilitySummary::test_host(
    label="Showcase test host",
  ),
  route? : String = ShowcaseRoute::default().format(),
) -> ShowcaseModel {
  let parsed = ShowcaseRoute::parse(route)
  let components = @components.ComponentGalleryModel::new(
    active_platform=platform_id_from_host(host_summary),
    active_item=match
      @components.gallery_item_id_from_string(
        if parsed.workspace == Components {
          parsed.id
        } else {
          "welcome"
        },
      ) {
      Some(id) => id
      None => @components.ComponentGalleryItemId::Welcome
    },
  )
  let patterns = @patterns.Model::new(
    route=if parsed.workspace == Patterns { parsed.id } else { "welcome" },
  )
  let platform = @platform.Model::new(
    route=if parsed.workspace == Platform { parsed.id } else { "host-services" },
    host_label=host_summary.label,
  )
  let diagnostics = {
    let base = @diagnostics.ShowcaseModel::new().with_host_summary(host_summary)
    if parsed.workspace == Diagnostics {
      base.open(parsed.id)
    } else {
      base
    }
  }
  {
    workspace: parsed.workspace,
    route_id: parsed.id,
    route_history: @views.RouteHistoryState::new(
      initial=@views.RouteLocation::new(path=parsed.format()),
      title=parsed.title(),
      source="showcase",
    ),
    nav_query: "",
    // Deep links and mobile default land on detail; empty list is opt-in.
    mobile_showing_detail: true,
    sidebar_scroll: @state.ScrollState::new(),
    detail_scroll: @state.ScrollState::new(),
    host_summary,
    components,
    patterns,
    platform,
    diagnostics,
  }
}

///|
pub fn ShowcaseModel::with_host_summary(
  self : ShowcaseModel,
  host_summary : @host.HostCapabilitySummary,
) -> ShowcaseModel {
  {
    ..self,
    host_summary,
    platform: self.platform.with_host_label(host_summary.label),
    diagnostics: self.diagnostics.with_host_summary(host_summary),
  }
}

///|
/// Wire host-owned platform adapters (timer/services/window events) used by the
/// Platform workspace. Desktop entrypoints should pass a real timer source so
/// Canvas animation and host timers keep ticking.
pub fn ShowcaseModel::with_platform_host(
  self : ShowcaseModel,
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
  timer_source? : @host.HostTimerSource? = None,
  window_events? : @host.HostWindowEventSource? = None,
) -> ShowcaseModel {
  {
    ..self,
    platform: self.platform.with_host_adapters(
      services~,
      timer_source~,
      window_events~,
    ),
  }
}

///|
pub fn ShowcaseModel::current_route(self : ShowcaseModel) -> ShowcaseRoute {
  ShowcaseRoute::new(workspace=self.workspace, id=self.route_id)
}

///|
pub fn ShowcaseModel::current_route_string(self : ShowcaseModel) -> String {
  self.current_route().format()
}

///|
fn platform_id_from_host(
  host_summary : @host.HostCapabilitySummary,
) -> @components.PlatformId {
  let label = host_summary.label.to_lower()
  if label.contains("android") {
    @components.PlatformId::Android
  } else if label.contains("ios") || label.contains("iphone") {
    @components.PlatformId::IOS
  } else if label.contains("harmony") {
    @components.PlatformId::HarmonyOs
  } else if label.contains("linux") {
    @components.PlatformId::Linux
  } else if label.contains("windows") {
    @components.PlatformId::Windows
  } else if label.contains("web") {
    @components.PlatformId::Web
  } else {
    @components.PlatformId::MacOS
  }
}
