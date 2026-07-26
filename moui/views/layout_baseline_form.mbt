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
      let sizes = ctx.children.map(child => child.size)
      let baselines = ctx.children.map(child => child.first_baseline)
      baseline_form_measure(
        sizes,
        baselines,
        width,
        row_spacing,
        ctx.constraints,
      )
    },
    place=ctx => {
      let sizes = ctx.children.map(child => child.size)
      let baselines = ctx.children.map(child => child.first_baseline)
      baseline_form_place(
        sizes,
        baselines,
        ctx.frame,
        width,
        label_width,
        row_spacing,
        column_spacing,
        ctx.layout_direction,
      )
    },
    semantics_label="Baseline form rows",
    paint=(_ctx, _frame) => (),
  )
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
  width : Double,
  label_width : Double,
  row_spacing : Double,
  column_spacing : Double,
  direction : @core.LayoutDirection,
) -> Array[@core.Rect] {
  let rects : Array[@core.Rect] = []
  let row_count = sizes.length() / 2
  let available = placement_width(width, frame)
  let control_width = layout_max_double(
    0.0,
    available - label_width - column_spacing,
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
