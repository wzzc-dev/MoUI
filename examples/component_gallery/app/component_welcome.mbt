///|
fn welcome_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
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
                  "\{component_gallery_items().length()}",
                  caption="focused entries",
                  tone=@views.FeedbackTone::Info,
                  theme~,
                  width=welcome_stat_width(inner, compact),
                ),
                stat_card(
                  "Groups",
                  "\{component_gallery_groups().length()}",
                  caption="browse sections",
                  tone=@views.FeedbackTone::Success,
                  theme~,
                  width=welcome_stat_width(inner, compact),
                ),
                stat_card(
                  "Hosts",
                  "\{platform_runtime_infos().length()}",
                  caption="desktop/mobile/web",
                  tone=@views.FeedbackTone::Warning,
                  theme~,
                  width=welcome_stat_width(inner, compact),
                ),
              ],
              width=inner,
              min_column_width=if compact { inner } else { 168.0 },
              row_spacing=theme.spacing_scale.sm,
              column_spacing=theme.spacing_scale.sm,
            ),
            wrapped_text(
              "Use the sidebar to jump between small component demos. Each demo is plain app code that can be reused in another MoUI example.",
              role=@views.TextRole::Body,
              theme~,
              width=inner,
              height=56.0,
              align=@text.TextAlign::TextStart,
            ),
          ],
          spacing=theme.spacing_scale.sm,
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
              welcome_group_width(inner, compact),
            ),
            component_tile(
              "Feedback",
              "Badge, progress, banner, callout, state panels, toast, snackbar.",
              theme,
              welcome_group_width(inner, compact),
            ),
            component_tile(
              "Display & Layout",
              "Stat cards, avatars, dividers, toolbars, surfaces, grids, scroll view.",
              theme,
              welcome_group_width(inner, compact),
            ),
            component_tile(
              "Runtime",
              "Six host routes run this same shared app package.",
              theme,
              welcome_group_width(inner, compact),
            ),
          ],
          width=inner,
          min_column_width=if compact { inner } else { 220.0 },
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
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
fn welcome_stat_width(width : Double, compact : Bool) -> Double {
  if compact {
    width
  } else {
    (width - 24.0) / 3.0
  }
}

///|
fn welcome_group_width(width : Double, compact : Bool) -> Double {
  if compact {
    width
  } else {
    (width - 12.0) / 2.0
  }
}
