///|
fn ShowcaseModel::catalog_shell(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
  offset : Double,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  split_view(
    primary=self.sidebar(theme, metrics),
    detail=self.current_destination(theme, metrics, offset, opacity),
    primary_width=metrics.sidebar_width,
    detail_width=metrics.detail_width,
    height=metrics.panel_height,
    spacing=theme.spacing_scale.lg,
  )
}

///|
fn ShowcaseModel::current_destination(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
  offset : Double,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  let route = self.route_history.current().path
  if route == "overview" {
    self.overview_section(theme, metrics, offset, opacity)
  } else if route == "text-media" {
    self.text_media_section(theme, metrics, opacity)
  } else if route == "controls" {
    self.controls_section(theme, metrics)
  } else if route == "forms" {
    self.forms_section(theme, metrics)
  } else if route == "data" {
    self.data_section(theme, metrics)
  } else if route == "layout" {
    self.layout_section(theme, metrics)
  } else if route == "navigation" {
    self.navigation_section(theme, metrics)
  } else if route == "feedback" {
    self.feedback_section(theme, metrics)
  } else if route == "theme-renderer" || route == "runtime-renderer" {
    self.theme_renderer_section(theme, metrics, opacity)
  } else if route == "diagnostics" {
    self.diagnostics_section(theme, metrics)
  } else if route == "examples" {
    self.examples_section(theme, metrics)
  } else if route == "advanced-rendering" {
    self.advanced_rendering_section(theme, metrics)
  } else if route == "text-diagnostics" {
    self.text_diagnostics_section(theme, metrics)
  } else if route == "interaction-lab" {
    self.interaction_lab_section(theme, metrics)
  } else {
    self.section_panel(
      theme,
      "Missing section",
      "The selected route is not in the Showcase catalog.",
      text("Route: " + self.selected_section, width=280.0, height=28.0),
      metrics~,
    )
  }
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
      route: "forms",
      title: "Forms",
      summary: "Labels, helper text, validation",
      group: "Views",
    },
    {
      route: "data",
      title: "Data",
      summary: "Tables, trees, avatars, metadata",
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
      title: "Navigation Shell",
      summary: "Sidebar, split view, wizard, presentation",
      group: "Patterns",
    },
    {
      route: "feedback",
      title: "Feedback",
      summary: "Status, banners, empty states",
      group: "Patterns",
    },
    {
      route: "runtime-renderer",
      title: "Runtime/Renderer",
      summary: "Host and renderer capability reports",
      group: "Runtime",
    },
    {
      route: "diagnostics",
      title: "Diagnostics",
      summary: "Input, text, rendering diagnostics",
      group: "Runtime",
    },
  ]
}

///|
fn showcase_grouped_sections() -> Array[(String, Array[ShowcaseSection])] {
  let start : Array[ShowcaseSection] = []
  let views : Array[ShowcaseSection] = []
  let patterns : Array[ShowcaseSection] = []
  let runtime : Array[ShowcaseSection] = []
  for section in showcase_sections() {
    match section.group {
      "Start" => start.push(section)
      "Views" => views.push(section)
      "Patterns" => patterns.push(section)
      "Runtime" => runtime.push(section)
      _ => ()
    }
  }
  let result : Array[(String, Array[ShowcaseSection])] = []
  if start.length() > 0 {
    result.push(("Start", start))
  }
  if views.length() > 0 {
    result.push(("Views", views))
  }
  if patterns.length() > 0 {
    result.push(("Patterns", patterns))
  }
  if runtime.length() > 0 {
    result.push(("Runtime", runtime))
  }
  result
}

