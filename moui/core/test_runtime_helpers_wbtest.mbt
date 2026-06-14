///|
fn AppRuntime::new_spec(
  root~ : ViewSpec,
  size~ : Size,
  environment? : Environment = Environment::default(),
) -> AppRuntime {
  {
    state: RuntimeState::new_spec(root~, size~, environment~),
    program_runtime_snapshot_fn: () => ProgramRuntimeSnapshot::empty(),
    destroy_program_runtime_fn: () => (),
  }
}

///|
fn AppRuntime::set_root_spec(self : AppRuntime, root : ViewSpec) -> Unit {
  self.state.set_root_spec(root)
}

///|
fn RuntimeState::set_root_spec(self : RuntimeState, root : ViewSpec) -> Unit {
  self.element_tree.root.cancel_component_tree_subscriptions()
  self.root_spec = root
  self.rebuild()
  self.needs_redraw = true
}

///|
fn RuntimeState::mount(self : RuntimeState, root : ViewSpec) -> Unit {
  self.element_tree.root.cancel_component_tree_subscriptions(
    reason=ComponentEffectCancelReason::EffectUnmounted,
  )
  let mounted = mount_view_spec_for_runtime(root, Some(self), 1)
  self.root_spec = root
  self.element_tree = ElementTree::new(mounted.node)
  self.next_element_id = mounted.next_id
  self.focused_element = None
  self.active_pointer_capture = None
  self.needs_rebuild = false
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
  self.mark_dirty(self.element_tree.id())
  self.layout_pass()
}

///|
fn ViewSpec::key(self : ViewSpec, value : String) -> ViewSpec {
  self.with_key(Key::new(value))
}

///|
fn ViewSpec::background(self : ViewSpec, color : Color) -> ViewSpec {
  self.background_brush(Brush::solid(color))
}

///|
fn ViewSpec::opacity(self : ViewSpec, opacity : Double) -> ViewSpec {
  self.modified(OpacityModifier(opacity))
}

///|
fn ViewSpec::clip(self : ViewSpec) -> ViewSpec {
  self.modified(ClipModifier)
}

///|
fn ViewSpec::focusable(self : ViewSpec, focusable? : Bool = true) -> ViewSpec {
  self.modified(FocusableModifier(focusable))
}

///|
fn ViewSpec::focus_trap(self : ViewSpec, enabled? : Bool = true) -> ViewSpec {
  self.modified(FocusTrapModifier(enabled))
}

///|
fn ViewSpec::keyboard_shortcut(
  self : ViewSpec,
  shortcut : KeyboardShortcut,
) -> ViewSpec {
  self.modified(KeyboardShortcutModifier(shortcut))
}

///|
fn ViewSpec::layout_priority(self : ViewSpec, priority : Double) -> ViewSpec {
  self.modified(LayoutPriorityModifier(priority))
}

///|
fn ViewSpec::align(
  self : ViewSpec,
  alignment? : Alignment = Alignment::center(),
) -> ViewSpec {
  self.modified(AlignModifier(alignment))
}

///|
fn ViewSpec::padding(self : ViewSpec, value : Double) -> ViewSpec {
  self.modified(PaddingModifier(Insets::all(value)))
}

///|
fn ViewSpec::frame(
  self : ViewSpec,
  width? : Double,
  height? : Double,
  min_width? : Double,
  min_height? : Double,
  max_width? : Double,
  max_height? : Double,
) -> ViewSpec {
  self.modified(
    FrameModifier({
      width,
      height,
      min_width,
      min_height,
      max_width,
      max_height,
    }),
  )
}

///|
fn ViewSpec::custom(
  measure~ : (Constraints) -> Size,
  paint~ : (Rect) -> Array[DrawCommand],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> ViewSpec {
  CustomSpec({ key: None, measure, paint, semantics_role, semantics_label })
}

///|
fn ViewSpec::custom_layout(
  children~ : Array[ViewSpec],
  measure~ : (CustomLayoutContext) -> Size,
  place~ : (CustomPlacementContext) -> Array[Rect],
  paint? : (Rect) -> Array[DrawCommand] = _frame => [],
  semantics_role? : SemanticsRole = SemanticsRole::Group,
  semantics_label? : String = "",
) -> ViewSpec {
  CustomLayoutSpec({
    key: None,
    children,
    cache: CustomLayoutCache::new(),
    measure,
    place,
    paint,
    semantics_role,
    semantics_label,
  })
}
