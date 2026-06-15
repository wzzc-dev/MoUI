///|
priv struct RuntimeState {
  mut root_spec : ViewSpec
  mut element_tree : ElementTree
  mut layout_tree : LayoutTree
  mut render_tree : RenderTree
  mut size : Size
  mut needs_redraw : Bool
  mut needs_rebuild : Bool
  mut needs_layout : Bool
  mut needs_paint : Bool
  mut rebuild_pass_count : Int
  mut layout_pass_count : Int
  mut paint_pass_count : Int
  mut draw_command_build_count : Int
  mut cache_epoch : Int
  mut last_damage_region : DamageRegion
  known_layer_cache_keys : Array[CachedLayerState]
  mut next_element_id : Int
  dirty_elements : Array[ElementId]
  dirty_build_elements : Array[ElementId]
  dirty_layout_elements : Array[ElementId]
  dirty_paint_elements : Array[ElementId]
  mut focused_element : ElementId?
  mut active_pointer_capture : ElementId?
  mut environment : Environment
  mut text_system : TextSystem
  mut redraw_callback : (() -> Unit)?
  mut action_commands : ActionCommandMap
  clock : Clock
  saveable_state : SaveableStateStore
}

///|
fn[Msg] RuntimeState::new_view(
  root~ : @core.View[Msg],
  size~ : Size,
  environment? : Environment = Environment::default(),
  on_message? : ((Msg) -> Unit)? = None,
) -> RuntimeState {
  let emit = match on_message {
    Some(handler) => handler
    None => _message => ()
  }
  RuntimeState::new_spec(
    root=lower_view_for_runtime(root, emit),
    size~,
    environment~,
  )
}

///|
fn RuntimeState::new_spec(
  root~ : ViewSpec,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> RuntimeState {
  let initial = mount_view_spec_with_next(root, 1)
  let state = {
    root_spec: root,
    element_tree: ElementTree::new(initial.node),
    layout_tree: LayoutTree::empty(),
    render_tree: RenderTree::empty(),
    size,
    needs_redraw: true,
    needs_rebuild: false,
    needs_layout: true,
    needs_paint: true,
    rebuild_pass_count: 0,
    layout_pass_count: 0,
    paint_pass_count: 0,
    draw_command_build_count: 0,
    cache_epoch: 0,
    last_damage_region: DamageRegion::full("initial frame"),
    known_layer_cache_keys: [],
    next_element_id: initial.next_id,
    dirty_elements: [],
    dirty_build_elements: [],
    dirty_layout_elements: [],
    dirty_paint_elements: [],
    focused_element: None,
    active_pointer_capture: None,
    environment,
    text_system: TextSystem::fallback(),
    redraw_callback: None,
    action_commands: ActionCommandMap::new(),
    clock: Clock::new(),
    saveable_state: SaveableStateStore::new(),
  }
  let mounted = mount_view_spec_for_runtime(root, Some(state), 1)
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
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
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
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
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
    self.needs_rebuild = self.element_tree.root.mark_component_tree_build_dirty()
    self.needs_layout = true
    self.needs_paint = true
    self.needs_redraw = true
    self.element_tree.root.mark_subtree_layout_dirty()
    self.mark_build_dirty(self.element_tree.id())
  }
}

///|
fn RuntimeState::destroy(self : RuntimeState) -> Unit {
  self.element_tree.root.cancel_component_tree_subscriptions(
    reason=ComponentEffectCancelReason::EffectRuntimeDestroyed,
  )
  self.element_tree = ElementTree::empty()
  self.layout_tree = LayoutTree::empty()
  self.render_tree = RenderTree::empty()
  self.root_spec = ViewSpec::EmptySpec
  self.next_element_id = 1
  self.dirty_elements.clear()
  self.dirty_build_elements.clear()
  self.dirty_layout_elements.clear()
  self.dirty_paint_elements.clear()
  self.focused_element = None
  self.active_pointer_capture = None
  self.needs_rebuild = false
  self.needs_layout = false
  self.needs_paint = false
  self.needs_redraw = false
  self.rebuild_pass_count = 0
  self.layout_pass_count = 0
  self.paint_pass_count = 0
  self.draw_command_build_count = 0
  self.cache_epoch = 0
  self.last_damage_region = DamageRegion::empty()
  self.known_layer_cache_keys.clear()
}

///|
fn RuntimeState::rebuild(self : RuntimeState) -> Unit {
  self.rebuild_pass_count = self.rebuild_pass_count + 1
  let result = reconcile_element_for_runtime(
    self.element_tree.root,
    self.root_spec,
    Some(self),
    self.next_element_id,
  )
  self.element_tree = ElementTree::new(result.node)
  self.next_element_id = result.next_id
  self.clear_stale_pointer_capture()
  self.needs_rebuild = false
  self.needs_layout = self.element_tree.root.has_dirty_layout()
  self.needs_paint = self.element_tree.root.has_dirty_paint()
  if self.needs_layout || self.needs_paint {
    self.mark_current_dirty_elements()
  }
  if self.needs_layout {
    self.layout_pass()
  }
}

