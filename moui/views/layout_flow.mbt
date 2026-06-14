///|
pub fn[Msg] wrap(
  children : Array[@core.View[Msg]],
  width? : Double = 320.0,
  spacing? : Double = 8.0,
  row_spacing? : Double = 8.0,
) -> @core.View[Msg] {
  flow(children, width~, spacing~, row_spacing~)
}

///|
pub fn[Msg] flow(
  children : Array[@core.View[Msg]],
  width? : Double = 320.0,
  spacing? : Double = 8.0,
  row_spacing? : Double = 8.0,
) -> @core.View[Msg] {
  custom_children_layout(
    children~,
    measure=ctx => {
      flow_measure(
        ctx.child_sizes,
        width,
        spacing,
        row_spacing,
        ctx.constraints,
      )
    },
    place=ctx => {
      flow_place(
        ctx.child_sizes,
        ctx.frame,
        width,
        spacing,
        row_spacing,
        ctx.layout_direction,
      )
    },
    semantics_label="Flow layout",
  )
}

///|
fn flow_measure(
  sizes : Array[@core.Size],
  width : Double,
  spacing : Double,
  row_spacing : Double,
  constraints : @core.Constraints,
) -> @core.Size {
  let measured = flow_size(
    sizes,
    available_width(width, constraints),
    spacing,
    row_spacing,
  )
  constraints.constrain(measured)
}

///|
fn flow_place(
  sizes : Array[@core.Size],
  frame : @core.Rect,
  width : Double,
  spacing : Double,
  row_spacing : Double,
  direction : @core.LayoutDirection,
) -> Array[@core.Rect] {
  let available = placement_width(width, frame)
  let rows = flow_rows(sizes, available, spacing, row_spacing)
  let rects : Array[@core.Rect] = []
  for item in rows {
    let size = sizes[item.index]
    rects.push(
      @core.Rect::new(
        x=layout_mirror_x(frame, item.x, size.width, direction),
        y=frame.origin.y + item.y,
        width=size.width,
        height=size.height,
      ),
    )
  }
  rects
}

///|
priv struct FlowItemPlacement {
  index : Int
  x : Double
  y : Double
}

///|
fn flow_size(
  sizes : Array[@core.Size],
  width : Double,
  spacing : Double,
  row_spacing : Double,
) -> @core.Size {
  if sizes.length() == 0 {
    @core.Size::new(width~, height=0.0)
  } else {
    let rows = flow_rows(sizes, width, spacing, row_spacing)
    let mut height = 0.0
    for item in rows {
      height = layout_max_double(height, item.y + sizes[item.index].height)
    }
    @core.Size::new(width~, height~)
  }
}

///|
fn flow_rows(
  sizes : Array[@core.Size],
  width : Double,
  spacing : Double,
  row_spacing : Double,
) -> Array[FlowItemPlacement] {
  let items : Array[FlowItemPlacement] = []
  let mut x = 0.0
  let mut y = 0.0
  let mut row_height = 0.0
  let available = layout_max_double(1.0, width)
  for index, size in sizes {
    if x > 0.0 && x + size.width > available {
      x = 0.0
      y = y + row_height + row_spacing
      row_height = 0.0
    }
    items.push({ index, x, y })
    x = x + size.width + spacing
    row_height = layout_max_double(row_height, size.height)
  }
  items
}
