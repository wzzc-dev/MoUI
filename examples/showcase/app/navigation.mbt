///|
fn ShowcaseApp::catalog_shell(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  selected : String,
  filter : @core.Binding[String],
  draft : @core.Binding[String],
  tab : @core.Binding[String],
  slider : @core.Binding[Double],
  enabled : @core.Binding[Bool],
  secondary : @core.Binding[Bool],
  picker : @core.Binding[String],
  date : @core.Binding[@core.DateValue],
  active : Bool,
  offset : Double,
  opacity : Double,
) -> @core.ViewSpec {
  @views.row(
    [
      self.sidebar(theme, metrics, selected, filter),
      @views.navigation_stack(
        self.navigation,
        self.destinations(
          ctx, theme, metrics, draft, tab, slider, enabled, secondary, picker, date,
          active, offset, opacity,
        ),
        fallback=section_panel(
          theme,
          "Missing section",
          "The selected route is not in the Showcase catalog.",
          @views.text("Route: " + selected, width=280.0, height=28.0),
          metrics~,
        ),
      ).frame(width=metrics.detail_width, height=metrics.panel_height),
    ],
    spacing=theme.spacing_scale.lg,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
}

///|
fn ShowcaseApp::destinations(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  draft : @core.Binding[String],
  tab : @core.Binding[String],
  slider : @core.Binding[Double],
  enabled : @core.Binding[Bool],
  secondary : @core.Binding[Bool],
  picker : @core.Binding[String],
  date : @core.Binding[@core.DateValue],
  active : Bool,
  offset : Double,
  opacity : Double,
) -> Array[@views.NavigationDestination] {
  [
    @views.navigation_destination(
      route="overview",
      view=self.overview_section(
        theme, metrics, active, offset, opacity, slider,
      ),
    ),
    @views.navigation_destination(
      route="text-media",
      view=self.text_media_section(theme, metrics, draft, opacity),
    ),
    @views.navigation_destination(
      route="controls",
      view=self.controls_section(
        theme, metrics, draft, tab, slider, enabled, secondary, picker, date,
      ),
    ),
    @views.navigation_destination(
      route="layout",
      view=self.layout_section(theme, metrics, slider),
    ),
    @views.navigation_destination(
      route="navigation",
      view=self.navigation_section(theme, metrics, tab),
    ),
    @views.navigation_destination(
      route="examples",
      view=self.examples_section(ctx, theme, metrics),
    ),
    @views.navigation_destination(
      route="theme-renderer",
      view=self.theme_renderer_section(theme, metrics, enabled, active, opacity),
    ),
  ]
}

///|
fn showcase_sections() -> Array[ShowcaseSection] {
  [
    {
      route: "overview",
      title: "Overview",
      summary: "Visual polish and capability status",
      group: "Start",
    },
    {
      route: "text-media",
      title: "Text & Media",
      summary: "Text, images, rich text, Markdown",
      group: "Views",
    },
    {
      route: "controls",
      title: "Controls",
      summary: "Buttons, input, picker, datepicker",
      group: "Views",
    },
    {
      route: "layout",
      title: "Layout",
      summary: "Grid, lazy views, intrinsic sizing",
      group: "Views",
    },
    {
      route: "navigation",
      title: "Navigation",
      summary: "Stack, tabs, dialog, sheet",
      group: "Patterns",
    },
    {
      route: "examples",
      title: "Examples",
      summary: "Counter, Todo, Markdown reuse",
      group: "Reuse",
    },
    {
      route: "theme-renderer",
      title: "Theme & Renderer",
      summary: "Theme helpers and renderer report",
      group: "Runtime",
    },
  ]
}

///|
fn ShowcaseApp::sidebar(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  selected : String,
  filter : @core.Binding[String],
) -> @core.ViewSpec {
  let inner_width = metrics.sidebar_width - theme.spacing_scale.lg * 2.0
  let sidebar_body_height = max_showcase_double(
    64.0,
    metrics.panel_height - theme.spacing_scale.lg * 2.0,
  )
  let rows : Array[@core.ViewSpec] = [
    @views.text("View Catalog", width=inner_width, height=30.0)
    .font(theme.typography.control)
    .foreground(theme.palette.foreground),
    @views.searchbar(
      query=filter,
      placeholder="Filter sections",
      foreground=theme.palette.foreground,
      background=@core.Brush::solid(theme.palette.surface_variant),
      corner_radius=theme.radius_scale.md,
      on_clear=Some(() => filter.set("")),
    ).frame(width=inner_width, height=38.0),
  ]
  let query = filter.get()
  for section in showcase_sections() {
    if string_contains(section.title, query) ||
      string_contains(section.summary, query) ||
      string_contains(section.group, query) {
      rows.push(
        self.sidebar_item(
          theme,
          section,
          selected == section.route,
          inner_width,
        ),
      )
    }
  }
  @views.surface(
    @views.scroll_view(
      @views.column(
        rows,
        spacing=theme.spacing_scale.sm,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
      ),
      width=inner_width,
      height=sidebar_body_height,
    ),
    width=metrics.sidebar_width,
    height=metrics.panel_height,
    style=showcase_panel_style(theme),
  )
}

///|
fn ShowcaseApp::sidebar_item(
  self : ShowcaseApp,
  theme : @core.Theme,
  section : ShowcaseSection,
  selected : Bool,
  width : Double,
) -> @core.ViewSpec {
  let style = if selected {
    @core.ButtonStyle::filled(theme~)
  } else {
    @core.ButtonStyle::ghost(theme~)
  }
  @views.button(
    section.title,
    on_click=() => self.select_section(section.route),
    style~,
    width~,
    height=34.0,
  ).key("showcase-section-" + section.route)
}

///|
fn ShowcaseApp::header(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  dark : Bool,
  active : Bool,
) -> @core.ViewSpec {
  let overview_width = if metrics.compact { 86.0 } else { 100.0 }
  let examples_width = if metrics.compact { 88.0 } else { 100.0 }
  let scheme_width = if metrics.compact { 72.0 } else { 86.0 }
  let dialog_width = if metrics.compact { 82.0 } else { 96.0 }
  let title_width = if metrics.compact { 260.0 } else { 330.0 }
  let subtitle_width = if metrics.compact {
    280.0
  } else {
    min_showcase_double(metrics.shell_width, 520.0)
  }
  let title = @views.column(
    [
      @views.text("MoUI View Showcase", width=title_width, height=34.0)
      .font(theme.typography.title)
      .foreground(theme.palette.foreground),
      @views.text(
        if active {
          "State-driven visuals are active"
        } else {
          "A complete catalog built from reusable example code"
        },
        width=subtitle_width,
        height=28.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=theme.spacing_scale.xs,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
  let actions = @views.scroll_view(
    @views.row(
      [
        @views.button(
          "Overview",
          on_click=() => self.select_section("overview"),
          style=@core.ButtonStyle::tonal(theme~),
          width=overview_width,
        ),
        @views.button(
          "Examples",
          on_click=() => self.select_section("examples"),
          style=@core.ButtonStyle::tonal(theme~),
          width=examples_width,
        ),
        @views.button(
          if dark {
            "Light"
          } else {
            "Dark"
          },
          on_click=() => self.toggle_scheme(),
          style=@core.ButtonStyle::tonal(theme~),
          width=scheme_width,
        ),
        @views.menu_button(
          "Dialog",
          on_click=() => self.show_dialog(),
          style=@core.ButtonStyle::outline(theme~),
          width=dialog_width,
        ).keyboard_shortcut(
          @core.KeyboardShortcut::new(
            key="k",
            modifiers=@core.KeyModifiers::new(meta=true),
          ),
        ),
      ],
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
    width=metrics.action_width,
    height=46.0,
  )
  if metrics.shell_width < 560.0 {
    @views.column(
      [title, actions],
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    )
  } else {
    @views.row(
      [title, @views.spacer(min_length=12.0, weight=1.0), actions],
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    )
  }
}
