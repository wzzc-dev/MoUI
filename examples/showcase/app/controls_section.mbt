///|
fn ShowcaseModel::controls_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let choice_items = [
    choice_item("native", "Native"),
    choice_item("web", "Web"),
    choice_item("test", "Test"),
  ]
  self.section_panel(
    theme,
    "Controls",
    "TEA-controlled controls plus the current preview ecosystem baseline.",
    column(
      [
        control_ecosystem_baseline_card(theme, metrics.body_width),
        @views.tab_view(
          self.tab,
          [
            @views.tab_item(
              route="form",
              label="Form",
              view=column(
                [
                  grid(
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
                      toggle(
                        "Secondary toggle",
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
                  segmented_control(
                    choice_items,
                    selected=self.picker_value,
                    on_select=value => PickerSelected(value),
                    theme~,
                    width=360.0,
                  ),
                  row(
                    [
                      radio_group(
                        choice_items,
                        selected=self.picker_value,
                        on_select=value => PickerSelected(value),
                        theme~,
                      ),
                      checkbox_group(
                        choice_items,
                        selected=["native", "test"],
                        on_change=(_id, value) => FeatureEnabledChanged(value),
                        theme~,
                      ),
                    ],
                    spacing=theme.spacing_scale.xl,
                    align=@views.CrossAlign::Start,
                  ),
                  row(
                    [
                      filter_chip(
                        "Filter chip",
                        selected=self.feature_enabled,
                        on_change=value => FeatureEnabledChanged(value),
                        theme~,
                        width=132.0,
                      ),
                      choice_chip(
                        "Choice chip",
                        selected=self.secondary_enabled,
                        on_select=SecondaryEnabledChanged(true),
                        theme~,
                        width=132.0,
                      ),
                      tag("Tag", theme~, width=76.0),
                    ],
                    spacing=theme.spacing_scale.sm,
                    align=@views.CrossAlign::Center,
                  ),
                ],
                spacing=theme.spacing_scale.md,
                align=@views.CrossAlign::Start,
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
                    on_change=Some(value => SliderChanged(value)),
                  ),
                  progress(
                    self.slider_value,
                    width=300.0,
                    foreground=theme.palette.primary,
                  ),
                  @views.picker(
                    [
                      @views.picker_item("native", "Native Skia"),
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
                    mode=@views.DatePickerMode::Date,
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
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
  )
}

///|
fn control_ecosystem_baseline_card(
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  let inner_width = max_showcase_double(160.0, width - 32.0)
  container(
    column(
      [
        text("Preview Control Baseline", width=inner_width, height=26.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        text(
          "Workflow | status | public surface | evidence | preview gap",
          width=inner_width,
          height=20.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        baseline_row(
          theme, inner_width, "Forms | ready | form_workflow_bar + inputs | Showcase + Settings | app validation",
        ),
        baseline_row(
          theme, inner_width, "Navigation | ready | sidebar/tabs/route_header + RouteFocusStore | Showcase | app routes",
        ),
        baseline_row(
          theme, inner_width, "Dialogs/Menus | ready | view dialog/popover + host menu preview | Command Palette | native modal/a11y follow-up",
        ),
        baseline_row(
          theme, inner_width, "Data Views | ready | table/filter/pagination | Data Table app | app data logic",
        ),
        baseline_row(
          theme, inner_width, "Feedback | ready | toast/banner/progress | Showcase + File Importer | app queues",
        ),
        baseline_row(
          theme, inner_width, "Input/A11y | ready | focus_key/FocusScope/semantics | Interaction Lab | native adapters tracked",
        ),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=194.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
  ).border(showcase_panel_border(theme))
}

///|
fn baseline_row(
  theme : @moui.Theme,
  width : Double,
  label : String,
) -> @moui.View[ShowcaseMsg] {
  text(label, width~, height=20.0)
  .font(theme.typography.caption)
  .foreground(theme.palette.muted)
}

///|
