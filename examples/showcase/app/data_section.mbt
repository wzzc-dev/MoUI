///|
fn ShowcaseModel::data_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  section_panel(
    theme,
    "Data",
    "Tables, trees, avatars, and metadata views compose from existing primitives.",
    column(
      [
        self.data_table_card(theme, metrics.body_width),
        row(
          [
            self.data_tree_card(theme, metrics.body_width * 0.44),
            self.data_profile_card(theme, metrics.body_width * 0.44),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
  )
}

///|
fn ShowcaseModel::data_table_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  let columns = [
    table_column(id="name", label="Name", width=150.0),
    table_column(id="status", label="Status", width=112.0),
    table_column(id="owner", label="Owner", width=132.0),
  ]
  showcase_soft_card(
    theme,
    column(
      [
        text(
          "Data Table",
          role=@views.TextRole::Control,
          theme~,
          width=width - 32.0,
          height=28.0,
        ),
        table(
          columns,
          [
            ["Project Atlas", "Active", "Mira"],
            ["Billing Flow", "Review", "Noah"],
            ["Import Queue", "Paused", "Iris"],
          ],
          selected_row=Some(1),
          theme~,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width=430.0,
    height=194.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::data_tree_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  let tree = [
    tree_item(id="workspace", label="Workspace", children=[
      tree_item(id="forms", label="Forms"),
      tree_item(id="data", label="Data"),
    ]),
    tree_item(id="archive", label="Archive"),
  ]
  showcase_soft_card(
    theme,
    column(
      [
        text(
          "Tree View",
          role=@views.TextRole::Control,
          theme~,
          width=width - 32.0,
          height=28.0,
        ),
        tree_view(
          tree,
          expanded=["workspace"],
          selected="data",
          on_select=Some(route => SelectSection(route)),
          on_toggle=Some(_id => ToggleActive),
          theme~,
          width=width - 32.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=184.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::data_profile_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        row(
          [
            avatar("Mira Chen", theme~, size=44.0),
            column(
              [
                text(
                  "Mira Chen",
                  role=@views.TextRole::Control,
                  theme~,
                  width=180.0,
                  height=24.0,
                ),
                text(
                  "Product lead",
                  role=@views.TextRole::Caption,
                  theme~,
                  width=180.0,
                  height=22.0,
                ),
              ],
              spacing=theme.spacing_scale.xs,
              align=@views.CrossAlign::Start,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        description_list(
          [
            description_item("Team", "Experience"),
            description_item("Region", "APAC"),
            description_item("Status", "Available"),
          ],
          theme~,
          width=width - 32.0,
        ),
        avatar_group(["Mira", "Noah", "Iris", "Ava", "Kai"], theme~, size=32.0),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=184.0,
    padding=theme.spacing_scale.md,
  )
}
