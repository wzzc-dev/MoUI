///|
fn ShowcaseModel::diagnostics_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let card_width = if metrics.compact { metrics.body_width } else { 300.0 }
  section_panel(
    theme,
    "Diagnostics",
    "Input, text, renderer, and reusable example diagnostics stay grouped away from the main catalog.",
    grid(
      [
        self.diagnostics_route_card(
          theme,
          "Interaction Lab",
          "Tooltip, file drop, focus, gestures, variants, image lifecycle",
          "interaction-lab",
          card_width,
        ),
        self.diagnostics_route_card(
          theme,
          "Text Diagnostics",
          "CJK, bidi, emoji, wrapping, Markdown and rich text samples",
          "text-diagnostics",
          card_width,
        ),
        self.diagnostics_route_card(
          theme,
          "Advanced Rendering",
          "Layer, blend, filter, shader, path, transform and opacity commands",
          "advanced-rendering",
          card_width,
        ),
        self.diagnostics_route_card(
          theme,
          "Examples",
          "Counter and Todo reusable app patterns before dedicated examples land",
          "examples",
          card_width,
        ),
      ],
      columns=if metrics.compact { 1 } else { 2 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
  )
}

///|
fn ShowcaseModel::diagnostics_route_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  title : String,
  summary : String,
  route : String,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text(title, width=width - 32.0, height=24.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        text(summary, width=width - 32.0, height=54.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        button(
          "Open",
          on_click=SelectSection(route),
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=110.0,
          height=34.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=144.0,
    padding=theme.spacing_scale.md,
  )
}
