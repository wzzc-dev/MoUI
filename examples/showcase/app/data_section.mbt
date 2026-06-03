///|
fn ShowcaseModel::data_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  self.section_panel(
    theme,
    "Data",
    "Tables, lists, pagination, selection detail, trees, avatars, and metadata views compose from existing primitives.",
    column(
      [
        self.data_table_card(theme, metrics.body_width),
        self.data_selectable_list_card(theme, metrics.body_width),
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
  let sort = @views.DataSortState::new(column="status", ascending=false)
  let visibility = @views.ColumnVisibilityState::new(
    visible=["name", "owner"],
    locked=["name"],
  )
  let selection = @views.SelectionState::new(selected=["atlas", "billing"])
  let page_state = @views.PaginationState::new(
    page=1,
    page_size=3,
    total_count=10,
  ).clamped()
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
        text(
          "Data helpers: sort=status desc, page \{page_state.page + 1}/\{page_state.page_count()}, selected \{selection.count()}",
          role=@views.TextRole::Caption,
          theme~,
          width=392.0,
          height=22.0,
        ),
        data_filter_bar(
          query="atlas",
          on_query=_value => FilterChanged("atlas"),
          filters=[
            data_filter(
              id="active",
              label="Active",
              selected=true,
              message=ToggleActive,
            ),
            data_filter(
              id="review",
              label="Review",
              selected=false,
              message=ToggleActive,
            ),
          ],
          result_count=3,
          on_clear=Some(ClearFilter),
          theme~,
          width=392.0,
        ),
        table(
          columns,
          [
            ["Project Atlas", "Active", "Mira"],
            ["Billing Flow", "Review", "Noah"],
            ["Import Queue", "Paused", "Iris"],
          ],
          selected_row=if selection.contains("billing") {
            Some(1)
          } else {
            None
          },
          on_row_select=Some(_row => ToggleActive),
          sort_column=sort.column,
          sort_ascending=sort.ascending,
          on_sort=Some(_id => ToggleActive),
          theme~,
        ),
        column_visibility_panel(
          columns,
          visible=visibility.visible,
          locked=visibility.locked,
          on_toggle=(_id, _visible) => ToggleActive,
          theme~,
          width=392.0,
        ),
        selection_toolbar(
          selected_count=selection.count(),
          total_count=3,
          actions=[
            @views.MenuItem::new(
              id="archive",
              label="Archive",
              message=ToggleActive,
            ),
            @views.MenuItem::new(
              id="export",
              label="Export",
              message=ToggleActive,
            ),
          ],
          on_clear=Some(ClearFilter),
          theme~,
          width=392.0,
        ),
        pagination(
          page=page_state.page,
          page_count=page_state.page_count(),
          on_previous=ToggleActive,
          on_next=ToggleActive,
          theme~,
          width=392.0,
        ),
        detail_panel(
          "Selected row",
          [
            description_item("Project", "Billing Flow"),
            description_item("Owner", "Noah"),
          ],
          subtitle="Compact detail panel",
          theme~,
          width=392.0,
          height=142.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width=430.0,
    height=724.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::data_selectable_list_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text(
          "Selectable List",
          role=@views.TextRole::Control,
          theme~,
          width=width - 32.0,
          height=28.0,
        ),
        selectable_list(
          [
            @views.SelectableListItem::new(
              id="atlas",
              title="Project Atlas",
              subtitle="Healthy pipeline",
              detail="Mira",
              message=ToggleActive,
            ),
            @views.SelectableListItem::new(
              id="billing",
              title="Billing Flow",
              subtitle="Review required",
              detail="Noah",
              message=ToggleActive,
            ),
            @views.SelectableListItem::new(
              id="archive",
              title="Archive Import",
              subtitle="Disabled source",
              detail="Iris",
              message=ToggleActive,
              enabled=false,
            ),
          ],
          selected="billing",
          theme~,
          width=392.0,
          row_height=58.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width=430.0,
    height=240.0,
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
