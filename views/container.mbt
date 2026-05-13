///|
pub fn container(
  child : @core.ViewNode,
  width? : Double,
  height? : Double,
  background? : @core.Color,
  corner_radius? : Double = 0.0,
) -> @core.ViewNode {
  let size = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  @core.ViewNode::Container({ size, background, corner_radius, child })
}

///|
pub fn spacer(min_length? : Double = 0.0) -> @core.ViewNode {
  @core.ViewNode::Spacer({ min_length, })
}
