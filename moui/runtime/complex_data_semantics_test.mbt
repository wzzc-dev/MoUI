///|
fn complex_data_semantics_node_by_role(
  snapshot : @runtime.SemanticsSnapshot,
  role : @core.SemanticsRole,
) -> @core.SemanticsNode? {
  for node in snapshot.nodes() {
    if node.role == role {
      return Some(node)
    }
  }
  None
}

///|
test "runtime commits data grid collection coordinates" {
  let root : @core.View[Unit] = @views.column([
    @views.data_grid_semantics(@views.text("grid"), row_count=8, column_count=4),
    @views.data_grid_cell_semantics(
      @views.text("cell"),
      row_index=3,
      column_index=2,
      row_count=8,
      column_count=4,
      selected=true,
      read_only=false,
    ),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=320.0, height=120.0),
  )
  let snapshot = match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(value)) => value
    _ => abort("expected full semantics snapshot")
  }
  guard complex_data_semantics_node_by_role(snapshot, @core.SemanticsRole::Grid)
    is Some(grid) else {
    fail("expected grid semantics node")
  }
  assert_eq(
    grid.collection,
    Some(@core.SemanticsCollectionInfo::new(row_count=8, column_count=4)),
  )
  guard complex_data_semantics_node_by_role(snapshot, @core.SemanticsRole::Cell)
    is Some(cell) else {
    fail("expected cell semantics node")
  }
  assert_true(cell.state.selected)
  assert_false(cell.state.read_only)
  assert_eq(
    cell.collection,
    Some(
      @core.SemanticsCollectionInfo::new(
        row_index=3,
        row_count=8,
        column_index=2,
        column_count=4,
      ),
    ),
  )
}

///|
test "table commits grid row and cell semantics" {
  let table : @core.View[Unit] = @views.table(
    [
      @views.table_column(id="name", label="Name"),
      @views.table_column(id="value", label="Value"),
    ],
    [["A", "1"], ["B", "2"]],
  )
  let runtime = @runtime.AppRuntime::new_view(
    root=table,
    size=@core.Size::new(width=320.0, height=160.0),
  )
  let snapshot = match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(value)) => value
    _ => abort("expected full semantics snapshot")
  }
  guard complex_data_semantics_node_by_role(snapshot, @core.SemanticsRole::Grid)
    is Some(grid) else {
    fail("expected table grid semantics node")
  }
  assert_eq(
    grid.collection,
    Some(@core.SemanticsCollectionInfo::new(row_count=3, column_count=2)),
  )
  inspect(
    snapshot
    .nodes()
    .filter(node => node.role == @core.SemanticsRole::Row)
    .length(),
    content="3",
  )
  inspect(
    snapshot
    .nodes()
    .filter(node => node.role == @core.SemanticsRole::Cell)
    .length(),
    content="6",
  )
}
