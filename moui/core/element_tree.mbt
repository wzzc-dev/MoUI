///|
priv struct ElementNode {
  id : ElementId
  mut key : Key?
  mut spec : ViewSpec
  mut children : Array[ElementNode]
  dirty : DirtyFlags
  control : ElementControlState
  component : ElementComponentState
  layout_cache : ElementLayoutCache
  render_cache : ElementRenderCache
}

///|
priv struct ElementTree {
  root : ElementNode
}

///|
priv struct LayoutTree {
  root : PlacedNode
}

///|
priv struct ElementControlState {
  mut button_state : ButtonState
  mut picker_expanded : Bool
  mut datepicker_expanded : Bool
  mut datepicker_view : DateValue
  mut caret : Int
  mut selection : TextRange?
  mut text_selection_anchor : Int?
  mut composition : String?
  mut composition_cursor : TextRange?
  mut long_press_gesture : LongPressGestureState
  mut double_tap_gesture : DoubleTapGestureState
  mut drag_gesture : DragGestureState
  text_undo_stack : Array[TextHistoryEntry]
  text_redo_stack : Array[TextHistoryEntry]
}

///|
priv struct ElementComponentState {
  mut component_subscriptions : Array[StateSubscription]
  mut component_effects : Array[ComponentEffect]
}

///|
priv struct ElementLayoutCache {
  mut cached_intrinsic_size : Size?
  mut cached_measure_constraints : Constraints?
  mut cached_measured : MeasuredNode?
  mut cached_place_frame : Rect?
  mut cached_placed : PlacedNode?
}

///|
priv struct ElementRenderCache {
  mut cached_render_frame : Rect?
  mut cached_render_focused : ElementId?
  mut cached_render : RenderNode?
  mut content_revision : Int
}

///|
struct TextHistoryEntry {
  text : String
  caret : Int
  selection : TextRange?
} derive(Eq, Debug, ToJson)

///|
fn TextHistoryEntry::from_element(
  text : String,
  element : ElementNode,
) -> TextHistoryEntry {
  { text, caret: element.control.caret, selection: element.control.selection }
}

///|
struct RenderNode {
  element_id : ElementId
  frame : Rect
  children : Array[RenderNode]
  hit_testable : Bool
  paint_bounds : Rect
  content_revision : Int
  is_repaint_boundary : Bool
  layer_cache_key : String?
  paint_commands : Array[DrawCommand]
  post_paint_commands : Array[DrawCommand]
  overlay_paint_commands : Array[DrawCommand]
  platform_views : Array[PlatformViewPlacement]
  cached_draw_commands : Array[DrawCommand]?
  cached_overlay_draw_commands : Array[DrawCommand]?
} derive(Eq, Debug, ToJson)

///|
priv struct CachedLayerState {
  key : String
  content_revision : Int
}

///|
priv struct RenderTree {
  root : RenderNode
}

///|
fn RenderNode::empty() -> RenderNode {
  {
    element_id: ElementId::new(0),
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    children: [],
    hit_testable: false,
    paint_bounds: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    content_revision: 0,
    is_repaint_boundary: false,
    layer_cache_key: None,
    paint_commands: [],
    post_paint_commands: [],
    overlay_paint_commands: [],
    platform_views: [],
    cached_draw_commands: None,
    cached_overlay_draw_commands: None,
  }
}

///|
fn ElementTree::new(root : ElementNode) -> ElementTree {
  { root, }
}

///|
fn ElementTree::empty() -> ElementTree {
  { root: mount_view_spec(ViewSpec::EmptySpec) }
}

///|
fn ElementTree::id(self : ElementTree) -> ElementId {
  self.root.id
}

///|
fn RenderTree::empty() -> RenderTree {
  { root: RenderNode::empty() }
}

///|
fn LayoutTree::empty() -> LayoutTree {
  {
    root: {
      element_id: ElementId::new(0),
      frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
      children: [],
    },
  }
}

///|
fn ElementControlState::new() -> ElementControlState {
  {
    button_state: ButtonState::Normal,
    picker_expanded: false,
    datepicker_expanded: false,
    datepicker_view: DateValue::today(),
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
    long_press_gesture: LongPressGestureState::new(),
    double_tap_gesture: DoubleTapGestureState::new(),
    drag_gesture: DragGestureState::new(),
    text_undo_stack: [],
    text_redo_stack: [],
  }
}

///|
fn ElementComponentState::new(
  subscriptions~ : Array[StateSubscription],
  effects~ : Array[ComponentEffect],
) -> ElementComponentState {
  { component_subscriptions: subscriptions, component_effects: effects }
}

///|
fn ElementLayoutCache::empty() -> ElementLayoutCache {
  {
    cached_intrinsic_size: None,
    cached_measure_constraints: None,
    cached_measured: None,
    cached_place_frame: None,
    cached_placed: None,
  }
}

///|
fn ElementLayoutCache::clear(self : ElementLayoutCache) -> Unit {
  self.cached_intrinsic_size = None
  self.cached_measure_constraints = None
  self.cached_measured = None
  self.cached_place_frame = None
  self.cached_placed = None
}

///|
fn ElementRenderCache::empty() -> ElementRenderCache {
  {
    cached_render_frame: None,
    cached_render_focused: None,
    cached_render: None,
    content_revision: 0,
  }
}

///|
fn ElementRenderCache::clear(self : ElementRenderCache) -> Unit {
  self.cached_render_frame = None
  self.cached_render_focused = None
  self.cached_render = None
}
