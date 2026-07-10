///|
pub struct Model {
  dark : Bool
  hero_count : Int
  page : WebsitePage
  selected_doc_slug : String
  catalog_state : WebsiteCatalogLoadState
  doc_state : WebsiteDocLoadState
  docs_search : String
  mobile_menu_open : Bool
  docs_drawer_open : Bool
  compact_hero_tab : String
  home_scroll : @state.ScrollState
  docs_body_scroll : @state.ScrollState
  docs_scroll : @state.ScrollState
  showcases_scroll : @state.ScrollState
  showcase_grid_scroll : @state.ScrollState
  route_history : @views.RouteHistoryState
  pending_anchor : String?
  copy_feedback_active : Bool
}

///|
pub enum Msg {
  ToggleDark
  CounterIncrement
  CounterReset
  OpenRepository
  OpenHome
  OpenHomeAt(Double)
  OpenHomeAnchor(String)
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
  HostRouteChanged(@host.HostRouteEvent)
  HostCatalogCompleted(@host.HostCompletedServiceResponse)
  HostDocsCompleted(@host.HostCompletedServiceResponse)
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
    hero_count: 0,
    page: WebsiteHome,
    selected_doc_slug: "moui-readme",
    catalog_state: CatalogNotLoaded,
    doc_state: DocNotLoaded,
    docs_search: "",
    mobile_menu_open: false,
    docs_drawer_open: false,
    compact_hero_tab: "source",
    home_scroll: @state.ScrollState::new(),
    docs_body_scroll: @state.ScrollState::new(),
    docs_scroll: @state.ScrollState::new(),
    showcases_scroll: @state.ScrollState::new(),
    showcase_grid_scroll: @state.ScrollState::new(),
    route_history: @views.RouteHistoryState::new(
      initial=@views.RouteLocation::new(path="home"),
      title="MoUI",
      source="website",
    ),
    pending_anchor: None,
    copy_feedback_active: false,
  }
}

///|
fn Model::update(self : Model, message : Msg) -> Model {
  match message {
    ToggleDark => { ..self, dark: !self.dark, copy_feedback_active: false }
    CounterIncrement =>
      { ..self, hero_count: self.hero_count + 1, copy_feedback_active: false }
    CounterReset => { ..self, hero_count: 0, copy_feedback_active: false }
    OpenRepository | OpenShowcaseSource(_) | OpenDocLink(_) =>
      { ..self, copy_feedback_active: false }
    CopyText(_) => { ..self, copy_feedback_active: true }
    OpenHome => { ..self.with_route("home"), copy_feedback_active: false }
    OpenHomeAt(offset_y) => {
      self.home_scroll.scroll_to(x=0.0, y=max_website_double(0.0, offset_y))
      { ..self.with_route("home"), copy_feedback_active: false }
    }
    OpenHomeAnchor(anchor) =>
      {
        ..self.with_route("home?anchor=" + anchor),
        copy_feedback_active: false,
      }
    OpenDocs =>
      {
        ..self.with_route("docs/" + self.selected_doc_slug),
        copy_feedback_active: false,
      }
    OpenShowcases =>
      { ..self.with_route("showcases"), copy_feedback_active: false }
    SelectDoc(slug) =>
      { ..self.with_route("docs/" + slug), copy_feedback_active: false }
    RetryCatalog =>
      { ..self, catalog_state: CatalogNotLoaded, copy_feedback_active: false }
    RetryDoc => { ..self, doc_state: DocNotLoaded, copy_feedback_active: false }
    SearchDocs(value) =>
      { ..self, docs_search: value, copy_feedback_active: false }
    ToggleMobileMenu => { ..self, mobile_menu_open: !self.mobile_menu_open }
    CloseMobileMenu => { ..self, mobile_menu_open: false }
    ToggleDocsDrawer => { ..self, docs_drawer_open: !self.docs_drawer_open }
    CloseDocsDrawer => { ..self, docs_drawer_open: false }
    SelectCompactHeroTab(tab) => { ..self, compact_hero_tab: tab }
    HostRouteChanged(event) => self.with_host_route(event)
    HostCatalogCompleted(completion) =>
      self.apply_catalog_completion(completion)
    HostDocsCompleted(completion) => self.apply_docs_completion(completion)
  }
}

///|
fn Model::current_body_scroll(self : Model) -> @state.ScrollState {
  match self.page {
    WebsiteHome => self.home_scroll
    WebsiteDocs => self.docs_body_scroll
    WebsiteShowcases => self.showcases_scroll
  }
}

