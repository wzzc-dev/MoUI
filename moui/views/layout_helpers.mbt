///|
pub fn[Msg] expanded(
  child : @core.View[Msg],
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  child.expanded(weight~)
}

///|
pub fn[Msg] flexible(
  child : @core.View[Msg],
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  child.flexible(weight~)
}

///|
pub fn[Msg] layout_priority(
  child : @core.View[Msg],
  priority : Double,
) -> @core.View[Msg] {
  child.layout_priority(priority)
}

///|
pub fn[Msg] align(
  child : @core.View[Msg],
  alignment? : @core.Alignment = @core.Alignment::center(),
) -> @core.View[Msg] {
  child.align(alignment~)
}

///|
pub fn[Msg] aspect_ratio(
  child : @core.View[Msg],
  ratio : Double,
) -> @core.View[Msg] {
  child.aspect_ratio(ratio)
}

///|
pub fn[Msg] intrinsic_width(child : @core.View[Msg]) -> @core.View[Msg] {
  child.intrinsic_width()
}

///|
pub fn[Msg] intrinsic_height(child : @core.View[Msg]) -> @core.View[Msg] {
  child.intrinsic_height()
}

///|
pub fn[Msg] custom_layout(
  measure~ : (@core.Constraints) -> @core.Size,
  paint~ : (@core.Rect) -> Array[@core.DrawCommand],
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @core.View::custom_view(measure~, paint~, semantics_role~, semantics_label~)
}

