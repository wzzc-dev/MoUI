///|
pub(all) struct Key {
  value : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ElementId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DirtyFlags {
  mut needs_build : Bool
  mut needs_layout : Bool
  mut needs_paint : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct StateSlot[T] {
  mut value : T
  mut version : Int
  mut listeners : Array[StateListener]
}

///|
pub(all) struct StateListener {
  mut active : Bool
  callback : () -> Unit
}

///|
pub(all) struct StateSubscription {
  listener : StateListener
}

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
  background : Color?
  corner_radius : Double?
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
  background : Color
  hovered_background : Color
  pressed_background : Color
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
  background : Color
  border_color : Color
  focused_border_color : Color
  cursor_color : Color
  corner_radius : Double
  on_submit : (() -> Unit)?
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
  background : Color?
  corner_radius : Double
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
pub(all) enum ViewSpec {
  EmptySpec
  TextSpec(TextViewSpec)
  ButtonSpec(ButtonViewSpec)
  TextFieldSpec(TextFieldViewSpec)
  FlexSpec(FlexViewSpec)
  PaddingSpec(PaddingViewSpec)
  ContainerSpec(ContainerViewSpec)
  SpacerSpec(SpacerViewSpec)
  FrameSpec(FrameViewSpec)
}

///|
pub(all) struct ElementNode {
  id : ElementId
  mut key : Key?
  mut spec : ViewSpec
  mut children : Array[ElementNode]
  mut dirty : DirtyFlags
  mut button_state : ButtonState
}

///|
pub(all) struct RenderNode {
  element_id : ElementId
  frame : Rect
  children : Array[RenderNode]
  hit_testable : Bool
  paint_commands : Array[DrawCommand]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ElementEventResult {
  changed : Bool
  activated : Bool
  focused : ElementId?
} derive(Eq, Debug, ToJson)

///|
priv struct MountResult {
  node : ElementNode
  next_id : Int
}

///|
priv struct ReconcileResult {
  node : ElementNode
  next_id : Int
}

///|
pub fn Key::new(value : String) -> Key {
  { value, }
}

///|
pub fn ElementId::new(value : Int) -> ElementId {
  { value, }
}

///|
pub fn DirtyFlags::clean() -> DirtyFlags {
  { needs_build: false, needs_layout: false, needs_paint: false }
}

///|
pub fn DirtyFlags::all() -> DirtyFlags {
  { needs_build: true, needs_layout: true, needs_paint: true }
}

///|
pub fn DirtyFlags::mark_build(self : DirtyFlags) -> Unit {
  self.needs_build = true
  self.needs_layout = true
  self.needs_paint = true
}

///|
pub fn DirtyFlags::mark_layout(self : DirtyFlags) -> Unit {
  self.needs_layout = true
  self.needs_paint = true
}

///|
pub fn DirtyFlags::mark_paint(self : DirtyFlags) -> Unit {
  self.needs_paint = true
}

///|
pub fn DirtyFlags::clear(self : DirtyFlags) -> Unit {
  self.needs_build = false
  self.needs_layout = false
  self.needs_paint = false
}

///|
pub fn[T] StateSlot::new(value : T) -> StateSlot[T] {
  { value, version: 0, listeners: [] }
}

///|
pub fn[T] StateSlot::get(self : StateSlot[T]) -> T {
  self.value
}

///|
pub fn[T] StateSlot::set(self : StateSlot[T], value : T) -> Unit {
  self.value = value
  self.version = self.version + 1
  self.notify()
}

///|
pub fn[T] StateSlot::update(
  self : StateSlot[T],
  f : (T) -> T raise?,
) -> Unit raise? {
  self.set(f(self.value))
}

///|
pub fn[T] StateSlot::subscribe(
  self : StateSlot[T],
  callback : () -> Unit,
) -> StateSubscription {
  let listener = StateListener::new(callback)
  self.listeners.push(listener)
  { listener, }
}

///|
fn[T] StateSlot::notify(self : StateSlot[T]) -> Unit {
  for listener in self.listeners {
    if listener.active {
      (listener.callback)()
    }
  }
}

///|
pub fn StateListener::new(callback : () -> Unit) -> StateListener {
  { active: true, callback }
}

///|
pub fn StateSubscription::cancel(self : StateSubscription) -> Unit {
  self.listener.active = false
}

///|
pub fn StateSubscription::is_active(self : StateSubscription) -> Bool {
  self.listener.active
}

///|
pub fn ViewStyle::empty() -> ViewStyle {
  { font: None, foreground: None, background: None, corner_radius: None }
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
    FlexSpec(data) => data.key
    PaddingSpec(data) => data.key
    ContainerSpec(data) => data.key
    SpacerSpec(data) => data.key
    FrameSpec(data) => data.key
  }
}

///|
pub fn ViewSpec::with_key(self : ViewSpec, key : Key) -> ViewSpec {
  match self {
    EmptySpec => EmptySpec
    TextSpec(data) => TextSpec({ ..data, key: Some(key) })
    ButtonSpec(data) => ButtonSpec({ ..data, key: Some(key) })
    TextFieldSpec(data) => TextFieldSpec({ ..data, key: Some(key) })
    FlexSpec(data) => FlexSpec({ ..data, key: Some(key) })
    PaddingSpec(data) => PaddingSpec({ ..data, key: Some(key) })
    ContainerSpec(data) => ContainerSpec({ ..data, key: Some(key) })
    SpacerSpec(data) => SpacerSpec({ ..data, key: Some(key) })
    FrameSpec(data) => FrameSpec({ ..data, key: Some(key) })
  }
}

///|
pub fn ViewSpec::kind(self : ViewSpec) -> Int {
  match self {
    EmptySpec => 0
    TextSpec(_) => 1
    ButtonSpec(_) => 2
    TextFieldSpec(_) => 3
    FlexSpec(_) => 4
    PaddingSpec(_) => 5
    ContainerSpec(_) => 6
    SpacerSpec(_) => 7
    FrameSpec(_) => 8
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
  match self {
    TextSpec(data) => TextSpec({ ..data, font })
    ButtonSpec(data) => ButtonSpec({ ..data, font })
    TextFieldSpec(data) => TextFieldSpec({ ..data, font })
    FlexSpec(data) =>
      FlexSpec({ ..data, children: data.children.map(child => child.font(font)) })
    PaddingSpec(data) => PaddingSpec({ ..data, child: data.child.font(font) })
    ContainerSpec(data) =>
      ContainerSpec({
        ..data,
        child: map_view_spec(data.child, child => child.font(font)),
      })
    FrameSpec(data) => FrameSpec({ ..data, child: data.child.font(font) })
    EmptySpec | SpacerSpec(_) => self
  }
}

///|
pub fn ViewSpec::foreground(self : ViewSpec, color : Color) -> ViewSpec {
  match self {
    TextSpec(data) => TextSpec({ ..data, color })
    ButtonSpec(data) => ButtonSpec({ ..data, foreground: color })
    TextFieldSpec(data) => TextFieldSpec({ ..data, foreground: color })
    FlexSpec(data) =>
      FlexSpec({
        ..data,
        children: data.children.map(child => child.foreground(color)),
      })
    PaddingSpec(data) =>
      PaddingSpec({ ..data, child: data.child.foreground(color) })
    ContainerSpec(data) =>
      ContainerSpec({
        ..data,
        child: map_view_spec(data.child, child => child.foreground(color)),
      })
    FrameSpec(data) => FrameSpec({ ..data, child: data.child.foreground(color) })
    EmptySpec | SpacerSpec(_) => self
  }
}

///|
pub fn ViewSpec::background(self : ViewSpec, color : Color) -> ViewSpec {
  match self {
    ButtonSpec(data) => ButtonSpec({ ..data, background: color })
    TextFieldSpec(data) => TextFieldSpec({ ..data, background: color })
    ContainerSpec(data) => ContainerSpec({ ..data, background: Some(color) })
    FrameSpec(data) => FrameSpec({ ..data, child: data.child.background(color) })
    _ =>
      ContainerSpec({
        key: self.identity_key(),
        size: None,
        background: Some(color),
        corner_radius: 0.0,
        child: Some(self),
      })
  }
}

///|
pub fn ViewSpec::corner_radius(self : ViewSpec, radius : Double) -> ViewSpec {
  match self {
    ButtonSpec(data) => ButtonSpec({ ..data, corner_radius: radius })
    TextFieldSpec(data) => TextFieldSpec({ ..data, corner_radius: radius })
    ContainerSpec(data) => ContainerSpec({ ..data, corner_radius: radius })
    FrameSpec(data) =>
      FrameSpec({ ..data, child: data.child.corner_radius(radius) })
    _ =>
      ContainerSpec({
        key: self.identity_key(),
        size: None,
        background: None,
        corner_radius: radius,
        child: Some(self),
      })
  }
}

///|
pub fn ViewSpec::padding(self : ViewSpec, value : Double) -> ViewSpec {
  PaddingSpec({ key: None, insets: Insets::all(value), child: self })
}

///|
pub fn ViewSpec::spacing(self : ViewSpec, spacing : Double) -> ViewSpec {
  match self {
    FlexSpec(data) => FlexSpec({ ..data, spacing })
    PaddingSpec(data) => PaddingSpec({ ..data, child: data.child.spacing(spacing) })
    ContainerSpec(data) =>
      ContainerSpec({
        ..data,
        child: map_view_spec(data.child, child => child.spacing(spacing)),
      })
    FrameSpec(data) => FrameSpec({ ..data, child: data.child.spacing(spacing) })
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
        child: map_view_spec(
          data.child,
          child => child.main_axis_alignment(alignment),
        ),
      })
    FrameSpec(data) =>
      FrameSpec({ ..data, child: data.child.main_axis_alignment(alignment) })
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
        child: map_view_spec(
          data.child,
          child => child.cross_axis_alignment(alignment),
        ),
      })
    FrameSpec(data) =>
      FrameSpec({ ..data, child: data.child.cross_axis_alignment(alignment) })
    _ => self
  }
}

