///|
using @views {
  badge,
  button,
  column,
  empty_state,
  error_state,
  loading_state,
  row,
  stat_card,
  status_bar,
  surface,
  table,
  table_column,
  text,
  text_field,
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
  selected_row : Int
  expanded : Array[String]
  page : Int
  page_size : Int
  sort_key : DataSortKey
  ascending : Bool
  status : DataStatus
}

///|
pub(all) enum DataTableMsg {
  QueryChanged(String)
  TeamSelected(String)
  RowSelected(Int)
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
    selected_row: 0,
    expanded: ["teams"],
    page: 0,
    page_size: 3,
    sort_key: DataSortKey::Project,
    ascending: true,
    status: DataStatus::Ready,
  }
}

///|
pub fn DataTableModel::update(
  self : DataTableModel,
  message : DataTableMsg,
) -> DataTableModel {
  match message {
    QueryChanged(value) => { ..self, query: value, page: 0 }
    TeamSelected(value) => { ..self, selected_team: value, page: 0 }
    RowSelected(id) => { ..self, selected_row: id }
    ToggleTree(id) => { ..self, expanded: toggle_id(self.expanded, id) }
    SortBy(key) =>
      if self.sort_key == key {
        { ..self, ascending: !self.ascending, page: 0 }
      } else {
        { ..self, sort_key: key, ascending: true, page: 0 }
      }
    NextPage => { ..self, page: data_min_int(self.page + 1, self.page_count() - 1) }
    PreviousPage => { ..self, page: data_max_int(0, self.page - 1) }
    SetLoading => { ..self, status: DataStatus::Loading }
    SetFailed(message) => { ..self, status: DataStatus::Failed(message) }
    SetReady => { ..self, status: DataStatus::Ready }
  }
}

///|
pub fn update(
  model : DataTableModel,
  message : DataTableMsg,
) -> DataTableModel {
  model.update(message)
}

///|
pub fn DataTableModel::filtered_records(self : DataTableModel) -> Array[DataRecord] {
  let needle = self.query.to_lower()
  self.records.filter(record => {
    let team_match = self.selected_team == "all" || record.team == self.selected_team
    let query_match = needle == "" ||
      record.project.to_lower().contains(needle) ||
      record.owner.to_lower().contains(needle) ||
      record.status.to_lower().contains(needle) ||
      record.priority.to_lower().contains(needle)
    team_match && query_match
  })
}

///|
pub fn DataTableModel::sorted_records(self : DataTableModel) -> Array[DataRecord] {
  sort_records(self.filtered_records(), key=self.sort_key, ascending=self.ascending)
}

