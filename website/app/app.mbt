///|
pub struct Model {
  dark : Bool
  locale : String
  hero_count : Int
  page : WebsitePage
  selected_doc_slug : String
  catalog_state : WebsiteCatalogLoadState
  doc_state : WebsiteDocLoadState
  docs_search : String
  mobile_menu_open : Bool
  docs_drawer_open : Bool
  compact_hero_tab : String
  home_scroll : @geometry.Point
  docs_body_scroll : @geometry.Point
  docs_scroll : @geometry.Point
  showcase_grid_scroll : @geometry.Point
  tutorial_scroll : @geometry.Point
  route_history : @views.RouteHistoryState
  pending_anchor : String?
  copied_text : String?
  next_service_token : Int
}

///|
pub enum Msg {
  ToggleDark
  SelectLocale(String)
  CounterIncrement
  CounterReset
  OpenRepository
  OpenHome
  OpenHomeAt(Double)
  OpenHomeAnchor(String)
  OpenTutorial
  OpenPlayground
  OpenPlaygroundLesson(String)
  OpenDocs
  OpenShowcases
  OpenShowcaseSource(String)
  SelectDoc(String)
  OpenDocLink(String)
  CopyText(String)
  RetryCatalog
  RetryDoc
  SearchDocs(String)
  ToggleMobileMenu
  CloseMobileMenu
  ToggleDocsDrawer
  CloseDocsDrawer
  SelectCompactHeroTab(String)
  HomeScrolled(@geometry.Point)
  DocsBodyScrolled(@geometry.Point)
  DocsScrolled(@geometry.Point)
  ShowcaseGridScrolled(@geometry.Point)
  TutorialScrolled(@geometry.Point)
  HostRouteChanged(@services.RouteEvent)
  HostCatalogCompleted(Int, @services.ServiceTaskResult[String])
  HostDocsCompleted(Int, String, @services.ServiceTaskResult[String])
  HostActionCompleted(@services.ServiceTaskResult[Unit])
}

///|
priv struct Metrics {
  viewport : @geometry.Size
  compact : Bool
  nav_compact : Bool
  docs_compact : Bool
  content_width : Double
  body_scroll_width : Double
  body_height : Double
  top_bar_height : Double
  section_top : Double
  section_bottom : Double
  docs_sidebar_width : Double
  hero_copy_width : Double
  hero_scene_width : Double
  hero_scene_height : Double
  feature_card_width : Double
  platform_card_width : Double
}

///|
fn Model::new() -> Model {
  {
    dark: false,
    locale: "en-US",
    hero_count: 0,
    page: WebsiteHome,
    selected_doc_slug: "moui-readme",
    catalog_state: CatalogNotLoaded,
    doc_state: DocNotLoaded,
    docs_search: "",
    mobile_menu_open: false,
    docs_drawer_open: false,
    compact_hero_tab: "source",
    home_scroll: @geometry.Point::new(x=0.0, y=0.0),
    docs_body_scroll: @geometry.Point::new(x=0.0, y=0.0),
    docs_scroll: @geometry.Point::new(x=0.0, y=0.0),
    showcase_grid_scroll: @geometry.Point::new(x=0.0, y=0.0),
    tutorial_scroll: @geometry.Point::new(x=0.0, y=0.0),
    route_history: @views.RouteHistoryState::new(
      initial=@views.RouteLocation::new(path="home"),
      title="MoUI",
      source="website",
    ),
    pending_anchor: None,
    copied_text: None,
    next_service_token: 1,
  }
}

