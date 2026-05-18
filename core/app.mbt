///|
pub(all) struct RuntimeState {
  mut root_spec : ViewSpec
  mut element_tree : ElementNode
  mut render_tree : RenderNode
  mut size : Size
  mut needs_redraw : Bool
  mut needs_rebuild : Bool
  mut needs_layout : Bool
  mut needs_paint : Bool
  mut next_element_id : Int
  mut dirty_elements : Array[ElementId]
  mut focused_element : ElementId?
  mut redraw_callback : (() -> Unit)?
  clock : Clock
  mut animations : Array[AnimationController]
}

///|
pub(all) struct BuildContext {
  runtime : RuntimeState
  component_id : ElementId
  subscriptions : Array[StateSubscription]
}

///|
pub(all) struct Component {
  build : (BuildContext) -> ViewSpec
}

///|
priv struct ComponentBuildResult {
  child_spec : ViewSpec
  subscriptions : Array[StateSubscription]
}

///|
pub fn RuntimeState::new_spec(root~ : ViewSpec, size~ : Size) -> RuntimeState {
  let initial = mount_view_spec_with_next(root, 1)
  let state = {
    root_spec: root,
    element_tree: initial.node,
    render_tree: RenderNode::empty(),
    size,
    needs_redraw: true,
    needs_rebuild: false,
    needs_layout: true,
    needs_paint: true,
    next_element_id: initial.next_id,
    dirty_elements: [],
    focused_element: None,
    redraw_callback: None,
    clock: Clock::new(),
    animations: [],
  }
  let mounted = mount_view_spec_for_runtime(root, Some(state), 1)
  state.element_tree = mounted.node
  state.next_element_id = mounted.next_id
  state.mark_dirty(state.element_tree.id)
  state.render_current_tree()
  state
}

///|
pub fn RuntimeState::new_component(
  root~ : Component,
  size~ : Size,
) -> RuntimeState {
  let root_spec = ViewSpec::component(root)
  let mounted = mount_view_spec_for_runtime(root_spec, None, 1)
  let state = {
    root_spec,
    element_tree: mounted.node,
    render_tree: RenderNode::empty(),
    size,
    needs_redraw: true,
    needs_rebuild: false,
    needs_layout: true,
    needs_paint: true,
    next_element_id: mounted.next_id,
    dirty_elements: [],
    focused_element: None,
    redraw_callback: None,
    clock: Clock::new(),
    animations: [],
  }
  let mounted = mount_view_spec_for_runtime(root_spec, Some(state), 1)
  state.element_tree = mounted.node
  state.next_element_id = mounted.next_id
  state.mark_dirty(state.element_tree.id)
  state.render_current_tree()
  state
}

///|
pub fn Component::new(build : (BuildContext) -> ViewSpec) -> Component {
  { build, }
}

///|
pub fn[T] BuildContext::watch(self : BuildContext, state : State[T]) -> T {
  let component_id = self.component_id
  let subscription = state.subscribe(() => {
    self.runtime.request_component_rebuild(component_id)
  })
  self.subscriptions.push(subscription)
  state.get()
}

///|
pub fn[T] BuildContext::binding(
  self : BuildContext,
  state : State[T],
) -> Binding[T] {
  let component_id = self.component_id
  let subscription = state.subscribe(() => {
    self.runtime.request_component_rebuild(component_id)
  })
  self.subscriptions.push(subscription)
  state.binding()
}

///|
pub fn RuntimeState::set_root_spec(
  self : RuntimeState,
  root : ViewSpec,
) -> Unit {
  self.element_tree.cancel_component_tree_subscriptions()
  self.root_spec = root
  self.rebuild()
  self.needs_redraw = true
}

