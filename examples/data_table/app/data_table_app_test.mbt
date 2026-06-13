///|
test "data table filters by query and team" {
  let model = DataTableModel::new().update(QueryChanged("flow"))
  let filtered = model.filtered_records()
  inspect(filtered.length(), content="1")
  inspect(filtered[0].project, content="Billing Flow")
  let team_filtered = DataTableModel::new()
    .update(TeamSelected("platform"))
    .filtered_records()
  inspect(team_filtered.length(), content="2")
  inspect(team_filtered[0].team, content="platform")
  let status_filtered = DataTableModel::new()
    .update(ToggleStatusFilter("Active"))
    .filtered_records()
  inspect(status_filtered.length(), content="2")
  inspect(status_filtered[0].status, content="Active")
  let cleared = DataTableModel::new()
    .update(QueryChanged("atlas"))
    .update(TeamSelected("experience"))
    .update(ToggleStatusFilter("Active"))
    .update(ClearFilters)
  inspect(cleared.query, content="")
  inspect(cleared.selected_team, content="all")
  inspect(cleared.selected_statuses.length(), content="0")
}

///|
test "data table sorting and paging are stable" {
  let owner_sorted = DataTableModel::new().update(SortBy(DataSortKey::Owner))
  inspect(owner_sorted.sorted_records()[0].owner, content="Ava")
  let owner_desc = owner_sorted.update(SortBy(DataSortKey::Owner))
  inspect(owner_desc.sorted_records()[0].owner, content="Ren")
  let page_two = DataTableModel::new().update(NextPage)
  inspect(page_two.pagination.page(), content="1")
  inspect(page_two.visible_records().length(), content="3")
  inspect(page_two.visible_records()[0].project, content="Import Queue")
}

///|
test "data table state transitions and tree toggle" {
  let loading = DataTableModel::new().update(SetLoading)
  assert_true(loading.status is DataStatus::Loading)
  let failed = loading.update(SetFailed("Network unavailable"))
  assert_true(failed.status is DataStatus::Failed(_))
  let ready = failed.update(SetReady)
  assert_true(ready.status is DataStatus::Ready)
  let collapsed = ready.update(ToggleTree("teams"))
  inspect(collapsed.expanded.length(), content="0")
  let hidden_priority = ready.update(ToggleColumnVisibility("priority", false))
  inspect(hidden_priority.visible_columns.visible.length(), content="3")
  let project_locked = hidden_priority.update(
    ToggleColumnVisibility("project", false),
  )
  assert_true(project_locked.visible_columns.is_visible("project"))
  let resized = ready.update(ResizeColumn("project", 260.0))
  inspect(resized.column_widths.width_for("project", 180.0), content="260")
  let clamped = ready.update(ResizeColumn("project", 24.0))
  inspect(clamped.column_widths.width_for("project", 180.0), content="86")
  let moved = ready.update(MoveColumnBefore("priority", "project"))
  inspect(moved.column_order.order[0], content="priority")
  let selected = ready.update(RowSelected(1))
  inspect(selected.selected_rows.count(), content="2")
  let cleared = selected.update(ClearSelection)
  inspect(cleared.selected_rows.count(), content="0")
  inspect(cleared.last_action, content="Selection cleared")
  let exported = selected.update(ExportSelection)
  inspect(exported.last_action, content="Export queued for 2 row(s)")
}

///|
test "data table runtime draws ready shell" {
  let commands = @app.runtime(width=1020.0, height=740.0).draw_commands()
  assert_true(has_text(commands, "Data Table"))
  assert_true(has_text(commands, "Teams"))
  assert_true(has_text(commands, "Search projects"))
  assert_true(has_text(commands, "6 results"))
  assert_true(has_text(commands, "Active"))
  assert_true(has_text(commands, "Review"))
  assert_true(has_text(commands, "Clear"))
  assert_true(has_text(commands, "Column visibility"))
  assert_true(has_text(commands, "4 of 4 columns visible"))
  assert_true(has_text(commands, "Widen Project"))
  assert_true(has_text(commands, "Priority first"))
  assert_true(has_text(commands, "Project width 180"))
  assert_true(has_text(commands, "Priority"))
  assert_true(has_text(commands, "1 of 6 selected"))
  assert_true(has_text(commands, "Archive"))
  assert_true(has_text(commands, "Export"))
  assert_true(has_text(commands, "Project ^"))
  assert_true(has_text(commands, "Audit Trail"))
  assert_true(has_text(commands, "Billing Flow"))
  assert_true(has_text(commands, "Page 1 of 2"))
  assert_true(has_text(commands, "Rows: 6"))
  assert_true(has_text(commands, "Selected: 1"))
  assert_true(has_text(commands, "Columns: 4/4"))
}

///|
test "data table runtime draws empty loading and error states" {
  let empty_commands = DataTableModel::new()
    .update(QueryChanged("zzz"))
    .runtime(width=1020.0, height=680.0)
    .draw_commands()
  assert_true(has_text(empty_commands, "No rows"))
  let loading_commands = DataTableModel::new()
    .update(SetLoading)
    .runtime(width=1020.0, height=680.0)
    .draw_commands()
  assert_true(has_text(loading_commands, "Loading data"))
  let error_commands = DataTableModel::new()
    .update(SetFailed("Network unavailable"))
    .runtime(width=1020.0, height=680.0)
    .draw_commands()
  assert_true(has_text(error_commands, "Could not load data"))
  assert_true(has_text(error_commands, "Retry"))
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
