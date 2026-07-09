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
              role=@views.TextRole::Subtitle,
              theme~,
              width=inner,
              height=28.0,
              align=@text.TextAlign::TextStart,
            ),
            wrapped_text(
              detail,
              role=@views.TextRole::Caption,
              theme~,
              width=inner,
              height=38.0,
              align=@text.TextAlign::TextStart,
            ).foreground(theme.palette.muted),
          ],
          spacing=2.0,
          align=@views.CrossAlign::Stretch,
        ),
        body,
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    variant=@views.ContainerVariant::Raised,
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
          role=@views.TextRole::Control,
          theme~,
          width=width - 24.0,
          height=24.0,
          align=@text.TextAlign::TextStart,
        ),
        wrapped_text(
          detail,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
          height=36.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=84.0,
    variant=@views.ContainerVariant::Base,
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
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
          height=22.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
        text(
          value,
          role=@views.TextRole::Subtitle,
          theme~,
          width=width - 24.0,
          height=28.0,
          align=@text.TextAlign::TextStart,
        ),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=76.0,
    variant=@views.ContainerVariant::Base,
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
    role=@views.TextRole::Subtitle,
    theme~,
    width=if compact { width } else { (width - 220.0).max(180.0) },
    height=30.0,
    align=@text.TextAlign::TextStart,
  )
  let controls = row(
    [
      button(
        "-",
        on_click=Decrement,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=52.0,
      ),
      button(
        "Reset",
        on_click=Reset,
        variant=@views.ButtonVariant::Tonal,
        theme~,
        width=92.0,
      ),
      button(
        "+",
        on_click=Increment,
        variant=@views.ButtonVariant::Primary,
        theme~,
        width=52.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
  if compact {
    column(
      [label, controls],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    )
  } else {
    row(
      [label, spacer(weight=1.0), controls],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
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
          role=@views.TextRole::Control,
          theme~,
          width=label_width,
          height=24.0,
          align=@text.TextAlign::TextStart,
        ),
        spacer(weight=1.0),
        status_badge(
          if active {
            "host"
          } else {
            info.status
          },
          tone=if active { @views.BadgeTone::Accent } else { info.badge_tone },
          theme~,
          width=badge_width,
        ),
      ],
      spacing=gap,
      align=@views.CrossAlign::Center,
    ),
    width~,
    variant=@views.ContainerVariant::Base,
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
  let inner = width - 28.0
  container(
    column(
      [
        row(
          [
            text(
              info.name,
              role=@views.TextRole::Subtitle,
              theme~,
              width=(inner - 104.0).max(130.0),
              height=28.0,
              align=@text.TextAlign::TextStart,
            ),
            spacer(weight=1.0),
            status_badge(
              if active {
                "host"
              } else {
                info.status
              },
              tone=if active {
                @views.BadgeTone::Accent
              } else {
                info.badge_tone
              },
              theme~,
              width=92.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
        wrapped_text(
          info.route,
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=36.0,
          align=@text.TextAlign::TextStart,
        ),
        wrapped_text(
          info.command,
          role=@views.TextRole::Mono,
          theme~,
          width=inner,
          height=44.0,
          align=@text.TextAlign::TextStart,
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
          variant=if selected {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Tonal
          },
          theme~,
          width=112.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=244.0,
    variant=@views.ContainerVariant::Raised,
    padding=14.0,
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
    @views.FeedbackTone::Success
  } else if model.slider_value >= 0.48 {
    @views.FeedbackTone::Info
  } else {
    @views.FeedbackTone::Warning
  }
}
