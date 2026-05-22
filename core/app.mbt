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
  mut environment : Environment
  mut text_measurer : TextMeasurer
  mut redraw_callback : (() -> Unit)?
  mut action_commands : ActionCommandMap
  clock : Clock
  mut animations : Array[AnimationController]
  mut saveable_state : SaveableStateStore
}

///|
pub(all) struct BuildContext {
  runtime : RuntimeState
  component_id : ElementId
  subscriptions : Array[StateSubscription]
  effects : Array[ComponentEffect]
  old_effects : Array[ComponentEffect]
  environment : Environment
}

///|
pub(all) struct Component {
  build : (BuildContext) -> ViewSpec
}

///|
pub(all) struct ComponentEffect {
  key : String
  cleanup : (() -> Unit)?
  cleanup_with_reason : ((ComponentEffectCancelReason) -> Unit)?
  mut status : ComponentEffectStatus
  mut cancel_reason : ComponentEffectCancelReason?
  mut reused : Bool
}

///|
pub(all) enum ComponentEffectStatus {
  EffectActive
  EffectCancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ComponentEffectCancelReason {
  EffectKeyChanged
  EffectUnmounted
  EffectRuntimeDestroyed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SaveableCodec[T] {
  encode : (T) -> String
  decode : (String) -> T?
}

///|
pub(all) struct SaveableStateStore {
  mut strings : Array[SaveableStringEntry]
}

///|
pub(all) struct SaveableStringEntry {
  key : String
  mut value : String
} derive(Eq, Debug, ToJson)

///|
priv struct ComponentBuildResult {
  child_spec : ViewSpec
  subscriptions : Array[StateSubscription]
  effects : Array[ComponentEffect]
}

///|
pub fn RuntimeState::new_spec(
  root~ : ViewSpec,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> RuntimeState {
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
    environment,
    text_measurer: TextMeasurer::default(),
    redraw_callback: None,
    action_commands: ActionCommandMap::new(),
    clock: Clock::new(),
    animations: [],
    saveable_state: SaveableStateStore::new(),
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
  environment? : Environment = Environment::default(),
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
    environment,
    text_measurer: TextMeasurer::default(),
    redraw_callback: None,
    action_commands: ActionCommandMap::new(),
    clock: Clock::new(),
    animations: [],
    saveable_state: SaveableStateStore::new(),
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
pub fn ComponentEffect::new(
  key~ : String,
  cleanup? : (() -> Unit)? = None,
  cleanup_with_reason? : ((ComponentEffectCancelReason) -> Unit)? = None,
) -> ComponentEffect {
  {
    key,
    cleanup,
    cleanup_with_reason,
    status: ComponentEffectStatus::EffectActive,
    cancel_reason: None,
    reused: false,
  }
}

///|
pub fn ComponentEffect::cancel(self : ComponentEffect) -> Unit {
  self.cancel_with_reason(ComponentEffectCancelReason::EffectUnmounted)
}

///|
pub fn ComponentEffect::cancel_with_reason(
  self : ComponentEffect,
  reason : ComponentEffectCancelReason,
) -> Unit {
  self.status = ComponentEffectStatus::EffectCancelled
  self.cancel_reason = Some(reason)
  match self.cleanup_with_reason {
    Some(cleanup) => cleanup(reason)
    None => ()
  }
  match self.cleanup {
    Some(cleanup) => cleanup()
    None => ()
  }
}

///|
pub fn[T] SaveableCodec::new(
  encode~ : (T) -> String,
  decode~ : (String) -> T?,
) -> SaveableCodec[T] {
  { encode, decode }
}

///|
pub fn SaveableCodec::string() -> SaveableCodec[String] {
  SaveableCodec::new(encode=value => value, decode=value => Some(value))
}

///|
pub fn SaveableCodec::bool() -> SaveableCodec[Bool] {
  SaveableCodec::new(encode=value => if value { "true" } else { "false" }, decode=value => {
    match value {
      "true" => Some(true)
      "false" => Some(false)
      _ => None
    }
  })
}

///|
pub fn SaveableCodec::int() -> SaveableCodec[Int] {
  SaveableCodec::new(
    encode=value => value.to_string(),
    decode=parse_saveable_int,
  )
}

///|
pub fn SaveableStateStore::new() -> SaveableStateStore {
  { strings: [] }
}

///|
pub fn[T] SaveableStateStore::get(
  self : SaveableStateStore,
  key : String,
  codec : SaveableCodec[T],
) -> T? {
  match self.get_string(key) {
    Some(value) => (codec.decode)(value)
    None => None
  }
}

///|
pub fn[T] SaveableStateStore::set(
  self : SaveableStateStore,
  key : String,
  value : T,
  codec : SaveableCodec[T],
) -> Unit {
  self.set_string(key, (codec.encode)(value))
}

///|
pub fn SaveableStateStore::get_string(
  self : SaveableStateStore,
  key : String,
) -> String? {
  for entry in self.strings {
    if entry.key == key {
      return Some(entry.value)
    }
  }
  None
}

///|
pub fn SaveableStateStore::set_string(
  self : SaveableStateStore,
  key : String,
  value : String,
) -> Unit {
  for entry in self.strings {
    if entry.key == key {
      entry.value = value
      return
    }
  }
  self.strings.push({ key, value })
}

///|
pub fn SaveableStateStore::get_bool(
  self : SaveableStateStore,
  key : String,
) -> Bool? {
  self.get(key, SaveableCodec::bool())
}

///|
pub fn SaveableStateStore::set_bool(
  self : SaveableStateStore,
  key : String,
  value : Bool,
) -> Unit {
  self.set(key, value, SaveableCodec::bool())
}

///|
pub fn SaveableStateStore::get_int(
  self : SaveableStateStore,
  key : String,
) -> Int? {
  self.get(key, SaveableCodec::int())
}

///|
pub fn SaveableStateStore::set_int(
  self : SaveableStateStore,
  key : String,
  value : Int,
) -> Unit {
  self.set(key, value, SaveableCodec::int())
}

///|
pub fn SaveableStateStore::remove(
  self : SaveableStateStore,
  key : String,
) -> Unit {
  self.strings = self.strings.filter(entry => entry.key != key)
}

///|
fn parse_saveable_int(value : String) -> Int? {
  let chars = value.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut index = 0
  let mut sign = 1
  if chars[index] == '-' {
    sign = -1
    index = index + 1
  }
  if index >= chars.length() {
    return None
  }
  let mut parsed = 0
  while index < chars.length() {
    let char = chars[index]
    if !char.is_ascii_digit() {
      return None
    }
    parsed = parsed * 10 + char.to_int() - '0'.to_int()
    index = index + 1
  }
  Some(parsed * sign)
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
pub fn[T] BuildContext::watch_derived(
  self : BuildContext,
  state : DerivedState[T],
) -> T {
  let component_id = self.component_id
  for
    subscription in state.subscribe(() => {
      self.runtime.request_component_rebuild(component_id)
    }) {
    self.subscriptions.push(subscription)
  }
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
pub fn BuildContext::run_effect(
  self : BuildContext,
  key~ : String,
  effect : () -> (() -> Unit)?,
) -> Unit {
  match self.take_old_effect(key) {
    Some(existing) => {
      existing.reused = true
      self.effects.push(existing)
    }
    None => self.effects.push(ComponentEffect::new(key~, cleanup=effect()))
  }
}

///|
pub fn BuildContext::run_effect_with_reason(
  self : BuildContext,
  key~ : String,
  effect : () -> ((ComponentEffectCancelReason) -> Unit)?,
) -> Unit {
  match self.take_old_effect(key) {
    Some(existing) => {
      existing.reused = true
      self.effects.push(existing)
    }
    None =>
      self.effects.push(
        ComponentEffect::new(key~, cleanup_with_reason=effect()),
      )
  }
}

///|
pub fn BuildContext::on_update(
  self : BuildContext,
  key~ : String,
  deps~ : Array[String],
  effect : () -> (() -> Unit)?,
) -> Unit {
  let deps_key = deps.join("|")
  self.run_effect(key="update:\{key}:\{deps_key}", effect)
}

///|
pub fn BuildContext::on_update_with_reason(
  self : BuildContext,
  key~ : String,
  deps~ : Array[String],
  effect : () -> ((ComponentEffectCancelReason) -> Unit)?,
) -> Unit {
  let deps_key = deps.join("|")
  self.run_effect_with_reason(key="update:\{key}:\{deps_key}", effect)
}

///|
pub fn BuildContext::on_mount(
  self : BuildContext,
  key~ : String,
  effect : () -> Unit,
) -> Unit {
  self.run_effect(key="mount:\{key}", () => {
    effect()
    None
  })
}

///|
pub fn BuildContext::on_unmount_with_reason(
  self : BuildContext,
  key~ : String,
  cleanup : (ComponentEffectCancelReason) -> Unit,
) -> Unit {
  self.run_effect_with_reason(key="dispose:\{key}", () => Some(cleanup))
}

///|
pub fn BuildContext::on_unmount(
  self : BuildContext,
  key~ : String,
  cleanup : () -> Unit,
) -> Unit {
  self.on_dispose(key~, cleanup)
}

///|
pub fn BuildContext::on_dispose(
  self : BuildContext,
  key~ : String,
  cleanup : () -> Unit,
) -> Unit {
  self.run_effect(key="dispose:\{key}", () => Some(cleanup))
}

///|
pub fn BuildContext::save_string(
  self : BuildContext,
  key~ : String,
  value : String,
) -> Unit {
  self.runtime.saveable_state.set_string(self.scoped_saveable_key(key), value)
}

///|
pub fn BuildContext::restore_string(
  self : BuildContext,
  key~ : String,
) -> String? {
  self.runtime.saveable_state.get_string(self.scoped_saveable_key(key))
}

///|
pub fn BuildContext::save_bool(
  self : BuildContext,
  key~ : String,
  value : Bool,
) -> Unit {
  self.runtime.saveable_state.set_bool(self.scoped_saveable_key(key), value)
}

///|
pub fn BuildContext::restore_bool(self : BuildContext, key~ : String) -> Bool? {
  self.runtime.saveable_state.get_bool(self.scoped_saveable_key(key))
}

///|
pub fn BuildContext::save_int(
  self : BuildContext,
  key~ : String,
  value : Int,
) -> Unit {
  self.runtime.saveable_state.set_int(self.scoped_saveable_key(key), value)
}

///|
pub fn BuildContext::restore_int(self : BuildContext, key~ : String) -> Int? {
  self.runtime.saveable_state.get_int(self.scoped_saveable_key(key))
}

///|
pub fn[T] BuildContext::save(
  self : BuildContext,
  key~ : String,
  value : T,
  codec : SaveableCodec[T],
) -> Unit {
  self.runtime.saveable_state.set(self.scoped_saveable_key(key), value, codec)
}

///|
pub fn[T] BuildContext::restore(
  self : BuildContext,
  key~ : String,
  codec : SaveableCodec[T],
) -> T? {
  self.runtime.saveable_state.get(self.scoped_saveable_key(key), codec)
}

///|
pub fn[T] BuildContext::saveable(
  self : BuildContext,
  key~ : String,
  initial : T,
  codec : SaveableCodec[T],
) -> State[T] {
  let scoped = self.scoped_saveable_key(key)
  let restored = self.runtime.saveable_state
    .get(scoped, codec)
    .unwrap_or(initial)
  let state = State::new(restored)
  let store = self.runtime.saveable_state
  let runtime = self.runtime
  let component_id = self.component_id
  ignore(
    state.subscribe(() => {
      store.set(scoped, state.get(), codec)
      runtime.request_component_rebuild(component_id)
    }),
  )
  store.set(scoped, state.get(), codec)
  state
}

///|
pub fn BuildContext::saveable_string(
  self : BuildContext,
  key~ : String,
  initial : String,
) -> State[String] {
  self.saveable(key~, initial, SaveableCodec::string())
}

///|
pub fn BuildContext::saveable_bool(
  self : BuildContext,
  key~ : String,
  initial : Bool,
) -> State[Bool] {
  self.saveable(key~, initial, SaveableCodec::bool())
}

///|
pub fn BuildContext::saveable_int(
  self : BuildContext,
  key~ : String,
  initial : Int,
) -> State[Int] {
  self.saveable(key~, initial, SaveableCodec::int())
}

///|
fn BuildContext::scoped_saveable_key(
  self : BuildContext,
  key : String,
) -> String {
  "\{self.component_id.value}:\{key}"
}

///|
fn BuildContext::take_old_effect(
  self : BuildContext,
  key : String,
) -> ComponentEffect? {
  for effect in self.old_effects {
    if !effect.reused && effect.key == key {
      return Some(effect)
    }
  }
  None
}

///|
pub fn BuildContext::environment(self : BuildContext) -> Environment {
  self.environment
}

///|
pub fn BuildContext::theme(self : BuildContext) -> Theme {
  self.environment.theme
}

///|
pub fn BuildContext::color_scheme(self : BuildContext) -> ColorScheme {
  self.environment.color_scheme
}

///|
pub fn BuildContext::scale_factor(self : BuildContext) -> Double {
  self.environment.scale_factor
}

///|
pub fn BuildContext::viewport_size(self : BuildContext) -> Size {
  self.runtime.size
}

///|
pub fn BuildContext::text_scale(self : BuildContext) -> Double {
  self.environment.text_scale
}

///|
pub fn BuildContext::locale(self : BuildContext) -> String {
  self.environment.locale
}

///|
pub fn BuildContext::layout_direction(self : BuildContext) -> LayoutDirection {
  self.environment.layout_direction
}

///|
pub fn BuildContext::accessibility_contrast(
  self : BuildContext,
) -> AccessibilityContrast {
  self.environment.accessibility_contrast
}

///|
pub fn BuildContext::reduced_motion(self : BuildContext) -> Bool {
  self.environment.reduced_motion
}

///|
pub fn BuildContext::content_size_category(
  self : BuildContext,
) -> ContentSizeCategory {
  self.environment.content_size_category
}

///|
pub fn BuildContext::enabled(self : BuildContext) -> Bool {
  self.environment.enabled
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
pub fn RuntimeState::environment(self : RuntimeState) -> Environment {
  self.environment
}

///|
pub fn RuntimeState::text_measurer(self : RuntimeState) -> TextMeasurer {
  self.text_measurer
}

///|
pub fn RuntimeState::set_text_measurer(
  self : RuntimeState,
  text_measurer : TextMeasurer,
) -> Unit {
  self.text_measurer = text_measurer
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
  self.element_tree.mark_subtree_layout_dirty()
  self.mark_dirty(self.element_tree.id)
}

///|
pub fn RuntimeState::register_font_data(
  self : RuntimeState,
  family : FontFamily,
  data : Bytes,
) -> Unit {
  self.text_measurer.register_font_data(family, data)
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
  self.element_tree.mark_subtree_layout_dirty()
  self.mark_dirty(self.element_tree.id)
}

///|
pub fn RuntimeState::set_environment(
  self : RuntimeState,
  environment : Environment,
) -> Unit {
  if self.environment != environment {
    self.environment = environment
    self.needs_rebuild = self.element_tree.mark_component_tree_build_dirty()
    self.needs_layout = true
    self.needs_paint = true
    self.needs_redraw = true
    self.element_tree.mark_subtree_layout_dirty()
    self.mark_dirty(self.element_tree.id)
  }
}

///|
pub fn RuntimeState::mount(self : RuntimeState, root : ViewSpec) -> Unit {
  self.element_tree.cancel_component_tree_subscriptions(
    reason=ComponentEffectCancelReason::EffectUnmounted,
  )
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
pub fn RuntimeState::destroy(self : RuntimeState) -> Unit {
  self.element_tree.cancel_component_tree_subscriptions(
    reason=ComponentEffectCancelReason::EffectRuntimeDestroyed,
  )
  self.element_tree = mount_view_spec(ViewSpec::EmptySpec)
  self.render_tree = RenderNode::empty()
  self.root_spec = ViewSpec::EmptySpec
  self.next_element_id = 1
  self.dirty_elements.clear()
  self.focused_element = None
  self.needs_rebuild = false
  self.needs_layout = false
  self.needs_paint = false
  self.needs_redraw = false
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
pub fn RuntimeState::dispatch_focused_text_command(
  self : RuntimeState,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  match self.focused_element {
    Some(target) => {
      let result = self.element_tree.dispatch_text_command(
        target,
        intent,
        paste_text~,
      )
      if result.changed {
        self.needs_redraw = true
        self.needs_paint = true
        self.mark_dirty(self.element_tree.id)
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
      self.needs_rebuild = self.element_tree.mark_component_tree_build_dirty()
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
        self.focused_element = self.element_tree.find_focusable_at(
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
      } else if self.action_commands.dispatch_shortcut(event) is Some(_) {
        self.request_activation_rebuild()
        self.rebuild_if_possible()
      } else if event.pressed && event.key == "Tab" {
        ignore(self.move_focus(reverse=event.modifiers.shift))
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
fn RuntimeState::move_focus(
  self : RuntimeState,
  reverse? : Bool = false,
) -> Bool {
  self.ensure_render_tree()
  let previous_focus = self.focused_element
  self.focused_element = self.element_tree.next_focus(
    current=previous_focus,
    reverse~,
  )
  if previous_focus != self.focused_element {
    self.mark_dirty(self.element_tree.id)
    true
  } else {
    false
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
      match
        self.element_tree.focused_text_input(
          target,
          self.render_tree,
          text_measurer=self.text_measurer,
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
  self.render_tree = self.element_tree.render_focused_with_text_measurer(
    Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
    focused=self.focused_element,
    environment=self.environment,
    text_measurer=self.text_measurer,
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
  old_effects : Array[ComponentEffect],
) -> ComponentBuildResult {
  for subscription in old_subscriptions {
    subscription.cancel()
  }
  let subscriptions : Array[StateSubscription] = []
  let effects : Array[ComponentEffect] = []
  let context = BuildContext::{
    runtime,
    component_id,
    subscriptions,
    effects,
    old_effects,
    environment: runtime.environment,
  }
  let child_spec = (component.build)(context)
  for effect in old_effects {
    if !effect.reused {
      effect.cancel_with_reason(ComponentEffectCancelReason::EffectKeyChanged)
    }
    effect.reused = false
  }
  { child_spec, subscriptions, effects }
}

///|
fn cancel_component_effects(
  effects : Array[ComponentEffect],
  reason? : ComponentEffectCancelReason = ComponentEffectCancelReason::EffectUnmounted,
) -> Unit {
  for effect in effects {
    effect.cancel_with_reason(reason)
  }
}
