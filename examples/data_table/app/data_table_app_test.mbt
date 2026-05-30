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
}

///|
test "data table sorting and paging are stable" {
  let owner_sorted = DataTableModel::new().update(SortBy(DataSortKey::Owner))
  inspect(owner_sorted.sorted_records()[0].owner, content="Ava")
  let owner_desc = owner_sorted.update(SortBy(DataSortKey::Owner))
  inspect(owner_desc.sorted_records()[0].owner, content="Ren")
  let page_two = DataTableModel::new().update(NextPage)
  inspect(page_two.page, content="1")
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
}

///|
test "data table runtime draws ready shell" {
  let commands = @app.runtime(width=1020.0, height=680.0).draw_commands()
  assert_true(has_text(commands, "Data Table"))
  assert_true(has_text(commands, "Teams"))
  assert_true(has_text(commands, "Audit Trail"))
  assert_true(has_text(commands, "Billing Flow"))
  assert_true(has_text(commands, "Page 1 of 2"))
  assert_true(has_text(commands, "Rows: 6"))
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
