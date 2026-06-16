///|
priv struct MeasuredNode {
  element_id : ElementId
  size : Size
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
  text_system~ : TextSystem,
) -> MeasuredNode {
  if !self.dirty.needs_layout &&
    self.layout_cache.cached_measure_constraints == Some(constraints) {
    match self.layout_cache.cached_measured {
      Some(measured) => return measured
      None => ()
    }
  }
  let child_constraints = (self.widget.child_constraints)(constraints)
  let children : Array[MeasuredNode] = []
  for child in self.children {
    children.push(
      child.measure_with_text_system(
        child_constraints,
        environment~,
        text_system~,
      ),
    )
  }
  let widget_layout = (self.widget.layout)({
    constraints,
    child_sizes: children.map(child => child.size),
    text_system,
    environment,
  })
  let measured = {
    element_id: self.id,
    size: constraints.constrain(widget_layout.size),
    children,
  }
  self.layout_cache.cached_measure_constraints = Some(constraints)
  self.layout_cache.cached_measured = Some(measured)
  self.dirty.needs_layout = false
  measured
}

///|
fn ElementNode::place_with_text_system(
  self : ElementNode,
  bounds : Rect,
  environment~ : Environment,
  text_system~ : TextSystem,
  layout_direction? : LayoutDirection = LayoutDirection::LeftToRight,
) -> PlacedNode {
  if !self.dirty.needs_layout &&
    self.layout_cache.cached_place_frame == Some(bounds) {
    match self.layout_cache.cached_placed {
      Some(placed) => return placed
      None => ()
    }
  }
  let constraints = Constraints::tight(bounds.size)
  let measured = self.measure_with_text_system(
    constraints,
    environment~,
    text_system~,
  )
  let placed = self.place_measured_with_text_system(
    measured,
    bounds,
    environment~,
    text_system~,
    layout_direction~,
  )
  self.layout_cache.cached_place_frame = Some(bounds)
  self.layout_cache.cached_placed = Some(placed)
  placed
}

///|
fn ElementNode::place_measured_with_text_system(
  self : ElementNode,
  measured : MeasuredNode,
  frame : Rect,
  environment~ : Environment,
  text_system~ : TextSystem,
  layout_direction~ : LayoutDirection,
) -> PlacedNode {
  let result = (self.widget.layout)({
    constraints: Constraints::tight(frame.size),
    child_sizes: self.children.map(child => child.intrinsic_size()),
    text_system,
    environment,
  })
  let child_frames = result.child_frames.map(child_frame => {
    child_frame.offset(dx=frame.origin.x, dy=frame.origin.y)
  })
  let children : Array[PlacedNode] = []
  for index, child in self.children {
    if index < child_frames.length() && index < measured.children.length() {
      children.push(
        child.place_measured_with_text_system(
          measured.children[index],
          child_frames[index],
          environment~,
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
  let size = (self.widget.layout)({
      constraints: Constraints::unbounded(),
      child_sizes: self.children.map(child => child.intrinsic_size()),
      text_system: TextSystem::fallback(),
      environment: Environment::default(),
    }).size
  self.layout_cache.cached_intrinsic_size = Some(size)
  size
}
