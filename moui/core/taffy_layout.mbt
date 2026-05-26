///|
priv struct TaffyLayoutPlan {
  tree : @taffy.TaffyTree[Int]
  root : Int
  children : Array[Int]
}

///|
fn ElementNode::taffy_child_frames_for_place(
  self : ElementNode,
  frame : Rect,
) -> Array[Rect]? {
  match self.spec {
    FlexSpec(data) =>
      self.taffy_flex_child_frames(
        frame,
        data.axis,
        data.spacing,
        data.main_axis_alignment,
        data.cross_axis_alignment,
      )
    GridSpec(data) =>
      self.taffy_grid_child_frames(
        frame,
        data.columns,
        data.row_spacing,
        data.column_spacing,
      )
    ListSpec(data) =>
      self.taffy_flex_child_frames(
        frame,
        Axis::Vertical,
        data.spacing,
        MainAxisAlignment::MainStart,
        CrossAxisAlignment::CrossStretch,
      )
    StackSpec(_) => self.taffy_stack_child_frames(frame)
    _ => None
  }
}

///|
fn ElementNode::taffy_flex_child_frames(
  self : ElementNode,
  frame : Rect,
  axis : Axis,
  spacing : Double,
  main_axis_alignment : MainAxisAlignment,
  cross_axis_alignment : CrossAxisAlignment,
) -> Array[Rect]? {
  let children = self.taffy_leaf_nodes(axis~)
  let root_style = @taffy_style.Style::default()
    .with_display(@taffy_style.Display::DisplayFlex)
    .with_size(taffy_size(width=frame.size.width, height=frame.size.height))
    .with_gap(taffy_size(width=spacing, height=spacing))
    .with_flex_direction(taffy_flex_direction(axis))
    .with_justify_content(taffy_main_axis_alignment(main_axis_alignment))
    .with_align_items(taffy_cross_axis_alignment(cross_axis_alignment))
  let root = children.tree.new_with_children(root_style, children.children)
  let plan = { tree: children.tree, root, children: children.children }
  taffy_compute_child_frames(plan, frame, self.children)
}

///|
fn ElementNode::taffy_grid_child_frames(
  self : ElementNode,
  frame : Rect,
  columns : Int,
  row_spacing : Double,
  column_spacing : Double,
) -> Array[Rect]? {
  let tree : @taffy.TaffyTree[Int] = @taffy.TaffyTree::TaffyTree()
  tree.disable_rounding()
  let column_count = max_int(1, columns)
  let rows = grid_row_count(self.children.length(), column_count)
  let total_column_spacing = column_spacing *
    max_int(0, column_count - 1).to_double()
  let total_row_spacing = row_spacing * max_int(0, rows - 1).to_double()
  let cell_width = max_double(
    0.0,
    (frame.size.width - total_column_spacing) / column_count.to_double(),
  )
  let measured = measure_grid_size(
    column_count,
    row_spacing,
    column_spacing,
    self.children,
  )
  let cell_height = if measured.height > 0.0 && rows > 0 {
    max_double(0.0, (measured.height - total_row_spacing) / rows.to_double())
  } else if rows > 0 {
    max_double(0.0, (frame.size.height - total_row_spacing) / rows.to_double())
  } else {
    0.0
  }
  let nodes : Array[Int] = []
  for index, child in self.children {
    let column = index - index / column_count * column_count
    let row = index / column_count
    nodes.push(
      tree.new_leaf_with_context(
        taffy_measured_leaf_style(child, Axis::Horizontal)
        .with_grid_column_start(column + 1)
        .with_grid_row_start(row + 1),
        index,
      ),
    )
  }
  let tracks : Array[@taffy_style.Dimension] = []
  for _ in 0..<column_count {
    tracks.push(@taffy_style.Dimension::DimLength(cell_width))
  }
  let row_tracks : Array[@taffy_style.Dimension] = []
  for _ in 0..<rows {
    row_tracks.push(@taffy_style.Dimension::DimLength(cell_height))
  }
  let root_style = @taffy_style.Style::default()
    .with_display(@taffy_style.Display::DisplayGrid)
    .with_size(taffy_size(width=frame.size.width, height=frame.size.height))
    .with_gap(taffy_size(width=column_spacing, height=row_spacing))
    .with_grid_template_columns(tracks)
    .with_grid_template_rows(row_tracks)
    .with_align_items(@taffy_style.AlignItems::ItemsStretch)
    .with_justify_items(@taffy_style.AlignItems::ItemsStretch)
  let root = tree.new_with_children(root_style, nodes)
  taffy_compute_child_frames(
    { tree, root, children: nodes },
    frame,
    self.children,
  )
}

