///|
fn ShowcaseModel::overview_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  offset : Double,
  opacity : Double,
) -> @core.View[ShowcaseMsg] {
  section_panel(
    theme,
    "Overview",
    "Showcase is now a data-driven catalog of MoUI views.",
    if metrics.compact && metrics.body_width < 448.0 {
      let visual_width = min_showcase_double(metrics.body_width, 320.0)
      column(
        [
          self.visual_card(
            theme,
            metrics,
            visual_width,
            self.active,
            offset,
            opacity,
          ),
          self.capability_card(theme, metrics.body_width, 220.0),
          self.shortcut_preview(theme),
          self.progress_preview(
            theme,
            self.slider_value,
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
            theme,
            metrics,
            visual_width,
            self.active,
            offset,
            opacity,
          ),
          column(
            [
              self.capability_card(theme, capability_width, capability_height),
              self.shortcut_preview(theme),
              self.progress_preview(
                theme,
                self.slider_value,
                width=capability_width,
              ),
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