///|
pub fn[Msg] custom_children_layout(
  children~ : Array[@core.View[Msg]],
  measure~ : (@core.CustomLayoutContext) -> @core.Size,
  place~ : (@core.CustomPlacementContext) -> Array[@core.Rect],
  paint? : (@core.Rect) -> Array[@core.DrawCommand] = _frame => [],
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @core.View::custom_children_layout(
    children~,
    measure~,
    place~,
    paint~,
    semantics_role~,
    semantics_label~,
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
pub fn[Msg] responsive_grid(
  children : Array[@core.View[Msg]],
  width? : Double = 320.0,
  min_column_width? : Double = 120.0,
  row_spacing? : Double = 8.0,
  column_spacing? : Double = 8.0,
) -> @core.View[Msg] {
  custom_children_layout(
    children~,
    measure=ctx => {
      responsive_grid_measure(
        ctx.child_sizes,
        width,
        min_column_width,
        row_spacing,
        column_spacing,
        ctx.constraints,
      )
    },
    place=ctx => {
      responsive_grid_place(
        ctx.child_sizes,
        ctx.frame,
        min_column_width,
        row_spacing,
        column_spacing,
        ctx.layout_direction,
      )
    },
    semantics_label="Responsive grid",
  )
}

///|
pub fn[Msg] baseline_form_rows(
  rows : Array[BaselineFormRow[Msg]],
  width? : Double = 420.0,
  label_width? : Double = 140.0,
  row_spacing? : Double = 10.0,
  column_spacing? : Double = 12.0,
) -> @core.View[Msg] {
  let children : Array[@core.View[Msg]] = []
  for row in rows {
    children.push(row.label)
    children.push(row.control)
  }
  custom_children_layout(
    children~,
    measure=ctx => {
      baseline_form_measure(
        ctx.child_sizes,
        ctx.child_baselines,
        width,
        row_spacing,
        ctx.constraints,
      )
    },
    place=ctx => {
      baseline_form_place(
        ctx.child_sizes,
        ctx.child_baselines,
        ctx.frame,
        label_width,
        row_spacing,
        column_spacing,
        ctx.layout_direction,
      )
    },
    semantics_label="Baseline form rows",
  )
}

///|
pub fn component(
  build : (@core.BuildContext) -> @core.View[Unit],
) -> @core.View[Unit] {
  @core.View::component(build)
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
  let available = if frame.size.width > 0.0 { frame.size.width } else { width }
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
fn responsive_grid_measure(
  sizes : Array[@core.Size],
  width : Double,
  min_column_width : Double,
  row_spacing : Double,
  column_spacing : Double,
  constraints : @core.Constraints,
) -> @core.Size {
  let available = available_width(width, constraints)
  let columns = responsive_grid_columns(
    available, min_column_width, column_spacing,
  )
  let rows = layout_ceil_div(sizes.length(), columns)
  let mut height = 0.0
  for row_index in 0..<rows {
    let mut row_height = 0.0
    let start = row_index * columns
    let end = layout_min_int(sizes.length(), start + columns)
    for index in start..<end {
      row_height = layout_max_double(row_height, sizes[index].height)
    }
    height = height + row_height
    if row_index + 1 < rows {
      height = height + row_spacing
    }
  }
  constraints.constrain(@core.Size::new(width=available, height~))
}

///|
fn responsive_grid_place(
  sizes : Array[@core.Size],
  frame : @core.Rect,
  min_column_width : Double,
  row_spacing : Double,
  column_spacing : Double,
  direction : @core.LayoutDirection,
) -> Array[@core.Rect] {
  let columns = responsive_grid_columns(
    frame.size.width,
    min_column_width,
    column_spacing,
  )
  let column_width = responsive_grid_column_width(
    frame.size.width,
    columns,
    column_spacing,
  )
  let rects : Array[@core.Rect] = []
  let mut y = frame.origin.y
  let rows = layout_ceil_div(sizes.length(), columns)
  for row_index in 0..<rows {
    let start = row_index * columns
    let end = layout_min_int(sizes.length(), start + columns)
    let mut row_height = 0.0
    for index in start..<end {
      row_height = layout_max_double(row_height, sizes[index].height)
    }
    for index in start..<end {
      let column = index - start
      let x = frame.origin.x +
        column.to_double() * (column_width + column_spacing)
      rects.push(
        @core.Rect::new(
          x=layout_mirror_x(frame, x - frame.origin.x, column_width, direction),
          y~,
          width=column_width,
          height=sizes[index].height,
        ),
      )
    }
    y = y + row_height + row_spacing
  }
  rects
}

///|
fn baseline_form_measure(
  sizes : Array[@core.Size],
  baselines : Array[Double?],
  width : Double,
  row_spacing : Double,
  constraints : @core.Constraints,
) -> @core.Size {
  let row_count = sizes.length() / 2
  let mut height = 0.0
  for row in 0..<row_count {
    height = height + baseline_form_row_height(sizes, baselines, row)
    if row + 1 < row_count {
      height = height + row_spacing
    }
  }
  constraints.constrain(
    @core.Size::new(width=available_width(width, constraints), height~),
  )
}

///|
fn baseline_form_place(
  sizes : Array[@core.Size],
  baselines : Array[Double?],
  frame : @core.Rect,
  label_width : Double,
  row_spacing : Double,
  column_spacing : Double,
  direction : @core.LayoutDirection,
) -> Array[@core.Rect] {
  let rects : Array[@core.Rect] = []
  let row_count = sizes.length() / 2
  let control_width = layout_max_double(
    0.0,
    frame.size.width - label_width - column_spacing,
  )
  let mut y = frame.origin.y
  for row in 0..<row_count {
    let label_index = row * 2
    let control_index = label_index + 1
    let label_size = sizes[label_index]
    let control_size = sizes[control_index]
    let label_baseline = baseline_at(baselines, label_index, label_size)
    let control_baseline = baseline_at(baselines, control_index, control_size)
    let shared_baseline = layout_max_double(label_baseline, control_baseline)
    let label_y = y + shared_baseline - label_baseline
    let control_y = y + shared_baseline - control_baseline
    rects.push(
      @core.Rect::new(
        x=layout_mirror_x(frame, 0.0, label_width, direction),
        y=label_y,
        width=label_width,
        height=label_size.height,
      ),
    )
    rects.push(
      @core.Rect::new(
        x=layout_mirror_x(
          frame,
          label_width + column_spacing,
          control_width,
          direction,
        ),
        y=control_y,
        width=control_width,
        height=control_size.height,
      ),
    )
    y = y + baseline_form_row_height(sizes, baselines, row) + row_spacing
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

///|
fn responsive_grid_columns(
  width : Double,
  min_column_width : Double,
  column_spacing : Double,
) -> Int {
  let min_column_width = layout_max_double(1.0, min_column_width)
  let mut columns = 1
  let mut needed = min_column_width * 2.0 + column_spacing
  while needed <= width {
    columns = columns + 1
    needed = columns.to_double() * min_column_width +
      (columns - 1).to_double() * column_spacing
  }
  columns
}

///|
fn responsive_grid_column_width(
  width : Double,
  columns : Int,
  column_spacing : Double,
) -> Double {
  let columns = layout_max_int(1, columns)
  layout_max_double(
    1.0,
    (width - (columns - 1).to_double() * column_spacing) / columns.to_double(),
  )
}

///|
fn available_width(width : Double, constraints : @core.Constraints) -> Double {
  if constraints.max.width < 1.0e9 {
    constraints.max.width
  } else {
    width
  }
}

///|
fn baseline_form_row_height(
  sizes : Array[@core.Size],
  baselines : Array[Double?],
  row : Int,
) -> Double {
  let label_index = row * 2
  let control_index = label_index + 1
  let label_size = sizes[label_index]
  let control_size = sizes[control_index]
  let label_baseline = baseline_at(baselines, label_index, label_size)
  let control_baseline = baseline_at(baselines, control_index, control_size)
  let shared = layout_max_double(label_baseline, control_baseline)
  layout_max_double(
    shared + label_size.height - label_baseline,
    shared + control_size.height - control_baseline,
  )
}

///|
fn baseline_at(
  baselines : Array[Double?],
  index : Int,
  size : @core.Size,
) -> Double {
  if index < baselines.length() {
    baselines[index].unwrap_or(size.height * 0.8)
  } else {
    size.height * 0.8
  }
}

///|
fn layout_mirror_x(
  frame : @core.Rect,
  local_x : Double,
  width : Double,
  direction : @core.LayoutDirection,
) -> Double {
  match direction {
    @core.LayoutDirection::LeftToRight => frame.origin.x + local_x
    @core.LayoutDirection::RightToLeft =>
      frame.origin.x + frame.size.width - local_x - width
  }
}

///|
fn layout_ceil_div(a : Int, b : Int) -> Int {
  let b = layout_max_int(1, b)
  if a == 0 {
    0
  } else {
    (a + b - 1) / b
  }
}

///|
fn layout_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn layout_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn layout_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
