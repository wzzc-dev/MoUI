///|
/// Full-window bridge node. It owns no app state: layout fills the viewport,
/// paints the latest decoded plugin frame, and lets the generated host's event
/// closure forward input to the plugin.
pub(all) struct DevBridgeView {
  revision : Int32
}

///|
pub fn DevBridgeView::new(revision : Int32) -> DevBridgeView {
  { revision, }
}

///|
pub impl @core.ViewNode for DevBridgeView with fn identity(self) {
  @core.ViewIdentity::new(
    kind="moui-dev-bridge",
    key=Some(self.revision.to_string()),
  )
}

///|
pub impl @core.ViewNode for DevBridgeView with fn layout(self, context) {
  let _ = self
  @core.ViewLayoutResult::new(
    size=@core.Size::new(
      width=context.constraints.max.width,
      height=context.constraints.max.height,
    ),
  )
}

///|
pub impl @core.ViewNode for DevBridgeView with fn paint(self, context) {
  let _ = self
  let _ = context
  @core.ViewPaintPlan::{
    commands: frame_commands(),
    child_layers: [],
    post_commands: [],
    overlay_commands: [],
    repaint_boundary: false,
    animating: false,
  }
}
