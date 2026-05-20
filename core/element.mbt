///|
pub(all) struct ElementNode {
  id : ElementId
  mut key : Key?
  mut spec : ViewSpec
  mut children : Array[ElementNode]
  mut dirty : DirtyFlags
  mut button_state : ButtonState
  mut picker_expanded : Bool
  mut datepicker_expanded : Bool
  mut datepicker_view : DateValue
  mut caret : Int
  mut selection : TextRange?
  mut composition : String?
  mut composition_cursor : TextRange?
  mut component_child_spec : ViewSpec?
  mut component_subscriptions : Array[StateSubscription]
  mut component_effects : Array[ComponentEffect]
  mut cached_intrinsic_size : Size?
  mut cached_measure_constraints : Constraints?
  mut cached_measured : MeasuredNode?
  mut cached_place_frame : Rect?
  mut cached_placed : PlacedNode?
  mut cached_render_frame : Rect?
  mut cached_render_focused : ElementId?
  mut cached_render : RenderNode?
}

///|
pub(all) struct RenderNode {
  element_id : ElementId
  frame : Rect
  children : Array[RenderNode]
  hit_testable : Bool
  paint_commands : Array[DrawCommand]
  post_paint_commands : Array[DrawCommand]
} derive(Eq, Debug, ToJson)

///|
fn RenderNode::empty() -> RenderNode {
  {
    element_id: ElementId::new(0),
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    children: [],
    hit_testable: false,
    paint_commands: [],
    post_paint_commands: [],
  }
}

///|
pub(all) struct ElementEventResult {
  changed : Bool
  activated : Bool
  focused : ElementId?
} derive(Eq, Debug, ToJson)

///|
priv struct MountResult {
  node : ElementNode
  next_id : Int
}

///|
priv struct ReconcileResult {
  node : ElementNode
  next_id : Int
}

///|
pub fn mount_view_spec(spec : ViewSpec) -> ElementNode {
  mount_view_spec_with_next(spec, 1).node
}

///|
fn mount_view_spec_with_next(spec : ViewSpec, next_id : Int) -> MountResult {
  mount_view_spec_for_runtime(spec, None, next_id)
}

///|
fn mount_view_spec_for_runtime(
  spec : ViewSpec,
  runtime : RuntimeState?,
  next_id : Int,
) -> MountResult {
  let id = ElementId::new(next_id)
  let mut next = next_id + 1
  let children : Array[ElementNode] = []
  let mut component_child_spec : ViewSpec? = None
  let mut component_subscriptions : Array[StateSubscription] = []
  let mut component_effects : Array[ComponentEffect] = []
  match spec {
    ComponentSpec(data) =>
      match runtime {
        Some(runtime) => {
          let built = build_component_spec(data.component, runtime, id, [], [])
          component_child_spec = Some(built.child_spec)
          component_subscriptions = built.subscriptions
          component_effects = built.effects
          let mounted = mount_view_spec_for_runtime(
            built.child_spec,
            Some(runtime),
            next,
          )
          children.push(mounted.node)
          next = mounted.next_id
        }
        None => ()
      }
    FlexSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    PaddingSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.child, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    FrameSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.child, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    StackSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    ScrollSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.child, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    GridSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    ListSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    CustomLayoutSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    SheetSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.content, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    ContainerSpec(data) =>
      match data.child {
        Some(child) => {
          let mounted = mount_view_spec_for_runtime(child, runtime, next)
          children.push(mounted.node)
          next = mounted.next_id
        }
        None => ()
      }
    ModifiedSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.child, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    _ => ()
  }
  {
    node: {
      id,
      key: spec.identity_key(),
      spec,
      children,
      dirty: DirtyFlags::all(),
      button_state: ButtonState::Normal,
      picker_expanded: false,
      datepicker_expanded: false,
      datepicker_view: DateValue::today(),
      caret: 0,
      selection: None,
      composition: None,
      composition_cursor: None,
      component_child_spec,
      component_subscriptions,
      component_effects,
      cached_intrinsic_size: None,
      cached_measure_constraints: None,
      cached_measured: None,
      cached_place_frame: None,
      cached_placed: None,
      cached_render_frame: None,
      cached_render_focused: None,
      cached_render: None,
    },
    next_id: next,
  }
}

///|
pub fn reconcile_element(
  old : ElementNode,
  next_spec : ViewSpec,
) -> ElementNode {
  reconcile_element_with_next(old, next_spec, 1).node
}

