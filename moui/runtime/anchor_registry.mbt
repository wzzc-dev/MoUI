///|
/// A layout-pass snapshot of stable keyed anchor frames. The registry is
/// rebuilt after base layout and before presentation placement so scroll,
/// resize, and scale changes naturally produce fresh coordinates.
pub struct AnchorFrameRegistry {
  entries : Array[(String, @core.Rect)]
}

///|
pub fn AnchorFrameRegistry::new() -> AnchorFrameRegistry {
  { entries: [] }
}

///|
pub fn AnchorFrameRegistry::clear(self : AnchorFrameRegistry) -> Unit {
  self.entries.clear()
}

///|
pub fn AnchorFrameRegistry::register(
  self : AnchorFrameRegistry,
  key~ : String,
  frame~ : @core.Rect,
) -> Unit {
  for index, entry in self.entries {
    if entry.0 == key {
      self.entries[index] = (key, frame)
      return
    }
  }
  self.entries.push((key, frame))
}

///|
pub fn AnchorFrameRegistry::frame(
  self : AnchorFrameRegistry,
  key : String,
) -> @core.Rect? {
  for entry in self.entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
pub fn AnchorFrameRegistry::keys(self : AnchorFrameRegistry) -> Array[String] {
  self.entries.map(entry => entry.0)
}

///|
/// Return a detached snapshot suitable for a layout context.
pub fn AnchorFrameRegistry::snapshot(
  self : AnchorFrameRegistry,
) -> Array[(String, @core.Rect)] {
  self.entries.copy()
}

///|
fn ElementNode::collect_anchor_frames(
  self : ElementNode,
  placed : PlacedNode,
  registry : AnchorFrameRegistry,
) -> Unit {
  match self.key {
    Some(key) => registry.register(key=key.value(), frame=placed.frame)
    None => ()
  }
  for index, child in self.children {
    if index < placed.children.length() {
      child.collect_anchor_frames(placed.children[index], registry)
    }
  }
}

///|
pub fn AppRuntime::anchor_frame(self : AppRuntime, key : String) -> @core.Rect? {
  self.state.ensure_layout_tree()
  self.state.anchor_registry.frame(key)
}

///|
pub fn AppRuntime::anchor_keys(self : AppRuntime) -> Array[String] {
  self.state.ensure_layout_tree()
  self.state.anchor_registry.keys()
}
