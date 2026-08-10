///|
test "welcome grid cell widths preserve capped column counts" {
  let widths = [320.0, 500.0, 880.0, 1600.0, 2400.0]
  let gap = 8.0
  for available in widths {
    let stat_columns = welcome_grid_columns(
      available~,
      min_column_width=168.0,
      column_spacing=gap,
      max_columns=3,
    )
    let stat_width = welcome_cell_width(available, stat_columns, gap)
    let placed_stat_columns = welcome_grid_columns(
      available~,
      min_column_width=stat_width,
      column_spacing=gap,
      max_columns=64,
    )
    assert_true(placed_stat_columns == stat_columns)

    let group_columns = welcome_grid_columns(
      available~,
      min_column_width=220.0,
      column_spacing=gap,
      max_columns=4,
    )
    let group_width = welcome_cell_width(available, group_columns, gap)
    let placed_group_columns = welcome_grid_columns(
      available~,
      min_column_width=group_width,
      column_spacing=gap,
      max_columns=64,
    )
    assert_true(placed_group_columns == group_columns)
  }
}
