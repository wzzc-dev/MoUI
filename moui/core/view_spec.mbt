///|
pub(all) enum MainAxisAlignment {
  MainStart
  MainCenter
  MainEnd
  SpaceBetween
  SpaceAround
  SpaceEvenly
} derive(Eq, Debug, ToJson)

///|
pub(all) enum CrossAxisAlignment {
  CrossStart
  CrossCenter
  CrossEnd
  CrossStretch
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Alignment {
  x : Double
  y : Double
} derive(Eq, Debug, ToJson)

///|
type ClickHandler = () -> Unit

///|
type FileDropHandler = (Array[String], Point) -> Unit

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
  RichTextEditorNode(
    RichTextEditorViewSpec,
    ((Int, TextRange?) -> Msg)?,
    ((Int) -> Msg)?
  )
  ImageNode(ImageViewSpec)
  CheckboxNode(CheckboxViewSpec)
  PickerNode(PickerViewSpec)
  DatePickerNode(DatePickerViewSpec)
  SearchBarNode(SearchBarViewSpec, Msg?, Msg?)
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
priv enum ViewModifierNode[Msg] {
  KeyModifierNode(Key)
  PlainModifier(ViewModifier)
  RealizedModifier((ViewSpec) -> ViewSpec)
  TapModifier(Msg)
  FileDropModifier((Array[String], Point) -> Msg)
}

///|
pub(all) struct KeyboardShortcut {
  key : String
  modifiers : KeyModifiers
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ButtonState {
  Normal
  Hovered
  Pressed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ViewStyle {
  font : FontSpec?
  foreground : Color?
  background : Brush?
  corner_radius : Double?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ImageFit {
  Contain
  Cover
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShadowStyle {
  color : Color
  offset : Point
  blur_radius : Double
  spread : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct BorderStyle {
  brush : Brush
  width : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct VisualStyle {
  background : Brush?
  foreground : Color?
  border : BorderStyle?
  shadow : ShadowStyle?
  radius : Double?
  opacity : Double?
} derive(Eq, Debug, ToJson)

///|
priv struct TextViewSpec {
  key : Key?
  text : String
  size : Size
  font : FontSpec
  color : Color
}

///|
priv struct ButtonViewSpec {
  key : Key?
  text : String
  size : Size
  font : FontSpec
  foreground : Color
  background : Brush
  hovered_background : Brush
  pressed_background : Brush
  border : BorderStyle?
  shadow : ShadowStyle?
  corner_radius : Double
  on_click : ClickHandler?
}

///|
priv struct TextFieldViewSpec {
  key : Key?
  value : Binding[String]
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
  on_submit : (() -> Unit)?
}

///|
pub type RichTextFormatter = (String) -> RichTextDocument

///|
pub(all) struct RichTextInputTransform {
  text : String
  caret : Int
  selection : TextRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextSourceRange {
  start : Int
  end : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RichTextDecoration {
  Strikethrough
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextRun {
  text : String
  visual_text : String?
  image_source : String?
  image_size : Size?
  image_fit : ImageFit
  font : FontSpec?
  color : Color?
  background : Brush?
  background_radius : Double
  decoration : RichTextDecoration?
  source_range : RichTextSourceRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextTableCell {
  text : String
  header : Bool
  align : TextAlign?
  source_range : RichTextSourceRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextTable {
  rows : Array[Array[RichTextTableCell]]
  row_height : Double
  cell_padding : Insets
  border : Color
  header_background : Brush?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextBlock {
  runs : Array[RichTextRun]
  table : RichTextTable?
  prefix : String
  font : FontSpec?
  color : Color?
  background : Brush?
  border_left : BorderStyle?
  inset : Insets
  line_height : Double?
  corner_radius : Double
  rule : Bool
  source_range : RichTextSourceRange?
  content_range : RichTextSourceRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextDocument {
  blocks : Array[RichTextBlock]
} derive(Eq, Debug, ToJson)

///|
priv struct RichTextEditorViewSpec {
  key : Key?
  value : Binding[String]
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
  on_selection_change : ((Int, TextRange?) -> Unit)?
  on_prefix_click : ((Int) -> Unit)?
  input_transform : ((String, Int, TextRange?, String) -> RichTextInputTransform?)?
  accepts_tab_input : Bool
}

///|
priv struct ImageViewSpec {
  key : Key?
  source : String
  size : Size?
  opacity : Double
  corner_radius : Double
  fit : ImageFit
}

///|
priv struct CheckboxViewSpec {
  key : Key?
  label : String
  checked : Binding[Bool]
  font : FontSpec
  foreground : Color
  check_color : Color
  size : Size
}

///|
priv struct FlexViewSpec {
  key : Key?
  axis : Axis
  spacing : Double
  main_axis_alignment : MainAxisAlignment
  cross_axis_alignment : CrossAxisAlignment
  children : Array[ViewSpec]
}

///|
priv struct PaddingViewSpec {
  key : Key?
  insets : Insets
  child : ViewSpec
}

///|
priv struct ContainerViewSpec {
  key : Key?
  size : Size?
  background : Brush?
  border : BorderStyle?
  corner_radius : Double
  shadow : ShadowStyle?
  child : ViewSpec?
}

///|
priv struct SpacerViewSpec {
  key : Key?
  min_length : Double
  weight : Double
}

///|
priv struct FrameViewSpec {
  key : Key?
  width : Double?
  height : Double?
  min_width : Double?
  min_height : Double?
  max_width : Double?
  max_height : Double?
  child : ViewSpec
}

///|
priv struct StackViewSpec {
  key : Key?
  children : Array[ViewSpec]
}

///|
priv struct ScrollViewSpec {
  key : Key?
  offset : Point
  viewport : Size?
  on_scroll : ((Point) -> Unit)?
  child : ViewSpec
}

///|
priv struct GridViewSpec {
  key : Key?
  columns : Int
  row_spacing : Double
  column_spacing : Double
  children : Array[ViewSpec]
}

///|
priv struct ListViewSpec {
  key : Key?
  spacing : Double
  children : Array[ViewSpec]
}

///|
priv struct FrameModifierSpec {
  width : Double?
  height : Double?
  min_width : Double?
  min_height : Double?
  max_width : Double?
  max_height : Double?
}

///|
priv enum ViewModifier {
  PaddingModifier(Insets)
  FrameModifier(FrameModifierSpec)
  BackgroundModifier(Brush)
  ForegroundModifier(Color)
  FontModifier(FontSpec)
  CornerRadiusModifier(Double)
  OpacityModifier(Double)
  ShadowModifier(ShadowStyle)
  BorderModifier(BorderStyle)
  OffsetModifier(Double, Double)
  ClipModifier
  ScaleModifier(Double, Double)
  DisabledModifier(Bool)
  AccessibilityLabelModifier(String)
  SemanticsRoleModifier(SemanticsRole)
  FocusableModifier(Bool)
  OnTapModifier(ClickHandler)
  OnFileDropModifier(FileDropHandler)
  KeyboardShortcutModifier(KeyboardShortcut)
  FlexibleModifier(Double)
  LayoutPriorityModifier(Double)
  AlignModifier(Alignment)
  AspectRatioModifier(Double)
  IntrinsicWidthModifier
  IntrinsicHeightModifier
}

///|
priv struct ModifiedViewSpec {
  key : Key?
  modifier : ViewModifier
  child : ViewSpec
}

///|
priv struct CustomViewSpec {
  key : Key?
  measure : (Constraints) -> Size
  paint : (Rect) -> Array[DrawCommand]
  semantics_role : SemanticsRole
  semantics_label : String
}

///|
pub(all) struct CustomLayoutCacheEntry {
  key : String
  mut value : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct CustomLayoutCache {
  mut entries : Array[CustomLayoutCacheEntry]
}

///|
pub(all) struct AlignmentGuideSet {
  leading : Double
  center : Double
  trailing : Double
  first_baseline : Double?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct CustomLayoutContext {
  constraints : Constraints
  child_sizes : Array[Size]
  child_baselines : Array[Double?]
  child_priorities : Array[Double]
  child_alignment_guides : Array[AlignmentGuideSet]
  cache : CustomLayoutCache
  cache_key : String
  layout_direction : LayoutDirection
  safe_area : Insets
  viewport : Size?
}

///|
pub(all) struct CustomPlacementContext {
  frame : Rect
  measured_size : Size
  child_sizes : Array[Size]
  child_baselines : Array[Double?]
  child_priorities : Array[Double]
  child_alignment_guides : Array[AlignmentGuideSet]
  cache : CustomLayoutCache
  cache_key : String
  layout_direction : LayoutDirection
  safe_area : Insets
  viewport : Size?
}

///|
priv struct CustomLayoutSpec {
  key : Key?
  children : Array[ViewSpec]
  cache : CustomLayoutCache
  measure : (CustomLayoutContext) -> Size
  place : (CustomPlacementContext) -> Array[Rect]
  paint : (Rect) -> Array[DrawCommand]
  semantics_role : SemanticsRole
  semantics_label : String
}

///|
priv struct ComponentViewSpec {
  key : Key?
  component : Component
}

///|
pub(all) struct PickerItem {
  id : String
  label : String
}

///|
priv struct PickerViewSpec {
  key : Key?
  items : Array[PickerItem]
  selected : Binding[String]
  placeholder : String
  font : FontSpec
  foreground : Color
  background : Brush
  cornerRadius : Double
  maxHeight : Double
}

///|
pub(all) enum DatePickerMode {
  Date
  DateAndTime
  Time
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DateValue {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
} derive(Eq, Debug, ToJson)

///|
priv struct DatePickerViewSpec {
  key : Key?
  selected : Binding[DateValue]
  mode : DatePickerMode
  placeholder : String
  font : FontSpec
  foreground : Color
  background : Brush
  corner_radius : Double
  min_date : DateValue?
  max_date : DateValue?
}

///|
priv struct SearchBarViewSpec {
  key : Key?
  query : Binding[String]
  placeholder : String
  font : FontSpec
  foreground : Color
  placeholder_color : Color
  background : Brush
  border : BorderStyle?
  focused_border : BorderStyle?
  cursor_color : Color
  corner_radius : Double
  on_submit : (() -> Unit)?
  on_clear : (() -> Unit)?
}

///|
pub(all) enum SheetPresentationMode {
  Modal
  BottomSheet
} derive(Eq, Debug, ToJson)

///|
priv struct SheetViewSpec {
  key : Key?
  content : ViewSpec
  presentation_mode : SheetPresentationMode
  background : Brush
  corner_radius : Double
  shadow : ShadowStyle?
  on_dismiss : (() -> Unit)?
}

///|
priv enum ViewSpec {
  EmptySpec
  TextSpec(TextViewSpec)
  ButtonSpec(ButtonViewSpec)
  TextFieldSpec(TextFieldViewSpec)
  RichTextEditorSpec(RichTextEditorViewSpec)
  ImageSpec(ImageViewSpec)
  CheckboxSpec(CheckboxViewSpec)
  PickerSpec(PickerViewSpec)
  DatePickerSpec(DatePickerViewSpec)
  SearchBarSpec(SearchBarViewSpec)
  SheetSpec(SheetViewSpec)
  FlexSpec(FlexViewSpec)
  PaddingSpec(PaddingViewSpec)
  ContainerSpec(ContainerViewSpec)
  SpacerSpec(SpacerViewSpec)
  FrameSpec(FrameViewSpec)
  StackSpec(StackViewSpec)
  ScrollSpec(ScrollViewSpec)
  GridSpec(GridViewSpec)
  ListSpec(ListViewSpec)
  ModifiedSpec(ModifiedViewSpec)
  CustomSpec(CustomViewSpec)
  CustomLayoutSpec(CustomLayoutSpec)
  ComponentSpec(ComponentViewSpec)
}

///|
pub fn ViewStyle::empty() -> ViewStyle {
  { font: None, foreground: None, background: None, corner_radius: None }
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
pub fn[Msg] View::frame_spec(
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
      { key: None, offset, viewport, on_scroll: None, child: EmptySpec },
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
pub fn[Msg] View::focusable(
  self : View[Msg],
  focusable? : Bool = true,
) -> View[Msg] {
  modify_view(self, PlainModifier(FocusableModifier(focusable)))
}

///|
pub fn[Msg] View::on_tap(self : View[Msg], message : Msg) -> View[Msg] {
  modify_view(self, TapModifier(message))
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

///|
fn[Msg] realize_view_node(
  node : ViewNode[Msg],
  emit : (Msg) -> Unit,
) -> ViewSpec {
  match node {
    EmptyNode => EmptySpec
    TextNode(data) => TextSpec(data)
    ButtonNode(data, message) =>
      ButtonSpec({
        ..data,
        on_click: match message {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    TextFieldNode(data, message) =>
      TextFieldSpec({
        ..data,
        on_submit: match message {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    RichTextEditorNode(data, selection, prefix) =>
      RichTextEditorSpec({
        ..data,
        on_selection_change: match selection {
          Some(handler) => Some((caret, range) => emit(handler(caret, range)))
          None => None
        },
        on_prefix_click: match prefix {
          Some(handler) => Some(offset => emit(handler(offset)))
          None => None
        },
      })
    ImageNode(data) => ImageSpec(data)
    CheckboxNode(data) => CheckboxSpec(data)
    PickerNode(data) => PickerSpec(data)
    DatePickerNode(data) => DatePickerSpec(data)
    SearchBarNode(data, submit, clear) =>
      SearchBarSpec({
        ..data,
        on_submit: match submit {
          Some(message) => Some(() => emit(message))
          None => None
        },
        on_clear: match clear {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    SheetNode(data, content, dismiss) =>
      SheetSpec({
        ..data,
        content: realize_view_node(content, emit),
        on_dismiss: match dismiss {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    FlexNode(data, children) =>
      FlexSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    PaddingNode(data, child) =>
      PaddingSpec({ ..data, child: realize_view_node(child, emit) })
    ContainerNode(data, child) =>
      ContainerSpec({
        ..data,
        child: match child {
          Some(child) => Some(realize_view_node(child, emit))
          None => None
        },
      })
    SpacerNode(data) => SpacerSpec(data)
    FrameNode(data, child) =>
      FrameSpec({ ..data, child: realize_view_node(child, emit) })
    StackNode(data, children) =>
      StackSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    ScrollNode(data, child, state, scroll) =>
      ScrollSpec({
        ..data,
        child: realize_view_node(child, emit),
        on_scroll: match (state, scroll) {
          (Some(state), Some(handler)) =>
            Some(delta => {
              state.scroll_to(
                x=0.0,
                y=max_scroll_offset(0.0, state.offset().y - delta.y),
              )
              emit(handler(delta))
            })
          (Some(state), None) =>
            Some(delta => {
              state.scroll_to(
                x=0.0,
                y=max_scroll_offset(0.0, state.offset().y - delta.y),
              )
            })
          (None, Some(handler)) => Some(delta => emit(handler(delta)))
          (None, None) => None
        },
      })
    GridNode(data, children) =>
      GridSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    ListNode(data, children) =>
      ListSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    ModifiedNode(modifier, child) => {
      let spec = realize_view_node(child, emit)
      match modifier {
        KeyModifierNode(key) => spec.with_key(key)
        PlainModifier(modifier) => spec.modified(modifier)
        RealizedModifier(modifier) => modifier(spec)
        TapModifier(message) => spec.on_tap(() => emit(message))
        FileDropModifier(handler) =>
          spec.on_file_drop((paths, point) => emit(handler(paths, point)))
      }
    }
    CustomNode(data) => CustomSpec(data)
    CustomLayoutNode(data, children) =>
      CustomLayoutSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    ComponentNode(build) =>
      ViewSpec::component(Component::new(ctx => realize_view(build(ctx), emit)))
  }
}

///|
fn[Msg, NextMsg] map_view_node(
  node : ViewNode[Msg],
  map : (Msg) -> NextMsg,
) -> ViewNode[NextMsg] {
  match node {
    EmptyNode => EmptyNode
    TextNode(data) => TextNode(data)
    ButtonNode(data, message) =>
      ButtonNode(data, option_map_message(message, map))
    TextFieldNode(data, message) =>
      TextFieldNode(data, option_map_message(message, map))
    RichTextEditorNode(data, selection, prefix) =>
      RichTextEditorNode(
        data,
        option_map_selection_handler(selection, map),
        option_map_prefix_handler(prefix, map),
      )
    ImageNode(data) => ImageNode(data)
    CheckboxNode(data) => CheckboxNode(data)
    PickerNode(data) => PickerNode(data)
    DatePickerNode(data) => DatePickerNode(data)
    SearchBarNode(data, submit, clear) =>
      SearchBarNode(
        data,
        option_map_message(submit, map),
        option_map_message(clear, map),
      )
    SheetNode(data, content, dismiss) =>
      SheetNode(
        data,
        map_view_node(content, map),
        option_map_message(dismiss, map),
      )
    FlexNode(data, children) =>
      FlexNode(data, children.map(child => map_view_node(child, map)))
    PaddingNode(data, child) => PaddingNode(data, map_view_node(child, map))
    ContainerNode(data, child) =>
      ContainerNode(data, option_map_view_node(child, map))
    SpacerNode(data) => SpacerNode(data)
    FrameNode(data, child) => FrameNode(data, map_view_node(child, map))
    StackNode(data, children) =>
      StackNode(data, children.map(child => map_view_node(child, map)))
    ScrollNode(data, child, state, scroll) =>
      ScrollNode(
        data,
        map_view_node(child, map),
        state,
        option_map_scroll_handler(scroll, map),
      )
    GridNode(data, children) =>
      GridNode(data, children.map(child => map_view_node(child, map)))
    ListNode(data, children) =>
      ListNode(data, children.map(child => map_view_node(child, map)))
    ModifiedNode(modifier, child) =>
      ModifiedNode(map_modifier_node(modifier, map), map_view_node(child, map))
    CustomNode(data) => CustomNode(data)
    CustomLayoutNode(data, children) =>
      CustomLayoutNode(data, children.map(child => map_view_node(child, map)))
    ComponentNode(build) => ComponentNode(ctx => build(ctx).map(map))
  }
}

///|
fn[Msg, NextMsg] map_modifier_node(
  modifier : ViewModifierNode[Msg],
  map : (Msg) -> NextMsg,
) -> ViewModifierNode[NextMsg] {
  match modifier {
    KeyModifierNode(key) => KeyModifierNode(key)
    PlainModifier(modifier) => PlainModifier(modifier)
    RealizedModifier(modifier) => RealizedModifier(modifier)
    TapModifier(message) => TapModifier(map(message))
    FileDropModifier(handler) =>
      FileDropModifier((paths, point) => map(handler(paths, point)))
  }
}

///|
fn[Msg, NextMsg] option_map_message(
  message : Msg?,
  map : (Msg) -> NextMsg,
) -> NextMsg? {
  match message {
    Some(message) => Some(map(message))
    None => None
  }
}

///|
fn[Msg, NextMsg] option_map_scroll_handler(
  handler : ((Point) -> Msg)?,
  map : (Msg) -> NextMsg,
) -> ((Point) -> NextMsg)? {
  match handler {
    Some(handler) => Some(delta => map(handler(delta)))
    None => None
  }
}

///|
fn[Msg, NextMsg] option_map_selection_handler(
  handler : ((Int, TextRange?) -> Msg)?,
  map : (Msg) -> NextMsg,
) -> ((Int, TextRange?) -> NextMsg)? {
  match handler {
    Some(handler) => Some((caret, range) => map(handler(caret, range)))
    None => None
  }
}

///|
fn[Msg, NextMsg] option_map_prefix_handler(
  handler : ((Int) -> Msg)?,
  map : (Msg) -> NextMsg,
) -> ((Int) -> NextMsg)? {
  match handler {
    Some(handler) => Some(offset => map(handler(offset)))
    None => None
  }
}

///|
fn max_scroll_offset(min : Double, value : Double) -> Double {
  if value < min {
    min
  } else {
    value
  }
}

///|
fn[Msg, NextMsg] option_map_view_node(
  node : ViewNode[Msg]?,
  map : (Msg) -> NextMsg,
) -> ViewNode[NextMsg]? {
  match node {
    Some(node) => Some(map_view_node(node, map))
    None => None
  }
}

///|
pub fn RichTextRun::new(
  text~ : String,
  visual_text? : String? = None,
  image_source? : String? = None,
  image_size? : Size? = None,
  image_fit? : ImageFit = ImageFit::Contain,
  font? : FontSpec? = None,
  color? : Color? = None,
  background? : Brush? = None,
  background_radius? : Double = 4.0,
  decoration? : RichTextDecoration? = None,
  source_range? : RichTextSourceRange? = None,
) -> RichTextRun {
  {
    text,
    visual_text,
    image_source,
    image_size,
    image_fit,
    font,
    color,
    background,
    background_radius,
    decoration,
    source_range,
  }
}

///|
pub fn RichTextInputTransform::new(
  text~ : String,
  caret~ : Int,
  selection? : TextRange? = None,
) -> RichTextInputTransform {
  { text, caret, selection }
}

///|
pub fn RichTextBlock::new(
  runs~ : Array[RichTextRun],
  table? : RichTextTable? = None,
  prefix? : String = "",
  font? : FontSpec? = None,
  color? : Color? = None,
  background? : Brush? = None,
  border_left? : BorderStyle? = None,
  inset? : Insets = Insets::symmetric(),
  line_height? : Double? = None,
  corner_radius? : Double = 0.0,
  rule? : Bool = false,
  source_range? : RichTextSourceRange? = None,
  content_range? : RichTextSourceRange? = None,
) -> RichTextBlock {
  {
    runs,
    table,
    prefix,
    font,
    color,
    background,
    border_left,
    inset,
    line_height,
    corner_radius,
    rule,
    source_range,
    content_range,
  }
}

///|
pub fn RichTextDocument::new(
  blocks~ : Array[RichTextBlock],
) -> RichTextDocument {
  { blocks, }
}

///|
pub fn RichTextDocument::plain(text : String) -> RichTextDocument {
  let blocks : Array[RichTextBlock] = []
  let current : Array[Char] = []
  for ch in text {
    if ch == '\n' {
      blocks.push(
        RichTextBlock::new(runs=[
          RichTextRun::new(text=String::from_array(current)),
        ]),
      )
      current.clear()
    } else {
      current.push(ch)
    }
  }
  blocks.push(
    RichTextBlock::new(runs=[RichTextRun::new(text=String::from_array(current))]),
  )
  RichTextDocument::new(blocks~)
}

///|
pub fn ShadowStyle::new(
  color~ : Color,
  offset? : Point = Point::new(x=0.0, y=2.0),
  blur_radius? : Double = 8.0,
  spread? : Double = 0.0,
) -> ShadowStyle {
  { color, offset, blur_radius, spread }
}

///|
pub fn BorderStyle::new(brush~ : Brush, width? : Double = 1.0) -> BorderStyle {
  { brush, width }
}

///|
pub fn VisualStyle::empty() -> VisualStyle {
  {
    background: None,
    foreground: None,
    border: None,
    shadow: None,
    radius: None,
    opacity: None,
  }
}

///|
pub fn Alignment::new(x~ : Double, y~ : Double) -> Alignment {
  { x: clamp_double(x, -1.0, 1.0), y: clamp_double(y, -1.0, 1.0) }
}

///|
pub fn Alignment::center() -> Alignment {
  Alignment::new(x=0.0, y=0.0)
}

///|
pub fn Alignment::top_leading() -> Alignment {
  Alignment::new(x=-1.0, y=-1.0)
}

///|
pub fn Alignment::top_trailing() -> Alignment {
  Alignment::new(x=1.0, y=-1.0)
}

///|
pub fn Alignment::bottom_leading() -> Alignment {
  Alignment::new(x=-1.0, y=1.0)
}

///|
pub fn Alignment::bottom_trailing() -> Alignment {
  Alignment::new(x=1.0, y=1.0)
}

///|
pub fn KeyboardShortcut::new(
  key~ : String,
  modifiers? : KeyModifiers = KeyModifiers::none(),
) -> KeyboardShortcut {
  { key, modifiers }
}

///|
pub fn KeyboardShortcut::matches(
  self : KeyboardShortcut,
  event : KeyboardEvent,
) -> Bool {
  event.pressed && event.key == self.key && event.modifiers == self.modifiers
}

///|
pub fn ViewStyle::merge(self : ViewStyle, next : ViewStyle) -> ViewStyle {
  {
    font: option_prefer(next.font, self.font),
    foreground: option_prefer(next.foreground, self.foreground),
    background: option_prefer(next.background, self.background),
    corner_radius: option_prefer(next.corner_radius, self.corner_radius),
  }
}

///|
fn[T] option_prefer(value : T?, fallback : T?) -> T? {
  match value {
    Some(_) => value
    None => fallback
  }
}

///|
fn ViewSpec::identity_key(self : ViewSpec) -> Key? {
  match self {
    EmptySpec => None
    TextSpec(data) => data.key
    ButtonSpec(data) => data.key
    TextFieldSpec(data) => data.key
    RichTextEditorSpec(data) => data.key
    ImageSpec(data) => data.key
    CheckboxSpec(data) => data.key
    PickerSpec(data) => data.key
    DatePickerSpec(data) => data.key
    SearchBarSpec(data) => data.key
    SheetSpec(data) => data.key
    FlexSpec(data) => data.key
    PaddingSpec(data) => data.key
    ContainerSpec(data) => data.key
    SpacerSpec(data) => data.key
    FrameSpec(data) => data.key
    StackSpec(data) => data.key
    ScrollSpec(data) => data.key
    GridSpec(data) => data.key
    ListSpec(data) => data.key
    ModifiedSpec(data) => data.key
    CustomSpec(data) => data.key
    CustomLayoutSpec(data) => data.key
    ComponentSpec(data) => data.key
  }
}

///|
fn ViewSpec::with_key(self : ViewSpec, key : Key) -> ViewSpec {
  match self {
    EmptySpec => EmptySpec
    TextSpec(data) => TextSpec({ ..data, key: Some(key) })
    ButtonSpec(data) => ButtonSpec({ ..data, key: Some(key) })
    TextFieldSpec(data) => TextFieldSpec({ ..data, key: Some(key) })
    RichTextEditorSpec(data) => RichTextEditorSpec({ ..data, key: Some(key) })
    ImageSpec(data) => ImageSpec({ ..data, key: Some(key) })
    CheckboxSpec(data) => CheckboxSpec({ ..data, key: Some(key) })
    PickerSpec(data) => PickerSpec({ ..data, key: Some(key) })
    DatePickerSpec(data) => DatePickerSpec({ ..data, key: Some(key) })
    SearchBarSpec(data) => SearchBarSpec({ ..data, key: Some(key) })
    SheetSpec(data) => SheetSpec({ ..data, key: Some(key) })
    FlexSpec(data) => FlexSpec({ ..data, key: Some(key) })
    PaddingSpec(data) => PaddingSpec({ ..data, key: Some(key) })
    ContainerSpec(data) => ContainerSpec({ ..data, key: Some(key) })
    SpacerSpec(data) => SpacerSpec({ ..data, key: Some(key) })
    FrameSpec(data) => FrameSpec({ ..data, key: Some(key) })
    StackSpec(data) => StackSpec({ ..data, key: Some(key) })
    ScrollSpec(data) => ScrollSpec({ ..data, key: Some(key) })
    GridSpec(data) => GridSpec({ ..data, key: Some(key) })
    ListSpec(data) => ListSpec({ ..data, key: Some(key) })
    ModifiedSpec(data) => ModifiedSpec({ ..data, key: Some(key) })
    CustomSpec(data) => CustomSpec({ ..data, key: Some(key) })
    CustomLayoutSpec(data) => CustomLayoutSpec({ ..data, key: Some(key) })
    ComponentSpec(data) => ComponentSpec({ ..data, key: Some(key) })
  }
}

///|
fn ViewSpec::kind(self : ViewSpec) -> Int {
  match self {
    EmptySpec => 0
    TextSpec(_) => 1
    ButtonSpec(_) => 2
    TextFieldSpec(_) => 3
    ImageSpec(_) => 4
    CheckboxSpec(_) => 5
    PickerSpec(_) => 6
    DatePickerSpec(_) => 7
    SearchBarSpec(_) => 8
    SheetSpec(_) => 9
    FlexSpec(_) => 10
    PaddingSpec(_) => 11
    ContainerSpec(_) => 12
    SpacerSpec(_) => 13
    FrameSpec(_) => 14
    StackSpec(_) => 15
    ScrollSpec(_) => 16
    GridSpec(_) => 17
    ListSpec(_) => 18
    ModifiedSpec(_) => 19
    CustomSpec(_) => 20
    ComponentSpec(_) => 21
    RichTextEditorSpec(_) => 22
    CustomLayoutSpec(_) => 23
  }
}

///|
fn ViewSpec::same_identity(self : ViewSpec, next : ViewSpec) -> Bool {
  self.kind() == next.kind() && self.identity_key() == next.identity_key()
}

///|
fn ViewSpec::key(self : ViewSpec, value : String) -> ViewSpec {
  self.with_key(Key::new(value))
}

///|
fn ViewSpec::font(self : ViewSpec, font : FontSpec) -> ViewSpec {
  self.modified(FontModifier(font))
}

///|
fn ViewSpec::foreground(self : ViewSpec, color : Color) -> ViewSpec {
  self.modified(ForegroundModifier(color))
}

///|
fn ViewSpec::background(self : ViewSpec, color : Color) -> ViewSpec {
  self.background_brush(Brush::solid(color))
}

///|
fn ViewSpec::background_brush(self : ViewSpec, brush : Brush) -> ViewSpec {
  self.modified(BackgroundModifier(brush))
}

///|
fn ViewSpec::corner_radius(self : ViewSpec, radius : Double) -> ViewSpec {
  self.modified(CornerRadiusModifier(radius))
}

///|
fn ViewSpec::opacity(self : ViewSpec, opacity : Double) -> ViewSpec {
  self.modified(OpacityModifier(opacity))
}

///|
fn ViewSpec::shadow(self : ViewSpec, style : ShadowStyle) -> ViewSpec {
  self.modified(ShadowModifier(style))
}

///|
fn ViewSpec::border(self : ViewSpec, style : BorderStyle) -> ViewSpec {
  self.modified(BorderModifier(style))
}

///|
fn ViewSpec::offset(
  self : ViewSpec,
  dx? : Double = 0.0,
  dy? : Double = 0.0,
) -> ViewSpec {
  self.modified(OffsetModifier(dx, dy))
}

///|
fn ViewSpec::clip(self : ViewSpec) -> ViewSpec {
  self.modified(ClipModifier)
}

///|
fn ViewSpec::scale(
  self : ViewSpec,
  sx? : Double = 1.0,
  sy? : Double = 1.0,
) -> ViewSpec {
  self.modified(ScaleModifier(sx, sy))
}

///|
fn ViewSpec::disabled(self : ViewSpec, disabled? : Bool = true) -> ViewSpec {
  self.modified(DisabledModifier(disabled))
}

///|
fn ViewSpec::accessibility_label(self : ViewSpec, label : String) -> ViewSpec {
  self.modified(AccessibilityLabelModifier(label))
}

///|
fn ViewSpec::semantics_role(self : ViewSpec, role : SemanticsRole) -> ViewSpec {
  self.modified(SemanticsRoleModifier(role))
}

///|
fn ViewSpec::focusable(self : ViewSpec, focusable? : Bool = true) -> ViewSpec {
  self.modified(FocusableModifier(focusable))
}

///|
fn ViewSpec::on_tap(self : ViewSpec, handler : ClickHandler) -> ViewSpec {
  self.modified(OnTapModifier(handler))
}

///|
fn ViewSpec::on_file_drop(
  self : ViewSpec,
  handler : FileDropHandler,
) -> ViewSpec {
  self.modified(OnFileDropModifier(handler))
}

///|
fn ViewSpec::keyboard_shortcut(
  self : ViewSpec,
  shortcut : KeyboardShortcut,
) -> ViewSpec {
  self.modified(KeyboardShortcutModifier(shortcut))
}

///|
fn ViewSpec::flexible(self : ViewSpec, weight? : Double = 1.0) -> ViewSpec {
  self.modified(FlexibleModifier(max_double(0.0, weight)))
}

///|
fn ViewSpec::layout_priority(self : ViewSpec, priority : Double) -> ViewSpec {
  self.modified(LayoutPriorityModifier(priority))
}

///|
fn ViewSpec::expanded(self : ViewSpec, weight? : Double = 1.0) -> ViewSpec {
  self.flexible(weight~)
}

///|
fn ViewSpec::align(
  self : ViewSpec,
  alignment? : Alignment = Alignment::center(),
) -> ViewSpec {
  self.modified(AlignModifier(alignment))
}

///|
fn ViewSpec::aspect_ratio(self : ViewSpec, ratio : Double) -> ViewSpec {
  self.modified(AspectRatioModifier(max_double(0.01, ratio)))
}

///|
fn ViewSpec::intrinsic_width(self : ViewSpec) -> ViewSpec {
  self.modified(IntrinsicWidthModifier)
}

///|
fn ViewSpec::intrinsic_height(self : ViewSpec) -> ViewSpec {
  self.modified(IntrinsicHeightModifier)
}

///|
fn ViewSpec::padding(self : ViewSpec, value : Double) -> ViewSpec {
  self.modified(PaddingModifier(Insets::all(value)))
}

///|
fn ViewSpec::spacing(self : ViewSpec, spacing : Double) -> ViewSpec {
  match self {
    FlexSpec(data) => FlexSpec({ ..data, spacing, })
    PaddingSpec(data) =>
      PaddingSpec({ ..data, child: data.child.spacing(spacing) })
    ContainerSpec(data) =>
      ContainerSpec({
        ..data,
        child: map_view_spec(data.child, child => child.spacing(spacing)),
      })
    FrameSpec(data) => FrameSpec({ ..data, child: data.child.spacing(spacing) })
    StackSpec(data) =>
      StackSpec({
        ..data,
        children: data.children.map(child => child.spacing(spacing)),
      })
    ScrollSpec(data) =>
      ScrollSpec({ ..data, child: data.child.spacing(spacing) })
    GridSpec(data) =>
      GridSpec({ ..data, row_spacing: spacing, column_spacing: spacing })
    ListSpec(data) => ListSpec({ ..data, spacing, })
    ModifiedSpec(data) =>
      ModifiedSpec({ ..data, child: data.child.spacing(spacing) })
    _ => self
  }
}

///|
fn ViewSpec::main_axis_alignment(
  self : ViewSpec,
  alignment : MainAxisAlignment,
) -> ViewSpec {
  match self {
    FlexSpec(data) => FlexSpec({ ..data, main_axis_alignment: alignment })
    PaddingSpec(data) =>
      PaddingSpec({ ..data, child: data.child.main_axis_alignment(alignment) })
    ContainerSpec(data) =>
      ContainerSpec({
        ..data,
        child: map_view_spec(data.child, child => {
          child.main_axis_alignment(alignment)
        }),
      })
    FrameSpec(data) =>
      FrameSpec({ ..data, child: data.child.main_axis_alignment(alignment) })
    StackSpec(data) =>
      StackSpec({
        ..data,
        children: data.children.map(child => {
          child.main_axis_alignment(alignment)
        }),
      })
    ScrollSpec(data) =>
      ScrollSpec({ ..data, child: data.child.main_axis_alignment(alignment) })
    GridSpec(data) =>
      GridSpec({
        ..data,
        children: data.children.map(child => {
          child.main_axis_alignment(alignment)
        }),
      })
    ListSpec(data) =>
      ListSpec({
        ..data,
        children: data.children.map(child => {
          child.main_axis_alignment(alignment)
        }),
      })
    ModifiedSpec(data) =>
      ModifiedSpec({ ..data, child: data.child.main_axis_alignment(alignment) })
    _ => self
  }
}

///|
fn ViewSpec::cross_axis_alignment(
  self : ViewSpec,
  alignment : CrossAxisAlignment,
) -> ViewSpec {
  match self {
    FlexSpec(data) => FlexSpec({ ..data, cross_axis_alignment: alignment })
    PaddingSpec(data) =>
      PaddingSpec({ ..data, child: data.child.cross_axis_alignment(alignment) })
    ContainerSpec(data) =>
      ContainerSpec({
        ..data,
        child: map_view_spec(data.child, child => {
          child.cross_axis_alignment(alignment)
        }),
      })
    FrameSpec(data) =>
      FrameSpec({ ..data, child: data.child.cross_axis_alignment(alignment) })
    StackSpec(data) =>
      StackSpec({
        ..data,
        children: data.children.map(child => {
          child.cross_axis_alignment(alignment)
        }),
      })
    ScrollSpec(data) =>
      ScrollSpec({ ..data, child: data.child.cross_axis_alignment(alignment) })
    GridSpec(data) =>
      GridSpec({
        ..data,
        children: data.children.map(child => {
          child.cross_axis_alignment(alignment)
        }),
      })
    ListSpec(data) =>
      ListSpec({
        ..data,
        children: data.children.map(child => {
          child.cross_axis_alignment(alignment)
        }),
      })
    ModifiedSpec(data) =>
      ModifiedSpec({ ..data, child: data.child.cross_axis_alignment(alignment) })
    _ => self
  }
}

///|
fn ViewSpec::theme(self : ViewSpec, theme : Theme) -> ViewSpec {
  self
  .font(theme.font)
  .foreground(theme.foreground)
  .background_brush(Brush::solid(theme.background))
  .corner_radius(theme.corner_radius)
}

///|
fn ViewSpec::environment(
  self : ViewSpec,
  environment : Environment,
) -> ViewSpec {
  self.theme(environment.theme).disabled(disabled=!environment.enabled)
}

///|
fn ViewSpec::frame(
  self : ViewSpec,
  width? : Double,
  height? : Double,
  min_width? : Double,
  min_height? : Double,
  max_width? : Double,
  max_height? : Double,
) -> ViewSpec {
  self.modified(
    FrameModifier({
      width,
      height,
      min_width,
      min_height,
      max_width,
      max_height,
    }),
  )
}

///|
fn ViewSpec::modified(self : ViewSpec, modifier : ViewModifier) -> ViewSpec {
  ModifiedSpec({ key: None, modifier, child: self })
}

///|
fn ViewSpec::custom(
  measure~ : (Constraints) -> Size,
  paint~ : (Rect) -> Array[DrawCommand],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> ViewSpec {
  CustomSpec({ key: None, measure, paint, semantics_role, semantics_label })
}

///|
pub fn CustomLayoutCache::new() -> CustomLayoutCache {
  { entries: [] }
}

///|
pub fn CustomLayoutCache::get(
  self : CustomLayoutCache,
  key : String,
) -> String? {
  for entry in self.entries {
    if entry.key == key {
      return Some(entry.value)
    }
  }
  None
}

///|
pub fn CustomLayoutCache::set(
  self : CustomLayoutCache,
  key : String,
  value : String,
) -> Unit {
  for entry in self.entries {
    if entry.key == key {
      entry.value = value
      return
    }
  }
  self.entries.push({ key, value })
}

///|
pub fn CustomLayoutCache::clear(self : CustomLayoutCache) -> Unit {
  self.entries.clear()
}

///|
pub fn AlignmentGuideSet::from_size(
  size : Size,
  first_baseline? : Double? = None,
) -> AlignmentGuideSet {
  {
    leading: 0.0,
    center: size.width / 2.0,
    trailing: size.width,
    first_baseline,
  }
}

///|
pub fn CustomPlacementContext::mirror_x(
  self : CustomPlacementContext,
  x~ : Double,
  width~ : Double,
) -> Double {
  match self.layout_direction {
    LeftToRight => x
    RightToLeft =>
      self.frame.origin.x +
      self.frame.size.width -
      (x - self.frame.origin.x) -
      width
  }
}

///|
fn ViewSpec::custom_layout(
  children~ : Array[ViewSpec],
  measure~ : (CustomLayoutContext) -> Size,
  place~ : (CustomPlacementContext) -> Array[Rect],
  paint? : (Rect) -> Array[DrawCommand] = _frame => [],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> ViewSpec {
  CustomLayoutSpec({
    key: None,
    children,
    cache: CustomLayoutCache::new(),
    measure,
    place,
    paint,
    semantics_role,
    semantics_label,
  })
}

///|
fn ViewSpec::component(component : Component) -> ViewSpec {
  ComponentSpec({ key: None, component })
}

///|
pub fn DateValue::new(
  year~ : Int,
  month~ : Int,
  day~ : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
) -> DateValue {
  { year, month, day, hour, minute, second }
}

///|
pub fn DateValue::today() -> DateValue {
  { year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0 }
}

///|
pub fn DateValue::format(self : DateValue, mode : DatePickerMode) -> String {
  match mode {
    DatePickerMode::Date => "\{self.year}-\{self.month}-\{self.day}"
    DatePickerMode::DateAndTime =>
      "\{self.year}-\{self.month}-\{self.day} \{self.hour}:\{self.minute}"
    DatePickerMode::Time => "\{self.hour}:\{self.minute}"
  }
}

///|
fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 31
  }
}

///|
fn map_view_spec(value : ViewSpec?, f : (ViewSpec) -> ViewSpec) -> ViewSpec? {
  match value {
    Some(value) => Some(f(value))
    None => None
  }
}
