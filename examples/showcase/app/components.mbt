///|
fn section_panel(
  theme : @core.Theme,
  title : String,
  summary : String,
  body : @core.ViewSpec,
  metrics~ : ShowcaseMetrics,
) -> @core.ViewSpec {
  @views.surface(
    @views.column(
      [
        @views.column(
          [
            @views.text(title, width=metrics.body_width, height=30.0)
            .font(theme.typography.control)
            .foreground(theme.palette.foreground),
            @views.text(summary, width=metrics.body_width, height=28.0)
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
          ],
          spacing=theme.spacing_scale.xs,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
        @views.scroll_view(
          body,
          width=metrics.body_width,
          height=metrics.body_height,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=metrics.panel_width,
    height=metrics.panel_height,
    style=showcase_panel_style(theme),
  )
}

///|
fn example_preview(
  theme : @core.Theme,
  title : String,
  child : @core.ViewSpec,
) -> @core.ViewSpec {
  @views.surface(
    @views.column(
      [
        @views.text(title, width=220.0, height=26.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        child.frame(width=470.0, height=150.0),
      ],
      spacing=theme.spacing_scale.xs,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=500.0,
    height=190.0,
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn ShowcaseApp::layout_tile(
  self : ShowcaseApp,
  theme : @core.Theme,
  label : String,
) -> @core.ViewSpec {
  ignore(self)
  @views.surface(
    @views.text(label, width=120.0, height=24.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.foreground),
    width=132.0,
    height=36.0,
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn ShowcaseApp::visual_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
  active : Bool,
  offset : Double,
  opacity : Double,
) -> @core.ViewSpec {
  let card_width = if metrics.compact && metrics.body_width >= 448.0 {
    212.0
  } else if metrics.compact {
    min_showcase_double(metrics.body_width, 320.0)
  } else {
    284.0
  }
  let media_width = max_showcase_double(120.0, card_width - 36.0)
  let gradient = @core.Brush::linear_gradient(
    start=@core.Point::new(x=0.0, y=0.0),
    end=@core.Point::new(x=260.0, y=160.0),
    start_color=theme.palette.primary.multiply_alpha(0.92),
    end_color=theme.palette.surface_variant,
  )
  @views.surface(
    @views.column(
      [
        @views.image(
          showcase_image_source(),
          width=media_width,
          height=96.0,
          opacity~,
          corner_radius=theme.radius_scale.lg,
          fit=@core.ImageFit::Cover,
        )
        .background_brush(gradient)
        .corner_radius(theme.radius_scale.lg)
        .clip()
        .opacity(opacity)
        .offset(dx=offset, dy=0.0),
        @views.text(
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
        @views.button(
          if active {
            "Settle"
          } else {
            "Animate"
          },
          on_click=() => self.toggle_active(),
          style=@core.ButtonStyle::filled(theme~),
          width=140.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=card_width,
    height=250.0,
    style=showcase_panel_style(theme),
  )
}

///|
fn ShowcaseApp::capability_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @core.ViewSpec {
  ignore(self)
  let inner_width = max_showcase_double(
    120.0,
    width - theme.spacing_scale.lg * 2.0,
  )
  let list_height = max_showcase_double(56.0, height - 78.0)
  let rows : Array[@core.ViewSpec] = []
  let visible_limit = max_showcase_int(1, (list_height / 24.0).to_int())
  let mut visible_count = 0
  for entry in @render.renderer_feature_capability_report() {
    if visible_count < visible_limit {
      rows.push(capability_row(entry, theme))
      visible_count = visible_count + 1
    }
  }
  @views.surface(
    @views.column(
      [
        @views.text("Renderer capability", width=inner_width, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.scroll_view(
          @views.column(
            rows,
            spacing=theme.spacing_scale.xs,
            cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
          ),
          width=inner_width,
          height=list_height,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width~,
    height~,
    style=showcase_panel_style(theme),
  )
}

///|
fn ShowcaseApp::visual_correctness_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  active : Bool,
  opacity : Double,
) -> @core.ViewSpec {
  ignore(self)
  @views.surface(
    @views.row(
      [
        @views.image(
          showcase_image_source(),
          width=82.0,
          height=50.0,
          opacity=1.0,
          corner_radius=theme.radius_scale.sm,
          fit=@core.ImageFit::Contain,
        ).clip(),
        @views.image(
          showcase_image_source(),
          width=82.0,
          height=50.0,
          opacity~,
          corner_radius=theme.radius_scale.sm,
          fit=@core.ImageFit::Cover,
        ).clip(),
        @views.image(
          showcase_image_source(),
          width=82.0,
          height=50.0,
          opacity=0.78,
          corner_radius=theme.radius_scale.md,
          fit=@core.ImageFit::Cover,
        )
        .clip()
        .scale(sx=0.92, sy=0.92)
        .offset(dx=if active { 10.0 } else { 0.0 }, dy=0.0),
      ],
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
    width=292.0,
    height=74.0,
    style=showcase_raised_demo_style(theme),
  )
}

///|
fn ShowcaseApp::shortcut_preview(
  self : ShowcaseApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  ignore(self)
  @views.surface(
    @views.text("Keyboard: Meta+K", width=190.0, height=28.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.foreground),
    width=220.0,
    height=50.0,
    style=showcase_panel_style(theme),
  )
}

///|
fn ShowcaseApp::theme_helpers(
  self : ShowcaseApp,
  theme : @core.Theme,
  enabled : @core.Binding[Bool],
  active : Bool,
  opacity : Double,
) -> @core.ViewSpec {
  @views.column(
    [
      @views.text("Theme helpers", width=220.0, height=28.0)
      .font(theme.typography.control)
      .foreground(theme.palette.foreground),
      @views.toggle_switch(
        "Environment enabled",
        enabled,
        foreground=theme.palette.foreground,
        check_color=theme.palette.primary,
      ),
      @views.button(
        "Switch scheme",
        on_click=() => self.toggle_scheme(),
        style=@core.ButtonStyle::outline(theme~),
        width=160.0,
      ),
      self.visual_correctness_card(theme, active, opacity),
    ],
    spacing=theme.spacing_scale.md,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
}

///|
fn ShowcaseApp::sparkline(
  self : ShowcaseApp,
  theme : @core.Theme,
  value : Double,
) -> @core.ViewSpec {
  ignore(self)
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@core.Size::new(width=300.0, height=34.0))
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
fn ShowcaseApp::dialog(
  self : ShowcaseApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  @views.column(
    [
      @views.text("Showcase dialog", width=240.0, height=30.0)
      .font(theme.typography.control)
      .foreground(theme.palette.foreground),
      @views.text(
        "Dialogs, shortcuts, and semantics share the same ViewSpec tree.",
        width=280.0,
        height=52.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      @views.button(
        "Close",
        on_click=() => self.hide_dialog(),
        style=@core.ButtonStyle::filled(theme~),
        width=120.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
}

///|
fn ShowcaseApp::sheet(
  self : ShowcaseApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  @views.sheet(
    content=@views.column(
      [
        @views.text("Showcase sheet", width=240.0, height=30.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.text(
          "Sheet content is built with the same presentation primitives.",
          width=300.0,
          height=48.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        @views.button(
          "Done",
          on_click=() => self.hide_sheet(),
          style=@core.ButtonStyle::filled(theme~),
          width=120.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    presentation_mode=@core.SheetPresentationMode::BottomSheet,
    background=@core.Brush::solid(theme.palette.surface),
    corner_radius=theme.radius_scale.lg,
    shadow=Some(theme.shadow_scale.md),
  )
}

///|
fn capability_row(
  entry : @render.RendererFeatureCapability,
  theme : @core.Theme,
) -> @core.ViewSpec {
  let status = capability_status_label(entry)
  @views.row(
    [
      @views.text(entry.feature.label(), width=92.0, height=22.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
      @views.text(status, width=112.0, height=22.0)
      .font(theme.typography.caption)
      .foreground(capability_status_color(entry, theme)),
    ],
    spacing=theme.spacing_scale.xs,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
  )
}

///|
fn capability_status_label(entry : @render.RendererFeatureCapability) -> String {
  if entry.native_status == entry.web_status {
    entry.native_status.label()
  } else {
    "native " +
    entry.native_status.label() +
    " / web " +
    entry.web_status.label()
  }
}

///|
fn capability_status_color(
  entry : @render.RendererFeatureCapability,
  theme : @core.Theme,
) -> @core.Color {
  if entry.native_status.needs_follow_up() || entry.web_status.needs_follow_up() {
    theme.palette.primary
  } else {
    theme.palette.muted
  }
}
