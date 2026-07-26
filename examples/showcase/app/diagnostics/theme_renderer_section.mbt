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
          progress_preview(theme, 0.64, width=metrics.body_width),
          shortcut_preview(theme),
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
          column(
            [
              progress_preview(theme, 0.64, width=220.0),
              shortcut_preview(theme),
              sparkline(theme, 0.72),
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
fn progress_preview(
  theme : @moui.Theme,
  value : Double,
  width~ : Double,
) -> @moui.View[ShowcaseMsg] {
  container(
    progress(value, width=max_showcase_double(80.0, width - 24.0),
      foreground=theme.palette.primary),
    width~, height=42.0,
    variant=@views.ContainerVariant::Base, theme~, padding=12.0,
  ).border(showcase_card_border(theme))
}

///|
fn shortcut_preview(
  theme : @moui.Theme,
) -> @moui.View[ShowcaseMsg] {
  container(
    text("Keyboard: Meta+K", width=190.0, height=28.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
    width=220.0, height=50.0,
    variant=@views.ContainerVariant::Base, theme~,
    padding=theme.spacing_scale.md,
  ).border(showcase_card_border(theme))
}

///|
fn sparkline(
  theme : @moui.Theme,
  value : Double,
) -> @moui.View[ShowcaseMsg] {
  @views.custom_layout(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width=300.0, height=34.0))
    },
    paint=(ctx, frame) => {
      let fill = @geometry.Rect::new(
        x=frame.origin.x, y=frame.origin.y + 10.0,
        width=frame.size.width * clamp_double(value, 0.0, 1.0),
        height=14.0,
      )
      fill_rounded_rect(ctx,
        @graphics.RoundedRect::new(rect=frame, radius=theme.radius_scale.sm),
        @graphics.Brush::solid(theme.palette.surface_variant),
      )
      fill_rounded_rect(ctx,
        @graphics.RoundedRect::new(rect=fill, radius=7.0),
        @graphics.Brush::solid(theme.palette.primary),
      )
    },
    semantics_label="Sparkline demo",
  )
}
