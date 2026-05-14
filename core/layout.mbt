///|
pub(all) struct LayoutResult {
  frame : Rect
  children : Array[LayoutResult]
} derive(Eq, Debug, ToJson)

///|
pub fn measure_node(node : ViewNode, constraints : Constraints) -> Size {
  match node {
    Empty => Size::new(width=0.0, height=0.0).clamp(constraints)
    Label(data) => data.size.clamp(constraints)
    Button(data) => data.size.clamp(constraints)
    TextField(data) => data.size.clamp(constraints)
    Padding(data) => {
      let child = measure_node(data.child, constraints.deflate(data.insets))
      child.inflate(data.insets).clamp(constraints)
    }
    Flex(data) => measure_flex(data, constraints)
    Container(data) =>
      match data.size {
        Some(size) => size.clamp(constraints)
        None => measure_node(data.child, constraints)
      }
    Spacer(data) =>
      Size::new(width=data.min_length, height=data.min_length).clamp(
        constraints,
      )
    Styled(data) => measure_node(data.child, constraints)
    Keyed(data) => measure_node(data.child, constraints)
    EnvironmentNode(data) => measure_node(data.child, constraints)
  }
}

///|
pub fn layout_node(node : ViewNode, bounds : Rect) -> LayoutResult {
  match node {
    Empty | Label(_) | Button(_) | TextField(_) =>
      { frame: bounds, children: [] }
    Padding(data) => {
      let child_frame = bounds.inset(data.insets)
      { frame: bounds, children: [layout_node(data.child, child_frame)] }
    }
    Flex(data) => layout_flex(data, bounds)
    Container(data) => {
      let child_frame = match data.size {
        Some(size) =>
          Rect::new(
            x=bounds.origin.x,
            y=bounds.origin.y,
            width=size.width,
            height=size.height,
          )
        None => bounds
      }
      { frame: child_frame, children: [layout_node(data.child, child_frame)] }
    }
    Spacer(_) => { frame: bounds, children: [] }
    Styled(data) => layout_node(data.child, bounds)
    Keyed(data) => layout_node(data.child, bounds)
    EnvironmentNode(data) => layout_node(data.child, bounds)
  }
}

///|
pub fn layout_spec(spec : ViewSpec, bounds : Rect) -> LayoutResult {
  mount_view_spec(spec).render(bounds).to_layout_result()
}

///|
pub fn hit_test(layout : LayoutResult, point : Point) -> Bool {
  if !layout.frame.contains(point) {
    false
  } else if layout.children.length() == 0 {
    true
  } else {
    layout.children.any(child => hit_test(child, point))
  }
}

///|
fn measure_flex(data : FlexData, constraints : Constraints) -> Size {
  let mut main = 0.0
  let mut cross = 0.0
  for index, child in data.children {
    let size = measure_node(child, Constraints::loose(constraints.max))
    match data.axis {
      Horizontal => {
        main = main + size.width
        cross = max_double(cross, size.height)
      }
      Vertical => {
        main = main + size.height
        cross = max_double(cross, size.width)
      }
    }
    if index > 0 {
      main = main + data.spacing
    }
  }
  let size = match data.axis {
    Horizontal => Size::new(width=main, height=cross)
    Vertical => Size::new(width=cross, height=main)
  }
  size.clamp(constraints)
}

///|
fn layout_flex(data : FlexData, bounds : Rect) -> LayoutResult {
  let children : Array[LayoutResult] = []
  let count = data.children.length()
  if count > 0 {
    let sizes = data.children.map(child => {
      measure_node(child, Constraints::loose(bounds.size))
    })
    let frames = flex_child_frames(
      data.axis,
      data.spacing,
      data.main_axis_alignment,
      data.cross_axis_alignment,
      sizes,
      bounds,
    )
    for index, child in data.children {
      children.push(layout_node(child, frames[index]))
    }
  }
  { frame: bounds, children }
}
