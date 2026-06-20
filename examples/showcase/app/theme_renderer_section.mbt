///|
fn ShowcaseModel::theme_renderer_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  let custom_theme = @views.theme(scheme=theme.scheme, palette=theme.palette)
  let environment = @views.environment(theme=custom_theme)
  ignore(environment)
  self.section_panel(
    theme,
    "Runtime & Renderer",
    "Host capability, theme helpers, and renderer reports stay visible in the catalog.",
    if metrics.compact {
      column(
        [
          self.host_capability_card(theme, metrics.body_width, 210.0),
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
          column(
            [
              self.host_capability_card(theme, 360.0, 210.0),
              self.capability_card(theme, 360.0, 250.0),
            ],
            spacing=theme.spacing_scale.md,
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
