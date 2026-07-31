// Local helpers for controls/: thin row/column/stack wrappers over the
// shared @common implementations, plus the controls-local first_child_size.
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

///|
