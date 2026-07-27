///|
pub fn[Msg] stack(children : Array[@core.View[Msg]]) -> @core.View[Msg] {
  stack_layout(children~)
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
  shows_indicator? : Bool = false,
) -> @core.View[Msg] {
  let viewport = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  match state {
    Some(scroll_state) =>
      component(context => {
        let current_offset = context.watch_scroll(scroll_state)
        scroll_container(
          child~,
          offset=current_offset,
          viewport~,
          state=Some(scroll_state),
          on_scroll~,
          shows_indicator~,
        )
      })
    None =>
      scroll_container(
        child~,
        offset~,
        viewport~,
        state=None,
        on_scroll~,
        shows_indicator~,
      )
  }
}
