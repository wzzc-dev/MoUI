///|
fn Model::top_bar(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let message = key => website_message(self.locale, key)
  let action_label = if self.dark { "☀" } else { "☾" }
  let action_accessibility_label = if self.dark {
    message("theme.switch_light")
  } else {
    message("theme.switch_dark")
  }
  let items : Array[@moui.View[Msg]] = [brand_mark(theme, self.locale)]
  if !metrics.nav_compact {
    items.push(
      nav_button(
        theme,
        message("nav.home"),
        self.page is WebsiteHome,
        OpenHomeAt(0.0),
      ),
    )
    items.push(
      nav_button(
        theme,
        message("nav.tutorial"),
        self.page is WebsiteTutorial,
        OpenTutorial,
      ),
    )
    items.push(
      nav_button(
        theme,
        message("nav.quick_start"),
        false,
        OpenHomeAnchor("quick-start"),
        width=102.0,
      ),
    )
    items.push(
      nav_button(
        theme,
        message("nav.showcases"),
        self.page is WebsiteShowcases,
        OpenShowcases,
        width=92.0,
      ),
    )
    items.push(
      nav_button(theme, message("nav.docs"), self.page is WebsiteDocs, OpenDocs),
    )
    items.push(nav_button(theme, message("nav.github"), false, OpenRepository))
    items.push(
      button(
        "EN",
        on_click=SelectLocale("en-US"),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=40.0,
        height=34.0,
      ).accessibility_label(message("site.english")),
    )
    items.push(
      button(
        "中",
        on_click=SelectLocale("zh-Hans"),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=40.0,
        height=34.0,
      ).accessibility_label(message("site.chinese")),
    )
  } else {
    items.push(
      button(
        website_message(self.locale, "nav.menu"),
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
  .accessibility_label(message("site.navigation"))
}

///|
fn brand_mark(theme : @moui.Theme, locale : String) -> @moui.View[Msg] {
  row(
    [
      text("MoUI", width=72.0, height=26.0)
      .font(@text.FontSpec::new(size=19.0, weight=820))
      .foreground(theme.palette.foreground),
      text(website_message(locale, "brand.subtitle"), width=88.0, height=20.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  ).frame(width=164.0, height=44.0)
}

///|
fn nav_button(
  theme : @moui.Theme,
  label : String,
  active : Bool,
  message : Msg,
  width? : Double = 76.0,
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
    width~,
    height=34.0,
  ).foreground(if active { theme.palette.primary } else { theme.palette.muted })
}

///|
fn Model::hero(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let message = key => website_message(self.locale, key)
  let ctas = row(
    [
      button(
        message("action.get_started"),
        on_click=OpenHomeAnchor("quick-start"),
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=134.0,
        height=if metrics.compact { 40.0 } else { 46.0 },
      ).foreground(theme.palette.foreground),
      button(
        message("nav.github"),
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
          message("hero.framework"),
          width=metrics.hero_copy_width,
          height=42.0,
        )
        .font(hero_statement_font(metrics))
        .foreground(theme.palette.foreground),
        text(
          message("hero.typed_compact"),
          width=metrics.hero_copy_width,
          height=24.0,
        )
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        text(
          message("hero.model_compact"),
          width=metrics.hero_copy_width,
          height=24.0,
        )
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        text(
          message("hero.shared_compact"),
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
          message("hero.framework"),
          width=metrics.hero_copy_width,
          height=54.0,
        )
        .font(hero_statement_font(metrics))
        .foreground(theme.palette.foreground),
        text(message("hero.typed"), width=metrics.hero_copy_width, height=26.0)
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        text(message("hero.model"), width=metrics.hero_copy_width, height=26.0)
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        text(message("hero.shared"), width=metrics.hero_copy_width, height=34.0)
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
        @views.choice_item("source", message("hero.source")),
        @views.choice_item("counter", message("hero.counter")),
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
        self.locale,
      )
    } else {
      hero_source_panel(
        theme,
        metrics.hero_scene_width,
        metrics.hero_scene_height - 48.0,
        true,
        self.locale,
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
      self.locale,
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
    // The hero title now sizes to its measured 52px/850 line box (65, up
    // from the cached 62); reclaim 3px of bottom padding so the capability
    // strip's first metric stays above the 760 fold on desktop.
    bottom=if metrics.compact { 24.0 } else { 7.0 },
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
  let message = key => website_message(self.locale, key)
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
          message("metric.app_surface"),
          "View[Msg]",
          caption=message("metric.app_surface.caption"),
          width=stat_width,
          accent=website_blue(theme),
        ),
        metric_card(
          theme,
          message("metric.runtime_model"),
          "TEA",
          caption=message("metric.runtime_model.caption"),
          width=stat_width,
          accent=website_green(theme),
        ),
        metric_card(
          theme,
          message("metric.render_routes"),
          "3",
          caption=message("metric.render_routes.caption"),
          width=stat_width,
          accent=website_amber(theme),
        ),
        metric_card(
          theme,
          message("metric.targets"),
          "4",
          caption=message("metric.targets.caption"),
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
  let message = key => website_message(self.locale, key)
  section_shell(
    theme,
    metrics,
    column(
      [
        section_header(
          theme,
          message("foundation.title"),
          message("foundation.summary"),
          message("foundation.description"),
          metrics.content_width,
        ),
        responsive_grid(
          [
            feature_card(
              theme,
              "1",
              message("feature.predictable.title"),
              message("feature.predictable.summary"),
              message("feature.predictable.detail"),
              metrics.feature_card_width,
              theme.palette.primary,
            ),
            feature_card(
              theme,
              "T",
              message("feature.strict_types.title"),
              message("feature.strict_types.summary"),
              message("feature.strict_types.detail"),
              metrics.feature_card_width,
              theme.palette.primary,
            ),
            feature_card(
              theme,
              "[]",
              message("feature.modular_hosts.title"),
              message("feature.modular_hosts.summary"),
              message("feature.modular_hosts.detail"),
              metrics.feature_card_width,
              theme.palette.primary,
            ),
            feature_card(
              theme,
              "{}",
              message("feature.renderer_neutral.title"),
              message("feature.renderer_neutral.summary"),
              message("feature.renderer_neutral.detail"),
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
  let message = key => website_message(self.locale, key)
  section_shell(
    theme,
    metrics,
    column(
      [
        section_header(
          theme,
          message("platform.title"),
          message("platform.summary"),
          message("platform.description"),
          metrics.content_width,
        ),
        responsive_grid(
          [
            platform_card(
              theme,
              message("platform.website.title"),
              message("platform.website.subtitle"),
              [
                message("platform.website.line1"),
                message("platform.website.line2"),
                message("platform.website.line3"),
              ],
              "MoUI",
              1.0,
              metrics.platform_card_width,
              theme.palette.primary,
              self.locale,
            ),
            platform_card(
              theme,
              message("platform.showcase.title"),
              message("platform.showcase.subtitle"),
              [
                message("platform.showcase.line1"),
                message("platform.showcase.line2"),
                message("platform.showcase.line3"),
              ],
              "01",
              0.76,
              metrics.platform_card_width,
              website_amber(theme),
              self.locale,
            ),
            platform_card(
              theme,
              message("platform.markdown.title"),
              message("platform.markdown.subtitle"),
              [
                message("platform.markdown.line1"),
                message("platform.markdown.line2"),
                message("platform.markdown.line3"),
              ],
              "02",
              0.70,
              metrics.platform_card_width,
              website_blue(theme),
              self.locale,
            ),
            platform_card(
              theme,
              message("platform.workbench.title"),
              message("platform.workbench.subtitle"),
              [
                message("platform.workbench.line1"),
                message("platform.workbench.line2"),
                message("platform.workbench.line3"),
              ],
              "03",
              0.64,
              metrics.platform_card_width,
              website_green(theme),
              self.locale,
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
        quick_start_header(theme, panel_width, self.locale),
        self.quick_start_steps(theme, panel_width),
        quick_start_actions(theme, self.locale),
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
  locale : String,
) -> @moui.View[Msg] {
  ignore(value)
  container(
    column(
      [
        showcase_thumb(theme, status, width - 2.0, accent, locale),
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
  locale : String,
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
    semantics_label=website_message(locale, "showcase.thumbnail"),
  )
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
