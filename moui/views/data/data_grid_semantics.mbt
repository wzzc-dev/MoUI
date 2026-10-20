///|
pub fn[Msg] data_grid_semantics(
  view : @core.View[Msg],
  row_count~ : Int32,
  column_count~ : Int32,
) -> @core.View[Msg] {
  view
  .semantics_role(Grid)
  .semantics_collection(
    @core.SemanticsCollectionInfo::new(
      row_count=row_count.max(0),
      column_count=column_count.max(0),
    ),
  )
}

///|
pub fn[Msg] data_grid_row_semantics(
  view : @core.View[Msg],
  row_index~ : Int32,
  row_count~ : Int32,
  column_count~ : Int32,
) -> @core.View[Msg] {
  view
  .semantics_role(Row)
  .semantics_collection(
    @core.SemanticsCollectionInfo::new(
      row_index=row_index.max(0),
      row_count=row_count.max(0),
      column_count=column_count.max(0),
    ),
  )
}

///|
pub fn[Msg] data_grid_cell_semantics(
  view : @core.View[Msg],
  row_index~ : Int32,
  column_index~ : Int32,
  row_count~ : Int32,
  column_count~ : Int32,
  selected~ : Bool = false,
  read_only~ : Bool = true,
) -> @core.View[Msg] {
  view
  .semantics_role(Cell)
  .semantics_selected(selected~)
  .semantics_state(read_only~)
  .semantics_collection(
    @core.SemanticsCollectionInfo::new(
      row_index=row_index.max(0),
      row_count=row_count.max(0),
      column_index=column_index.max(0),
      column_count=column_count.max(0),
    ),
  )
}
