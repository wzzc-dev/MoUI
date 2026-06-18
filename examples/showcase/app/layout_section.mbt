///|
fn ShowcaseModel::layout_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let gallery_grid_columns = if metrics.compact { 1 } else { 2 }
  let gallery_grid_width = if metrics.compact { 252.0 } else { 324.0 }
  let gallery_grid_height = if metrics.compact { 128.0 } else { 100.0 }
  let gallery_list = scroll_view(
    virtual_list(
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
      overscan=1,
    ),
    width=200.0,
    height=88.0,
  )
  let sectioned_gallery = sectioned_list(
    [
      @views.SectionListSection::new(id="layout", title="Layout helpers", items=[
        "Expanded", "Frame", "Priority",
      ]),
      @views.SectionListSection::new(id="lists", title="Virtual lists", items=[
        "Windowed", "Overscan", "Empty state",
      ]),
    ],
    item => "layout-section-" + item,
    item => {
      text(item, width=180.0, height=22.0).foreground(theme.palette.foreground)
    },
    header=section => {
      text(
        section.title,
        role=@views.TextRole::Caption,
        theme~,
        width=180.0,
        height=22.0,
      )
    },
    item_height=24.0,
    header_height=24.0,
    viewport_height=108.0,
    spacing=2.0,
    overscan=0,
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
      [gallery_list, sectioned_gallery, gallery_grid],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    )
  } else {
    row(
      [gallery_list, sectioned_gallery, gallery_grid],
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
        ctx.constraints.constrain(@moui.Size::new(width=220.0, height=34.0))
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
  let responsive_demo = column(
    [
      flow(
        [
          tag("Wrap", theme~),
          tag("Flow", theme~),
          tag("Responsive", theme~),
          tag("Baseline", theme~),
        ],
        width=260.0,
        spacing=theme.spacing_scale.xs,
        row_spacing=theme.spacing_scale.xs,
      ),
      responsive_grid(
        [
          self.layout_tile_sized(theme, "Grid One", 84.0, 32.0),
          self.layout_tile_sized(theme, "Grid Two", 84.0, 32.0),
          self.layout_tile_sized(theme, "Grid Three", 84.0, 32.0),
        ],
        width=300.0,
        min_column_width=92.0,
        row_spacing=theme.spacing_scale.xs,
        column_spacing=theme.spacing_scale.xs,
      ),
      baseline_form_rows(
        [
          @views.BaselineFormRow::new(
            label=text(
              "Baseline label",
              role=@views.TextRole::Caption,
              theme~,
              width=100.0,
              height=24.0,
            ),
            control=text_field(
              "Aligned",
              on_input=value => DraftChanged(value),
              theme~,
              width=150.0,
            ),
          ),
        ],
        width=300.0,
        label_width=112.0,
        row_spacing=theme.spacing_scale.xs,
        column_spacing=theme.spacing_scale.sm,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Start,
  )
  self.section_panel(
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
        responsive_demo,
        resizable_panel(
          content=column(
            [
              text(
                "Resizable Panel",
                role=@views.TextRole::Control,
                theme~,
                width=220.0,
                height=28.0,
              ),
              text(
                "Controlled size with a visual handle",
                role=@views.TextRole::Caption,
                theme~,
                width=240.0,
                height=28.0,
              ),
            ],
            spacing=theme.spacing_scale.xs,
            align=@views.CrossAlign::Start,
          ),
          size=220.0 + self.slider_value * 180.0,
          theme~,
          height=112.0,
          on_drag=Some(size => ResizePanel(size)),
        ),
        self.sparkline(theme, self.slider_value),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
  )
}

///|
