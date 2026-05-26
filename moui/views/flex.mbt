///|
pub fn row(
  children : Array[@core.ViewSpec],
  spacing? : Double = 0.0,
  justify? : MainAlign = MainAlign::Start,
  align? : CrossAlign = CrossAlign::Stretch,
) -> @core.ViewSpec {
  @core.ViewSpec::FlexSpec({
    key: None,
    axis: @core.Axis::Horizontal,
    spacing,
    main_axis_alignment: justify.core(),
    cross_axis_alignment: align.core(),
    children,
  })
}

///|
pub fn column(
  children : Array[@core.ViewSpec],
  spacing? : Double = 0.0,
  justify? : MainAlign = MainAlign::Start,
  align? : CrossAlign = CrossAlign::Stretch,
) -> @core.ViewSpec {
  @core.ViewSpec::FlexSpec({
    key: None,
    axis: @core.Axis::Vertical,
    spacing,
    main_axis_alignment: justify.core(),
    cross_axis_alignment: align.core(),
    children,
  })
}
