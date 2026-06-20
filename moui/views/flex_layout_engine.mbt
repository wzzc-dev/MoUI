///|
fn[Msg] flex_layout(
  children~ : Array[@core.View[Msg]],
  axis~ : @core.Axis,
  spacing? : Double = 0.0,
  main_axis_alignment? : @core.MainAxisAlignment = @core.MainAxisAlignment::MainStart,
  cross_axis_alignment? : @core.CrossAxisAlignment = @core.CrossAxisAlignment::CrossStretch,
  kind? : String = "Flex",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "flex:\{axis_revision(axis)}:\{spacing}:\{main_axis_revision(main_axis_alignment)}:\{cross_axis_revision(cross_axis_alignment)}"
    },
    children=() => children,
    layout=ctx => {
      let measured = flex_measured_size(axis, spacing, ctx.child_sizes)
      let size = ctx.constraints.constrain(measured)
      @core.ViewLayoutResult::new(
        size~,
        child_frames=flex_child_frames(
          axis,
          spacing,
          main_axis_alignment,
          cross_axis_alignment,
          ctx.child_sizes,
          ctx.child_flex_weights,
          size,
        ),
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}

///|
fn flex_measured_size(
  axis : @core.Axis,
  spacing : Double,
  child_sizes : Array[@core.Size],
) -> @core.Size {
  let mut main = 0.0
  let mut cross = 0.0
  for index, size in child_sizes {
    match axis {
      @core.Axis::Horizontal => {
        main = main + size.width
        cross = view_max_double(cross, size.height)
      }
      @core.Axis::Vertical => {
        main = main + size.height
        cross = view_max_double(cross, size.width)
      }
    }
    if index > 0 {
      main = main + spacing
    }
  }
  match axis {
    @core.Axis::Horizontal => @core.Size::new(width=main, height=cross)
    @core.Axis::Vertical => @core.Size::new(width=cross, height=main)
  }
}

///|
fn flex_child_frames(
  axis : @core.Axis,
  spacing : Double,
  main_axis_alignment : @core.MainAxisAlignment,
  cross_axis_alignment : @core.CrossAxisAlignment,
  child_sizes : Array[@core.Size],
  child_flex_weights : Array[Double],
  size : @core.Size,
) -> Array[@core.Rect] {
  let count = child_sizes.length()
  let frames : Array[@core.Rect] = []
  if count == 0 {
    frames
  } else {
    let total_spacing = spacing * (count.to_double() - 1.0)
    let mut child_main_total = 0.0
    for child_size in child_sizes {
      child_main_total = child_main_total +
        flex_child_main_size(axis, child_size)
    }
    let available_main = match axis {
      @core.Axis::Horizontal => size.width
      @core.Axis::Vertical => size.height
    }
    // Slack is the main-axis space left after every child's base size. Weighted
    // children (flex_weight > 0) grow to consume it proportionally, so a layout
    // like `[spacer(weight=1), content, spacer(weight=1)]` centers `content`.
    let slack = view_max_double(
      0.0,
      available_main - child_main_total - total_spacing,
    )
    let total_weight = flex_total_weight(child_flex_weights)
    let main_sizes = flex_resolved_main_sizes(
      axis, child_sizes, child_flex_weights, total_weight, slack,
    )
    let grown_total = flex_sum(main_sizes)
    let remaining = view_max_double(
      0.0,
      available_main - grown_total - total_spacing,
    )
    let offsets = flex_offsets(main_axis_alignment, remaining, spacing, count)
    let mut cursor = offsets.leading
    for index, child_size in child_sizes {
      let main_size = main_sizes[index]
      let cross_size = match axis {
        @core.Axis::Horizontal => child_size.height
        @core.Axis::Vertical => child_size.width
      }
      let cross_available = match axis {
        @core.Axis::Horizontal => size.height
        @core.Axis::Vertical => size.width
      }
      let cross = cross_axis_offset(
        cross_axis_alignment, cross_available, cross_size,
      )
      let frame = match axis {
        @core.Axis::Horizontal =>
          @core.Rect::new(
            x=cursor,
            y=cross.offset,
            width=main_size,
            height=cross.size,
          )
        @core.Axis::Vertical =>
          @core.Rect::new(
            x=cross.offset,
            y=cursor,
            width=cross.size,
            height=main_size,
          )
      }
      frames.push(frame)
      cursor = cursor + main_size + offsets.gap
    }
    frames
  }
}

///|
/// Sum of positive flex weights; zero when no child wants to grow.
fn flex_total_weight(weights : Array[Double]) -> Double {
  let mut total = 0.0
  for weight in weights {
    if weight > 0.0 {
      total = total + weight
    }
  }
  total
}

///|
/// Per-child main-axis sizes after applying flex growth. Each child starts at
/// its measured base size; weighted children claim `slack * weight /
/// total_weight` extra (only when `total_weight > 0`).
fn flex_resolved_main_sizes(
  axis : @core.Axis,
  child_sizes : Array[@core.Size],
  weights : Array[Double],
  total_weight : Double,
  slack : Double,
) -> Array[Double] {
  let sizes : Array[Double] = []
  for index, child_size in child_sizes {
    let base = flex_child_main_size(axis, child_size)
    let weight = if index < weights.length() { weights[index] } else { 0.0 }
    let grown = if total_weight > 0.0 && weight > 0.0 {
      base + slack * weight / total_weight
    } else {
      base
    }
    sizes.push(view_max_double(0.0, grown))
  }
  sizes
}

///|
fn flex_sum(values : Array[Double]) -> Double {
  let mut total = 0.0
  for value in values {
    total = total + value
  }
  total
}

///|
fn flex_child_main_size(axis : @core.Axis, size : @core.Size) -> Double {
  match axis {
    @core.Axis::Horizontal => size.width
    @core.Axis::Vertical => size.height
  }
}

///|
priv struct FlexOffsets {
  leading : Double
  gap : Double
}

///|
fn flex_offsets(
  alignment : @core.MainAxisAlignment,
  remaining : Double,
  base_gap : Double,
  count : Int,
) -> FlexOffsets {
  match alignment {
    @core.MainAxisAlignment::MainStart => { leading: 0.0, gap: base_gap }
    @core.MainAxisAlignment::MainCenter =>
      { leading: remaining / 2.0, gap: base_gap }
    @core.MainAxisAlignment::MainEnd => { leading: remaining, gap: base_gap }
    @core.MainAxisAlignment::SpaceBetween =>
      if count > 1 {
        { leading: 0.0, gap: base_gap + remaining / (count.to_double() - 1.0) }
      } else {
        { leading: 0.0, gap: base_gap }
      }
    @core.MainAxisAlignment::SpaceAround => {
      let extra = remaining / count.to_double()
      { leading: extra / 2.0, gap: base_gap + extra }
    }
    @core.MainAxisAlignment::SpaceEvenly => {
      let extra = remaining / (count.to_double() + 1.0)
      { leading: extra, gap: base_gap + extra }
    }
  }
}

///|
priv struct CrossAxisOffset {
  offset : Double
  size : Double
}

///|
fn cross_axis_offset(
  alignment : @core.CrossAxisAlignment,
  available : Double,
  child : Double,
) -> CrossAxisOffset {
  match alignment {
    @core.CrossAxisAlignment::CrossStart => { offset: 0.0, size: child }
    @core.CrossAxisAlignment::CrossCenter =>
      { offset: view_max_double(0.0, available - child) / 2.0, size: child }
    @core.CrossAxisAlignment::CrossEnd =>
      { offset: view_max_double(0.0, available - child), size: child }
    @core.CrossAxisAlignment::CrossStretch => { offset: 0.0, size: available }
  }
}

///|
fn size_revision(size : @core.Size?) -> String {
  match size {
    Some(size) => "\{size.width}x\{size.height}"
    None => "auto"
  }
}

///|
fn image_fit_revision(fit : @core.ImageFit) -> String {
  match fit {
    @core.ImageFit::Contain => "contain"
    @core.ImageFit::Cover => "cover"
    @core.ImageFit::Stretch => "stretch"
    @core.ImageFit::ScaleDown => "scale-down"
    @core.ImageFit::FitWidth => "fit-width"
    @core.ImageFit::FitHeight => "fit-height"
  }
}

///|
fn axis_revision(axis : @core.Axis) -> String {
  match axis {
    @core.Axis::Horizontal => "h"
    @core.Axis::Vertical => "v"
  }
}

///|
fn main_axis_revision(alignment : @core.MainAxisAlignment) -> String {
  match alignment {
    @core.MainAxisAlignment::MainStart => "start"
    @core.MainAxisAlignment::MainCenter => "center"
    @core.MainAxisAlignment::MainEnd => "end"
    @core.MainAxisAlignment::SpaceBetween => "between"
    @core.MainAxisAlignment::SpaceAround => "around"
    @core.MainAxisAlignment::SpaceEvenly => "evenly"
  }
}

///|
fn cross_axis_revision(alignment : @core.CrossAxisAlignment) -> String {
  match alignment {
    @core.CrossAxisAlignment::CrossStart => "start"
    @core.CrossAxisAlignment::CrossCenter => "center"
    @core.CrossAxisAlignment::CrossEnd => "end"
    @core.CrossAxisAlignment::CrossStretch => "stretch"
  }
}
