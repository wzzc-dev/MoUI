///|
fn measure_flex_sizes(
  axis : Axis,
  spacing : Double,
  children : Array[ElementNode],
) -> Size {
  let mut main = 0.0
  let mut cross = 0.0
  for index, child in children {
    let size = child.intrinsic_size()
    match axis {
      Axis::Horizontal => {
        main = main + size.width
        cross = max_double(cross, size.height)
      }
      Axis::Vertical => {
        main = main + size.height
        cross = max_double(cross, size.width)
      }
    }
    if index > 0 {
      main = main + spacing
    }
  }
  match axis {
    Axis::Horizontal => Size::new(width=main, height=cross)
    Axis::Vertical => Size::new(width=cross, height=main)
  }
}

///|
fn measure_stack_size(children : Array[ElementNode]) -> Size {
  let mut width = 0.0
  let mut height = 0.0
  for child in children {
    let size = child.intrinsic_size()
    width = max_double(width, size.width)
    height = max_double(height, size.height)
  }
  Size::new(width~, height~)
}

///|
fn measure_grid_size(
  columns : Int,
  row_spacing : Double,
  column_spacing : Double,
  children : Array[ElementNode],
) -> Size {
  let count = children.length()
  if count == 0 {
    Size::new(width=0.0, height=0.0)
  } else {
    let columns = max_int(1, columns)
    let rows = grid_row_count(count, columns)
    let mut cell_width = 0.0
    let mut cell_height = 0.0
    for child in children {
      let size = child.intrinsic_size()
      cell_width = max_double(cell_width, size.width)
      cell_height = max_double(cell_height, size.height)
    }
    Size::new(
      width=cell_width * columns.to_double() +
        column_spacing * max_int(0, columns - 1).to_double(),
      height=cell_height * rows.to_double() +
        row_spacing * max_int(0, rows - 1).to_double(),
    )
  }
}

///|
fn measure_list_size(spacing : Double, children : Array[ElementNode]) -> Size {
  let mut width = 0.0
  let mut height = 0.0
  for index, child in children {
    let size = child.intrinsic_size()
    width = max_double(width, size.width)
    height = height + size.height
    if index > 0 {
      height = height + spacing
    }
  }
  Size::new(width~, height~)
}

///|
fn resolve_frame_size(data : FrameViewSpec, child : Size) -> Size {
  let width = data.width.unwrap_or(child.width)
  let height = data.height.unwrap_or(child.height)
  let min_width = data.min_width.unwrap_or(0.0)
  let min_height = data.min_height.unwrap_or(0.0)
  let max_width = data.max_width.unwrap_or(width)
  let max_height = data.max_height.unwrap_or(height)
  Size::new(width~, height~).clamp({
    min: Size::new(width=min_width, height=min_height),
    max: Size::new(
      width=max_double(min_width, max_width),
      height=max_double(min_height, max_height),
    ),
  })
}

///|
fn frame_rect_for_spec(data : FrameViewSpec, bounds : Rect) -> Rect {
  let size = resolve_frame_size(data, bounds.size)
  Rect::new(
    x=bounds.origin.x,
    y=bounds.origin.y,
    width=size.width,
    height=size.height,
  )
}

///|
fn resolve_frame_modifier_size(data : FrameModifierSpec, child : Size) -> Size {
  let width = data.width.unwrap_or(child.width)
  let height = data.height.unwrap_or(child.height)
  let min_width = data.min_width.unwrap_or(0.0)
  let min_height = data.min_height.unwrap_or(0.0)
  let max_width = data.max_width.unwrap_or(width)
  let max_height = data.max_height.unwrap_or(height)
  Size::new(width~, height~).clamp({
    min: Size::new(width=min_width, height=min_height),
    max: Size::new(
      width=max_double(min_width, max_width),
      height=max_double(min_height, max_height),
    ),
  })
}

///|
fn frame_rect_for_modifier(data : FrameModifierSpec, bounds : Rect) -> Rect {
  let size = resolve_frame_modifier_size(data, bounds.size)
  Rect::new(
    x=bounds.origin.x,
    y=bounds.origin.y,
    width=size.width,
    height=size.height,
  )
}