///|
fn reconcile_element_with_next(
  old : ElementNode,
  next_spec : ViewSpec,
  next_id : Int,
) -> ReconcileResult {
  reconcile_element_for_runtime(old, next_spec, None, next_id)
}

///|
fn reconcile_element_for_runtime(
  old : ElementNode,
  next_spec : ViewSpec,
  runtime : RuntimeState?,
  next_id : Int,
) -> ReconcileResult {
  if !old.spec.same_identity(next_spec) {
    old.cancel_component_tree_subscriptions()
    let mounted = mount_view_spec_for_runtime(next_spec, runtime, next_id)
    { node: mounted.node, next_id: mounted.next_id }
  } else {
    old.spec = next_spec
    old.key = old.spec.identity_key()
    let children_result = if old.spec is ComponentSpec(_) {
      { children: old.children, next_id }
    } else {
      reconcile_children_for_runtime(old.children, old.spec, runtime, next_id)
    }
    old.children = children_result.children
    match old.spec {
      ComponentSpec(_) => {
        old.dirty.mark_build()
        old.clear_cached_layout_and_paint()
      }
      _ => {
        old.dirty.mark_layout()
        old.clear_cached_layout_and_paint()
      }
    }
    { node: old, next_id: children_result.next_id }
  }
}

///|
priv struct ChildrenReconcileResult {
  children : Array[ElementNode]
  next_id : Int
}

