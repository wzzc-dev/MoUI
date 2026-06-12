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

///|
pub fn[Msg, NextMsg] View::map(
  self : View[Msg],
  map : (Msg) -> NextMsg,
) -> View[NextMsg] {
  view_from_node(map_view_node(self.node, map))
}

///|
pub fn[Msg] View::key(self : View[Msg], value : String) -> View[Msg] {
  modify_view(self, KeyModifierNode(Key::new(value)))
}

///|
pub fn[Msg] View::font(self : View[Msg], font : FontSpec) -> View[Msg] {
  modify_view(self, PlainModifier(FontModifier(font)))
}

///|
pub fn[Msg] View::foreground(self : View[Msg], color : Color) -> View[Msg] {
  modify_view(self, PlainModifier(ForegroundModifier(color)))
}

///|
pub fn[Msg] View::title(self : View[Msg]) -> View[Msg] {
  let theme = Theme::default()
  self.font(theme.typography.title).foreground(theme.foreground)
}

///|
pub fn[Msg] View::caption(self : View[Msg]) -> View[Msg] {
  let theme = Theme::default()
  self.font(theme.typography.caption).foreground(theme.palette.muted)
}

///|
pub fn[Msg] View::mono(self : View[Msg]) -> View[Msg] {
  let theme = Theme::default()
  self
  .font({ ..theme.typography.body, families: FontFamilyStack::monospace() })
  .foreground(theme.foreground)
}

///|
pub fn[Msg] View::background(self : View[Msg], color : Color) -> View[Msg] {
  self.background_brush(Brush::solid(color))
}

///|
pub fn[Msg] View::background_brush(
  self : View[Msg],
  brush : Brush,
) -> View[Msg] {
  modify_view(self, PlainModifier(BackgroundModifier(brush)))
}

///|
pub fn[Msg] View::corner_radius(self : View[Msg], radius : Double) -> View[Msg] {
  modify_view(self, PlainModifier(CornerRadiusModifier(radius)))
}

///|
pub fn[Msg] View::opacity(self : View[Msg], opacity : Double) -> View[Msg] {
  modify_view(self, PlainModifier(OpacityModifier(opacity)))
}

///|
pub fn[Msg] View::shadow(self : View[Msg], style : ShadowStyle) -> View[Msg] {
  modify_view(self, PlainModifier(ShadowModifier(style)))
}

///|
pub fn[Msg] View::border(self : View[Msg], style : BorderStyle) -> View[Msg] {
  modify_view(self, PlainModifier(BorderModifier(style)))
}

///|
pub fn[Msg] View::offset(
  self : View[Msg],
  dx? : Double = 0.0,
  dy? : Double = 0.0,
) -> View[Msg] {
  modify_view(self, PlainModifier(OffsetModifier(dx, dy)))
}

///|
pub fn[Msg] View::clip(self : View[Msg]) -> View[Msg] {
  modify_view(self, PlainModifier(ClipModifier))
}

///|
pub fn[Msg] View::scale(
  self : View[Msg],
  sx? : Double = 1.0,
  sy? : Double = 1.0,
) -> View[Msg] {
  modify_view(self, PlainModifier(ScaleModifier(sx, sy)))
}

///|
pub fn[Msg] View::transition(
  self : View[Msg],
  spec? : TransitionSpec = TransitionSpec::new(),
  progress? : Double = 1.0,
  reduced_motion? : Bool = false,
) -> View[Msg] {
  self.apply_transition_style(spec.sample(progress, reduced_motion~).style)
}

///|
pub fn[Msg] View::presence(
  self : View[Msg],
  present~ : Bool,
  spec? : TransitionSpec = TransitionSpec::fade(),
  progress? : Double = 1.0,
  reduced_motion? : Bool = false,
) -> View[Msg] {
  let sample = spec.presence(present~, progress~, reduced_motion~)
  if sample.present {
    self.apply_transition_style(sample.style)
  } else {
    View::empty()
  }
}

///|
fn[Msg] View::apply_transition_style(
  self : View[Msg],
  style : TransitionStyle,
) -> View[Msg] {
  let mut view = self
  view = view.opacity(style.opacity)
  if style.offset.x != 0.0 || style.offset.y != 0.0 {
    view = view.offset(dx=style.offset.x, dy=style.offset.y)
  }
  if style.scale.x != 1.0 || style.scale.y != 1.0 {
    view = view.scale(sx=style.scale.x, sy=style.scale.y)
  }
  match style.foreground {
    Some(color) => view.foreground(color)
    None => view
  }
}

///|
pub fn[Msg] View::disabled(
  self : View[Msg],
  disabled? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(DisabledModifier(disabled)))
}

///|
pub fn[Msg] View::accessibility_label(
  self : View[Msg],
  label : String,
) -> View[Msg] {
  modify_view(self, PlainModifier(AccessibilityLabelModifier(label)))
}

///|
pub fn[Msg] View::semantics_role(
  self : View[Msg],
  role : SemanticsRole,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsRoleModifier(role)))
}

///|
pub fn[Msg] View::semantics_selected(
  self : View[Msg],
  selected? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsSelectedModifier(selected)))
}

///|
pub fn[Msg] View::semantics_pressed(
  self : View[Msg],
  pressed? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsPressedModifier(pressed)))
}

///|
pub fn[Msg] View::semantics_checked(
  self : View[Msg],
  checked? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsCheckedModifier(checked)))
}

///|
pub fn[Msg] View::semantics_expanded(
  self : View[Msg],
  expanded? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsExpandedModifier(expanded)))
}