///|
pub fn RuntimeState::mount(self : RuntimeState, root : ViewSpec) -> Unit {
  self.element_tree.cancel_component_tree_subscriptions()
  let mounted = mount_view_spec_for_runtime(root, Some(self), 1)
  self.root_spec = root
  self.element_tree = mounted.node
  self.next_element_id = mounted.next_id
  self.focused_element = None
  self.needs_rebuild = false
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
  self.mark_dirty(mounted.node.id)
  self.layout_pass()
}

///|
pub fn RuntimeState::rebuild(self : RuntimeState) -> Unit {
  let result = reconcile_element_for_runtime(
    self.element_tree,
    self.root_spec,
    Some(self),
    self.next_element_id,
  )
  self.element_tree = result.node
  self.next_element_id = result.next_id
  self.needs_rebuild = false
  self.needs_layout = true
  self.needs_paint = true
  self.mark_dirty(self.element_tree.id)
  self.layout_pass()
}

///|
pub fn RuntimeState::set_redraw_callback(
  self : RuntimeState,
  callback : () -> Unit,
) -> Unit {
  self.redraw_callback = Some(callback)
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
  self.render_current_tree()
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
      self.needs_redraw = true
      self.needs_layout = true
      self.needs_paint = true
      self.element_tree.mark_subtree_layout_dirty()
      self.mark_dirty(self.element_tree.id)
    }
    Redraw(_) => {
      self.needs_redraw = false
      if self.has_active_animations() {
        self.request_redraw()
      }
    }
    Pointer(event) => {
      self.ensure_render_tree()
      if event.phase == PointerPhase::Down {
        let previous_focus = self.focused_element
        self.focused_element = self.element_tree.find_text_field_at(
          event.position,
          self.render_tree,
        )
        if previous_focus != self.focused_element {
          self.mark_dirty(self.element_tree.id)
        }
      }
      let result = self.element_tree.dispatch_pointer(event, self.render_tree)
      self.needs_redraw = self.needs_redraw || result.changed
      self.needs_rebuild = self.needs_rebuild || result.activated
      self.needs_paint = self.needs_paint || result.changed
      if result.changed || result.activated {
        self.mark_dirty(self.element_tree.id)
      }
      if result.activated {
        self.request_activation_rebuild()
      }
      self.rebuild_if_possible()
    }
    Keyboard(event) => {
      let shortcut = self.element_tree.dispatch_keyboard_shortcut(event)
      if shortcut.changed || shortcut.activated {
        self.needs_redraw = self.needs_redraw || shortcut.changed
        self.needs_rebuild = self.needs_rebuild || shortcut.activated
        self.needs_paint = self.needs_paint || shortcut.changed
        self.mark_dirty(self.element_tree.id)
        if shortcut.activated {
          self.request_activation_rebuild()
        }
        self.rebuild_if_possible()
      } else if event.pressed && event.key == "Tab" {
        self.ensure_render_tree()
        let previous_focus = self.focused_element
        self.focused_element = self.element_tree.next_focus(
          current=previous_focus,
          reverse=event.modifiers.shift,
        )
        if previous_focus != self.focused_element {
          self.mark_dirty(self.element_tree.id)
        }
      } else {
        match self.focused_element {
          Some(target) => {
            let result = self.element_tree.dispatch_keyboard(target, event)
            self.needs_redraw = self.needs_redraw || result.changed
            self.needs_rebuild = self.needs_rebuild || result.activated
            self.needs_paint = self.needs_paint || result.changed
            if result.changed || result.activated {
              self.mark_dirty(self.element_tree.id)
            }
            if result.activated {
              self.request_activation_rebuild()
            }
            self.rebuild_if_possible()
          }
          None => ()
        }
      }
    }
    TextInput(event) =>
      match self.focused_element {
        Some(target) => {
          let result = self.element_tree.dispatch_text_input(target, event)
          self.needs_redraw = self.needs_redraw || result.changed
          self.needs_rebuild = self.needs_rebuild || result.activated
          self.needs_paint = self.needs_paint || result.changed
          if result.changed || result.activated {
            self.mark_dirty(self.element_tree.id)
          }
          if result.activated {
            self.request_activation_rebuild()
          }
          self.rebuild_if_possible()
        }
        None => ()
      }
    CloseRequested => ()
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
  self.ensure_render_tree()
  self.render_tree.to_layout_result()
}

