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
  mut component_root : Component?
  mut subscriptions : Array[StateSubscription]
  mut redraw_callback : (() -> Unit)?
  clock : Clock
  mut animations : Array[AnimationController]
}

///|
pub(all) struct BuildContext {
  runtime : RuntimeState
}

///|
pub(all) struct Component {
  build : (BuildContext) -> ViewSpec
}

///|
pub fn RuntimeState::new_spec(root~ : ViewSpec, size~ : Size) -> RuntimeState {
  let mounted = mount_view_spec_with_next(root, 1)
  let render_tree = mounted.node.render(
    Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
  )
  {
    root_spec: root,
    element_tree: mounted.node,
    render_tree,
    size,
    needs_redraw: true,
    needs_rebuild: false,
    needs_layout: false,
    needs_paint: false,
    next_element_id: mounted.next_id,
    dirty_elements: [],
    focused_element: None,
    component_root: None,
    subscriptions: [],
    redraw_callback: None,
    clock: Clock::new(),
    animations: [],
  }
}

///|
pub fn RuntimeState::new_component(
  root~ : Component,
  size~ : Size,
) -> RuntimeState {
  let initial_spec = EmptySpec
  let mounted = mount_view_spec_with_next(initial_spec, 1)
  let render_tree = mounted.node.render(
    Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
  )
  let state = {
    root_spec: initial_spec,
    element_tree: mounted.node,
    render_tree,
    size,
    needs_redraw: true,
    needs_rebuild: true,
    needs_layout: false,
    needs_paint: false,
    next_element_id: mounted.next_id,
    dirty_elements: [],
    focused_element: None,
    component_root: Some(root),
    subscriptions: [],
    redraw_callback: None,
    clock: Clock::new(),
    animations: [],
  }
  state.rebuild_if_possible()
  state
}

///|
pub fn Component::new(build : (BuildContext) -> ViewSpec) -> Component {
  { build, }
}

///|
pub fn[T] BuildContext::watch(self : BuildContext, state : State[T]) -> T {
  let subscription = state.subscribe(() => self.runtime.request_rebuild())
  self.runtime.subscriptions.push(subscription)
  state.get()
}

///|
pub fn[T] BuildContext::binding(
  self : BuildContext,
  state : State[T],
) -> Binding[T] {
  let subscription = state.subscribe(() => self.runtime.request_rebuild())
  self.runtime.subscriptions.push(subscription)
  state.binding()
}

///|
pub fn RuntimeState::set_root_spec(
  self : RuntimeState,
  root : ViewSpec,
) -> Unit {
  self.cancel_subscriptions()
  self.component_root = None
  self.root_spec = root
  self.rebuild()
  self.needs_redraw = true
}

///|
pub fn RuntimeState::mount(self : RuntimeState, root : ViewSpec) -> Unit {
  self.cancel_subscriptions()
  self.component_root = None
  let mounted = mount_view_spec_with_next(root, 1)
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
  let result = reconcile_element_with_next(
    self.element_tree,
    self.root_spec,
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
      self.rebuild_if_possible()
    }
    Keyboard(event) =>
      if event.pressed && event.key == "Tab" {
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
            self.rebuild_if_possible()
          }
          None => ()
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
          self.rebuild_if_possible()
        }
        None => ()
      }
    CloseRequested => ()
  }
}

///|
pub fn RuntimeState::advance_time(self : RuntimeState, time_ms : Double) -> Unit {
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
    match self.component_root {
      Some(component) => {
        self.cancel_subscriptions()
        let context = BuildContext::{ runtime: self }
        self.root_spec = (component.build)(context)
        self.rebuild()
        self.needs_redraw = true
      }
      None => ()
    }
  }
}

///|
pub fn RuntimeState::request_rebuild(self : RuntimeState) -> Unit {
  self.needs_rebuild = true
  self.needs_layout = true
  self.needs_paint = true
  self.mark_dirty(self.element_tree.id)
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
fn RuntimeState::cancel_subscriptions(self : RuntimeState) -> Unit {
  for subscription in self.subscriptions {
    subscription.cancel()
  }
  self.subscriptions.clear()
}

///|
fn RuntimeState::ensure_render_tree(self : RuntimeState) -> Unit {
  if self.needs_layout || self.needs_paint {
    self.render_current_tree()
  }
}

///|
fn RuntimeState::render_current_tree(self : RuntimeState) -> Unit {
  self.render_tree = self.element_tree.render_focused(
    Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
    focused=self.focused_element,
  )
  self.needs_layout = false
  self.needs_paint = false
  self.clear_dirty_queue()
}

///|
pub fn RuntimeState::mark_dirty(self : RuntimeState, id : ElementId) -> Unit {
  if !self.dirty_elements.any(existing => existing == id) {
    self.dirty_elements.push(id)
  }
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
