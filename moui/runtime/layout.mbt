///|
priv struct MeasuredNode {
  element_id : ElementId
  size : Size
  flex_weight : Double
  children : Array[MeasuredNode]
} derive(Eq, Debug, ToJson)

///|
priv struct PlacedNode {
  element_id : ElementId
  frame : Rect
  children : Array[PlacedNode]
} derive(Eq, Debug, ToJson)

///|
fn PlacedNode::to_layout_result(self : PlacedNode) -> LayoutResult {
  {
    frame: self.frame,
    children: self.children.map(child => child.to_layout_result()),
  }
}

///|
fn ElementNode::measure_with_text_system(
  self : ElementNode,
  constraints : Constraints,
  environment~ : Environment,
  style? : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem,
  anchor_frames? : Array[(String, Rect)] = [],
) -> MeasuredNode {
  if !self.has_dirty_layout() &&
    self.layout_cache.cached_measure_constraints == Some(constraints) &&
    self.layout_cache.cached_measure_environment == Some(environment) &&
    self.layout_cache.cached_measure_style == Some(style) &&
    self.layout_cache.cached_measure_anchor_frames == Some(anchor_frames) {
    match self.layout_cache.cached_measured {
      Some(measured) => {
        self.layout_cache.hit_count = self.layout_cache.hit_count + 1
        return measured
      }
      None => ()
    }
  }
  self.layout_cache.miss_count = self.layout_cache.miss_count + 1
  let child_constraints = self.view_node.child_constraints(constraints)
  let child_environment = self.view_node.child_environment(environment)
  let child_style = self.view_node.child_style(style)
  let children : Array[MeasuredNode] = []
  for child in self.children {
    children.push(
      child.measure_with_text_system(
        child_constraints,
        environment=child_environment,
        style=child_style,
        text_system~,
        anchor_frames~,
      ),
    )
  }
  let view_node_layout = self.view_node.layout({
    constraints,
    child_sizes: children.map(child => child.size),
    child_flex_weights: children.map(child => child.flex_weight),
    anchor_frames: anchor_frames.copy(),
    state: self.control.view_state,
    text_system,
    environment,
    style,
  })
  let measured = {
    element_id: self.id,
    size: constraints.constrain(view_node_layout.size),
    flex_weight: self.view_node.flex_weight(),
    children,
  }
  self.layout_cache.cached_measure_constraints = Some(constraints)
  self.layout_cache.cached_measure_environment = Some(environment)
  self.layout_cache.cached_measure_style = Some(style)
  self.layout_cache.cached_measure_anchor_frames = Some(anchor_frames)
  self.layout_cache.cached_measured = Some(measured)
  self.dirty.needs_layout = false
  self.refresh_descendant_dirty_flags()
  measured
}

///|
fn ElementNode::place_with_text_system(
  self : ElementNode,
  bounds : Rect,
  environment~ : Environment,
  style? : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem,
  layout_direction? : LayoutDirection = LayoutDirection::LeftToRight,
  anchor_frames? : Array[(String, Rect)] = [],
) -> PlacedNode {
  if !self.has_dirty_layout() &&
    self.layout_cache.cached_place_frame == Some(bounds) &&
    self.layout_cache.cached_place_environment == Some(environment) &&
    self.layout_cache.cached_place_style == Some(style) &&
    self.layout_cache.cached_place_anchor_frames == Some(anchor_frames) {
    match self.layout_cache.cached_placed {
      Some(placed) => {
        self.layout_cache.hit_count = self.layout_cache.hit_count + 1
        return placed
      }
      None => ()
    }
  }
  let constraints = Constraints::tight(bounds.size)
  let measured = self.measure_with_text_system(
    constraints,
    environment~,
    style~,
    text_system~,
    anchor_frames~,
  )
  let placed = self.place_measured_with_text_system(
    measured,
    bounds,
    environment~,
    style~,
    text_system~,
    layout_direction~,
    anchor_frames~,
  )
  self.layout_cache.cached_place_frame = Some(bounds)
  self.layout_cache.cached_place_environment = Some(environment)
  self.layout_cache.cached_place_style = Some(style)
  self.layout_cache.cached_place_anchor_frames = Some(anchor_frames)
  self.layout_cache.cached_placed = Some(placed)
  self.refresh_descendant_dirty_flags()
  placed
}

///|
fn ElementNode::place_measured_with_text_system(
  self : ElementNode,
  measured : MeasuredNode,
  frame : Rect,
  environment~ : Environment,
  style~ : ViewStyle,
  text_system~ : TextSystem,
  layout_direction~ : LayoutDirection,
  anchor_frames? : Array[(String, Rect)] = [],
) -> PlacedNode {
  let result = self.view_node.layout({
    constraints: Constraints::tight(frame.size),
    child_sizes: self.children.map(child => child.intrinsic_size(anchor_frames~)),
    child_flex_weights: measured.children.map(child => child.flex_weight),
    state: self.control.view_state,
    text_system,
    environment,
    style,
    anchor_frames: anchor_frames.copy(),
  })
  let child_frames = result.child_frames.map(child_frame => {
    child_frame.offset(dx=frame.origin.x, dy=frame.origin.y)
  })
  let child_environment = self.view_node.child_environment(environment)
  let child_style = self.view_node.child_style(style)
  let children : Array[PlacedNode] = []
  for index, child in self.children {
    if index < child_frames.length() && index < measured.children.length() {
      children.push(
        child.place_measured_with_text_system(
          measured.children[index],
          child_frames[index],
          environment=child_environment,
          style=child_style,
          text_system~,
          layout_direction~,
          anchor_frames~,
        ),
      )
    }
  }
  { element_id: self.id, frame, children }
}

///|
fn ElementNode::intrinsic_size(
  self : ElementNode,
  anchor_frames? : Array[(String, Rect)] = [],
) -> Size {
  if !self.has_dirty_layout() &&
    self.layout_cache.cached_intrinsic_anchor_frames == Some(anchor_frames) {
    match self.layout_cache.cached_intrinsic_size {
      Some(size) => return size
      None => ()
    }
    match self.layout_cache.cached_measured {
      Some(measured) => return measured.size
      None => ()
    }
  }
  let size = self.view_node.layout({
      constraints: Constraints::unbounded(),
      child_sizes: self.children.map(child => {
        child.intrinsic_size(anchor_frames~)
      }),
      child_flex_weights: self.children.map(child => {
        child.view_node.flex_weight()
      }),
      state: self.control.view_state,
      text_system: TextSystem::fallback(),
      environment: Environment::neutral(),
      style: ViewStyle::empty(),
      anchor_frames: anchor_frames.copy(),
    }).size
  self.layout_cache.cached_intrinsic_anchor_frames = Some(anchor_frames)
  self.layout_cache.cached_intrinsic_size = Some(size)
  size
}
