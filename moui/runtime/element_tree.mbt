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
  /// Monotonic counter bumped by `apply_view_context` whenever the applied
  /// context differs from the current one. Overlay placement probing and the
  /// per-node place cache key on it: a view whose `layout`/`place_overlays`
  /// output depends on view state (picker `expanded`, modal `selected`, ...)
  /// must not be served from a cache computed under the previous state.
  /// Over-bumping is safe (extra probes/re-places); under-bumping is not, so
  /// the bump is guarded by a structural compare.
  mut state_revision : Int32
  /// Monotonic counter bumped when the text-control context changes. Paint
  /// plans can read caret/selection/composition state, so the render cache
  /// must not reuse a plan across an edit even when layout is unchanged.
  mut text_revision : Int32
  mut caret : Int32
  mut selection : TextRange?
  mut text_selection_anchor : Int32?
  mut text_selection_origin : Point?
  mut composition : String?
  mut composition_cursor : TextRange?
  mut goal_column : Double?
  mut reveal : Rect?
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
  if value != self.view_state {
    self.view_state = value
    self.state_revision = self.state_revision + 1
  }
}

///|
priv struct ElementLayoutCache {
  mut cached_intrinsic_size : Size?
  mut cached_measure_constraints : Constraints?
  /// Interned environment identity (C1) instead of the full `Environment`
  /// value: 0 means "no environment cached yet".
  mut cached_measure_environment_id : Int32
  mut cached_measure_style : ViewStyle?
  mut cached_measured : MeasuredNode?
  mut cached_place_frame : Rect?
  mut cached_place_environment_id : Int32
  mut cached_place_style : ViewStyle?
  mut cached_placed : PlacedNode?
  /// Full per-node place cache key (C3). The place recursion consults this
  /// entry for every element, not just the root, so an overlay re-place can
  /// reuse unaffected sibling subtrees instead of re-placing the whole tree.
  /// `cached_place_fit` is the ADR 0035 tight-fit flag and
  /// `cached_place_state_revision` the element's view-state revision (views
  /// whose layout reads state must not be served stale). Ancestor transforms
  /// and clips are applied by boundary consumers, not stored here.
  mut cached_place_fit : Bool
  mut cached_place_state_revision : Int32
  /// Monotonic revision bumped whenever this node produces a new placed
  /// subtree. Paint can read child frames, so the render cache must observe
  /// placement changes even when the node's own frame is unchanged.
  mut place_revision : Int32
  /// Classification of this node's `child_environment` for the current view
  /// node and parent environment identity. Not cache content: it survives
  /// `clear()`. A changed view node or environment identity forces
  /// reclassification because a scope can be a structural no-op for one input
  /// and change the environment for another.
  mut child_environment_classified : Bool
  mut child_environment_input_id : Int32
  mut child_environment_passthrough : Bool
  mut hit_count : Int32
  mut miss_count : Int32
}

///|
/// Everything a render-cache entry depends on, excluding the animation clock.
/// Time-dependent paint plans bypass the cache through
/// `ViewPaintPlan.animating` or the overlay-enter fade check; a static plan may
/// be reused across ticks.
priv struct RenderCacheKey {
  frame : Rect
  focused : Bool
  environment_id : Int32
  style : ViewStyle
  font : FontSpec?
  foreground : Color?
  corner_radius : Double?
  text_system_id : String
  state_revision : Int32
  text_revision : Int32
  place_revision : Int32
} derive(Eq)

///|
priv struct ElementRenderCache {
  mut cached_key : RenderCacheKey?
  mut cached_plan : ViewPaintPlan?
  mut cached_render : RenderNode?
  mut content_revision : Int32
  mut hit_count : Int32
  mut miss_count : Int32
}

///|
priv struct ElementSemanticsCache {
  mut frame : Rect?
  mut transform : Transform2D?
  /// Interned environment identity (C1) instead of the full `Environment`.
  mut environment_id : Int32
  mut style : ViewStyle?
  roots : Array[SemanticsNodeId]
}

///|
priv struct ElementPlatformCache {
  mut frame : Rect?
  /// Interned environment identity (C1) instead of the full `Environment`.
  mut environment_id : Int32
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
    text_selection_origin: self.text_selection_origin,
    composition: self.composition,
    composition_cursor: self.composition_cursor,
    undo_stack: self.text_undo_stack.copy(),
    redo_stack: self.text_redo_stack.copy(),
    goal_column: self.goal_column,
    reveal: self.reveal,
  }
}

///|
/// Consume a reveal request: the element reports the rect it wants made
/// visible exactly once, and the frame that scrolls it into view clears
/// the request. A view never has to reset the field itself.
fn ElementControlState::take_reveal(self : ElementControlState) -> Rect? {
  let reveal = self.reveal
  self.reveal = None
  reveal
}

