///|
priv struct RuntimeState {
  mut element_tree : ElementTree
  mut layout_tree : LayoutTree
  mut render_tree : RenderTree
  mut platform_tree : PlatformTree
  mut size : Size
  dirty : DirtyTracking
  stats : RenderStats
  mut next_element_id : Int
  animfocus : AnimFocusState
  mut environment : Environment
  mut text_system : TextSystem
  mut redraw_callback : (() -> Unit)?
  mut action_commands : ActionCommandMap
  begin_message_batch : () -> Unit
  end_message_batch : () -> Unit
  mut event_observer : (AppEvent) -> Unit
  clock : Clock
  saveable_state : SaveableStateStore
  mut pending_scroll_request : ScrollRequest?
  mut closed : Bool
  semantics : SemanticsSubsystem
}

///|
priv struct ScrollRequest {
  key : String
  alignment : ScrollAlignment
}

///|
fn[Msg] RuntimeState::new_view(
  root~ : @core.View[Msg],
  size~ : Size,
  environment? : Environment = Environment::neutral(),
  on_message? : ((Msg) -> Unit)? = None,
  begin_message_batch? : () -> Unit = () => (),
  end_message_batch? : () -> Unit = () => (),
) -> RuntimeState {
  let emit = match on_message {
    Some(handler) => handler
    None => _message => ()
  }
  RuntimeState::new_runtime_view_node(
    root=adapt_view_for_runtime(root, emit),
    size~,
    environment~,
    begin_message_batch~,
    end_message_batch~,
  )
}

///|
fn RuntimeState::new_runtime_view_node(
  root~ : &RuntimeViewNode,
  size~ : Size,
  environment? : Environment = Environment::neutral(),
  begin_message_batch? : () -> Unit = () => (),
  end_message_batch? : () -> Unit = () => (),
) -> RuntimeState {
  let initial = mount_runtime_view_node_with_next(root, 1)
  let state = {
    element_tree: ElementTree::new(initial.node),
    layout_tree: LayoutTree::empty(),
    render_tree: RenderTree::empty(),
    platform_tree: PlatformTree::empty(),
    size,
    dirty: DirtyTracking::new(),
    stats: RenderStats::new(),
    next_element_id: initial.next_id,
    animfocus: AnimFocusState::new(),
    environment,
    text_system: TextSystem::fallback(),
    redraw_callback: None,
    action_commands: ActionCommandMap::new(),
    begin_message_batch,
    end_message_batch,
    event_observer: _event => (),
    clock: Clock::new(),
    saveable_state: SaveableStateStore::new(),
    pending_scroll_request: None,
    closed: false,
    semantics: SemanticsSubsystem::new(),
  }
  let mounted = mount_runtime_view_node_for_runtime(root, Some(state), 1)
  state.element_tree = ElementTree::new(mounted.node)
  state.next_element_id = mounted.next_id
  state.mark_dirty(state.element_tree.id())
  state.render_current_tree()
  state
}

///|
fn RuntimeState::environment(self : RuntimeState) -> Environment {
  self.environment
}

///|
fn RuntimeState::text_system(self : RuntimeState) -> TextSystem {
  self.text_system
}

///|
fn RuntimeState::set_text_system(
  self : RuntimeState,
  text_system : TextSystem,
) -> Unit {
  self.text_system = text_system
  self.dirty.needs_layout = true
  self.dirty.needs_paint = true
  self.dirty.needs_redraw = true
  self.element_tree.root.mark_subtree_layout_dirty()
  self.mark_layout_dirty(self.element_tree.id())
}

///|
fn RuntimeState::register_font_data(
  self : RuntimeState,
  family : FontFamily,
  data : Bytes,
) -> Unit {
  self.text_system.register_font_data(family, data)
  self.dirty.needs_layout = true
  self.dirty.needs_paint = true
  self.dirty.needs_redraw = true
  self.element_tree.root.mark_subtree_layout_dirty()
  self.mark_layout_dirty(self.element_tree.id())
}

///|
fn RuntimeState::set_environment(
  self : RuntimeState,
  environment : Environment,
) -> Unit {
  if self.environment != environment {
    self.environment = environment
    self.dirty.needs_rebuild = self.element_tree.root.mark_component_tree_build_dirty()
    self.dirty.needs_layout = true
    self.dirty.needs_paint = true
    self.dirty.needs_redraw = true
    self.element_tree.root.mark_subtree_layout_dirty()
    self.mark_build_dirty(self.element_tree.id())
  }
}

///|
fn RuntimeState::request_destroy(
  self : RuntimeState,
  destroy_program : () -> Unit,
) -> Unit {
  if self.semantics.semantics_action_dispatching {
    self.semantics.semantics_destroy_requested = true
    self.semantics.semantics_destroy_program = Some(destroy_program)
  } else {
    destroy_program()
    self.destroy_now()
  }
}

