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
pub type ClickHandler = () -> Unit

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
pub(all) enum ViewSpec {
  EmptySpec
  TextSpec(TextViewSpec)
  ButtonSpec(ButtonViewSpec)
  TextFieldSpec(TextFieldViewSpec)
  ImageSpec(ImageViewSpec)
  CheckboxSpec(CheckboxViewSpec)
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
}

///|
pub fn ViewStyle::empty() -> ViewStyle {
  { font: None, foreground: None, background: None, corner_radius: None }
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
    ImageSpec(data) => data.key
    CheckboxSpec(data) => data.key
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
  }
}

///|
pub fn ViewSpec::with_key(self : ViewSpec, key : Key) -> ViewSpec {
  match self {
    EmptySpec => EmptySpec
    TextSpec(data) => TextSpec({ ..data, key: Some(key) })
    ButtonSpec(data) => ButtonSpec({ ..data, key: Some(key) })
    TextFieldSpec(data) => TextFieldSpec({ ..data, key: Some(key) })
    ImageSpec(data) => ImageSpec({ ..data, key: Some(key) })
    CheckboxSpec(data) => CheckboxSpec({ ..data, key: Some(key) })
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
    FlexSpec(_) => 6
    PaddingSpec(_) => 7
    ContainerSpec(_) => 8
    SpacerSpec(_) => 9
    FrameSpec(_) => 10
    StackSpec(_) => 11
    ScrollSpec(_) => 12
    GridSpec(_) => 13
    ListSpec(_) => 14
    ModifiedSpec(_) => 15
    CustomSpec(_) => 16
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
  self.theme(environment.theme)
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
fn map_view_spec(value : ViewSpec?, f : (ViewSpec) -> ViewSpec) -> ViewSpec? {
  match value {
    Some(value) => Some(f(value))
    None => None
  }
}
