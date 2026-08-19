// Local helpers for navigation/: package-local layout pieces not shared
// with other view sub-packages (row/column/stack live in @style).

///|
fn[Msg] modal_scrim(alpha~ : Double) -> @core.View[Msg] {
  @core.View::from_node(ModalScrim::{ alpha, })
}

/// A transparent overlay marker used by native platform-view hosts to expose
/// a small MoUI-rendered sibling above a native child surface.
pub fn[Msg] overlay_marker(width~ : Double, height~ : Double) -> @core.View[Msg] {
  @core.View::from_node(OverlayMarker::{ width, height })
}

///|
priv struct OverlayMarker {
  width : Double
  height : Double
}

///|
impl @core.ViewNode for OverlayMarker with fn identity(_self) {
  @core.ViewIdentity::new(kind="OverlayMarker", key=Some("{self.width}x{self.height}"))
}

///|
impl @core.ViewNode for OverlayMarker with fn declaration(self) {
  @common.view_paint_declaration(@core.DeclarationKey::record(type_tag="OverlayMarker", fields=[
    ("width", @core.DeclarationKey::double(self.width)),
    ("height", @core.DeclarationKey::double(self.height)),
  ]))
}

///|
impl @core.ViewNode for OverlayMarker with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(@core.Size::new(width=self.width, height=self.height)))
}

///|
impl @core.ViewNode for OverlayMarker with fn paint(_self, ctx) {
  {
    ..@core.ViewPaintPlan::empty(),
    overlay_commands: [@core.DrawCommand::FillRect(
      // Paint commands use the runtime's absolute frame. Keeping the marker
      // in local coordinates would expose the wrong native WebView region
      // whenever the marker is nested in an aligned/offset overlay.
      ctx.frame,
      @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
    )],
  }
}

///|
impl @core.ViewNode for OverlayMarker with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(composition=@core.SemanticsComposition::Hidden)
}

///|
priv struct ModalScrim {
  alpha : Double
}

///|
impl @core.ViewNode for ModalScrim with fn identity(_self) {
  @core.ViewIdentity::new(kind="ModalScrim")
}

///|
impl @core.ViewNode for ModalScrim with fn declaration(self) {
  @common.view_paint_declaration(@core.DeclarationKey::double(self.alpha))
}

///|
impl @core.ViewNode for ModalScrim with fn layout(_self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(@core.Size::new(width=0.0, height=0.0)),
  )
}

///|
impl @core.ViewNode for ModalScrim with fn paint(self, ctx) {
  {
    ..@core.ViewPaintPlan::empty(),
    commands: [
      @core.DrawCommand::FillRect(
        ctx.frame,
        @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=self.alpha),
      ),
    ],
    // Overlay commands are collected after ordinary child paint. Keep the
    // visible scrim in normal order so the dialog stays undimmed, and use a
    // transparent full-frame marker only to activate native sibling overlay.
    overlay_commands: [
      @core.DrawCommand::FillRect(
        ctx.frame,
        @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
      ),
    ],
  }
}

///|
impl @core.ViewNode for ModalScrim with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}
