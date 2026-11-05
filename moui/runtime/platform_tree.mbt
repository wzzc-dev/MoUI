///|
/// Builds the platform tree from element/layout state without invoking paint.
/// Clean subtrees reuse their immutable cached node, while a dirty route is
/// rebuilt in DFS order so host placement ordering stays stable.
fn ElementNode::platform_with_environment(
  self : ElementNode,
  placed : PlacedNode,
  environment : RenderEnvironment,
  environment_id~ : Int32 = 0,
) -> PlatformNode {
  let env_id = if environment_id == 0 {
    environment_identity(environment.environment)
  } else {
    environment_id
  }
  if !self.has_dirty_platform() &&
    self.platform_cache.frame == Some(placed.frame) &&
    self.platform_cache.environment_id == env_id &&
    self.platform_cache.style == Some(environment.style) {
    match self.platform_cache.node {
      Some(node) => return node
      None => ()
    }
  }
  let cache_key_matches = self.platform_cache.frame == Some(placed.frame) &&
    self.platform_cache.environment_id == env_id &&
    self.platform_cache.style == Some(environment.style)
  let placements = if !self.dirty.needs_platform && cache_key_matches {
    match self.platform_cache.node {
      Some(node) => node.placements.copy()
      None =>
        self.view_node.platform_views({
          frame: platform_local_frame(placed),
          child_frames: platform_local_child_frames(placed),
          environment: environment.environment,
          style: environment.style,
        })
    }
  } else {
    self.view_node.platform_views({
      frame: platform_local_frame(placed),
      child_frames: platform_local_child_frames(placed),
      environment: environment.environment,
      style: environment.style,
    })
  }
  let children : Array[PlatformNode] = []
  let child_environment_value = self.view_node.child_environment(
    environment.environment,
  )
  let child_environment_id = self.child_environment_identity(
    child_environment_value,
    environment.environment,
    env_id,
  )
  let child_environment = environment.with_child_context(
    child_environment_value,
    self.view_node.child_style(environment.style),
    child_environment_id,
  )
  for index, child in self.children {
    if index < placed.children.length() {
      children.push(
        child.platform_with_environment(
          placed.children[index],
          child_environment,
          environment_id=child_environment_id,
        ),
      )
    }
  }
  let node = PlatformNode::{
    placements,
    frame: placed.frame,
    child_transform: placed.child_transform,
    overlay_child_indices: placed.overlay_child_indices.copy(),
    children,
  }
  self.dirty.needs_platform = false
  self.refresh_descendant_dirty_flags()
  self.platform_cache.frame = Some(placed.frame)
  self.platform_cache.environment_id = env_id
  self.platform_cache.style = Some(environment.style)
  self.platform_cache.node = Some(node)
  node
}

///|
fn PlatformNode::collect_placements(
  self : PlatformNode,
  output : Array[PlatformViewPlacement],
  node_to_screen : Transform2D,
) -> Unit {
  for placement in self.placements {
    output.push({
      ..placement,
      frame: runtime_transform_rect(node_to_screen, placement.frame),
      clip: match placement.clip {
        Some(clip) => Some(runtime_transform_rect(node_to_screen, clip))
        None => None
      },
    })
  }
  let child_content_to_screen = runtime_transform_compose(
    node_to_screen,
    self.child_transform,
  )
  for index, child in self.children {
    let child_to_screen = if self.overlay_child_indices.contains(index) {
      runtime_overlay_to_screen(child.frame)
    } else {
      runtime_transform_compose(
        child_content_to_screen,
        Transform2D::translation(
          dx=child.frame.origin.x,
          dy=child.frame.origin.y,
        ),
      )
    }
    child.collect_placements(output, child_to_screen)
  }
}

///|
fn PlatformTree::placements(
  self : PlatformTree,
) -> Array[PlatformViewPlacement] {
  let output : Array[PlatformViewPlacement] = []
  self.root.collect_placements(output, Transform2D::identity())
  output
}

///|
fn platform_local_frame(placed : PlacedNode) -> Rect {
  Rect::new(
    x=0.0,
    y=0.0,
    width=placed.frame.size.width,
    height=placed.frame.size.height,
  )
}

///|
fn platform_local_child_frames(placed : PlacedNode) -> Array[Rect] {
  let frames : Array[Rect] = []
  for index, child in placed.children {
    let frame = if placed.overlay_child_indices.contains(index) {
      child.frame
    } else {
      runtime_transform_rect(placed.child_transform, child.frame)
    }
    frames.push(frame)
  }
  frames
}
