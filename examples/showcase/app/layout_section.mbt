///|
fn ShowcaseModel::layout_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
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
        resizable_panel(
          content=column(
            [
              text("Resizable Panel", role=@views.TextRole::Control, theme~, width=220.0, height=28.0),
              text("Controlled size with a visual handle", role=@views.TextRole::Caption, theme~, width=240.0, height=28.0),
            ],
            spacing=theme.spacing_scale.xs,
            align=@views.CrossAlign::Start,
          ),
          size=260.0,
          theme~,
          height=112.0,
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
