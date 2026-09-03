///|
priv struct ElementNode {
  id : ElementId
  mut semantics_node_id : SemanticsNodeId?
  mut key : Key?
  mut view_node : &RuntimeViewNode
  mut children : Array[ElementNode]
  dirty : DirtyFlags
  control : ElementControlState
  layout_cache : ElementLayoutCache
  render_cache : ElementRenderCache
  semantics_cache : ElementSemanticsCache
  platform_cache : ElementPlatformCache
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
  mut view_state : @core.ViewStateContext
  mut caret : Int
  mut selection : TextRange?
  mut text_selection_anchor : Int?
  mut composition : String?
  mut composition_cursor : TextRange?
  text_undo_stack : Array[@core.TextHistoryEntryContext]
  text_redo_stack : Array[@core.TextHistoryEntryContext]
}

///|
fn ElementControlState::view_context(
  self : ElementControlState,
  focused : Bool,
) -> @core.ViewStateContext {
  { ..self.view_state, focused, }
}

///|
fn ElementControlState::apply_view_context(
  self : ElementControlState,
  value : @core.ViewStateContext,
) -> Unit {
  self.view_state = value
}

///|
priv struct ElementLayoutCache {
  mut cached_intrinsic_size : Size?
  mut cached_measure_constraints : Constraints?
  mut cached_measure_environment : Environment?
  mut cached_measure_style : ViewStyle?
  mut cached_measured : MeasuredNode?
  mut cached_place_frame : Rect?
  mut cached_place_environment : Environment?
  mut cached_place_style : ViewStyle?
  mut cached_placed : PlacedNode?
  mut hit_count : Int
  mut miss_count : Int
}

///|
priv struct ElementRenderCache {
  mut cached_render_frame : Rect?
  mut cached_render_focused : ElementId?
  mut cached_plan : ViewPaintPlan?
  mut cached_render : RenderNode?
  mut content_revision : Int
  mut hit_count : Int
  mut miss_count : Int
}

///|
priv struct ElementSemanticsCache {
  mut frame : Rect?
  mut environment : Environment?
  mut style : ViewStyle?
  roots : Array[SemanticsNodeId]
}

///|
priv struct ElementPlatformCache {
  mut frame : Rect?
  mut environment : Environment?
  mut style : ViewStyle?
  mut node : PlatformNode?
}

///|
fn ElementControlState::text_context(
  self : ElementControlState,
) -> @core.TextControlStateContext {
  {
    caret: self.caret,
    selection: self.selection,
    text_selection_anchor: self.text_selection_anchor,
    composition: self.composition,
    composition_cursor: self.composition_cursor,
    undo_stack: self.text_undo_stack.copy(),
    redo_stack: self.text_redo_stack.copy(),
  }
}

///|
fn ElementControlState::apply_text_context(
  self : ElementControlState,
  value : @core.TextControlStateContext,
) -> Unit {
  self.caret = value.caret
  self.selection = value.selection
  self.text_selection_anchor = value.text_selection_anchor
  self.composition = value.composition
  self.composition_cursor = value.composition_cursor
  self.text_undo_stack.clear()
  self.text_undo_stack.append(value.undo_stack.copy())
  self.text_redo_stack.clear()
  self.text_redo_stack.append(value.redo_stack.copy())
}

///|
priv struct RenderNode {
  element_id : ElementId
  frame : Rect
  children : Array[RenderNode]
  /// True for children whose placed frames are overlay-positioned. They are
  /// painted after the whole tree so popup content escapes ancestor clip
  /// rects, and they win hit-test priority.
  is_overlay_child : Bool
  paint_bounds : Rect
  /// Hit region from the placed tree (frame ∩ accumulated clip). `None`
  /// means "use paint_bounds".
  hit_rect : Rect?
  /// Enter-fade opacity for hoisted overlay subtrees. `None` or 1.0 renders
  /// normally; values below 1.0 wrap the subtree in a fading opacity layer.
  render_opacity : Double?
  content_revision : Int
  is_repaint_boundary : Bool
  layer_cache_key : String?
  paint_commands : Array[DrawCommand]
  post_paint_commands : Array[DrawCommand]
  overlay_paint_commands : Array[DrawCommand]
  cached_draw_commands : Array[DrawCommand]?
  cached_overlay_draw_commands : Array[DrawCommand]?
  /// True when this node or any descendant reported a mid-animation paint
  /// sample (`ViewPaintPlan.animating`). Folded up the tree so the runtime
  /// can keep ticking redraws while any animation is in flight.
  animating : Bool
}

