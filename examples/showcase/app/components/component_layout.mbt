///|
fn surface_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  // Align the tile width with the grid's column width so the two-column
  // layout stays stable during live resize. Using a fixed 220.0 min caused
  // a spurious 2→3 column pop at ~676px inner (≈1048px window) which
  // produced a 115px tile-vs-cell mismatch and height jitter perceived as
  // flicker. The tile now drives the column count.
  let sample_width = tile_width(inner, compact)
  component_demo_section(
    "Surface",
    "Containers provide the simple framing used by the gallery itself.",
    responsive_grid(
      [
        container(
          column(
            [
              text(
                "Base",
                role=@views.TextRole::Control,
                theme~,
                width=sample_width - 32.0,
                height=24.0,
              ),
              wrapped_text(
                "A quiet surface for grouped controls.",
                role=@views.TextRole::Caption,
                theme~,
                width=sample_width - 32.0,
                height=36.0,
                align=@text.TextAlign::TextStart,
              ).foreground(theme.palette.muted),
            ],
            spacing=4.0,
            align=@views.CrossAlign::Stretch,
          ),
          width=sample_width,
          height=112.0,
          variant=@views.ContainerVariant::Base,
          padding=16.0,
          corner_radius=8.0,
          theme~,
        ),
        card(
          column(
            [
              text(
                "Card",
                role=@views.TextRole::Control,
                theme~,
                width=sample_width - 32.0,
                height=24.0,
              ),
              wrapped_text(
                "A raised surface for previews and repeated components.",
                role=@views.TextRole::Caption,
                theme~,
                width=sample_width - 32.0,
                height=36.0,
                align=@text.TextAlign::TextStart,
              ).foreground(theme.palette.muted),
            ],
            spacing=4.0,
            align=@views.CrossAlign::Stretch,
          ),
          width=sample_width,
          height=112.0,
          padding=16.0,
          theme~,
        ),
      ],
      width=inner,
      min_column_width=sample_width,
      row_spacing=theme.spacing_scale.sm,
      column_spacing=theme.spacing_scale.sm,
    ),
    theme,
    width,
  )
}

///|
fn row_column_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let sample_width = tile_width(inner, compact)
  component_demo_section(
    "Row & Column",
    "The basic composition primitives stay explicit and predictable.",
    responsive_grid(
      [
        container(
          row(
            [
              status_badge(
                "one",
                tone=@views.BadgeTone::Accent,
                theme~,
                width=72.0,
              ),
              status_badge(
                "two",
                tone=@views.BadgeTone::Success,
                theme~,
                width=72.0,
              ),
              status_badge(
                "three",
                tone=@views.BadgeTone::Warning,
                theme~,
                width=82.0,
              ),
            ],
            spacing=theme.spacing_scale.xs,
            align=@views.CrossAlign::Center,
          ),
          width=sample_width,
          height=86.0,
          variant=@views.ContainerVariant::Base,
          background=theme.palette.surface_variant.multiply_alpha(0.45),
          padding=12.0,
          corner_radius=8.0,
          theme~,
        ),
        container(
          column(
            [
              text(
                "Mode",
                role=@views.TextRole::Caption,
                theme~,
                width=sample_width - 24.0,
                height=22.0,
              ).foreground(theme.palette.muted),
              text(
                mode_label(model.selected_mode),
                role=@views.TextRole::Subtitle,
                theme~,
                width=sample_width - 24.0,
                height=28.0,
              ),
            ],
            spacing=2.0,
            align=@views.CrossAlign::Stretch,
          ),
          width=sample_width,
          height=86.0,
          variant=@views.ContainerVariant::Base,
          background=theme.palette.surface_variant.multiply_alpha(0.45),
          padding=12.0,
          corner_radius=8.0,
          theme~,
        ),
      ],
      width=inner,
      min_column_width=sample_width,
      row_spacing=theme.spacing_scale.sm,
      column_spacing=theme.spacing_scale.sm,
    ),
    theme,
    width,
  )
}

///|
fn responsive_grid_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  // Keep the 4 tiles mapped to at most 2 columns (tile_width is half-width).
  // A fixed 150.0 min produced a 4-column layout on wide windows (728px inner)
  // which collapsed to 3→2 columns during resize, causing an 84px height jump
  // (1 row ↔ 2 rows) perceived as flicker. Using the tile width caps at 2 columns.
  let sample_width = tile_width(inner, compact)
  component_demo_section(
    "Responsive Grid",
    "Columns collapse automatically as the available width changes.",
    responsive_grid(
      [
        layout_tile(
          "Sidebar",
          if compact {
            "stacked"
          } else {
            "visible"
          },
          theme,
          sample_width,
        ),
        layout_tile("Mode", mode_label(model.selected_mode), theme, sample_width),
        layout_tile(
          "Density",
          density_label(model.selected_density),
          theme,
          sample_width,
        ),
        layout_tile("Scroll", "stateful", theme, sample_width),
      ],
      width=inner,
      min_column_width=sample_width,
      row_spacing=component_spacing(model, theme),
      column_spacing=theme.spacing_scale.sm,
    ),
    theme,
    width,
  )
}

///|
fn scroll_view_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let rows : Array[@moui.View[ComponentGalleryMsg]] = []
  for index in 1..<=8 {
    rows.push(
      component_tile(
        "Row \{index}",
        "This row is inside a clipped scroll viewport.",
        theme,
        inner - 24.0,
      ),
    )
  }
  component_demo_section(
    "Scroll View",
    "The page scroll uses a persistent state; this sample shows the same primitive in a small viewport.",
    container(
      scroll_view(
        column(
          rows,
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Stretch,
        ),
        width=inner - 24.0,
        height=208.0,
      ),
      width=inner,
      height=232.0,
      variant=@views.ContainerVariant::Base,
      background=theme.palette.surface_variant.multiply_alpha(0.35),
      padding=12.0,
      corner_radius=8.0,
      theme~,
    ),
    theme,
    width,
  )
}
