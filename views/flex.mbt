///|
pub fn row(
  children : Array[@core.ViewSpec],
  spacing? : Double = 0.0,
  main_axis_alignment? : @core.MainAxisAlignment = @core.MainAxisAlignment::MainStart,
  cross_axis_alignment? : @core.CrossAxisAlignment = @core.CrossAxisAlignment::CrossStretch,
) -> @core.ViewSpec {
  @core.ViewSpec::FlexSpec({
    key: None,
    axis: @core.Axis::Horizontal,
    spacing,
    main_axis_alignment,
    cross_axis_alignment,
    children,
  })
}

///|
pub fn column(
  children : Array[@core.ViewSpec],
  spacing? : Double = 0.0,
  main_axis_alignment? : @core.MainAxisAlignment = @core.MainAxisAlignment::MainStart,
  cross_axis_alignment? : @core.CrossAxisAlignment = @core.CrossAxisAlignment::CrossStretch,
) -> @core.ViewSpec {
  @core.ViewSpec::FlexSpec({
    key: None,
    axis: @core.Axis::Vertical,
    spacing,
    main_axis_alignment,
    cross_axis_alignment,
    children,
  })
}
