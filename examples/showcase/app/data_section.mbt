///|
priv struct ShowcaseDataRecord {
  name : String
  status : String
  owner : String
}

///|
fn showcase_data_records(ascending : Bool) -> Array[ShowcaseDataRecord] {
  let active = { name: "Project Atlas", status: "Active", owner: "Mira" }
  let review = { name: "Billing Flow", status: "Review", owner: "Noah" }
  let paused = { name: "Import Queue", status: "Paused", owner: "Iris" }
  if ascending {
    [active, paused, review]
  } else {
    [review, paused, active]
  }
}

///|
fn showcase_data_cell(
  record : ShowcaseDataRecord,
  column_id : String,
) -> String {
  if column_id == "status" {
    record.status
  } else if column_id == "owner" {
    record.owner
  } else {
    record.name
  }
}

///|
fn showcase_visible_columns(
  columns : Array[@views.TableColumn],
  visible : Array[String],
) -> Array[@views.TableColumn] {
  columns.filter(column => showcase_string_array_contains(visible, column.id()))
}

///|
fn showcase_data_table_rows(
  columns : Array[@views.TableColumn],
  ascending : Bool,
) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  for record in showcase_data_records(ascending) {
    let values : Array[String] = []
    for column in columns {
      values.push(showcase_data_cell(record, column.id()))
    }
    rows.push(values)
  }
  rows
}

///|
fn ShowcaseModel::data_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let lower_columns = showcase_grid_columns(
    metrics.body_width,
    metrics.compact,
    2,
  )
  let lower_width = showcase_grid_card_width(
    metrics.body_width,
    lower_columns,
    theme.spacing_scale.md,
  )
  self.section_panel(
    theme,
    "Data",
    "Tables, lists, pagination, selection detail, trees, avatars, and metadata views compose from existing primitives.",
    column(
      [
        self.data_table_card(theme, metrics.body_width),
        self.data_selectable_list_card(theme, metrics.body_width),
        grid(
          [
            self.data_tree_card(theme, lower_width),
            self.data_profile_card(theme, lower_width),
          ],
          columns=lower_columns,
          row_spacing=theme.spacing_scale.md,
          column_spacing=theme.spacing_scale.md,
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
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  let sort = @views.DataSortState::new(
    column=self.data_sort_column,
    ascending=self.data_sort_ascending,
  )
  let visibility = @views.ColumnVisibilityState::new(
    visible=self.data_visible_columns,
    locked=["name"],
  )
  let selection = @views.SelectionState::new(selected=["atlas", "billing"])
  let page_state = @views.PaginationState::new(
    page=self.data_page,
    page_size=3,
    total_count=10,
  ).clamped()
  let all_columns = [
    table_column(id="name", label="Name", width=150.0),
    table_column(id="status", label="Status", width=112.0),
    table_column(id="owner", label="Owner", width=132.0),
  ]
  let columns = showcase_visible_columns(all_columns, visibility.visible())
  let table_rows = showcase_data_table_rows(columns, sort.ascending())
  let inner_width = max_showcase_double(
    260.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let direction = if sort.ascending() { "asc" } else { "desc" }
  showcase_soft_card(
    theme,
    column(
      [
        text(
          "Data Table",
          role=@views.TextRole::Control,
          theme~,
          width=inner_width,
          height=28.0,
        ),
        text(
          "Data helpers: sort=\{sort.column()} \{direction}, page \{page_state.page() + 1}/\{page_state.page_count()}, selected \{selection.count()}",
          role=@views.TextRole::Caption,
          theme~,
          width=inner_width,
          height=22.0,
        ),
        data_filter_bar(
          query=self.data_filter_query,
          on_query=value => DataFilterQueryChanged(value),
          filters=[
            data_filter(
              id="active",
              label="Active",
              selected=self.data_filter_active,
              message=DataActiveFilterChanged(!self.data_filter_active),
            ),
            data_filter(
              id="review",
              label="Review",
              selected=self.data_filter_review,
              message=DataReviewFilterChanged(!self.data_filter_review),
            ),
          ],
          result_count=self.data_filter_result_count(),
          on_clear=Some(ClearDataFilters),
          theme~,
          width=inner_width,
        ),
        table(
          columns,
          table_rows,
          selected_row=if selection.contains("billing") {
            Some(if sort.ascending() { 2 } else { 0 })
          } else {
            None
          },
          sort_column=sort.column(),
          sort_ascending=sort.ascending(),
          on_sort=Some(column => DataSortChanged(column)),
          sortable_columns=["status"],
          theme~,
        ),
        column_visibility_panel(
          all_columns,
          visible=visibility.visible(),
          locked=visibility.locked(),
          on_toggle=(id, visible) => DataColumnVisibilityChanged(id, visible),
          theme~,
          width=inner_width,
        ),
        selection_toolbar(
          selected_count=selection.count(),
          total_count=3,
          actions=[
            action_item(id="archive", label="Archive", message=ToggleActive),
            action_item(id="export", label="Export", message=ToggleActive),
          ],
          on_clear=Some(ClearFilter),
          theme~,
          width=inner_width,
        ),
        pagination(
          page=page_state.page(),
          page_count=page_state.page_count(),
          on_previous=DataPreviousPage,
          on_next=DataNextPage,
          theme~,
          width=inner_width,
        ),
        detail_panel(
          "Selected row",
          [
            description_item("Project", "Billing Flow"),
            description_item("Owner", "Noah"),
          ],
          subtitle="Compact detail panel",
          theme~,
          width=inner_width,
          height=142.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=724.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::data_filter_result_count(self : ShowcaseModel) -> Int {
  if self.data_filter_query == "" &&
    !self.data_filter_active &&
    !self.data_filter_review {
    10
  } else if self.data_filter_active && self.data_filter_review {
    5
  } else if self.data_filter_review {
    2
  } else if self.data_filter_active {
    3
  } else {
    4
  }
}

///|
fn ShowcaseModel::data_selectable_list_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let inner_width = max_showcase_double(
    220.0,
    width - theme.spacing_scale.md * 2.0,
  )
  showcase_soft_card(
    theme,
    column(
      [
        text(
          "Selectable List",
          role=@views.TextRole::Control,
          theme~,
          width=inner_width,
          height=28.0,
        ),
        selectable_list(
          [
            selectable_list_item(
              id="atlas",
              title="Project Atlas",
              subtitle="Healthy pipeline",
              detail="Mira",
              message=ToggleActive,
            ),
            selectable_list_item(
              id="billing",
              title="Billing Flow",
              subtitle="Review required",
              detail="Noah",
              message=ToggleActive,
            ),
            selectable_list_item(
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
          width=inner_width,
          row_height=58.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=240.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::data_tree_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let inner_width = max_showcase_double(
    160.0,
    width - theme.spacing_scale.md * 2.0,
  )
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
          width=inner_width,
          height=28.0,
        ),
        tree_view(
          tree,
          expanded=["workspace"],
          selected="data",
          on_select=Some(route => SelectSection(route)),
          on_toggle=Some(_id => ToggleActive),
          theme~,
          width=inner_width,
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
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let inner_width = max_showcase_double(
    160.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let profile_text_width = max_showcase_double(112.0, inner_width - 56.0)
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
                  width=profile_text_width,
                  height=24.0,
                ),
                text(
                  "Product lead",
                  role=@views.TextRole::Caption,
                  theme~,
                  width=profile_text_width,
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
          width=inner_width,
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
