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
          showcase_format_markdown,
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
    "Counter and Todo are built into Showcase as reusable app patterns.",
    @views.scroll_view(
      @views.column(
        [
          example_preview(
            theme,
            "Counter Preview",
            self.counter_preview(ctx, theme),
          ),
          example_preview(theme, "Todo Preview", self.todo_preview(ctx, theme)),
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
fn ShowcaseApp::counter_preview(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
  theme : @core.Theme,
) -> @core.ViewSpec {
  let count = ctx.watch(self.counter_count)
  @views.surface(
    @views.column(
      [
        @views.text("MoUI Counter")
        .font(theme.typography.title)
        .foreground(theme.palette.foreground),
        @views.text("Count: \{count}")
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        @views.button(
          "Increment",
          on_click=() => self.counter_increment(),
          style=showcase_flat_filled_button_style(theme),
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn ShowcaseApp::todo_preview(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
  theme : @core.Theme,
) -> @core.ViewSpec {
  let items = ctx.watch(self.todo_items)
  let draft = ctx.binding(self.todo_draft)
  let children : Array[@core.ViewSpec] = [
    @views.text("MoUI Todo")
    .font(theme.typography.title)
    .foreground(theme.palette.foreground),
    @views.row(
      [
        @views.text_field(
          draft,
          on_submit=Some(() => self.todo_submit_draft()),
          placeholder="New todo",
          style=@core.TextFieldStyle::filled(theme~),
          width=220.0,
        ),
        @views.button(
          "Add",
          on_click=() => self.todo_submit_draft(),
          style=showcase_flat_filled_button_style(theme),
          width=120.0,
        ),
      ],
      spacing=8.0,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
  ]
  for item in items {
    children.push(self.todo_row(item, theme))
  }
  @views.surface(
    @views.column(
      children,
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn ShowcaseApp::todo_row(
  self : ShowcaseApp,
  item : ShowcaseTodoItem,
  theme : @core.Theme,
) -> @core.ViewSpec {
  @views.row(
    [
      @views.checkbox(
        item.text,
        checked=self.todo_completed_binding(item.id),
        foreground=theme.palette.foreground,
        check_color=theme.palette.primary,
      ).frame(width=220.0, height=36.0),
      @views.button(
        "Remove",
        on_click=() => self.todo_remove(item.id),
        style=@core.ButtonStyle::outline(theme~),
        width=120.0,
      ),
    ],
    spacing=8.0,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
  ).key("todo-\{item.id}")
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
