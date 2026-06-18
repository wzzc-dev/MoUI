///|
fn section_panel(
  theme : @moui.Theme,
  title : String,
  summary : String,
  body : @moui.View[ShowcaseMsg],
  metrics~ : ShowcaseMetrics,
  scroll_offset? : @moui.Point = @moui.Point::new(x=0.0, y=0.0),
  scroll_state? : @core.ScrollState? = None,
  on_scroll? : ((@moui.Point) -> ShowcaseMsg)? = None,
) -> @moui.View[ShowcaseMsg] {
  let scroll_body = match on_scroll {
    Some(handler) =>
      scroll_view(
        body.repaint_boundary(),
        offset=scroll_offset,
        width=metrics.body_width,
        height=metrics.body_height,
        state=scroll_state,
        on_scroll=Some(handler),
      )
    None =>
      scroll_view(
        body.repaint_boundary(),
        offset=scroll_offset,
        width=metrics.body_width,
        height=metrics.body_height,
        state=scroll_state,
      )
  }
  surface(
    column(
      [
        column(
          [
            text(title, width=metrics.body_width, height=30.0)
            .font(theme.typography.control)
            .foreground(theme.palette.foreground),
            text(summary, width=metrics.body_width, height=28.0)
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Start,
        ),
        scroll_body,
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    width=metrics.panel_width,
    height=metrics.panel_height,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
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
) -> @moui.View[ShowcaseMsg] {
  let offset = @moui.Point::new(
    x=0.0,
    y=max_showcase_double(0.0, self.detail_scroll.offset().y),
  )
  section_panel(
    theme,
    title,
    summary,
    body,
    metrics~,
    scroll_offset=offset,
    scroll_state=Some(self.detail_scroll),
  )
}

///|
fn showcase_panel_border(theme : @moui.Theme) -> @core.BorderStyle {
  @core.BorderStyle::new(
    brush=@core.Brush::solid(theme.palette.outline.multiply_alpha(0.82)),
    width=1.0,
  )
}

///|
fn showcase_soft_card(
  theme : @moui.Theme,
  child : @moui.View[ShowcaseMsg],
  width~ : Double,
  height~ : Double,
  padding? : Double = 0.0,
) -> @moui.View[ShowcaseMsg] {
  surface(
    child,
    width~,
    height~,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding~,
  ).border(showcase_panel_border(theme))
}

///|
fn example_preview(
  theme : @moui.Theme,
  title : String,
  child : @moui.View[ShowcaseMsg],
) -> @moui.View[ShowcaseMsg] {
  surface(
    column(
      [
        text(title, width=220.0, height=26.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        child.frame(width=470.0, height=150.0),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Start,
    ),
    width=500.0,
    height=190.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
  )
}

///|
fn ShowcaseModel::layout_tile(
  self : ShowcaseModel,
  theme : @moui.Theme,
  label : String,
) -> @moui.View[ShowcaseMsg] {
  self.layout_tile_sized(theme, label, 156.0, 40.0)
}

///|
fn ShowcaseModel::layout_tile_sized(
  self : ShowcaseModel,
  theme : @moui.Theme,
  label : String,
  width : Double,
  height : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  surface(
    row(
      [
        layout_tile_marker(theme),
        text(
          label,
          width=max_showcase_double(20.0, width - 34.0),
          height=max_showcase_double(20.0, height - 12.0),
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height~,
    background=theme.palette.surface_variant.multiply_alpha(0.48),
    corner_radius=theme.radius_scale.sm,
    padding=6.0,
  )
}

///|
fn layout_tile_marker(theme : @moui.Theme) -> @moui.View[ShowcaseMsg] {
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@moui.Size::new(width=4.0, height=22.0))
    },
    paint=frame => {
      [
        @core.DrawCommand::FillRoundedRect(
          @core.RoundedRect::new(rect=frame, radius=2.0),
          theme.palette.primary.multiply_alpha(0.72),
        ),
      ]
    },
    semantics_label="",
  )
}

///|
fn ShowcaseModel::visual_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
  card_width : Double,
  active : Bool,
  offset : Double,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let media_width = max_showcase_double(120.0, card_width - 36.0)
  let media_height = if metrics.compact { 96.0 } else { 136.0 }
  let card_height = if metrics.compact { 250.0 } else { 300.0 }
  let transition = @core.TransitionSpec::new(
    from=@core.TransitionStyle::identity()
      .with_opacity(0.66)
      .with_offset(dx=offset, dy=0.0),
    to=@core.TransitionStyle::identity()
      .with_opacity(opacity)
      .with_offset(dx=offset, dy=0.0),
    easing=@core.Easing::Linear,
  )
  let gradient = @core.Brush::linear_gradient(
    start=@moui.Point::new(x=0.0, y=0.0),
    end=@moui.Point::new(x=260.0, y=160.0),
    start_color=theme.palette.primary.multiply_alpha(0.92),
    end_color=theme.palette.surface_variant,
  )
  showcase_soft_card(
    theme,
    column(
      [
        image(
          showcase_image_source(),
          width=media_width,
          height=media_height,
          opacity~,
          corner_radius=theme.radius_scale.lg,
          fit=@core.ImageFit::Cover,
        )
        .background_brush(gradient)
        .corner_radius(theme.radius_scale.lg)
        .clip()
        .transition(spec=transition, progress=1.0),
        text(
          if active {
            "Raised card with motion"
          } else {
            "Layered card with image"
          },
          width=media_width,
          height=28.0,
        )
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        button(
          if active {
            "Settle"
          } else {
            "Animate"
          },
          on_click=ToggleActive,
          variant=@views.ButtonVariant::Primary,
          theme~,
          width=140.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    width=card_width,
    height=card_height,
    padding=theme.spacing_scale.md,
  )
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
  let entries = capability_card_entries()
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
  let summary = self.host_summary
  let rows = [
    host_capability_row(
      "Services",
      "\{summary.service_count()}/5",
      host_service_summary(summary.services),
      theme,
      inner_width,
    ),
    host_capability_row(
      "Input",
      "\{summary.input_count()}/7",
      host_input_summary(summary),
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
          summary.label + " / " + summary.backend.label(),
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
fn host_service_summary(capabilities : @host.HostServiceCapabilities) -> String {
  host_label_summary(capabilities.enabled_labels(), empty="no services")
}

///|
fn host_input_summary(summary : @host.HostCapabilitySummary) -> String {
  let labels = summary.input.enabled_labels()
  host_label_summary(labels, empty="no input")
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
fn capability_card_entries() -> Array[@render.RendererFeatureCapability] {
  let primary : Array[@render.RendererFeatureCapability] = []
  let secondary : Array[@render.RendererFeatureCapability] = []
  let complete : Array[@render.RendererFeatureCapability] = []
  for entry in @render.renderer_feature_capability_report() {
    if capability_has_partial_or_gap(entry) {
      primary.push(entry)
    } else if entry.needs_follow_up() {
      secondary.push(entry)
    } else {
      complete.push(entry)
    }
  }
  primary + secondary + complete
}

///|
fn capability_has_partial_or_gap(
  entry : @render.RendererFeatureCapability,
) -> Bool {
  entry.backends.any(capability => {
    match capability.status {
      @render.RendererFeatureStatus::Partial
      | @render.RendererFeatureStatus::Gap => true
      _ => false
    }
  })
}

///|
fn ShowcaseModel::visual_correctness_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  active : Bool,
  opacity : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let image_motion = @core.TransitionSpec::slide(
    from_offset=@moui.Point::new(x=0.0, y=0.0),
    to_offset=@moui.Point::new(x=if active { 10.0 } else { 0.0 }, y=0.0),
    easing=@core.Easing::Linear,
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
          fit=@core.ImageFit::Contain,
        ).clip(),
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity~,
          corner_radius=theme.radius_scale.sm,
          fit=@core.ImageFit::Cover,
        ).clip(),
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity=0.92,
          corner_radius=theme.radius_scale.sm,
          fit=@core.ImageFit::FitWidth,
        ).clip(),
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity=0.86,
          corner_radius=theme.radius_scale.sm,
          fit=@core.ImageFit::FitHeight,
        ).clip(),
        image(
          showcase_image_source(),
          width=48.0,
          height=50.0,
          opacity=0.78,
          corner_radius=theme.radius_scale.md,
          fit=@core.ImageFit::ScaleDown,
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
fn ShowcaseModel::shortcut_preview(
  self : ShowcaseModel,
  theme : @moui.Theme,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  surface(
    text("Keyboard: Meta+K", width=190.0, height=28.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.foreground),
    width=220.0,
    height=50.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
  ).border(showcase_panel_border(theme))
}

///|
fn ShowcaseModel::progress_preview(
  self : ShowcaseModel,
  theme : @moui.Theme,
  value : Double,
  width~ : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  surface(
    progress(
      value,
      width=max_showcase_double(80.0, width - 24.0),
      foreground=theme.palette.primary,
    ),
    width~,
    height=42.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=12.0,
  ).border(showcase_panel_border(theme))
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
      toggle_switch(
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
      constraints.constrain(@moui.Size::new(width=292.0, height=74.0))
    },
    paint=frame => {
      let inset = 12.0
      let left = frame.origin.x + inset
      let top = frame.origin.y + inset
      let bottom = frame.origin.y + frame.size.height - inset
      let mid_y = frame.origin.y + frame.size.height * 0.5
      let fill = @core.Brush::linear_gradient(
        start=@moui.Point::new(x=left, y=top),
        end=@moui.Point::new(x=left + 72.0, y=bottom),
        start_color=theme.palette.primary.multiply_alpha(0.88),
        end_color=theme.accent.multiply_alpha(0.82),
      )
      let stroke = @core.Brush::solid(
        theme.palette.foreground.multiply_alpha(0.72),
      )
      [
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=frame, radius=theme.radius_scale.md),
          @core.Brush::solid(theme.palette.surface_variant.multiply_alpha(0.42)),
        ),
        @core.DrawCommand::DrawPath(
          @core.PathSpec::new(
            verbs=[
              @core.PathVerb::MoveTo(@moui.Point::new(x=left, y=bottom)),
              @core.PathVerb::CubicTo(
                @moui.Point::new(x=left + 24.0, y=top - 4.0),
                @moui.Point::new(x=left + 58.0, y=top + 4.0),
                @moui.Point::new(x=left + 82.0, y=bottom),
              ),
              @core.PathVerb::LineTo(@moui.Point::new(x=left + 42.0, y=mid_y)),
              @core.PathVerb::Close,
            ],
            fill=Some(fill),
          ),
        ),
        @core.DrawCommand::DrawPath(
          @core.PathSpec::new(
            verbs=[
              @core.PathVerb::MoveTo(@moui.Point::new(x=left + 116.0, y=bottom)),
              @core.PathVerb::QuadTo(
                @moui.Point::new(x=left + 148.0, y=top),
                @moui.Point::new(x=left + 180.0, y=bottom),
              ),
              @core.PathVerb::CubicTo(
                @moui.Point::new(x=left + 196.0, y=mid_y),
                @moui.Point::new(x=left + 216.0, y=mid_y),
                @moui.Point::new(x=left + 236.0, y=top + 8.0),
              ),
            ],
            stroke=Some(stroke),
            stroke_width=3.0,
          ),
        ),
      ]
    },
    semantics_label="Vector path renderer demo",
  )
}

///|
fn ShowcaseModel::sparkline(
  self : ShowcaseModel,
  theme : @moui.Theme,
  value : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@moui.Size::new(width=300.0, height=34.0))
    },
    paint=frame => {
      let fill = @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + 10.0,
        width=frame.size.width * clamp_double(value, 0.0, 1.0),
        height=14.0,
      )
      [
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=frame, radius=theme.radius_scale.sm),
          @core.Brush::solid(theme.palette.surface_variant),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=fill, radius=7.0),
          @core.Brush::solid(theme.palette.primary),
        ),
      ]
    },
    semantics_label="Custom layout sparkline",
  )
}