///|
fn ElementNode::taffy_stack_child_frames(
  self : ElementNode,
  frame : Rect,
) -> Array[Rect]? {
  let tree : @taffy.TaffyTree[Int] = @taffy.TaffyTree::TaffyTree()
  tree.disable_rounding()
  let nodes : Array[Int] = []
  for index, _child in self.children {
    nodes.push(
      tree.new_leaf_with_context(
        @taffy_style.Style::default()
        .with_position(@taffy_style.Position::PosAbsolute)
        .with_size(taffy_size_percent(width=1.0, height=1.0)),
        index,
      ),
    )
  }
  let root = tree.new_with_children(
    @taffy_style.Style::default().with_size(
      taffy_size(width=frame.size.width, height=frame.size.height),
    ),
    nodes,
  )
  taffy_compute_child_frames(
    { tree, root, children: nodes },
    frame,
    self.children,
  )
}

///|
fn ElementNode::taffy_leaf_nodes(
  self : ElementNode,
  axis~ : Axis,
) -> TaffyLayoutPlan {
  let tree : @taffy.TaffyTree[Int] = @taffy.TaffyTree::TaffyTree()
  tree.disable_rounding()
  let nodes : Array[Int] = []
  for index, child in self.children {
    nodes.push(
      tree.new_leaf_with_context(taffy_measured_leaf_style(child, axis), index),
    )
  }
  { tree, root: -1, children: nodes }
}

///|
fn taffy_compute_child_frames(
  plan : TaffyLayoutPlan,
  frame : Rect,
  children : Array[ElementNode],
) -> Array[Rect]? {
  try {
    plan.tree.compute_layout_with_measure(
      plan.root,
      @taffy_geometry.Size::Size(
        width=@taffy_geometry.AvailableSpace::AvailDefinite(frame.size.width),
        height=@taffy_geometry.AvailableSpace::AvailDefinite(frame.size.height),
      ),
      (_known, _available, _node_id, context, _style) => {
        match context {
          Some(index) =>
            if index >= 0 && index < children.length() {
              let size = children[index].intrinsic_size()
              @taffy_geometry.Size::Size(width=size.width, height=size.height)
            } else {
              @taffy_geometry.Size::zero()
            }
          None => @taffy_geometry.Size::zero()
        }
      },
    )
    let frames : Array[Rect] = []
    for node in plan.children {
      let layout = plan.tree.layout(node)
      frames.push(
        Rect::new(
          x=frame.origin.x + layout.location.x,
          y=frame.origin.y + layout.location.y,
          width=layout.size.width,
          height=layout.size.height,
        ),
      )
    }
    Some(frames)
  } catch {
    _ => None
  }
}

///|
fn taffy_measured_leaf_style(
  child : ElementNode,
  axis : Axis,
) -> @taffy_style.Style {
  let weight = spacer_weight(child)
  let base = @taffy_style.Style::default().with_flex_shrink(0.0)
  if weight > 0.0 {
    base
    .with_flex_grow(weight)
    .with_flex_basis(
      @taffy_style.Dimension::DimLength(
        child_main_size(axis, child.intrinsic_size()),
      ),
    )
  } else {
    base
  }
}

///|
fn taffy_size(
  width~ : Double,
  height~ : Double,
) -> @taffy_geometry.Size[@taffy_style.Dimension] {
  @taffy_geometry.Size::Size(
    width=@taffy_style.Dimension::DimLength(width),
    height=@taffy_style.Dimension::DimLength(height),
  )
}

///|
fn taffy_size_percent(
  width~ : Double,
  height~ : Double,
) -> @taffy_geometry.Size[@taffy_style.Dimension] {
  @taffy_geometry.Size::Size(
    width=@taffy_style.Dimension::DimPercent(width),
    height=@taffy_style.Dimension::DimPercent(height),
  )
}

///|
fn taffy_flex_direction(axis : Axis) -> @taffy_style.FlexDirection {
  match axis {
    Axis::Horizontal => @taffy_style.FlexDirection::FlexRow
    Axis::Vertical => @taffy_style.FlexDirection::FlexColumn
  }
}

///|
fn taffy_main_axis_alignment(
  alignment : MainAxisAlignment,
) -> @taffy_style.AlignContent {
  match alignment {
    MainStart => @taffy_style.AlignContent::AlignFlexStart
    MainCenter => @taffy_style.AlignContent::AlignCenter
    MainEnd => @taffy_style.AlignContent::AlignFlexEnd
    SpaceBetween => @taffy_style.AlignContent::AlignSpaceBetween
    SpaceAround => @taffy_style.AlignContent::AlignSpaceAround
    SpaceEvenly => @taffy_style.AlignContent::AlignSpaceEvenly
  }
}

///|
fn taffy_cross_axis_alignment(
  alignment : CrossAxisAlignment,
) -> @taffy_style.AlignItems {
  match alignment {
    CrossStart => @taffy_style.AlignItems::ItemsFlexStart
    CrossCenter => @taffy_style.AlignItems::ItemsCenter
    CrossEnd => @taffy_style.AlignItems::ItemsFlexEnd
    CrossStretch => @taffy_style.AlignItems::ItemsStretch
  }
}
