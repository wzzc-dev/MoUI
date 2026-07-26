///|
/// Concrete view node for the `flow` / `wrap` controls.
///
/// Lays out children left-to-right in rows, wrapping to a new row when the
/// next child would overflow the configured `width`. The node carries only
/// immutable declaration data (`width`, `spacing`, `row_spacing`). Children
/// are attached through `View::from_node`'s typed children adapter, so the
/// node itself stays message-independent.
priv struct FlowViewNode {
  width : Double
  spacing : Double
  row_spacing : Double
}

///|
impl @core.ViewNode for FlowViewNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Flow")
}

///|
impl @core.ViewNode for FlowViewNode with fn revision(self) {
  "flow:\{self.width}:\{self.spacing}:\{self.row_spacing}"
}

///|
impl @core.ViewNode for FlowViewNode with fn layout(self, ctx) {
  let sizes = ctx.child_sizes
  let available = available_width(self.width, ctx.constraints)
  let measured = flow_size(sizes, available, self.spacing, self.row_spacing)
  let size = ctx.constraints.constrain(measured)
  let rows = flow_rows(sizes, available, self.spacing, self.row_spacing)
  let frames : Array[@core.Rect] = []
  for item in rows {
    let item_size = sizes[item.index]
    let x = layout_mirror_x(
      @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
      item.x,
      item_size.width,
      ctx.environment.layout_direction,
    )
    frames.push(
      @core.Rect::new(
        x~,
        y=item.y,
        width=item_size.width,
        height=item_size.height,
      ),
    )
  }
  @core.ViewLayoutResult::new(size~, child_frames=frames)
}

///|
impl @core.ViewNode for FlowViewNode with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::Group,
    label="Flow layout",
  )
}

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
  @core.View::from_node(
    FlowViewNode::{ width, spacing, row_spacing },
    children=_node => children,
  )
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
priv struct FlowItemPlacement {
  index : Int
  x : Double
  y : Double
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
