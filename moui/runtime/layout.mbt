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
) -> MeasuredNode {
  if !self.dirty.needs_layout &&
    self.layout_cache.cached_measure_constraints == Some(constraints) &&
    self.layout_cache.cached_measure_environment == Some(environment) &&
    self.layout_cache.cached_measure_style == Some(style) {
    match self.layout_cache.cached_measured {
      Some(measured) => return measured
      None => ()
    }
  }
  let child_constraints = (self.erased_view_node.child_constraints)(constraints)
  let child_environment = (self.erased_view_node.child_environment)(environment)
  let child_style = (self.erased_view_node.child_style)(style)
  let children : Array[MeasuredNode] = []
  for child in self.children {
    children.push(
      child.measure_with_text_system(
        child_constraints,
        environment=child_environment,
        style=child_style,
        text_system~,
      ),
    )
  }
  let view_node_layout = (self.erased_view_node.layout)({
    constraints,
    child_sizes: children.map(child => child.size),
    child_flex_weights: children.map(child => child.flex_weight),
    text_system,
    environment,
    style,
  })
  let measured = {
    element_id: self.id,
    size: constraints.constrain(view_node_layout.size),
    flex_weight: (self.erased_view_node.flex_weight)(),
    children,
  }
  self.layout_cache.cached_measure_constraints = Some(constraints)
  self.layout_cache.cached_measure_environment = Some(environment)
  self.layout_cache.cached_measure_style = Some(style)
  self.layout_cache.cached_measured = Some(measured)
  self.dirty.needs_layout = false
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
) -> PlacedNode {
  if !self.dirty.needs_layout &&
    self.layout_cache.cached_place_frame == Some(bounds) &&
    self.layout_cache.cached_place_environment == Some(environment) &&
    self.layout_cache.cached_place_style == Some(style) {
    match self.layout_cache.cached_placed {
      Some(placed) => return placed
      None => ()
    }
  }
  let constraints = Constraints::tight(bounds.size)
  let measured = self.measure_with_text_system(
    constraints,
    environment~,
    style~,
    text_system~,
  )
  let placed = self.place_measured_with_text_system(
    measured,
    bounds,
    environment~,
    style~,
    text_system~,
    layout_direction~,
  )
  self.layout_cache.cached_place_frame = Some(bounds)
  self.layout_cache.cached_place_environment = Some(environment)
  self.layout_cache.cached_place_style = Some(style)
  self.layout_cache.cached_placed = Some(placed)
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
) -> PlacedNode {
  let result = (self.erased_view_node.layout)({
    constraints: Constraints::tight(frame.size),
    child_sizes: self.children.map(child => child.intrinsic_size()),
    child_flex_weights: measured.children.map(child => child.flex_weight),
    text_system,
    environment,
    style,
  })
  let child_frames = result.child_frames.map(child_frame => {
    child_frame.offset(dx=frame.origin.x, dy=frame.origin.y)
  })
  let child_environment = (self.erased_view_node.child_environment)(environment)
  let child_style = (self.erased_view_node.child_style)(style)
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
        ),
      )
    }
  }
  { element_id: self.id, frame, children }
}

///|
fn ElementNode::intrinsic_size(self : ElementNode) -> Size {
  if !self.dirty.needs_layout {
    match self.layout_cache.cached_intrinsic_size {
      Some(size) => return size
      None => ()
    }
    match self.layout_cache.cached_measured {
      Some(measured) => return measured.size
      None => ()
    }
  }
  let size = (self.erased_view_node.layout)({
      constraints: Constraints::unbounded(),
      child_sizes: self.children.map(child => child.intrinsic_size()),
      child_flex_weights: self.children.map(child => (child.erased_view_node.flex_weight)()),
      text_system: TextSystem::fallback(),
      environment: Environment::neutral(),
      style: ViewStyle::empty(),
    }).size
  self.layout_cache.cached_intrinsic_size = Some(size)
  size
}
