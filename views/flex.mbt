///|
pub fn row(
  children : Array[@core.ViewNode],
  spacing? : Double = 0.0,
) -> @core.ViewNode {
  @core.ViewNode::Flex({ axis: @core.Axis::Horizontal, spacing, children })
}

///|
pub fn column(
  children : Array[@core.ViewNode],
  spacing? : Double = 0.0,
) -> @core.ViewNode {
  @core.ViewNode::Flex({ axis: @core.Axis::Vertical, spacing, children })
}