///|

///|
priv struct RenderTree {
  root : RenderNode
}

///|
priv struct PlatformNode {
  placements : Array[PlatformViewPlacement]
  children : Array[PlatformNode]
}

///|
priv struct PlatformTree {
  root : PlatformNode
}

///|
fn RenderNode::empty() -> RenderNode {
  {
    element_id: ElementId::new(0),
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    children: [],
    is_overlay_child: false,
    paint_bounds: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    hit_rect: None,
    render_opacity: None,
    content_revision: 0,
    is_repaint_boundary: false,
    layer_cache_key: None,
    paint_commands: [],
    post_paint_commands: [],
    overlay_paint_commands: [],
    cached_draw_commands: None,
    cached_overlay_draw_commands: None,
    animating: false,
  }
}

///|
fn ElementTree::new(root : ElementNode) -> ElementTree {
  { root, }
}

///|
fn ElementTree::empty() -> ElementTree {
  { root: mount_runtime_view_node(empty_runtime_view_node()) }
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
fn PlatformNode::empty() -> PlatformNode {
  { placements: [], children: [] }
}

///|
fn PlatformTree::empty() -> PlatformTree {
  { root: PlatformNode::empty() }
}

///|
fn LayoutTree::empty() -> LayoutTree {
  {
    root: {
      element_id: ElementId::new(0),
      frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
      children: [],
      overlay_child_indices: [],
      hit_rect: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    },
  }
}

///|
fn ElementControlState::new() -> ElementControlState {
  {
    view_state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
    text_undo_stack: [],
    text_redo_stack: [],
  }
}

///|
fn ElementLayoutCache::empty() -> ElementLayoutCache {
  {
    cached_intrinsic_size: None,
    cached_measure_constraints: None,
    cached_measure_environment: None,
    cached_measure_style: None,
    cached_measured: None,
    cached_place_frame: None,
    cached_place_environment: None,
    cached_place_style: None,
    cached_placed: None,
    hit_count: 0,
    miss_count: 0,
  }
}

///|
fn ElementLayoutCache::clear(self : ElementLayoutCache) -> Unit {
  self.cached_intrinsic_size = None
  self.cached_measure_constraints = None
  self.cached_measure_environment = None
  self.cached_measure_style = None
  self.cached_measured = None
  self.cached_place_frame = None
  self.cached_place_environment = None
  self.cached_place_style = None
  self.cached_placed = None
}

///|
fn ElementRenderCache::empty() -> ElementRenderCache {
  {
    cached_render_frame: None,
    cached_render_focused: None,
    cached_plan: None,
    cached_render: None,
    content_revision: 0,
    hit_count: 0,
    miss_count: 0,
  }
}

///|
fn ElementRenderCache::clear(self : ElementRenderCache) -> Unit {
  self.cached_render_frame = None
  self.cached_render_focused = None
  self.cached_plan = None
  self.cached_render = None
}

///|
fn ElementRenderCache::invalidate_composition(
  self : ElementRenderCache,
) -> Unit {
  self.cached_render = None
}

///|
fn ElementSemanticsCache::empty() -> ElementSemanticsCache {
  { frame: None, environment: None, style: None, roots: [] }
}

///|
fn ElementSemanticsCache::clear(self : ElementSemanticsCache) -> Unit {
  self.frame = None
  self.environment = None
  self.style = None
  self.roots.clear()
}

///|
fn ElementPlatformCache::empty() -> ElementPlatformCache {
  { frame: None, environment: None, style: None, node: None }
}
