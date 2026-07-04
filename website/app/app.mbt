///|
pub struct Model {
  dark : Bool
  body_scroll_y : Double
  docs_scroll_y : Double
  hero_count : Int
  page : WebsitePage
  selected_doc_slug : String
  doc_state : WebsiteDocLoadState
}

///|
pub enum Msg {
  ToggleDark
  ScrollBodyTo(Double)
  ScrollDocsTo(Double)
  CounterIncrement
  CounterReset
  OpenRepository
  OpenHome
  OpenHomeAt(Double)
  OpenDocs
  OpenShowcases
  SelectDoc(String)
  RetryDoc
  HostDocsCompleted(@host.HostCompletedServiceResponse)
}

///|
priv struct Metrics {
  viewport : @geometry.Size
  compact : Bool
  content_width : Double
  body_width : Double
  body_scroll_width : Double
  body_height : Double
  body_content_height : Double
  scrollbar_width : Double
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
  let doc = website_default_doc_entry()
  {
    dark: false,
    body_scroll_y: 0.0,
    docs_scroll_y: 0.0,
    hero_count: 0,
    page: WebsiteHome,
    selected_doc_slug: doc.slug,
    doc_state: DocNotLoaded,
  }
}

///|
fn Model::update(self : Model, message : Msg) -> Model {
  match message {
    ToggleDark => { ..self, dark: !self.dark }
    ScrollBodyTo(offset_y) =>
      { ..self, body_scroll_y: max_website_double(0.0, offset_y) }
    ScrollDocsTo(offset_y) =>
      { ..self, docs_scroll_y: max_website_double(0.0, offset_y) }
    CounterIncrement => { ..self, hero_count: self.hero_count + 1 }
    CounterReset => { ..self, hero_count: 0 }
    OpenRepository => self
    OpenHome => { ..self, page: WebsiteHome }
    OpenHomeAt(offset_y) =>
      {
        ..self,
        page: WebsiteHome,
        body_scroll_y: max_website_double(0.0, offset_y),
      }
    OpenDocs => { ..self, page: WebsiteDocs }
    OpenShowcases => {
      let model = {
        ..self,
        page: WebsiteDocs,
        selected_doc_slug: "showcases",
        docs_scroll_y: 0.0,
        doc_state: DocNotLoaded,
      }
      model
    }
    SelectDoc(slug) => {
      let entry = website_doc_entry_by_slug(slug)
      {
        ..self,
        page: WebsiteDocs,
        selected_doc_slug: entry.slug,
        docs_scroll_y: 0.0,
        doc_state: DocNotLoaded,
      }
    }
    RetryDoc => { ..self, doc_state: DocNotLoaded }
    HostDocsCompleted(completion) => self.apply_docs_completion(completion)
  }
}

///|
fn Model::update_with_services(
  self : Model,
  message : Msg,
  services : @host.HostAppServices,
) -> (Model, @moui.Effect[Msg]) {
  match message {
    OpenRepository =>
      (
        self,
        @moui.Effect::host_service(
          key="host:open-moui-repository",
          label="Open MoUI repository",
          run=_dispatch => ignore(services.open_url(moui_repository_url())),
        ),
      )
    OpenDocs => {
      let model = { ..self, page: WebsiteDocs }
      model.request_selected_doc(services)
    }
    OpenShowcases => {
      let model = {
        ..self,
        page: WebsiteDocs,
        selected_doc_slug: "showcases",
        docs_scroll_y: 0.0,
        doc_state: DocNotLoaded,
      }
      model.request_selected_doc(services)
    }
    SelectDoc(slug) => {
      let entry = website_doc_entry_by_slug(slug)
      let model = {
        ..self,
        page: WebsiteDocs,
        selected_doc_slug: entry.slug,
        docs_scroll_y: 0.0,
        doc_state: DocNotLoaded,
      }
      model.request_selected_doc(services)
    }
    RetryDoc => {
      let model = { ..self, doc_state: DocNotLoaded, docs_scroll_y: 0.0 }
      model.request_selected_doc(services)
    }
    HostDocsCompleted(completion) =>
      (self.apply_docs_completion(completion), @moui.Effect::none())
    _ => (self.update(message), @moui.Effect::none())
  }
}