///|
pub fn ViewSpec::theme(self : ViewSpec, theme : Theme) -> ViewSpec {
  self.font(theme.font)
    .foreground(theme.foreground)
    .background(theme.background)
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
  FrameSpec({
    key: None,
    width,
    height,
    min_width,
    min_height,
    max_width,
    max_height,
    child: self,
  })
}

///|
fn map_view_spec(value : ViewSpec?, f : (ViewSpec) -> ViewSpec) -> ViewSpec? {
  match value {
    Some(value) => Some(f(value))
    None => None
  }
}

///|
pub fn mount_view_spec(spec : ViewSpec) -> ElementNode {
  mount_view_spec_with_next(spec, 1).node
}

///|
fn mount_view_spec_with_next(spec : ViewSpec, next_id : Int) -> MountResult {
  let id = ElementId::new(next_id)
  let mut next = next_id + 1
  let children : Array[ElementNode] = []
  match spec {
    FlexSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_with_next(child_spec, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    PaddingSpec(data) => {
      let mounted = mount_view_spec_with_next(data.child, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    FrameSpec(data) => {
      let mounted = mount_view_spec_with_next(data.child, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    ContainerSpec(data) =>
      match data.child {
        Some(child) => {
          let mounted = mount_view_spec_with_next(child, next)
          children.push(mounted.node)
          next = mounted.next_id
        }
        None => ()
      }
    _ => ()
  }
  {
    node: {
      id,
      key: spec.identity_key(),
      spec,
      children,
      dirty: DirtyFlags::all(),
      button_state: ButtonState::Normal,
    },
    next_id: next,
  }
}

///|
pub fn reconcile_element(
  old : ElementNode,
  next_spec : ViewSpec,
) -> ElementNode {
  reconcile_element_with_next(old, next_spec, 1).node
}

///|
fn reconcile_element_with_next(
  old : ElementNode,
  next_spec : ViewSpec,
  next_id : Int,
) -> ReconcileResult {
  if !old.spec.same_identity(next_spec) {
    let mounted = mount_view_spec_with_next(next_spec, next_id)
    { node: mounted.node, next_id: mounted.next_id }
  } else {
    let children_result = reconcile_children(old.children, next_spec, next_id)
    old.spec = next_spec
    old.key = old.spec.identity_key()
    old.children = children_result.children
    old.dirty.mark_build()
    { node: old, next_id: children_result.next_id }
  }
}

///|
priv struct ChildrenReconcileResult {
  children : Array[ElementNode]
  next_id : Int
}

///|
fn reconcile_children(
  old_children : Array[ElementNode],
  next_spec : ViewSpec,
  next_id : Int,
) -> ChildrenReconcileResult {
  let next_specs = child_specs(next_spec)
  let children : Array[ElementNode] = []
  let used : Array[Bool] = []
  for _ in old_children {
    used.push(false)
  }
  let mut next = next_id
  for index, child_spec in next_specs {
    let old_index = find_reusable_child(old_children, used, child_spec, index)
    match old_index {
      Some(old_index) => {
        used[old_index] = true
        let result = reconcile_element_with_next(
          old_children[old_index],
          child_spec,
          next,
        )
        children.push(result.node)
        next = result.next_id
      }
      None => {
        let mounted = mount_view_spec_with_next(child_spec, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    }
  }
  { children, next_id: next }
}

///|
fn find_reusable_child(
  old_children : Array[ElementNode],
  used : Array[Bool],
  child_spec : ViewSpec,
  index : Int,
) -> Int? {
  match child_spec.identity_key() {
    Some(key) => {
      for old_index, old_child in old_children {
        if !used[old_index] &&
          old_child.key == Some(key) &&
          old_child.spec.kind() == child_spec.kind() {
          return Some(old_index)
        }
      }
      None
    }
    None =>
      if index < old_children.length() &&
        !used[index] &&
        old_children[index].key is None &&
        old_children[index].spec.kind() == child_spec.kind() {
        Some(index)
      } else {
        None
      }
  }
}

///|
fn child_specs(spec : ViewSpec) -> Array[ViewSpec] {
  match spec {
    FlexSpec(data) => data.children
    PaddingSpec(data) => [data.child]
    FrameSpec(data) => [data.child]
    ContainerSpec(data) =>
      match data.child {
        Some(child) => [child]
        None => []
      }
    _ => []
  }
}

///|
pub fn ElementNode::render(self : ElementNode, bounds : Rect) -> RenderNode {
  self.render_with_focus(bounds, None)
}

///|
fn ElementNode::render_with_focus(
  self : ElementNode,
  bounds : Rect,
  focused : ElementId?,
) -> RenderNode {
  let children : Array[RenderNode] = []
  let commands : Array[DrawCommand] = []
  match self.spec {
    EmptySpec => ()
    SpacerSpec(_) => ()
    TextSpec(data) =>
      commands.push(
        DrawText({
          text: data.text,
          frame: bounds,
          font: data.font,
          color: data.color,
        }),
      )
    ButtonSpec(data) => {
      let background = match self.button_state {
        ButtonState::Normal => data.background
        ButtonState::Hovered => data.hovered_background
        ButtonState::Pressed => data.pressed_background
      }
      if data.corner_radius > 0.0 {
        commands.push(
          FillRoundedRect(
            RoundedRect::new(rect=bounds, radius=data.corner_radius),
            background,
          ),
        )
      } else {
        commands.push(FillRect(bounds, background))
      }
      let foreground = match self.button_state {
        ButtonState::Pressed => Color::white()
        ButtonState::Normal | ButtonState::Hovered => data.foreground
      }
      commands.push(
        DrawText({
          text: data.text,
          frame: bounds,
          font: data.font,
          color: foreground,
        }),
      )
    }
    TextFieldSpec(data) =>
      append_text_field_commands(
        commands,
        data,
        bounds,
        focused == Some(self.id),
      )
    FlexSpec(data) => {
      let frames = flex_child_frames(
        data.axis,
        data.spacing,
        data.main_axis_alignment,
        data.cross_axis_alignment,
        self.children,
        bounds,
      )
      for index, child in self.children {
        children.push(child.render_with_focus(frames[index], focused))
      }
    }
    PaddingSpec(data) => {
      let child_frame = bounds.inset(data.insets)
      if self.children.length() > 0 {
        children.push(self.children[0].render_with_focus(child_frame, focused))
      }
    }
    ContainerSpec(data) => {
      let frame = match data.size {
        Some(size) =>
          Rect::new(
            x=bounds.origin.x,
            y=bounds.origin.y,
            width=size.width,
            height=size.height,
          )
        None => bounds
      }
      match data.background {
        Some(color) =>
          if data.corner_radius > 0.0 {
            commands.push(
              FillRoundedRect(
                RoundedRect::new(rect=frame, radius=data.corner_radius),
                color,
              ),
            )
          } else {
            commands.push(FillRect(frame, color))
          }
        None => ()
      }
      if self.children.length() > 0 {
        children.push(self.children[0].render_with_focus(frame, focused))
      }
    }
    FrameSpec(data) => {
      let frame = frame_rect_for_spec(data, bounds)
      if self.children.length() > 0 {
        children.push(self.children[0].render_with_focus(frame, focused))
      }
    }
  }
  self.dirty.clear()
  {
    element_id: self.id,
    frame: bounds,
    children,
    hit_testable: element_hit_testable(self.spec),
    paint_commands: commands,
  }
}

///|
pub fn ElementNode::intrinsic_size(self : ElementNode) -> Size {
  match self.spec {
    EmptySpec => Size::new(width=0.0, height=0.0)
    TextSpec(data) => data.size
    ButtonSpec(data) => data.size
    TextFieldSpec(data) => data.size
    SpacerSpec(data) =>
      if data.weight > 0.0 {
        Size::new(width=0.0, height=0.0)
      } else {
        Size::new(width=data.min_length, height=data.min_length)
      }
    PaddingSpec(data) =>
      if self.children.length() > 0 {
        self.children[0].intrinsic_size().inflate(data.insets)
      } else {
        Size::new(width=0.0, height=0.0).inflate(data.insets)
      }
    ContainerSpec(data) =>
      match data.size {
        Some(size) => size
        None =>
          if self.children.length() > 0 {
            self.children[0].intrinsic_size()
          } else {
            Size::new(width=0.0, height=0.0)
          }
      }
    FlexSpec(data) => measure_flex_sizes(data.axis, data.spacing, self.children)
    FrameSpec(data) => {
      let child_size = if self.children.length() > 0 {
        self.children[0].intrinsic_size()
      } else {
        Size::new(width=0.0, height=0.0)
      }
      resolve_frame_size(data, child_size)
    }
  }
}

///|
fn element_hit_testable(spec : ViewSpec) -> Bool {
  match spec {
    ButtonSpec(_) => true
    TextFieldSpec(_) => true
    ContainerSpec(data) => data.background is Some(_)
    _ => false
  }
}

///|
pub fn ElementNode::dispatch_pointer(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
) -> ElementEventResult {
  match self.spec {
    ButtonSpec(data) =>
      handle_button_element_pointer(self, data, event, render.frame)
    TextFieldSpec(_) => {
      let focused = if event.phase == PointerPhase::Down &&
        render.frame.contains(event.position) {
        Some(self.id)
      } else {
        None
      }
      { changed: false, activated: false, focused }
    }
    FlexSpec(_) | PaddingSpec(_) | ContainerSpec(_) | FrameSpec(_) => {
      let mut changed = false
      let mut activated = false
      let mut focused : ElementId? = None
      let mut index = self.children.length() - 1
      while index >= 0 {
        if index < render.children.length() &&
          render.children[index].frame.contains(event.position) {
          let result = self.children[index].dispatch_pointer(
            event,
            render.children[index],
          )
          changed = result.changed
          activated = result.activated
          match result.focused {
            Some(_) => focused = result.focused
            None => ()
          }
          break
        }
        index = index - 1
      }
      if changed {
        self.dirty.mark_paint()
      }
      { changed, activated, focused }
    }
    EmptySpec | TextSpec(_) | SpacerSpec(_) =>
      { changed: false, activated: false, focused: None }
  }
}

///|
fn handle_button_element_pointer(
  element : ElementNode,
  data : ButtonViewSpec,
  event : PointerEvent,
  frame : Rect,
) -> ElementEventResult {
  let inside = frame.contains(event.position)
  let tap = recognize_button_tap(element.button_state, inside, event.phase)
  if tap.activated {
    match data.on_click {
      Some(handler) => handler()
      None => ()
    }
  }
  let changed = tap.next_state != element.button_state || tap.activated
  element.button_state = tap.next_state
  if changed {
    element.dirty.mark_paint()
  }
  { changed, activated: tap.activated, focused: None }
}

///|
pub fn ElementNode::render_focused(
  self : ElementNode,
  bounds : Rect,
  focused~ : ElementId?,
) -> RenderNode {
  self.render_with_focus(bounds, focused)
}

///|
pub fn ElementNode::find_text_field_at(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> ElementId? {
  match self.spec {
    TextFieldSpec(_) =>
      if render.frame.contains(point) {
        Some(self.id)
      } else {
        None
      }
    FlexSpec(_) | PaddingSpec(_) | ContainerSpec(_) | FrameSpec(_) => {
      let mut index = self.children.length() - 1
      while index >= 0 {
        if index < render.children.length() &&
          render.children[index].frame.contains(point) {
          match self.children[index].find_text_field_at(point, render.children[index]) {
            Some(id) => return Some(id)
            None => ()
          }
        }
        index = index - 1
      }
      None
    }
    _ => None
  }
}

///|
pub fn ElementNode::focusable_ids(
  self : ElementNode,
  ids : Array[ElementId],
) -> Unit {
  match self.spec {
    TextFieldSpec(_) => ids.push(self.id)
    FlexSpec(_) | PaddingSpec(_) | ContainerSpec(_) | FrameSpec(_) =>
      for child in self.children {
        child.focusable_ids(ids)
      }
    _ => ()
  }
}

///|
pub fn ElementNode::next_focus(
  self : ElementNode,
  current~ : ElementId?,
  reverse~ : Bool,
) -> ElementId? {
  let ids : Array[ElementId] = []
  self.focusable_ids(ids)
  if ids.length() == 0 {
    None
  } else {
    let mut index = -1
    match current {
      Some(current) =>
        for i, id in ids {
          if id == current {
            index = i
          }
        }
      None => ()
    }
    if reverse {
      let next = if index <= 0 { ids.length() - 1 } else { index - 1 }
      Some(ids[next])
    } else {
      let next = if index < 0 || index + 1 >= ids.length() {
        0
      } else {
        index + 1
      }
      Some(ids[next])
    }
  }
}

///|
pub fn ElementNode::find_keyed(
  self : ElementNode,
  key : String,
) -> ElementId? {
  if self.key == Some(Key::new(key)) {
    Some(self.id)
  } else {
    for child in self.children {
      match child.find_keyed(key) {
        Some(id) => return Some(id)
        None => ()
      }
    }
    None
  }
}

///|
pub fn ElementNode::dispatch_keyboard(
  self : ElementNode,
  target : ElementId,
  event : KeyboardEvent,
) -> ElementEventResult {
  if self.id == target {
    match self.spec {
      TextFieldSpec(data) => handle_text_field_keyboard(self, data, event)
      _ => { changed: false, activated: false, focused: None }
    }
  } else {
    let mut changed = false
    let mut activated = false
    for child in self.children {
      let result = child.dispatch_keyboard(target, event)
      changed = changed || result.changed
      activated = activated || result.activated
    }
    if changed {
      self.dirty.mark_paint()
    }
    { changed, activated, focused: None }
  }
}

///|
fn handle_text_field_keyboard(
  element : ElementNode,
  data : TextFieldViewSpec,
  event : KeyboardEvent,
) -> ElementEventResult {
  if !event.pressed {
    return { changed: false, activated: false, focused: None }
  }
  if event.key == "Enter" {
    match data.on_submit {
      Some(handler) => handler()
      None => ()
    }
    element.dirty.mark_paint()
    return { changed: true, activated: true, focused: None }
  }
  if event.key == "Backspace" {
    let next = remove_last_character(data.value.get())
    if next != data.value.get() {
      data.value.set(next)
      element.dirty.mark_paint()
      return { changed: true, activated: false, focused: None }
    }
    return { changed: false, activated: false, focused: None }
  }
  match event.text {
    Some(text) =>
      if text != "" {
        data.value.set(data.value.get() + text)
        element.dirty.mark_paint()
        { changed: true, activated: false, focused: None }
      } else {
        { changed: false, activated: false, focused: None }
      }
    None => { changed: false, activated: false, focused: None }
  }
}

///|
fn remove_last_character(text : String) -> String {
  let chars = text.to_array()
  ignore(chars.pop())
  String::from_array(chars)
}

///|
fn append_text_field_commands(
  commands : Array[DrawCommand],
  data : TextFieldViewSpec,
  frame : Rect,
  focused : Bool,
) -> Unit {
  let border = if focused {
    data.focused_border_color
  } else {
    data.border_color
  }
  if data.corner_radius > 0.0 {
    commands.push(
      FillRoundedRect(
        RoundedRect::new(rect=frame, radius=data.corner_radius),
        data.background,
      ),
    )
    commands.push(
      StrokeRoundedRect(
        RoundedRect::new(rect=frame, radius=data.corner_radius),
        border,
        if focused {
          2.0
        } else {
          1.0
        },
      ),
    )
  } else {
    commands.push(FillRect(frame, data.background))
    commands.push(StrokeRect(frame, border, if focused { 2.0 } else { 1.0 }))
  }
  let text = data.value.get()
  let display = if text == "" { data.placeholder } else { text }
  let color = if text == "" { data.placeholder_color } else { data.foreground }
  let text_frame = frame.inset(Insets::symmetric(horizontal=10.0, vertical=4.0))
  commands.push(
    DrawText({ text: display, frame: text_frame, font: data.font, color }),
  )
  if focused {
    let cursor_x = text_frame.origin.x +
      text.to_array().length().to_double() * data.font.size * 0.55
    let cursor = Rect::new(
      x=cursor_x,
      y=text_frame.origin.y + 6.0,
      width=1.5,
      height=max_double(8.0, text_frame.size.height - 12.0),
    )
    commands.push(FillRect(cursor, data.cursor_color))
  }
}

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
fn spacer_weight(child : ElementNode) -> Double {
  match child.spec {
    SpacerSpec(data) => data.weight
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
pub fn RenderNode::collect_draw_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
) -> Unit {
  for command in self.paint_commands {
    commands.push(command)
  }
  for child in self.children {
    child.collect_draw_commands(commands)
  }
}

///|
pub fn RenderNode::to_layout_result(self : RenderNode) -> LayoutResult {
  {
    frame: self.frame,
    children: self.children.map(child => child.to_layout_result()),
  }
}
