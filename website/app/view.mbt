///|
fn Model::top_bar(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let action_label = if self.dark { "☀" } else { "☾" }
  let action_accessibility_label = if self.dark {
    "Switch to light theme"
  } else {
    "Switch to dark theme"
  }
  let items : Array[@moui.View[Msg]] = [brand_mark(theme)]
  if !metrics.nav_compact {
    items.push(
      nav_button(theme, "Home", self.page is WebsiteHome, OpenHomeAt(0.0)),
    )
    items.push(
      nav_button(theme, "Tutorial", self.page is WebsiteTutorial, OpenTutorial),
    )
    items.push(
      nav_button(theme, "Quick Start", false, OpenHomeAnchor("quick-start")),
    )
    items.push(
      nav_button(
        theme,
        "Showcases",
        self.page is WebsiteShowcases,
        OpenShowcases,
      ),
    )
    items.push(nav_button(theme, "Docs", self.page is WebsiteDocs, OpenDocs))
    items.push(nav_button(theme, "GitHub", false, OpenRepository))
  } else {
    items.push(
      button(
        "Menu",
        on_click=ToggleMobileMenu,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=72.0,
        height=34.0,
      ).semantics_expanded(expanded=self.mobile_menu_open),
    )
  }
  items.push(spacer(min_length=12.0, weight=1.0))
  items.push(
    button(
      action_label,
      on_click=ToggleDark,
      variant=@views.ButtonVariant::Outline,
      theme~,
      width=48.0,
      height=34.0,
    )
    .font(@text.FontSpec::new(size=18.0, weight=760))
    .accessibility_label(action_accessibility_label),
  )
  let top_bar_content = row(
    [
      spacer(min_length=0.0, weight=1.0),
      frame(
        row(
          items,
          spacing=if metrics.nav_compact { 8.0 } else { 18.0 },
          align=@views.CrossAlign::Center,
        ),
        width=metrics.content_width,
        height=metrics.top_bar_height,
      ),
      spacer(min_length=0.0, weight=1.0),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Center,
  )
  container(
    frame(
      top_bar_content,
      width=metrics.viewport.width,
      height=metrics.top_bar_height,
    ),
    width=metrics.viewport.width,
    height=metrics.top_bar_height,
    background=theme.palette.background.multiply_alpha(0.94),
    corner_radius=0.0,
    theme~,
    padding=0.0,
  )
  .border(website_border(theme))
  .semantics_role(@core.SemanticsRole::Navigation)
  .accessibility_label("Website navigation")
}

///|
fn brand_mark(theme : @moui.Theme) -> @moui.View[Msg] {
  row(
    [
      text("MoUI", width=72.0, height=26.0)
      .font(@text.FontSpec::new(size=19.0, weight=820))
      .foreground(theme.palette.foreground),
      text("MoonBit UI", width=88.0, height=20.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  ).frame(width=164.0, height=44.0)
}

///|
fn Model::showcases_content(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let card_width = if metrics.compact {
    metrics.content_width
  } else {
    clamp_website_double((metrics.content_width - 32.0) / 2.0, 360.0, 540.0)
  }
  let thumb_height = card_width * 0.56
  let entries = website_showcase_entries()
  let columns = if metrics.compact { 1 } else { 2 }
  let card_height = thumb_height + 110.0
  let grid_height = min_website_double(
    max_website_double(card_height + 20.0, metrics.body_height - 190.0),
    if metrics.compact {
      card_height * 2.0 + 20.0
    } else {
      card_height * 1.5
    },
  )
  section_shell(
    theme,
    metrics,
    column(
      [
        section_header(
          theme,
          "Showcases",
          "MoUI 示例截图展示",
          "Click any screenshot to open its source on GitHub.",
          metrics.content_width,
        ),
        lazy_grid(
          entries,
          entry => entry.slug,
          entry => showcase_card(theme, entry, card_width, thumb_height),
          state=self.showcase_grid_scroll,
          columns~,
          item_height=card_height,
          viewport_width=metrics.content_width,
          viewport_height=grid_height,
          row_spacing=20.0,
          column_spacing=16.0,
        ),
      ],
      spacing=24.0,
      align=@views.CrossAlign::Start,
    ),
    top=metrics.section_top,
    bottom=metrics.section_bottom,
    background=Some(showcase_section_background(theme)),
  )
}

///|
fn showcase_card(
  theme : @moui.Theme,
  entry : WebsiteShowcaseEntry,
  width : Double,
  thumb_height : Double,
) -> @moui.View[Msg] {
  let source_url = entry.source_url
  let slug = entry.slug
  let title = entry.title
  let subtitle = entry.subtitle
  container(
    column(
      [
        container(
          image(
            showcase_image_source(slug),
            width=width - 2.0,
            height=thumb_height,
            fit=@graphics.ImageFit::Contain,
          )
          .on_tap(OpenShowcaseSource(source_url))
          .semantics_role(@core.SemanticsRole::Link)
          .semantics_url(source_url)
          .accessibility_label("Open source for " + title),
          width~,
          height=thumb_height,
          corner_radius=8.0,
          theme~,
          padding=0.0,
        ),
        column(
          [
            text(title, width=width - 32.0, height=28.0)
            .font(theme.typography.control)
            .foreground(theme.palette.foreground),
            text(subtitle, width=width - 32.0, height=22.0)
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Start,
        ),
        button(
          "Open Source",
          on_click=OpenShowcaseSource(source_url),
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=width - 32.0,
          height=36.0,
        ),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=thumb_height + 110.0,
    background=theme.palette.background,
    corner_radius=8.0,
    theme~,
    padding=1.0,
  ).border(website_border(theme))
}

///|
priv struct WebsiteShowcaseEntry {
  slug : String
  title : String
  subtitle : String
  source_url : String
}

///|
fn website_showcase_entries() -> Array[WebsiteShowcaseEntry] {
  [
    {
      slug: "showcase",
      title: "Showcase",
      subtitle: "Visual component catalog",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase",
    },
    {
      slug: "ios-componentgallery",
      title: "iOS Showcase",
      subtitle: "Showcase mobile workspace on iOS",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase",
    },
    {
      slug: "harmonyos-componentgallery",
      title: "HarmonyOS Showcase",
      subtitle: "Showcase mobile workspace on HarmonyOS",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase",
    },
    {
      slug: "markdown_editor",
      title: "Markdown Editor",
      subtitle: "WYSIWYG Markdown editing",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/markdown_editor",
    },
    {
      slug: "mo_workbench",
      title: "Mo Workbench",
      subtitle: "Desktop agent workspace",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/mo_workbench",
    },
    {
      slug: "excel",
      title: "Excel Viewer",
      subtitle: "MoonBit Excel file renderer",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/excel",
    },
    {
      slug: "webview",
      title: "WebView Demo",
      subtitle: "Native platform WebView shell",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/webview_demo",
    },
    {
      slug: "android-componentgallery",
      title: "Android Showcase",
      subtitle: "Showcase mobile workspace on Android",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase",
    },
  ]
}

///|
fn nav_button(
  theme : @moui.Theme,
  label : String,
  active : Bool,
  message : Msg,
) -> @moui.View[Msg] {
  button(
    label,
    on_click=message,
    variant=if active {
      @views.ButtonVariant::Ghost
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    width=if label == "Quick Start" {
      102.0
    } else if label == "Showcases" {
      92.0
    } else {
      76.0
    },
    height=34.0,
  ).foreground(if active { theme.palette.primary } else { theme.palette.muted })
}

///|
fn Model::hero(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let ctas = row(
    [
      button(
        "Get Started",
        on_click=OpenHomeAnchor("quick-start"),
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=134.0,
        height=if metrics.compact { 40.0 } else { 46.0 },
      ).foreground(theme.palette.foreground),
      button(
        "GitHub",
        on_click=OpenRepository,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=104.0,
        height=if metrics.compact { 40.0 } else { 46.0 },
      ).foreground(theme.palette.foreground),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Center,
  )
  let copy = if metrics.compact {
    column(
      [
        text("MoUI", width=metrics.hero_copy_width, height=46.0)
        .font(hero_title_font(metrics))
        .foreground(theme.palette.primary),
        text(
          "MoonBit GUI Framework",
          width=metrics.hero_copy_width,
          height=42.0,
        )
        .font(hero_statement_font(metrics))
        .foreground(theme.palette.foreground),
        text(
          "Typed UI for web and native hosts.",
          width=metrics.hero_copy_width,
          height=24.0,
        )
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        text(
          "Model / Msg / update / view.",
          width=metrics.hero_copy_width,
          height=24.0,
        )
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        text(
          "MoonBit 应用逻辑共享到 Web 与原生。",
          width=metrics.hero_copy_width,
          height=28.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        ctas,
      ],
      spacing=7.0,
      align=@views.CrossAlign::Start,
    )
  } else {
    column(
      [
        text("MoUI", width=metrics.hero_copy_width, height=62.0)
        .font(hero_title_font(metrics))
        .foreground(theme.palette.primary),
        text(
          "MoonBit GUI Framework",
          width=metrics.hero_copy_width,
          height=54.0,
        )
        .font(hero_statement_font(metrics))
        .foreground(theme.palette.foreground),
        text(
          "Typed, declarative UI for web and native hosts.",
          width=metrics.hero_copy_width,
          height=26.0,
        )
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        text(
          "Model, Msg, update, view. One app surface, several render routes.",
          width=metrics.hero_copy_width,
          height=26.0,
        )
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        text(
          "用 MoonBit 写一次应用逻辑，让 Web 与原生宿主共享同一套界面模型。",
          width=metrics.hero_copy_width,
          height=34.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        ctas,
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    )
  }
  let visual = if metrics.compact {
    let tab = segmented_control(
      [
        @views.choice_item("source", "Source"),
        @views.choice_item("counter", "Counter"),
      ],
      selected=self.compact_hero_tab,
      on_select=value => SelectCompactHeroTab(value),
      theme~,
      width=metrics.hero_scene_width,
    )
    let panel = if self.compact_hero_tab == "counter" {
      hero_counter_panel(
        theme,
        metrics.hero_scene_width,
        metrics.hero_scene_height - 48.0,
        true,
        self.hero_count,
      )
    } else {
      hero_source_panel(
        theme,
        metrics.hero_scene_width,
        metrics.hero_scene_height - 48.0,
        true,
      )
    }
    column([tab, panel], spacing=8.0, align=@views.CrossAlign::Start)
  } else {
    hero_demo_panel(
      theme,
      metrics.hero_scene_width,
      metrics.hero_scene_height,
      false,
      self.hero_count,
    )
  }
  let hero_body = column(
    [copy, visual],
    spacing=if metrics.compact { 18.0 } else { 14.0 },
    align=@views.CrossAlign::Center,
  )
  painted_section_shell(
    theme,
    metrics,
    hero_body,
    top=if metrics.compact { 24.0 } else { 20.0 },
    bottom=if metrics.compact { 24.0 } else { 10.0 },
    background=Some(hero_background(theme)),
    dotted=true,
    wash=false,
  )
}

///|
fn Model::capability_strip(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  ignore(self)
  let stat_width = if metrics.compact {
    metrics.content_width
  } else {
    clamp_website_double((metrics.content_width - 36.0) / 4.0, 240.0, 286.0)
  }
  section_shell(
    theme,
    metrics,
    grid(
      [
        metric_card(
          theme,
          "App surface",
          "View[Msg]",
          caption="Opaque public API",
          width=stat_width,
          accent=website_blue(theme),
        ),
        metric_card(
          theme,
          "Runtime model",
          "TEA",
          caption="Model -> update -> view",
          width=stat_width,
          accent=website_green(theme),
        ),
        metric_card(
          theme,
          "Render routes",
          "3",
          caption="WGPU / Skia / WebGPU",
          width=stat_width,
          accent=website_amber(theme),
        ),
        metric_card(
          theme,
          "Targets",
          "4",
          caption="Web, macOS, Windows, Linux",
          width=stat_width,
          accent=theme.palette.muted,
        ),
      ],
      columns=if metrics.compact { 1 } else { 4 },
      row_spacing=12.0,
      column_spacing=12.0,
    ),
    top=20.0,
    bottom=26.0,
    background=Some(theme.palette.surface_variant.multiply_alpha(0.30)),
  )
}

///|
fn Model::foundation_section(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  ignore(self)
  section_shell(
    theme,
    metrics,
    column(
      [
        section_header(
          theme,
          "Why use MoUI with MoonBit?",
          "声明式、强类型、跨平台，保持应用逻辑清晰可测试。",
          "A small public app surface sits above explicit runtime, host, and renderer contracts.",
          metrics.content_width,
        ),
        responsive_grid(
          [
            feature_card(
              theme,
              "1",
              "Predictable",
              "Model, Msg, update, view.",
              "Typed messages drive one explicit update path.",
              metrics.feature_card_width,
              theme.palette.primary,
            ),
            feature_card(
              theme,
              "T",
              "Strict Types",
              "Opaque View[Msg] public API.",
              "No stringly UI protocol or Any sprawl.",
              metrics.feature_card_width,
              theme.palette.primary,
            ),
            feature_card(
              theme,
              "[]",
              "Modular Hosts",
              "Shared app, thin entrypoints.",
              "Web and native hosts reuse the same model.",
              metrics.feature_card_width,
              theme.palette.primary,
            ),
            feature_card(
              theme,
              "{}",
              "Renderer Neutral",
              "WGPU, Skia, WebGPU.",
              "Renderer capability stays out of app logic.",
              metrics.feature_card_width,
              theme.palette.primary,
            ),
          ],
          width=metrics.content_width,
          min_column_width=metrics.feature_card_width,
          row_spacing=16.0,
          column_spacing=16.0,
        ),
      ],
      spacing=38.0,
      align=@views.CrossAlign::Start,
    ),
    top=metrics.section_top,
    bottom=metrics.section_bottom,
    background=Some(theme.palette.surface_variant.multiply_alpha(0.42)),
  )
}

///|
fn Model::platform_section(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  ignore(self)
  section_shell(
    theme,
    metrics,
    column(
      [
        section_header(
          theme,
          "Built with MoUI",
          "官网首页本身就是一个由 MoUI 渲染的 Web wasm-gc 应用。",
          "Real app surfaces that exercise the same public View[Msg] model.",
          metrics.content_width,
        ),
        responsive_grid(
          [
            platform_card(
              theme,
              "MoUI Website",
              "Official homepage",
              [
                "This page: shared app logic", "in website/app and a thin", "Web entrypoint.",
              ],
              "MoUI",
              1.0,
              metrics.platform_card_width,
              theme.palette.primary,
            ),
            platform_card(
              theme,
              "Showcase",
              "Component gallery",
              [
                "Layout, input, drawing,", "renderer reporting, and", "platform smoke paths.",
              ],
              "01",
              0.76,
              metrics.platform_card_width,
              website_amber(theme),
            ),
            platform_card(
              theme,
              "Markdown Editor",
              "WYSIWYG editing",
              [
                "Source and visual editing", "share one typed Markdown", "application model.",
              ],
              "02",
              0.70,
              metrics.platform_card_width,
              website_blue(theme),
            ),
            platform_card(
              theme,
              "Mo Workbench",
              "Agent workspace",
              [
                "Native Skia dogfood surface", "for workflow, evidence, and", "session state.",
              ],
              "03",
              0.64,
              metrics.platform_card_width,
              website_green(theme),
            ),
          ],
          width=metrics.content_width,
          min_column_width=metrics.platform_card_width,
          row_spacing=16.0,
          column_spacing=12.0,
        ),
      ],
      spacing=24.0,
      align=@views.CrossAlign::Start,
    ),
    top=metrics.section_top,
    bottom=metrics.section_bottom,
    background=Some(showcase_section_background(theme)),
  )
}

///|
fn Model::quick_start_section(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let panel_width = if metrics.compact {
    metrics.content_width
  } else {
    min_website_double(720.0, metrics.content_width)
  }
  section_shell(
    theme,
    metrics,
    column(
      [
        quick_start_header(theme, panel_width),
        self.quick_start_steps(theme, panel_width),
        quick_start_actions(theme),
      ],
      spacing=28.0,
      align=@views.CrossAlign::Center,
    ),
    top=metrics.section_top,
    bottom=metrics.section_bottom,
    background=Some(theme.palette.surface_variant.multiply_alpha(0.36)),
  )
}

///|
fn section_shell(
  theme : @moui.Theme,
  metrics : Metrics,
  child : @moui.View[Msg],
  top~ : Double,
  bottom~ : Double,
  background~ : @graphics.Color?,
) -> @moui.View[Msg] {
  let centered = frame(
    row(
      [
        spacer(min_length=0.0, weight=1.0),
        frame(child, width=metrics.content_width),
        spacer(min_length=0.0, weight=1.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=metrics.viewport.width,
  )
  let padded = padding_edges(centered, top~, right=0.0, bottom~, left=0.0)
  match background {
    Some(color) =>
      container(
        padded,
        width=metrics.viewport.width,
        background=color,
        corner_radius=0.0,
        theme~,
        padding=0.0,
      )
    None => padded
  }
}

///|
fn painted_section_shell(
  theme : @moui.Theme,
  metrics : Metrics,
  child : @moui.View[Msg],
  top~ : Double,
  bottom~ : Double,
  background~ : @graphics.Color?,
  dotted~ : Bool,
  wash~ : Bool,
) -> @moui.View[Msg] {
  ignore(dotted)
  ignore(wash)
  section_shell(theme, metrics, child, top~, bottom~, background~)
}

///|
fn section_header(
  theme : @moui.Theme,
  title : String,
  summary_zh : String,
  summary : String,
  width : Double,
) -> @moui.View[Msg] {
  column(
    [
      text(title, width~, height=46.0)
      .font(@text.FontSpec::new(size=32.0, weight=820))
      .foreground(theme.palette.foreground),
      text(summary_zh, width~, height=30.0)
      .font(@text.FontSpec::new(size=15.0, weight=520))
      .foreground(theme.palette.muted),
      text(summary, width~, height=30.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn metric_card(
  theme : @moui.Theme,
  label : String,
  value : String,
  caption~ : String,
  width~ : Double,
  accent~ : @graphics.Color,
) -> @moui.View[Msg] {
  container(
    column(
      [
        text(label, width=width - 28.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(value, width=width - 28.0, height=42.0)
        .font(@text.FontSpec::new(size=26.0, weight=820))
        .foreground(accent),
        text(caption, width=width - 28.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=116.0,
    background=theme.palette.surface,
    corner_radius=theme.radius_scale.lg,
    theme~,
    padding=14.0,
  ).border(website_border(theme))
}

///|
fn feature_card(
  theme : @moui.Theme,
  index : String,
  title : String,
  zh_summary : String,
  summary : String,
  width : Double,
  accent : @graphics.Color,
) -> @moui.View[Msg] {
  let content_width = width - 40.0
  container(
    column(
      [
        row(
          [
            container(
              text(index, width=28.0, height=28.0)
              .font(@text.FontSpec::new(size=16.0, weight=820))
              .foreground(accent),
              width=36.0,
              height=36.0,
              background=accent.multiply_alpha(0.10),
              corner_radius=8.0,
              theme~,
              padding=4.0,
            ),
            text(title, width=content_width - 48.0, height=30.0)
            .font(theme.typography.control)
            .foreground(theme.palette.foreground),
          ],
          spacing=12.0,
          align=@views.CrossAlign::Center,
        ),
        text(zh_summary, width=content_width, height=34.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        text(summary, width=content_width, height=44.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=162.0,
    background=theme.palette.surface,
    corner_radius=8.0,
    theme~,
    padding=20.0,
  ).border(website_border(theme))
}

///|
fn platform_card(
  theme : @moui.Theme,
  title : String,
  subtitle : String,
  summary_lines : Array[String],
  status : String,
  value : Double,
  width : Double,
  accent : @graphics.Color,
) -> @moui.View[Msg] {
  ignore(value)
  container(
    column(
      [
        showcase_thumb(theme, status, width - 2.0, accent),
        column(
          [
            text(title, width=width - 32.0, height=28.0)
            .font(theme.typography.control)
            .foreground(theme.palette.foreground),
            text(subtitle, width=width - 32.0, height=24.0)
            .font(theme.typography.caption)
            .foreground(accent),
            platform_card_summary(theme, summary_lines, width - 32.0),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=246.0,
    background=theme.palette.background,
    corner_radius=12.0,
    theme~,
    padding=1.0,
  ).border(website_border(theme))
}

///|
fn platform_card_summary(
  theme : @moui.Theme,
  lines : Array[String],
  width : Double,
) -> @moui.View[Msg] {
  column(
    lines.map(line => {
      text(line, width~, height=17.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted)
    }),
    spacing=1.0,
    align=@views.CrossAlign::Start,
  ).frame(width~, height=58.0)
}

///|
fn showcase_thumb(
  theme : @moui.Theme,
  label : String,
  width : Double,
  accent : @graphics.Color,
) -> @moui.View[Msg] {
  ignore(theme)
  let foreground = accent
  let font = @text.FontSpec::new(size=24.0, weight=820)
  custom_layout(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width~, height=118.0))
    },
    paint=(ctx, frame) => {
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=frame, radius=12.0),
        @graphics.Brush::solid(accent.multiply_alpha(0.08)),
      )
      let stripe = 12.0
      let count = ((frame.size.width + frame.size.height) / stripe)
        .ceil()
        .to_int()
      for index in 0..<count {
        let start_x = frame.origin.x + index.to_double() * stripe
        draw_path(
          ctx,
          @graphics.PathSpec::new(
            verbs=[
              @graphics.PathVerb::MoveTo(
                @geometry.Point::new(
                  x=start_x,
                  y=frame.origin.y + frame.size.height,
                ),
              ),
              @graphics.PathVerb::LineTo(
                @geometry.Point::new(
                  x=start_x - frame.size.height,
                  y=frame.origin.y,
                ),
              ),
            ],
            stroke=Some(@graphics.Brush::solid(accent.multiply_alpha(0.18))),
            stroke_width=1.0,
          ),
        )
      }
      draw_text(
        ctx,
        @text.TextRun::new(
          text=label,
          frame=@geometry.Rect::new(
            x=frame.origin.x,
            y=frame.origin.y + 41.0,
            width=frame.size.width,
            height=36.0,
          ),
          font~,
          color=foreground,
        ),
      )
    },
    semantics_label="Showcase thumbnail",
  )
}

///|
fn quick_start_header(theme : @moui.Theme, width : Double) -> @moui.View[Msg] {
  column(
    [
      text("Quick Start / 快速开始", width~, height=44.0)
      .font(@text.FontSpec::new(size=34.0, weight=820))
      .foreground(theme.palette.foreground),
      text(
        "From zero to a running app in three steps. / 三步从零跑通应用。",
        width~,
        height=28.0,
      )
      .font(@text.FontSpec::new(size=15.0, weight=480))
      .foreground(theme.palette.muted),
    ],
    spacing=10.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn Model::quick_start_steps(
  self : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let steps = [
    (
      "1",
      "Install the CLI / 安装 CLI",
      ["moon install wzzc-dev/moui_cli/cmd/moui"],
    ),
    (
      "2",
      "Create the app / 创建应用",
      ["moui new my_app", "cd my_app", "moon update", "moon check"],
    ),
    (
      "3",
      "Run on the host / 在本机运行",
      ["moon run macos_skia --target native"],
    ),
  ]
  let rows : Array[@moui.View[Msg]] = []
  let last = steps.length() - 1
  for index = 0; index < steps.length(); index = index + 1 {
    let (number, title, lines) = steps[index]
    rows.push(
      self.quick_start_step(
        theme,
        width,
        number,
        title,
        lines,
        show_connector=index < last,
      ),
    )
  }
  column(rows, spacing=18.0, align=@views.CrossAlign::Start)
}

///|
fn Model::quick_start_step(
  self : Model,
  theme : @moui.Theme,
  width : Double,
  number : String,
  title : String,
  lines : Array[String],
  show_connector~ : Bool,
) -> @moui.View[Msg] {
  let badge_size = 30.0
  let rail_width = 36.0
  let content_width = max_website_double(180.0, width - rail_width - 12.0)
  let rail_children : Array[@moui.View[Msg]] = [
    quick_start_step_badge(theme, number, badge_size),
  ]
  if show_connector {
    rail_children.push(
      container(
        spacer(min_length=0.0, weight=1.0),
        width=2.0,
        height=if lines.length() > 1 { 118.0 } else { 54.0 },
        background=theme.palette.outline.multiply_alpha(0.35),
        corner_radius=1.0,
        theme~,
        padding=0.0,
      ),
    )
  }
  row(
    [
      column(rail_children, spacing=8.0, align=@views.CrossAlign::Center).frame(
        width=rail_width,
      ),
      column(
        [
          text(
            title,
            width=content_width,
            height=28.0,
            align=@text.TextAlign::TextStart,
          )
          .font(@text.FontSpec::new(size=17.0, weight=700))
          .foreground(theme.palette.foreground),
          self.quick_start_code_block(theme, content_width, lines),
        ],
        spacing=10.0,
        align=@views.CrossAlign::Start,
      ),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn quick_start_step_badge(
  theme : @moui.Theme,
  number : String,
  size : Double,
) -> @moui.View[Msg] {
  let fill = website_green(theme)
  let font = @text.FontSpec::new(size=13.0, weight=780)
  custom_layout(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width=size, height=size))
    },
    paint=(ctx, frame) => {
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=frame, radius=size / 2.0),
        @graphics.Brush::solid(fill),
      )
      draw_text(
        ctx,
        @text.TextRun::new(
          text=number,
          frame~,
          font~,
          color=@graphics.Color::white(),
          align=@text.TextAlign::TextCenter,
        ),
      )
    },
    semantics_label="Step \{number}",
  )
}

///|
fn Model::quick_start_code_block(
  self : Model,
  theme : @moui.Theme,
  width : Double,
  lines : Array[String],
) -> @moui.View[Msg] {
  let pad = 14.0
  let gap = 12.0
  let copy_height = 30.0
  let line_height = 22.0
  let line_gap = 4.0
  let font_size = if width < 360.0 { 12.0 } else { 13.5 }
  let mono_font = @text.FontSpec::new(
    size=font_size,
    weight=560,
    families=@text.FontFamilyStack::monospace(),
  )
  let copy_text = quick_start_join_lines(lines)
  let copied = match self.copied_text {
    Some(value) => value == copy_text
    None => false
  }
  let copy_width = if copied { 70.0 } else { 58.0 }
  let code_width = max_website_double(
    96.0,
    width - pad * 2.0 - copy_width - gap,
  )
  let line_views : Array[@moui.View[Msg]] = []
  for line in lines {
    line_views.push(
      text(
        line,
        width=code_width,
        height=line_height,
        align=@text.TextAlign::TextStart,
      )
      .font(mono_font)
      .foreground(quick_start_code_foreground(theme)),
    )
  }
  let code_height = if lines.length() <= 0 {
    line_height
  } else {
    lines.length().to_double() * line_height +
    (lines.length() - 1).to_double() * line_gap
  }
  let content_height = max_website_double(code_height, copy_height)
  container(
    row(
      [
        column(line_views, spacing=line_gap, align=@views.CrossAlign::Start).frame(
          width=code_width,
          height=code_height,
        ),
        button(
          if copied {
            "Copied"
          } else {
            "Copy"
          },
          on_click=CopyText(copy_text),
          style=quick_start_copy_button_style(theme, copied),
          theme~,
          width=if copied { 70.0 } else { copy_width },
          height=copy_height,
        ),
      ],
      spacing=gap,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=content_height + pad * 2.0,
    background=quick_start_code_background(theme),
    corner_radius=12.0,
    theme~,
    padding=pad,
  )
}

///|
fn quick_start_copy_button_style(
  theme : @moui.Theme,
  copied : Bool,
) -> @views.ButtonStyle {
  ignore(theme)
  let label = if copied {
    @graphics.Color::rgba(r=0.05, g=0.12, b=0.11)
  } else {
    @graphics.Color::rgba(r=0.78, g=0.98, b=0.92)
  }
  let fill = if copied {
    @graphics.Color::rgba(r=0.45, g=0.92, b=0.82)
  } else {
    @graphics.Color::rgba(r=0.12, g=0.20, b=0.19)
  }
  let hover_fill = if copied {
    @graphics.Color::rgba(r=0.55, g=0.95, b=0.86)
  } else {
    @graphics.Color::rgba(r=0.16, g=0.26, b=0.24)
  }
  let press_fill = if copied {
    @graphics.Color::rgba(r=0.38, g=0.84, b=0.74)
  } else {
    @graphics.Color::rgba(r=0.10, g=0.17, b=0.16)
  }
  let border = @graphics.Color::rgba(r=0.45, g=0.92, b=0.82)
  let radius = 8.0
  let normal = @views.new_control_state_style(
    foreground=label,
    background=@graphics.Brush::solid(fill),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border),
      width=1.0,
    ),
    radius~,
  )
  let hovered = @views.new_control_state_style(
    foreground=label,
    background=@graphics.Brush::solid(hover_fill),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border),
      width=1.0,
    ),
    radius~,
  )
  let pressed = @views.new_control_state_style(
    foreground=label,
    background=@graphics.Brush::solid(press_fill),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border),
      width=1.0,
    ),
    radius~,
  )
  let disabled = @views.new_control_state_style(
    foreground=@graphics.Color::rgba(r=0.55, g=0.62, b=0.60),
    background=@graphics.Brush::solid(
      @graphics.Color::rgba(r=0.10, g=0.14, b=0.13),
    ),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(
        @graphics.Color::rgba(r=0.30, g=0.38, b=0.36),
      ),
      width=1.0,
    ),
    radius~,
  )
  @views.ButtonStyle::new(normal~, hovered~, pressed~, disabled~)
}

///|
fn quick_start_actions(theme : @moui.Theme) -> @moui.View[Msg] {
  row(
    [
      button(
        "Read the Docs",
        on_click=OpenDocs,
        variant=@views.ButtonVariant::Primary,
        theme~,
        width=148.0,
        height=42.0,
      ),
      button(
        "Open Playground",
        on_click=OpenPlayground,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=156.0,
        height=42.0,
      ).foreground(theme.palette.foreground),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn quick_start_join_lines(lines : Array[String]) -> String {
  let mut joined = ""
  for index = 0; index < lines.length(); index = index + 1 {
    if index > 0 {
      joined = "\{joined}\n"
    }
    joined = "\{joined}\{lines[index]}"
  }
  joined
}

///|
fn quick_start_code_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.05, g=0.09, b=0.09)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.07, g=0.12, b=0.11)
  }
}

///|
fn quick_start_code_foreground(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.55, g=0.95, b=0.86)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.45, g=0.92, b=0.82)
  }
}

///|
fn hero_title_font(metrics : Metrics) -> @text.FontSpec {
  @text.FontSpec::new(
    size=if metrics.compact { 42.0 } else { 52.0 },
    weight=850,
  )
}

///|
fn hero_statement_font(metrics : Metrics) -> @text.FontSpec {
  @text.FontSpec::new(
    size=if metrics.compact { 26.0 } else { 40.0 },
    weight=800,
  )
}

///|
fn website_blue(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.40, g=0.58, b=1.0)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.10, g=0.34, b=0.92)
  }
}

///|
fn website_green(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.24, g=0.78, b=0.58)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.05, g=0.52, b=0.34)
  }
}

///|
fn website_amber(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.98, g=0.69, b=0.25)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.78, g=0.39, b=0.05)
  }
}

///|
fn hero_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.08, g=0.09, b=0.10)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.98, g=0.99, b=0.98)
  }
}

///|
fn showcase_section_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.09, g=0.10, b=0.12)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.94, g=0.97, b=0.95)
  }
}

///|
fn soft_panel_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.11, g=0.13, b=0.15)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.99, g=1.0, b=0.99)
  }
}

///|
fn code_panel_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::black()
    @state.ColorScheme::Light => @graphics.Color::white()
  }
}

///|
fn website_border(theme : @moui.Theme) -> @graphics.BorderStyle {
  @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(theme.palette.outline.multiply_alpha(0.62)),
    width=1.0,
  )
}

///|
fn accent_border(
  theme : @moui.Theme,
  accent : @graphics.Color,
) -> @graphics.BorderStyle {
  ignore(theme)
  @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(accent.multiply_alpha(0.58)),
    width=1.0,
  )
}