///|
fn ShowcaseModel::sidebar(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let inner_width = metrics.sidebar_width - theme.spacing_scale.lg * 2.0
  let sidebar_body_height = max_showcase_double(
    64.0,
    metrics.panel_height - theme.spacing_scale.md * 2.0,
  )
  let title = text("View Catalog", width=inner_width, height=30.0)
    .font(theme.typography.control)
    .foreground(theme.palette.foreground)
  let search = searchbar(
    query=self.filter,
    on_input=value => FilterChanged(value),
    placeholder="Filter sections",
    theme~,
    on_clear=Some(ClearFilter),
  ).frame(width=inner_width, height=38.0)
  let scrollbar_gutter = 24.0
  let list_width = max_showcase_double(120.0, inner_width - scrollbar_gutter)
  let list_rows : Array[@moui.View[ShowcaseMsg]] = []
  let mut content_height = 0.0
  let mut header_count = 0
  let mut button_count = 0
  let mut spacer_count = 0
  let query = self.filter
  let grouped = showcase_grouped_sections()
  let mut rendered_groups = 0
  for pair in grouped {
    let group_name = pair.0
    let sections = pair.1
    let matching_sections = sections.filter(section => {
      string_contains(section.title, query) ||
      string_contains(section.summary, query) ||
      string_contains(section.group, query)
    })
    if matching_sections.length() == 0 {
      continue
    }
    if rendered_groups > 0 {
      list_rows.push(
        spacer(weight=0.0).frame(
          width=inner_width,
          height=theme.spacing_scale.md,
        ),
      )
      spacer_count = spacer_count + 1
    }
    list_rows.push(
      text(group_name, width=inner_width, height=22.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    )
    header_count = header_count + 1
    for section in matching_sections {
      list_rows.push(
        self.sidebar_item(
          theme,
          section,
          self.selected_section == section.route,
          list_width,
        ),
      )
      button_count = button_count + 1
    }
    rendered_groups = rendered_groups + 1
  }
  content_height = header_count.to_double() * 22.0 +
    button_count.to_double() * 34.0 +
    spacer_count.to_double() * theme.spacing_scale.md +
    theme.spacing_scale.md +
    8.0
  if list_rows.length() > 0 {
    content_height = content_height +
      (list_rows.length() - 1).to_double() * theme.spacing_scale.sm
  }
  let list_viewport_height = max_showcase_double(
    64.0,
    sidebar_body_height - 30.0 - 38.0 - theme.spacing_scale.sm * 2.0,
  )
  let max_scroll = max_showcase_double(
    0.0,
    content_height - list_viewport_height,
  )
  let normalized_offset = @geometry.Point::new(
    x=0.0,
    y=clamp_double(self.sidebar_scroll_offset.y, 0.0, max_scroll),
  )
  container(
    column(
      [
        title,
        search,
        row(
          [
            scroll_view(
              column(
                [
                  column(
                    list_rows,
                    spacing=theme.spacing_scale.sm,
                    align=@views.CrossAlign::Start,
                  ),
                  spacer(weight=0.0).frame(
                    width=inner_width,
                    height=theme.spacing_scale.md,
                  ),
                  spacer(weight=0.0).frame(width=inner_width, height=8.0),
                ],
                align=@views.CrossAlign::Start,
              ).repaint_boundary(),
              offset=normalized_offset,
              width=list_width,
              height=list_viewport_height,
              on_scroll=Some(delta => {
                SidebarScrollTo(
                  clamp_double(normalized_offset.y - delta.y, 0.0, max_scroll),
                )
              }),
            ),
            spacer(min_length=scrollbar_gutter - 8.0, weight=0.0),
            sidebar_scrollbar(
              theme,
              viewport_height=list_viewport_height,
              content_height~,
              offset_y=normalized_offset.y,
            ).frame(width=8.0, height=list_viewport_height),
          ],
          spacing=0.0,
          align=@views.CrossAlign::Start,
        ).frame(width=inner_width, height=list_viewport_height),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width=metrics.sidebar_width,
    height=metrics.panel_height,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .border(showcase_panel_border(theme))
  .repaint_boundary()
}

///|
fn sidebar_scrollbar(
  theme : @moui.Theme,
  viewport_height~ : Double,
  content_height~ : Double,
  offset_y~ : Double,
) -> @moui.View[ShowcaseMsg] {
  let width = 8.0
  @views.custom_layout(
    measure=_constraints => @geometry.Size::new(width~, height=viewport_height),
    paint=(ctx, frame) => {
      let max_scroll = max_showcase_double(
        0.0,
        content_height - viewport_height,
      )
      if max_scroll <= 0.0 {
        return
      }
      let track_width = 4.0
      let track = @geometry.Rect::new(
        x=frame.origin.x + (frame.size.width - track_width) / 2.0,
        y=frame.origin.y,
        width=track_width,
        height=frame.size.height,
      )
      let thumb_height = clamp_double(
        frame.size.height * frame.size.height / content_height,
        32.0,
        frame.size.height,
      )
      let thumb_y = frame.origin.y +
        (frame.size.height - thumb_height) *
        clamp_double(offset_y, 0.0, max_scroll) /
        max_scroll
      let thumb = @geometry.Rect::new(
        x=track.origin.x,
        y=thumb_y,
        width=track_width,
        height=thumb_height,
      )
      fill_rounded_rect(
        ctx,
        @views.RoundedRect::new(rect=track, radius=2.0),
        @graphics.Brush::solid(theme.palette.outline.multiply_alpha(0.22)),
      )
      fill_rounded_rect(
        ctx,
        @views.RoundedRect::new(rect=thumb, radius=2.0),
        @graphics.Brush::solid(theme.palette.primary.multiply_alpha(0.72)),
      )
    },
    semantics_label="Catalog scrollbar",
  )
}

///|
fn ShowcaseModel::sidebar_item(
  self : ShowcaseModel,
  theme : @moui.Theme,
  section : ShowcaseSection,
  selected : Bool,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let variant = if selected {
    @views.ButtonVariant::Primary
  } else {
    @views.ButtonVariant::Ghost
  }
  button(
    section.title,
    on_click=SelectSection(section.route),
    variant~,
    theme~,
    width~,
    height=34.0,
  ).key("showcase-section-" + section.route)
}

///|
fn ShowcaseModel::header(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let overview_width = if metrics.compact { 78.0 } else { 82.0 }
  let examples_width = if metrics.compact { 80.0 } else { 82.0 }
  let scheme_width = if metrics.compact { 64.0 } else { 70.0 }
  let dialog_width = if metrics.compact { 74.0 } else { 76.0 }
  let title_width = if metrics.compact { 260.0 } else { 330.0 }
  let subtitle_width = if metrics.compact {
    280.0
  } else {
    min_showcase_double(metrics.shell_width, 520.0)
  }
  let title = column(
    [
      text("MoUI View Showcase", width=title_width, height=34.0)
      .font(theme.typography.title)
      .foreground(theme.palette.foreground),
      text(
        if self.active {
          "State-driven visuals are active"
        } else {
          "Theme: " + showcase_scheme_label(self.scheme)
        },
        width=subtitle_width,
        height=28.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Start,
  )
  let actions = scroll_view(
    row(
      [
        button(
          "Overview",
          on_click=SelectSection("overview"),
          variant=if self.selected_section == "overview" {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=overview_width,
          height=38.0,
        ),
        button(
          "Examples",
          on_click=SelectSection("examples"),
          variant=if self.selected_section == "examples" {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=examples_width,
          height=38.0,
        ),
        button(
          if self.scheme == @state.ColorScheme::Dark {
            "Light"
          } else {
            "Dark"
          },
          on_click=ToggleScheme,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=scheme_width,
          height=38.0,
        ),
        menu_button(
          "Dialog",
          on_click=ShowDialog,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=dialog_width,
          height=38.0,
        ).keyboard_shortcut(
          @views.KeyboardShortcut::new(
            key="k",
            modifiers=@views.KeyModifiers::new(meta=true),
          ),
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
    width=metrics.action_width,
    height=46.0,
  )
  let header_content = if metrics.shell_width < 560.0 {
    column(
      [title, actions],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    )
  } else {
    row(
      [title, spacer(min_length=12.0, weight=1.0), actions],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    )
  }
  let header_bg = match theme.scheme {
    @state.ColorScheme::Light =>
      theme.palette.surface_variant.multiply_alpha(0.28)
    @state.ColorScheme::Dark => @graphics.Color::white().multiply_alpha(0.03)
  }
  container(
    header_content,
    width=metrics.shell_width,
    height=72.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
    background=header_bg,
  )
}

///|
fn showcase_scheme_label(scheme : @state.ColorScheme) -> String {
  match scheme {
    @state.ColorScheme::Light => "Light"
    @state.ColorScheme::Dark => "Dark"
  }
}
