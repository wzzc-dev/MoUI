///|
fn component_demo_section(
  title : String,
  detail : String,
  body : @moui.View[ComponentGalleryMsg],
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  container(
    column(
      [
        column(
          [
            text(
              title,
              role=Subtitle,
              theme~,
              width=inner,
              height=28.0,
              align=TextStart,
            ),
            wrapped_text(
              detail,
              role=Caption,
              theme~,
              width=inner,
              height=38.0,
              align=TextStart,
            ).foreground(theme.palette.muted),
          ],
          spacing=2.0,
          align=Stretch,
        ),
        body,
      ],
      spacing=theme.spacing_scale.sm,
      align=Stretch,
    ),
    width~,
    variant=Raised,
    padding=16.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn section_inner_width(width : Double) -> Double {
  (width - 32.0).max(256.0)
}

///|
fn tile_width(width : Double, compact : Bool) -> Double {
  if compact {
    width
  } else {
    (width - 24.0) / 2.0
  }
}

///|
fn component_tile(
  title : String,
  detail : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  container(
    column(
      [
        text(
          title,
          role=Control,
          theme~,
          width=width - 24.0,
          height=24.0,
          align=TextStart,
        ),
        wrapped_text(
          detail,
          role=Caption,
          theme~,
          width=width - 24.0,
          height=36.0,
          align=TextStart,
        ).foreground(theme.palette.muted),
      ],
      spacing=2.0,
      align=Stretch,
    ),
    width~,
    height=84.0,
    variant=Base,
    background=theme.palette.surface_variant.multiply_alpha(0.45),
    padding=12.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn layout_tile(
  title : String,
  value : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  container(
    column(
      [
        text(
          title,
          role=Caption,
          theme~,
          width=width - 24.0,
          height=22.0,
          align=TextStart,
        ).foreground(theme.palette.muted),
        text(
          value,
          role=Subtitle,
          theme~,
          width=width - 24.0,
          height=28.0,
          align=TextStart,
        ),
      ],
      spacing=2.0,
      align=Stretch,
    ),
    width~,
    height=76.0,
    variant=Base,
    background=theme.palette.surface_variant.multiply_alpha(0.48),
    padding=12.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn action_counter_panel(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let label = text(
    "Count: \{model.counter}",
    role=Subtitle,
    theme~,
    width=if compact { width } else { (width - 220.0).max(180.0) },
    height=30.0,
    align=TextStart,
  )
  let controls = row(
    [
      button("-", on_click=Decrement, variant=Outline, theme~, width=52.0),
      button("Reset", on_click=Reset, variant=Tonal, theme~, width=92.0),
      button("+", on_click=Increment, variant=Primary, theme~, width=52.0),
    ],
    spacing=theme.spacing_scale.sm,
    align=Center,
  )
  if compact {
    column([label, controls], spacing=theme.spacing_scale.sm, align=Start)
  } else {
    row(
      [label, spacer(weight=1.0), controls],
      spacing=theme.spacing_scale.sm,
      align=Center,
    )
  }
}

///|
fn platform_badge_grid(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let spacing = theme.spacing_scale.sm
  let min_column_width = if compact { width } else { 168.0 }
  let columns = gallery_grid_columns(width, min_column_width, spacing)
  let chip_width = gallery_grid_column_width(width, columns, spacing)
  responsive_grid(
    platform_runtime_infos().map(info => {
      platform_chip(model, info, theme, chip_width)
    }),
    width~,
    min_column_width~,
    row_spacing=spacing,
    column_spacing=spacing,
  )
}

///|
fn platform_chip(
  model : ComponentGalleryModel,
  info : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let active = info.id == model.active_platform
  let padding = 10.0
  let badge_width = 76.0
  let gap = theme.spacing_scale.xs
  let content_width = (width - padding * 2.0).max(1.0)
  let label_width = (content_width - badge_width - gap).max(1.0)
  container(
    row(
      [
        text(
          info.name,
          role=Control,
          theme~,
          width=label_width,
          height=24.0,
          align=TextStart,
        ),
        spacer(weight=1.0),
        status_badge(
          if active {
            "host"
          } else {
            info.status
          },
          tone=if active { Accent } else { info.badge_tone },
          theme~,
          width=badge_width,
        ),
      ],
      spacing=gap,
      align=Center,
    ),
    width~,
    variant=Base,
    background=theme.palette.surface_variant.multiply_alpha(0.45),
    padding~,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn platform_route_card(
  model : ComponentGalleryModel,
  info : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let selected = info.id == model.selected_platform
  let active = info.id == model.active_platform
  let border_color = if selected {
    theme.palette.primary
  } else {
    theme.palette.outline.multiply_alpha(0.5)
  }
  let padding = 14.0
  let inner = (width - padding * 2.0).max(1.0)
  let badge_width = 88.0
  let title_width = (inner - badge_width - theme.spacing_scale.xs).max(96.0)
  let stack = if inner < 240.0 {
    column(
      [
        text(
          info.name,
          role=Subtitle,
          theme~,
          width=inner,
          height=28.0,
          align=TextStart,
        ),
        status_badge(
          if active {
            "host"
          } else {
            info.status
          },
          tone=if active { Accent } else { info.badge_tone },
          theme~,
          width=badge_width,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=Start,
    )
  } else {
    row(
      [
        text(
          info.name,
          role=Subtitle,
          theme~,
          width=title_width,
          height=28.0,
          align=TextStart,
        ),
        spacer(weight=1.0),
        status_badge(
          if active {
            "host"
          } else {
            info.status
          },
          tone=if active { Accent } else { info.badge_tone },
          theme~,
          width=badge_width,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=Center,
    )
  }
  container(
    column(
      [
        stack,
        wrapped_text(
          info.route,
          role=Caption,
          theme~,
          width=inner,
          height=40.0,
          align=TextStart,
        ),
        wrapped_text(
          info.command,
          role=Mono,
          theme~,
          width=inner,
          height=56.0,
          align=TextStart,
        ),
        progress_status(
          "Evidence",
          value=info.progress,
          status=info.status,
          tone=info.tone,
          theme~,
          width=inner,
        ),
        button(
          "Select",
          on_click=SelectPlatform(platform_id_to_string(info.id)),
          variant=if selected { Primary } else { Tonal },
          theme~,
          width=if inner < 160.0 { inner } else { 112.0 },
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=Stretch,
    ),
    width~,
    variant=Raised,
    padding~,
    corner_radius=8.0,
    theme~,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border_color),
      width=if selected { 2.0 } else { 1.0 },
    ),
  )
}

///|
fn component_spacing(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
) -> Double {
  match model.selected_density {
    "compact" => theme.spacing_scale.xs
    "comfortable" => theme.spacing_scale.lg
    _ => theme.spacing_scale.sm
  }
}

///|
fn mode_label(id : String) -> String {
  match id {
    "canvas" => "Canvas"
    "states" => "States"
    "runtime" => "Runtime"
    _ => "Canvas"
  }
}

///|
fn density_label(id : String) -> String {
  match id {
    "compact" => "Compact"
    "regular" => "Regular"
    "comfortable" => "Comfortable"
    _ => "Regular"
  }
}

///|
fn score_label(model : ComponentGalleryModel) -> String {
  "\{(model.slider_value * 100.0).round().to_int()}%"
}

///|
fn feedback_tone(model : ComponentGalleryModel) -> @views.FeedbackTone {
  if model.slider_value >= 0.82 {
    Success
  } else if model.slider_value >= 0.48 {
    Info
  } else {
    Warning
  }
}
