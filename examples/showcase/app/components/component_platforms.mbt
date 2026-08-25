///|
fn platform_routes_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let card_width = if compact { inner } else { 320.0 }
  column(
    [
      session_runtime_panel(model, theme, width),
      component_demo_section(
        "Platform Routes",
        "Thin entrypoints launch the same Component Gallery program.",
        responsive_grid(
          platform_runtime_infos().map(info => {
            platform_route_card(model, info, theme, card_width)
          }),
          width=inner,
          min_column_width=card_width,
          row_spacing=theme.spacing_scale.md,
          column_spacing=theme.spacing_scale.md,
        ),
        theme,
        width,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn session_runtime_panel(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let info = model.session_runtime
  let inner = section_inner_width(width)
  let tile_w = if inner < 420.0 {
    inner
  } else {
    (inner - theme.spacing_scale.sm * 2.0) / 3.0
  }
  let note = if info.note == "" {
    "No fallback note for this session."
  } else {
    info.note
  }
  component_demo_section(
    "Session Runtime",
    "Active host path, backend, and surface route for this process.",
    column(
      [
        responsive_grid(
          [
            layout_tile("Path", info.path, theme, tile_w),
            layout_tile("Backend", info.backend, theme, tile_w),
            layout_tile("Surface", info.surface_route, theme, tile_w),
            layout_tile("Requested", info.requested, theme, tile_w),
            layout_tile(
              "GPU available",
              if info.gpu_available {
                "yes"
              } else {
                "no"
              },
              theme,
              tile_w,
            ),
            layout_tile(
              "GPU promoted",
              if info.gpu_promoted {
                "yes"
              } else {
                "no"
              },
              theme,
              tile_w,
            ),
          ],
          width=inner,
          min_column_width=tile_w,
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        status_badge(
          info.host,
          tone=@views.BadgeTone::Accent,
          detail=info.path,
          theme~,
          width=if inner < 280.0 { inner } else { 180.0 },
        ),
        wrapped_text(
          note,
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=48.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    theme,
    width,
  )
}