///|
fn modified_intrinsic_size(
  modifier : ViewModifier,
  children : Array[ElementNode],
) -> Size {
  let child_size = if children.length() > 0 {
    children[0].intrinsic_size()
  } else {
    Size::new(width=0.0, height=0.0)
  }
  match modifier {
    PaddingModifier(insets) => child_size.inflate(insets)
    FrameModifier(data) => resolve_frame_modifier_size(data, child_size)
    BackgroundModifier(_)
    | ForegroundModifier(_)
    | FontModifier(_)
    | CornerRadiusModifier(_)
    | OpacityModifier(_)
    | ShadowModifier(_)
    | BorderModifier(_)
    | OffsetModifier(_, _)
    | ClipModifier
    | ScaleModifier(_, _)
    | DisabledModifier(_)
    | AccessibilityLabelModifier(_)
    | SemanticsRoleModifier(_)
    | FocusableModifier(_)
    | OnTapModifier(_)
    | KeyboardShortcutModifier(_)
    | FlexibleModifier(_)
    | LayoutPriorityModifier(_)
    | AlignModifier(_)
    | IntrinsicWidthModifier
    | IntrinsicHeightModifier => child_size
    AspectRatioModifier(ratio) => aspect_ratio_size(child_size, ratio)
  }
}

///|
fn ElementNode::first_baseline(
  self : ElementNode,
  text_measurer? : TextMeasurer = TextMeasurer::default(),
) -> Double? {
  match self.spec {
    TextSpec(data) =>
      Some(
        text_measurer.measure_text(
          TextLayoutInput::new(text=data.text, font=data.font),
        ).baseline,
      )
    ButtonSpec(data) =>
      Some(
        text_measurer.measure_text(
          TextLayoutInput::new(text=data.text, font=data.font),
        ).baseline,
      )
    TextFieldSpec(data) =>
      Some(
        text_measurer.measure_text(
          TextLayoutInput::new(text=data.value.get(), font=data.font),
        ).baseline,
      )
    RichTextEditorSpec(data) =>
      Some(
        text_measurer.measure_text(
          TextLayoutInput::new(text=data.value.get(), font=data.font),
        ).baseline,
      )
    CheckboxSpec(data) =>
      Some(
        text_measurer.measure_text(
          TextLayoutInput::new(text=data.label, font=data.font),
        ).baseline,
      )
    ModifiedSpec(_) | ComponentSpec(_) =>
      if self.children.length() > 0 {
        self.children[0].first_baseline(text_measurer~)
      } else {
        None
      }
    _ => None
  }
}

///|
fn ElementNode::layout_priority(self : ElementNode) -> Double {
  match self.spec {
    ModifiedSpec(data) =>
      match data.modifier {
        LayoutPriorityModifier(priority) => priority
        _ =>
          if self.children.length() > 0 {
            self.children[0].layout_priority()
          } else {
            0.0
          }
      }
    ComponentSpec(_) =>
      if self.children.length() > 0 {
        self.children[0].layout_priority()
      } else {
        0.0
      }
    _ => 0.0
  }
}

///|
fn custom_layout_cache_key(
  _spec : ViewSpec,
  child_sizes : Array[Size],
) -> String {
  let prefix = "custom-layout"
  let parts : Array[String] = []
  for size in child_sizes {
    parts.push("\{size.width}x\{size.height}")
  }
  prefix + ":" + parts.join(",")
}

///|
fn custom_alignment_guides(
  child_sizes : Array[Size],
  child_baselines : Array[Double?],
) -> Array[AlignmentGuideSet] {
  let guides : Array[AlignmentGuideSet] = []
  for index, size in child_sizes {
    let baseline = if index < child_baselines.length() {
      child_baselines[index]
    } else {
      None
    }
    guides.push(AlignmentGuideSet::from_size(size, first_baseline=baseline))
  }
  guides
}

///|
fn spacer_weight(child : ElementNode) -> Double {
  match child.spec {
    SpacerSpec(data) => data.weight
    ModifiedSpec(data) =>
      match data.modifier {
        FlexibleModifier(weight) => weight
        _ =>
          if child.children.length() > 0 {
            spacer_weight(child.children[0])
          } else {
            0.0
          }
      }
    _ => 0.0
  }
}

///|
fn child_main_size(axis : Axis, size : Size) -> Double {
  match axis {
    Axis::Horizontal => size.width
    Axis::Vertical => size.height
  }
}

