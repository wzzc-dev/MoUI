///|
pub fn[Msg] grid(
  children : Array[@core.View[Msg]],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> @core.View[Msg] {
  @core.View::primitive_grid_view(
    children~,
    columns~,
    row_spacing~,
    column_spacing~,
  )
}

///|
pub fn[Msg] list(
  children : Array[@core.View[Msg]],
  spacing? : Double = 0.0,
) -> @core.View[Msg] {
  @core.View::primitive_list_view(children~, spacing~)
}
