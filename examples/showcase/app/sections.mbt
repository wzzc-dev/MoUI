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
      let visual_width = min_showcase_double(metrics.body_width, 320.0)
      column(
        [
          self.visual_card(
            theme, metrics, visual_width, active, offset, opacity,
          ),
          self.capability_card(theme, metrics.body_width, 220.0),
          self.shortcut_preview(theme),
          self.progress_preview(
            theme,
            slider.get(),
            width=min_showcase_double(metrics.body_width, 260.0),
          ),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      )
    } else {
      let side_width = if metrics.compact {
        max_showcase_double(220.0, metrics.body_width * 0.44)
      } else {
        clamp_double(metrics.body_width * 0.32, 260.0, 380.0)
      }
      let visual_width = if metrics.compact {
        max_showcase_double(
          212.0,
          metrics.body_width - side_width - theme.spacing_scale.md,
        )
      } else {
        clamp_double(
          metrics.body_width - side_width - theme.spacing_scale.md,
          320.0,
          620.0,
        )
      }
      let capability_width = side_width
      let capability_height = if metrics.compact { 142.0 } else { 220.0 }
      row(
        [
          self.visual_card(
            theme, metrics, visual_width, active, offset, opacity,
          ),
          column(
            [
              self.capability_card(theme, capability_width, capability_height),
              self.shortcut_preview(theme),
              self.progress_preview(theme, slider.get(), width=capability_width),
            ],
            spacing=theme.spacing_scale.md,
            align=@views.CrossAlign::Start,
          ),
        ],
        spacing=theme.spacing_scale.lg,
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
          self.capability_card(theme, metrics.body_width, 250.0),
          self.theme_helpers(theme, enabled, active, opacity),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      )
    } else {
      row(
        [
          self.theme_helpers(theme, enabled, active, opacity),
          self.capability_card(theme, 360.0, 250.0),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      )
    },
    metrics~,
  )
}