///|
fn reconcile_children_for_runtime(
  old_children : Array[ElementNode],
  next_spec : ViewSpec,
  runtime : RuntimeState?,
  next_id : Int,
) -> ChildrenReconcileResult {
  let next_specs = child_specs(next_spec)
  let children : Array[ElementNode] = []
  let used : Array[Bool] = []
  for _ in old_children {
    used.push(false)
  }
  let mut next = next_id
  for index, child_spec in next_specs {
    let old_index = find_reusable_child(old_children, used, child_spec, index)
    match old_index {
      Some(old_index) => {
        used[old_index] = true
        let result = reconcile_element_for_runtime(
          old_children[old_index],
          child_spec,
          runtime,
          next,
        )
        children.push(result.node)
        next = result.next_id
      }
      None => {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    }
  }
  for index, old_child in old_children {
    if !used[index] {
      old_child.cancel_component_tree_subscriptions()
    }
  }
  { children, next_id: next }
}

///|
fn find_reusable_child(
  old_children : Array[ElementNode],
  used : Array[Bool],
  child_spec : ViewSpec,
  index : Int,
) -> Int? {
  match child_spec.identity_key() {
    Some(key) => {
      for old_index, old_child in old_children {
        if !used[old_index] &&
          old_child.key == Some(key) &&
          old_child.spec.kind() == child_spec.kind() {
          return Some(old_index)
        }
      }
      None
    }
    None =>
      if index < old_children.length() &&
        !used[index] &&
        old_children[index].key is None &&
        old_children[index].spec.kind() == child_spec.kind() {
        Some(index)
      } else {
        None
      }
  }
}

///|
fn child_specs(spec : ViewSpec) -> Array[ViewSpec] {
  match spec {
    FlexSpec(data) => data.children
    PaddingSpec(data) => [data.child]
    FrameSpec(data) => [data.child]
    StackSpec(data) => data.children
    ScrollSpec(data) => [data.child]
    GridSpec(data) => data.children
    ListSpec(data) => data.children
    CustomLayoutSpec(data) => data.children
    SheetSpec(data) => [data.content]
    ContainerSpec(data) =>
      match data.child {
        Some(child) => [child]
        None => []
      }
    ModifiedSpec(data) => [data.child]
    ComponentSpec(_) => []
    _ => []
  }
}

///|
fn ElementNode::rebuild_dirty_components(
  self : ElementNode,
  runtime : RuntimeState,
  next_id : Int,
) -> ReconcileResult {
  let mut next = next_id
  if self.dirty.needs_build {
    match self.spec {
      ComponentSpec(data) => {
        let built = build_component_spec(
          data.component,
          runtime,
          self.id,
          self.component_subscriptions,
          self.component_effects,
        )
        self.component_subscriptions = built.subscriptions
        self.component_effects = built.effects
        self.component_child_spec = Some(built.child_spec)
        let result = if self.children.length() > 0 {
          reconcile_element_for_runtime(
            self.children[0],
            built.child_spec,
            Some(runtime),
            next,
          )
        } else {
          let mounted = mount_view_spec_for_runtime(
            built.child_spec,
            Some(runtime),
            next,
          )
          { node: mounted.node, next_id: mounted.next_id }
        }
        self.children = [result.node]
        next = result.next_id
      }
      _ => ()
    }
    self.dirty.needs_build = false
    self.dirty.mark_layout()
    self.clear_cached_layout_and_paint()
  }
  let children : Array[ElementNode] = []
  for child in self.children {
    let result = child.rebuild_dirty_components(runtime, next)
    children.push(result.node)
    next = result.next_id
  }
  self.children = children
  { node: self, next_id: next }
}

///|
fn ElementNode::has_dirty_build(self : ElementNode) -> Bool {
  if self.dirty.needs_build {
    true
  } else {
    self.children.any(child => child.has_dirty_build())
  }
}

///|
fn ElementNode::has_dirty_layout(self : ElementNode) -> Bool {
  if self.dirty.needs_layout {
    true
  } else {
    self.children.any(child => child.has_dirty_layout())
  }
}

///|
fn ElementNode::has_dirty_paint(self : ElementNode) -> Bool {
  if self.dirty.needs_paint {
    true
  } else {
    self.children.any(child => child.has_dirty_paint())
  }
}

///|
fn ElementNode::mark_build_dirty_by_id(
  self : ElementNode,
  id : ElementId,
) -> Bool {
  if self.id == id {
    self.dirty.mark_build()
    self.clear_cached_layout_and_paint()
    true
  } else {
    let mut found = false
    for child in self.children {
      found = child.mark_build_dirty_by_id(id) || found
    }
    if found {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    }
    found
  }
}

///|
fn ElementNode::mark_paint_dirty_by_id(
  self : ElementNode,
  id : ElementId,
) -> Bool {
  if self.id == id {
    self.dirty.mark_paint()
    self.cached_render_frame = None
    self.cached_render_focused = None
    self.cached_render = None
    true
  } else {
    let mut found = false
    for child in self.children {
      found = child.mark_paint_dirty_by_id(id) || found
    }
    if found {
      self.dirty.mark_paint()
      self.cached_render_frame = None
      self.cached_render_focused = None
      self.cached_render = None
    }
    found
  }
}

///|
fn ElementNode::mark_root_component_build_dirty(self : ElementNode) -> Bool {
  match self.spec {
    ComponentSpec(_) => {
      self.dirty.mark_build()
      self.clear_cached_layout_and_paint()
      true
    }
    _ => false
  }
}

///|
fn ElementNode::mark_component_tree_build_dirty(self : ElementNode) -> Bool {
  let mut found = false
  match self.spec {
    ComponentSpec(_) => {
      self.dirty.mark_build()
      self.clear_cached_layout_and_paint()
      found = true
    }
    _ => ()
  }
  for child in self.children {
    found = child.mark_component_tree_build_dirty() || found
  }
  if found {
    self.dirty.mark_layout()
    self.clear_cached_layout_and_paint()
  }
  found
}

///|
fn ElementNode::mark_subtree_layout_dirty(self : ElementNode) -> Unit {
  self.dirty.mark_layout()
  self.clear_cached_layout_and_paint()
  for child in self.children {
    child.mark_subtree_layout_dirty()
  }
}

///|
fn ElementNode::cancel_component_tree_subscriptions(self : ElementNode) -> Unit {
  self.cancel_component_subscriptions()
  self.cancel_component_effects()
  for child in self.children {
    child.cancel_component_tree_subscriptions()
  }
}

///|
fn ElementNode::cancel_component_subscriptions(self : ElementNode) -> Unit {
  for subscription in self.component_subscriptions {
    subscription.cancel()
  }
  self.component_subscriptions.clear()
}

///|
fn ElementNode::cancel_component_effects(self : ElementNode) -> Unit {
  cancel_component_effects(self.component_effects)
  self.component_effects.clear()
}

///|
fn ElementNode::clear_cached_layout_and_paint(self : ElementNode) -> Unit {
  self.cached_intrinsic_size = None
  self.cached_measure_constraints = None
  self.cached_measured = None
  self.cached_place_frame = None
  self.cached_placed = None
  self.cached_render_frame = None
  self.cached_render_focused = None
  self.cached_render = None
}
