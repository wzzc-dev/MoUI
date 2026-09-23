///|
pub fn[Msg] row(
  children : Array[@core.View[Msg]],
  spacing? : Double = 10.0,
  justify? : @style.MainAlign = Start,
  align? : @style.CrossAlign = Stretch,
) -> @core.View[Msg] {
  @common.flex_layout(
    children~,
    axis=Horizontal,
    spacing~,
    main_axis_alignment=justify.core(),
    cross_axis_alignment=align.core(),
  )
}

///|
pub fn[Msg] column(
  children : Array[@core.View[Msg]],
  spacing? : Double = 10.0,
  justify? : @style.MainAlign = Start,
  align? : @style.CrossAlign = Stretch,
) -> @core.View[Msg] {
  @common.flex_layout(
    children~,
    axis=Vertical,
    spacing~,
    main_axis_alignment=justify.core(),
    cross_axis_alignment=align.core(),
  )
}
