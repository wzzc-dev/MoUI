// Local helpers for popover/: thin row/column/stack wrappers over the
// shared @common implementations, plus first_child_size and the
// component/scroll_view wrappers over @controls.
///|
fn first_child_size(sizes : Array[@core.Size]) -> @core.Size {
  match sizes {
    [size, ..] => size
    [] => @core.Size::new(width=0.0, height=0.0)
  }
}


fn[Msg] row(
  children : Array[@core.View[Msg]],
  spacing? : Double = 10.0,
  justify? : @style.MainAlign = @style.MainAlign::Start,
  align? : @style.CrossAlign = @style.CrossAlign::Stretch,
) -> @core.View[Msg] {
  @common.flex_layout(
    children~,
    axis=@core.Axis::Horizontal,
    spacing~,
    main_axis_alignment=justify.core(),
    cross_axis_alignment=align.core(),
  )
}

///|
fn[Msg] column(
  children : Array[@core.View[Msg]],
  spacing? : Double = 10.0,
  justify? : @style.MainAlign = @style.MainAlign::Start,
  align? : @style.CrossAlign = @style.CrossAlign::Stretch,
) -> @core.View[Msg] {
  @common.flex_layout(
    children~,
    axis=@core.Axis::Vertical,
    spacing~,
    main_axis_alignment=justify.core(),
    cross_axis_alignment=align.core(),
  )
}

// === Stack layout ===

///|

fn[Msg] stack(children : Array[@core.View[Msg]]) -> @core.View[Msg] {
  @common.stack_layout(children~)
}

// === Component + scroll_view (depend on @controls.component_host / @controls.scroll_container) ===

///|
fn[Msg] component(
  build : (@core.ComponentContext) -> @core.View[Msg],
) -> @core.View[Msg] {
  @controls.component_host(build)
}

///|
fn[Msg] scroll_view(
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
