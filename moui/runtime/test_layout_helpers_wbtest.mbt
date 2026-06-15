///|
fn hit_test(layout : LayoutResult, point : Point) -> Bool {
  @core.hit_test(layout, point)
}

///|
fn layout_spec(spec : ViewSpec, bounds : Rect) -> LayoutResult {
  mount_view_spec(spec).place(bounds).to_layout_result()
}

///|
fn layout_spec_with_text_system(
  spec : ViewSpec,
  bounds : Rect,
  text_system~ : TextSystem,
) -> LayoutResult {
  mount_view_spec(spec)
  .place_with_text_system(bounds, text_system~)
  .to_layout_result()
}

///|
fn ElementNode::measure(
  self : ElementNode,
  constraints : Constraints,
) -> MeasuredNode {
  self.measure_with_text_system(constraints, text_system=TextSystem::fallback())
}

///|
fn ElementNode::place(self : ElementNode, bounds : Rect) -> PlacedNode {
  self.place_with_text_system(bounds, text_system=TextSystem::fallback())
}

///|
fn ElementNode::render(self : ElementNode, bounds : Rect) -> RenderNode {
  self.render_with_environment(
    self.place(bounds),
    None,
    RenderEnvironment::from_environment(Environment::default()),
  )
}

///|
fn ElementTree::measure(
  self : ElementTree,
  constraints : Constraints,
) -> MeasuredNode {
  self.root.measure(constraints)
}

///|
fn ElementNode::find_keyed(self : ElementNode, key : String) -> ElementId? {
  if self.key == Some(Key::new(key)) {
    Some(self.id)
  } else {
    for child in self.children {
      match child.find_keyed(key) {
        Some(id) => return Some(id)
        None => ()
      }
    }
    None
  }
}

///|
fn ElementTree::find_keyed(self : ElementTree, key : String) -> ElementId? {
  self.root.find_keyed(key)
}

///|
fn reconcile_element(old : ElementNode, next_spec : ViewSpec) -> ElementNode {
  reconcile_element_for_runtime(old, next_spec, None, 1).node
}

///|
struct HitTestEntry {
  element_id : ElementId
  local_position : Point
  frame : Rect
} derive(Eq, Debug, ToJson)

///|
struct HitTestResult {
  path : Array[HitTestEntry]
} derive(Eq, Debug, ToJson)

///|
fn ElementNode::hit_test_path(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> HitTestResult {
  let path : Array[HitTestEntry] = []
  if self.append_hit_test_path(point, render, path) {
    { path, }
  } else {
    { path: [] }
  }
}

///|
fn ElementNode::append_hit_test_path(
  self : ElementNode,
  point : Point,
  render : RenderNode,
  path : Array[HitTestEntry],
) -> Bool {
  if !render.frame.contains(point) {
    false
  } else {
    path.push({
      element_id: self.id,
      local_position: Point::new(
        x=point.x - render.frame.origin.x,
        y=point.y - render.frame.origin.y,
      ),
      frame: render.frame,
    })
    let mut index = self.children.length() - 1
    while index >= 0 {
      if index < render.children.length() &&
        self.children[index].append_hit_test_path(
          point,
          render.children[index],
          path,
        ) {
        return true
      }
      index = index - 1
    }
    true
  }
}
