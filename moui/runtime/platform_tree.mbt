///|
/// Builds the platform tree from element/layout state without invoking paint.
/// Clean subtrees reuse their immutable cached node, while a dirty route is
/// rebuilt in DFS order so host placement ordering stays stable.
fn ElementNode::platform_with_environment(
  self : ElementNode,
  placed : PlacedNode,
  environment : RenderEnvironment,
) -> PlatformNode {
  if !self.has_dirty_platform() &&
    self.platform_cache.frame == Some(placed.frame) &&
    self.platform_cache.environment == Some(environment.environment) &&
    self.platform_cache.style == Some(environment.style) {
    match self.platform_cache.node {
      Some(node) => return node
      None => ()
    }
  }
  let cache_key_matches = self.platform_cache.frame == Some(placed.frame) &&
    self.platform_cache.environment == Some(environment.environment) &&
    self.platform_cache.style == Some(environment.style)
  let placements = if !self.dirty.needs_platform && cache_key_matches {
    match self.platform_cache.node {
      Some(node) => node.placements.copy()
      None =>
        self.view_node.platform_views({
          frame: placed.frame,
          child_frames: placed.children.map(child => child.frame),
          environment: environment.environment,
          style: environment.style,
        })
    }
  } else {
    self.view_node.platform_views({
      frame: placed.frame,
      child_frames: placed.children.map(child => child.frame),
      environment: environment.environment,
      style: environment.style,
    })
  }
  let children : Array[PlatformNode] = []
  let child_environment = environment.with_child_context(self.view_node)
  for index, child in self.children {
    if index < placed.children.length() {
      children.push(
        child.platform_with_environment(
          placed.children[index],
          child_environment,
        ),
      )
    }
  }
  let node = PlatformNode::{ placements, children }
  self.dirty.needs_platform = false
  self.refresh_descendant_dirty_flags()
  self.platform_cache.frame = Some(placed.frame)
  self.platform_cache.environment = Some(environment.environment)
  self.platform_cache.style = Some(environment.style)
  self.platform_cache.node = Some(node)
  node
}

///|
fn PlatformNode::collect_placements(
  self : PlatformNode,
  output : Array[PlatformViewPlacement],
) -> Unit {
  output.append(self.placements)
  for child in self.children {
    child.collect_placements(output)
  }
}

///|
fn PlatformTree::placements(
  self : PlatformTree,
) -> Array[PlatformViewPlacement] {
  let output : Array[PlatformViewPlacement] = []
  self.root.collect_placements(output)
  output
}