///|
fn Model::update(self : Model, message : Msg) -> Model {
  match message {
    ToggleDark => { ..self, dark: !self.dark, copied_text: None }
    SelectLocale(locale) =>
      {
        ..self,
        locale: website_supported_locale(locale),
        catalog_state: CatalogNotLoaded,
        doc_state: DocNotLoaded,
        copied_text: None,
      }
    CounterIncrement =>
      { ..self, hero_count: self.hero_count + 1, copied_text: None }
    CounterReset => { ..self, hero_count: 0, copied_text: None }
    OpenRepository | OpenShowcaseSource(_) | OpenDocLink(_) =>
      { ..self, copied_text: None }
    CopyText(value) => { ..self, copied_text: Some(value) }
    OpenHome => { ..self.with_route("home"), copied_text: None }
    OpenHomeAt(offset_y) =>
      {
        ..self.with_route("home"),
        home_scroll: @geometry.Point::new(
          x=0.0,
          y=max_website_double(0.0, offset_y),
        ),
        copied_text: None,
      }
    OpenHomeAnchor(anchor) =>
      { ..self.with_route("home?anchor=" + anchor), copied_text: None }
    OpenTutorial => { ..self.with_route("tutorial"), copied_text: None }
    OpenPlayground => { ..self, copied_text: None }
    OpenPlaygroundLesson(_) => { ..self, copied_text: None }
    OpenDocs =>
      { ..self.with_route("docs/" + self.selected_doc_slug), copied_text: None }
    OpenShowcases => { ..self.with_route("showcases"), copied_text: None }
    SelectDoc(slug) => { ..self.with_route("docs/" + slug), copied_text: None }
    RetryCatalog =>
      { ..self, catalog_state: CatalogNotLoaded, copied_text: None }
    RetryDoc => { ..self, doc_state: DocNotLoaded, copied_text: None }
    SearchDocs(value) => { ..self, docs_search: value, copied_text: None }
    ToggleMobileMenu => { ..self, mobile_menu_open: !self.mobile_menu_open }
    CloseMobileMenu => { ..self, mobile_menu_open: false }
    ToggleDocsDrawer => { ..self, docs_drawer_open: !self.docs_drawer_open }
    CloseDocsDrawer => { ..self, docs_drawer_open: false }
    SelectCompactHeroTab(tab) => { ..self, compact_hero_tab: tab }
    HomeScrolled(offset) => { ..self, home_scroll: offset }
    DocsBodyScrolled(offset) => { ..self, docs_body_scroll: offset }
    DocsScrolled(offset) => { ..self, docs_scroll: offset }
    ShowcaseGridScrolled(offset) => { ..self, showcase_grid_scroll: offset }
    TutorialScrolled(offset) => { ..self, tutorial_scroll: offset }
    HostRouteChanged(event) => self.with_host_route(event)
    HostCatalogCompleted(token, result) =>
      self.apply_catalog_completion(token, result)
    HostDocsCompleted(token, path, result) =>
      self.apply_docs_completion(token, path, result)
    HostActionCompleted(_) => self
  }
}

///|
fn Model::with_route(self : Model, route : String) -> Model {
  let localized_route = website_route_with_locale(route, self.locale)
  let location = @views.RouteLocation::parse(
    website_normalize_route(localized_route),
  )
  let locale = website_locale_from_route(location.to_route())
  let page = website_page_from_location(location)
  let selected_doc_slug = website_doc_slug_from_location(location).unwrap_or(
    self.selected_doc_slug,
  )
  let anchor = location.query_value("anchor")
  let zero = @geometry.Point::new(x=0.0, y=0.0)
  let home_scroll = if page != self.page && page is WebsiteHome {
    zero
  } else {
    self.home_scroll
  }
  let tutorial_scroll = if page != self.page && page is WebsiteTutorial {
    zero
  } else {
    self.tutorial_scroll
  }
  let docs_body_scroll = if page != self.page && page is WebsiteDocs {
    zero
  } else {
    self.docs_body_scroll
  }
  let docs_scroll = if (page != self.page && page is WebsiteDocs) ||
    (page is WebsiteDocs && selected_doc_slug != self.selected_doc_slug) {
    zero
  } else {
    self.docs_scroll
  }
  let showcase_grid_scroll = if page != self.page && page is WebsiteShowcases {
    zero
  } else {
    self.showcase_grid_scroll
  }
  let history = if self.route_history.current_route() == location.to_route() {
    self.route_history.replace(
      location,
      title=self.website_route_title(location),
      source="website",
    )
  } else {
    self.route_history.push(
      location,
      title=self.website_route_title(location),
      source="website",
    )
  }
  {
    ..self,
    page,
    locale,
    selected_doc_slug,
    doc_state: if selected_doc_slug != self.selected_doc_slug {
      DocNotLoaded
    } else {
      self.doc_state
    },
    route_history: history,
    pending_anchor: anchor,
    mobile_menu_open: false,
    docs_drawer_open: false,
    home_scroll,
    tutorial_scroll,
    docs_body_scroll,
    docs_scroll,
    showcase_grid_scroll,
  }
}

