///|
pub fn[Msg] stack(children : Array[@core.View[Msg]]) -> @core.View[Msg] {
  @core.View::stack(children~)
}

///|
pub fn[Msg] overlay(
  base : @core.View[Msg],
  overlay : @core.View[Msg],
) -> @core.View[Msg] {
  stack([base, overlay])
}

///|
pub fn[Msg] scroll_view(
  child : @core.View[Msg],
  offset? : @core.Point = @core.Point::new(x=0.0, y=0.0),
  width? : Double,
  height? : Double,
  state? : @core.ScrollState? = None,
  on_scroll? : ((@core.Point) -> Msg)? = None,
) -> @core.View[Msg] {
  let viewport = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  @core.View::scroll(child~, offset~, viewport~, state~, on_scroll~)
}