///|
fn RuntimeState::set_redraw_callback(
  self : RuntimeState,
  callback : () -> Unit,
) -> Unit {
  self.redraw_callback = Some(callback)
}

///|
fn RuntimeState::layout_pass(self : RuntimeState) -> Unit {
  self.ensure_layout_tree()
}

///|
fn RuntimeState::paint_pass(self : RuntimeState) -> Array[DrawCommand] {
  self.build_draw_commands()
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
fn RuntimeState::cached_semantics(self : RuntimeState) -> SemanticsNode {
  self.element_tree.root.semantics(
    self.render_tree.root,
    focused=self.focused_element,
  )
}

///|
fn RuntimeState::inspector_rebuild_reason(self : RuntimeState) -> String {
  if self.needs_rebuild {
    "rebuild requested"
  } else if self.needs_layout {
    "layout requested"
  } else if self.needs_paint {
    "paint requested"
  } else if self.needs_redraw {
    "redraw requested"
  } else {
    "clean"
  }
}

///|
fn RuntimeState::inspector_dirty_reasons(self : RuntimeState) -> Array[String] {
  let reasons : Array[String] = []
  if self.needs_rebuild {
    reasons.push("rebuild")
  }
  if self.needs_layout {
    reasons.push("layout")
  }
  if self.needs_paint {
    reasons.push("paint")
  }
  if self.needs_redraw {
    reasons.push("redraw")
  }
  if self.dirty_elements.length() > 0 {
    reasons.push("dirty elements: \{self.dirty_elements.length()}")
  }
  reasons
}

///|
fn RuntimeState::semantics(self : RuntimeState) -> SemanticsNode {
  self.ensure_render_tree()
  self.element_tree.root.semantics(
    self.render_tree.root,
    focused=self.focused_element,
  )
}

///|
fn RuntimeState::focused_text_input(self : RuntimeState) -> TextInputState {
  self.ensure_render_tree()
  match self.focused_element {
    Some(target) =>
      match
        self.element_tree.root.focused_text_input(
          target,
          self.render_tree.root,
          text_system=self.text_system,
        ) {
        Some(state) => state
        None => TextInputState::none()
      }
    None => TextInputState::none()
  }
}

///|
fn RuntimeState::build_draw_commands(self : RuntimeState) -> Array[DrawCommand] {
  self.draw_command_build_count = self.draw_command_build_count + 1
  let commands : Array[DrawCommand] = [Clear(Color::white())]
  self.rebuild_if_possible()
  self.ensure_render_tree()
  self.render_tree.root.collect_draw_commands(commands)
  commands
}

///|
fn RuntimeState::build_draw_frame(self : RuntimeState) -> DrawFrame {
  self.draw_command_build_count = self.draw_command_build_count + 1
  let commands : Array[DrawCommand] = [Clear(Color::white())]
  self.rebuild_if_possible()
  self.ensure_render_tree()
  self.render_tree.root.collect_frame_commands(
    commands,
    self.known_layer_cache_keys,
  )
  let platform_views : Array[PlatformViewPlacement] = []
  self.render_tree.root.collect_platform_views(platform_views)
  self.record_cached_layer_updates(commands)
  DrawFrame::new(
    commands~,
    platform_views~,
    damage=self.last_damage_region,
    clear_color=Color::white(),
    cache_epoch=self.cache_epoch,
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
  if self.needs_rebuild {
    if self.element_tree.root.has_dirty_build() {
      self.rebuild_pass_count = self.rebuild_pass_count + 1
      let result = self.element_tree.root.rebuild_dirty_components(
        self,
        self.next_element_id,
      )
      self.element_tree = ElementTree::new(result.node)
      self.next_element_id = result.next_id
      self.clear_stale_pointer_capture()
      self.needs_rebuild = self.element_tree.root.has_dirty_build()
      self.needs_layout = self.needs_layout ||
        self.element_tree.root.has_dirty_layout()
      self.needs_paint = self.needs_paint ||
        self.element_tree.root.has_dirty_paint()
      self.needs_redraw = true
    }
  }
}

///|
fn RuntimeState::request_component_rebuild(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  ignore(self.element_tree.root.mark_build_dirty_by_id(id))
  self.needs_rebuild = true
  self.needs_layout = true
  self.needs_paint = true
  self.mark_build_dirty(id)
  self.request_redraw()
}

///|
fn RuntimeState::request_activation_rebuild(self : RuntimeState) -> Unit {
  self.needs_rebuild = true
  if !self.element_tree.root.has_dirty_build() &&
    self.element_tree.root.mark_root_component_build_dirty() {
    self.needs_layout = true
    self.needs_paint = true
    self.mark_build_dirty(self.element_tree.id())
  }
  self.request_redraw()
}
