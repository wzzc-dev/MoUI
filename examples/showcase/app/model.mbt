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
  sidebar_scroll : @geometry.Point
  /// Right-hand detail canvas scroll.
  detail_scroll : @geometry.Point
  diagnostics_input : @diagnostics.ShowcaseDiagnosticsInput
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
  HostRouteChanged(@services.RouteEvent)
  SelectWorkspace(Workspace)
  NavQueryChanged(String)
  ShowMobileCatalog
  SidebarScrolled(@geometry.Point)
  DetailScrolled(@geometry.Point)
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
  route_source : @services.RouteSource
  dispatch_command : (ShowcaseRouteHistoryCommand) -> Unit
}

///|
pub fn ShowcaseApp::new() -> ShowcaseApp {
  { unit: () }
}

///|
pub fn ShowcaseRouteHost::new(
  route_source~ : @services.RouteSource,
  dispatch_command~ : (ShowcaseRouteHistoryCommand) -> Unit,
) -> ShowcaseRouteHost {
  { route_source, dispatch_command }
}

///|
pub fn ShowcaseModel::new(
  diagnostics_input? : @diagnostics.ShowcaseDiagnosticsInput = @diagnostics.ShowcaseDiagnosticsInput::fallback(),
  route? : String = ShowcaseRoute::default().format(),
) -> ShowcaseModel {
  let parsed = ShowcaseRoute::parse(route)
  let components = @components.ComponentGalleryModel::new(
    active_platform=platform_id_from_host(diagnostics_input.host.label),
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
    host_label=diagnostics_input.host.label,
  )
  let diagnostics = {
    let base = @diagnostics.ShowcaseModel::new().with_diagnostics_input(
      diagnostics_input,
    )
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
    sidebar_scroll: @geometry.Point::new(x=0.0, y=0.0),
    detail_scroll: @geometry.Point::new(x=0.0, y=0.0),
    diagnostics_input,
    components,
    patterns,
    platform,
    diagnostics,
  }
}

///|
pub fn ShowcaseModel::with_diagnostics_input(
  self : ShowcaseModel,
  diagnostics_input : @diagnostics.ShowcaseDiagnosticsInput,
) -> ShowcaseModel {
  {
    ..self,
    diagnostics_input,
    platform: self.platform.with_host_label(diagnostics_input.host.label),
    diagnostics: self.diagnostics.with_diagnostics_input(diagnostics_input),
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
fn platform_id_from_host(host_label : String) -> @components.PlatformId {
  let label = host_label.to_lower()
  if label.contains("android") {
    @components.PlatformId::Android
  } else if label.contains("ios") || label.contains("iphone") {
    @components.PlatformId::IOS
  } else if label.contains("harmony") {
    @components.PlatformId::HarmonyOS
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
