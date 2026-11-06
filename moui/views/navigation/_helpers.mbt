// Local helpers for navigation/: package-local layout pieces not shared
// with other view sub-packages (row/column/stack live in @style).

///|
/// A transparent overlay marker used by native platform-view hosts to expose
/// a small MoUI-rendered sibling above a native child surface.
pub fn[Msg] overlay_marker(
  width~ : Double,
  height~ : Double,
) -> @core.View[Msg] {
  @core.View::from_node(OverlayMarker::{ width, height, })
}

///|
priv struct OverlayMarker {
  width : Double
  height : Double
}

///|
impl @core.ViewNode for OverlayMarker with fn identity(_self) {
  @core.ViewIdentity::new(kind="OverlayMarker")
}

///|
impl @core.ViewNode for OverlayMarker with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
  )
}

///|
impl @core.ViewNode for OverlayMarker with fn paint(_self, ctx) {
  {
    ..@core.ViewPaintPlan::empty(),
    overlay_commands: [
      FillRect(
        // Paint commands stay in the marker's local space. The runtime applies
        // the same accumulated transform to this hoisted overlay command as to
        // the marker's screen frame.
        ctx.frame,
        @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
      ),
    ],
  }
}

///|
impl @core.ViewNode for OverlayMarker with fn semantics(_self) {
  @core.ViewSemanticsInfo::hidden()
}
