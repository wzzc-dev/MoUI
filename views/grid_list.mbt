///|
pub fn grid(
  children : Array[@core.ViewSpec],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> @core.ViewSpec {
  @core.ViewSpec::GridSpec({
    key: None,
    columns,
    row_spacing,
    column_spacing,
    children,
  })
}

///|
pub fn list(
  children : Array[@core.ViewSpec],
  spacing? : Double = 0.0,
) -> @core.ViewSpec {
  @core.ViewSpec::ListSpec({ key: None, spacing, children })
}
