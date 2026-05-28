///|
fn ShowcaseModel::navigation_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  section_panel(
    theme,
    "Navigation",
    "Navigation stack, tab view, dialog host, and sheet host are wired together.",
    column(
      [
        @views.tab_view(
          self.tab,
          [
            @views.tab_item(
              route="form",
              label="Routes",
              view=text(
                "Current route: " + self.selected_section,
                width=300.0,
                height=28.0,
              ).foreground(theme.palette.foreground),
            ),
            @views.tab_item(
              route="values",
              label="Presentation",
              view=row(
                [
                  button(
                    "Open dialog",
                    on_click=ShowDialog,
                    variant=@views.ButtonVariant::Primary,
                    theme~,
                    width=128.0,
                  ),
                  button(
                    "Open sheet",
                    on_click=ShowSheet,
                    variant=@views.ButtonVariant::Outline,
                    theme~,
                    width=128.0,
                  ),
                ],
                spacing=theme.spacing_scale.sm,
              ),
            ),
          ],
          on_select=route => TabSelected(route),
        ),
        text(
          "Dialog host and sheet host wrap the whole Showcase shell.",
          width=360.0,
          height=28.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
  )
}

///|
