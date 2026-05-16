///|
pub fn stack(children : Array[@core.ViewSpec]) -> @core.ViewSpec {
  @core.ViewSpec::StackSpec({ key: None, children })
}

///|
pub fn overlay(
  base : @core.ViewSpec,
  overlay : @core.ViewSpec,
) -> @core.ViewSpec {
  stack([base, overlay])
}

///|
pub fn scroll_view(
  child : @core.ViewSpec,
  offset? : @core.Point = @core.Point::new(x=0.0, y=0.0),
  width? : Double,
  height? : Double,
) -> @core.ViewSpec {
  let viewport = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  @core.ViewSpec::ScrollSpec({ key: None, offset, viewport, child })
}
