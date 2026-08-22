///|
pub fn[Msg] data_grid_semantics(
  view : @core.View[Msg],
  row_count~ : Int,
  column_count~ : Int,
) -> @core.View[Msg] {
  view
  .semantics_role(@core.SemanticsRole::Grid)
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
  row_index~ : Int,
  row_count~ : Int,
  column_count~ : Int,
) -> @core.View[Msg] {
  view
  .semantics_role(@core.SemanticsRole::Row)
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
  row_index~ : Int,
  column_index~ : Int,
  row_count~ : Int,
  column_count~ : Int,
  selected? : Bool = false,
  read_only? : Bool = true,
) -> @core.View[Msg] {
  view
  .semantics_role(@core.SemanticsRole::Cell)
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
