///|
pub(all) struct LayoutResult {
  frame : Rect
  children : Array[LayoutResult]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MeasuredNode {
  element_id : ElementId
  size : Size
  children : Array[MeasuredNode]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PlacedNode {
  element_id : ElementId
  frame : Rect
  children : Array[PlacedNode]
} derive(Eq, Debug, ToJson)

///|
pub fn layout_spec(spec : ViewSpec, bounds : Rect) -> LayoutResult {
  mount_view_spec(spec).place(bounds).to_layout_result()
}

///|
pub fn layout_spec_with_text_system(
  spec : ViewSpec,
  bounds : Rect,
  text_system~ : TextSystem,
) -> LayoutResult {
  mount_view_spec(spec)
  .place_with_text_system(bounds, text_system~)
  .to_layout_result()
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
pub fn ElementNode::measure(
  self : ElementNode,
  constraints : Constraints,
) -> MeasuredNode {
  self.measure_with_text_system(constraints, text_system=TextSystem::fallback())
}

///|
pub fn ElementNode::measure_with_text_system(
  self : ElementNode,
  constraints : Constraints,
  text_system~ : TextSystem,
) -> MeasuredNode {
  if !self.dirty.needs_layout &&
    self.cached_measure_constraints == Some(constraints) {
    match self.cached_measured {
      Some(measured) => return measured
      None => ()
    }
  }
  let child_constraints = child_constraints_for_measure(self.spec, constraints)
  let children : Array[MeasuredNode] = []
  for child in self.children {
    children.push(
      child.measure_with_text_system(child_constraints, text_system~),
    )
  }
  let measured = {
    element_id: self.id,
    size: constraints.constrain(
      self.measured_size_from_children(children, text_system~),
    ),
    children,
  }
  self.cached_measure_constraints = Some(constraints)
  self.cached_measured = Some(measured)
  self.dirty.needs_layout = false
  measured
}

///|
pub fn ElementNode::place(self : ElementNode, bounds : Rect) -> PlacedNode {
  self.place_with_text_system(bounds, text_system=TextSystem::fallback())
}

///|
pub fn ElementNode::place_with_text_system(
  self : ElementNode,
  bounds : Rect,
  text_system~ : TextSystem,
) -> PlacedNode {
  if !self.dirty.needs_layout && self.cached_place_frame == Some(bounds) {
    match self.cached_placed {
      Some(placed) => return placed
      None => ()
    }
  }
  let constraints = Constraints::tight(bounds.size)
  let measured = self.measure_with_text_system(constraints, text_system~)
  let placed = self.place_measured_with_text_system(
    measured,
    bounds,
    text_system~,
  )
  self.cached_place_frame = Some(bounds)
  self.cached_placed = Some(placed)
  placed
}

///|
fn ElementNode::place_measured_with_text_system(
  self : ElementNode,
  measured : MeasuredNode,
  frame : Rect,
  text_system~ : TextSystem,
) -> PlacedNode {
  let child_frames = self.child_frames_for_place(frame, text_system~)
  let children : Array[PlacedNode] = []
  for index, child in self.children {
    if index < child_frames.length() && index < measured.children.length() {
      children.push(
        child.place_measured_with_text_system(
          measured.children[index],
          child_frames[index],
          text_system~,
        ),
      )
    }
  }
  { element_id: self.id, frame, children }
}

///|
fn ElementNode::measured_size_from_children(
  self : ElementNode,
  children : Array[MeasuredNode],
  text_system~ : TextSystem,
) -> Size {
  match self.spec {
    EmptySpec => Size::new(width=0.0, height=0.0)
    TextSpec(data) => data.size
    ButtonSpec(data) => data.size
    TextFieldSpec(data) => data.size
    RichTextEditorSpec(data) => data.size
    ImageSpec(data) => data.size.unwrap_or(Size::new(width=0.0, height=0.0))
    CheckboxSpec(data) => checkbox_intrinsic_size(data)
    PickerSpec(_) => Size::new(width=200.0, height=40.0)
    DatePickerSpec(_) => Size::new(width=200.0, height=40.0)
    SearchBarSpec(_) => Size::new(width=240.0, height=40.0)
    SheetSpec(_) =>
      if children.length() > 0 {
        children[0].size.inflate(
          Insets::symmetric(horizontal=16.0, vertical=16.0),
        )
      } else {
        Size::new(width=240.0, height=200.0)
      }
    SpacerSpec(data) =>
      if data.weight > 0.0 {
        Size::new(width=0.0, height=0.0)
      } else {
        Size::new(width=data.min_length, height=data.min_length)
      }
    PaddingSpec(data) =>
      if children.length() > 0 {
        children[0].size.inflate(data.insets)
      } else {
        Size::new(width=0.0, height=0.0).inflate(data.insets)
      }
    ContainerSpec(data) =>
      match data.size {
        Some(size) => size
        None =>
          if children.length() > 0 {
            children[0].size
          } else {
            Size::new(width=0.0, height=0.0)
          }
      }
    FlexSpec(data) => measure_flex_measured(data.axis, data.spacing, children)
    FrameSpec(data) => {
      let child_size = if children.length() > 0 {
        children[0].size
      } else {
        Size::new(width=0.0, height=0.0)
      }
      resolve_frame_size(data, child_size)
    }
    StackSpec(_) => measure_stack_measured(children)
    ScrollSpec(data) =>
      match data.viewport {
        Some(size) => size
        None =>
          if children.length() > 0 {
            children[0].size
          } else {
            Size::new(width=0.0, height=0.0)
          }
      }
    GridSpec(data) =>
      measure_grid_measured(
        data.columns,
        data.row_spacing,
        data.column_spacing,
        children,
      )
    ListSpec(data) => measure_list_measured(data.spacing, children)
    ModifiedSpec(data) => modified_measured_size(data.modifier, children)
    CustomSpec(data) => (data.measure)(Constraints::unbounded())
    CustomLayoutSpec(data) =>
      (data.measure)({
        constraints: Constraints::unbounded(),
        child_sizes: children.map(child => child.size),
        child_baselines: self.children.map(child => {
          child.first_baseline(text_system~)
        }),
        child_priorities: self.children.map(child => child.layout_priority()),
        child_alignment_guides: custom_alignment_guides(
          children.map(child => child.size),
          self.children.map(child => child.first_baseline(text_system~)),
        ),
        cache: data.cache,
        cache_key: custom_layout_cache_key(
          self.spec,
          children.map(child => child.size),
        ),
        layout_direction: LayoutDirection::LeftToRight,
        safe_area: Insets::symmetric(),
        viewport: None,
      })
    ComponentSpec(_) =>
      if children.length() > 0 {
        children[0].size
      } else {
        Size::new(width=0.0, height=0.0)
      }
  }
}

///|
fn child_constraints_for_measure(
  spec : ViewSpec,
  constraints : Constraints,
) -> Constraints {
  match spec {
    PaddingSpec(data) => constraints.deflate(data.insets)
    FrameSpec(data) => frame_constraints_for_measure(data, constraints)
    ModifiedSpec(data) => modified_child_constraints(data.modifier, constraints)
    ScrollSpec(_) => Constraints::unbounded()
    ComponentSpec(_) => constraints
    _ => constraints.loosen()
  }
}

///|
fn frame_constraints_for_measure(
  data : FrameViewSpec,
  constraints : Constraints,
) -> Constraints {
  match (data.width, data.height) {
    (Some(width), Some(height)) => constraints.tighten(width~, height~).loosen()
    (Some(width), None) => constraints.tighten(width~).loosen()
    (None, Some(height)) => constraints.tighten(height~).loosen()
    (None, None) => constraints.loosen()
  }
}

///|
fn frame_modifier_constraints_for_measure(
  data : FrameModifierSpec,
  constraints : Constraints,
) -> Constraints {
  match (data.width, data.height) {
    (Some(width), Some(height)) => constraints.tighten(width~, height~).loosen()
    (Some(width), None) => constraints.tighten(width~).loosen()
    (None, Some(height)) => constraints.tighten(height~).loosen()
    (None, None) => constraints.loosen()
  }
}

///|
fn ElementNode::child_frames_for_place(
  self : ElementNode,
  frame : Rect,
  text_system~ : TextSystem,
) -> Array[Rect] {
  match self.taffy_child_frames_for_place(frame) {
    Some(frames) => return frames
    None => ()
  }
  match self.spec {
    FlexSpec(data) =>
      flex_child_frames(
        data.axis,
        data.spacing,
        data.main_axis_alignment,
        data.cross_axis_alignment,
        self.children,
        frame,
      )
    PaddingSpec(data) => [frame.inset(data.insets)]
    ContainerSpec(data) => {
      let child_frame = match data.size {
        Some(size) =>
          Rect::new(
            x=frame.origin.x,
            y=frame.origin.y,
            width=size.width,
            height=size.height,
          )
        None => frame
      }
      if self.children.length() > 0 {
        [child_frame]
      } else {
        []
      }
    }
    FrameSpec(data) => [frame_rect_for_spec(data, frame)]
    StackSpec(_) => self.children.map(_child => frame)
    ScrollSpec(data) =>
      if self.children.length() > 0 {
        [scroll_child_frame(frame, data, self.children[0])]
      } else {
        []
      }
    GridSpec(data) =>
      grid_child_frames(
        data.columns,
        data.row_spacing,
        data.column_spacing,
        self.children,
        frame,
      )
    ListSpec(data) => list_child_frames(data.spacing, self.children, frame)
    CustomLayoutSpec(data) =>
      (data.place)({
        frame,
        measured_size: frame.size,
        child_sizes: self.children.map(child => child.intrinsic_size()),
        child_baselines: self.children.map(child => {
          child.first_baseline(text_system~)
        }),
        child_priorities: self.children.map(child => child.layout_priority()),
        child_alignment_guides: custom_alignment_guides(
          self.children.map(child => child.intrinsic_size()),
          self.children.map(child => child.first_baseline(text_system~)),
        ),
        cache: data.cache,
        cache_key: custom_layout_cache_key(
          self.spec,
          self.children.map(child => child.intrinsic_size()),
        ),
        layout_direction: LayoutDirection::LeftToRight,
        safe_area: Insets::symmetric(),
        viewport: Some(frame.size),
      })
    ModifiedSpec(data) => modified_child_frames(data.modifier, frame)
    ComponentSpec(_) => if self.children.length() > 0 { [frame] } else { [] }
    _ => []
  }
}

///|
fn scroll_child_frame(
  frame : Rect,
  data : ScrollViewSpec,
  child : ElementNode,
) -> Rect {
  let viewport = data.viewport.unwrap_or(frame.size)
  let child_size = child.intrinsic_size()
  Rect::new(
    x=frame.origin.x - data.offset.x,
    y=frame.origin.y - data.offset.y,
    width=max_double(viewport.width, child_size.width),
    height=max_double(viewport.height, child_size.height),
  )
}

///|
fn modified_measured_size(
  modifier : ViewModifier,
  children : Array[MeasuredNode],
) -> Size {
  let child_size = if children.length() > 0 {
    children[0].size
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
    | OnFileDropModifier(_)
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
fn modified_child_constraints(
  modifier : ViewModifier,
  constraints : Constraints,
) -> Constraints {
  match modifier {
    PaddingModifier(insets) => constraints.deflate(insets)
    FrameModifier(data) =>
      frame_modifier_constraints_for_measure(data, constraints)
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
    | OnFileDropModifier(_)
    | KeyboardShortcutModifier(_)
    | FlexibleModifier(_)
    | LayoutPriorityModifier(_)
    | AlignModifier(_)
    | AspectRatioModifier(_)
    | IntrinsicWidthModifier
    | IntrinsicHeightModifier => constraints.loosen()
  }
}

///|
fn modified_child_frames(modifier : ViewModifier, frame : Rect) -> Array[Rect] {
  match modifier {
    PaddingModifier(insets) => [frame.inset(insets)]
    FrameModifier(data) => [frame_rect_for_modifier(data, frame)]
    BackgroundModifier(_)
    | ForegroundModifier(_)
    | FontModifier(_)
    | CornerRadiusModifier(_)
    | OpacityModifier(_)
    | ShadowModifier(_)
    | BorderModifier(_)
    | ClipModifier
    | ScaleModifier(_, _)
    | DisabledModifier(_)
    | AccessibilityLabelModifier(_)
    | SemanticsRoleModifier(_)
    | FocusableModifier(_)
    | OnTapModifier(_)
    | OnFileDropModifier(_)
    | KeyboardShortcutModifier(_)
    | FlexibleModifier(_)
    | LayoutPriorityModifier(_)
    | AlignModifier(_)
    | IntrinsicWidthModifier
    | IntrinsicHeightModifier => [frame]
    OffsetModifier(dx, dy) => [frame.offset(dx~, dy~)]
    AspectRatioModifier(ratio) => [aspect_ratio_rect(frame, ratio)]
  }
}

///|
fn aspect_ratio_size(size : Size, ratio : Double) -> Size {
  if size.width > 0.0 {
    Size::new(width=size.width, height=size.width / ratio)
  } else if size.height > 0.0 {
    Size::new(width=size.height * ratio, height=size.height)
  } else {
    size
  }
}

///|
fn aspect_ratio_rect(frame : Rect, ratio : Double) -> Rect {
  let target = aspect_ratio_size(frame.size, ratio).clamp(
    Constraints::loose(frame.size),
  )
  Rect::new(
    x=frame.origin.x,
    y=frame.origin.y,
    width=target.width,
    height=target.height,
  )
}

///|
fn measure_flex_measured(
  axis : Axis,
  spacing : Double,
  children : Array[MeasuredNode],
) -> Size {
  let mut main = 0.0
  let mut cross = 0.0
  for index, child in children {
    match axis {
      Axis::Horizontal => {
        main = main + child.size.width
        cross = max_double(cross, child.size.height)
      }
      Axis::Vertical => {
        main = main + child.size.height
        cross = max_double(cross, child.size.width)
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
fn measure_stack_measured(children : Array[MeasuredNode]) -> Size {
  let mut width = 0.0
  let mut height = 0.0
  for child in children {
    width = max_double(width, child.size.width)
    height = max_double(height, child.size.height)
  }
  Size::new(width~, height~)
}

///|
fn measure_grid_measured(
  columns : Int,
  row_spacing : Double,
  column_spacing : Double,
  children : Array[MeasuredNode],
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
      cell_width = max_double(cell_width, child.size.width)
      cell_height = max_double(cell_height, child.size.height)
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
fn measure_list_measured(
  spacing : Double,
  children : Array[MeasuredNode],
) -> Size {
  let mut width = 0.0
  let mut height = 0.0
  for index, child in children {
    width = max_double(width, child.size.width)
    height = height + child.size.height
    if index > 0 {
      height = height + spacing
    }
  }
  Size::new(width~, height~)
}

///|
pub fn PlacedNode::to_layout_result(self : PlacedNode) -> LayoutResult {
  {
    frame: self.frame,
    children: self.children.map(child => child.to_layout_result()),
  }
}
