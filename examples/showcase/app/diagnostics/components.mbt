///|
fn section_panel(
  theme : @moui.Theme,
  title : String,
  summary : String,
  body : @moui.View[ShowcaseMsg],
  metrics~ : ShowcaseMetrics,
  eyebrow? : String = "",
  scroll_offset? : @geometry.Point = @geometry.Point::new(x=0.0, y=0.0),
  scroll_state? : @state.ScrollState? = None,
  on_scroll? : ((@geometry.Point) -> ShowcaseMsg)? = None,
) -> @moui.View[ShowcaseMsg] {
  let header_extra = if eyebrow == "" {
    0.0
  } else {
    20.0 + theme.spacing_scale.xs
  }
  let scroll_height = max_showcase_double(
    80.0,
    metrics.body_height - header_extra,
  )
  let scroll_body = match on_scroll {
    Some(handler) =>
      scroll_view(
        body.repaint_boundary(),
        offset=scroll_offset,
        width=metrics.body_width,
        height=scroll_height,
        state=scroll_state,
        on_scroll=Some(handler),
      )
    None =>
      scroll_view(
        body.repaint_boundary(),
        offset=scroll_offset,
        width=metrics.body_width,
        height=scroll_height,
        state=scroll_state,
      )
  }
  let header_bg = match theme.scheme {
    @state.ColorScheme::Light =>
      theme.palette.surface_variant.multiply_alpha(0.32)
    @state.ColorScheme::Dark => @graphics.Color::white().multiply_alpha(0.04)
  }
  let header_rows : Array[@moui.View[ShowcaseMsg]] = []
  if eyebrow != "" {
    header_rows.push(
      text(eyebrow, width=metrics.body_width, height=20.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.primary),
    )
  }
  header_rows.push(
    text(title, width=metrics.body_width, height=30.0)
    .font(theme.typography.control)
    .foreground(theme.palette.foreground),
  )
  header_rows.push(
    text(summary, width=metrics.body_width, height=28.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted),
  )
  container(
    column(
      [
        column(
          header_rows,
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Start,
        ),
        // A hairline separates the section header from its scrollable body so
        // the hierarchy reads even when the body is long and dense.
        divider(theme~),
        scroll_body,
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    width=metrics.panel_width,
    height=metrics.panel_height,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
    background=header_bg,
  )
  .border(showcase_panel_border(theme))
  .repaint_boundary()
}

///|
fn ShowcaseModel::section_panel(
  self : ShowcaseModel,
  theme : @moui.Theme,
  title : String,
  summary : String,
  body : @moui.View[ShowcaseMsg],
  metrics~ : ShowcaseMetrics,
  eyebrow? : String = "",
) -> @moui.View[ShowcaseMsg] {
  let offset = @geometry.Point::new(
    x=0.0,
    y=max_showcase_double(0.0, self.detail_scroll.offset().y),
  )
  section_panel(
    theme,
    title,
    summary,
    body,
    metrics~,
    eyebrow~,
    scroll_offset=offset,
    scroll_state=Some(self.detail_scroll),
  )
}

///|
fn showcase_panel_border(theme : @moui.Theme) -> @graphics.BorderStyle {
  // Slightly softer than the legacy 0.82 outline so the panel reads as a calm
  // container rather than a hard-edged box, letting the new accent and surface
  // tones carry the hierarchy.
  @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(theme.palette.outline.multiply_alpha(0.6)),
    width=1.0,
  )
}

///|
/// Soft hairline border for elevated cards. Fainter than the panel border so
/// the shadow, not the stroke, carries the elevation cue.
fn showcase_card_border(theme : @moui.Theme) -> @graphics.BorderStyle {
  let color = match theme.scheme {
    @state.ColorScheme::Light => theme.palette.outline.multiply_alpha(0.55)
    @state.ColorScheme::Dark => @graphics.Color::white().multiply_alpha(0.06)
  }
  @graphics.BorderStyle::new(brush=@graphics.Brush::solid(color), width=1.0)
}

///|
fn showcase_soft_card(
  theme : @moui.Theme,
  child : @moui.View[ShowcaseMsg],
  width~ : Double,
  height~ : Double,
  padding? : Double = 0.0,
) -> @moui.View[ShowcaseMsg] {
  container(
    child,
    width~,
    height~,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding~,
  ).border(showcase_card_border(theme))
}

///|
fn ShowcaseModel::capability_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let inner_width = max_showcase_double(
    120.0,
    width - theme.spacing_scale.lg * 2.0,
  )
  let list_height = max_showcase_double(56.0, height - 72.0)
  let rows : Array[@moui.View[ShowcaseMsg]] = []
  let visible_limit = max_showcase_int(1, (list_height / 42.0).to_int())
  let entries = capability_card_entries(
    self.diagnostics_input.renderer_features,
  )
  let mut visible_count = 0
  for entry in entries {
    if visible_count < visible_limit {
      rows.push(capability_row(entry, theme, inner_width))
      visible_count = visible_count + 1
    }
  }
  showcase_soft_card(
    theme,
    column(
      [
        text("Renderer capability", width=inner_width, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        scroll_view(
          column(
            rows,
            spacing=theme.spacing_scale.xs,
            align=@views.CrossAlign::Start,
          ),
          width=inner_width,
          height=list_height,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::host_capability_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[ShowcaseMsg] {
  let inner_width = max_showcase_double(
    120.0,
    width - theme.spacing_scale.lg * 2.0,
  )
  let summary = self.diagnostics_input.host
  let rows = [
    host_capability_row(
      "Services",
      "\{summary.service_count}/\{summary.service_capacity}",
      host_label_summary(summary.service_labels, empty="no services"),
      theme,
      inner_width,
    ),
    host_capability_row(
      "Input",
      "\{summary.input_count}/\{summary.input_capacity}",
      host_label_summary(summary.input_labels, empty="no input"),
      theme,
      inner_width,
    ),
    host_capability_row(
      "Windows",
      if summary.multi_window {
        "multi"
      } else {
        "single"
      },
      if summary.window_lifecycle {
        "lifecycle queue ready"
      } else {
        "runtime-only test surface"
      },
      theme,
      inner_width,
    ),
  ]
  showcase_soft_card(
    theme,
    column(
      [
        text("Host capability", width=inner_width, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        text(
          summary.label + " / " + summary.backend_label,
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        column(
          rows,
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn host_capability_row(
  label : String,
  value : String,
  detail : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  let value_width = 78.0
  let label_width = max_showcase_double(70.0, width - value_width - 8.0)
  column(
    [
      row(
        [
          text(label, width=label_width, height=20.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.foreground),
          text(value, width=value_width, height=20.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.primary),
        ],
        spacing=8.0,
        align=@views.CrossAlign::Center,
      ),
      text(detail, width~, height=18.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn host_label_summary(labels : Array[String], empty~ : String) -> String {
  if labels.is_empty() {
    empty
  } else {
    let mut output = ""
    let limit = if labels.length() < 3 { labels.length() } else { 3 }
    for index in 0..<limit {
      if output == "" {
        output = labels[index]
      } else {
        output = output + ", " + labels[index]
      }
    }
    if labels.length() > limit {
      output + " +" + (labels.length() - limit).to_string()
    } else {
      output
    }
  }
}

///|
fn capability_card_entries(
  entries : Array[ShowcaseRendererFeatureDiagnostic],
) -> Array[ShowcaseRendererFeatureDiagnostic] {
  let primary : Array[ShowcaseRendererFeatureDiagnostic] = []
  let secondary : Array[ShowcaseRendererFeatureDiagnostic] = []
  let complete : Array[ShowcaseRendererFeatureDiagnostic] = []
  for entry in entries {
    match entry.priority {
      GapOrPartial => primary.push(entry)
      FollowUp => secondary.push(entry)
      Complete => complete.push(entry)
    }
  }
  primary + secondary + complete
}

///|
fn ShowcaseModel::visual_correctness_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  active : Bool,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let image_motion = @animation.TransitionSpec::slide(
    from_offset=@geometry.Point::new(x=0.0, y=0.0),
    to_offset=@geometry.Point::new(x=if active { 10.0 } else { 0.0 }, y=0.0),
    easing=@animation.Easing::Linear,
  )
  showcase_soft_card(
    theme,
    row(
      [
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity=1.0,
          corner_radius=theme.radius_scale.sm,
          fit=@graphics.ImageFit::Contain,
        ).clip(),
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity~,
          corner_radius=theme.radius_scale.sm,
          fit=@graphics.ImageFit::Cover,
        ).clip(),
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity=0.92,
          corner_radius=theme.radius_scale.sm,
          fit=@graphics.ImageFit::FitWidth,
        ).clip(),
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity=0.86,
          corner_radius=theme.radius_scale.sm,
          fit=@graphics.ImageFit::FitHeight,
        ).clip(),
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity=0.78,
          corner_radius=theme.radius_scale.md,
          fit=@graphics.ImageFit::ScaleDown,
        )
        .clip()
        .scale(sx=0.92, sy=0.92)
        .transition(spec=image_motion, progress=1.0),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
    width=292.0,
    height=74.0,
  )
}

///|
fn ShowcaseModel::theme_helpers(
  self : ShowcaseModel,
  theme : @moui.Theme,
  active : Bool,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  column(
    [
      text("Theme helpers", width=220.0, height=28.0)
      .font(theme.typography.control)
      .foreground(theme.palette.foreground),
      toggle(
        "Environment enabled",
        self.feature_enabled,
        on_change=value => FeatureEnabledChanged(value),
        foreground=theme.palette.foreground,
        check_color=theme.palette.primary,
      ),
      button(
        "Switch scheme",
        on_click=ToggleScheme,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=160.0,
      ),
      self.visual_correctness_card(theme, active, opacity),
      self.vector_path_card(theme),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Start,
  )
}

///|
fn ShowcaseModel::vector_path_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width=292.0, height=74.0))
    },
    paint=(ctx, frame) => {
      let inset = 12.0
      let left = frame.origin.x + inset
      let top = frame.origin.y + inset
      let bottom = frame.origin.y + frame.size.height - inset
      let mid_y = frame.origin.y + frame.size.height * 0.5
      let fill = @graphics.Brush::linear_gradient(
        start=@geometry.Point::new(x=left, y=top),
        end=@geometry.Point::new(x=left + 72.0, y=bottom),
        start_color=theme.palette.primary.multiply_alpha(0.88),
        end_color=theme.palette.primary.multiply_alpha(0.82),
      )
      let stroke = @graphics.Brush::solid(
        theme.palette.foreground.multiply_alpha(0.72),
      )
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=frame, radius=theme.radius_scale.md),
        @graphics.Brush::solid(
          theme.palette.surface_variant.multiply_alpha(0.42),
        ),
      )
      draw_path(
        ctx,
        @graphics.PathSpec::new(
          verbs=[
            @graphics.PathVerb::MoveTo(@geometry.Point::new(x=left, y=bottom)),
            @graphics.PathVerb::CubicTo(
              @geometry.Point::new(x=left + 24.0, y=top - 4.0),
              @geometry.Point::new(x=left + 58.0, y=top + 4.0),
              @geometry.Point::new(x=left + 82.0, y=bottom),
            ),
            @graphics.PathVerb::LineTo(
              @geometry.Point::new(x=left + 42.0, y=mid_y),
            ),
            @graphics.PathVerb::Close,
          ],
          fill=Some(fill),
        ),
      )
      draw_path(
        ctx,
        @graphics.PathSpec::new(
          verbs=[
            @graphics.PathVerb::MoveTo(
              @geometry.Point::new(x=left + 116.0, y=bottom),
            ),
            @graphics.PathVerb::QuadTo(
              @geometry.Point::new(x=left + 148.0, y=top),
              @geometry.Point::new(x=left + 180.0, y=bottom),
            ),
            @graphics.PathVerb::CubicTo(
              @geometry.Point::new(x=left + 196.0, y=mid_y),
              @geometry.Point::new(x=left + 216.0, y=mid_y),
              @geometry.Point::new(x=left + 236.0, y=top + 8.0),
            ),
          ],
          stroke=Some(stroke),
          stroke_width=3.0,
        ),
      )
    },
    semantics_label="Vector path renderer demo",
  )
}

///|
fn capability_row(
  entry : ShowcaseRendererFeatureDiagnostic,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  let status_width = clamp_double(width * 0.52, 156.0, 240.0)
  let feature_width = max_showcase_double(
    70.0,
    width - status_width - theme.spacing_scale.xs,
  )
  row(
    [
      text(entry.feature_label, width=feature_width, height=38.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
      capability_status_view(entry, theme, status_width),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}

///|
fn capability_status_view(
  entry : ShowcaseRendererFeatureDiagnostic,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  let providers = entry.providers
  let row_height = if providers.length() <= 2 { 18.0 } else { 13.0 }
  let rows : Array[@moui.View[ShowcaseMsg]] = []
  for provider in providers {
    rows.push(
      text(
        provider.provider_id + " " + provider.status_label,
        width~,
        height=row_height,
      )
      .font(theme.typography.caption)
      .foreground(capability_status_color(provider.needs_follow_up, theme)),
    )
  }
  column(rows, spacing=1.0, align=@views.CrossAlign::Start)
}

///|
fn capability_status_color(
  needs_follow_up : Bool,
  theme : @moui.Theme,
) -> @graphics.Color {
  if needs_follow_up {
    theme.palette.primary
  } else {
    theme.palette.muted
  }
}

///|
fn layout_tile_marker(theme : @moui.Theme) -> @moui.View[ShowcaseMsg] {
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width=4.0, height=22.0))
    },
    paint=(ctx, frame) => {
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=frame, radius=2.0),
        @graphics.Brush::solid(theme.palette.primary.multiply_alpha(0.72)),
      )
    },
    semantics_label="",
  )
}

///|
fn layout_tile(theme : @moui.Theme, label : String) -> @moui.View[ShowcaseMsg] {
  container(
    row(
      [
        layout_tile_marker(theme),
        text(label, width=120.0, height=20.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width=156.0,
    height=40.0,
    background=theme.palette.surface_variant.multiply_alpha(0.48),
    corner_radius=theme.radius_scale.sm,
    padding=6.0,
  )
}

///|
fn example_preview(
  theme : @moui.Theme,
  title : String,
  child : @moui.View[ShowcaseMsg],
  width? : Double = 500.0,
) -> @moui.View[ShowcaseMsg] {
  let inner_width = max_showcase_double(220.0, width - 30.0)
  container(
    column(
      [
        text(title, width=inner_width, height=26.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        child.frame(width=inner_width, height=150.0),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=190.0,
    variant=@views.ContainerVariant::Raised,
    theme~,
  ).border(showcase_card_border(theme))
}

///|
/// Visual card: a framed image with caption + corner badge, for image/avatar demos.
fn visual_card(
  theme : @moui.Theme,
  image_source : String,
  caption : String,
  badge : String,
  width? : Double = 240.0,
) -> @moui.View[ShowcaseMsg] {
  let inner_width = max_showcase_double(180.0, width - 24.0)
  container(
    column(
      [
        @views.image(image_source, width=inner_width, height=120.0),
        row(
          [
            text(caption, width=inner_width - 60.0, height=22.0)
            .font(theme.typography.caption)
            .foreground(theme.palette.foreground),
            text(badge, width=60.0, height=22.0)
            .font(theme.typography.caption)
            .foreground(theme.palette.primary),
          ],
          spacing=8.0,
          justify=@views.MainAlign::Between,
          align=@views.CrossAlign::Center,
        ).frame(width=inner_width, height=22.0),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=164.0,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=12.0,
  ).border(showcase_card_border(theme))
}
