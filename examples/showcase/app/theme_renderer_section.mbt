///|
fn ShowcaseModel::theme_renderer_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  opacity : Double,
) -> @core.View[ShowcaseMsg] {
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
          self.theme_helpers(theme, self.active, opacity),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      )
    } else {
      row(
        [
          self.theme_helpers(theme, self.active, opacity),
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
