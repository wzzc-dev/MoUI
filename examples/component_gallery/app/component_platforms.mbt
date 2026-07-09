///|
fn platform_routes_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let card_width = if compact { inner } else { 300.0 }
  component_demo_section(
    "Platform Routes",
    "Thin entrypoints launch the same Component Gallery program.",
    responsive_grid(
      platform_runtime_infos().map(info => {
        platform_route_card(model, info, theme, card_width)
      }),
      width=inner,
      min_column_width=if compact { inner } else { 280.0 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    theme,
    width,
  )
}