///|
fn Model::with_host_route(self : Model, event : @services.RouteEvent) -> Model {
  let normalized = website_normalize_route(event.location.to_route())
  let locale = website_locale_from_route(normalized)
  let next = { ..self, locale, }.with_route(normalized)
  let location = @views.RouteLocation::parse(next.route_history.current_route())
  {
    ..next,
    route_history: self.route_history.replace(
      location,
      title=self.website_route_title(location),
      source=event.source,
    ),
  }
}

///|
fn website_normalize_route(route : String) -> String {
  let location = @views.RouteLocation::parse(route)
  let path = location.path()
  let page = if path == "" || path == "/" || path == "overview" {
    "home"
  } else {
    path
  }
  let query : Array[@views.RouteQueryParam] = []
  for parameter in location.query() {
    if parameter.key() != "lang" ||
      website_supported_locale(parameter.value()) != "en-US" {
      query.push(parameter)
    }
  }
  @views.RouteLocation::new(path=page, query~).to_route()
}

///|
fn website_supported_locale(locale : String) -> String {
  match @i18n.Locale::parse(locale) {
    Some(parsed) if parsed.canonical() == "zh-Hans" => "zh-Hans"
    _ => "en-US"
  }
}

///|
fn website_route_with_locale(route : String, locale : String) -> String {
  let location = @views.RouteLocation::parse(route)
  let query : Array[@views.RouteQueryParam] = []
  for parameter in location.query() {
    if parameter.key() != "lang" {
      query.push(parameter)
    }
  }
  if website_supported_locale(locale) == "zh-Hans" {
    query.push(@views.RouteQueryParam::new(key="lang", value="zh-Hans"))
  }
  @views.RouteLocation::new(path=location.path(), query~).to_route()
}

///|
fn website_locale_from_route(route : String) -> String {
  let location = @views.RouteLocation::parse(route)
  website_supported_locale(location.query_value("lang").unwrap_or("en-US"))
}

///|
fn website_page_from_location(location : @views.RouteLocation) -> WebsitePage {
  let path = location.path()
  if path == "showcases" {
    WebsiteShowcases
  } else if path == "tutorial" {
    WebsiteTutorial
  } else if path.has_prefix("docs/") || path == "docs" {
    WebsiteDocs
  } else {
    WebsiteHome
  }
}

///|
fn website_doc_slug_from_location(location : @views.RouteLocation) -> String? {
  let path = location.path()
  if path.has_prefix("docs/") && path.length() > 5 {
    Some(path[5:].to_owned())
  } else {
    None
  }
}

///|
fn Model::website_route_title(
  self : Model,
  location : @views.RouteLocation,
) -> String {
  let path = location.path()
  if path == "showcases" {
    website_message(self.locale, "route.showcases")
  } else if path == "tutorial" {
    website_message(self.locale, "route.tutorial")
  } else if path.has_prefix("docs/") {
    website_message(self.locale, "route.docs")
  } else {
    website_message(self.locale, "route.home")
  }
}

