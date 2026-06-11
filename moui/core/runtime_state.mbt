///|
struct RuntimeState {
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
  animations : Array[AnimationController]
  saveable_state : SaveableStateStore
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
    animations: [],
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
fn RuntimeState::new_component(
  root~ : Component,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> RuntimeState {
  let root_spec = ViewSpec::component(root)
  let mounted = mount_view_spec_for_runtime(root_spec, None, 1)
  let state = {
    root_spec,
    element_tree: ElementTree::new(mounted.node),
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
    next_element_id: mounted.next_id,
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
    animations: [],
    saveable_state: SaveableStateStore::new(),
  }
  let mounted = mount_view_spec_for_runtime(root_spec, Some(state), 1)
  state.element_tree = ElementTree::new(mounted.node)
  state.next_element_id = mounted.next_id
  state.mark_dirty(state.element_tree.id())
  state.render_current_tree()
  state
}

///|
pub fn RuntimeState::environment(self : RuntimeState) -> Environment {
  self.environment
}

///|
pub fn RuntimeState::text_system(self : RuntimeState) -> TextSystem {
  self.text_system
}

///|
pub fn RuntimeState::set_text_system(
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
pub fn RuntimeState::register_font_data(
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
pub fn RuntimeState::set_environment(
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
pub fn RuntimeState::destroy(self : RuntimeState) -> Unit {
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
pub fn RuntimeState::rebuild(self : RuntimeState) -> Unit {
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
pub fn RuntimeState::set_redraw_callback(
  self : RuntimeState,
  callback : () -> Unit,
) -> Unit {
  self.redraw_callback = Some(callback)
}

///|
pub fn RuntimeState::set_action_commands(
  self : RuntimeState,
  commands : ActionCommandMap,
) -> Unit {
  self.action_commands = commands
}

///|
pub fn RuntimeState::action_commands(
  self : RuntimeState,
) -> Array[ActionCommand] {
  self.action_commands.commands()
}

///|
pub fn RuntimeState::dispatch_command(
  self : RuntimeState,
  intent : CommandIntent,
) -> Bool {
  let text_result = self.dispatch_focused_text_command(intent)
  if text_result.handled {
    text_result.changed
  } else if self.action_commands.dispatch_intent(intent) {
    self.request_activation_rebuild()
    true
  } else {
    false
  }
}

///|
pub fn RuntimeState::dispatch_action_command(
  self : RuntimeState,
  command : ActionCommand,
) -> Bool {
  if self.action_commands.dispatch_command(command) {
    self.request_activation_rebuild()
    true
  } else {
    false
  }
}

///|
pub fn RuntimeState::dispatch_focused_text_command(
  self : RuntimeState,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  match self.focused_element {
    Some(target) => {
      let result = self.element_tree.root.dispatch_text_command(
        target,
        intent,
        paste_text~,
      )
      if result.changed {
        self.needs_redraw = true
        self.needs_rebuild = true
        self.needs_paint = true
        self.mark_build_dirty(self.element_tree.id())
        self.rebuild_if_possible()
      }
      result
    }
    None => TextCommandResult::ignored()
  }
}

///|
pub fn RuntimeState::add_animation(
  self : RuntimeState,
  controller : AnimationController,
) -> Unit {
  self.animations.push(controller)
  if controller.is_active() {
    self.request_redraw()
  }
}

///|
pub fn RuntimeState::animation_count(self : RuntimeState) -> Int {
  self.animations.length()
}

///|
pub fn RuntimeState::layout_pass(self : RuntimeState) -> Unit {
  self.ensure_layout_tree()
}

///|
pub fn RuntimeState::paint_pass(self : RuntimeState) -> Array[DrawCommand] {
  self.build_draw_commands()
}

///|
pub fn RuntimeState::dispatch_event(
  self : RuntimeState,
  event : AppEvent,
) -> Unit {
  match event {
    FrameTick(frame) => self.tick_animations(frame)
    Resize(size) => {
      self.size = size
      self.needs_rebuild = self.element_tree.root.mark_component_tree_build_dirty()
      self.needs_redraw = true
      self.needs_layout = true
      self.needs_paint = true
      self.element_tree.root.mark_subtree_layout_dirty()
      self.mark_build_dirty(self.element_tree.id())
    }
    Redraw(_) => {
      self.needs_redraw = false
      if self.has_active_animations() {
        self.request_redraw()
      }
    }
    Pointer(event) => {
      if event.phase == PointerPhase::Down {
        let previous_focus = self.focused_element
        let candidate_focus = self.element_tree.root.find_focusable_at(
          event.position,
          self.render_tree.root,
        )
        self.focused_element = self.element_tree.root.constrained_focus_target(
          candidate_focus,
          current=previous_focus,
        )
        if previous_focus != self.focused_element {
          self.mark_dirty(self.element_tree.id())
        }
      }
      let result = match self.active_pointer_capture {
        Some(target) =>
          if event.phase == PointerPhase::Down {
            self.element_tree.root.dispatch_pointer(
              event,
              self.render_tree.root,
              text_system=self.text_system,
              capture_lookup=false,
            )
          } else {
            match
              self.element_tree.root.dispatch_pointer_to_target(
                target,
                event,
                self.render_tree.root,
                text_system=self.text_system,
              ) {
              Some(result) => result
              None => {
                self.active_pointer_capture = None
                self.element_tree.root.dispatch_pointer(
                  event,
                  self.render_tree.root,
                  text_system=self.text_system,
                  capture_lookup=false,
                )
              }
            }
          }
        None =>
          self.element_tree.root.dispatch_pointer(
            event,
            self.render_tree.root,
            text_system=self.text_system,
            capture_lookup=false,
          )
      }
      if event.phase == PointerPhase::Down {
        self.active_pointer_capture = self.element_tree.root.active_pointer_capture_id(
          PointerPhase::Move,
        )
      } else if event.phase == PointerPhase::Up ||
        event.phase == PointerPhase::Cancel {
        self.active_pointer_capture = None
      }
      self.needs_redraw = self.needs_redraw || result.changed
      self.needs_rebuild = self.needs_rebuild || result.activated
      self.needs_paint = self.needs_paint || result.changed
      if result.changed || result.activated {
        self.mark_current_dirty_elements()
      }
      if result.activated {
        self.request_activation_rebuild()
      }
    }
    Keyboard(event) => {
      let shortcut = self.element_tree.root.dispatch_keyboard_shortcut(event)
      if shortcut.changed || shortcut.activated {
        self.needs_redraw = self.needs_redraw || shortcut.changed
        self.needs_rebuild = self.needs_rebuild || shortcut.activated
        self.needs_paint = self.needs_paint || shortcut.changed
        self.mark_current_dirty_elements()
        if shortcut.activated {
          self.request_activation_rebuild()
        }
      } else if self.action_commands.dispatch_shortcut(event) is Some(_) {
        self.request_activation_rebuild()
      } else if event.pressed && event.key == "Tab" {
        match self.focused_element {
          Some(target) => {
            let constrained_target = self.element_tree.root.constrained_focus_target(
              Some(target),
              current=Some(target),
            )
            if constrained_target != Some(target) {
              ignore(self.move_focus(reverse=event.modifiers.shift))
            } else if self.element_tree.root.accepts_tab_input(target) {
              let result = self.element_tree.root.dispatch_keyboard(
                target, event,
              )
              self.needs_redraw = self.needs_redraw || result.changed
              self.needs_rebuild = self.needs_rebuild || result.activated
              self.needs_paint = self.needs_paint || result.changed
              if result.changed || result.activated {
                self.mark_current_dirty_elements()
              }
              if result.activated {
                self.request_activation_rebuild()
              }
              if result.changed {
                self.rebuild_if_possible()
              }
            } else {
              ignore(self.move_focus(reverse=event.modifiers.shift))
            }
          }
          None => ignore(self.move_focus(reverse=event.modifiers.shift))
        }
      } else {
        match self.focused_element {
          Some(target) => {
            let is_text_input = self.element_tree.root.is_text_input_target(
              target,
            )
            let result = self.element_tree.root.dispatch_keyboard(target, event)
            self.needs_redraw = self.needs_redraw || result.changed
            self.needs_rebuild = self.needs_rebuild || result.activated
            self.needs_paint = self.needs_paint || result.changed
            if result.changed || result.activated {
              self.mark_current_dirty_elements()
            }
            if result.activated {
              self.request_activation_rebuild()
            }
            if is_text_input && result.changed {
              self.rebuild_if_possible()
            }
          }
          None => ()
        }
      }
    }
    TextInput(event) =>
      match self.focused_element {
        Some(target) => {
          let result = self.element_tree.root.dispatch_text_input(target, event)
          self.needs_redraw = self.needs_redraw || result.changed
          self.needs_rebuild = self.needs_rebuild || result.activated
          self.needs_paint = self.needs_paint || result.changed
          if result.changed || result.activated {
            self.mark_current_dirty_elements()
          }
          if result.activated {
            self.request_activation_rebuild()
          }
          if result.changed {
            self.rebuild_if_possible()
          }
        }
        None => ()
      }
    DragDrop(event) => {
      let result = self.element_tree.root.dispatch_drag_drop(
        event,
        self.render_tree.root,
      )
      self.needs_redraw = self.needs_redraw || result.changed
      self.needs_rebuild = self.needs_rebuild || result.activated
      self.needs_paint = self.needs_paint || result.changed
      if result.changed || result.activated {
        self.mark_current_dirty_elements()
      }
      if result.activated {
        self.request_activation_rebuild()
      }
    }
    AppEvent::WebView(id, event) =>
      if self.element_tree.root.dispatch_web_view_event(id, event) {
        self.needs_rebuild = true
        self.needs_redraw = true
        self.needs_paint = true
        self.mark_current_dirty_elements()
        self.request_activation_rebuild()
      }
    CloseRequested => ()
  }
}

///|
fn RuntimeState::move_focus(
  self : RuntimeState,
  reverse? : Bool = false,
) -> Bool {
  self.ensure_render_tree()
  let previous_focus = self.focused_element
  self.focused_element = self.element_tree.root.next_focus(
    current=previous_focus,
    reverse~,
  )
  if previous_focus != self.focused_element {
    self.mark_dirty(self.element_tree.id())
    true
  } else {
    false
  }
}

///|
fn RuntimeState::focus_key(self : RuntimeState, key : String) -> Bool {
  self.ensure_render_tree()
  match self.element_tree.root.focusable_key_target(key) {
    Some(target) => {
      let previous_focus = self.focused_element
      let constrained = self.element_tree.root.constrained_focus_target(
        Some(target),
        current=previous_focus,
      )
      if constrained == Some(target) {
        self.focused_element = Some(target)
        if previous_focus != self.focused_element {
          self.mark_dirty(self.element_tree.id())
        }
        true
      } else {
        false
      }
    }
    None => false
  }
}

///|
pub fn RuntimeState::advance_time(
  self : RuntimeState,
  time_ms : Double,
) -> Unit {
  self.dispatch_event(FrameTick(self.clock.frame(time_ms)))
}

///|
pub fn RuntimeState::layout(self : RuntimeState) -> LayoutResult {
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
pub fn RuntimeState::semantics(self : RuntimeState) -> SemanticsNode {
  self.ensure_render_tree()
  self.element_tree.root.semantics(
    self.render_tree.root,
    focused=self.focused_element,
  )
}

///|
pub fn RuntimeState::focused_text_input(self : RuntimeState) -> TextInputState {
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
pub fn RuntimeState::build_draw_commands(
  self : RuntimeState,
) -> Array[DrawCommand] {
  self.draw_command_build_count = self.draw_command_build_count + 1
  let commands : Array[DrawCommand] = [Clear(Color::white())]
  self.rebuild_if_possible()
  self.ensure_render_tree()
  self.render_tree.root.collect_draw_commands(commands)
  commands
}

///|
pub fn RuntimeState::build_draw_frame(self : RuntimeState) -> DrawFrame {
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
pub fn RuntimeState::rebuild_if_possible(self : RuntimeState) -> Unit {
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
pub fn RuntimeState::request_rebuild(self : RuntimeState) -> Unit {
  self.request_component_rebuild(self.element_tree.id())
  self.request_redraw()
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

///|
fn RuntimeState::tick_animations(self : RuntimeState, frame : Frame) -> Unit {
  let mut active = false
  let mut changed = false
  for controller in self.animations {
    changed = controller.tick(frame) || changed
    active = controller.is_active() || active
  }
  if changed {
    self.needs_paint = true
    self.mark_dirty(self.element_tree.id())
  }
  if active {
    self.request_redraw()
  }
}

///|
fn RuntimeState::has_active_animations(self : RuntimeState) -> Bool {
  self.animations.any(controller => controller.is_active())
}

///|
fn RuntimeState::clear_stale_pointer_capture(self : RuntimeState) -> Unit {
  match self.active_pointer_capture {
    Some(target) =>
      if !self.element_tree.root.contains_element_id(target) {
        self.active_pointer_capture = None
      }
    None => ()
  }
}

///|
fn RuntimeState::request_redraw(self : RuntimeState) -> Unit {
  self.needs_redraw = true
  match self.redraw_callback {
    Some(callback) => callback()
    None => ()
  }
}

///|
fn RuntimeState::ensure_render_tree(self : RuntimeState) -> Unit {
  if self.needs_rebuild || self.needs_layout || self.needs_paint {
    self.render_current_tree()
  }
}

///|
fn RuntimeState::ensure_layout_tree(self : RuntimeState) -> Unit {
  if self.needs_rebuild || self.needs_layout {
    self.layout_current_tree()
  }
}

///|
fn RuntimeState::layout_current_tree(self : RuntimeState) -> Unit {
  self.rebuild_if_possible()
  self.layout_pass_count = self.layout_pass_count + 1
  self.layout_tree = {
    root: self.element_tree.root.place_with_text_system(
      Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
      text_system=self.text_system,
      layout_direction=self.environment.layout_direction,
    ),
  }
  self.needs_rebuild = false
  self.needs_layout = false
}

///|
fn RuntimeState::render_current_tree(self : RuntimeState) -> Unit {
  let previous_render = self.render_tree
  let dirty_ids = self.dirty_elements.copy()
  let force_full_reason = if self.needs_rebuild {
    Some("rebuild requested")
  } else if previous_render.root.element_id.value == 0 {
    Some("initial frame")
  } else {
    None
  }
  self.ensure_layout_tree()
  self.paint_pass_count = self.paint_pass_count + 1
  self.render_tree = {
    root: self.element_tree.root.render_focused_with_text_system(
      self.layout_tree.root,
      focused=self.focused_element,
      environment=self.environment,
      text_system=self.text_system,
    ),
  }
  self.last_damage_region = self.compute_damage_region(
    previous_render,
    self.render_tree,
    dirty_ids,
    force_full_reason~,
  )
  self.needs_rebuild = false
  self.needs_layout = false
  self.needs_paint = false
  self.clear_dirty_queue()
}

///|
fn RuntimeState::compute_damage_region(
  self : RuntimeState,
  previous : RenderTree,
  current : RenderTree,
  dirty_ids : Array[ElementId],
  force_full_reason~ : String?,
) -> DamageRegion {
  match force_full_reason {
    Some(reason) => DamageRegion::full(reason)
    None => {
      if dirty_ids.is_empty() {
        return DamageRegion::full("dirty bounds unavailable")
      }
      let surface = Rect::new(
        x=0.0,
        y=0.0,
        width=self.size.width,
        height=self.size.height,
      )
      let rects : Array[Rect] = []
      let mut missing_bounds = false
      for id in dirty_ids {
        if !previous.root.has_dirty_descendant(id, dirty_ids) &&
          !current.root.has_dirty_descendant(id, dirty_ids) {
          let mut found_bounds = false
          match previous.root.find_damage_bounds(id) {
            Some(bounds) => {
              rects.push(bounds)
              found_bounds = true
            }
            None => ()
          }
          match current.root.find_damage_bounds(id) {
            Some(bounds) => {
              rects.push(bounds)
              found_bounds = true
            }
            None => ()
          }
          if !found_bounds {
            missing_bounds = true
          }
        }
      }
      if missing_bounds || rects.is_empty() {
        DamageRegion::full("dirty bounds unavailable")
      } else {
        DamageRegion::from_rects(rects, surface)
      }
    }
  }
}

///|
fn RuntimeState::record_cached_layer_updates(
  self : RuntimeState,
  commands : Array[DrawCommand],
) -> Unit {
  let mut updated = false
  for command in commands {
    match command {
      BeginCachedLayer(spec) =>
        if self.record_cached_layer_update(spec) {
          updated = true
        }
      _ => ()
    }
  }
  if updated {
    self.cache_epoch = self.cache_epoch + 1
  }
}

///|
fn RuntimeState::record_cached_layer_update(
  self : RuntimeState,
  spec : CachedLayerSpec,
) -> Bool {
  let retained : Array[CachedLayerState] = []
  let mut found = false
  let mut changed = false
  for existing in self.known_layer_cache_keys {
    if existing.key == spec.key {
      found = true
      if existing.content_revision != spec.content_revision {
        changed = true
      }
      retained.push({ key: spec.key, content_revision: spec.content_revision })
    } else {
      retained.push(existing)
    }
  }
  if !found {
    retained.push({ key: spec.key, content_revision: spec.content_revision })
    changed = true
  }
  if changed {
    self.known_layer_cache_keys.clear()
    self.known_layer_cache_keys.append(retained)
  }
  changed
}

///|
fn RuntimeState::invalidate_cached_layer_key(
  self : RuntimeState,
  key : String,
) -> Unit {
  let retained : Array[CachedLayerState] = []
  for existing in self.known_layer_cache_keys {
    if existing.key != key {
      retained.push(existing)
    }
  }
  if retained.length() != self.known_layer_cache_keys.length() {
    self.known_layer_cache_keys.clear()
    self.known_layer_cache_keys.append(retained)
    self.cache_epoch = self.cache_epoch + 1
    self.request_redraw()
  }
}

///|
fn push_unique_element_id(queue : Array[ElementId], id : ElementId) -> Unit {
  if !queue.any(existing => existing == id) {
    queue.push(id)
  }
}

///|
fn RuntimeState::queue_dirty_element(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  push_unique_element_id(self.dirty_elements, id)
}

///|
fn RuntimeState::queue_build_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_dirty_element(id)
  push_unique_element_id(self.dirty_build_elements, id)
}

///|
fn RuntimeState::queue_layout_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  self.queue_dirty_element(id)
  push_unique_element_id(self.dirty_layout_elements, id)
}

///|
fn RuntimeState::queue_paint_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_dirty_element(id)
  push_unique_element_id(self.dirty_paint_elements, id)
}

///|
fn RuntimeState::mark_build_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_build_dirty(id)
  self.queue_layout_dirty(id)
  self.queue_paint_dirty(id)
  self.needs_rebuild = true
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
}

///|
fn RuntimeState::mark_layout_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_layout_dirty(id)
  self.queue_paint_dirty(id)
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
}

///|
pub fn RuntimeState::mark_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_paint_dirty(id)
  ignore(self.element_tree.root.mark_paint_dirty_by_id(id))
  self.needs_paint = true
  self.needs_redraw = true
}

///|
fn RuntimeState::mark_current_dirty_elements(self : RuntimeState) -> Unit {
  let ids : Array[ElementId] = []
  let build_ids : Array[ElementId] = []
  let layout_ids : Array[ElementId] = []
  let paint_ids : Array[ElementId] = []
  self.element_tree.root.collect_dirty_element_ids_by_kind(
    ids, build_ids, layout_ids, paint_ids,
  )
  if ids.is_empty() {
    self.mark_dirty(self.element_tree.id())
  } else {
    for id in ids {
      self.queue_dirty_element(id)
    }
    if !build_ids.is_empty() {
      for id in build_ids {
        push_unique_element_id(self.dirty_build_elements, id)
      }
      self.needs_rebuild = true
    }
    if !layout_ids.is_empty() {
      for id in layout_ids {
        push_unique_element_id(self.dirty_layout_elements, id)
      }
      self.needs_layout = true
    }
    for id in paint_ids {
      push_unique_element_id(self.dirty_paint_elements, id)
    }
    self.needs_paint = true
    self.needs_redraw = true
  }
}

///|
pub fn RuntimeState::dirty_count(self : RuntimeState) -> Int {
  self.dirty_elements.length()
}

///|
pub fn RuntimeState::dirty_element_ids(self : RuntimeState) -> Array[ElementId] {
  self.dirty_elements.copy()
}

///|
pub fn RuntimeState::clear_dirty_queue(self : RuntimeState) -> Unit {
  self.dirty_elements.clear()
  self.dirty_build_elements.clear()
  self.dirty_layout_elements.clear()
  self.dirty_paint_elements.clear()
}
