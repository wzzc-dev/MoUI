///|
pub struct ShowcaseApp {
  dark : @core.State[Bool]
  active : @core.State[Bool]
  dialog_visible : @core.State[Bool]
  sheet_visible : @core.State[Bool]
  feature_enabled : @core.State[Bool]
  secondary_enabled : @core.State[Bool]
  draft : @core.State[String]
  tab : @core.State[String]
  selected_section : @core.State[String]
  filter : @core.State[String]
  slider_value : @core.State[Double]
  picker_value : @core.State[String]
  date_value : @core.State[@core.DateValue]
  navigation : @core.NavigationState
  list_scroll : @core.ScrollState
  grid_scroll : @core.ScrollState
  counter : @counter_app.CounterApp
  todo : @todo_app.TodoApp
  markdown : @markdown_app.MarkdownEditorApp
}

///|
priv struct ShowcaseSection {
  route : String
  title : String
  summary : String
  group : String
}

///|
priv struct ShowcaseMetrics {
  viewport : @core.Size
  shell_width : Double
  sidebar_width : Double
  detail_width : Double
  panel_width : Double
  panel_height : Double
  body_width : Double
  body_height : Double
  action_width : Double
  compact : Bool
}

///|
pub fn ShowcaseApp::new() -> ShowcaseApp {
  let todo = @todo_app.TodoApp::new()
  todo.add("Reuse Todo app logic")
  todo.add("Render inside Showcase")
  let markdown = @markdown_app.MarkdownEditorApp::new()
  markdown.set_document(
    "# Embedded Markdown\n\nShowcase reuses the editor parser.",
  )
  {
    dark: @core.State::new(false),
    active: @core.State::new(false),
    dialog_visible: @core.State::new(false),
    sheet_visible: @core.State::new(false),
    feature_enabled: @core.State::new(true),
    secondary_enabled: @core.State::new(false),
    draft: @core.State::new("Visual polish"),
    tab: @core.State::new("form"),
    selected_section: @core.State::new("overview"),
    filter: @core.State::new(""),
    slider_value: @core.State::new(0.64),
    picker_value: @core.State::new("native"),
    date_value: @core.State::new(
      @core.DateValue::new(year=2026, month=5, day=21),
    ),
    navigation: @core.NavigationState::new(initial="overview"),
    list_scroll: @core.ScrollState::new(),
    grid_scroll: @core.ScrollState::new(),
    counter: @counter_app.CounterApp::new(),
    todo,
    markdown,
  }
}

///|
pub fn ShowcaseApp::toggle_scheme(self : ShowcaseApp) -> Unit {
  self.dark.update(value => !value)
}

///|
pub fn ShowcaseApp::toggle_active(self : ShowcaseApp) -> Unit {
  self.active.update(value => !value)
}

///|
pub fn ShowcaseApp::show_dialog(self : ShowcaseApp) -> Unit {
  self.dialog_visible.set(true)
}

///|
pub fn ShowcaseApp::hide_dialog(self : ShowcaseApp) -> Unit {
  self.dialog_visible.set(false)
}

///|
pub fn ShowcaseApp::show_sheet(self : ShowcaseApp) -> Unit {
  self.sheet_visible.set(true)
}

///|
pub fn ShowcaseApp::hide_sheet(self : ShowcaseApp) -> Unit {
  self.sheet_visible.set(false)
}

///|
pub fn ShowcaseApp::select_section(self : ShowcaseApp, route : String) -> Unit {
  self.selected_section.set(route)
  self.navigation.replace(route)
}

