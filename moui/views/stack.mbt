///|
pub using @layout {stack, overlay}

///|
/// `scroll_view` stays on the root facade: it composes `@controls` scroll
/// primitives (`component_host` / `scroll_container`) and the `layout/`
/// sub-package cannot depend on `controls/` (which already depends on it).
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
      @controls.component_host(context => {
        let current_offset = context.watch_scroll(scroll_state)
        @controls.scroll_container(
          child~,
          offset=current_offset,
          viewport~,
          state=Some(scroll_state),
          on_scroll~,
          shows_indicator~,
        )
      })
    None =>
      @controls.scroll_container(
        child~,
        offset~,
        viewport~,
        state=None,
        on_scroll~,
        shows_indicator~,
      )
  }
}
