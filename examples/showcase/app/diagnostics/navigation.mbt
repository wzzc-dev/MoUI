///|
/// Dispatch `selected_section` (already normalized by `open`) to its section
/// renderer. No second normalization pass — `selected_section` is the canonical
/// route id once the shell has routed into this workspace.
fn ShowcaseModel::current_destination(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
  offset : Double,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(offset)
  let route = self.selected_section
  if route == "runtime-renderer" {
    self.theme_renderer_section(theme, metrics, opacity)
  } else if route == "advanced-rendering" {
    self.advanced_rendering_section(theme, metrics)
  } else if route == "text-diagnostics" {
    self.text_diagnostics_section(theme, metrics)
  } else if route == "interaction-lab" {
    self.interaction_lab_section(theme, metrics)
  } else if route == "theme" {
    self.theme_side_section(theme, metrics, opacity)
  } else {
    self.diagnostics_section(theme, metrics)
  }
}

///|
/// Eyebrow label for a diagnostics sub-route, sourced from the catalog item
/// title so the sidebar and the section header agree without a second
/// hand-maintained lookup table.
fn showcase_route_eyebrow(route : String) -> String {
  for item in catalog_items() {
    if item.id == route {
      return "Diagnostics / " + item.title
    }
  }
  ""
}

///|
fn ShowcaseModel::theme_side_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  let body_width = metrics.body_width
  self.section_panel(
    theme,
    "Theme",
    "Theme helpers, toggle, scheme switch, and visual polish.",
    column(
      [
        self.theme_helpers(theme, self.active, opacity),
        button(
          "Open Dialog",
          on_click=ShowDialog,
          variant=@views.ButtonVariant::Primary,
          theme~,
          width=body_width,
          height=36.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
  )
}