///|
pub fn ShowcaseApp::root(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
) -> @core.ViewSpec {
  let dark = ctx.watch(self.dark)
  let active = ctx.watch(self.active)
  let dialog_visible = ctx.watch(self.dialog_visible)
  let sheet_visible = ctx.watch(self.sheet_visible)
  let selected_section = ctx.watch(self.selected_section)
  let filter = ctx.binding(self.filter)
  let draft = ctx.binding(self.draft)
  let tab = ctx.binding(self.tab)
  let slider = ctx.binding(self.slider_value)
  let enabled = ctx.binding(self.feature_enabled)
  let secondary = ctx.binding(self.secondary_enabled)
  let picker = ctx.binding(self.picker_value)
  let date = ctx.binding(self.date_value)
  ignore(ctx.watch_navigation(self.navigation))
  ignore(ctx.watch_scroll(self.list_scroll))
  ignore(ctx.watch_scroll(self.grid_scroll))
  let theme = if dark { @views.dark_theme() } else { @views.light_theme() }
  let metrics = showcase_metrics(ctx.viewport_size(), theme)
  let offset = if active { 18.0 } else { 0.0 }
  let opacity = if active { 1.0 } else { 0.68 }
  let shell = @views.surface(
    @views.column(
      [
        self.header(theme, metrics, dark, active),
        self.catalog_shell(
          ctx, theme, metrics, selected_section, filter, draft, tab, slider, enabled,
          secondary, picker, date, active, offset, opacity,
        ),
      ],
      spacing=theme.spacing_scale.lg,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStretch,
    ),
    width=metrics.viewport.width,
    height=metrics.viewport.height,
    style=@core.SurfaceStyle::default(theme~),
  )
  let sheeted = @views.sheet_host(
    child=shell,
    sheet=Some(self.sheet(theme)),
    presented=sheet_visible,
    presentation_mode=@core.SheetPresentationMode::BottomSheet,
    on_dismiss=Some(() => self.hide_sheet()),
  )
  @views.dialog_host(
    sheeted,
    dialog=Some(self.dialog(theme)),
    presented=dialog_visible,
  )
}

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

///|
fn ShowcaseApp::overview_section(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  active : Bool,
  offset : Double,
  opacity : Double,
  slider : @core.Binding[Double],
) -> @core.ViewSpec {
  section_panel(
    theme,
    "Overview",
    "Showcase is now a data-driven catalog of MoUI views.",
    if metrics.compact && metrics.body_width < 448.0 {
      @views.column(
        [
          self.visual_card(theme, metrics, active, offset, opacity),
          self.capability_card(theme, metrics.body_width, 166.0),
          self.shortcut_preview(theme),
          @views.progress(
            slider.get(),
            width=min_showcase_double(metrics.body_width, 260.0),
            foreground=theme.palette.primary,
          ),
        ],
        spacing=theme.spacing_scale.md,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
      )
    } else {
      let visual_width = if metrics.compact { 212.0 } else { 284.0 }
      let capability_width = if metrics.compact {
        max_showcase_double(
          204.0,
          metrics.body_width - visual_width - theme.spacing_scale.md,
        )
      } else {
        244.0
      }
      @views.row(
        [
          self.visual_card(theme, metrics, active, offset, opacity),
          @views.column(
            [
              self.capability_card(theme, capability_width, 166.0),
              self.shortcut_preview(theme),
              @views.progress(
                slider.get(),
                width=capability_width,
                foreground=theme.palette.primary,
              ),
            ],
            spacing=theme.spacing_scale.sm,
            cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
          ),
        ],
        spacing=theme.spacing_scale.md,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
      )
    },
    metrics~,
  )
}

