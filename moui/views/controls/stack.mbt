///|
/// Scroll view composes the runtime-slot-backed `scroll_container` into the
/// public entrypoint.
pub fn[Msg] scroll_view(
  child : @core.View[Msg],
  offset? : @core.Point,
  width? : Double,
  height? : Double,
  on_scroll? : ((@core.Point) -> Msg)? = None,
  request? : @core.ScrollRequest,
  shows_indicator? : Bool = false,
) -> @core.View[Msg] {
  let viewport = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  scroll_container(
    child~,
    offset?,
    viewport~,
    on_scroll~,
    request?,
    shows_indicator~,
  )
}
