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
      column(
        [
          self.visual_card(theme, metrics, active, offset, opacity),
          self.capability_card(theme, metrics.body_width, 166.0),
          self.shortcut_preview(theme),
          progress(
            slider.get(),
            width=min_showcase_double(metrics.body_width, 260.0),
            foreground=theme.palette.primary,
          ),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
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
      row(
        [
          self.visual_card(theme, metrics, active, offset, opacity),
          column(
            [
              self.capability_card(theme, capability_width, 166.0),
              self.shortcut_preview(theme),
              progress(
                slider.get(),
                width=capability_width,
                foreground=theme.palette.primary,
              ),
            ],
            spacing=theme.spacing_scale.sm,
            align=@views.CrossAlign::Start,
          ),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
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
    column(
      [
        row(
          [
            text("Label text", width=136.0, height=28.0)
            .font(theme.typography.body)
            .foreground(theme.palette.foreground),
            image(
              showcase_image_source(),
              width=120.0,
              height=72.0,
              opacity~,
              fit=@core.ImageFit::Cover,
            ).clip(),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Start,
        ),
        text_field(
          draft,
          placeholder="Editable text",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=320.0,
        ),
        rich_text_editor(
          draft,
          showcase_format_rich_text,
          placeholder="Rich text preview",
          width=320.0,
          height=78.0,
          variant=@views.TextFieldVariant::Filled,
          theme~,
        ),
        markdown_editor(
          draft,
          showcase_format_markdown,
          placeholder="Markdown preview",
          width=320.0,
          height=78.0,
          variant=@views.TextFieldVariant::Outline,
          theme~,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
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
        view=grid(
          [
            text_field(
              draft,
              on_submit=Some(() => self.toggle_active()),
              placeholder="Type a label",
              variant=@views.TextFieldVariant::Outline,
              theme~,
              width=220.0,
            ),
            searchbar(query=draft, placeholder="Search catalog", theme~),
            button(
              "Primary",
              on_click=() => self.toggle_active(),
              variant=@views.ButtonVariant::Primary,
              theme~,
              width=104.0,
            ),
            menu_button(
              "Menu",
              on_click=() => self.show_dialog(),
              variant=@views.ButtonVariant::Tonal,
              theme~,
              width=104.0,
            ),
            checkbox(
              "Checkbox",
              checked=enabled,
              check_color=theme.palette.primary,
            ),
            toggle("Toggle", enabled, check_color=theme.palette.primary),
            toggle_switch(
              "Toggle switch",
              secondary,
              check_color=theme.palette.primary,
            ),
            radio("Radio option", secondary, check_color=theme.palette.primary),
          ],
          columns=2,
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.md,
        ),
      ),
      @views.tab_item(
        route="values",
        label="Values",
        view=column(
          [
            @views.slider(slider, width=300.0, foreground=theme.palette.primary),
            progress(
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
              theme~,
            ).frame(width=260.0, height=38.0),
            datepicker(
              selected=date,
              mode=@core.DatePickerMode::Date,
              placeholder="Release date",
              theme~,
            ).frame(width=260.0, height=38.0),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Start,
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
  let gallery_grid_columns = if metrics.compact { 1 } else { 2 }
  let gallery_grid_width = if metrics.compact { 252.0 } else { 324.0 }
  let gallery_grid_height = if metrics.compact { 128.0 } else { 100.0 }
  let gallery_list = scroll_view(
    lazy_list(
      self.gallery_items(),
      item => item,
      item => {
        text(item, width=180.0, height=24.0).foreground(
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
  )
  let gallery_grid = lazy_grid(
    self.gallery_items(),
    item => item,
    item => self.layout_tile(theme, item),
    state=self.grid_scroll,
    columns=gallery_grid_columns,
    item_height=44.0,
    viewport_width=gallery_grid_width,
    viewport_height=gallery_grid_height,
    row_spacing=4.0,
    column_spacing=4.0,
  )
  let gallery_browser = if metrics.compact {
    column(
      [gallery_list, gallery_grid],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    )
  } else {
    row(
      [gallery_list, gallery_grid],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    )
  }
  let overlay_demo = overlay(
    padding(self.layout_tile(theme, "Base: Padding"), 8.0),
    align(
      surface(
        text("Overlay", width=62.0, height=18.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.primary_foreground),
        width=82.0,
        height=26.0,
        background=theme.palette.primary.multiply_alpha(0.88),
        corner_radius=theme.radius_scale.sm,
        padding=4.0,
      ),
      alignment=@core.Alignment::top_trailing(),
    ),
  )
  let custom_children_demo = padding(
    @views.custom_children_layout(
      children=[
        text("Custom children layout", width=180.0, height=24.0).foreground(
          theme.palette.foreground,
        ),
      ],
      measure=ctx => {
        ctx.constraints.constrain(@core.Size::new(width=220.0, height=34.0))
      },
      place=ctx => [ctx.frame],
      paint=frame => {
        [
          @core.DrawCommand::StrokeRoundedRect(
            @core.RoundedRect::new(rect=frame, radius=theme.radius_scale.sm),
            theme.palette.primary,
            1.0,
          ),
        ]
      },
      semantics_label="Custom children layout",
    ),
    4.0,
  )
  let advanced_layout_demos = if metrics.compact {
    column(
      [overlay_demo, custom_children_demo],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    )
  } else {
    row(
      [overlay_demo, custom_children_demo],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Center,
    )
  }
  section_panel(
    theme,
    "Layout",
    "Rows, columns, grids, lazy windows, intrinsic sizing, and custom placement.",
    column(
      [
        row(
          [
            expanded(self.layout_tile(theme, "Expanded"), weight=1.0),
            flexible(self.layout_tile(theme, "Flexible"), weight=1.0),
            spacer(min_length=12.0, weight=0.0),
            frame(
              self.layout_tile_sized(theme, "Frame", 76.0, 32.0),
              width=92.0,
              height=48.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        grid(
          [
            frame(
              aspect_ratio(self.layout_tile(theme, "Aspect ratio"), 1.7),
              width=156.0,
              height=40.0,
            ),
            frame(
              intrinsic_width(self.layout_tile(theme, "Intrinsic width")),
              width=156.0,
              height=40.0,
            ),
            frame(
              intrinsic_height(self.layout_tile(theme, "Intrinsic height")),
              width=156.0,
              height=40.0,
            ),
            frame(
              layout_priority(self.layout_tile(theme, "Priority"), 2.0),
              width=156.0,
              height=40.0,
            ),
          ],
          columns=2,
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        gallery_browser,
        advanced_layout_demos,
        self.sparkline(theme, slider.get()),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
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
    column(
      [
        @views.tab_view(tab, [
          @views.tab_item(
            route="form",
            label="Routes",
            view=text(
              "Current route: " + self.navigation.current(),
              width=300.0,
              height=28.0,
            ).foreground(theme.palette.foreground),
          ),
          @views.tab_item(
            route="values",
            label="Presentation",
            view=row(
              [
                button(
                  "Open dialog",
                  on_click=() => self.show_dialog(),
                  variant=@views.ButtonVariant::Primary,
                  theme~,
                  width=128.0,
                ),
                button(
                  "Open sheet",
                  on_click=() => self.show_sheet(),
                  variant=@views.ButtonVariant::Outline,
                  theme~,
                  width=128.0,
                ),
              ],
              spacing=theme.spacing_scale.sm,
            ),
          ),
        ]),
        text(
          "Dialog host and sheet host wrap the whole Showcase shell.",
          width=360.0,
          height=28.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
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
    scroll_view(
      column(
        [
          example_preview(
            theme,
            "Counter Preview",
            self.counter_preview(ctx, theme),
          ),
          example_preview(theme, "Todo Preview", self.todo_preview(ctx, theme)),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
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
  surface(
    column(
      [
        text("MoUI Counter")
        .font(theme.typography.title)
        .foreground(theme.palette.foreground),
        text("Count: \{count}")
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        button(
          "Increment",
          on_click=() => self.counter_increment(),
          variant=@views.ButtonVariant::Primary,
          theme~,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Center,
    ),
    variant=@views.SurfaceVariant::Base,
    theme~,
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
    text("MoUI Todo")
    .font(theme.typography.title)
    .foreground(theme.palette.foreground),
    row(
      [
        text_field(
          draft,
          on_submit=Some(() => self.todo_submit_draft()),
          placeholder="New todo",
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=220.0,
        ),
        button(
          "Add",
          on_click=() => self.todo_submit_draft(),
          variant=@views.ButtonVariant::Primary,
          theme~,
          width=120.0,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
  ]
  for item in items {
    children.push(self.todo_row(item, theme))
  }
  surface(
    column(
      children,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
    variant=@views.SurfaceVariant::Base,
    theme~,
  )
}

///|
fn ShowcaseApp::todo_row(
  self : ShowcaseApp,
  item : ShowcaseTodoItem,
  theme : @core.Theme,
) -> @core.ViewSpec {
  row(
    [
      checkbox(
        item.text,
        checked=self.todo_completed_binding(item.id),
        check_color=theme.palette.primary,
      ).frame(width=220.0, height=36.0),
      button(
        "Remove",
        on_click=() => self.todo_remove(item.id),
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=120.0,
      ),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
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
      column(
        [
          self.theme_helpers(theme, enabled, active, opacity),
          self.capability_card(theme, metrics.body_width, 190.0),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      )
    } else {
      row(
        [
          self.theme_helpers(theme, enabled, active, opacity),
          self.capability_card(theme, 244.0, 190.0),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      )
    },
    metrics~,
  )
}
