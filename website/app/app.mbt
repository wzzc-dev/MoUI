///|
pub(all) enum HeroDemoMode {
  HeroSource
  HeroCounter
} derive(Eq)

///|
pub(all) struct Model {
  dark : Bool
  body_scroll_y : Double
  hero_demo : HeroDemoMode
  hero_count : Int
}

///|
pub(all) enum Msg {
  ToggleDark
  ScrollBodyTo(Double)
  SelectHeroDemo(HeroDemoMode)
  CounterIncrement
  CounterReset
  OpenRepository
}

///|
priv struct Metrics {
  viewport : @core.Size
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
  hero_copy_width : Double
  hero_scene_width : Double
  hero_scene_height : Double
  feature_card_width : Double
  platform_card_width : Double
}

///|
pub fn Model::new() -> Model {
  { dark: false, body_scroll_y: 0.0, hero_demo: HeroCounter, hero_count: 0 }
}

///|
pub fn Model::update(self : Model, message : Msg) -> Model {
  match message {
    ToggleDark => { ..self, dark: !self.dark }
    ScrollBodyTo(offset_y) =>
      { ..self, body_scroll_y: max_website_double(0.0, offset_y) }
    SelectHeroDemo(mode) => { ..self, hero_demo: mode }
    CounterIncrement => { ..self, hero_count: self.hero_count + 1 }
    CounterReset => { ..self, hero_count: 0 }
    OpenRepository => self
  }
}

///|
pub fn Model::update_with_services(
  self : Model,
  message : Msg,
  services : @host.HostAppServices,
) -> (Model, @core.Effect[Msg]) {
  match message {
    OpenRepository =>
      (
        self,
        @core.Effect::host_service(
          key="host:open-moui-repository",
          label="Open MoUI repository",
          run=_dispatch => ignore(services.open_url(moui_repository_url())),
        ),
      )
    _ => (self.update(message), @core.Effect::none())
  }
}

///|
pub fn Model::view(
  self : Model,
  env : @core.ViewEnvironment,
) -> @core.View[Msg] {
  let theme = website_theme(self.dark)
  let metrics = website_metrics(env.viewport_size())
  let max_scroll = max_website_double(
    0.0,
    metrics.body_content_height - metrics.body_height,
  )
  let body_scroll_y = clamp_website_double(self.body_scroll_y, 0.0, max_scroll)
  let body_content = column(
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
  let body = row(
    [
      scroll_view(
        body_content,
        offset=@core.Point::new(x=0.0, y=body_scroll_y),
        width=metrics.body_scroll_width,
        height=metrics.body_height,
        on_scroll=Some(delta => {
          ScrollBodyTo(
            clamp_website_double(body_scroll_y - delta.y, 0.0, max_scroll),
          )
        }),
      ),
      website_scrollbar(
        theme,
        viewport_height=metrics.body_height,
        content_height=metrics.body_content_height,
        offset_y=body_scroll_y,
      ).frame(width=metrics.scrollbar_width, height=metrics.body_height),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Start,
  ).frame(width=metrics.body_width, height=metrics.body_height)
  surface(
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
pub fn Model::runtime(
  self : Model,
  width? : Double = 1180.0,
  height? : Double = 760.0,
) -> @core.AppRuntime {
  self.runtime_with_services(
    @host.HostAppServices::unavailable(),
    width~,
    height~,
  )
}

///|
pub fn Model::runtime_with_services(
  self : Model,
  services : @host.HostAppServices,
  width? : Double = 1180.0,
  height? : Double = 760.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::new_with_environment(
      init=() => (self, @core.Effect::none()),
      update=(model, message) => model.update_with_services(message, services),
      view=(model, env) => model.view(env),
    ),
    size=@core.Size::new(width~, height~),
  )
}

///|
pub fn runtime(
  width? : Double = 1180.0,
  height? : Double = 760.0,
) -> @core.AppRuntime {
  Model::new().runtime(width~, height~)
}

///|
pub fn runtime_with_services(
  services : @host.HostAppServices,
  width? : Double = 1180.0,
  height? : Double = 760.0,
) -> @core.AppRuntime {
  Model::new().runtime_with_services(services, width~, height~)
}

///|
fn moui_repository_url() -> String {
  "https://github.com/wzzc-dev/MoUI"
}

///|
fn website_metrics(viewport : @core.Size) -> Metrics {
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
  let hero_scene_width = if compact {
    min_website_double(content_width, 430.0)
  } else {
    clamp_website_double(content_width * 0.50, 520.0, 560.0)
  }
  let hero_scene_height = if compact { 264.0 } else { 426.0 }
  let hero_copy_width = if compact {
    content_width
  } else {
    max_website_double(390.0, content_width - hero_scene_width - 52.0)
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
fn website_theme(dark : Bool) -> @core.Theme {
  let scheme = if dark {
    @core.ColorScheme::Dark
  } else {
    @core.ColorScheme::Light
  }
  let palette : @core.ColorPalette = if dark {
    {
      foreground: @core.Color::rgba(r=0.91, g=0.92, b=0.96),
      background: @core.Color::rgba(r=0.06, g=0.06, b=0.08),
      surface: @core.Color::rgba(r=0.09, g=0.09, b=0.12),
      surface_variant: @core.Color::rgba(r=0.15, g=0.16, b=0.22),
      primary: @core.Color::rgba(r=0.18, g=0.83, b=0.75),
      primary_foreground: @core.Color::white(),
      outline: @core.Color::rgba(r=0.15, g=0.16, b=0.23),
      muted: @core.Color::rgba(r=0.55, g=0.58, b=0.66),
    }
  } else {
    {
      foreground: @core.Color::rgba(r=0.07, g=0.09, b=0.14),
      background: @core.Color::rgba(r=0.98, g=0.98, b=0.98),
      surface: @core.Color::white(),
      surface_variant: @core.Color::rgba(r=0.95, g=0.96, b=0.97),
      primary: @core.Color::rgba(r=0.0, g=0.44, b=0.40),
      primary_foreground: @core.Color::white(),
      outline: @core.Color::rgba(r=0.90, g=0.91, b=0.93),
      muted: @core.Color::rgba(r=0.42, g=0.45, b=0.50),
    }
  }
  let typography : @core.TypographyScale = {
    body: @core.FontSpec::new(size=16.0, weight=500),
    title: @core.FontSpec::new(size=28.0, weight=800),
    caption: @core.FontSpec::new(size=13.0, weight=500),
    control: @core.FontSpec::new(size=15.0, weight=700),
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