///|
pub fn DataTableModel::visible_records(self : DataTableModel) -> Array[DataRecord] {
  let sorted = self.sorted_records()
  let start = self.page * self.page_size
  let end = data_min_int(sorted.length(), start + self.page_size)
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
  let total = self.filtered_records().length()
  if total == 0 {
    1
  } else {
    (total + self.page_size - 1) / self.page_size
  }
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
pub fn view(model : DataTableModel) -> @core.View[DataTableMsg] {
  model.view()
}

///|
pub fn DataTableModel::view(self : DataTableModel) -> @core.View[DataTableMsg] {
  let theme = @views.light_theme()
  let shell = column(
    [
      row(
        [
          column(
            [
              text("Data Table", role=@views.TextRole::Title, theme~, width=260.0, height=34.0),
              text(
                "Filter, tree selection, pagination, and state panels.",
                role=@views.TextRole::Caption,
                theme~,
                width=420.0,
                height=24.0,
              ),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          button("Loading", on_click=SetLoading, variant=@views.ButtonVariant::Outline, theme~, width=96.0, height=36.0),
          button("Error", on_click=SetFailed("Import failed"), variant=@views.ButtonVariant::Outline, theme~, width=82.0, height=36.0),
          button("Ready", on_click=SetReady, variant=@views.ButtonVariant::Primary, theme~, width=82.0, height=36.0),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      ),
      row(
        [
          self.filter_tree(theme),
          self.data_panel(theme),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      ),
      status_bar(
        [
          "Rows: \{self.filtered_records().length()}",
          "Page: \{self.page + 1}/\{self.page_count()}",
          "Sort: " + self.sort_label(),
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
    height=620.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
pub fn DataTableApp::runtime(
  self : DataTableApp,
  width? : Double = 1020.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime(width~, height~)
}

///|
pub fn runtime(
  width? : Double = 1020.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  DataTableModel::new().runtime(width~, height~)
}

///|
pub fn DataTableModel::runtime(
  self : DataTableModel,
  width? : Double = 1020.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::simple(init=self, update~, view~),
    size=@core.Size::new(width~, height~),
  )
}

///|
fn DataTableModel::filter_tree(
  self : DataTableModel,
  theme : @core.Theme,
) -> @core.View[DataTableMsg] {
  surface(
    column(
      [
        text("Teams", role=@views.TextRole::Control, theme~, width=190.0, height=26.0),
        tree_view(
          [
            tree_item(
              id="teams",
              label="All Teams",
              children=[
                tree_item(id="experience", label="Experience"),
                tree_item(id="platform", label="Platform"),
                tree_item(id="operations", label="Operations"),
              ],
            ),
          ],
          expanded=self.expanded,
          selected=self.selected_team,
          on_select=Some(id => TeamSelected(if id == "teams" { "all" } else { id })),
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
    height=470.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn DataTableModel::data_panel(
  self : DataTableModel,
  theme : @core.Theme,
) -> @core.View[DataTableMsg] {
  surface(
    column(
      [
        row(
          [
            text_field(
              self.query,
              on_input=value => QueryChanged(value),
              placeholder="Search projects",
              variant=@views.TextFieldVariant::Outline,
              theme~,
              width=260.0,
              height=38.0,
            ),
            button("Project", on_click=SortBy(DataSortKey::Project), variant=@views.ButtonVariant::Ghost, theme~, width=88.0, height=36.0),
            button("Owner", on_click=SortBy(DataSortKey::Owner), variant=@views.ButtonVariant::Ghost, theme~, width=76.0, height=36.0),
            button("Status", on_click=SortBy(DataSortKey::Status), variant=@views.ButtonVariant::Ghost, theme~, width=82.0, height=36.0),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
        self.state_or_table(theme),
        row(
          [
            button("Previous", on_click=PreviousPage, variant=@views.ButtonVariant::Outline, theme~, width=98.0, height=36.0),
            text("Page \{self.page + 1} of \{self.page_count()}", role=@views.TextRole::Caption, theme~, width=130.0, height=28.0),
            button("Next", on_click=NextPage, variant=@views.ButtonVariant::Outline, theme~, width=82.0, height=36.0),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    width=660.0,
    height=470.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn DataTableModel::state_or_table(
  self : DataTableModel,
  theme : @core.Theme,
) -> @core.View[DataTableMsg] {
  match self.status {
    DataStatus::Loading => loading_state(title="Loading data", message="Fetching project rows.", theme~, width=600.0)
    DataStatus::Failed(message) =>
      error_state(
        "Could not load data",
        message,
        action=Some(@views.StateViewAction::new(label="Retry", message=SetReady)),
        theme~,
        width=600.0,
      )
    DataStatus::Ready => self.table_view(theme)
  }
}

///|
fn DataTableModel::table_view(
  self : DataTableModel,
  theme : @core.Theme,
) -> @core.View[DataTableMsg] {
  let records = self.visible_records()
  let columns = [
    table_column(id="project", label="Project", width=180.0),
    table_column(id="status", label="Status", width=104.0),
    table_column(id="owner", label="Owner", width=128.0),
    table_column(id="priority", label="Priority", width=110.0),
  ]
  table(
    columns,
    records.map(record => [record.project, record.status, record.owner, record.priority]),
    selected_row=selected_visible_index(records, self.selected_row),
    cell=Some((row_index, column, value) => {
      let record = records[row_index]
      let base : @core.View[DataTableMsg] = if column.id == "status" {
        badge(value, tone=status_tone(value), theme~, width=82.0, height=24.0)
      } else {
        text(value, role=@views.TextRole::Body, theme~, width=column.width - 16.0, height=30.0)
      }
      base.on_tap(RowSelected(record.id))
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
  theme : @core.Theme,
) -> @core.View[DataTableMsg] {
  let selected = match self.selected_record() {
    Some(record) => record.project + " - " + record.owner
    None => "No row selected"
  }
  stat_card(
    "Selected",
    selected,
    caption="Click a table row",
    tone=@views.FeedbackTone::Info,
    theme~,
    width=210.0,
    height=116.0,
  )
}

///|
fn sample_records() -> Array[DataRecord] {
  [
    DataRecord::new(id=0, project="Project Atlas", status="Active", owner="Mira", team="experience", priority="High"),
    DataRecord::new(id=1, project="Billing Flow", status="Review", owner="Noah", team="operations", priority="Medium"),
    DataRecord::new(id=2, project="Import Queue", status="Paused", owner="Iris", team="platform", priority="Low"),
    DataRecord::new(id=3, project="Design Tokens", status="Active", owner="Ava", team="experience", priority="Medium"),
    DataRecord::new(id=4, project="Sync Engine", status="Blocked", owner="Kai", team="platform", priority="High"),
    DataRecord::new(id=5, project="Audit Trail", status="Review", owner="Ren", team="operations", priority="Medium"),
  ]
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
  if ascending { result } else { 0 - result }
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
  if left < right { -1 } else if left > right { 1 } else { 0 }
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
  let direction = if self.ascending { "Asc" } else { "Desc" }
  match self.sort_key {
    Project => "Project " + direction
    Owner => "Owner " + direction
    Status => "Status " + direction
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

///|
fn data_min_int(left : Int, right : Int) -> Int {
  if left < right { left } else { right }
}

///|
fn data_max_int(left : Int, right : Int) -> Int {
  if left > right { left } else { right }
}
