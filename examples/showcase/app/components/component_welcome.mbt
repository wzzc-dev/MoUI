///|
fn welcome_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let gap = theme.spacing_scale.sm
  // Match responsive_grid column counts so child widths equal placed cell
  // widths. Fixed 2/3-column math overlaps when the grid adds more columns.
  let stat_columns = welcome_grid_columns(
    available=inner,
    min_column_width=if compact { inner } else { 168.0 },
    column_spacing=gap,
    max_columns=3,
  )
  let group_columns = welcome_grid_columns(
    available=inner,
    min_column_width=if compact { inner } else { 220.0 },
    column_spacing=gap,
    max_columns=4,
  )
  let stat_width = welcome_cell_width(inner, stat_columns, gap)
  let group_width = welcome_cell_width(inner, group_columns, gap)
  column(
    [
      component_demo_section(
        "Catalog",
        "Focused component demos first; runtime proof stays available without becoming the main content.",
        column(
          [
            responsive_grid(
              [
                stat_card(
                  "Components",
                  "\{catalog_items().length()}",
                  caption="focused entries",
                  tone=@views.FeedbackTone::Info,
                  theme~,
                  width=stat_width,
                ),
                stat_card(
                  "Groups",
                  "\{catalog_groups().length()}",
                  caption="browse sections",
                  tone=@views.FeedbackTone::Success,
                  theme~,
                  width=stat_width,
                ),
                stat_card(
                  "Hosts",
                  "\{platform_runtime_infos().length()}",
                  caption="desktop/mobile/web",
                  tone=@views.FeedbackTone::Warning,
                  theme~,
                  width=stat_width,
                ),
              ],
              width=inner,
              min_column_width=if compact { inner } else { 168.0 },
              row_spacing=gap,
              column_spacing=gap,
            ),
            wrapped_text(
              "Use the left Stories rail to open small component demos. Each demo is plain app code you can reuse in another MoUI example.",
              role=@views.TextRole::Body,
              theme~,
              width=inner,
              height=56.0,
              align=@text.TextAlign::TextStart,
            ),
          ],
          spacing=gap,
          align=@views.CrossAlign::Stretch,
        ),
        theme,
        width,
      ),
      component_demo_section(
        "Component Groups",
        "The catalog is organized by how a user reaches for components.",
        responsive_grid(
          [
            component_tile(
              "Controls",
              "Button, text inputs, checkbox, toggle, radio, chips, picker, slider.",
              theme,
              group_width,
            ),
            component_tile(
              "Feedback",
              "Badge, progress, banner, callout, state panels, toast, snackbar.",
              theme,
              group_width,
            ),
            component_tile(
              "Display & Layout",
              "Stat cards, avatars, dividers, toolbars, surfaces, grids, scroll view.",
              theme,
              group_width,
            ),
            component_tile(
              "Runtime",
              "Host routes and platform proof stay available from Platform / Runtime stories.",
              theme,
              group_width,
            ),
          ],
          width=inner,
          min_column_width=if compact { inner } else { 220.0 },
          row_spacing=gap,
          column_spacing=gap,
        ),
        theme,
        width,
      ),
      component_demo_section(
        "Runtime Hosts",
        "The same component gallery adapts to each runtime route.",
        platform_badge_grid(model, theme, inner, compact),
        theme,
        width,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
/// Same column-count rule as `@views.responsive_grid`, with an optional cap so
/// welcome sections stay readable on very wide canvases.
fn welcome_grid_columns(
  available~ : Double,
  min_column_width~ : Double,
  column_spacing~ : Double,
  max_columns~ : Int,
) -> Int {
  let min_column_width = min_column_width.max(1.0)
  let max_columns = max_columns.max(1)
  let mut columns = 1
  let mut candidate = 2
  while candidate <= max_columns {
    let needed = candidate.to_double() * min_column_width +
      (candidate - 1).to_double() * column_spacing
    if needed > available {
      break
    }
    columns = candidate
    candidate = candidate + 1
  }
  columns
}

///|
fn welcome_cell_width(
  available : Double,
  columns : Int,
  column_spacing : Double,
) -> Double {
  let columns = columns.max(1)
  (
    (available - (columns - 1).to_double() * column_spacing) /
    columns.to_double()
  ).max(1.0)
}