///|
fn flex_child_frames(
  axis : Axis,
  spacing : Double,
  main_axis_alignment : MainAxisAlignment,
  cross_axis_alignment : CrossAxisAlignment,
  children : Array[ElementNode],
  bounds : Rect,
) -> Array[Rect] {
  let count = children.length()
  let frames : Array[Rect] = []
  if count == 0 {
    frames
  } else {
    let total_spacing = spacing * (count.to_double() - 1.0)
    let mut child_main_total = 0.0
    let mut total_weight = 0.0
    let child_sizes = children.map(child => child.intrinsic_size())
    for index, size in child_sizes {
      let weight = spacer_weight(children[index])
      if weight > 0.0 {
        total_weight = total_weight + weight
        child_main_total = child_main_total + child_main_size(axis, size)
      } else {
        child_main_total = child_main_total + child_main_size(axis, size)
      }
    }
    let available_main = match axis {
      Axis::Horizontal => bounds.size.width
      Axis::Vertical => bounds.size.height
    }
    let remaining = max_double(
      0.0,
      available_main - child_main_total - total_spacing,
    )
    let alignment_remaining = if total_weight > 0.0 { 0.0 } else { remaining }
    let offsets = flex_offsets(
      main_axis_alignment, alignment_remaining, spacing, count,
    )
    let mut cursor = offsets.leading
    for index, size in child_sizes {
      let weight = spacer_weight(children[index])
      let main_size = if weight > 0.0 && total_weight > 0.0 {
        child_main_size(axis, size) + remaining * weight / total_weight
      } else {
        child_main_size(axis, size)
      }
      let cross_size = match axis {
        Axis::Horizontal => size.height
        Axis::Vertical => size.width
      }
      let cross_available = match axis {
        Axis::Horizontal => bounds.size.height
        Axis::Vertical => bounds.size.width
      }
      let cross = cross_axis_offset(
        cross_axis_alignment, cross_available, cross_size,
      )
      let frame = match axis {
        Axis::Horizontal =>
          Rect::new(
            x=bounds.origin.x + cursor,
            y=bounds.origin.y + cross.offset,
            width=main_size,
            height=cross.size,
          )
        Axis::Vertical =>
          Rect::new(
            x=bounds.origin.x + cross.offset,
            y=bounds.origin.y + cursor,
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
priv struct FlexOffsets {
  leading : Double
  gap : Double
}

///|
fn flex_offsets(
  alignment : MainAxisAlignment,
  remaining : Double,
  base_gap : Double,
  count : Int,
) -> FlexOffsets {
  match alignment {
    MainStart => { leading: 0.0, gap: base_gap }
    MainCenter => { leading: remaining / 2.0, gap: base_gap }
    MainEnd => { leading: remaining, gap: base_gap }
    SpaceBetween =>
      if count > 1 {
        { leading: 0.0, gap: base_gap + remaining / (count.to_double() - 1.0) }
      } else {
        { leading: 0.0, gap: base_gap }
      }
    SpaceAround => {
      let extra = remaining / count.to_double()
      { leading: extra / 2.0, gap: base_gap + extra }
    }
    SpaceEvenly => {
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
  alignment : CrossAxisAlignment,
  available : Double,
  child : Double,
) -> CrossAxisOffset {
  match alignment {
    CrossStart => { offset: 0.0, size: child }
    CrossCenter =>
      { offset: max_double(0.0, available - child) / 2.0, size: child }
    CrossEnd => { offset: max_double(0.0, available - child), size: child }
    CrossStretch => { offset: 0.0, size: available }
  }
}

///|
fn grid_row_count(count : Int, columns : Int) -> Int {
  let columns = max_int(1, columns)
  (count + columns - 1) / columns
}

///|
fn grid_child_frames(
  columns : Int,
  row_spacing : Double,
  column_spacing : Double,
  children : Array[ElementNode],
  bounds : Rect,
) -> Array[Rect] {
  let frames : Array[Rect] = []
  if children.length() == 0 {
    frames
  } else {
    let columns = max_int(1, columns)
    let rows = grid_row_count(children.length(), columns)
    let total_column_spacing = column_spacing *
      max_int(0, columns - 1).to_double()
    let total_row_spacing = row_spacing * max_int(0, rows - 1).to_double()
    let cell_width = max_double(
      0.0,
      (bounds.size.width - total_column_spacing) / columns.to_double(),
    )
    let measured = measure_grid_size(
      columns, row_spacing, column_spacing, children,
    )
    let fallback_height = if rows > 0 {
      max_double(
        0.0,
        (bounds.size.height - total_row_spacing) / rows.to_double(),
      )
    } else {
      0.0
    }
    let cell_height = if measured.height > 0.0 {
      max_double(0.0, (measured.height - total_row_spacing) / rows.to_double())
    } else {
      fallback_height
    }
    for index, _child in children {
      let column = index - index / columns * columns
      let row = index / columns
      frames.push(
        Rect::new(
          x=bounds.origin.x + column.to_double() * (cell_width + column_spacing),
          y=bounds.origin.y + row.to_double() * (cell_height + row_spacing),
          width=cell_width,
          height=cell_height,
        ),
      )
    }
    frames
  }
}

///|
fn list_child_frames(
  spacing : Double,
  children : Array[ElementNode],
  bounds : Rect,
) -> Array[Rect] {
  let frames : Array[Rect] = []
  let mut cursor = bounds.origin.y
  for index, child in children {
    if index > 0 {
      cursor = cursor + spacing
    }
    let size = child.intrinsic_size()
    frames.push(
      Rect::new(
        x=bounds.origin.x,
        y=cursor,
        width=bounds.size.width,
        height=size.height,
      ),
    )
    cursor = cursor + size.height
  }
  frames
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