///|
fn Model::with_route(self : Model, route : String) -> Model {
  let location = @views.RouteLocation::parse(website_normalize_route(route))
  let page = website_page_from_location(location)
  let selected_doc_slug = website_doc_slug_from_location(location).unwrap_or(
    self.selected_doc_slug,
  )
  let anchor = location.query_value("anchor")
  if page != self.page {
    match page {
      WebsiteHome => self.home_scroll.scroll_to(x=0.0, y=0.0)
      WebsiteDocs => {
        self.docs_body_scroll.scroll_to(x=0.0, y=0.0)
        self.docs_scroll.scroll_to(x=0.0, y=0.0)
      }
      WebsiteShowcases => self.showcases_scroll.scroll_to(x=0.0, y=0.0)
    }
  } else if page is WebsiteDocs && selected_doc_slug != self.selected_doc_slug {
    self.docs_scroll.scroll_to(x=0.0, y=0.0)
  }
  let history = if self.route_history.current_route() == location.to_route() {
    self.route_history.replace(
      location,
      title=website_route_title(location),
      source="website",
    )
  } else {
    self.route_history.push(
      location,
      title=website_route_title(location),
      source="website",
    )
  }
  {
    ..self,
    page,
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
  }
}

///|
fn Model::with_host_route(self : Model, event : @host.HostRouteEvent) -> Model {
  let normalized = website_normalize_route(event.location.to_route())
  let location = @views.RouteLocation::parse(normalized)
  let next = self.with_route(normalized)
  {
    ..next,
    route_history: self.route_history.replace(
      location,
      title=website_route_title(location),
      source=event.source,
    ),
  }
}

///|
fn website_normalize_route(route : String) -> String {
  let location = @views.RouteLocation::parse(route)
  let path = location.path()
  if path == "" || path == "/" || path == "overview" {
    "home"
  } else {
    location.to_route()
  }
}

