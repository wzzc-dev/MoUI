///|
pub fn padding(child : @core.ViewNode, value : Double) -> @core.ViewNode {
  @core.ViewNode::Padding({ insets: @core.Insets::all(value), child })
}

///|
pub fn padding_insets(
  child : @core.ViewNode,
  insets : @core.Insets,
) -> @core.ViewNode {
  @core.ViewNode::Padding({ insets, child })
}