///|
fn Model::update_with_services(
  self : Model,
  message : Msg,
  services : @services.AppServices,
  route_host : WebsiteRouteHost?,
) -> (Model, @moui.Effect[Msg]) {
  match message {
    SelectLocale(_) => {
      let selected = self.update(message)
      let next = selected.with_route(selected.route_history.current_route())
      let route = website_route_with_locale(
        next.route_history.current_route(),
        next.locale,
      )
      let locale_effect = match route_host {
        Some(host) =>
          @moui.Effect::run(
            key="website:apply-locale",
            kind="host-service",
            label=website_message(next.locale, "a11y.apply_locale"),
            run=_dispatch => (host.apply_locale)(next.locale),
          )
        None => @moui.Effect::none()
      }
      let route_effect = WebsiteRouteCommand::PushRoute(route).effect(
        route_host,
        next.locale,
      )
      let (prepared, catalog_effect) = next.request_catalog(services)
      (
        prepared.with_metadata_updated(route_host),
        @moui.Effect::batch([locale_effect, route_effect, catalog_effect]),
      )
    }
    OpenRepository =>
      (self, website_open_url_effect(services, moui_repository_url()))
    OpenPlayground =>
      (self, website_open_url_effect(services, website_playground_url()))
    OpenPlaygroundLesson(id) =>
      (
        self,
        website_open_url_effect(services, website_playground_url(example=id)),
      )
    OpenShowcaseSource(url) => (self, website_open_url_effect(services, url))
    OpenDocLink(target) => self.open_doc_link(target, services, route_host)
    CopyText(value) =>
      (
        self.update(message),
        services
        .clipboard()
        .write_text(value)
        .effect(map=result => HostActionCompleted(result)),
      )
    RetryCatalog => self.request_catalog(services)
    RetryDoc => self.request_selected_doc(services)
    ToggleDocsDrawer => {
      let next = self.update(message)
      let effect = if next.docs_drawer_open {
        WebsiteRouteCommand::ScrollToKey(
          "docs-nav-" + next.selected_doc_slug,
          @core.ScrollAlignment::Center,
        ).effect(route_host, next.locale)
      } else {
        @moui.Effect::none()
      }
      (next, effect)
    }
    HostCatalogCompleted(token, result) => {
      let next = self.apply_catalog_completion(token, result)
      let (prepared, effect) = if next.page is WebsiteDocs &&
        next.catalog_state is CatalogLoaded(_) &&
        next.doc_state is DocNotLoaded {
        next.request_selected_doc(services)
      } else {
        (next, @moui.Effect::none())
      }
      (prepared.with_metadata_updated(route_host), effect)
    }
    HostDocsCompleted(token, path, result) =>
      (self.apply_docs_completion(token, path, result), @moui.Effect::none())
    OpenHome
    | OpenHomeAt(_)
    | OpenHomeAnchor(_)
    | OpenTutorial
    | OpenDocs
    | OpenShowcases
    | SelectDoc(_) => {
      let next = self.update(message)
      let route = next.route_history.current_route()
      let route_effect = WebsiteRouteCommand::PushRoute(route).effect(
        route_host,
        next.locale,
      )
      let anchor_effect = match next.pending_anchor {
        Some(anchor) =>
          WebsiteRouteCommand::ScrollToKey(
            website_anchor_key(anchor),
            @core.ScrollAlignment::Start,
          ).effect(route_host, next.locale)
        None => @moui.Effect::none()
      }
      let (prepared, doc_effect) = if next.page is WebsiteDocs &&
        next.doc_state is DocNotLoaded {
        next.request_selected_doc(services)
      } else {
        (next, @moui.Effect::none())
      }
      (
        prepared.with_metadata_updated(route_host),
        @moui.Effect::batch([route_effect, anchor_effect, doc_effect]),
      )
    }
    HostRouteChanged(event) => {
      let next = self.with_host_route(event)
      let (prepared, doc_effect) = if next.page is WebsiteDocs &&
        next.doc_state is DocNotLoaded {
        next.request_selected_doc(services)
      } else {
        (next, @moui.Effect::none())
      }
      let anchor_effect = match next.pending_anchor {
        Some(anchor) =>
          WebsiteRouteCommand::ScrollToKey(
            website_anchor_key(anchor),
            @core.ScrollAlignment::Start,
          ).effect(route_host, next.locale)
        None => @moui.Effect::none()
      }
      let locale_effect = match route_host {
        Some(host) =>
          @moui.Effect::run(
            key="website:apply-locale",
            kind="host-service",
            label=website_message(next.locale, "a11y.apply_locale"),
            run=_dispatch => (host.apply_locale)(next.locale),
          )
        None => @moui.Effect::none()
      }
      (
        prepared.with_metadata_updated(route_host),
        @moui.Effect::batch([locale_effect, doc_effect, anchor_effect]),
      )
    }
    _ => (self.update(message), @moui.Effect::none())
  }
}

