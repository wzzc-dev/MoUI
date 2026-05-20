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
pub type ClickHandler = () -> Unit

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
pub(all) struct TextViewSpec {
  key : Key?
  text : String
  size : Size
  font : FontSpec
  color : Color
}

///|
pub(all) struct ButtonViewSpec {
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
pub(all) struct TextFieldViewSpec {
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
pub(all) struct RichTextRun {
  text : String
  font : FontSpec?
  color : Color?
  background : Brush?
  background_radius : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextBlock {
  runs : Array[RichTextRun]
  prefix : String
  font : FontSpec?
  color : Color?
  background : Brush?
  border_left : BorderStyle?
  inset : Insets
  line_height : Double?
  corner_radius : Double
  rule : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextDocument {
  blocks : Array[RichTextBlock]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RichTextEditorViewSpec {
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
}

///|
pub(all) struct ImageViewSpec {
  key : Key?
  source : String
  size : Size?
  opacity : Double
  corner_radius : Double
  fit : ImageFit
}

///|
pub(all) struct CheckboxViewSpec {
  key : Key?
  label : String
  checked : Binding[Bool]
  font : FontSpec
  foreground : Color
  check_color : Color
  size : Size
}

///|
pub(all) struct FlexViewSpec {
  key : Key?
  axis : Axis
  spacing : Double
  main_axis_alignment : MainAxisAlignment
  cross_axis_alignment : CrossAxisAlignment
  children : Array[ViewSpec]
}

///|
pub(all) struct PaddingViewSpec {
  key : Key?
  insets : Insets
  child : ViewSpec
}

///|
pub(all) struct ContainerViewSpec {
  key : Key?
  size : Size?
  background : Brush?
  border : BorderStyle?
  corner_radius : Double
  shadow : ShadowStyle?
  child : ViewSpec?
}

///|
pub(all) struct SpacerViewSpec {
  key : Key?
  min_length : Double
  weight : Double
}

///|
pub(all) struct FrameViewSpec {
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
pub(all) struct StackViewSpec {
  key : Key?
  children : Array[ViewSpec]
}

///|
pub(all) struct ScrollViewSpec {
  key : Key?
  offset : Point
  viewport : Size?
  child : ViewSpec
}

///|
pub(all) struct GridViewSpec {
  key : Key?
  columns : Int
  row_spacing : Double
  column_spacing : Double
  children : Array[ViewSpec]
}

///|
pub(all) struct ListViewSpec {
  key : Key?
  spacing : Double
  children : Array[ViewSpec]
}

///|
pub(all) struct FrameModifierSpec {
  width : Double?
  height : Double?
  min_width : Double?
  min_height : Double?
  max_width : Double?
  max_height : Double?
}

///|
pub(all) enum ViewModifier {
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
  KeyboardShortcutModifier(KeyboardShortcut)
  FlexibleModifier(Double)
  LayoutPriorityModifier(Double)
  AlignModifier(Alignment)
  AspectRatioModifier(Double)
  IntrinsicWidthModifier
  IntrinsicHeightModifier
}

///|
pub(all) struct ModifiedViewSpec {
  key : Key?
  modifier : ViewModifier
  child : ViewSpec
}

///|
pub(all) struct CustomViewSpec {
  key : Key?
  measure : (Constraints) -> Size
  paint : (Rect) -> Array[DrawCommand]
  semantics_role : SemanticsRole
  semantics_label : String
}

///|
pub(all) struct CustomLayoutContext {
  constraints : Constraints
  child_sizes : Array[Size]
  child_baselines : Array[Double?]
  child_priorities : Array[Double]
}

///|
pub(all) struct CustomPlacementContext {
  frame : Rect
  measured_size : Size
  child_sizes : Array[Size]
  child_baselines : Array[Double?]
  child_priorities : Array[Double]
}

///|
pub(all) struct CustomLayoutSpec {
  key : Key?
  children : Array[ViewSpec]
  measure : (CustomLayoutContext) -> Size
  place : (CustomPlacementContext) -> Array[Rect]
  paint : (Rect) -> Array[DrawCommand]
  semantics_role : SemanticsRole
  semantics_label : String
}

///|
pub(all) struct ComponentViewSpec {
  key : Key?
  component : Component
}

///|
pub(all) struct PickerItem {
  id : String
  label : String
}

///|
pub(all) struct PickerViewSpec {
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
pub(all) struct DatePickerViewSpec {
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
pub(all) struct SearchBarViewSpec {
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
pub(all) struct SheetViewSpec {
  key : Key?
  content : ViewSpec
  presentation_mode : SheetPresentationMode
  background : Brush
  corner_radius : Double
  shadow : ShadowStyle?
  on_dismiss : (() -> Unit)?
}

///|
pub(all) enum ViewSpec {
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
pub fn RichTextRun::new(
  text~ : String,
  font? : FontSpec? = None,
  color? : Color? = None,
  background? : Brush? = None,
  background_radius? : Double = 4.0,
) -> RichTextRun {
  { text, font, color, background, background_radius }
}

///|
pub fn RichTextBlock::new(
  runs~ : Array[RichTextRun],
  prefix? : String = "",
  font? : FontSpec? = None,
  color? : Color? = None,
  background? : Brush? = None,
  border_left? : BorderStyle? = None,
  inset? : Insets = Insets::symmetric(),
  line_height? : Double? = None,
  corner_radius? : Double = 0.0,
  rule? : Bool = false,
) -> RichTextBlock {
  {
    runs,
    prefix,
    font,
    color,
    background,
    border_left,
    inset,
    line_height,
    corner_radius,
    rule,
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
pub fn ViewSpec::with_key(self : ViewSpec, key : Key) -> ViewSpec {
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
pub fn ViewSpec::kind(self : ViewSpec) -> Int {
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
pub fn ViewSpec::same_identity(self : ViewSpec, next : ViewSpec) -> Bool {
  self.kind() == next.kind() && self.identity_key() == next.identity_key()
}

///|
pub fn ViewSpec::key(self : ViewSpec, value : String) -> ViewSpec {
  self.with_key(Key::new(value))
}

///|
pub fn ViewSpec::font(self : ViewSpec, font : FontSpec) -> ViewSpec {
  self.modified(FontModifier(font))
}

///|
pub fn ViewSpec::foreground(self : ViewSpec, color : Color) -> ViewSpec {
  self.modified(ForegroundModifier(color))
}

///|
pub fn ViewSpec::background(self : ViewSpec, color : Color) -> ViewSpec {
  self.background_brush(Brush::solid(color))
}

///|
pub fn ViewSpec::background_brush(self : ViewSpec, brush : Brush) -> ViewSpec {
  self.modified(BackgroundModifier(brush))
}

///|
pub fn ViewSpec::corner_radius(self : ViewSpec, radius : Double) -> ViewSpec {
  self.modified(CornerRadiusModifier(radius))
}

///|
pub fn ViewSpec::opacity(self : ViewSpec, opacity : Double) -> ViewSpec {
  self.modified(OpacityModifier(opacity))
}

///|
pub fn ViewSpec::shadow(self : ViewSpec, style : ShadowStyle) -> ViewSpec {
  self.modified(ShadowModifier(style))
}

///|
pub fn ViewSpec::border(self : ViewSpec, style : BorderStyle) -> ViewSpec {
  self.modified(BorderModifier(style))
}

///|
pub fn ViewSpec::offset(
  self : ViewSpec,
  dx? : Double = 0.0,
  dy? : Double = 0.0,
) -> ViewSpec {
  self.modified(OffsetModifier(dx, dy))
}

///|
pub fn ViewSpec::clip(self : ViewSpec) -> ViewSpec {
  self.modified(ClipModifier)
}

///|
pub fn ViewSpec::scale(
  self : ViewSpec,
  sx? : Double = 1.0,
  sy? : Double = 1.0,
) -> ViewSpec {
  self.modified(ScaleModifier(sx, sy))
}

///|
pub fn ViewSpec::disabled(self : ViewSpec, disabled? : Bool = true) -> ViewSpec {
  self.modified(DisabledModifier(disabled))
}

///|
pub fn ViewSpec::accessibility_label(
  self : ViewSpec,
  label : String,
) -> ViewSpec {
  self.modified(AccessibilityLabelModifier(label))
}

///|
pub fn ViewSpec::semantics_role(
  self : ViewSpec,
  role : SemanticsRole,
) -> ViewSpec {
  self.modified(SemanticsRoleModifier(role))
}

///|
pub fn ViewSpec::focusable(
  self : ViewSpec,
  focusable? : Bool = true,
) -> ViewSpec {
  self.modified(FocusableModifier(focusable))
}

///|
pub fn ViewSpec::on_tap(self : ViewSpec, handler : ClickHandler) -> ViewSpec {
  self.modified(OnTapModifier(handler))
}

///|
pub fn ViewSpec::keyboard_shortcut(
  self : ViewSpec,
  shortcut : KeyboardShortcut,
) -> ViewSpec {
  self.modified(KeyboardShortcutModifier(shortcut))
}

///|
pub fn ViewSpec::flexible(self : ViewSpec, weight? : Double = 1.0) -> ViewSpec {
  self.modified(FlexibleModifier(max_double(0.0, weight)))
}

///|
pub fn ViewSpec::layout_priority(
  self : ViewSpec,
  priority : Double,
) -> ViewSpec {
  self.modified(LayoutPriorityModifier(priority))
}

///|
pub fn ViewSpec::expanded(self : ViewSpec, weight? : Double = 1.0) -> ViewSpec {
  self.flexible(weight~)
}

///|
pub fn ViewSpec::align(
  self : ViewSpec,
  alignment? : Alignment = Alignment::center(),
) -> ViewSpec {
  self.modified(AlignModifier(alignment))
}

///|
pub fn ViewSpec::aspect_ratio(self : ViewSpec, ratio : Double) -> ViewSpec {
  self.modified(AspectRatioModifier(max_double(0.01, ratio)))
}

///|
pub fn ViewSpec::intrinsic_width(self : ViewSpec) -> ViewSpec {
  self.modified(IntrinsicWidthModifier)
}

///|
pub fn ViewSpec::intrinsic_height(self : ViewSpec) -> ViewSpec {
  self.modified(IntrinsicHeightModifier)
}

///|
pub fn ViewSpec::padding(self : ViewSpec, value : Double) -> ViewSpec {
  self.modified(PaddingModifier(Insets::all(value)))
}

///|
pub fn ViewSpec::spacing(self : ViewSpec, spacing : Double) -> ViewSpec {
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
pub fn ViewSpec::main_axis_alignment(
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
pub fn ViewSpec::cross_axis_alignment(
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
pub fn ViewSpec::theme(self : ViewSpec, theme : Theme) -> ViewSpec {
  self
  .font(theme.font)
  .foreground(theme.foreground)
  .background_brush(Brush::solid(theme.background))
  .corner_radius(theme.corner_radius)
}

///|
pub fn ViewSpec::environment(
  self : ViewSpec,
  environment : Environment,
) -> ViewSpec {
  self.theme(environment.theme).disabled(disabled=!environment.enabled)
}

///|
pub fn ViewSpec::frame(
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
pub fn ViewSpec::modified(self : ViewSpec, modifier : ViewModifier) -> ViewSpec {
  ModifiedSpec({ key: None, modifier, child: self })
}

///|
pub fn ViewSpec::custom(
  measure~ : (Constraints) -> Size,
  paint~ : (Rect) -> Array[DrawCommand],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> ViewSpec {
  CustomSpec({ key: None, measure, paint, semantics_role, semantics_label })
}

///|
pub fn ViewSpec::custom_layout(
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
    measure,
    place,
    paint,
    semantics_role,
    semantics_label,
  })
}

///|
pub fn ViewSpec::component(component : Component) -> ViewSpec {
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
