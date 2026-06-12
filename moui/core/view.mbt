///|
pub struct View[Msg] {
  priv node : ViewNode[Msg]
}

///|
enum ViewNode[Msg] {
  EmptyNode
  TextNode(TextViewSpec)
  ButtonNode(ButtonViewSpec, Msg?)
  TextFieldNode(TextFieldViewSpec, Msg?)
  ControlledTextFieldNode(ControlledTextFieldViewData[Msg])
  RichTextEditorNode(
    RichTextEditorViewSpec,
    ((Int, TextRange?) -> Msg)?,
    ((Int) -> Msg)?
  )
  ControlledRichTextEditorNode(ControlledRichTextEditorViewData[Msg])
  ImageNode(ImageViewSpec)
  CheckboxNode(CheckboxViewSpec)
  ControlledCheckboxNode(ControlledCheckboxViewData[Msg])
  PickerNode(PickerViewSpec)
  ControlledPickerNode(ControlledPickerViewData[Msg])
  DatePickerNode(DatePickerViewSpec)
  ControlledDatePickerNode(ControlledDatePickerViewData[Msg])
  SearchBarNode(SearchBarViewSpec, Msg?, Msg?)
  ControlledSearchBarNode(ControlledSearchBarViewData[Msg])
  WebViewNode(WebViewSpec, ((WebViewEvent) -> Msg)?)
  SheetNode(SheetViewSpec, ViewNode[Msg], Msg?)
  FlexNode(FlexViewSpec, Array[ViewNode[Msg]])
  PaddingNode(PaddingViewSpec, ViewNode[Msg])
  ContainerNode(ContainerViewSpec, ViewNode[Msg]?)
  SpacerNode(SpacerViewSpec)
  FrameNode(FrameViewSpec, ViewNode[Msg])
  StackNode(StackViewSpec, Array[ViewNode[Msg]])
  ScrollNode(ScrollViewSpec, ViewNode[Msg], ScrollState?, ((Point) -> Msg)?)
  GridNode(GridViewSpec, Array[ViewNode[Msg]])
  ListNode(ListViewSpec, Array[ViewNode[Msg]])
  ModifiedNode(ViewModifierNode[Msg], ViewNode[Msg])
  CustomNode(CustomViewSpec)
  CustomLayoutNode(CustomLayoutSpec, Array[ViewNode[Msg]])
  ComponentNode((BuildContext) -> View[Msg])
}

///|
priv struct ControlledTextFieldViewData[Msg] {
  key : Key?
  value : String
  placeholder : String
  size : Size
  font : FontSpec
  foreground : Color
  placeholder_color : Color
  background : Brush
  border : BorderStyle?
  focused_border : BorderStyle?
  cursor_color : Color
  corner_radius : Double
  on_input : (String) -> Msg
  on_submit : Msg?
}

///|
priv struct ControlledRichTextEditorViewData[Msg] {
  key : Key?
  value : String
  placeholder : String
  size : Size
  format : RichTextFormatter
  font : FontSpec
  foreground : Color
  placeholder_color : Color
  background : Brush
  border : BorderStyle?
  focused_border : BorderStyle?
  cursor_color : Color
  corner_radius : Double
  on_input : (String) -> Msg
  on_selection_change : ((Int, TextRange?) -> Msg)?
  on_prefix_click : ((Int) -> Msg)?
  input_transform : ((String, Int, TextRange?, String) -> RichTextInputTransform?)?
  accepts_tab_input : Bool
}

///|
priv struct ControlledCheckboxViewData[Msg] {
  key : Key?
  label : String
  checked : Bool
  font : FontSpec
  foreground : Color
  check_color : Color
  size : Size
  on_change : (Bool) -> Msg
}

///|
priv struct ControlledPickerViewData[Msg] {
  key : Key?
  items : Array[PickerItem]
  selected : String
  placeholder : String
  font : FontSpec
  foreground : Color
  background : Brush
  cornerRadius : Double
  maxHeight : Double
  on_select : (String) -> Msg
}

///|
priv struct ControlledDatePickerViewData[Msg] {
  key : Key?
  selected : DateValue
  mode : DatePickerMode
  placeholder : String
  font : FontSpec
  foreground : Color
  background : Brush
  corner_radius : Double
  min_date : DateValue?
  max_date : DateValue?
  on_select : (DateValue) -> Msg
}

///|
priv struct ControlledSearchBarViewData[Msg] {
  key : Key?
  query : String
  placeholder : String
  font : FontSpec
  foreground : Color
  placeholder_color : Color
  background : Brush
  border : BorderStyle?
  focused_border : BorderStyle?
  cursor_color : Color
  corner_radius : Double
  on_input : (String) -> Msg
  on_submit : Msg?
  on_clear : Msg?
}

