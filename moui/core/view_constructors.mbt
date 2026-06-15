///|
pub fn[Msg] View::primitive_empty_view() -> View[Msg] {
  view_from_node(EmptyNode)
}

///|
pub fn[Msg] View::primitive_text_view(
  text~ : String,
  size~ : Size,
  font~ : FontSpec,
  color~ : Color,
) -> View[Msg] {
  view_from_node(TextNode({ key: None, text, size, font, color }))
}

///|
pub fn[Msg] View::primitive_button_view(
  text~ : String,
  size~ : Size,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  hovered_background~ : Brush,
  pressed_background~ : Brush,
  border? : BorderStyle? = None,
  shadow? : ShadowStyle? = None,
  corner_radius? : Double = 0.0,
  on_click? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    ButtonNode(
      {
        key: None,
        text,
        size,
        font,
        foreground,
        background,
        hovered_background,
        pressed_background,
        border,
        shadow,
        corner_radius,
        on_click: None,
      },
      on_click,
    ),
  )
}

///|
pub fn[Msg] View::primitive_image_view(
  source~ : String,
  size? : Size? = None,
  opacity? : Double = 1.0,
  corner_radius? : Double = 0.0,
  fit? : ImageFit = ImageFit::Contain,
) -> View[Msg] {
  view_from_node(
    ImageNode({ key: None, source, size, opacity, corner_radius, fit }),
  )
}

///|
pub fn[Msg] View::primitive_web_view(
  id~ : String,
  url~ : String,
  width? : Double? = None,
  height? : Double? = None,
  title? : String = "",
  policy? : WebViewNavigationPolicy = WebViewNavigationPolicy::AllowHttpHttpsFile,
  on_event? : ((WebViewEvent) -> Msg)? = None,
) -> View[Msg] {
  view_from_node(
    WebViewNode(
      WebViewSpec::new(id~, url~, width~, height~, title~, policy~),
      on_event,
    ),
  )
}

///|
pub fn[Msg] View::primitive_flex_view(
  children~ : Array[View[Msg]],
  axis~ : Axis,
  spacing? : Double = 0.0,
  main_axis_alignment? : MainAxisAlignment = MainAxisAlignment::MainStart,
  cross_axis_alignment? : CrossAxisAlignment = CrossAxisAlignment::CrossStretch,
) -> View[Msg] {
  view_from_node(
    FlexNode(
      { key: None, axis, spacing, main_axis_alignment, cross_axis_alignment },
      children.map(child => child.node),
    ),
  )
}

///|
pub fn[Msg] View::primitive_padding_insets_view(
  child~ : View[Msg],
  insets~ : Insets,
) -> View[Msg] {
  view_from_node(PaddingNode({ key: None, insets }, child.node))
}

///|
pub fn[Msg] View::primitive_container_view(
  child? : View[Msg]? = None,
  size? : Size? = None,
  background? : Brush? = None,
  border? : BorderStyle? = None,
  corner_radius? : Double = 0.0,
  shadow? : ShadowStyle? = None,
) -> View[Msg] {
  view_from_node(
    ContainerNode(
      { key: None, size, background, border, corner_radius, shadow },
      match child {
        Some(child) => Some(child.node)
        None => None
      },
    ),
  )
}

///|
pub fn[Msg] View::primitive_spacer_view(
  min_length? : Double = 0.0,
  weight? : Double = 1.0,
) -> View[Msg] {
  view_from_node(SpacerNode({ key: None, min_length, weight }))
}

///|
pub fn[Msg] View::primitive_frame_view(
  child~ : View[Msg],
  width~ : Double?,
  height~ : Double?,
  min_width~ : Double?,
  min_height~ : Double?,
  max_width~ : Double?,
  max_height~ : Double?,
) -> View[Msg] {
  view_from_node(
    FrameNode(
      { key: None, width, height, min_width, min_height, max_width, max_height },
      child.node,
    ),
  )
}

///|
pub fn[Msg] View::primitive_stack_view(
  children~ : Array[View[Msg]],
) -> View[Msg] {
  view_from_node(StackNode({ key: None }, children.map(child => child.node)))
}

///|
pub fn[Msg] View::primitive_scroll_view(
  child~ : View[Msg],
  offset? : Point = Point::new(x=0.0, y=0.0),
  viewport? : Size? = None,
  state? : ScrollState? = None,
  on_scroll? : ((Point) -> Msg)? = None,
) -> View[Msg] {
  view_from_node(
    ScrollNode(
      {
        key: None,
        offset,
        viewport,
        on_scroll: None,
        scroll_state: None,
        scroll_activates: false,
      },
      child.node,
      state,
      on_scroll,
    ),
  )
}

///|
pub fn[Msg] View::primitive_grid_view(
  children~ : Array[View[Msg]],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> View[Msg] {
  view_from_node(
    GridNode(
      { key: None, columns, row_spacing, column_spacing },
      children.map(child => child.node),
    ),
  )
}

///|
pub fn[Msg] View::primitive_list_view(
  children~ : Array[View[Msg]],
  spacing? : Double = 0.0,
) -> View[Msg] {
  view_from_node(
    ListNode({ key: None, spacing }, children.map(child => child.node)),
  )
}

///|
pub fn[Msg] View::primitive_sheet_view(
  content~ : View[Msg],
  presentation_mode~ : SheetPresentationMode,
  background~ : Brush,
  corner_radius~ : Double,
  shadow? : ShadowStyle? = None,
  on_dismiss? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    SheetNode(
      {
        key: None,
        presentation_mode,
        background,
        corner_radius,
        shadow,
        on_dismiss: None,
      },
      content.node,
      on_dismiss,
    ),
  )
}

///|
pub fn[Msg] View::primitive_custom_view(
  measure~ : (Constraints) -> Size,
  paint~ : (Rect) -> Array[DrawCommand],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> View[Msg] {
  view_from_node(
    CustomNode({ key: None, measure, paint, semantics_role, semantics_label }),
  )
}

///|
pub fn[Msg] View::primitive_custom_children_layout_view(
  children~ : Array[View[Msg]],
  measure~ : (CustomLayoutContext) -> Size,
  place~ : (CustomPlacementContext) -> Array[Rect],
  paint? : (Rect) -> Array[DrawCommand] = _frame => [],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> View[Msg] {
  view_from_node(
    CustomLayoutNode(
      {
        key: None,
        cache: CustomLayoutCache::new(),
        measure,
        place,
        paint,
        semantics_role,
        semantics_label,
      },
      children.map(child => child.node),
    ),
  )
}

///|
pub fn[Msg] View::primitive_component_view(
  build : (BuildContext) -> View[Msg],
) -> View[Msg] {
  view_from_node(ComponentNode(build))
}