///|
fn Model::view(self : Model, env : @moui.ViewEnvironment) -> @moui.View[Msg] {
  let theme = website_theme(self.dark)
  let metrics = website_metrics(env.viewport_size())
  let content_height = self.website_current_content_height(metrics)
  let scroll_y = match self.page {
    WebsiteHome => self.body_scroll_y
    WebsiteDocs => self.docs_scroll_y
  }
  let max_scroll = max_website_double(0.0, content_height - metrics.body_height)
  let body_scroll_y = clamp_website_double(scroll_y, 0.0, max_scroll)
  let body_content = match self.page {
    WebsiteHome => self.home_content(theme, metrics)
    WebsiteDocs => self.docs_content(theme, metrics)
  }
  let body = row(
    [
      scroll_view(
        body_content,
        offset=@geometry.Point::new(x=0.0, y=body_scroll_y),
        width=metrics.body_scroll_width,
        height=metrics.body_height,
        on_scroll=Some(delta => {
          let next = clamp_website_double(
            body_scroll_y + delta.y,
            0.0,
            max_scroll,
          )
          match self.page {
            WebsiteHome => ScrollBodyTo(next)
            WebsiteDocs => ScrollDocsTo(next)
          }
        }),
      ),
      website_scrollbar(
        theme,
        viewport_height=metrics.body_height,
        content_height~,
        offset_y=body_scroll_y,
      ).frame(width=metrics.scrollbar_width, height=metrics.body_height),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Start,
  ).frame(width=metrics.body_width, height=metrics.body_height)
  container(
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
}

///|
fn Model::program(self : Model) -> @moui.Program[Model, Msg] {
  self.program_with_services(@host.HostAppServices::unavailable())
}

///|
fn Model::program_with_services(
  self : Model,
  services : @host.HostAppServices,
) -> @moui.Program[Model, Msg] {
  @moui.Program::new_with_environment(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => model.update_with_services(message, services),
    view=(model, env) => model.view(env),
    subscriptions=model => model.subscriptions(services),
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
      self.foundation_section(theme, metrics),
      self.platform_section(theme, metrics),
      self.quick_start_section(theme, metrics),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn Model::subscriptions(
  self : Model,
  services : @host.HostAppServices,
) -> @moui.Subscription[Msg] {
  match self.doc_state.pending_id() {
    Some(id) =>
      if id.value <= 0 {
        @moui.Subscription::none()
      } else {
        services.completion_subscription(
          id,
          map=completion => HostDocsCompleted(completion),
          key="website:docs:" + id.value.to_string(),
          label="Website docs markdown completion",
        )
      }
    None => @moui.Subscription::none()
  }
}

///|
fn Model::request_selected_doc(
  self : Model,
  services : @host.HostAppServices,
) -> (Model, @moui.Effect[Msg]) {
  let entry = self.website_doc_selected_entry()
  (
    {
      ..self,
      page: WebsiteDocs,
      selected_doc_slug: entry.slug,
      doc_state: DocLoading(@host.HostServiceRequestId::new(0), entry.path),
    },
    @moui.Effect::host_service(
      key="website:load-doc:" + entry.slug,
      label="Load website markdown doc",
      run=dispatch => {
        let response = services.read_text_file(entry.path)
        dispatch(
          HostDocsCompleted(website_doc_completion(entry.path, response)),
        )
      },
    ),
  )
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
  if path != self.website_doc_loading_path() {
    return self
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
        doc_state: DocFailed(
          path, "unexpected host response while loading docs",
        ),
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
        match completion.response {
          @host.HostServiceResponse::Pending(_) => true
          _ => completion.id == id
        }
      } else {
        completion.id == id
      }
    _ => false
  }
}

///|
fn website_doc_completion(
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
fn Model::website_current_content_height(
  self : Model,
  metrics : Metrics,
) -> Double {
  match self.page {
    WebsiteHome => metrics.body_content_height
    WebsiteDocs => self.website_docs_content_height(metrics)
  }
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  Model::new().program()
}

///|
pub fn program_with_services(
  services : @host.HostAppServices,
) -> @moui.Program[Model, Msg] {
  Model::new().program_with_services(services)
}

///|
fn moui_repository_url() -> String {
  "https://github.com/wzzc-dev/MoUI"
}

///|
fn website_metrics(viewport : @geometry.Size) -> Metrics {
  let compact = viewport.width < 820.0
  let scrollbar_width = 14.0
  let body_scroll_width = max_website_double(
    120.0,
    viewport.width - scrollbar_width,
  )
  let horizontal_margin = if compact { 20.0 } else { 40.0 }
  let content_width = min_website_double(
    max_website_double(280.0, body_scroll_width - horizontal_margin * 2.0),
    1100.0,
  )
  let top_bar_height = 60.0
  let section_top = if compact { 52.0 } else { 82.0 }
  let section_bottom = if compact { 52.0 } else { 82.0 }
  let hero_scene_width = content_width
  let hero_scene_height = if compact { 260.0 } else { 300.0 }
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
  let docs_sidebar_width = if compact { content_width } else { 270.0 }
  {
    viewport,
    compact,
    content_width,
    body_width: viewport.width,
    body_scroll_width,
    body_height: max_website_double(120.0, viewport.height - top_bar_height),
    body_content_height: website_body_content_height(compact),
    scrollbar_width,
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
fn website_body_content_height(compact : Bool) -> Double {
  if compact {
    3500.0
  } else {
    2850.0
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
