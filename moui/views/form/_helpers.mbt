// Local helpers for form/: thin row/column wrappers over the shared
// @common flex implementation.


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
