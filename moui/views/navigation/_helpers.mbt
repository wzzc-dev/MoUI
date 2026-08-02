// Local helpers for navigation/: package-local layout pieces not shared
// with other view sub-packages (row/column/stack live in @style).

///|
fn[Msg] modal_scrim(alpha~ : Double) -> @core.View[Msg] {
  @container.empty().background_brush(
    @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha)),
  )
}