///|
priv enum ViewModifierNode[Msg] {
  KeyModifierNode(Key)
  PlainModifier(ViewModifier)
  RealizedModifier((ViewSpec) -> ViewSpec)
  TapModifier(Msg)
  LongPressModifier(Msg)
  DoubleTapModifier(Msg)
  DragModifier((DragGestureEvent) -> Msg)
  DragWithFrameModifier((DragGestureEvent, Rect) -> Msg)
  FileDropModifier((Array[String], Point) -> Msg)
}

///|
fn[Msg] view_from_node(node : ViewNode[Msg]) -> View[Msg] {
  { node, }
}

///|
fn[Msg] modify_view(
  view : View[Msg],
  modifier : ViewModifierNode[Msg],
) -> View[Msg] {
  view_from_node(ModifiedNode(modifier, view.node))
}

///|
fn[Msg] modify_realized_view(
  view : View[Msg],
  modifier : (ViewSpec) -> ViewSpec,
) -> View[Msg] {
  modify_view(view, RealizedModifier(modifier))
}

///|
pub fn[Msg] View::empty() -> View[Msg] {
  view_from_node(EmptyNode)
}

///|
pub fn[Msg] View::text(
  text~ : String,
  size~ : Size,
  font~ : FontSpec,
  color~ : Color,
) -> View[Msg] {
  view_from_node(TextNode({ key: None, text, size, font, color }))
}