///|
fn WebsiteRouteCommand::effect(
  self : WebsiteRouteCommand,
  route_host : WebsiteRouteHost?,
  locale : String,
) -> @moui.Effect[Msg] {
  match route_host {
    Some(host) =>
      @moui.Effect::run(
        key="website:route-command",
        kind="host-service",
        label=website_message(locale, "a11y.route_command"),
        run=_dispatch => {
          match self {
            PushRoute(route) => (host.push_route)(route)
            ScrollToKey(key, alignment) => (host.scroll_to_key)(key, alignment)
          }
        },
      )
    None => @moui.Effect::none()
  }
}

///|
fn Model::with_metadata_updated(
  self : Model,
  route_host : WebsiteRouteHost?,
) -> Model {
  match route_host {
    Some(host) => {
      let (title, description, canonical) = self.document_metadata()
      (host.update_metadata)(title, description, canonical, self.locale, "ltr")
    }
    None => ()
  }
  self
}

///|
fn Model::document_metadata(self : Model) -> (String, String, String) {
  let site_url = match self.website_catalog() {
    Some(catalog) => catalog.siteUrl
    None => "https://wzzc-dev.github.io/MoUI/"
  }
  let message = key => website_message(self.locale, key)
  let canonical = route => {
    let locale_suffix = if self.locale == "zh-Hans" {
      "&lang=zh-Hans"
    } else {
      ""
    }
    site_url + "?section=" + route + locale_suffix
  }
  match self.page {
    WebsiteHome =>
      (
        message("meta.home.title"),
        message("meta.home.description"),
        canonical("home"),
      )
    WebsiteTutorial =>
      (
        message("meta.tutorial.title"),
        message("meta.tutorial.description"),
        canonical("tutorial"),
      )
    WebsiteShowcases =>
      (
        message("meta.showcases.title"),
        message("meta.showcases.description"),
        canonical("showcases"),
      )
    WebsiteDocs =>
      match self.website_doc_selected_entry() {
        Some(entry) =>
          (
            entry.title + message("meta.docs.suffix"),
            entry.summary,
            canonical("docs/" + entry.slug),
          )
        None =>
          (
            message("meta.not_found.title"),
            message("meta.not_found.description"),
            canonical("docs/" + self.selected_doc_slug),
          )
      }
  }
}

///|
fn website_anchor_key(anchor : String) -> String {
  if anchor == "tour" {
    "home-tour"
  } else if anchor == "quick-start" {
    "home-quick-start"
  } else {
    "doc-heading-" + anchor
  }
}

///|
fn website_open_url_effect(
  services : @services.AppServices,
  url : String,
) -> @moui.Effect[Msg] {
  services.urls().open(url).effect(map=result => HostActionCompleted(result))
}

///|
fn Model::open_doc_link(
  self : Model,
  target : String,
  services : @services.AppServices,
  route_host : WebsiteRouteHost?,
) -> (Model, @moui.Effect[Msg]) {
  if target.has_prefix("https://") || target.has_prefix("http://") {
    return (self, website_open_url_effect(services, target))
  }
  if target.has_prefix("#") {
    let anchor = website_heading_anchor(target[1:].to_owned())
    let route = "docs/" + self.selected_doc_slug + "?anchor=" + anchor
    let next = self.with_route(route)
    return (
      next,
      @moui.Effect::batch([
        WebsiteRouteCommand::PushRoute(next.route_history.current_route()).effect(
          route_host,
          next.locale,
        ),
        WebsiteRouteCommand::ScrollToKey(
          website_anchor_key(anchor),
          @core.ScrollAlignment::Start,
        ).effect(route_host, next.locale),
      ]),
    )
  }
  let parts = target.split("#").to_array()
  let path = parts[0].to_owned()
  let anchor = if parts.length() > 1 {
    Some(website_heading_anchor(parts[1].to_owned()))
  } else {
    None
  }
  let filename = path
    .split("/")
    .last()
    .map(view => view.to_owned())
    .unwrap_or(path)
  let mut resolved : WebsiteDocEntry? = None
  match self.website_catalog() {
    Some(catalog) =>
      for entry in catalog.entries {
        if entry.path.has_suffix("/" + filename) || entry.path == filename {
          resolved = Some(entry)
          break
        }
      }
    None => ()
  }
  match resolved {
    Some(entry) => {
      let suffix = match anchor {
        Some(anchor) => "?anchor=" + anchor
        None => ""
      }
      let route = "docs/" + entry.slug + suffix
      let next = self.with_route(route)
      let load = next.request_selected_doc(services).1
      (
        next,
        @moui.Effect::batch([
          WebsiteRouteCommand::PushRoute(next.route_history.current_route()).effect(
            route_host,
            next.locale,
          ),
          load,
        ]),
      )
    }
    None => (self, @moui.Effect::none())
  }
}

