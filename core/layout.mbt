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
    Padding(data) => {
      let child = measure_node(data.child, constraints.deflate(data.insets))
      child.inflate(data.insets).clamp(constraints)
    }
    Flex(data) => measure_flex(data, constraints)
  }
}

///|
pub fn layout_node(node : ViewNode, bounds : Rect) -> LayoutResult {
  match node {
    Empty | Label(_) | Button(_) => { frame: bounds, children: [] }
    Padding(data) => {
      let child_frame = bounds.inset(data.insets)
      { frame: bounds, children: [layout_node(data.child, child_frame)] }
    }
    Flex(data) => layout_flex(data, bounds)
  }
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
    let total_spacing = data.spacing * (count.to_double() - 1.0)
    let main = match data.axis {
      Horizontal =>
        max_double(0.0, bounds.size.width - total_spacing) / count.to_double()
      Vertical =>
        max_double(0.0, bounds.size.height - total_spacing) / count.to_double()
    }
    for index, child in data.children {
      let offset = index.to_double() * (main + data.spacing)
      let child_frame = match data.axis {
        Horizontal =>
          Rect::new(
            x=bounds.origin.x + offset,
            y=bounds.origin.y,
            width=main,
            height=bounds.size.height,
          )
        Vertical =>
          Rect::new(
            x=bounds.origin.x,
            y=bounds.origin.y + offset,
            width=bounds.size.width,
            height=main,
          )
      }
      children.push(layout_node(child, child_frame))
    }
  }
  { frame: bounds, children }
}
