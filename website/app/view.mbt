///|
fn Model::top_bar(
  self : Model,
  theme : @core.Theme,
  metrics : Metrics,
) -> @core.View[Msg] {
  let action_label = if self.dark { "☀" } else { "☾" }
  let action_accessibility_label = if self.dark {
    "Switch to light theme"
  } else {
    "Switch to dark theme"
  }
  let items : Array[@core.View[Msg]] = [brand_mark(theme)]
  if !metrics.compact {
    items.push(
      nav_button(theme, "Home", self.page is WebsiteHome, OpenHomeAt(0.0)),
    )
    items.push(nav_button(theme, "Tour", false, OpenHomeAt(700.0)))
    items.push(nav_button(theme, "Examples", false, OpenHomeAt(1840.0)))
    items.push(nav_button(theme, "Docs", self.page is WebsiteDocs, OpenDocs))
    items.push(nav_button(theme, "GitHub", false, OpenRepository))
  } else {
    items.push(
      nav_button(
        theme,
        if self.page is WebsiteDocs {
          "Home"
        } else {
          "Docs"
        },
        false,
        if self.page is WebsiteDocs {
          OpenHome
        } else {
          OpenDocs
        },
      ),
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
    .font(@core.FontSpec::new(size=18.0, weight=760))
    .accessibility_label(action_accessibility_label),
  )
  let top_bar_content = row(
    [
      spacer(min_length=0.0, weight=1.0),
      frame(
        row(
          items,
          spacing=if metrics.compact { 8.0 } else { 18.0 },
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
  surface(
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
  ).border(website_border(theme))
}

///|
fn brand_mark(theme : @core.Theme) -> @core.View[Msg] {
  row(
    [
      text("MoUI", width=72.0, height=26.0)
      .font(@core.FontSpec::new(size=19.0, weight=820))
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
fn nav_button(
  theme : @core.Theme,
  label : String,
  active : Bool,
  message : Msg,
) -> @core.View[Msg] {
  button(
    label,
    on_click=message,
    variant=if active {
      @views.ButtonVariant::Ghost
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    width=if label == "Examples" { 92.0 } else { 76.0 },
    height=34.0,
  ).foreground(if active { theme.palette.primary } else { theme.palette.muted })
}

///|
fn Model::hero(
  self : Model,
  theme : @core.Theme,
  metrics : Metrics,
) -> @core.View[Msg] {
  let ctas = row(
    [
      button(
        "Get Started",
        on_click=OpenRepository,
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
  let visual = hero_demo_panel(
    theme,
    metrics.hero_scene_width,
    metrics.hero_scene_height,
    metrics.compact,
    self.hero_count,
  )
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
  theme : @core.Theme,
  metrics : Metrics,
) -> @core.View[Msg] {
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
  theme : @core.Theme,
  metrics : Metrics,
) -> @core.View[Msg] {
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
  theme : @core.Theme,
  metrics : Metrics,
) -> @core.View[Msg] {
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
  theme : @core.Theme,
  metrics : Metrics,
) -> @core.View[Msg] {
  ignore(self)
  let copy_width = if metrics.compact { metrics.content_width } else { 520.0 }
  section_shell(
    theme,
    metrics,
    column(
      [
        quick_start_copy(theme, copy_width),
        quick_start_placeholder(theme, copy_width),
      ],
      spacing=22.0,
      align=@views.CrossAlign::Center,
    ),
    top=metrics.section_top,
    bottom=metrics.section_bottom,
    background=Some(theme.palette.surface_variant.multiply_alpha(0.36)),
  )
}

///|
fn section_shell(
  theme : @core.Theme,
  metrics : Metrics,
  child : @core.View[Msg],
  top~ : Double,
  bottom~ : Double,
  background~ : @core.Color?,
) -> @core.View[Msg] {
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
      surface(
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
  theme : @core.Theme,
  metrics : Metrics,
  child : @core.View[Msg],
  top~ : Double,
  bottom~ : Double,
  background~ : @core.Color?,
  dotted~ : Bool,
  wash~ : Bool,
) -> @core.View[Msg] {
  ignore(dotted)
  ignore(wash)
  section_shell(theme, metrics, child, top~, bottom~, background~)
}

///|
fn section_header(
  theme : @core.Theme,
  title : String,
  summary_zh : String,
  summary : String,
  width : Double,
) -> @core.View[Msg] {
  column(
    [
      text(title, width~, height=46.0)
      .font(@core.FontSpec::new(size=32.0, weight=820))
      .foreground(theme.palette.foreground),
      text(summary_zh, width~, height=30.0)
      .font(@core.FontSpec::new(size=15.0, weight=520))
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
fn website_scrollbar(
  theme : @core.Theme,
  viewport_height~ : Double,
  content_height~ : Double,
  offset_y~ : Double,
) -> @core.View[Msg] {
  let width = 14.0
  custom_layout(
    measure=_constraints => @core.Size::new(width~, height=viewport_height),
    paint=frame => {
      let max_scroll = max_website_double(0.0, content_height - viewport_height)
      if max_scroll <= 0.0 {
        return []
      }
      let track_width = 5.0
      let track = @core.Rect::new(
        x=frame.origin.x + (frame.size.width - track_width) / 2.0,
        y=frame.origin.y + 8.0,
        width=track_width,
        height=max_website_double(0.0, frame.size.height - 16.0),
      )
      let thumb_height = clamp_website_double(
        track.size.height * viewport_height / content_height,
        38.0,
        track.size.height,
      )
      let thumb_y = track.origin.y +
        (track.size.height - thumb_height) *
        clamp_website_double(offset_y, 0.0, max_scroll) /
        max_scroll
      let thumb = @core.Rect::new(
        x=track.origin.x,
        y=thumb_y,
        width=track_width,
        height=thumb_height,
      )
      [
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=track, radius=2.5),
          @core.Brush::solid(theme.palette.outline.multiply_alpha(0.26)),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=thumb, radius=2.5),
          @core.Brush::solid(theme.palette.primary.multiply_alpha(0.72)),
        ),
      ]
    },
    semantics_label="Website main scrollbar",
  )
}

///|
fn metric_card(
  theme : @core.Theme,
  label : String,
  value : String,
  caption~ : String,
  width~ : Double,
  accent~ : @core.Color,
) -> @core.View[Msg] {
  surface(
    column(
      [
        text(label, width=width - 28.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(value, width=width - 28.0, height=42.0)
        .font(@core.FontSpec::new(size=26.0, weight=820))
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
  theme : @core.Theme,
  index : String,
  title : String,
  zh_summary : String,
  summary : String,
  width : Double,
  accent : @core.Color,
) -> @core.View[Msg] {
  let content_width = width - 40.0
  surface(
    column(
      [
        row(
          [
            surface(
              text(index, width=28.0, height=28.0)
              .font(@core.FontSpec::new(size=16.0, weight=820))
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
  theme : @core.Theme,
  title : String,
  subtitle : String,
  summary_lines : Array[String],
  status : String,
  value : Double,
  width : Double,
  accent : @core.Color,
) -> @core.View[Msg] {
  ignore(value)
  surface(
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
  theme : @core.Theme,
  lines : Array[String],
  width : Double,
) -> @core.View[Msg] {
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
  theme : @core.Theme,
  label : String,
  width : Double,
  accent : @core.Color,
) -> @core.View[Msg] {
  ignore(theme)
  let foreground = accent
  let font = @core.FontSpec::new(size=24.0, weight=820)
  custom_layout(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width~, height=118.0))
    },
    paint=frame => {
      let commands : Array[@core.DrawCommand] = [
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=frame, radius=12.0),
          @core.Brush::solid(accent.multiply_alpha(0.08)),
        ),
      ]
      let stripe = 12.0
      let count = ((frame.size.width + frame.size.height) / stripe)
        .ceil()
        .to_int()
      for index in 0..<count {
        let start_x = frame.origin.x + index.to_double() * stripe
        commands.push(
          @core.DrawCommand::DrawPath(
            @core.PathSpec::new(
              verbs=[
                @core.PathVerb::MoveTo(
                  @core.Point::new(
                    x=start_x,
                    y=frame.origin.y + frame.size.height,
                  ),
                ),
                @core.PathVerb::LineTo(
                  @core.Point::new(
                    x=start_x - frame.size.height,
                    y=frame.origin.y,
                  ),
                ),
              ],
              stroke=Some(@core.Brush::solid(accent.multiply_alpha(0.18))),
              stroke_width=1.0,
            ),
          ),
        )
      }
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=label,
            frame=@core.Rect::new(
              x=frame.origin.x,
              y=frame.origin.y + 41.0,
              width=frame.size.width,
              height=36.0,
            ),
            font~,
            color=foreground,
          ),
        ),
      )
      commands
    },
    semantics_label="Showcase thumbnail",
  )
}

///|
fn quick_start_copy(theme : @core.Theme, width : Double) -> @core.View[Msg] {
  column(
    [
      badge("Build it", tone=@views.BadgeTone::Success, theme~, width=78.0),
      text("Quick Start / 快速开始", width~, height=36.0)
      .font(@core.FontSpec::new(size=26.0, weight=780))
      .foreground(theme.palette.foreground),
      text(
        "先修复本地依赖，再构建这个由 MoUI 自己渲染的官网首页。",
        width~,
        height=52.0,
      )
      .font(theme.typography.body)
      .foreground(theme.palette.foreground),
      text(
        "The Web entrypoint stays thin: shared homepage logic lives in website/app, and wasm-gc hosts the canvas.",
        width~,
        height=58.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      flow(
        [
          tag("website/app", theme~, width=112.0),
          tag("web_wasm", theme~, width=96.0),
          tag("wasm-gc", theme~, width=86.0),
        ],
        width~,
        spacing=8.0,
        row_spacing=8.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn quick_start_placeholder(
  theme : @core.Theme,
  width : Double,
) -> @core.View[Msg] {
  surface(
    column(
      [
        badge(
          "快速开始方式",
          tone=@views.BadgeTone::Neutral,
          theme~,
          width=118.0,
        ),
        text("正在开发中", width=width - 36.0, height=38.0)
        .font(@core.FontSpec::new(size=22.0, weight=780))
        .foreground(theme.palette.foreground),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=118.0,
    background=soft_panel_background(theme),
    corner_radius=theme.radius_scale.lg,
    theme~,
    padding=18.0,
  ).border(website_border(theme))
}

///|
fn hero_title_font(metrics : Metrics) -> @core.FontSpec {
  @core.FontSpec::new(
    size=if metrics.compact { 42.0 } else { 52.0 },
    weight=850,
  )
}

///|
fn hero_statement_font(metrics : Metrics) -> @core.FontSpec {
  @core.FontSpec::new(
    size=if metrics.compact { 26.0 } else { 40.0 },
    weight=800,
  )
}

///|
fn website_blue(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Dark => @core.Color::rgba(r=0.40, g=0.58, b=1.0)
    @core.ColorScheme::Light => @core.Color::rgba(r=0.10, g=0.34, b=0.92)
  }
}

///|
fn website_green(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Dark => @core.Color::rgba(r=0.24, g=0.78, b=0.58)
    @core.ColorScheme::Light => @core.Color::rgba(r=0.05, g=0.52, b=0.34)
  }
}

///|
fn website_amber(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Dark => @core.Color::rgba(r=0.98, g=0.69, b=0.25)
    @core.ColorScheme::Light => @core.Color::rgba(r=0.78, g=0.39, b=0.05)
  }
}

///|
fn hero_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Dark => @core.Color::rgba(r=0.08, g=0.09, b=0.10)
    @core.ColorScheme::Light => @core.Color::rgba(r=0.98, g=0.99, b=0.98)
  }
}

///|
fn showcase_section_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Dark => @core.Color::rgba(r=0.09, g=0.10, b=0.12)
    @core.ColorScheme::Light => @core.Color::rgba(r=0.94, g=0.97, b=0.95)
  }
}

///|
fn soft_panel_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Dark => @core.Color::rgba(r=0.11, g=0.13, b=0.15)
    @core.ColorScheme::Light => @core.Color::rgba(r=0.99, g=1.0, b=0.99)
  }
}

///|
fn code_panel_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Dark => @core.Color::black()
    @core.ColorScheme::Light => @core.Color::white()
  }
}

///|
fn website_border(theme : @core.Theme) -> @core.BorderStyle {
  @core.BorderStyle::new(
    brush=@core.Brush::solid(theme.palette.outline.multiply_alpha(0.62)),
    width=1.0,
  )
}

///|
fn accent_border(
  theme : @core.Theme,
  accent : @core.Color,
) -> @core.BorderStyle {
  ignore(theme)
  @core.BorderStyle::new(
    brush=@core.Brush::solid(accent.multiply_alpha(0.58)),
    width=1.0,
  )
}
