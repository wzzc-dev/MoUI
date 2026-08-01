// Local helpers for navigation/: thin row/column/stack wrappers over the
// shared @common implementations, plus the navigation-local modal_scrim.

///|
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

// === Modal scrim (mirrors root view_control_helpers.mbt; kept local because
// the root helper is shared with non-navigation files like sheet.mbt) ===

///|
fn[Msg] modal_scrim(alpha~ : Double) -> @core.View[Msg] {
  @container.empty().background_brush(
    @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha)),
  )
}
