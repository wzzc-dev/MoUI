///|
fn ShowcaseModel::devtools_inspector_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let inner_width = max_showcase_double(
    180.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let report = self.diagnostics_input.devtools
  let line_views : Array[@moui.View[ShowcaseMsg]] = []
  for line in report.report_text.split("\n") {
    line_views.push(
      text(line.to_owned(), width=inner_width, height=20.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
    )
  }
  showcase_soft_card(
    theme,
    column(
      [
        text("DevTools Inspector", width=inner_width, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        text(
          "moui_devtools InspectorReport captured from a probe runtime: runtime, view tree, layout, render, semantics",
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(report.summary_text, width=inner_width, height=22.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.primary),
        container(
          scroll_view(
            column(line_views, spacing=2.0),
            width=inner_width,
            height=240.0,
          ),
          width=inner_width,
          height=244.0,
          theme~,
        ),
        text(report.json_text, width=inner_width, height=44.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=430.0,
    padding=theme.spacing_scale.md,
  )
}
