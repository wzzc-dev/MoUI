///|
using @views {
  badge,
  button,
  column,
  column_visibility_panel,
  data_filter,
  data_filter_bar,
  description_item,
  detail_panel,
  empty_state,
  error_state,
  loading_state,
  pagination,
  row,
  selection_toolbar,
  status_bar,
  surface,
  table,
  table_column,
  text,
  tree_item,
  tree_view,
}

///|
pub struct DataTableApp {
  unit : Unit
}

///|
pub(all) enum DataStatus {
  Ready
  Loading
  Failed(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DataSortKey {
  Project
  Owner
  Status
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DataRecord {
  id : Int
  project : String
  status : String
  owner : String
  team : String
  priority : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DataTableModel {
  records : Array[DataRecord]
  query : String
  selected_team : String
  selected_statuses : Array[String]
  selected_row : Int
  selected_rows : @views.SelectionState
  visible_columns : @views.ColumnVisibilityState
  column_widths : @views.ColumnWidthState
  column_order : @views.ColumnOrderState
  expanded : Array[String]
  pagination : @views.PaginationState
  sort : @views.DataSortState
  status : DataStatus
  last_action : String
}

///|
pub(all) enum DataTableMsg {
  QueryChanged(String)
  TeamSelected(String)
  ToggleStatusFilter(String)
  ClearFilters
  RowSelected(Int)
  ClearSelection
  ArchiveSelection
  ExportSelection
  ToggleColumnVisibility(String, Bool)
  ResizeColumn(String, Double)
  MoveColumnBefore(String, String)
  ToggleTree(String)
  SortBy(DataSortKey)
  NextPage
  PreviousPage
  SetLoading
  SetFailed(String)
  SetReady
}

///|
pub fn DataTableApp::new() -> DataTableApp {
  { unit: () }
}

///|
pub fn DataRecord::new(
  id~ : Int,
  project~ : String,
  status~ : String,
  owner~ : String,
  team~ : String,
  priority~ : String,
) -> DataRecord {
  { id, project, status, owner, team, priority }
}

///|
pub fn DataTableModel::new() -> DataTableModel {
  {
    records: sample_records(),
    query: "",
    selected_team: "all",
    selected_statuses: [],
    selected_row: 0,
    selected_rows: @views.SelectionState::new(selected=["0"]),
    visible_columns: @views.ColumnVisibilityState::new(
      visible=["project", "status", "owner", "priority"],
      locked=["project"],
    ),
    column_widths: @views.ColumnWidthState::new(
      widths=data_table_columns(),
      min_width=86.0,
      max_width=260.0,
    ),
    column_order: @views.ColumnOrderState::new(order=[
      "project", "status", "owner", "priority",
    ]),
    expanded: ["teams"],
    pagination: @views.PaginationState::new(page=0, page_size=3, total_count=6),
    sort: @views.DataSortState::new(column="project"),
    status: DataStatus::Ready,
    last_action: "Ready",
  }
}

///|
pub fn DataTableModel::update(
  self : DataTableModel,
  message : DataTableMsg,
) -> DataTableModel {
  match message {
    QueryChanged(value) =>
      { ..self, query: value, pagination: self.first_page() }
    TeamSelected(value) =>
      { ..self, selected_team: value, pagination: self.first_page() }
    ToggleStatusFilter(status) =>
      {
        ..self,
        selected_statuses: toggle_id(self.selected_statuses, status),
        pagination: self.first_page(),
      }
    ClearFilters =>
      {
        ..self,
        query: "",
        selected_team: "all",
        selected_statuses: [],
        pagination: self.first_page(),
      }
    RowSelected(id) =>
      {
        ..self,
        selected_row: id,
        selected_rows: self.selected_rows.toggle(id.to_string()),
        last_action: "Selected row \{id}",
      }
    ClearSelection =>
      {
        ..self,
        selected_rows: @views.SelectionState::new(),
        last_action: "Selection cleared",
      }
    ArchiveSelection =>
      {
        ..self,
        last_action: "Archive queued for \{self.selected_rows.count()} row(s)",
      }
    ExportSelection =>
      {
        ..self,
        last_action: "Export queued for \{self.selected_rows.count()} row(s)",
      }
    ToggleColumnVisibility(id, visible) =>
      { ..self, visible_columns: self.visible_columns.set_visible(id, visible) }
    ResizeColumn(id, width) =>
      {
        ..self,
        column_widths: self.column_widths.resize(id, width),
        last_action: "Resized column " + id,
      }
    MoveColumnBefore(id, before) =>
      {
        ..self,
        column_order: self.column_order.move_before(id, before),
        last_action: "Moved column " + id,
      }
    ToggleTree(id) => { ..self, expanded: toggle_id(self.expanded, id) }
    SortBy(key) =>
      {
        ..self,
        sort: self.sort.toggle(data_sort_column_id_for_key(key)),
        pagination: self.first_page(),
      }
    NextPage => { ..self, pagination: self.pagination_state().next() }
    PreviousPage => { ..self, pagination: self.pagination_state().previous() }
    SetLoading => { ..self, status: DataStatus::Loading }
    SetFailed(message) => { ..self, status: DataStatus::Failed(message) }
    SetReady => { ..self, status: DataStatus::Ready }
  }
}

///|
pub fn update(model : DataTableModel, message : DataTableMsg) -> DataTableModel {
  model.update(message)
}

///|
pub fn DataTableModel::filtered_records(
  self : DataTableModel,
) -> Array[DataRecord] {
  let needle = self.query.to_lower()
  self.records.filter(record => {
    let team_match = self.selected_team == "all" ||
      record.team == self.selected_team
    let status_match = self.selected_statuses.length() == 0 ||
      self.selected_statuses.any(status => status == record.status)
    let query_match = needle == "" ||
      record.project.to_lower().contains(needle) ||
      record.owner.to_lower().contains(needle) ||
      record.status.to_lower().contains(needle) ||
      record.priority.to_lower().contains(needle)
    team_match && status_match && query_match
  })
}

///|
pub fn DataTableModel::sorted_records(
  self : DataTableModel,
) -> Array[DataRecord] {
  sort_records(
    self.filtered_records(),
    key=data_sort_key_for_column(self.sort.column()),
    ascending=self.sort.ascending(),
  )
}

///|
pub fn DataTableModel::visible_records(
  self : DataTableModel,
) -> Array[DataRecord] {
  let sorted = self.sorted_records()
  let pagination = self.pagination_state()
  let start = pagination.start_index()
  let end = pagination.end_index()
  let rows : Array[DataRecord] = []
  if start >= sorted.length() {
    return rows
  }
  for index in start..<end {
    rows.push(sorted[index])
  }
  rows
}

///|
pub fn DataTableModel::page_count(self : DataTableModel) -> Int {
  self.pagination_state().page_count()
}

///|
fn DataTableModel::pagination_state(
  self : DataTableModel,
) -> @views.PaginationState {
  @views.PaginationState::new(
    page=self.pagination.page(),
    page_size=self.pagination.page_size(),
    total_count=self.filtered_records().length(),
  ).clamped()
}

///|
fn DataTableModel::first_page(self : DataTableModel) -> @views.PaginationState {
  @views.PaginationState::new(
    page=0,
    page_size=self.pagination.page_size(),
    total_count=self.filtered_records().length(),
  )
}

///|
pub fn DataTableModel::selected_record(self : DataTableModel) -> DataRecord? {
  for record in self.records {
    if record.id == self.selected_row {
      return Some(record)
    }
  }
  None
}

///|
pub fn view(model : DataTableModel) -> @moui.View[DataTableMsg] {
  model.view()
}

///|
pub fn DataTableModel::view(self : DataTableModel) -> @moui.View[DataTableMsg] {
  let theme = @views.light_theme()
  let shell = column(
    [
      row(
        [
          column(
            [
              text(
                "Data Table",
                role=@views.TextRole::Title,
                theme~,
                width=260.0,
                height=34.0,
              ),
              text(
                "Filter bar, column visibility, row selection, pagination, and state panels.",
                role=@views.TextRole::Caption,
                theme~,
                width=520.0,
                height=24.0,
              ),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          button(
            "Loading",
            on_click=SetLoading,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=96.0,
            height=36.0,
          ),
          button(
            "Error",
            on_click=SetFailed("Import failed"),
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=82.0,
            height=36.0,
          ),
          button(
            "Ready",
            on_click=SetReady,
            variant=@views.ButtonVariant::Primary,
            theme~,
            width=82.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      ),
      row(
        [self.filter_tree(theme), self.data_panel(theme)],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      ),
      status_bar(
        [
          "Rows: \{self.filtered_records().length()}",
          "Selected: \{self.selected_rows.count()}",
          "Columns: \{self.visible_columns.visible().length()}/4",
          "Page: \{self.pagination_state().page() + 1}/\{self.page_count()}",
          "Sort: " + self.sort_label(),
          self.last_action,
        ],
        theme~,
        width=928.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
  surface(
    shell,
    width=980.0,
    height=700.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
pub fn DataTableApp::program(
  self : DataTableApp,
) -> @moui.Program[DataTableModel, DataTableMsg] {
  ignore(self)
  program()
}

///|
pub fn program() -> @moui.Program[DataTableModel, DataTableMsg] {
  DataTableModel::new().program()
}

///|
pub fn DataTableModel::program(
  self : DataTableModel,
) -> @moui.Program[DataTableModel, DataTableMsg] {
  @moui.Program::simple(init=self, update~, view~)
}

///|
fn DataTableModel::filter_tree(
  self : DataTableModel,
  theme : @moui.Theme,
) -> @moui.View[DataTableMsg] {
  surface(
    column(
      [
        text(
          "Teams",
          role=@views.TextRole::Control,
          theme~,
          width=190.0,
          height=26.0,
        ),
        tree_view(
          [
            tree_item(id="teams", label="All Teams", children=[
              tree_item(id="experience", label="Experience"),
              tree_item(id="platform", label="Platform"),
              tree_item(id="operations", label="Operations"),
            ]),
          ],
          expanded=self.expanded,
          selected=self.selected_team,
          on_select=Some(id => {
            TeamSelected(if id == "teams" { "all" } else { id })
          }),
          on_toggle=Some(id => ToggleTree(id)),
          theme~,
          width=210.0,
        ),
        self.selected_summary(theme),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width=250.0,
    height=540.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn DataTableModel::data_panel(
  self : DataTableModel,
  theme : @moui.Theme,
) -> @moui.View[DataTableMsg] {
  let project_width = self.column_widths.width_for("project", 180.0)
  surface(
    column(
      [
        row(
          [
            data_filter_bar(
              query=self.query,
              on_query=value => QueryChanged(value),
              filters=self.data_filters(),
              result_count=self.filtered_records().length(),
              on_clear=Some(ClearFilters),
              placeholder="Search projects",
              theme~,
              width=390.0,
            ),
            column_visibility_panel(
              data_table_columns(),
              visible=self.visible_columns.visible(),
              locked=self.visible_columns.locked(),
              on_toggle=(id, visible) => ToggleColumnVisibility(id, visible),
              theme~,
              width=238.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Start,
        ),
        selection_toolbar(
          selected_count=self.selected_rows.count(),
          total_count=self.filtered_records().length(),
          actions=[
            @views.MenuItem::new(
              id="archive",
              label="Archive",
              message=ArchiveSelection,
            ),
            @views.MenuItem::new(
              id="export",
              label="Export",
              message=ExportSelection,
            ),
          ],
          on_clear=Some(ClearSelection),
          theme~,
          width=640.0,
        ),
        row(
          [
            button(
              "Widen Project",
              on_click=ResizeColumn("project", project_width + 24.0),
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=136.0,
              height=34.0,
            ),
            button(
              "Priority first",
              on_click=MoveColumnBefore("priority", "project"),
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=128.0,
              height=34.0,
            ),
            text(
              "Project width \{project_width}",
              role=@views.TextRole::Caption,
              theme~,
              width=170.0,
              height=28.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        self.state_or_table(theme),
        pagination(
          page=self.pagination_state().page(),
          page_count=self.page_count(),
          on_previous=PreviousPage,
          on_next=NextPage,
          theme~,
          width=340.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    width=660.0,
    height=540.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn DataTableModel::state_or_table(
  self : DataTableModel,
  theme : @moui.Theme,
) -> @moui.View[DataTableMsg] {
  match self.status {
    DataStatus::Loading =>
      loading_state(
        title="Loading data",
        message="Fetching project rows.",
        theme~,
        width=600.0,
      )
    DataStatus::Failed(message) =>
      error_state(
        "Could not load data",
        message,
        action=Some(
          @views.StateViewAction::new(label="Retry", message=SetReady),
        ),
        theme~,
        width=600.0,
      )
    DataStatus::Ready => self.table_view(theme)
  }
}

///|
fn DataTableModel::table_view(
  self : DataTableModel,
  theme : @moui.Theme,
) -> @moui.View[DataTableMsg] {
  let records = self.visible_records()
  let columns = self.visible_table_columns()
  table(
    columns,
    records.map(record => record_table_values(record, columns)),
    selected_row=selected_visible_index(records, self.selected_row),
    on_row_select=Some(row_index => RowSelected(records[row_index].id)),
    sort_column=self.sort_column_id(),
    sort_ascending=self.sort.ascending(),
    on_sort=Some(id => SortBy(data_sort_key_for_column(id))),
    sortable_columns=["project", "owner", "status"],
    cell=Some((row_index, column, value) => {
      ignore(row_index)
      let base : @moui.View[DataTableMsg] = if column.id() == "status" {
        badge(value, tone=status_tone(value), theme~, width=82.0, height=24.0)
      } else {
        text(
          value,
          role=@views.TextRole::Body,
          theme~,
          width=column.width() - 16.0,
          height=30.0,
        )
      }
      base
    }),
    empty=Some(
      empty_state(
        "No rows",
        "Try clearing the filter or choosing all teams.",
        theme~,
        width=600.0,
      ),
    ),
    theme~,
  )
}

///|
fn DataTableModel::selected_summary(
  self : DataTableModel,
  theme : @moui.Theme,
) -> @moui.View[DataTableMsg] {
  let items = match self.selected_record() {
    Some(record) =>
      [
        description_item("Project", record.project),
        description_item("Owner", record.owner),
        description_item("Status", record.status),
      ]
    None => []
  }
  detail_panel(
    "Selected",
    items,
    subtitle="Click a table row",
    empty=Some(
      text(
        "No row selected",
        role=@views.TextRole::Caption,
        theme~,
        width=178.0,
        height=28.0,
      ),
    ),
    theme~,
    width=210.0,
    height=188.0,
  )
}

///|
fn sample_records() -> Array[DataRecord] {
  [
    DataRecord::new(
      id=0,
      project="Project Atlas",
      status="Active",
      owner="Mira",
      team="experience",
      priority="High",
    ),
    DataRecord::new(
      id=1,
      project="Billing Flow",
      status="Review",
      owner="Noah",
      team="operations",
      priority="Medium",
    ),
    DataRecord::new(
      id=2,
      project="Import Queue",
      status="Paused",
      owner="Iris",
      team="platform",
      priority="Low",
    ),
    DataRecord::new(
      id=3,
      project="Design Tokens",
      status="Active",
      owner="Ava",
      team="experience",
      priority="Medium",
    ),
    DataRecord::new(
      id=4,
      project="Sync Engine",
      status="Blocked",
      owner="Kai",
      team="platform",
      priority="High",
    ),
    DataRecord::new(
      id=5,
      project="Audit Trail",
      status="Review",
      owner="Ren",
      team="operations",
      priority="Medium",
    ),
  ]
}

///|
fn data_table_columns() -> Array[@views.TableColumn] {
  [
    table_column(id="project", label="Project", width=180.0),
    table_column(id="status", label="Status", width=104.0),
    table_column(id="owner", label="Owner", width=128.0),
    table_column(id="priority", label="Priority", width=110.0),
  ]
}

///|
fn DataTableModel::visible_table_columns(
  self : DataTableModel,
) -> Array[@views.TableColumn] {
  let ordered_columns = self.column_order.ordered_columns(data_table_columns())
  let sized_columns = self.column_widths.apply(ordered_columns)
  let columns : Array[@views.TableColumn] = []
  for column in sized_columns {
    if self.visible_columns.is_visible(column.id()) {
      columns.push(column)
    }
  }
  if columns.length() == 0 {
    columns.push(
      table_column(
        id="project",
        label="Project",
        width=self.column_widths.width_for("project", 180.0),
      ),
    )
  }
  columns
}

///|
fn record_table_values(
  record : DataRecord,
  columns : Array[@views.TableColumn],
) -> Array[String] {
  let values : Array[String] = []
  for column in columns {
    values.push(record_table_value(record, column.id()))
  }
  values
}

///|
fn record_table_value(record : DataRecord, column_id : String) -> String {
  match column_id {
    "status" => record.status
    "owner" => record.owner
    "priority" => record.priority
    _ => record.project
  }
}

///|
fn DataTableModel::data_filters(
  self : DataTableModel,
) -> Array[@views.DataFilter[DataTableMsg]] {
  let filters : Array[@views.DataFilter[DataTableMsg]] = []
  if self.selected_team != "all" {
    filters.push(
      data_filter(
        id="team",
        label="Team: " + data_team_label(self.selected_team),
        selected=true,
        message=TeamSelected("all"),
      ),
    )
  }
  for status in data_status_filters() {
    filters.push(
      data_filter(
        id=status.to_lower(),
        label=status,
        selected=self.selected_statuses.any(selected => selected == status),
        message=ToggleStatusFilter(status),
      ),
    )
  }
  filters
}

///|
fn data_status_filters() -> Array[String] {
  ["Active", "Review", "Paused", "Blocked"]
}

///|
fn data_team_label(team : String) -> String {
  match team {
    "experience" => "Experience"
    "platform" => "Platform"
    "operations" => "Operations"
    _ => "All Teams"
  }
}

///|
fn sort_records(
  records : Array[DataRecord],
  key~ : DataSortKey,
  ascending~ : Bool,
) -> Array[DataRecord] {
  let sorted : Array[DataRecord] = []
  for record in records {
    let mut inserted = false
    let mut index = 0
    while index < sorted.length() && !inserted {
      if compare_records(record, sorted[index], key~, ascending~) < 0 {
        sorted.insert(index, record)
        inserted = true
      }
      index = index + 1
    }
    if !inserted {
      sorted.push(record)
    }
  }
  sorted
}

///|
fn compare_records(
  left : DataRecord,
  right : DataRecord,
  key~ : DataSortKey,
  ascending~ : Bool,
) -> Int {
  let left_value = record_sort_value(left, key)
  let right_value = record_sort_value(right, key)
  let result = compare_string(left_value, right_value)
  if ascending {
    result
  } else {
    0 - result
  }
}

///|
fn record_sort_value(record : DataRecord, key : DataSortKey) -> String {
  match key {
    Project => record.project
    Owner => record.owner
    Status => record.status
  }
}

///|
fn compare_string(left : String, right : String) -> Int {
  data_compare_int(sort_rank(left), sort_rank(right))
}

///|
fn sort_rank(value : String) -> Int {
  match value {
    "Audit Trail" => 10
    "Billing Flow" => 20
    "Design Tokens" => 30
    "Import Queue" => 40
    "Project Atlas" => 50
    "Sync Engine" => 60
    "Ava" => 10
    "Iris" => 20
    "Kai" => 30
    "Mira" => 40
    "Noah" => 50
    "Ren" => 60
    "Active" => 10
    "Blocked" => 20
    "Paused" => 30
    "Review" => 40
    _ => 1000
  }
}

///|
fn data_compare_int(left : Int, right : Int) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn selected_visible_index(records : Array[DataRecord], id : Int) -> Int? {
  for index, record in records {
    if record.id == id {
      return Some(index)
    }
  }
  None
}

///|
fn status_tone(status : String) -> @views.BadgeTone {
  match status {
    "Active" => @views.BadgeTone::Success
    "Review" => @views.BadgeTone::Accent
    "Paused" => @views.BadgeTone::Warning
    "Blocked" => @views.BadgeTone::Danger
    _ => @views.BadgeTone::Neutral
  }
}

///|
fn DataTableModel::sort_label(self : DataTableModel) -> String {
  let direction = if self.sort.ascending() { "Asc" } else { "Desc" }
  match data_sort_key_for_column(self.sort.column()) {
    Project => "Project " + direction
    Owner => "Owner " + direction
    Status => "Status " + direction
  }
}

///|
fn DataTableModel::sort_column_id(self : DataTableModel) -> String {
  self.sort.column()
}

///|
fn data_sort_column_id_for_key(key : DataSortKey) -> String {
  match key {
    Project => "project"
    Owner => "owner"
    Status => "status"
  }
}

///|
fn data_sort_key_for_column(id : String) -> DataSortKey {
  match id {
    "owner" => Owner
    "status" => Status
    _ => Project
  }
}

///|
fn toggle_id(values : Array[String], id : String) -> Array[String] {
  if values.any(value => value == id) {
    values.filter(value => value != id)
  } else {
    let next = values.copy()
    next.push(id)
    next
  }
}