///|
pub fn RuntimeState::semantics(self : RuntimeState) -> SemanticsNode {
  self.ensure_render_tree()
  self.element_tree.semantics(self.render_tree, focused=self.focused_element)
}

///|
pub fn RuntimeState::focused_text_input(self : RuntimeState) -> TextInputState {
  self.ensure_render_tree()
  match self.focused_element {
    Some(target) =>
      match self.element_tree.focused_text_input(target, self.render_tree) {
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
  let commands : Array[DrawCommand] = [Clear(Color::white())]
  self.rebuild_if_possible()
  self.ensure_render_tree()
  self.render_tree.collect_draw_commands(commands)
  commands
}

///|
pub fn RuntimeState::rebuild_if_possible(self : RuntimeState) -> Unit {
  if self.needs_rebuild {
    if self.element_tree.has_dirty_build() {
      let result = self.element_tree.rebuild_dirty_components(
        self,
        self.next_element_id,
      )
      self.element_tree = result.node
      self.next_element_id = result.next_id
      self.needs_rebuild = self.element_tree.has_dirty_build()
      self.needs_layout = self.needs_layout ||
        self.element_tree.has_dirty_layout()
      self.needs_paint = self.needs_paint || self.element_tree.has_dirty_paint()
      self.needs_redraw = true
    }
  }
}

///|
pub fn RuntimeState::request_rebuild(self : RuntimeState) -> Unit {
  self.request_component_rebuild(self.element_tree.id)
  self.request_redraw()
}

///|
fn RuntimeState::request_component_rebuild(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  ignore(self.element_tree.mark_build_dirty_by_id(id))
  self.needs_rebuild = true
  self.needs_layout = true
  self.needs_paint = true
  self.mark_dirty(id)
  self.request_redraw()
}

///|
fn RuntimeState::request_activation_rebuild(self : RuntimeState) -> Unit {
  self.needs_rebuild = true
  if !self.element_tree.has_dirty_build() &&
    self.element_tree.mark_root_component_build_dirty() {
    self.needs_layout = true
    self.needs_paint = true
    self.mark_dirty(self.element_tree.id)
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
    self.mark_dirty(self.element_tree.id)
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
fn RuntimeState::render_current_tree(self : RuntimeState) -> Unit {
  self.rebuild_if_possible()
  self.render_tree = self.element_tree.render_focused(
    Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
    focused=self.focused_element,
  )
  self.needs_rebuild = false
  self.needs_layout = false
  self.needs_paint = false
  self.clear_dirty_queue()
}

///|
pub fn RuntimeState::mark_dirty(self : RuntimeState, id : ElementId) -> Unit {
  if !self.dirty_elements.any(existing => existing == id) {
    self.dirty_elements.push(id)
  }
  ignore(self.element_tree.mark_paint_dirty_by_id(id))
  self.needs_paint = true
  self.needs_redraw = true
}

///|
pub fn RuntimeState::dirty_count(self : RuntimeState) -> Int {
  self.dirty_elements.length()
}

///|
pub fn RuntimeState::clear_dirty_queue(self : RuntimeState) -> Unit {
  self.dirty_elements.clear()
}

///|
fn build_component_spec(
  component : Component,
  runtime : RuntimeState,
  component_id : ElementId,
  old_subscriptions : Array[StateSubscription],
) -> ComponentBuildResult {
  for subscription in old_subscriptions {
    subscription.cancel()
  }
  let subscriptions : Array[StateSubscription] = []
  let context = BuildContext::{ runtime, component_id, subscriptions }
  { child_spec: (component.build)(context), subscriptions }
}