///|
fn ShowcaseModel::dialog(
  self : ShowcaseModel,
  theme : @moui.Theme,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  @views.dialog(
    "Showcase dialog",
    content=column(
      [
        text(
          "Dialog hosts custom content, focus, and actions in one modal surface.",
          width=392.0,
          height=48.0,
        ).foreground(theme.palette.foreground),
        description_list(
          [
            description_item("Host", "view-level"),
            description_item("Focus", "app-owned"),
            description_item("Actions", "footer"),
          ],
          theme~,
          width=392.0,
          term_width=88.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    subtitle="Custom content shell",
    primary_action=Some(
      @views.StateViewAction::new(label="Close", message=HideDialog),
    ),
    secondary_action=Some(
      @views.StateViewAction::new(label="Sheet", message=ShowSheet),
    ),
    dismiss_action=Some(
      @views.StateViewAction::new(label="Dismiss", message=HideDialog),
    ),
    theme~,
    width=440.0,
    height=286.0,
  )
}

///|
fn ShowcaseModel::sheet(
  self : ShowcaseModel,
  theme : @moui.Theme,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  sheet(
    content=column(
      [
        text("Showcase sheet", width=240.0, height=30.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        text(
          "Sheet content is built with the same presentation primitives.",
          width=300.0,
          height=48.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        button(
          "Done",
          on_click=HideSheet,
          variant=@views.ButtonVariant::Primary,
          theme~,
          width=120.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    presentation_mode=@core.SheetPresentationMode::BottomSheet,
    background=theme.palette.surface,
    corner_radius=theme.radius_scale.lg,
    shadow=Some(theme.shadow_scale.md),
  )
}

///|
fn capability_row(
  entry : @render.RendererFeatureCapability,
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
      text(entry.feature.label(), width=feature_width, height=38.0)
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
  entry : @render.RendererFeatureCapability,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  let backends = @render.renderer_capability_backends()
  let row_height = if backends.length() <= 2 { 18.0 } else { 13.0 }
  let rows : Array[@moui.View[ShowcaseMsg]] = []
  for backend in backends {
    let status = entry.status_for_backend(backend)
    rows.push(
      text(
        backend.short_label() + " " + status.label(),
        width~,
        height=row_height,
      )
      .font(theme.typography.caption)
      .foreground(capability_status_color(status, theme)),
    )
  }
  column(rows, spacing=1.0, align=@views.CrossAlign::Start)
}

///|
fn capability_status_color(
  status : @render.RendererFeatureStatus,
  theme : @moui.Theme,
) -> @core.Color {
  if status.needs_follow_up() {
    theme.palette.primary
  } else {
    theme.palette.muted
  }
}
