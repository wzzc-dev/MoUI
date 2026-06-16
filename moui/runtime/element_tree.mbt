///|
priv struct ElementNode {
  id : ElementId
  mut key : Key?
  mut widget : RuntimeWidget
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
  mut caret : Int
  mut selection : TextRange?
  mut text_selection_anchor : Int?
  mut composition : String?
  mut composition_cursor : TextRange?
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
priv struct TextHistoryEntry {
  text : String
  caret : Int
  selection : TextRange?
}

///|
fn TextHistoryEntry::to_context(
  self : TextHistoryEntry,
) -> @core.TextHistoryEntryContext {
  { text: self.text, caret: self.caret, selection: self.selection }
}

///|
fn TextHistoryEntry::from_context(
  value : @core.TextHistoryEntryContext,
) -> TextHistoryEntry {
  { text: value.text, caret: value.caret, selection: value.selection }
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
    undo_stack: self.text_undo_stack.map(entry => entry.to_context()),
    redo_stack: self.text_redo_stack.map(entry => entry.to_context()),
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
  self.text_undo_stack.append(
    value.undo_stack.map(entry => TextHistoryEntry::from_context(entry)),
  )
  self.text_redo_stack.clear()
  self.text_redo_stack.append(
    value.redo_stack.map(entry => TextHistoryEntry::from_context(entry)),
  )
}

///|
priv struct RenderNode {
  element_id : ElementId
  frame : Rect
  children : Array[RenderNode]
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
}

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
  { root: mount_runtime_widget(empty_runtime_widget()) }
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
