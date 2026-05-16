///|
pub(all) struct ElementNode {
  id : ElementId
  mut key : Key?
  mut spec : ViewSpec
  mut children : Array[ElementNode]
  mut dirty : DirtyFlags
  mut button_state : ButtonState
  mut caret : Int
  mut selection : TextRange?
  mut composition : String?
}

///|
pub(all) struct RenderNode {
  element_id : ElementId
  frame : Rect
  children : Array[RenderNode]
  hit_testable : Bool
  paint_commands : Array[DrawCommand]
} derive(Eq, Debug, ToJson)

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
  let id = ElementId::new(next_id)
  let mut next = next_id + 1
  let children : Array[ElementNode] = []
  match spec {
    FlexSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_with_next(child_spec, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    PaddingSpec(data) => {
      let mounted = mount_view_spec_with_next(data.child, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    FrameSpec(data) => {
      let mounted = mount_view_spec_with_next(data.child, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    StackSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_with_next(child_spec, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    ScrollSpec(data) => {
      let mounted = mount_view_spec_with_next(data.child, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    GridSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_with_next(child_spec, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    ListSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_with_next(child_spec, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    ContainerSpec(data) =>
      match data.child {
        Some(child) => {
          let mounted = mount_view_spec_with_next(child, next)
          children.push(mounted.node)
          next = mounted.next_id
        }
        None => ()
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
      caret: 0,
      selection: None,
      composition: None,
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
  if !old.spec.same_identity(next_spec) {
    let mounted = mount_view_spec_with_next(next_spec, next_id)
    { node: mounted.node, next_id: mounted.next_id }
  } else {
    let children_result = reconcile_children(old.children, next_spec, next_id)
    old.spec = next_spec
    old.key = old.spec.identity_key()
    old.children = children_result.children
    old.dirty.mark_build()
    { node: old, next_id: children_result.next_id }
  }
}

///|
priv struct ChildrenReconcileResult {
  children : Array[ElementNode]
  next_id : Int
}

///|
fn reconcile_children(
  old_children : Array[ElementNode],
  next_spec : ViewSpec,
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
        let result = reconcile_element_with_next(
          old_children[old_index],
          child_spec,
          next,
        )
        children.push(result.node)
        next = result.next_id
      }
      None => {
        let mounted = mount_view_spec_with_next(child_spec, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
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
    ContainerSpec(data) =>
      match data.child {
        Some(child) => [child]
        None => []
      }
    _ => []
  }
}

