///|
pub fn ShowcaseModel::update(
  self : ShowcaseModel,
  message : ShowcaseMsg,
) -> ShowcaseModel {
  self.update_with_route_host(message, None).0
}

///|
fn ShowcaseModel::update_with_route_host(
  self : ShowcaseModel,
  message : ShowcaseMsg,
  route_host : ShowcaseRouteHost?,
) -> (ShowcaseModel, @moui.Effect[ShowcaseMsg]) {
  match message {
    Navigate(route) => self.navigate(route, route_host, push=true)
    OpenRouteLink(route) => self.navigate(route, route_host, push=true)
    SelectWorkspace(workspace) => {
      let (next, effect) = self.navigate(
        ShowcaseRoute::new(workspace~, id=workspace.default_id()).format(),
        route_host,
        push=true,
      )
      ({ ..next, nav_query: "", mobile_showing_detail: false }, effect)
    }
    NavQueryChanged(query) => ({ ..self, nav_query: query }, @moui.Effect::none())
    ShowMobileCatalog =>
      ({ ..self, mobile_showing_detail: false }, @moui.Effect::none())
    RouteBack => {
      let history = self.route_history.back()
      let next = self.with_route_history(history).apply_current_route_to_children()
      (next, ShowcaseRouteHistoryCommand::BackRoute.effect(route_host))
    }
    RouteForward => {
      let history = self.route_history.forward()
      let next = self.with_route_history(history).apply_current_route_to_children()
      (next, ShowcaseRouteHistoryCommand::ForwardRoute.effect(route_host))
    }
    HostRouteChanged(event) =>
      (self.with_host_route_event(event), @moui.Effect::none())
    ComponentsMsg(msg) => {
      let components = @components.update(self.components, msg)
      let next = {
        ..self,
        components,
        route_id: if self.workspace == Components {
          components.route()
        } else {
          self.route_id
        },
      }
      let next = if self.workspace == Components {
        next.sync_history_to_current()
      } else {
        next
      }
      (next, @moui.Effect::none())
    }
    PatternsMsg(msg) => {
      let patterns = @patterns.update(self.patterns, msg)
      let next = {
        ..self,
        patterns,
        route_id: if self.workspace == Patterns {
          patterns.route()
        } else {
          self.route_id
        },
      }
      let next = if self.workspace == Patterns {
        next.sync_history_to_current()
      } else {
        next
      }
      (next, @moui.Effect::none())
    }
    PlatformMsg(msg) => {
      let (platform, effect) = @platform.update(self.platform, msg)
      let next = {
        ..self,
        platform,
        route_id: if self.workspace == Platform {
          platform.route()
        } else {
          self.route_id
        },
      }
      let next = if self.workspace == Platform {
        next.sync_history_to_current()
      } else {
        next
      }
      (next, effect.map(m => PlatformMsg(m)))
    }
    DiagnosticsMsg(msg) => {
      let diagnostics = self.diagnostics.update(msg)
      let next = {
        ..self,
        diagnostics,
        route_id: if self.workspace == Diagnostics {
          diagnostics.route()
        } else {
          self.route_id
        },
      }
      let next = if self.workspace == Diagnostics {
        next.sync_history_to_current()
      } else {
        next
      }
      (next, @moui.Effect::none())
    }
  }
}

///|
fn ShowcaseModel::navigate(
  self : ShowcaseModel,
  route : String,
  route_host : ShowcaseRouteHost?,
  push~ : Bool,
) -> (ShowcaseModel, @moui.Effect[ShowcaseMsg]) {
  let parsed = ShowcaseRoute::parse(route)
  let formatted = parsed.format()
  let history = if push {
    if self.route_history.current_route() == formatted {
      self.route_history.replace(
        @views.RouteLocation::new(path=formatted),
        title=parsed.title(),
        source="showcase",
      )
    } else {
      self.route_history.push(
        @views.RouteLocation::new(path=formatted),
        title=parsed.title(),
        source="showcase",
      )
    }
  } else {
    self.route_history.replace(
      @views.RouteLocation::new(path=formatted),
      title=parsed.title(),
      source="showcase",
    )
  }
  // Keep sidebar scroll; reset detail when opening a different story.
  if self.current_route_string() != formatted {
    self.detail_scroll.scroll_to(x=0.0, y=0.0)
  }
  let next = {
      ..self,
      workspace: parsed.workspace,
      route_id: parsed.id,
      route_history: history,
      mobile_showing_detail: true,
    }
    .apply_route_to_children(parsed)
  let command = if push {
    if self.route_history.current_route() == formatted {
      ShowcaseRouteHistoryCommand::ReplaceRoute(formatted)
    } else {
      ShowcaseRouteHistoryCommand::PushRoute(formatted)
    }
  } else {
    ShowcaseRouteHistoryCommand::ReplaceRoute(formatted)
  }
  (next, command.effect(route_host))
}

///|
fn ShowcaseModel::apply_route_to_children(
  self : ShowcaseModel,
  route : ShowcaseRoute,
) -> ShowcaseModel {
  match route.workspace {
    Components => { ..self, components: self.components.open(route.id) }
    Patterns => { ..self, patterns: self.patterns.open(route.id) }
    Platform => { ..self, platform: self.platform.open(route.id) }
    Diagnostics => { ..self, diagnostics: self.diagnostics.open(route.id) }
  }
}

///|
fn ShowcaseModel::apply_current_route_to_children(
  self : ShowcaseModel,
) -> ShowcaseModel {
  self.apply_route_to_children(self.current_route())
}

///|
fn ShowcaseModel::sync_history_to_current(self : ShowcaseModel) -> ShowcaseModel {
  let route = self.current_route()
  let formatted = route.format()
  if self.route_history.current_route() == formatted {
    self
  } else {
    {
      ..self,
      route_history: self.route_history.replace(
        @views.RouteLocation::new(path=formatted),
        title=route.title(),
        source="showcase",
      ),
    }
  }
}

///|
fn ShowcaseModel::with_route_history(
  self : ShowcaseModel,
  route_history : @views.RouteHistoryState,
) -> ShowcaseModel {
  let parsed = ShowcaseRoute::parse(route_history.current().path)
  {
    ..self,
    route_history,
    workspace: parsed.workspace,
    route_id: parsed.id,
  }
}

///|
fn ShowcaseModel::with_host_route_event(
  self : ShowcaseModel,
  event : @host.HostRouteEvent,
) -> ShowcaseModel {
  let route = event.route()
  let parsed = ShowcaseRoute::parse(route)
  let history = self.route_history.push(
    @views.RouteLocation::new(path=parsed.format()),
    title=parsed.title(),
    source=event.source,
  )
  {
      ..self,
      workspace: parsed.workspace,
      route_id: parsed.id,
      route_history: history,
    }
    .apply_route_to_children(parsed)
}

///|
fn ShowcaseRouteHistoryCommand::effect(
  self : ShowcaseRouteHistoryCommand,
  route_host : ShowcaseRouteHost?,
) -> @moui.Effect[ShowcaseMsg] {
  match route_host {
    Some(host) =>
      @moui.Effect::host_service(
        key="showcase:route-history",
        label=self.label(),
        run=_dispatch => (host.dispatch_command)(self),
      )
    None => @moui.Effect::none()
  }
}

///|
fn ShowcaseRouteHistoryCommand::label(
  self : ShowcaseRouteHistoryCommand,
) -> String {
  match self {
    PushRoute(route) => "Push route " + route
    ReplaceRoute(route) => "Replace route " + route
    BackRoute => "Back route"
    ForwardRoute => "Forward route"
  }
}
