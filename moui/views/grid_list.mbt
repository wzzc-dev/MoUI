///|
pub fn[Msg] grid(
  children : Array[@core.View[Msg]],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> @core.View[Msg] {
  raw_grid(children~, columns~, row_spacing~, column_spacing~)
}

///|
pub fn[Msg] list(
  children : Array[@core.View[Msg]],
  spacing? : Double = 0.0,
) -> @core.View[Msg] {
  raw_list(children~, spacing~)
}