///|
fn website_page_from_location(location : @views.RouteLocation) -> WebsitePage {
  let path = location.path()
  if path == "showcases" {
    WebsiteShowcases
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
fn website_route_title(location : @views.RouteLocation) -> String {
  let path = location.path()
  if path == "showcases" {
    "Showcases"
  } else if path.has_prefix("docs/") {
    "Docs"
  } else {
    "MoUI"
  }
}

///|
fn Model::update_with_services(
  self : Model,
  message : Msg,
  services : @host.HostAppServices,
  route_host : WebsiteRouteHost?,
) -> (Model, @moui.Effect[Msg]) {
  match message {
    OpenRepository =>
      (
        self,
        website_open_url_effect(
          services,
          moui_repository_url(),
          "Open MoUI repository",
        ),
      )
    OpenShowcaseSource(url) =>
      (self, website_open_url_effect(services, url, "Open showcase source"))
    OpenDocLink(target) => self.open_doc_link(target, services, route_host)
    CopyText(value) =>
      (
        self.update(message),
        @moui.Effect::host_service(
          key="website:copy",
          label="Copy website text",
          run=_dispatch => ignore(services.write_clipboard_text(value)),
        ),
      )
    RetryCatalog => self.request_catalog(services)
    RetryDoc => self.request_selected_doc(services)
    ToggleDocsDrawer => {
      let next = self.update(message)
      let effect = if next.docs_drawer_open {
        WebsiteRouteCommand::ScrollToKey(
          "docs-nav-" + next.selected_doc_slug,
          @core.ScrollAlignment::Center,
        ).effect(route_host)
      } else {
        @moui.Effect::none()
      }
      (next, effect)
    }
    HostCatalogCompleted(completion) => {
      let next = self.apply_catalog_completion(completion)
      let (prepared, effect) = if next.page is WebsiteDocs &&
        next.catalog_state is CatalogLoaded(_) &&
        next.doc_state is DocNotLoaded {
        next.request_selected_doc(services)
      } else {
        (next, @moui.Effect::none())
      }
      (prepared.with_metadata_updated(route_host), effect)
    }
    HostDocsCompleted(completion) =>
      (self.apply_docs_completion(completion), @moui.Effect::none())
    OpenHome
    | OpenHomeAt(_)
    | OpenHomeAnchor(_)
    | OpenDocs
    | OpenShowcases
    | SelectDoc(_) => {
      let next = self.update(message)
      let route = next.route_history.current_route()
      let route_effect = WebsiteRouteCommand::PushRoute(route).effect(
        route_host,
      )
      let anchor_effect = match next.pending_anchor {
        Some(anchor) =>
          WebsiteRouteCommand::ScrollToKey(
            website_anchor_key(anchor),
            @core.ScrollAlignment::Start,
          ).effect(route_host)
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
          ).effect(route_host)
        None => @moui.Effect::none()
      }
      (
        prepared.with_metadata_updated(route_host),
        @moui.Effect::batch([doc_effect, anchor_effect]),
      )
    }
    _ => (self.update(message), @moui.Effect::none())
  }
}

///|
fn WebsiteRouteCommand::effect(
  self : WebsiteRouteCommand,
  route_host : WebsiteRouteHost?,
) -> @moui.Effect[Msg] {
  match route_host {
    Some(host) =>
      @moui.Effect::host_service(
        key="website:route-command",
        label="Website route command",
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
      (host.update_metadata)(title, description, canonical)
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
  match self.page {
    WebsiteHome =>
      (
        "MoUI - MoonBit GUI Framework", "Typed, declarative MoonBit UI for Web and native hosts.",
        site_url,
      )
    WebsiteShowcases =>
      (
        "Showcases - MoUI",
        "Applications and platform surfaces built with MoUI.",
        site_url + "?section=showcases",
      )
    WebsiteDocs =>
      match self.website_doc_selected_entry() {
        Some(entry) =>
          (
            entry.title + " - MoUI Docs",
            entry.summary,
            site_url + "?section=docs/" + entry.slug,
          )
        None =>
          (
            "Not Found - MoUI Docs",
            "The requested MoUI documentation page was not found.",
            site_url + "?section=docs/" + self.selected_doc_slug,
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
  services : @host.HostAppServices,
  url : String,
  label : String,
) -> @moui.Effect[Msg] {
  @moui.Effect::host_service(key="website:open-url:" + url, label~, run=_dispatch => {
    ignore(services.open_url(url))
  })
}

///|
fn Model::open_doc_link(
  self : Model,
  target : String,
  services : @host.HostAppServices,
  route_host : WebsiteRouteHost?,
) -> (Model, @moui.Effect[Msg]) {
  if target.has_prefix("https://") || target.has_prefix("http://") {
    return (
      self,
      website_open_url_effect(services, target, "Open documentation link"),
    )
  }
  if target.has_prefix("#") {
    let anchor = website_heading_anchor(target[1:].to_owned())
    let route = "docs/" + self.selected_doc_slug + "?anchor=" + anchor
    let next = self.with_route(route)
    return (
      next,
      @moui.Effect::batch([
        WebsiteRouteCommand::PushRoute(route).effect(route_host),
        WebsiteRouteCommand::ScrollToKey(
          website_anchor_key(anchor),
          @core.ScrollAlignment::Start,
        ).effect(route_host),
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
          WebsiteRouteCommand::PushRoute(route).effect(route_host),
          load,
        ]),
      )
    }
    None => (self, @moui.Effect::none())
  }
}

///|
fn Model::view(self : Model, env : @moui.ViewEnvironment) -> @moui.View[Msg] {
  let theme = website_theme(self.dark)
  let metrics = website_metrics(env.viewport_size())
  let content = match self.page {
    WebsiteHome => self.home_content(theme, metrics)
    WebsiteDocs => self.docs_content(theme, metrics)
    WebsiteShowcases => self.showcases_content(theme, metrics)
  }
  let body = if self.page is WebsiteDocs {
    frame(content, width=metrics.body_scroll_width, height=metrics.body_height).semantics_role(
      @core.SemanticsRole::Main,
    )
  } else {
    scroll_view(
      content,
      state=Some(self.current_body_scroll()),
      width=metrics.body_scroll_width,
      height=metrics.body_height,
      shows_indicator=true,
    ).semantics_role(@core.SemanticsRole::Main)
  }
  let shell = container(
    column(
      [self.top_bar(theme, metrics), body],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=metrics.viewport.width,
    height=metrics.viewport.height,
    background=theme.palette.background,
    theme~,
    padding=0.0,
  )
  self.website_overlay_hosts(shell, theme, metrics)
}

///|
fn Model::program(self : Model) -> @moui.Program[Model, Msg] {
  self.program_with_services(@host.HostAppServices::unavailable())
}

///|
fn Model::program_with_services(
  self : Model,
  services : @host.HostAppServices,
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
    subscriptions=model => model.subscriptions(services, route_host),
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
  services : @host.HostAppServices,
  route_host : WebsiteRouteHost?,
) -> @moui.Subscription[Msg] {
  let subscriptions : Array[@moui.Subscription[Msg]] = []
  match self.catalog_state.pending_id() {
    Some(id) =>
      if id.value > 0 {
        subscriptions.push(
          services.completion_subscription(
            id,
            map=completion => HostCatalogCompleted(completion),
            key="website:catalog:" + id.value.to_string(),
            label="Website docs catalog completion",
          ),
        )
      }
    None => ()
  }
  match self.doc_state.pending_id() {
    Some(id) =>
      if id.value > 0 {
        subscriptions.push(
          services.completion_subscription(
            id,
            map=completion => HostDocsCompleted(completion),
            key="website:docs:" + id.value.to_string(),
            label="Website docs markdown completion",
          ),
        )
      }
    None => ()
  }
  match route_host {
    Some(host) =>
      subscriptions.push(
        host.route_source.subscription(
          key="website:host-route",
          label="Website host route",
          map=event => Some(HostRouteChanged(event)),
        ),
      )
    None => ()
  }
  @moui.Subscription::batch(subscriptions)
}

///|
fn Model::request_catalog(
  self : Model,
  services : @host.HostAppServices,
) -> (Model, @moui.Effect[Msg]) {
  (
    {
      ..self,
      catalog_state: CatalogLoading(@host.HostServiceRequestId::new(0)),
    },
    @moui.Effect::host_service(
      key="website:load-docs-catalog",
      label="Load website docs catalog",
      run=dispatch => {
        let response = services.read_text_file("docs/catalog.json")
        dispatch(
          HostCatalogCompleted(
            website_file_completion("docs/catalog.json", response),
          ),
        )
      },
    ),
  )
}

///|
fn Model::request_selected_doc(
  self : Model,
  services : @host.HostAppServices,
) -> (Model, @moui.Effect[Msg]) {
  match self.website_doc_selected_entry() {
    Some(entry) =>
      (
        {
          ..self,
          page: WebsiteDocs,
          doc_state: DocLoading(@host.HostServiceRequestId::new(0), entry.path),
        },
        @moui.Effect::host_service(
          key="website:load-doc:" + entry.slug,
          label="Load website Markdown document",
          run=dispatch => {
            let response = services.read_text_file(entry.path)
            dispatch(
              HostDocsCompleted(website_file_completion(entry.path, response)),
            )
          },
        ),
      )
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
  completion : @host.HostCompletedServiceResponse,
) -> Model {
  if !self.catalog_completion_matches(completion) {
    return self
  }
  match completion.response {
    @host.HostServiceResponse::Pending(id) =>
      { ..self, catalog_state: CatalogLoading(id) }
    @host.HostServiceResponse::TextFileContent(_, text) =>
      match website_parse_catalog(text) {
        Some(catalog) => { ..self, catalog_state: CatalogLoaded(catalog) }
        None =>
          {
            ..self,
            catalog_state: CatalogFailed("The generated catalog is invalid."),
          }
      }
    @host.HostServiceResponse::Unavailable(reason) =>
      { ..self, catalog_state: CatalogFailed(reason) }
    _ =>
      {
        ..self,
        catalog_state: CatalogFailed("Unexpected catalog host response."),
      }
  }
}

///|
fn Model::catalog_completion_matches(
  self : Model,
  completion : @host.HostCompletedServiceResponse,
) -> Bool {
  match self.catalog_state {
    CatalogLoading(id) =>
      if id.value == 0 {
        completion.id.value == 0 ||
        completion.response is @host.HostServiceResponse::Pending(_)
      } else {
        completion.id == id
      }
    _ => false
  }
}

///|
fn Model::apply_docs_completion(
  self : Model,
  completion : @host.HostCompletedServiceResponse,
) -> Model {
  let path = match completion.request {
    @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::ReadText(path)
    ) => path
    _ => self.website_doc_loading_path()
  }
  if !self.docs_completion_matches_current(completion, path) {
    return self
  }
  match completion.response {
    @host.HostServiceResponse::Pending(id) =>
      { ..self, doc_state: DocLoading(id, path) }
    @host.HostServiceResponse::TextFileContent(_, text) =>
      {
        ..self,
        doc_state: DocLoaded(path, website_parse_markdown_document(path, text)),
      }
    @host.HostServiceResponse::Unavailable(reason) =>
      { ..self, doc_state: DocFailed(path, reason) }
    _ =>
      {
        ..self,
        doc_state: DocFailed(path, "Unexpected document host response."),
      }
  }
}

///|
fn Model::docs_completion_matches_current(
  self : Model,
  completion : @host.HostCompletedServiceResponse,
  path : String,
) -> Bool {
  match self.doc_state {
    DocLoading(id, loading_path) =>
      if path != loading_path {
        false
      } else if id.value == 0 {
        completion.id.value == 0 ||
        completion.response is @host.HostServiceResponse::Pending(_)
      } else {
        completion.id == id
      }
    _ => false
  }
}

///|
fn website_file_completion(
  path : String,
  response : @host.HostServiceResponse,
) -> @host.HostCompletedServiceResponse {
  let id = match response {
    @host.HostServiceResponse::Pending(id) => id
    _ => @host.HostServiceRequestId::new(0)
  }
  {
    id,
    request: @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::ReadText(path),
    ),
    response,
  }
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  Model::new().program()
}

///|
pub fn program_with_services(
  services : @host.HostAppServices,
  route_host? : WebsiteRouteHost? = None,
) -> @moui.Program[Model, Msg] {
  Model::new().program_with_services(services, route_host~)
}

///|
fn moui_repository_url() -> String {
  "https://github.com/wzzc-dev/MoUI"
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
