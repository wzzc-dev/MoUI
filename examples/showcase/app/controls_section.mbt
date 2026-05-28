///|
fn ShowcaseModel::controls_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  section_panel(
    theme,
    "Controls",
    "All TEA-controlled controls are visible in one tabbed form.",
    @views.tab_view(
      self.tab,
      [
        @views.tab_item(
          route="form",
          label="Form",
          view=grid(
            [
              text_field(
                self.draft,
                on_input=value => DraftChanged(value),
                on_submit=Some(ToggleActive),
                placeholder="Type a label",
                variant=@views.TextFieldVariant::Outline,
                theme~,
                width=220.0,
              ),
              searchbar(
                query=self.draft,
                on_input=value => DraftChanged(value),
                placeholder="Search catalog",
                theme~,
              ),
              button(
                "Primary",
                on_click=ToggleActive,
                variant=@views.ButtonVariant::Primary,
                theme~,
                width=104.0,
              ),
              menu_button(
                "Menu",
                on_click=ShowDialog,
                variant=@views.ButtonVariant::Tonal,
                theme~,
                width=104.0,
              ),
              checkbox(
                "Checkbox",
                checked=self.feature_enabled,
                on_change=value => FeatureEnabledChanged(value),
                check_color=theme.palette.primary,
              ),
              toggle(
                "Toggle",
                self.feature_enabled,
                on_change=value => FeatureEnabledChanged(value),
                check_color=theme.palette.primary,
              ),
              toggle_switch(
                "Toggle switch",
                self.secondary_enabled,
                on_change=value => SecondaryEnabledChanged(value),
                check_color=theme.palette.primary,
              ),
              radio(
                "Radio option",
                self.secondary_enabled,
                on_change=value => SecondaryEnabledChanged(value),
                check_color=theme.palette.primary,
              ),
            ],
            columns=2,
            row_spacing=theme.spacing_scale.sm,
            column_spacing=theme.spacing_scale.md,
          ),
        ),
        @views.tab_item(
          route="values",
          label="Values",
          view=column(
            [
              @views.slider(
                self.slider_value,
                width=300.0,
                foreground=theme.palette.primary,
              ),
              progress(
                self.slider_value,
                width=300.0,
                foreground=theme.palette.primary,
              ),
              @views.picker(
                [
                  @views.picker_item("native", "Native WGPU"),
                  @views.picker_item("web", "WebGPU"),
                  @views.picker_item("test", "Test renderer"),
                ],
                selected=self.picker_value,
                on_select=value => PickerSelected(value),
                placeholder="Renderer target",
                theme~,
              ).frame(width=260.0, height=38.0),
              datepicker(
                selected=self.date_value,
                on_select=value => DateSelected(value),
                mode=@core.DatePickerMode::Date,
                placeholder="Release date",
                theme~,
              ).frame(width=260.0, height=38.0),
            ],
            spacing=theme.spacing_scale.md,
            align=@views.CrossAlign::Start,
          ),
        ),
      ],
      on_select=route => TabSelected(route),
    ),
    metrics~,
  )
}

///|
