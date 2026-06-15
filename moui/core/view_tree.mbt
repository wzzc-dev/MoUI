///|
type ClickHandler = () -> Unit

///|
type FileDropHandler = (Array[String], Point) -> Unit

///|
type DragGestureHandler = (DragGestureEvent) -> Unit

///|
type FrameDragGestureHandler = (DragGestureEvent, Rect) -> Unit

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
}

///|
priv struct PaddingViewSpec {
  key : Key?
  insets : Insets
}

///|
priv struct ContainerViewSpec {
  key : Key?
  size : Size?
  background : Brush?
  border : BorderStyle?
  corner_radius : Double
  shadow : ShadowStyle?
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
}

///|
priv struct StackViewSpec {
  key : Key?
}

///|
priv struct ScrollViewSpec {
  key : Key?
  offset : Point
  viewport : Size?
  on_scroll : ((Point) -> Unit)?
  scroll_state : ScrollState?
  scroll_activates : Bool
}

///|
priv struct GridViewSpec {
  key : Key?
  columns : Int
  row_spacing : Double
  column_spacing : Double
}

///|
priv struct ListViewSpec {
  key : Key?
  spacing : Double
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
  SemanticsSelectedModifier(Bool)
  SemanticsPressedModifier(Bool)
  SemanticsCheckedModifier(Bool)
  SemanticsExpandedModifier(Bool)
  SemanticsInvalidModifier(Bool)
  SemanticsRequiredModifier(Bool)
  SemanticsDescriptionModifier(String)
  SemanticsActionModifier(SemanticsAction)
  FocusableModifier(Bool)
  FocusTrapModifier(Bool)
  OnTapModifier(ClickHandler)
  OnLongPressModifier(ClickHandler)
  OnDoubleTapModifier(ClickHandler)
  OnDragModifier(DragGestureHandler)
  OnDragWithFrameModifier(FrameDragGestureHandler)
  OnFileDropModifier(FileDropHandler)
  KeyboardShortcutModifier(KeyboardShortcut)
  FlexibleModifier(Double)
  LayoutPriorityModifier(Double)
  AlignModifier(Alignment)
  SpacingModifier(Double)
  MainAxisAlignmentModifier(MainAxisAlignment)
  CrossAxisAlignmentModifier(CrossAxisAlignment)
  ThemeModifier(Theme)
  EnvironmentModifier(Environment)
  AspectRatioModifier(Double)
  IntrinsicWidthModifier
  IntrinsicHeightModifier
  RepaintBoundaryModifier
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
struct PickerItem {
  id : String
  label : String
}

///|
pub fn PickerItem::new(id~ : String, label~ : String) -> PickerItem {
  { id, label }
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
  presentation_mode : SheetPresentationMode
  background : Brush
  corner_radius : Double
  shadow : ShadowStyle?
  on_dismiss : (() -> Unit)?
}