///|
fn ElementControlState::apply_text_context(
  self : ElementControlState,
  value : @core.TextControlStateContext,
) -> Unit {
  let changed = self.caret != value.caret ||
    self.selection != value.selection ||
    self.text_selection_anchor != value.text_selection_anchor ||
    self.text_selection_origin != value.text_selection_origin ||
    self.composition != value.composition ||
    self.composition_cursor != value.composition_cursor ||
    self.goal_column != value.goal_column ||
    self.reveal != value.reveal ||
    self.text_undo_stack != value.undo_stack ||
    self.text_redo_stack != value.redo_stack
  self.caret = value.caret
  self.selection = value.selection
  self.text_selection_anchor = value.text_selection_anchor
  self.text_selection_origin = value.text_selection_origin
  self.composition = value.composition
  self.composition_cursor = value.composition_cursor
  self.goal_column = value.goal_column
  self.reveal = value.reveal
  self.text_undo_stack.clear()
  self.text_undo_stack.append(value.undo_stack.copy())
  self.text_redo_stack.clear()
  self.text_redo_stack.append(value.redo_stack.copy())
  if changed {
    self.text_revision = self.text_revision + 1
  }
}

///|
priv struct RenderNode {
  element_id : ElementId
  /// Frame in the parent's child-coordinate space. Hoisted overlay roots
  /// already use screen coordinates.
  frame : Rect
  /// Transform from this node's child-coordinate space into this node's local
  /// coordinate space.
  child_transform : Transform2D
  clips_children : Bool
  children : Array[RenderNode]
  /// True for children whose placed frames are overlay-positioned. They are
  /// painted after the whole tree so popup content escapes ancestor clip
  /// rects, and they win hit-test priority.
  is_overlay_child : Bool
  /// Paint layers already carry commands in their parent render node's
  /// coordinate space, so their frame origin is metadata rather than a child
  /// placement offset.
  is_paint_layer : Bool
  paint_bounds : Rect
  /// Enter-fade opacity for hoisted overlay subtrees. `None` or 1.0 renders
  /// normally; values below 1.0 wrap the subtree in a fading opacity layer.
  render_opacity : Double?
  content_revision : Int32
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
  /// Frame in the parent's child-coordinate space, matching `PlacedNode`.
  frame : Rect
  child_transform : Transform2D
  overlay_child_indices : Array[Int32]
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
    child_transform: Transform2D::identity(),
    clips_children: false,
    children: [],
    is_overlay_child: false,
    is_paint_layer: false,
    paint_bounds: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
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
  { root: mount_runtime_view_node(empty_runtime_view_node()), }
}

///|
fn ElementTree::id(self : ElementTree) -> ElementId {
  self.root.id
}

///|
fn RenderTree::empty() -> RenderTree {
  { root: RenderNode::empty(), }
}

///|
fn PlatformNode::empty() -> PlatformNode {
  {
    placements: [],
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    child_transform: Transform2D::identity(),
    overlay_child_indices: [],
    children: [],
  }
}

///|
fn PlatformTree::empty() -> PlatformTree {
  { root: PlatformNode::empty(), }
}

///|
fn LayoutTree::empty() -> LayoutTree {
  {
    root: {
      element_id: ElementId::new(0),
      frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
      child_transform: Transform2D::identity(),
      clips_children: false,
      children: [],
      overlay_child_indices: [],
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
    state_revision: 0,
    text_revision: 0,
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    goal_column: None,
    reveal: None,
    text_selection_origin: None,
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
    cached_measure_environment_id: 0,
    cached_measure_style: None,
    cached_measured: None,
    cached_place_frame: None,
    cached_place_environment_id: 0,
    cached_place_style: None,
    cached_placed: None,
    cached_place_fit: false,
    cached_place_state_revision: -1,
    place_revision: 0,
    child_environment_classified: false,
    child_environment_input_id: 0,
    child_environment_passthrough: false,
    hit_count: 0,
    miss_count: 0,
  }
}

///|
fn ElementLayoutCache::clear(self : ElementLayoutCache) -> Unit {
  self.cached_intrinsic_size = None
  self.cached_measure_constraints = None
  self.cached_measure_environment_id = 0
  self.cached_measure_style = None
  self.cached_measured = None
  self.cached_place_frame = None
  self.cached_place_environment_id = 0
  self.cached_place_style = None
  self.cached_placed = None
  self.cached_place_fit = false
  self.cached_place_state_revision = -1
}

///|
fn ElementRenderCache::empty() -> ElementRenderCache {
  {
    cached_key: None,
    cached_plan: None,
    cached_render: None,
    content_revision: 0,
    hit_count: 0,
    miss_count: 0,
  }
}

///|
fn ElementRenderCache::clear(self : ElementRenderCache) -> Unit {
  self.cached_key = None
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
  { frame: None, transform: None, environment_id: 0, style: None, roots: [], }
}

///|
fn ElementSemanticsCache::clear(self : ElementSemanticsCache) -> Unit {
  self.frame = None
  self.transform = None
  self.environment_id = 0
  self.style = None
  self.roots.clear()
}

///|
fn ElementPlatformCache::empty() -> ElementPlatformCache {
  { frame: None, environment_id: 0, style: None, node: None, }
}
