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
    WebViewHostSpec(data) => data.key
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
    WidgetSpec(data) =>
      match data.identity.key {
        Some(key) => Some(Key::new(key.value()))
        None => None
      }
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
    WebViewHostSpec(data) => WebViewHostSpec({ ..data, key: Some(key) })
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
    WidgetSpec(data) =>
      WidgetSpec({
        ..data,
        identity: { ..data.identity, key: Some(@core.Key::new(key.value)) },
      })
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
    WebViewHostSpec(_) => 9
    SheetSpec(_) => 10
    FlexSpec(_) => 11
    PaddingSpec(_) => 12
    ContainerSpec(_) => 13
    SpacerSpec(_) => 14
    FrameSpec(_) => 15
    StackSpec(_) => 16
    ScrollSpec(_) => 17
    GridSpec(_) => 18
    ListSpec(_) => 19
    ModifiedSpec(_) => 20
    CustomSpec(_) => 21
    ComponentSpec(_) => 22
    RichTextEditorSpec(_) => 23
    CustomLayoutSpec(_) => 24
    WidgetSpec(data) => stable_widget_kind(data.identity.kind)
  }
}

///|
fn ViewSpec::inspector_kind_label(self : ViewSpec) -> String {
  match self {
    EmptySpec => "Empty"
    TextSpec(_) => "Text"
    ButtonSpec(_) => "Button"
    TextFieldSpec(_) => "TextField"
    RichTextEditorSpec(_) => "RichTextEditor"
    ImageSpec(_) => "Image"
    CheckboxSpec(_) => "Checkbox"
    PickerSpec(_) => "Picker"
    DatePickerSpec(_) => "DatePicker"
    SearchBarSpec(_) => "SearchBar"
    WebViewHostSpec(_) => "WebView"
    SheetSpec(_) => "Sheet"
    FlexSpec(_) => "Flex"
    PaddingSpec(_) => "Padding"
    ContainerSpec(_) => "Container"
    SpacerSpec(_) => "Spacer"
    FrameSpec(_) => "Frame"
    StackSpec(_) => "Stack"
    ScrollSpec(_) => "Scroll"
    GridSpec(_) => "Grid"
    ListSpec(_) => "List"
    ModifiedSpec(_) => "Modified"
    CustomSpec(_) => "Custom"
    CustomLayoutSpec(_) => "CustomLayout"
    ComponentSpec(_) => "Component"
    WidgetSpec(data) => data.identity.kind
  }
}

///|
fn ViewSpec::inspector_is_control(self : ViewSpec) -> Bool {
  match self {
    ButtonSpec(_)
    | TextFieldSpec(_)
    | RichTextEditorSpec(_)
    | CheckboxSpec(_)
    | PickerSpec(_)
    | DatePickerSpec(_)
    | SearchBarSpec(_)
    | WebViewHostSpec(_) => true
    WidgetSpec(data) => (data.focusable)()
    _ => false
  }
}

///|
fn ViewSpec::same_identity(self : ViewSpec, next : ViewSpec) -> Bool {
  self.kind() == next.kind() && self.identity_key() == next.identity_key()
}

///|
fn stable_widget_kind(kind : String) -> Int {
  let mut hash = 0
  for ch in kind {
    hash = (hash * 31 + ch.to_int()) % 1000000007
  }
  1000 + (if hash < 0 { -hash } else { hash })
}

///|

///|
fn ViewSpec::font(self : ViewSpec, font : FontSpec) -> ViewSpec {
  self.modified(FontModifier(font))
}

///|
fn ViewSpec::foreground(self : ViewSpec, color : Color) -> ViewSpec {
  self.modified(ForegroundModifier(color))
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
fn ViewSpec::disabled(self : ViewSpec, disabled? : Bool = true) -> ViewSpec {
  self.modified(DisabledModifier(disabled))
}

///|
fn ViewSpec::on_tap(self : ViewSpec, handler : ClickHandler) -> ViewSpec {
  self.modified(OnTapModifier(handler))
}

///|
fn ViewSpec::on_long_press(self : ViewSpec, handler : ClickHandler) -> ViewSpec {
  self.modified(OnLongPressModifier(handler))
}

///|
fn ViewSpec::on_double_tap(self : ViewSpec, handler : ClickHandler) -> ViewSpec {
  self.modified(OnDoubleTapModifier(handler))
}

///|
fn ViewSpec::on_drag(self : ViewSpec, handler : DragGestureHandler) -> ViewSpec {
  self.modified(OnDragModifier(handler))
}

///|
fn ViewSpec::on_drag_with_frame(
  self : ViewSpec,
  handler : FrameDragGestureHandler,
) -> ViewSpec {
  self.modified(OnDragWithFrameModifier(handler))
}

///|
fn ViewSpec::on_file_drop(
  self : ViewSpec,
  handler : FileDropHandler,
) -> ViewSpec {
  self.modified(OnFileDropModifier(handler))
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
fn ViewSpec::modified(self : ViewSpec, modifier : ViewModifier) -> ViewSpec {
  match modifier {
    SpacingModifier(spacing) => self.spacing(spacing)
    MainAxisAlignmentModifier(alignment) => self.main_axis_alignment(alignment)
    CrossAxisAlignmentModifier(alignment) =>
      self.cross_axis_alignment(alignment)
    ThemeModifier(theme) => self.theme(theme)
    EnvironmentModifier(environment) => self.environment(environment)
    _ => ModifiedSpec({ key: None, modifier, child: self })
  }
}

///|
fn ViewSpec::component(component : Component) -> ViewSpec {
  ComponentSpec({ key: None, component })
}

///|
fn map_view_spec(value : ViewSpec?, f : (ViewSpec) -> ViewSpec) -> ViewSpec? {
  match value {
    Some(value) => Some(f(value))
    None => None
  }
}