///|
fn ShowcaseApp::text_media_section(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  draft : @core.Binding[String],
  opacity : Double,
) -> @core.ViewSpec {
  ignore(self)
  section_panel(
    theme,
    "Text & Media",
    "Text, image, rich text editor, and Markdown editor share one app state.",
    @views.column(
      [
        @views.row(
          [
            @views.text("Label text", width=136.0, height=28.0)
            .font(theme.typography.body)
            .foreground(theme.palette.foreground),
            @views.image(
              showcase_image_source(),
              width=120.0,
              height=72.0,
              opacity~,
              corner_radius=theme.radius_scale.md,
              fit=@core.ImageFit::Cover,
            ).clip(),
          ],
          spacing=theme.spacing_scale.md,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
        @views.text_field(
          draft,
          placeholder="Editable text",
          style=@core.TextFieldStyle::outline(theme~),
          width=320.0,
        ),
        @views.rich_text_editor(
          draft,
          showcase_format_rich_text,
          placeholder="Rich text preview",
          width=320.0,
          height=78.0,
          style=@core.TextFieldStyle::filled(theme~),
        ),
        @views.markdown_editor(
          draft,
          @markdown_app.markdown_to_rich_text,
          placeholder="Markdown preview",
          width=320.0,
          height=78.0,
          style=@core.TextFieldStyle::outline(theme~),
        ),
      ],
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    metrics~,
  )
}

///|
fn ShowcaseApp::controls_section(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  draft : @core.Binding[String],
  tab : @core.Binding[String],
  slider : @core.Binding[Double],
  enabled : @core.Binding[Bool],
  secondary : @core.Binding[Bool],
  picker : @core.Binding[String],
  date : @core.Binding[@core.DateValue],
) -> @core.ViewSpec {
  section_panel(
    theme,
    "Controls",
    "All binding-backed controls are visible in one tabbed form.",
    @views.tab_view(tab, [
      @views.tab_item(
        route="form",
        label="Form",
        view=@views.grid(
          [
            @views.text_field(
              draft,
              on_submit=Some(() => self.toggle_active()),
              placeholder="Type a label",
              style=@core.TextFieldStyle::outline(theme~),
              width=220.0,
            ),
            @views.searchbar(
              query=draft,
              placeholder="Search catalog",
              foreground=theme.palette.foreground,
              background=@core.Brush::solid(theme.palette.surface_variant),
              corner_radius=theme.radius_scale.md,
            ),
            @views.button(
              "Primary",
              on_click=() => self.toggle_active(),
              style=@core.ButtonStyle::filled(theme~),
              width=104.0,
            ),
            @views.menu_button(
              "Menu",
              on_click=() => self.show_dialog(),
              style=@core.ButtonStyle::tonal(theme~),
              width=104.0,
            ),
            @views.checkbox(
              "Checkbox",
              checked=enabled,
              foreground=theme.palette.foreground,
              check_color=theme.palette.primary,
            ),
            @views.toggle(
              "Toggle",
              enabled,
              foreground=theme.palette.foreground,
              check_color=theme.palette.primary,
            ),
            @views.toggle_switch(
              "Toggle switch",
              secondary,
              foreground=theme.palette.foreground,
              check_color=theme.palette.primary,
            ),
            @views.radio(
              "Radio option",
              secondary,
              foreground=theme.palette.foreground,
              check_color=theme.palette.primary,
            ),
          ],
          columns=2,
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.md,
        ),
      ),
      @views.tab_item(
        route="values",
        label="Values",
        view=@views.column(
          [
            @views.slider(slider, width=300.0, foreground=theme.palette.primary),
            @views.progress(
              slider.get(),
              width=300.0,
              foreground=theme.palette.primary,
            ),
            @views.picker(
              [
                @views.picker_item("native", "Native WGPU"),
                @views.picker_item("web", "WebGPU"),
                @views.picker_item("test", "Test renderer"),
              ],
              selected=picker,
              placeholder="Renderer target",
              foreground=theme.palette.foreground,
              background=@core.Brush::solid(theme.palette.surface_variant),
              corner_radius=theme.radius_scale.md,
            ).frame(width=260.0, height=38.0),
            @views.datepicker(
              selected=date,
              mode=@core.DatePickerMode::Date,
              placeholder="Release date",
              foreground=theme.palette.foreground,
              background=@core.Brush::solid(theme.palette.surface_variant),
              corner_radius=theme.radius_scale.md,
            ).frame(width=260.0, height=38.0),
          ],
          spacing=theme.spacing_scale.md,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
      ),
    ]),
    metrics~,
  )
}

///|
fn ShowcaseApp::layout_section(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  slider : @core.Binding[Double],
) -> @core.ViewSpec {
  section_panel(
    theme,
    "Layout",
    "Rows, columns, grids, lazy windows, intrinsic sizing, and custom placement.",
    @views.column(
      [
        @views.row(
          [
            @views.expanded(self.layout_tile(theme, "Expanded"), weight=1.0),
            @views.flexible(self.layout_tile(theme, "Flexible"), weight=1.0),
            @views.spacer(min_length=12.0, weight=0.0),
            @views.frame(
              self.layout_tile(theme, "Frame"),
              width=92.0,
              height=48.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
        ),
        @views.grid(
          [
            @views.aspect_ratio(self.layout_tile(theme, "Aspect ratio"), 1.7),
            @views.intrinsic_width(self.layout_tile(theme, "Intrinsic width")),
            @views.intrinsic_height(self.layout_tile(theme, "Intrinsic height")),
            @views.layout_priority(self.layout_tile(theme, "Priority"), 2.0),
          ],
          columns=2,
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        @views.row(
          [
            @views.scroll_view(
              @views.lazy_list(
                self.gallery_items(),
                item => item,
                item => {
                  @views.text(item, width=180.0, height=24.0).foreground(
                    theme.palette.foreground,
                  )
                },
                state=self.list_scroll,
                item_height=26.0,
                viewport_height=84.0,
                spacing=2.0,
              ),
              width=200.0,
              height=88.0,
            ),
            @views.lazy_grid(
              self.gallery_items(),
              item => item,
              item => self.layout_tile(theme, item),
              state=self.grid_scroll,
              columns=2,
              item_height=40.0,
              viewport_width=220.0,
              viewport_height=88.0,
              row_spacing=4.0,
              column_spacing=4.0,
            ),
          ],
          spacing=theme.spacing_scale.md,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
        @views.stack([
          @views.overlay(
            @views.padding(self.layout_tile(theme, "Padding"), 8.0),
            @views.align(
              @views.text("Overlay", width=82.0, height=22.0).foreground(
                theme.palette.primary,
              ),
              alignment=@core.Alignment::top_trailing(),
            ),
          ),
          @views.padding_insets(
            @views.custom_children_layout(
              children=[
                @views.text("Custom children layout", width=180.0, height=24.0).foreground(
                  theme.palette.foreground,
                ),
              ],
              measure=ctx => {
                ctx.constraints.constrain(
                  @core.Size::new(width=220.0, height=34.0),
                )
              },
              place=ctx => [ctx.frame],
              paint=frame => {
                [
                  @core.DrawCommand::StrokeRoundedRect(
                    @core.RoundedRect::new(
                      rect=frame,
                      radius=theme.radius_scale.sm,
                    ),
                    theme.palette.primary,
                    1.0,
                  ),
                ]
              },
              semantics_label="Custom children layout",
            ),
            @core.Insets::all(4.0),
          ),
        ]),
        self.sparkline(theme, slider.get()),
      ],
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    metrics~,
  )
}

///|
fn ShowcaseApp::navigation_section(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  tab : @core.Binding[String],
) -> @core.ViewSpec {
  section_panel(
    theme,
    "Navigation",
    "Navigation stack, tab view, dialog host, and sheet host are wired together.",
    @views.column(
      [
        @views.tab_view(tab, [
          @views.tab_item(
            route="form",
            label="Routes",
            view=@views.text(
              "Current route: " + self.navigation.current(),
              width=300.0,
              height=28.0,
            ).foreground(theme.palette.foreground),
          ),
          @views.tab_item(
            route="values",
            label="Presentation",
            view=@views.row(
              [
                @views.button(
                  "Open dialog",
                  on_click=() => self.show_dialog(),
                  style=@core.ButtonStyle::filled(theme~),
                  width=128.0,
                ),
                @views.button(
                  "Open sheet",
                  on_click=() => self.show_sheet(),
                  style=@core.ButtonStyle::outline(theme~),
                  width=128.0,
                ),
              ],
              spacing=theme.spacing_scale.sm,
            ),
          ),
        ]),
        @views.text(
          "Dialog host and sheet host wrap the whole Showcase shell.",
          width=360.0,
          height=28.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    metrics~,
  )
}

///|
fn ShowcaseApp::examples_section(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.ViewSpec {
  section_panel(
    theme,
    "Examples",
    "Counter, Todo, and Markdown app packages are rendered inside Showcase.",
    @views.scroll_view(
      @views.column(
        [
          example_preview(theme, "Counter Preview", self.counter.root(ctx)),
          example_preview(theme, "Todo Preview", self.todo.root(ctx)),
          example_preview(theme, "Markdown Preview", self.markdown.root(ctx)),
        ],
        spacing=theme.spacing_scale.md,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
      ),
      width=metrics.body_width,
      height=metrics.body_height,
    ),
    metrics~,
  )
}

///|
fn ShowcaseApp::theme_renderer_section(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  enabled : @core.Binding[Bool],
  active : Bool,
  opacity : Double,
) -> @core.ViewSpec {
  let custom_theme = @views.theme(
    foreground=theme.palette.foreground,
    background=theme.palette.background,
    accent=theme.palette.primary,
    scheme=theme.scheme,
  )
  let environment = @views.environment(theme=custom_theme)
  ignore(environment)
  section_panel(
    theme,
    "Theme & Renderer",
    "Theme helpers and renderer capability report stay visible in the catalog.",
    if metrics.compact {
      @views.column(
        [
          self.theme_helpers(theme, enabled, active, opacity),
          self.capability_card(theme, metrics.body_width, 190.0),
        ],
        spacing=theme.spacing_scale.md,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
      )
    } else {
      @views.row(
        [
          self.theme_helpers(theme, enabled, active, opacity),
          self.capability_card(theme, 244.0, 190.0),
        ],
        spacing=theme.spacing_scale.md,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
      )
    },
    metrics~,
  )
}

///|
fn section_panel(
  theme : @core.Theme,
  title : String,
  summary : String,
  body : @core.ViewSpec,
  metrics~ : ShowcaseMetrics,
) -> @core.ViewSpec {
  @views.surface(
    @views.column(
      [
        @views.column(
          [
            @views.text(title, width=metrics.body_width, height=30.0)
            .font(theme.typography.control)
            .foreground(theme.palette.foreground),
            @views.text(summary, width=metrics.body_width, height=28.0)
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
          ],
          spacing=theme.spacing_scale.xs,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
        @views.scroll_view(
          body,
          width=metrics.body_width,
          height=metrics.body_height,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=metrics.panel_width,
    height=metrics.panel_height,
    style=showcase_panel_style(theme),
  )
}

///|
fn example_preview(
  theme : @core.Theme,
  title : String,
  child : @core.ViewSpec,
) -> @core.ViewSpec {
  @views.surface(
    @views.column(
      [
        @views.text(title, width=220.0, height=26.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        child.frame(width=470.0, height=150.0),
      ],
      spacing=theme.spacing_scale.xs,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=500.0,
    height=190.0,
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn ShowcaseApp::layout_tile(
  self : ShowcaseApp,
  theme : @core.Theme,
  label : String,
) -> @core.ViewSpec {
  ignore(self)
  @views.surface(
    @views.text(label, width=120.0, height=24.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.foreground),
    width=132.0,
    height=36.0,
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn ShowcaseApp::visual_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  active : Bool,
  offset : Double,
  opacity : Double,
) -> @core.ViewSpec {
  let card_width = if metrics.compact && metrics.body_width >= 448.0 {
    212.0
  } else if metrics.compact {
    min_showcase_double(metrics.body_width, 320.0)
  } else {
    284.0
  }
  let media_width = max_showcase_double(120.0, card_width - 36.0)
  let gradient = @core.Brush::linear_gradient(
    start=@core.Point::new(x=0.0, y=0.0),
    end=@core.Point::new(x=260.0, y=160.0),
    start_color=theme.palette.primary.multiply_alpha(0.92),
    end_color=theme.palette.surface_variant,
  )
  @views.surface(
    @views.column(
      [
        @views.image(
          showcase_image_source(),
          width=media_width,
          height=96.0,
          opacity~,
          corner_radius=theme.radius_scale.lg,
          fit=@core.ImageFit::Cover,
        )
        .background_brush(gradient)
        .corner_radius(theme.radius_scale.lg)
        .clip()
        .opacity(opacity)
        .offset(dx=offset, dy=0.0),
        @views.text(
          if active {
            "Raised card with motion"
          } else {
            "Layered card with image"
          },
          width=media_width,
          height=28.0,
        )
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.button(
          if active {
            "Settle"
          } else {
            "Animate"
          },
          on_click=() => self.toggle_active(),
          style=@core.ButtonStyle::filled(theme~),
          width=140.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=card_width,
    height=250.0,
    style=showcase_panel_style(theme),
  )
}

///|
fn ShowcaseApp::capability_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @core.ViewSpec {
  ignore(self)
  let inner_width = max_showcase_double(
    120.0,
    width - theme.spacing_scale.lg * 2.0,
  )
  let list_height = max_showcase_double(56.0, height - 78.0)
  let rows : Array[@core.ViewSpec] = []
  let visible_limit = max_showcase_int(1, (list_height / 24.0).to_int())
  let mut visible_count = 0
  for entry in @render.renderer_feature_capability_report() {
    if visible_count < visible_limit {
      rows.push(capability_row(entry, theme))
      visible_count = visible_count + 1
    }
  }
  @views.surface(
    @views.column(
      [
        @views.text("Renderer capability", width=inner_width, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.scroll_view(
          @views.column(
            rows,
            spacing=theme.spacing_scale.xs,
            cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
          ),
          width=inner_width,
          height=list_height,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width~,
    height~,
    style=showcase_panel_style(theme),
  )
}

///|
fn ShowcaseApp::visual_correctness_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  active : Bool,
  opacity : Double,
) -> @core.ViewSpec {
  ignore(self)
  @views.surface(
    @views.row(
      [
        @views.image(
          showcase_image_source(),
          width=82.0,
          height=50.0,
          opacity=1.0,
          corner_radius=theme.radius_scale.sm,
          fit=@core.ImageFit::Contain,
        ).clip(),
        @views.image(
          showcase_image_source(),
          width=82.0,
          height=50.0,
          opacity~,
          corner_radius=theme.radius_scale.sm,
          fit=@core.ImageFit::Cover,
        ).clip(),
        @views.image(
          showcase_image_source(),
          width=82.0,
          height=50.0,
          opacity=0.78,
          corner_radius=theme.radius_scale.md,
          fit=@core.ImageFit::Cover,
        )
        .clip()
        .scale(sx=0.92, sy=0.92)
        .offset(dx=if active { 10.0 } else { 0.0 }, dy=0.0),
      ],
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
    width=292.0,
    height=74.0,
    style=showcase_raised_demo_style(theme),
  )
}

///|
fn ShowcaseApp::shortcut_preview(
  self : ShowcaseApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  ignore(self)
  @views.surface(
    @views.text("Keyboard: Meta+K", width=190.0, height=28.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.foreground),
    width=220.0,
    height=50.0,
    style=showcase_panel_style(theme),
  )
}

///|
fn ShowcaseApp::theme_helpers(
  self : ShowcaseApp,
  theme : @core.Theme,
  enabled : @core.Binding[Bool],
  active : Bool,
  opacity : Double,
) -> @core.ViewSpec {
  @views.column(
    [
      @views.text("Theme helpers", width=220.0, height=28.0)
      .font(theme.typography.control)
      .foreground(theme.palette.foreground),
      @views.toggle_switch(
        "Environment enabled",
        enabled,
        foreground=theme.palette.foreground,
        check_color=theme.palette.primary,
      ),
      @views.button(
        "Switch scheme",
        on_click=() => self.toggle_scheme(),
        style=@core.ButtonStyle::outline(theme~),
        width=160.0,
      ),
      self.visual_correctness_card(theme, active, opacity),
    ],
    spacing=theme.spacing_scale.md,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
}

///|
fn ShowcaseApp::sparkline(
  self : ShowcaseApp,
  theme : @core.Theme,
  value : Double,
) -> @core.ViewSpec {
  ignore(self)
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width=300.0, height=34.0))
    },
    paint=frame => {
      let fill = @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + 10.0,
        width=frame.size.width * clamp_double(value, 0.0, 1.0),
        height=14.0,
      )
      [
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=frame, radius=theme.radius_scale.sm),
          @core.Brush::solid(theme.palette.surface_variant),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=fill, radius=7.0),
          @core.Brush::solid(theme.palette.primary),
        ),
      ]
    },
    semantics_label="Custom layout sparkline",
  )
}

///|
fn ShowcaseApp::dialog(
  self : ShowcaseApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  @views.column(
    [
      @views.text("Showcase dialog", width=240.0, height=30.0)
      .font(theme.typography.control)
      .foreground(theme.palette.foreground),
      @views.text(
        "Dialogs, shortcuts, and semantics share the same ViewSpec tree.",
        width=280.0,
        height=52.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      @views.button(
        "Close",
        on_click=() => self.hide_dialog(),
        style=@core.ButtonStyle::filled(theme~),
        width=120.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
}

///|
fn ShowcaseApp::sheet(
  self : ShowcaseApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  @views.sheet(
    content=@views.column(
      [
        @views.text("Showcase sheet", width=240.0, height=30.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.text(
          "Sheet content is built with the same presentation primitives.",
          width=300.0,
          height=48.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        @views.button(
          "Done",
          on_click=() => self.hide_sheet(),
          style=@core.ButtonStyle::filled(theme~),
          width=120.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    presentation_mode=@core.SheetPresentationMode::BottomSheet,
    background=@core.Brush::solid(theme.palette.surface),
    corner_radius=theme.radius_scale.lg,
    shadow=Some(theme.shadow_scale.md),
  )
}

///|
fn capability_row(
  entry : @render.RendererFeatureCapability,
  theme : @core.Theme,
) -> @core.ViewSpec {
  let status = capability_status_label(entry)
  @views.row(
    [
      @views.text(entry.feature.label(), width=92.0, height=22.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
      @views.text(status, width=112.0, height=22.0)
      .font(theme.typography.caption)
      .foreground(capability_status_color(entry, theme)),
    ],
    spacing=theme.spacing_scale.xs,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
  )
}

///|
fn capability_status_label(entry : @render.RendererFeatureCapability) -> String {
  if entry.native_status == entry.web_status {
    entry.native_status.label()
  } else {
    "native " +
    entry.native_status.label() +
    " / web " +
    entry.web_status.label()
  }
}

///|
fn capability_status_color(
  entry : @render.RendererFeatureCapability,
  theme : @core.Theme,
) -> @core.Color {
  if entry.native_status.needs_follow_up() || entry.web_status.needs_follow_up() {
    theme.palette.primary
  } else {
    theme.palette.muted
  }
}

///|
fn showcase_format_rich_text(value : String) -> @core.RichTextDocument {
  @core.RichTextDocument::new(blocks=[
    @core.RichTextBlock::new(runs=[@core.RichTextRun::new(text=value)]),
  ])
}

///|
fn string_contains(value : String, needle : String) -> Bool {
  if needle == "" {
    true
  } else {
    value.contains(needle)
  }
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn min_showcase_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_showcase_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn max_showcase_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn showcase_metrics(
  viewport : @core.Size,
  theme : @core.Theme,
) -> ShowcaseMetrics {
  let viewport = @core.Size::new(
    width=max_showcase_double(1.0, viewport.width),
    height=max_showcase_double(1.0, viewport.height),
  )
  let outer_padding = theme.spacing_scale.md * 2.0
  let shell_width = max_showcase_double(560.0, viewport.width - outer_padding)
  let sidebar_width = if shell_width < 760.0 { 220.0 } else { 244.0 }
  let detail_width = max_showcase_double(
    420.0,
    shell_width - sidebar_width - theme.spacing_scale.lg,
  )
  let panel_height = max_showcase_double(280.0, viewport.height - 108.0)
  let panel_padding = theme.spacing_scale.md * 2.0
  let body_width = max_showcase_double(220.0, detail_width - panel_padding)
  let body_height = max_showcase_double(120.0, panel_height - 96.0)
  let action_width = clamp_double(shell_width - 288.0, 240.0, 420.0)
  {
    viewport,
    shell_width,
    sidebar_width,
    detail_width,
    panel_width: detail_width,
    panel_height,
    body_width,
    body_height,
    action_width,
    compact: body_width < 620.0,
  }
}

///|
fn showcase_panel_style(theme : @core.Theme) -> @core.SurfaceStyle {
  {
    ..@core.SurfaceStyle::raised(theme~),
    shadow: None,
    padding: @core.Insets::all(theme.spacing_scale.md),
  }
}

///|
fn showcase_raised_demo_style(theme : @core.Theme) -> @core.SurfaceStyle {
  { ..@core.SurfaceStyle::raised(theme~), shadow: Some(theme.shadow_scale.sm) }
}

///|
fn ShowcaseApp::gallery_items(self : ShowcaseApp) -> Array[String] {
  ignore(self)
  [
    "State holders", "Modifier order", "Lazy list rows", "Keyboard shortcut", "Dialog host",
    "Accessible controls", "Grid cell", "Intrinsic size",
  ]
}

///|
fn showcase_image_source() -> String {
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAYAAAA6yNxSAAACK0lEQVR42u3Uu6okVRQG4HqIfoXqulBdt66iLt1nZo6nuyr1GTQwMDAQDAwMFEcZFS94YVScEbVRn0gUERER8QVEhPJDOKIwHkcxnOAL1l4L1h/svYPw0Z+WNRExCSkZG3IKSipqtjS0dPQMjOzYc8Y1rnODcy44cGRiJggf+3FZExGTkJKxIaegpKJmS0NLR8/AyI49Z1zjOjc454IDRyZmgvDxH5Y1ETEJKRkbcgpKKmq2NLR09AyM7Nhzxs+//PqHc/UFB45MzAThE98vayJiElIyNuQUlFTUbGlo6egZGNmx58/LL104P3BkYiYIn/xuWRMRk5CSsSGnoKSiZktDS0fPwMiOPWf85R9QX3DgyMRMsPr8tDz08CP/yurd07K6zTu8zVu8yRu8zmu8yiu8zEt/v+P3AKvP+PSfg6zeN/fe6T8FWN3ixdPVAVYnPuFjPuJD7nKHD07/S4DVC9zkeZ47PQjwIMDyG/KhyFi81CXIAAAAAElFTkSuQmCC"
}

///|
pub fn ShowcaseApp::runtime(
  self : ShowcaseApp,
  width? : Double = 960.0,
  height? : Double = 560.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_component(
    root=@core.Component::new(ctx => self.root(ctx)),
    size=@core.Size::new(width~, height~),
  )
}