///|
fn RuntimeState::discard_semantics_destroy_request(self : RuntimeState) -> Unit {
  self.semantics.semantics_destroy_requested = false
  self.semantics.semantics_destroy_program = None
}

///|
fn RuntimeState::complete_semantics_destroy_request(
  self : RuntimeState,
) -> Bool {
  if !self.semantics.semantics_destroy_requested {
    return false
  }
  let destroy_program = self.semantics.semantics_destroy_program
  self.discard_semantics_destroy_request()
  match destroy_program {
    Some(destroy) => destroy()
    None => ()
  }
  self.destroy_now()
  true
}

///|
fn RuntimeState::destroy_now(self : RuntimeState) -> Unit {
  self.element_tree.root.cancel_component_tree_subscriptions(
    reason=ComponentEffectCancelReason::EffectRuntimeDestroyed,
  )
  self.element_tree = ElementTree::empty()
  self.layout_tree = LayoutTree::empty()
  self.render_tree = RenderTree::empty()
  self.platform_tree = PlatformTree::empty()
  self.next_element_id = 1
  self.dirty.dirty_elements.clear()
  self.dirty.dirty_build_elements.clear()
  self.dirty.dirty_layout_elements.clear()
  self.dirty.dirty_paint_elements.clear()
  self.dirty.dirty_semantics_elements.clear()
  self.dirty.dirty_platform_elements.clear()
  self.animfocus.focused_element = None
  self.animfocus.active_pointer_capture = None
  self.pending_scroll_request = None
  self.dirty.needs_rebuild = false
  self.dirty.needs_layout = false
  self.dirty.needs_paint = false
  self.dirty.needs_semantics = false
  self.dirty.needs_platform = false
  self.dirty.needs_redraw = false
  self.dirty.rebuild_wakeup_redraw = false
  self.stats.rebuild_pass_count = 0
  self.stats.layout_pass_count = 0
  self.stats.paint_pass_count = 0
  self.stats.semantics_recompute_count = 0
  self.stats.draw_command_build_count = 0
  self.stats.cache_epoch = 0
  self.stats.last_damage_region = DamageRegion::empty()
  self.stats.known_layer_cache_keys.clear()
  self.stats.cached_layer_admissions.clear()
  self.closed = true
  self.semantics.semantics_tree = SemanticsTree::empty()
  self.semantics.committed_semantics = SemanticsSnapshot::empty()
  self.semantics.semantics_initialized = false
  self.semantics.semantics_journal.clear()
  self.semantics.semantic_id_index.clear()
  self.semantics.semantics_commit_in_progress = false
  self.semantics.semantics_action_dispatching = false
  self.discard_semantics_destroy_request()
}

///|
fn RuntimeState::set_redraw_callback(
  self : RuntimeState,
  callback : () -> Unit,
) -> Unit {
  self.redraw_callback = Some(callback)
}

///|
fn RuntimeState::layout(self : RuntimeState) -> LayoutResult {
  self.ensure_layout_tree()
  self.layout_tree.root.to_layout_result()
}

///|
fn RuntimeState::cached_layout(self : RuntimeState) -> LayoutResult {
  self.layout_tree.root.to_layout_result()
}

///|
fn RuntimeState::cached_layout_tree_root(self : RuntimeState) -> PlacedNode {
  self.layout_tree.root
}

///|
fn RuntimeState::view_tree_inspector_snapshot(
  self : RuntimeState,
) -> ViewTreeInspectorSnapshot {
  self.element_tree.root.view_tree_inspector_snapshot()
}

///|
fn RuntimeState::cached_semantics(self : RuntimeState) -> SemanticsSnapshot {
  self.commit_semantics()
  self.semantics.committed_semantics
}

///|
fn RuntimeState::inspector_rebuild_reason(self : RuntimeState) -> String {
  if self.dirty.needs_rebuild {
    "rebuild requested"
  } else if self.dirty.needs_layout {
    "layout requested"
  } else if self.dirty.needs_paint {
    "paint requested"
  } else if self.dirty.needs_redraw {
    "redraw requested"
  } else {
    "clean"
  }
}

///|
fn RuntimeState::inspector_dirty_reasons(self : RuntimeState) -> Array[String] {
  let reasons : Array[String] = []
  if self.dirty.needs_rebuild {
    reasons.push("rebuild")
  }
  if self.dirty.needs_layout {
    reasons.push("layout")
  }
  if self.dirty.needs_paint {
    reasons.push("paint")
  }
  if self.dirty.needs_redraw {
    reasons.push("redraw")
  }
  if self.dirty.dirty_elements.length() > 0 {
    reasons.push("dirty elements: \{self.dirty.dirty_elements.length()}")
  }
  reasons
}