///|
fn Model::view(self : Model, env : @moui.ViewEnvironment) -> @moui.View[Msg] {
  let locale = website_supported_locale(env.environment().locale)
  let localized = if locale == self.locale { self } else { { ..self, locale, } }
  let theme = website_theme(localized.dark)
  let metrics = website_metrics(env.viewport_size())
  let content = match localized.page {
    WebsiteHome => localized.home_content(theme, metrics)
    WebsiteTutorial => localized.tutorial_content(theme, metrics)
    WebsiteDocs => localized.docs_content(theme, metrics)
    WebsiteShowcases => localized.showcases_content(theme, metrics)
  }
  let body = match localized.page {
    WebsiteDocs | WebsiteShowcases =>
      frame(
        content,
        width=metrics.body_scroll_width,
        height=metrics.body_height,
      ).semantics_role(@core.SemanticsRole::Main)
    WebsiteHome =>
      scroll_view(
        content,
        width=metrics.body_scroll_width,
        height=metrics.body_height,
        offset=localized.home_scroll,
        on_scroll=Some(offset => HomeScrolled(offset)),
        shows_indicator=true,
      ).semantics_role(@core.SemanticsRole::Main)
    WebsiteTutorial =>
      scroll_view(
        content,
        width=metrics.body_scroll_width,
        height=metrics.body_height,
        offset=localized.tutorial_scroll,
        on_scroll=Some(offset => TutorialScrolled(offset)),
        shows_indicator=true,
      ).semantics_role(@core.SemanticsRole::Main)
  }
  let shell = container(
    column(
      [localized.top_bar(theme, metrics), body],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=metrics.viewport.width,
    height=metrics.viewport.height,
    background=theme.palette.background,
    theme~,
    padding=0.0,
  )
  localized.website_overlay_hosts(shell, theme, metrics)
}

///|
fn Model::program(self : Model) -> @moui.Program[Model, Msg] {
  self.program_with_services(@services.AppServices::unavailable())
}

///|
fn Model::program_with_services(
  self : Model,
  services : @services.AppServices,
  route_host? : WebsiteRouteHost? = None,
) -> @moui.Program[Model, Msg] {
  @moui.Program::new_with_environment(
    init=() => {
      match self.catalog_state {
        CatalogNotLoaded => self.request_catalog(services)
        _ => (self, @moui.Effect::none())
      }
    },
    update=(model, message) => {
      model.update_with_services(message, services, route_host)
    },
    view=(model, env) => model.view(env),
    subscriptions=model => model.subscriptions(route_host),
  )
}

///|
fn Model::home_content(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  column(
    [
      self.hero(theme, metrics),
      self.capability_strip(theme, metrics),
      self.foundation_section(theme, metrics).key("home-tour"),
      self.platform_section(theme, metrics),
      self.quick_start_section(theme, metrics).key("home-quick-start"),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn Model::subscriptions(
  self : Model,
  route_host : WebsiteRouteHost?,
) -> @moui.Subscription[Msg] {
  let subscriptions : Array[@moui.Subscription[Msg]] = []
  match route_host {
    Some(host) =>
      subscriptions.push(
        host.route_source.subscription(
          key="website:host-route",
          label=website_message(self.locale, "a11y.host_route"),
          map=event => Some(HostRouteChanged(event)),
        ),
      )
    None => ()
  }
  @moui.Subscription::batch(subscriptions)
}

///|
fn Model::website_catalog_path(self : Model) -> String {
  if self.locale == "zh-Hans" {
    "docs/zh-Hans/catalog.json"
  } else {
    "docs/catalog.json"
  }
}

///|
fn Model::request_catalog(
  self : Model,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  let path = self.website_catalog_path()
  let token = self.next_service_token
  (
    {
      ..self,
      catalog_state: CatalogLoading(token),
      next_service_token: token + 1,
    },
    services
    .files()
    .read_text(path)
    .effect(map=result => HostCatalogCompleted(token, result)),
  )
}

///|
fn Model::request_selected_doc(
  self : Model,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  match self.website_doc_selected_entry() {
    Some(entry) => {
      let token = self.next_service_token
      (
        {
          ..self,
          page: WebsiteDocs,
          doc_state: DocLoading(token, entry.path),
          next_service_token: token + 1,
        },
        services
        .files()
        .read_text(entry.path)
        .effect(map=result => HostDocsCompleted(token, entry.path, result)),
      )
    }
    None =>
      match self.catalog_state {
        CatalogLoaded(_) =>
          (
            { ..self, doc_state: DocNotFound(self.selected_doc_slug) },
            @moui.Effect::none(),
          )
        _ => (self, @moui.Effect::none())
      }
  }
}

///|
fn Model::apply_catalog_completion(
  self : Model,
  token : Int,
  result : @services.ServiceTaskResult[String],
) -> Model {
  if !self.catalog_completion_matches(token) {
    return self
  }
  match result {
    @services.ServiceTaskResult::Success(text) =>
      match website_parse_catalog(text) {
        Some(catalog) => { ..self, catalog_state: CatalogLoaded(catalog) }
        None =>
          {
            ..self,
            catalog_state: CatalogFailed(
              website_message(self.locale, "docs.catalog_invalid"),
            ),
          }
      }
    @services.ServiceTaskResult::Failure(error) =>
      { ..self, catalog_state: CatalogFailed(error.message) }
    @services.ServiceTaskResult::Cancelled =>
      {
        ..self,
        catalog_state: CatalogFailed(
          website_message(self.locale, "docs.catalog_unexpected"),
        ),
      }
  }
}

///|
fn Model::catalog_completion_matches(self : Model, token : Int) -> Bool {
  match self.catalog_state {
    CatalogLoading(active_token) => active_token == token
    _ => false
  }
}

///|
fn Model::apply_docs_completion(
  self : Model,
  token : Int,
  path : String,
  result : @services.ServiceTaskResult[String],
) -> Model {
  if !self.docs_completion_matches_current(token, path) {
    return self
  }
  match result {
    @services.ServiceTaskResult::Success(text) =>
      {
        ..self,
        doc_state: DocLoaded(path, website_parse_markdown_document(path, text)),
      }
    @services.ServiceTaskResult::Failure(error) =>
      { ..self, doc_state: DocFailed(path, error.message) }
    @services.ServiceTaskResult::Cancelled =>
      {
        ..self,
        doc_state: DocFailed(
          path,
          website_message(self.locale, "docs.document_unexpected"),
        ),
      }
  }
}

///|
fn Model::docs_completion_matches_current(
  self : Model,
  token : Int,
  path : String,
) -> Bool {
  match self.doc_state {
    DocLoading(active_token, loading_path) =>
      path == loading_path && token == active_token
    _ => false
  }
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  Model::new().program()
}

///|
pub fn program_with_services(
  services : @services.AppServices,
  route_host? : WebsiteRouteHost? = None,
) -> @moui.Program[Model, Msg] {
  Model::new().program_with_services(services, route_host~)
}

///|
fn moui_repository_url() -> String {
  "https://github.com/wzzc-dev/MoUI"
}

///|
fn website_playground_url(example? : String) -> String {
  let base = "./playground/"
  match example {
    Some(id) => base + "?example=" + id
    None => base
  }
}

///|
fn website_metrics(viewport : @geometry.Size) -> Metrics {
  let compact = viewport.width < 820.0
  let nav_compact = viewport.width < 980.0
  let docs_compact = viewport.width < 1040.0
  let body_scroll_width = max_website_double(120.0, viewport.width)
  let horizontal_margin = if compact { 20.0 } else { 40.0 }
  let content_width = min_website_double(
    max_website_double(280.0, body_scroll_width - horizontal_margin * 2.0),
    1100.0,
  )
  let top_bar_height = 60.0
  let section_top = if compact { 52.0 } else { 82.0 }
  let section_bottom = if compact { 52.0 } else { 82.0 }
  let hero_scene_width = content_width
  let hero_scene_height = if compact { 330.0 } else { 300.0 }
  let hero_copy_width = if compact {
    content_width
  } else {
    min_website_double(content_width, 740.0)
  }
  let feature_card_width = if compact {
    content_width
  } else {
    clamp_website_double((content_width - 16.0) / 2.0, 500.0, 560.0)
  }
  let platform_card_width = if compact {
    content_width
  } else {
    clamp_website_double((content_width - 36.0) / 4.0, 240.0, 280.0)
  }
  let docs_sidebar_width = if docs_compact { content_width } else { 280.0 }
  {
    viewport,
    compact,
    nav_compact,
    docs_compact,
    content_width,
    body_scroll_width,
    body_height: max_website_double(120.0, viewport.height - top_bar_height),
    top_bar_height,
    section_top,
    section_bottom,
    docs_sidebar_width,
    hero_copy_width,
    hero_scene_width,
    hero_scene_height,
    feature_card_width,
    platform_card_width,
  }
}

///|
fn website_theme(dark : Bool) -> @moui.Theme {
  let scheme = if dark {
    @state.ColorScheme::Dark
  } else {
    @state.ColorScheme::Light
  }
  let palette : @views.ColorPalette = if dark {
    @views.ColorPalette::from_seed(
      primary=@graphics.Color::rgba(r=0.18, g=0.83, b=0.75),
      @state.ColorScheme::Dark,
      foreground=@graphics.Color::rgba(r=0.91, g=0.92, b=0.96),
      background=@graphics.Color::rgba(r=0.06, g=0.06, b=0.08),
      surface=@graphics.Color::rgba(r=0.09, g=0.09, b=0.12),
      surface_variant=@graphics.Color::rgba(r=0.15, g=0.16, b=0.22),
      outline=@graphics.Color::rgba(r=0.15, g=0.16, b=0.23),
      muted=@graphics.Color::rgba(r=0.55, g=0.58, b=0.66),
    )
  } else {
    @views.ColorPalette::from_seed(
      primary=@graphics.Color::rgba(r=0.0, g=0.44, b=0.40),
      @state.ColorScheme::Light,
      foreground=@graphics.Color::rgba(r=0.07, g=0.09, b=0.14),
      background=@graphics.Color::rgba(r=0.98, g=0.98, b=0.98),
      surface=@graphics.Color::white(),
      surface_variant=@graphics.Color::rgba(r=0.95, g=0.96, b=0.97),
      outline=@graphics.Color::rgba(r=0.90, g=0.91, b=0.93),
      muted=@graphics.Color::rgba(r=0.42, g=0.45, b=0.50),
    )
  }
  let typography : @views.TypographyScale = {
    ..@views.TypographyScale::default(),
    body: @text.FontSpec::new(size=16.0, weight=500),
    title: @text.FontSpec::new(size=28.0, weight=800),
    caption: @text.FontSpec::new(size=13.0, weight=500),
    control: @text.FontSpec::new(size=15.0, weight=700),
  }
  @views.theme(scheme~, palette~, typography~)
}

///|
fn clamp_website_double(
  value : Double,
  lower : Double,
  upper : Double,
) -> Double {
  max_website_double(lower, min_website_double(value, upper))
}

///|
fn min_website_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_website_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
