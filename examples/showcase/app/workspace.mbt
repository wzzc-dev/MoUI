///|
/// Top-level Showcase workspaces. Each maps to an isolated feature package.
pub(all) enum Workspace {
  Components
  Patterns
  Platform
  Diagnostics
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShowcaseRoute {
  workspace : Workspace
  id : String
} derive(Eq, Debug, ToJson)

///|
pub fn Workspace::slug(self : Workspace) -> String {
  match self {
    Components => "components"
    Patterns => "patterns"
    Platform => "platform"
    Diagnostics => "diagnostics"
  }
}

///|
pub fn Workspace::from_slug(slug : String) -> Workspace? {
  match slug {
    "components" => Some(Components)
    "patterns" => Some(Patterns)
    "platform" => Some(Platform)
    "diagnostics" => Some(Diagnostics)
    _ => None
  }
}

///|
pub fn Workspace::default_id(self : Workspace) -> String {
  match self {
    Components => "welcome"
    Patterns => "welcome"
    Platform => "host-services"
    Diagnostics => "diagnostics"
  }
}

///|
pub fn Workspace::title(self : Workspace) -> String {
  match self {
    Components => "Components"
    Patterns => "Patterns"
    Platform => "Platform"
    Diagnostics => "Diagnostics"
  }
}

///|
pub fn ShowcaseRoute::new(
  workspace~ : Workspace,
  id~ : String,
) -> ShowcaseRoute {
  { workspace, id: normalize_workspace_id(workspace, id) }
}

///|
pub fn ShowcaseRoute::default() -> ShowcaseRoute {
  ShowcaseRoute::new(workspace=Components, id="welcome")
}

///|
pub fn ShowcaseRoute::mobile_default() -> ShowcaseRoute {
  ShowcaseRoute::new(workspace=Platform, id="mobile-service-probe")
}

///|
pub fn ShowcaseRoute::format(self : ShowcaseRoute) -> String {
  self.workspace.slug() + "/" + self.id
}

///|
pub fn ShowcaseRoute::title(self : ShowcaseRoute) -> String {
  self.workspace.title() + " / " + self.id
}

///|
pub fn ShowcaseRoute::parse(raw : String) -> ShowcaseRoute {
  let location = @views.RouteLocation::parse(raw)
  let path = location.path
  if path == "" {
    return ShowcaseRoute::default()
  }
  let parts = path.split("/").to_array().map(part => part.to_owned())
  if parts.length() >= 2 {
    match Workspace::from_slug(parts[0]) {
      Some(workspace) => {
        let id = parts[1:].join("/")
        return ShowcaseRoute::new(workspace~, id~)
      }
      None => ()
    }
  }
  match legacy_showcase_route(path) {
    Some(route) => route
    None => ShowcaseRoute::default()
  }
}

///|
/// Legacy bare section ids still used by scripts, web deep links, and tests.
fn legacy_showcase_route(path : String) -> ShowcaseRoute? {
  match path {
    "showcase/accessibility-probe" | "accessibility-probe" =>
      Some(ShowcaseRoute::new(workspace=Components, id="accessibility-probe"))
    "advanced-rendering" =>
      Some(ShowcaseRoute::new(workspace=Diagnostics, id="advanced-rendering"))
    "runtime-renderer" | "theme-renderer" =>
      Some(ShowcaseRoute::new(workspace=Diagnostics, id="runtime-renderer"))
    "text-diagnostics" =>
      Some(ShowcaseRoute::new(workspace=Diagnostics, id="text-diagnostics"))
    "interaction-lab" =>
      Some(ShowcaseRoute::new(workspace=Diagnostics, id="interaction-lab"))
    "diagnostics" =>
      Some(ShowcaseRoute::new(workspace=Diagnostics, id="diagnostics"))
    "examples" => Some(ShowcaseRoute::new(workspace=Patterns, id="counter"))
    "feedback" | "layout" =>
      Some(ShowcaseRoute::new(workspace=Patterns, id="workflow"))
    "forms"
    | "data"
    | "navigation"
    | "text-media"
    | "counter"
    | "todo"
    | "workflow" => Some(ShowcaseRoute::new(workspace=Patterns, id=path))
    "overview" => Some(ShowcaseRoute::new(workspace=Components, id="welcome"))
    "controls" => Some(ShowcaseRoute::new(workspace=Components, id="button"))
    "welcome" | "button" | "platform-routes" | "mobile-service-probe" =>
      if path == "mobile-service-probe" {
        Some(ShowcaseRoute::new(workspace=Platform, id="mobile-service-probe"))
      } else {
        Some(ShowcaseRoute::new(workspace=Components, id=path))
      }
    "host-services" | "canvas" | "route-session" =>
      Some(ShowcaseRoute::new(workspace=Platform, id=path))
    _ =>
      match @components.gallery_item_id_from_string(path) {
        Some(_) => Some(ShowcaseRoute::new(workspace=Components, id=path))
        None => None
      }
  }
}

///|
fn normalize_workspace_id(workspace : Workspace, id : String) -> String {
  match workspace {
    Components =>
      match @components.gallery_item_id_from_string(id) {
        Some(item) => @components.gallery_item_id_to_string(item)
        None => "welcome"
      }
    Patterns => @patterns.Model::new(route=id).route()
    Platform => @platform.normalize_platform_route(id)
    Diagnostics => @diagnostics.normalize_diagnostics_route(id)
  }
}