///|
fn RuntimeState::focused_text_input(self : RuntimeState) -> TextInputState {
  self.ensure_render_tree()
  match self.animfocus.focused_element {
    Some(target) =>
      match
        self.element_tree.root.focused_text_input(
          target,
          self.render_tree.root,
          text_system=self.text_system,
          environment=self.environment,
        ) {
        Some(state) => state
        None => TextInputState::none()
      }
    None => TextInputState::none()
  }
}

///|
fn RuntimeState::build_draw_commands(self : RuntimeState) -> Array[DrawCommand] {
  self.stats.draw_command_build_count = self.stats.draw_command_build_count + 1
  let commands : Array[DrawCommand] = Array::new(
    capacity=self.stats.last_command_count.max(64),
  )
  commands.push(Clear(Color::white()))
  self.rebuild_if_possible()
  self.ensure_render_tree()
  self.render_tree.root.collect_draw_commands(commands)
  self.stats.last_command_count = commands.length()
  commands
}

///|
fn RuntimeState::build_draw_frame(self : RuntimeState) -> DrawFrame {
  self.stats.draw_command_build_count = self.stats.draw_command_build_count + 1
  let commands : Array[DrawCommand] = Array::new(
    capacity=self.stats.last_command_count.max(64),
  )
  let next_known_layers : Array[CachedLayerState] = []
  let next_admissions : Array[CachedLayerAdmissionState] = []
  self.rebuild_if_possible()
  self.ensure_render_tree()
  self.render_tree.root.collect_frame_commands(
    commands,
    self.stats.known_layer_cache_keys,
    self.stats.cached_layer_admissions,
    next_known_layers,
    next_admissions,
  )
  let platform_views = self.platform_tree.placements()
  self.record_cached_layer_frame(next_known_layers, next_admissions)
  self.stats.last_command_count = commands.length()
  DrawFrame::new(
    commands~,
    platform_views~,
    damage=self.stats.last_damage_region,
    clear_color=Color::white(),
    cache_epoch=self.stats.cache_epoch,
  )
}

///|
fn RuntimeState::cached_draw_commands(
  self : RuntimeState,
) -> Array[DrawCommand] {
  let commands : Array[DrawCommand] = [Clear(Color::white())]
  self.render_tree.root.collect_draw_commands(commands)
  commands
}

///|
fn RuntimeState::rebuild_if_possible(self : RuntimeState) -> Unit {
  if self.dirty.needs_rebuild {
    if self.element_tree.root.has_dirty_build() {
      self.stats.rebuild_pass_count = self.stats.rebuild_pass_count + 1
      let result = self.element_tree.root.rebuild_dirty_components(
        self,
        self.next_element_id,
      )
      self.element_tree = ElementTree::new(result.node)
      self.next_element_id = result.next_id
      self.clear_stale_pointer_capture()
      self.mark_current_dirty_elements()
    }
    self.dirty.needs_rebuild = self.element_tree.root.has_dirty_build()
    if !self.dirty.needs_rebuild {
      self.dirty.dirty_build_elements.clear()
      self.refresh_dirty_element_queue()
    }
  }
}

///|
fn RuntimeState::request_component_rebuild(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  if self.element_tree.root.mark_build_dirty_by_id(id) {
    self.queue_dirty_element(id)
    self.queue_build_dirty(id)
    self.dirty.needs_rebuild = true
    self.request_rebuild_wakeup()
  }
}

///|
fn RuntimeState::request_activation_rebuild(self : RuntimeState) -> Unit {
  if !self.element_tree.root.has_dirty_build() &&
    self.element_tree.root.mark_root_component_build_dirty() {
    self.queue_dirty_element(self.element_tree.id())
    self.queue_build_dirty(self.element_tree.id())
  }
  self.dirty.needs_rebuild = self.element_tree.root.has_dirty_build()
  if self.dirty.needs_rebuild {
    self.request_rebuild_wakeup()
  }
}

///|
/// Subsystem: combined dirty flags + per-phase element queues.
priv struct DirtyTracking {
  mut needs_redraw : Bool
  mut needs_rebuild : Bool
  mut needs_layout : Bool
  mut needs_paint : Bool
  mut needs_semantics : Bool
  mut needs_platform : Bool
  mut rebuild_wakeup_redraw : Bool
  dirty_elements : Array[ElementId]
  dirty_build_elements : Array[ElementId]
  dirty_layout_elements : Array[ElementId]
  dirty_paint_elements : Array[ElementId]
  dirty_semantics_elements : Array[ElementId]
  dirty_platform_elements : Array[ElementId]
}