///|
pub fn[Msg] View::semantics_invalid(
  self : View[Msg],
  invalid? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsInvalidModifier(invalid)))
}

///|
pub fn[Msg] View::semantics_required(
  self : View[Msg],
  required? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsRequiredModifier(required)))
}

///|
pub fn[Msg] View::semantics_description(
  self : View[Msg],
  description : String,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsDescriptionModifier(description)))
}

///|
pub fn[Msg] View::semantics_action(
  self : View[Msg],
  action : SemanticsAction,
) -> View[Msg] {
  modify_view(self, PlainModifier(SemanticsActionModifier(action)))
}

///|
pub fn[Msg] View::semantics_dismiss_action(self : View[Msg]) -> View[Msg] {
  self.semantics_action(SemanticsAction::Dismiss)
}

///|
pub fn[Msg] View::focusable(
  self : View[Msg],
  focusable? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(FocusableModifier(focusable)))
}

///|
pub fn[Msg] View::focus_trap(
  self : View[Msg],
  enabled? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(FocusTrapModifier(enabled)))
}

///|
pub fn[Msg] View::on_tap(self : View[Msg], message : Msg) -> View[Msg] {
  modify_view(self, TapModifier(message))
}

///|
pub fn[Msg] View::on_long_press(self : View[Msg], message : Msg) -> View[Msg] {
  modify_view(self, LongPressModifier(message))
}

///|
pub fn[Msg] View::on_double_tap(self : View[Msg], message : Msg) -> View[Msg] {
  modify_view(self, DoubleTapModifier(message))
}

///|
pub fn[Msg] View::on_drag(
  self : View[Msg],
  handler : (DragGestureEvent) -> Msg,
) -> View[Msg] {
  modify_view(self, DragModifier(handler))
}

///|
pub fn[Msg] View::on_drag_with_frame(
  self : View[Msg],
  handler : (DragGestureEvent, Rect) -> Msg,
) -> View[Msg] {
  modify_view(self, DragWithFrameModifier(handler))
}

///|
pub fn[Msg] View::on_file_drop(
  self : View[Msg],
  handler : (Array[String], Point) -> Msg,
) -> View[Msg] {
  modify_view(self, FileDropModifier(handler))
}

///|
pub fn[Msg] View::keyboard_shortcut(
  self : View[Msg],
  shortcut : KeyboardShortcut,
) -> View[Msg] {
  modify_view(self, PlainModifier(KeyboardShortcutModifier(shortcut)))
}

///|
pub fn[Msg] View::flexible(
  self : View[Msg],
  weight? : Double = 1.0,
) -> View[Msg] {
  modify_view(self, PlainModifier(FlexibleModifier(max_double(0.0, weight))))
}

///|
pub fn[Msg] View::layout_priority(
  self : View[Msg],
  priority : Double,
) -> View[Msg] {
  modify_view(self, PlainModifier(LayoutPriorityModifier(priority)))
}

///|
pub fn[Msg] View::expanded(
  self : View[Msg],
  weight? : Double = 1.0,
) -> View[Msg] {
  self.flexible(weight~)
}

///|
pub fn[Msg] View::align(
  self : View[Msg],
  alignment? : Alignment = Alignment::center(),
) -> View[Msg] {
  modify_view(self, PlainModifier(AlignModifier(alignment)))
}

///|
pub fn[Msg] View::aspect_ratio(self : View[Msg], ratio : Double) -> View[Msg] {
  modify_view(self, PlainModifier(AspectRatioModifier(max_double(0.01, ratio))))
}

///|
pub fn[Msg] View::intrinsic_width(self : View[Msg]) -> View[Msg] {
  modify_view(self, PlainModifier(IntrinsicWidthModifier))
}

///|
pub fn[Msg] View::intrinsic_height(self : View[Msg]) -> View[Msg] {
  modify_view(self, PlainModifier(IntrinsicHeightModifier))
}

///|
pub fn[Msg] View::repaint_boundary(self : View[Msg]) -> View[Msg] {
  modify_view(self, PlainModifier(RepaintBoundaryModifier))
}

///|
pub fn[Msg] View::padding(self : View[Msg], value : Double) -> View[Msg] {
  modify_view(self, PlainModifier(PaddingModifier(Insets::all(value))))
}

///|
pub fn[Msg] View::spacing(self : View[Msg], spacing : Double) -> View[Msg] {
  modify_realized_view(self, spec => spec.spacing(spacing))
}

///|
pub fn[Msg] View::main_axis_alignment(
  self : View[Msg],
  alignment : MainAxisAlignment,
) -> View[Msg] {
  modify_realized_view(self, spec => spec.main_axis_alignment(alignment))
}

///|
pub fn[Msg] View::cross_axis_alignment(
  self : View[Msg],
  alignment : CrossAxisAlignment,
) -> View[Msg] {
  modify_realized_view(self, spec => spec.cross_axis_alignment(alignment))
}

///|
pub fn[Msg] View::theme(self : View[Msg], theme : Theme) -> View[Msg] {
  modify_realized_view(self, spec => spec.theme(theme))
}

///|
pub fn[Msg] View::environment(
  self : View[Msg],
  environment : Environment,
) -> View[Msg] {
  modify_realized_view(self, spec => spec.environment(environment))
}

///|
pub fn[Msg] View::frame(
  self : View[Msg],
  width? : Double,
  height? : Double,
  min_width? : Double,
  min_height? : Double,
  max_width? : Double,
  max_height? : Double,
) -> View[Msg] {
  modify_view(
    self,
    PlainModifier(
      FrameModifier({
        width,
        height,
        min_width,
        min_height,
        max_width,
        max_height,
      }),
    ),
  )
}
