///|
pub fn[Msg] row(
  children : Array[@core.View[Msg]],
  spacing? : Double = 0.0,
  justify? : MainAlign = MainAlign::Start,
  align? : CrossAlign = CrossAlign::Stretch,
) -> @core.View[Msg] {
  @core.View::flex(
    children~,
    axis=@core.Axis::Horizontal,
    spacing~,
    main_axis_alignment=justify.core(),
    cross_axis_alignment=align.core(),
  )
}

///|
pub fn[Msg] column(
  children : Array[@core.View[Msg]],
  spacing? : Double = 0.0,
  justify? : MainAlign = MainAlign::Start,
  align? : CrossAlign = CrossAlign::Stretch,
) -> @core.View[Msg] {
  @core.View::flex(
    children~,
    axis=@core.Axis::Vertical,
    spacing~,
    main_axis_alignment=justify.core(),
    cross_axis_alignment=align.core(),
  )
}