///|
/// Subsystem: semantics tree, snapshot, journal, and action-safe destroy lifecycle.
priv struct SemanticsSubsystem {
  mut semantics_tree : SemanticsTree
  mut committed_semantics : SemanticsSnapshot
  mut semantics_initialized : Bool
  semantics_journal : Array[SemanticsDelta]
  mut next_semantics_node_id : UInt64
  semantic_id_index : Map[SemanticId, SemanticIdIndexEntry]
  mut semantics_commit_in_progress : Bool
  mut semantics_action_dispatching : Bool
  mut semantics_destroy_requested : Bool
  mut semantics_destroy_program : (() -> Unit)?
}

///|
/// Subsystem: animation clock, active-animation latch, focus and pointer capture.
priv struct AnimFocusState {
  mut now_ms : Double
  mut active_animations : Bool
  mut focused_element : ElementId?
  mut active_pointer_capture : ElementId?
}

///|
/// Subsystem: render counters and layer-cache bookkeeping.
priv struct RenderStats {
  mut rebuild_pass_count : Int
  mut layout_pass_count : Int
  mut paint_pass_count : Int
  mut semantics_recompute_count : Int
  mut draw_command_build_count : Int
  mut last_command_count : Int
  mut cache_epoch : Int
  mut last_damage_region : DamageRegion
  known_layer_cache_keys : Array[CachedLayerState]
  cached_layer_admissions : Array[CachedLayerAdmissionState]
}

///|
fn DirtyTracking::new() -> DirtyTracking {
  {
    needs_redraw: true,
    needs_rebuild: false,
    needs_layout: true,
    needs_paint: true,
    needs_semantics: true,
    needs_platform: true,
    rebuild_wakeup_redraw: false,
    dirty_elements: [],
    dirty_build_elements: [],
    dirty_layout_elements: [],
    dirty_paint_elements: [],
    dirty_semantics_elements: [],
    dirty_platform_elements: [],
  }
}

///|
fn DirtyTracking::clear(self : DirtyTracking) -> Unit {
  self.needs_redraw = false
  self.needs_rebuild = false
  self.needs_layout = false
  self.needs_paint = false
  self.needs_semantics = false
  self.needs_platform = false
  self.rebuild_wakeup_redraw = false
  self.dirty_elements.clear()
  self.dirty_build_elements.clear()
  self.dirty_layout_elements.clear()
  self.dirty_paint_elements.clear()
  self.dirty_semantics_elements.clear()
  self.dirty_platform_elements.clear()
}

///|
fn RenderStats::new() -> RenderStats {
  {
    rebuild_pass_count: 0,
    layout_pass_count: 0,
    paint_pass_count: 0,
    semantics_recompute_count: 0,
    draw_command_build_count: 0,
    last_command_count: 0,
    cache_epoch: 0,
    last_damage_region: DamageRegion::empty(),
    known_layer_cache_keys: [],
    cached_layer_admissions: [],
  }
}

///|
fn AnimFocusState::new() -> AnimFocusState {
  {
    now_ms: 0.0,
    active_animations: false,
    focused_element: None,
    active_pointer_capture: None,
  }
}

///|
fn SemanticsSubsystem::new() -> SemanticsSubsystem {
  {
    semantics_tree: SemanticsTree::empty(),
    committed_semantics: SemanticsSnapshot::empty(),
    semantics_initialized: false,
    semantics_journal: [],
    next_semantics_node_id: 1UL,
    semantic_id_index: Map([]),
    semantics_commit_in_progress: false,
    semantics_action_dispatching: false,
    semantics_destroy_requested: false,
    semantics_destroy_program: None,
  }
}

///|
/// Subsystem migration path:
///   1. Swap `RuntimeState` fields to `mut dirty: DirtyTracking` etc.
///   2. Compiler errors guide ~400 `self.needs_*` → `self.dirty.needs_*` renames.
///   3. Each rename is a `replace_all_preview` → `multi_edit` batch per file.
///   Constructors above produce correct initial values for the subsystem fields.

///|
/// Convenience: clear all dirty state in one call.
fn RuntimeState::clear_all_dirty(self : RuntimeState) -> Unit {
  self.dirty.needs_redraw = false
  self.dirty.needs_rebuild = false
  self.dirty.needs_layout = false
  self.dirty.needs_paint = false
  self.dirty.needs_semantics = false
  self.dirty.needs_platform = false
  self.dirty.rebuild_wakeup_redraw = false
  self.dirty.dirty_elements.clear()
  self.dirty.dirty_build_elements.clear()
  self.dirty.dirty_layout_elements.clear()
  self.dirty.dirty_paint_elements.clear()
  self.dirty.dirty_semantics_elements.clear()
  self.dirty.dirty_platform_elements.clear()
}
