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
      let sizes = ctx.children.map(child => child.size)
      responsive_grid_measure(
        sizes,
        width,
        min_column_width,
        row_spacing,
        column_spacing,
        ctx.constraints,
      )
    },
    place=ctx => {
      let sizes = ctx.children.map(child => child.size)
      responsive_grid_place(
        sizes,
        ctx.frame,
        width,
        min_column_width,
        row_spacing,
        column_spacing,
        ctx.layout_direction,
      )
    },
    semantics_label="Responsive grid",
    paint=(_ctx, _frame) => (),
  )
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
  let available = @layout.available_width(width, constraints)
  let columns = responsive_grid_columns(
    available, min_column_width, column_spacing,
  )
  let rows = @layout.layout_ceil_div(sizes.length(), columns)
  let mut height = 0.0
  for row_index in 0..<rows {
    let mut row_height = 0.0
    let start = row_index * columns
    let end = @layout.min_int(sizes.length(), start + columns)
    for index in start..<end {
      row_height = @layout.max_double(row_height, sizes[index].height)
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
  width : Double,
  min_column_width : Double,
  row_spacing : Double,
  column_spacing : Double,
  direction : @core.LayoutDirection,
) -> Array[@core.Rect] {
  let available = @layout.placement_width(width, frame)
  let columns = responsive_grid_columns(
    available, min_column_width, column_spacing,
  )
  let column_width = responsive_grid_column_width(
    available, columns, column_spacing,
  )
  let rects : Array[@core.Rect] = []
  let mut y = frame.origin.y
  let rows = @layout.layout_ceil_div(sizes.length(), columns)
  for row_index in 0..<rows {
    let start = row_index * columns
    let end = @layout.min_int(sizes.length(), start + columns)
    let mut row_height = 0.0
    for index in start..<end {
      row_height = @layout.max_double(row_height, sizes[index].height)
    }
    for index in start..<end {
      let column = index - start
      let x = frame.origin.x +
        column.to_double() * (column_width + column_spacing)
      rects.push(
        @core.Rect::new(
          x=@layout.layout_mirror_x(
            frame,
            x - frame.origin.x,
            column_width,
            direction,
          ),
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
fn responsive_grid_columns(
  width : Double,
  min_column_width : Double,
  column_spacing : Double,
) -> Int {
  let min_column_width = @layout.max_double(1.0, min_column_width)
  // Snap the available width to the nearest physical pixel to avoid sub-pixel
  // oscillation during live resize: a 0.5 logical pixel step on Retina can
  // otherwise flip the column count back and forth at the threshold, causing
  // height jumps and perceived flicker in two-column showcase demos.
  // Adding a tiny epsilon prevents floating-point jitter from toggling the
  // `needed <= width` boundary on successive resize frames.
  let width = (width * 2.0).round() / 2.0
  let mut columns = 1
  let mut candidate = 2
  let mut needed = candidate.to_double() * min_column_width +
    (candidate - 1).to_double() * column_spacing
  while needed <= width + 0.25 {
    columns = candidate
    candidate = candidate + 1
    needed = candidate.to_double() * min_column_width +
      (candidate - 1).to_double() * column_spacing
  }
  columns
}

///|
fn responsive_grid_column_width(
  width : Double,
  columns : Int,
  column_spacing : Double,
) -> Double {
  let columns = @layout.max_int(1, columns)
  @layout.max_double(
    1.0,
    (width - (columns - 1).to_double() * column_spacing) / columns.to_double(),
  )
}
