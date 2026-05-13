///|
pub fn row(
  children : Array[@core.ViewNode],
  spacing? : Double = 0.0,
  main_axis_alignment? : @core.MainAxisAlignment = @core.MainAxisAlignment::MainStart,
  cross_axis_alignment? : @core.CrossAxisAlignment = @core.CrossAxisAlignment::CrossStretch,
) -> @core.ViewNode {
  @core.ViewNode::Flex({
    axis: @core.Axis::Horizontal,
    spacing,
    main_axis_alignment,
    cross_axis_alignment,
    children,
  })
}

///|
pub fn column(
  children : Array[@core.ViewNode],
  spacing? : Double = 0.0,
  main_axis_alignment? : @core.MainAxisAlignment = @core.MainAxisAlignment::MainStart,
  cross_axis_alignment? : @core.CrossAxisAlignment = @core.CrossAxisAlignment::CrossStretch,
) -> @core.ViewNode {
  @core.ViewNode::Flex({
    axis: @core.Axis::Vertical,
    spacing,
    main_axis_alignment,
    cross_axis_alignment,
    children,
  })
}