///|
fn ShowcaseApp::advanced_rendering_section(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.ViewSpec {
  ignore(self)
  let card_width = if metrics.compact { 260.0 } else { 300.0 }
  let cards = [
    advanced_rendering_card(theme, "Layer + Blend", card_width, "blend"),
    advanced_rendering_card(theme, "Filter", card_width, "filter"),
    advanced_rendering_card(theme, "Shader", card_width, "shader"),
    advanced_rendering_card(theme, "Path + Transform", card_width, "path"),
  ]
  section_panel(
    theme,
    "Advanced Rendering",
    "Layers, blend modes, filters, shader effects, paths, transforms, and opacity.",
    grid(
      cards,
      columns=if metrics.compact { 1 } else { 2 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
  )
}

///|
fn advanced_rendering_card(
  theme : @core.Theme,
  title : String,
  width : Double,
  mode : String,
) -> @core.ViewSpec {
  showcase_soft_card(
    theme,
    column(
      [
        text(title, width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        advanced_rendering_canvas(theme, mode, width - 32.0, 108.0),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=158.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn advanced_rendering_canvas(
  theme : @core.Theme,
  mode : String,
  width : Double,
  height : Double,
) -> @core.ViewSpec {
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width~, height~))
    },
    paint=frame => {
      let bg = @core.RoundedRect::new(rect=frame, radius=theme.radius_scale.md)
      let inset = 14.0
      let left = frame.origin.x + inset
      let top = frame.origin.y + inset
      let rect_a = @core.Rect::new(x=left, y=top, width=88.0, height=58.0)
      let rect_b = @core.Rect::new(
        x=left + 42.0,
        y=top + 24.0,
        width=96.0,
        height=58.0,
      )
      let commands : Array[@core.DrawCommand] = [
        @core.DrawCommand::FillRoundedRectBrush(
          bg,
          @core.Brush::solid(theme.palette.surface_variant.multiply_alpha(0.36)),
        ),
      ]
      match mode {
        "blend" => {
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(rect=rect_a, radius=12.0),
              @core.Brush::solid(theme.palette.primary.multiply_alpha(0.82)),
            ),
          )
          commands.push(
            @core.DrawCommand::PushLayer(
              @core.LayerSpec::new(
                opacity=0.86,
                blend_mode=@core.BlendMode::Multiply,
                offscreen=true,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(rect=rect_b, radius=18.0),
              @core.Brush::solid(theme.accent.multiply_alpha(0.84)),
            ),
          )
          commands.push(@core.DrawCommand::PopLayer)
          commands.push(
            @core.DrawCommand::PushLayer(
              @core.LayerSpec::new(
                opacity=0.72,
                blend_mode=@core.BlendMode::Screen,
                offscreen=true,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(
                rect=@core.Rect::new(
                  x=left + 96.0,
                  y=top + 8.0,
                  width=58.0,
                  height=58.0,
                ),
                radius=29.0,
              ),
              @core.Brush::solid(theme.palette.surface.multiply_alpha(0.7)),
            ),
          )
          commands.push(@core.DrawCommand::PopLayer)
          commands.push(
            @core.DrawCommand::PushLayer(
              @core.LayerSpec::new(
                opacity=0.68,
                blend_mode=@core.BlendMode::Overlay,
                offscreen=true,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(
                rect=@core.Rect::new(
                  x=left + 18.0,
                  y=top + 58.0,
                  width=116.0,
                  height=26.0,
                ),
                radius=13.0,
              ),
              @core.Brush::solid(theme.palette.foreground.multiply_alpha(0.36)),
            ),
          )
          commands.push(@core.DrawCommand::PopLayer)
        }
        "filter" => {
          commands.push(
            @core.DrawCommand::PushFilter(@core.FilterEffect::blur(4.0)),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(rect=rect_a, radius=16.0),
              @core.Brush::solid(theme.palette.primary.multiply_alpha(0.66)),
            ),
          )
          commands.push(
            @core.DrawCommand::FillRoundedRectBrush(
              @core.RoundedRect::new(rect=rect_b, radius=16.0),
              @core.Brush::solid(theme.palette.foreground.multiply_alpha(0.22)),
            ),
          )
          commands.push(@core.DrawCommand::PopFilter)
        }
        "shader" => {
          commands.push(
            @core.DrawCommand::DrawShaderEffect(
              @core.ShaderEffectSpec::new(
                name="checker",
                frame=frame.inset(@core.Insets::all(10.0)),
                uniforms=[8.0, 0.6],
                fallback=@core.Brush::solid(theme.palette.surface_variant),
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawShaderEffect(
              @core.ShaderEffectSpec::new(
                name="vignette",
                frame=frame.inset(@core.Insets::all(24.0)),
                uniforms=[0.35],
                fallback=@core.Brush::solid(
                  theme.palette.primary.multiply_alpha(0.5),
                ),
              ),
            ),
          )
        }
        _ => {
          commands.push(@core.DrawCommand::PushOpacity(0.82))
          commands.push(
            @core.DrawCommand::PushTransform(
              @core.Transform2D::translation(dx=18.0, dy=4.0),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawPath(
              @core.PathSpec::new(
                verbs=[
                  @core.PathVerb::MoveTo(
                    @core.Point::new(x=left + 8.0, y=top + 74.0),
                  ),
                  @core.PathVerb::CubicTo(
                    @core.Point::new(x=left + 42.0, y=top - 6.0),
                    @core.Point::new(x=left + 104.0, y=top + 14.0),
                    @core.Point::new(x=left + 136.0, y=top + 76.0),
                  ),
                  @core.PathVerb::LineTo(
                    @core.Point::new(x=left + 70.0, y=top + 48.0),
                  ),
                  @core.PathVerb::Close,
                ],
                fill=Some(
                  @core.Brush::solid(theme.palette.primary.multiply_alpha(0.72)),
                ),
                stroke=Some(
                  @core.Brush::solid(
                    theme.palette.foreground.multiply_alpha(0.48),
                  ),
                ),
                stroke_width=2.0,
              ),
            ),
          )
          commands.push(@core.DrawCommand::PopTransform)
          commands.push(@core.DrawCommand::PopOpacity)
        }
      }
      commands
    },
    semantics_label=mode,
  )
}

///|
fn ShowcaseApp::text_diagnostics_section(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  draft : @core.Binding[String],
) -> @core.ViewSpec {
  ignore(self)
  let card_width = if metrics.compact { metrics.body_width } else { 300.0 }
  section_panel(
    theme,
    "Text Diagnostics",
    "CJK, bidi, emoji, wrapping, Markdown, and rich text diagnostics.",
    grid(
      [
        text_diagnostic_card(
          theme, "CJK", "MoUI 文本 mixed with English 123", card_width,
        ),
        text_diagnostic_card(
          theme, "RTL / Bidi", "مرحبا MoUI 123 שלום", card_width,
        ),
        text_diagnostic_card(
          theme, "Emoji", "Text 😀🚀✨  native gap\nweb partial", card_width,
        ),
        text_diagnostic_card(
          theme, "Wrapping", "A deliberately long diagnostic sentence is clipped inside a fixed card so layout bounds stay visible.",
          card_width,
        ),
        showcase_soft_card(
          theme,
          column(
            [
              text("Markdown/Rich Text", width=card_width - 32.0, height=24.0)
              .font(theme.typography.caption)
              .foreground(theme.palette.foreground),
              markdown_editor(
                draft,
                showcase_format_markdown,
                placeholder="Markdown diagnostic",
                width=card_width - 32.0,
                height=76.0,
                variant=@views.TextFieldVariant::Outline,
                theme~,
              ),
            ],
            spacing=theme.spacing_scale.sm,
            align=@views.CrossAlign::Start,
          ),
          width=card_width,
          height=132.0,
          padding=theme.spacing_scale.md,
        ),
      ],
      columns=if metrics.compact { 1 } else { 2 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
  )
}

///|
fn text_diagnostic_card(
  theme : @core.Theme,
  title : String,
  sample : String,
  width : Double,
) -> @core.ViewSpec {
  showcase_soft_card(
    theme,
    column(
      [
        text(title, width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        scroll_view(
          text(sample, width=width - 52.0, height=64.0)
          .font(theme.typography.body)
          .foreground(theme.palette.muted),
          width=width - 32.0,
          height=68.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=124.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseApp::interaction_lab_section(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  draft : @core.Binding[String],
) -> @core.ViewSpec {
  let drop_label = ctx.watch(self.last_drop_label)
  let card_width = if metrics.compact { metrics.body_width } else { 300.0 }
  section_panel(
    theme,
    "Interaction Lab",
    "Tooltip, file drop, focus, shortcuts, variants, and image lifecycle states.",
    grid(
      [
        self.tooltip_demo_card(theme, card_width),
        self.file_drop_card(theme, card_width, drop_label),
        self.focus_shortcut_card(theme, card_width),
        self.variant_gallery_card(theme, card_width, draft),
        self.image_lifecycle_card(theme, card_width),
      ],
      columns=if metrics.compact { 1 } else { 2 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
  )
}

///|
fn ShowcaseApp::tooltip_demo_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  width : Double,
) -> @core.ViewSpec {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Tooltip", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        tooltip(
          button(
            "Hover target",
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=140.0,
          ),
          "Tooltip: Meta+K",
          visible=true,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=136.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseApp::file_drop_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  width : Double,
  drop_label : String,
) -> @core.ViewSpec {
  showcase_soft_card(
    theme,
    column(
      [
        text("File Drop", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        surface(
          text("Drop files here", width=width - 64.0, height=24.0)
          .font(theme.typography.body)
          .foreground(theme.palette.foreground),
          width=width - 32.0,
          height=46.0,
          background=theme.palette.surface_variant.multiply_alpha(0.44),
          corner_radius=theme.radius_scale.sm,
          padding=8.0,
        ).on_file_drop((paths, _point) => self.record_file_drop(paths)),
        text(drop_label, width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=146.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseApp::focus_shortcut_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  width : Double,
) -> @core.ViewSpec {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Focus + Shortcut", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        button(
          "Focusable action",
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=180.0,
        )
        .focusable()
        .keyboard_shortcut(
          @core.KeyboardShortcut::new(
            key="k",
            modifiers=@core.KeyModifiers::new(meta=true),
          ),
        ),
        text("Keyboard shortcut: Meta+K", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=136.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseApp::variant_gallery_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  width : Double,
  draft : @core.Binding[String],
) -> @core.ViewSpec {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Variants", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        row(
          [
            button(
              "Primary",
              variant=@views.ButtonVariant::Primary,
              theme~,
              width=82.0,
              height=34.0,
            ),
            button(
              "Tonal",
              variant=@views.ButtonVariant::Tonal,
              theme~,
              width=76.0,
              height=34.0,
            ),
            button(
              "Ghost",
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=76.0,
              height=34.0,
            ),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Center,
        ),
        text_field(
          draft,
          placeholder="Outline",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=width - 32.0,
          height=36.0,
        ),
        text("Outline", width=width - 32.0, height=18.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text_field(
          draft,
          placeholder="Plain",
          variant=@views.TextFieldVariant::Plain,
          theme~,
          width=width - 32.0,
          height=32.0,
        ),
        text("Plain", width=width - 32.0, height=18.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        row(
          [
            surface_variant_tile(theme, "Base", @views.SurfaceVariant::Base),
            surface_variant_tile(
              theme,
              "Overlay",
              @views.SurfaceVariant::Overlay,
            ),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=228.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn surface_variant_tile(
  theme : @core.Theme,
  label : String,
  variant : @views.SurfaceVariant,
) -> @core.ViewSpec {
  surface(
    text(label, width=80.0, height=22.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.foreground),
    width=92.0,
    height=34.0,
    variant~,
    theme~,
    padding=6.0,
  )
}

///|
fn ShowcaseApp::image_lifecycle_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  width : Double,
) -> @core.ViewSpec {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Image Lifecycle", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        row(
          [
            image_lifecycle_tile(theme, "Ready", showcase_image_source()),
            image_lifecycle_tile(theme, "Loading", ""),
            image_lifecycle_tile(theme, "Failed", "missing://showcase-image"),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=142.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn image_lifecycle_tile(
  theme : @core.Theme,
  label : String,
  source : String,
) -> @core.ViewSpec {
  column(
    [
      image(
        source,
        width=72.0,
        height=44.0,
        opacity=if label == "Loading" { 0.36 } else { 1.0 },
        corner_radius=theme.radius_scale.sm,
        fit=@core.ImageFit::Cover,
      )
      .background(theme.palette.surface_variant.multiply_alpha(0.5))
      .clip(),
      text(label, width=72.0, height=20.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Start,
  )
}