///|
pub fn[Msg] View::button(
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
pub fn[Msg] View::image(
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
pub fn[Msg] View::web_view(
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
pub fn[Msg] View::checkbox(
  label~ : String,
  checked~ : Binding[Bool],
  font~ : FontSpec,
  foreground~ : Color,
  check_color~ : Color,
  size~ : Size,
) -> View[Msg] {
  view_from_node(
    CheckboxNode({
      key: None,
      label,
      checked,
      font,
      foreground,
      check_color,
      size,
    }),
  )
}

///|
pub fn[Msg] View::controlled_checkbox(
  label~ : String,
  checked~ : Bool,
  on_change~ : (Bool) -> Msg,
  font~ : FontSpec,
  foreground~ : Color,
  check_color~ : Color,
  size~ : Size,
) -> View[Msg] {
  view_from_node(
    ControlledCheckboxNode({
      key: None,
      label,
      checked,
      font,
      foreground,
      check_color,
      size,
      on_change,
    }),
  )
}

///|
pub fn[Msg] View::text_field(
  value~ : Binding[String],
  placeholder~ : String,
  size~ : Size,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius? : Double = 0.0,
  on_submit? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    TextFieldNode(
      {
        key: None,
        value,
        placeholder,
        size,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        on_submit: None,
      },
      on_submit,
    ),
  )
}

///|
pub fn[Msg] View::controlled_text_field(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : Size,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius? : Double = 0.0,
  on_submit? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    ControlledTextFieldNode({
      key: None,
      value,
      placeholder,
      size,
      font,
      foreground,
      placeholder_color,
      background,
      border,
      focused_border,
      cursor_color,
      corner_radius,
      on_input,
      on_submit,
    }),
  )
}

///|
pub fn[Msg] View::rich_text_editor(
  value~ : Binding[String],
  placeholder~ : String,
  size~ : Size,
  format~ : RichTextFormatter,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius? : Double = 0.0,
  on_selection_change? : ((Int, TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
) -> View[Msg] {
  view_from_node(
    RichTextEditorNode(
      {
        key: None,
        value,
        placeholder,
        size,
        format,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        on_selection_change: None,
        on_prefix_click: None,
        input_transform,
        accepts_tab_input,
      },
      on_selection_change,
      on_prefix_click,
    ),
  )
}

///|
pub fn[Msg] View::controlled_rich_text_editor(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : Size,
  format~ : RichTextFormatter,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius? : Double = 0.0,
  on_selection_change? : ((Int, TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
) -> View[Msg] {
  view_from_node(
    ControlledRichTextEditorNode({
      key: None,
      value,
      placeholder,
      size,
      format,
      font,
      foreground,
      placeholder_color,
      background,
      border,
      focused_border,
      cursor_color,
      corner_radius,
      on_input,
      on_selection_change,
      on_prefix_click,
      input_transform,
      accepts_tab_input,
    }),
  )
}

///|
pub fn[Msg] View::picker(
  items~ : Array[PickerItem],
  selected~ : Binding[String],
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  corner_radius~ : Double,
  max_height~ : Double,
) -> View[Msg] {
  view_from_node(
    PickerNode({
      key: None,
      items,
      selected,
      placeholder,
      font,
      foreground,
      background,
      cornerRadius: corner_radius,
      maxHeight: max_height,
    }),
  )
}

///|
pub fn[Msg] View::controlled_picker(
  items~ : Array[PickerItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  corner_radius~ : Double,
  max_height~ : Double,
) -> View[Msg] {
  view_from_node(
    ControlledPickerNode({
      key: None,
      items,
      selected,
      placeholder,
      font,
      foreground,
      background,
      cornerRadius: corner_radius,
      maxHeight: max_height,
      on_select,
    }),
  )
}

///|
pub fn[Msg] View::datepicker(
  selected~ : Binding[DateValue],
  mode~ : DatePickerMode,
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  corner_radius~ : Double,
  min_date? : DateValue? = None,
  max_date? : DateValue? = None,
) -> View[Msg] {
  view_from_node(
    DatePickerNode({
      key: None,
      selected,
      mode,
      placeholder,
      font,
      foreground,
      background,
      corner_radius,
      min_date,
      max_date,
    }),
  )
}

///|
pub fn[Msg] View::controlled_datepicker(
  selected~ : DateValue,
  on_select~ : (DateValue) -> Msg,
  mode~ : DatePickerMode,
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  corner_radius~ : Double,
  min_date? : DateValue? = None,
  max_date? : DateValue? = None,
) -> View[Msg] {
  view_from_node(
    ControlledDatePickerNode({
      key: None,
      selected,
      mode,
      placeholder,
      font,
      foreground,
      background,
      corner_radius,
      min_date,
      max_date,
      on_select,
    }),
  )
}

///|
pub fn[Msg] View::search_bar(
  query~ : Binding[String],
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius~ : Double,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    SearchBarNode(
      {
        key: None,
        query,
        placeholder,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        on_submit: None,
        on_clear: None,
      },
      on_submit,
      on_clear,
    ),
  )
}

///|
pub fn[Msg] View::controlled_search_bar(
  query~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius~ : Double,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    ControlledSearchBarNode({
      key: None,
      query,
      placeholder,
      font,
      foreground,
      placeholder_color,
      background,
      border,
      focused_border,
      cursor_color,
      corner_radius,
      on_input,
      on_submit,
      on_clear,
    }),
  )
}

///|
pub fn[Msg] View::flex(
  children~ : Array[View[Msg]],
  axis~ : Axis,
  spacing? : Double = 0.0,
  main_axis_alignment? : MainAxisAlignment = MainAxisAlignment::MainStart,
  cross_axis_alignment? : CrossAxisAlignment = CrossAxisAlignment::CrossStretch,
) -> View[Msg] {
  view_from_node(
    FlexNode(
      {
        key: None,
        axis,
        spacing,
        main_axis_alignment,
        cross_axis_alignment,
        children: [],
      },
      children.map(child => child.node),
    ),
  )
}

///|
pub fn[Msg] View::padding_insets(
  child~ : View[Msg],
  insets~ : Insets,
) -> View[Msg] {
  view_from_node(
    PaddingNode({ key: None, insets, child: EmptySpec }, child.node),
  )
}

///|
pub fn[Msg] View::container(
  child? : View[Msg]? = None,
  size? : Size? = None,
  background? : Brush? = None,
  border? : BorderStyle? = None,
  corner_radius? : Double = 0.0,
  shadow? : ShadowStyle? = None,
) -> View[Msg] {
  view_from_node(
    ContainerNode(
      {
        key: None,
        size,
        background,
        border,
        corner_radius,
        shadow,
        child: None,
      },
      match child {
        Some(child) => Some(child.node)
        None => None
      },
    ),
  )
}

///|
pub fn[Msg] View::spacer(
  min_length? : Double = 0.0,
  weight? : Double = 1.0,
) -> View[Msg] {
  view_from_node(SpacerNode({ key: None, min_length, weight }))
}

///|
pub fn[Msg] View::frame_node(
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
      {
        key: None,
        width,
        height,
        min_width,
        min_height,
        max_width,
        max_height,
        child: EmptySpec,
      },
      child.node,
    ),
  )
}

///|
pub fn[Msg] View::stack(children~ : Array[View[Msg]]) -> View[Msg] {
  view_from_node(
    StackNode({ key: None, children: [] }, children.map(child => child.node)),
  )
}

///|
pub fn[Msg] View::scroll(
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
        child: EmptySpec,
      },
      child.node,
      state,
      on_scroll,
    ),
  )
}

///|
pub fn[Msg] View::grid(
  children~ : Array[View[Msg]],
  columns? : Int = 1,
  row_spacing? : Double = 0.0,
  column_spacing? : Double = 0.0,
) -> View[Msg] {
  view_from_node(
    GridNode(
      { key: None, columns, row_spacing, column_spacing, children: [] },
      children.map(child => child.node),
    ),
  )
}

///|
pub fn[Msg] View::list(
  children~ : Array[View[Msg]],
  spacing? : Double = 0.0,
) -> View[Msg] {
  view_from_node(
    ListNode(
      { key: None, spacing, children: [] },
      children.map(child => child.node),
    ),
  )
}

///|
pub fn[Msg] View::sheet(
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
        content: EmptySpec,
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
pub fn[Msg] View::custom_view(
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
pub fn[Msg] View::custom_children_layout(
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
        children: [],
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
pub fn[Msg] View::component(build : (BuildContext) -> View[Msg]) -> View[Msg] {
  view_from_node(ComponentNode(build))
}

///|
fn[Msg] realize_view(view : View[Msg], emit : (Msg) -> Unit) -> ViewSpec {
  realize_view_node(view.node, emit)
}
