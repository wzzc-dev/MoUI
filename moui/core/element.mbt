///|
struct ElementEventResult {
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
  dirty_kind : ReconcileDirtyKind
}

///|
priv struct ChildrenReconcileResult {
  children : Array[ElementNode]
  next_id : Int
  dirty_kind : ReconcileDirtyKind
}

///|
priv enum ReconcileDirtyKind {
  ReconcileClean
  ReconcilePaint
  ReconcileLayout
}

///|
fn ReconcileDirtyKind::rank(self : ReconcileDirtyKind) -> Int {
  match self {
    ReconcileClean => 0
    ReconcilePaint => 1
    ReconcileLayout => 2
  }
}

///|
fn ReconcileDirtyKind::combine(
  self : ReconcileDirtyKind,
  other : ReconcileDirtyKind,
) -> ReconcileDirtyKind {
  if self.rank() >= other.rank() {
    self
  } else {
    other
  }
}

///|
fn mount_view_spec(spec : ViewSpec) -> ElementNode {
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
  let mut component_subscriptions : Array[StateSubscription] = []
  let mut component_effects : Array[ComponentEffect] = []
  match spec {
    ComponentSpec(data) =>
      match runtime {
        Some(runtime) => {
          let built = build_component_spec(data.component, runtime, id, [], [])
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
      control: ElementControlState::new(),
      component: ElementComponentState::new(
        subscriptions=component_subscriptions,
        effects=component_effects,
      ),
      layout_cache: ElementLayoutCache::empty(),
      render_cache: ElementRenderCache::empty(),
    },
    next_id: next,
  }
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
    {
      node: mounted.node,
      next_id: mounted.next_id,
      dirty_kind: ReconcileLayout,
    }
  } else {
    let own_dirty = old.spec.reconcile_dirty_kind(next_spec)
    old.spec = next_spec
    old.key = old.spec.identity_key()
    let children_result = if old.spec is ComponentSpec(_) {
      {
        children: old.children,
        next_id,
        dirty_kind: ReconcileDirtyKind::ReconcileClean,
      }
    } else {
      reconcile_children_for_runtime(old.children, old.spec, runtime, next_id)
    }
    old.children = children_result.children
    let dirty_kind = own_dirty.combine(children_result.dirty_kind)
    old.apply_reconcile_dirty(dirty_kind)
    { node: old, next_id: children_result.next_id, dirty_kind }
  }
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
  let mut dirty = ReconcileDirtyKind::ReconcileClean
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
        dirty = dirty.combine(result.dirty_kind)
      }
      None => {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
        dirty = dirty.combine(ReconcileDirtyKind::ReconcileLayout)
      }
    }
  }
  for index, old_child in old_children {
    if !used[index] {
      old_child.cancel_component_tree_subscriptions()
      dirty = dirty.combine(ReconcileDirtyKind::ReconcileLayout)
    }
  }
  { children, next_id: next, dirty_kind: dirty }
}

///|
fn ElementNode::apply_reconcile_dirty(
  self : ElementNode,
  dirty : ReconcileDirtyKind,
) -> Unit {
  match dirty {
    ReconcileClean => ()
    ReconcilePaint => {
      self.dirty.mark_paint()
      self.render_cache.clear()
    }
    ReconcileLayout => {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    }
  }
}

///|
fn bool_dirty(changed : Bool, dirty : ReconcileDirtyKind) -> ReconcileDirtyKind {
  if changed {
    dirty
  } else {
    ReconcileDirtyKind::ReconcileClean
  }
}

///|
fn combine_dirty(
  first : ReconcileDirtyKind,
  second : ReconcileDirtyKind,
) -> ReconcileDirtyKind {
  first.combine(second)
}

///|
fn ViewSpec::reconcile_dirty_kind(
  self : ViewSpec,
  next : ViewSpec,
) -> ReconcileDirtyKind {
  match (self, next) {
    (EmptySpec, EmptySpec) => ReconcileClean
    (TextSpec(old), TextSpec(new)) => {
      let layout_changed = old.text != new.text ||
        old.size != new.size ||
        old.font != new.font
      let paint_changed = old.color != new.color
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (ButtonSpec(old), ButtonSpec(new)) => {
      let layout_changed = old.text != new.text ||
        old.size != new.size ||
        old.font != new.font
      let paint_changed = old.foreground != new.foreground ||
        old.background != new.background ||
        old.hovered_background != new.hovered_background ||
        old.pressed_background != new.pressed_background ||
        old.border != new.border ||
        old.shadow != new.shadow ||
        old.corner_radius != new.corner_radius
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (TextFieldSpec(old), TextFieldSpec(new)) =>
      reconcile_text_field_dirty(old, new)
    (RichTextEditorSpec(old), RichTextEditorSpec(new)) =>
      reconcile_rich_text_editor_dirty(old, new)
    (ImageSpec(old), ImageSpec(new)) => {
      let layout_changed = old.size != new.size
      let paint_changed = old.source != new.source ||
        old.opacity != new.opacity ||
        old.corner_radius != new.corner_radius ||
        old.fit != new.fit
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (CheckboxSpec(old), CheckboxSpec(new)) => {
      let layout_changed = old.label != new.label ||
        old.font != new.font ||
        old.size != new.size
      let paint_changed = old.checked.get() != new.checked.get() ||
        old.foreground != new.foreground ||
        old.check_color != new.check_color
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (PickerSpec(old), PickerSpec(new)) => {
      let layout_changed = !picker_items_equal(old.items, new.items) ||
        old.placeholder != new.placeholder ||
        old.font != new.font ||
        old.maxHeight != new.maxHeight
      let paint_changed = old.selected.get() != new.selected.get() ||
        old.foreground != new.foreground ||
        old.background != new.background ||
        old.cornerRadius != new.cornerRadius
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (DatePickerSpec(old), DatePickerSpec(new)) => {
      let layout_changed = old.mode != new.mode ||
        old.placeholder != new.placeholder ||
        old.font != new.font ||
        old.min_date != new.min_date ||
        old.max_date != new.max_date
      let paint_changed = old.selected.get() != new.selected.get() ||
        old.foreground != new.foreground ||
        old.background != new.background ||
        old.corner_radius != new.corner_radius
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (SearchBarSpec(old), SearchBarSpec(new)) =>
      reconcile_searchbar_dirty(old, new)
    (SheetSpec(old), SheetSpec(new)) => {
      let layout_changed = old.presentation_mode != new.presentation_mode
      let paint_changed = old.background != new.background ||
        old.corner_radius != new.corner_radius ||
        old.shadow != new.shadow
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (FlexSpec(old), FlexSpec(new)) =>
      bool_dirty(
        old.axis != new.axis ||
        old.spacing != new.spacing ||
        old.main_axis_alignment != new.main_axis_alignment ||
        old.cross_axis_alignment != new.cross_axis_alignment,
        ReconcileLayout,
      )
    (PaddingSpec(old), PaddingSpec(new)) =>
      bool_dirty(old.insets != new.insets, ReconcileLayout)
    (ContainerSpec(old), ContainerSpec(new)) => {
      let layout_changed = old.size != new.size
      let paint_changed = old.background != new.background ||
        old.border != new.border ||
        old.corner_radius != new.corner_radius ||
        old.shadow != new.shadow
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (SpacerSpec(old), SpacerSpec(new)) =>
      bool_dirty(
        old.min_length != new.min_length || old.weight != new.weight,
        ReconcileLayout,
      )
    (FrameSpec(old), FrameSpec(new)) =>
      bool_dirty(
        old.width != new.width ||
        old.height != new.height ||
        old.min_width != new.min_width ||
        old.min_height != new.min_height ||
        old.max_width != new.max_width ||
        old.max_height != new.max_height,
        ReconcileLayout,
      )
    (StackSpec(_), StackSpec(_)) => ReconcileClean
    (ScrollSpec(old), ScrollSpec(new)) =>
      bool_dirty(
        old.offset != new.offset || old.viewport != new.viewport,
        ReconcileLayout,
      )
    (GridSpec(old), GridSpec(new)) =>
      bool_dirty(
        old.columns != new.columns ||
        old.row_spacing != new.row_spacing ||
        old.column_spacing != new.column_spacing,
        ReconcileLayout,
      )
    (ListSpec(old), ListSpec(new)) =>
      bool_dirty(old.spacing != new.spacing, ReconcileLayout)
    (ModifiedSpec(old), ModifiedSpec(new)) =>
      old.modifier.reconcile_dirty_kind(new.modifier)
    (CustomSpec(_), CustomSpec(_)) => ReconcileLayout
    (CustomLayoutSpec(_), CustomLayoutSpec(_)) => ReconcileLayout
    (ComponentSpec(_), ComponentSpec(_)) => ReconcileClean
    _ => ReconcileLayout
  }
}

///|
fn reconcile_text_field_dirty(
  old : TextFieldViewSpec,
  new : TextFieldViewSpec,
) -> ReconcileDirtyKind {
  let layout_changed = old.value.get() != new.value.get() ||
    old.placeholder != new.placeholder ||
    old.size != new.size ||
    old.font != new.font
  let paint_changed = old.foreground != new.foreground ||
    old.placeholder_color != new.placeholder_color ||
    old.background != new.background ||
    old.border != new.border ||
    old.focused_border != new.focused_border ||
    old.cursor_color != new.cursor_color ||
    old.corner_radius != new.corner_radius
  combine_dirty(
    bool_dirty(layout_changed, ReconcileLayout),
    bool_dirty(paint_changed, ReconcilePaint),
  )
}

///|
fn reconcile_rich_text_editor_dirty(
  old : RichTextEditorViewSpec,
  new : RichTextEditorViewSpec,
) -> ReconcileDirtyKind {
  let layout_changed = old.value.get() != new.value.get() ||
    old.placeholder != new.placeholder ||
    old.size != new.size ||
    old.font != new.font ||
    old.accepts_tab_input != new.accepts_tab_input
  let paint_changed = old.foreground != new.foreground ||
    old.placeholder_color != new.placeholder_color ||
    old.background != new.background ||
    old.border != new.border ||
    old.focused_border != new.focused_border ||
    old.cursor_color != new.cursor_color ||
    old.corner_radius != new.corner_radius
  combine_dirty(
    bool_dirty(layout_changed, ReconcileLayout),
    bool_dirty(paint_changed, ReconcilePaint),
  )
}

///|
fn reconcile_searchbar_dirty(
  old : SearchBarViewSpec,
  new : SearchBarViewSpec,
) -> ReconcileDirtyKind {
  let layout_changed = old.query.get() != new.query.get() ||
    old.placeholder != new.placeholder ||
    old.font != new.font
  let paint_changed = old.foreground != new.foreground ||
    old.placeholder_color != new.placeholder_color ||
    old.background != new.background ||
    old.border != new.border ||
    old.focused_border != new.focused_border ||
    old.cursor_color != new.cursor_color ||
    old.corner_radius != new.corner_radius
  combine_dirty(
    bool_dirty(layout_changed, ReconcileLayout),
    bool_dirty(paint_changed, ReconcilePaint),
  )
}

///|
fn picker_items_equal(old : Array[PickerItem], new : Array[PickerItem]) -> Bool {
  if old.length() != new.length() {
    false
  } else {
    for index, item in old {
      let next = new[index]
      if item.id != next.id || item.label != next.label {
        return false
      }
    }
    true
  }
}

///|
fn frame_modifier_equal(
  old : FrameModifierSpec,
  new : FrameModifierSpec,
) -> Bool {
  old.width == new.width &&
  old.height == new.height &&
  old.min_width == new.min_width &&
  old.min_height == new.min_height &&
  old.max_width == new.max_width &&
  old.max_height == new.max_height
}

///|
fn ViewModifier::reconcile_dirty_kind(
  self : ViewModifier,
  next : ViewModifier,
) -> ReconcileDirtyKind {
  match (self, next) {
    (PaddingModifier(old), PaddingModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (FrameModifier(old), FrameModifier(new)) =>
      bool_dirty(!frame_modifier_equal(old, new), ReconcileLayout)
    (BackgroundModifier(old), BackgroundModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (ForegroundModifier(old), ForegroundModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (FontModifier(old), FontModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (CornerRadiusModifier(old), CornerRadiusModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (OpacityModifier(old), OpacityModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (ShadowModifier(old), ShadowModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (BorderModifier(old), BorderModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (OffsetModifier(old_x, old_y), OffsetModifier(new_x, new_y)) =>
      bool_dirty(old_x != new_x || old_y != new_y, ReconcileLayout)
    (ClipModifier, ClipModifier) => ReconcileClean
    (ScaleModifier(old_x, old_y), ScaleModifier(new_x, new_y)) =>
      bool_dirty(old_x != new_x || old_y != new_y, ReconcilePaint)
    (DisabledModifier(old), DisabledModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (AccessibilityLabelModifier(old), AccessibilityLabelModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsRoleModifier(old), SemanticsRoleModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsSelectedModifier(old), SemanticsSelectedModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsPressedModifier(old), SemanticsPressedModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsCheckedModifier(old), SemanticsCheckedModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsExpandedModifier(old), SemanticsExpandedModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsInvalidModifier(old), SemanticsInvalidModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsRequiredModifier(old), SemanticsRequiredModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsDescriptionModifier(old), SemanticsDescriptionModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsActionModifier(old), SemanticsActionModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (FocusableModifier(old), FocusableModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (FocusTrapModifier(old), FocusTrapModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (OnTapModifier(_), OnTapModifier(_)) => ReconcileClean
    (OnLongPressModifier(_), OnLongPressModifier(_)) => ReconcileClean
    (OnDoubleTapModifier(_), OnDoubleTapModifier(_)) => ReconcileClean
    (OnDragModifier(_), OnDragModifier(_)) => ReconcileClean
    (OnDragWithFrameModifier(_), OnDragWithFrameModifier(_)) => ReconcileClean
    (OnFileDropModifier(_), OnFileDropModifier(_)) => ReconcileClean
    (KeyboardShortcutModifier(old), KeyboardShortcutModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (FlexibleModifier(old), FlexibleModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (LayoutPriorityModifier(old), LayoutPriorityModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (AlignModifier(old), AlignModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (AspectRatioModifier(old), AspectRatioModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (IntrinsicWidthModifier, IntrinsicWidthModifier) => ReconcileClean
    (IntrinsicHeightModifier, IntrinsicHeightModifier) => ReconcileClean
    (RepaintBoundaryModifier, RepaintBoundaryModifier) => ReconcileClean
    _ => ReconcileLayout
  }
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
  let mut dirty_kind = ReconcileDirtyKind::ReconcileClean
  if self.dirty.needs_build {
    match self.spec {
      ComponentSpec(data) => {
        let built = build_component_spec(
          data.component,
          runtime,
          self.id,
          self.component.component_subscriptions,
          self.component.component_effects,
        )
        self.component.component_subscriptions = built.subscriptions
        self.component.component_effects = built.effects
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
          {
            node: mounted.node,
            next_id: mounted.next_id,
            dirty_kind: ReconcileDirtyKind::ReconcileLayout,
          }
        }
        self.children = [result.node]
        next = result.next_id
        dirty_kind = dirty_kind.combine(result.dirty_kind)
      }
      _ => ()
    }
    self.dirty.needs_build = false
    self.apply_reconcile_dirty(dirty_kind)
  }
  let children : Array[ElementNode] = []
  for child in self.children {
    let result = child.rebuild_dirty_components(runtime, next)
    children.push(result.node)
    next = result.next_id
    dirty_kind = dirty_kind.combine(result.dirty_kind)
  }
  self.children = children
  { node: self, next_id: next, dirty_kind }
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
fn ElementNode::view_tree_inspector_snapshot(
  self : ElementNode,
) -> ViewTreeInspectorSnapshot {
  let nodes : Array[ViewNodeInspectorSummary] = []
  self.collect_view_node_summaries(nodes)
  {
    root_kind: self.spec.inspector_kind_label(),
    node_count: nodes.length(),
    component_count: self.inspector_component_count(),
    control_count: self.inspector_control_count(),
    modified_count: self.inspector_modified_count(),
    dirty_build_count: nodes.filter(node => node.needs_build).length(),
    dirty_layout_count: nodes.filter(node => node.needs_layout).length(),
    dirty_paint_count: nodes.filter(node => node.needs_paint).length(),
    nodes,
  }
}

///|
fn ElementNode::collect_view_node_summaries(
  self : ElementNode,
  nodes : Array[ViewNodeInspectorSummary],
) -> Unit {
  nodes.push({
    element_id: self.id,
    kind: self.spec.inspector_kind_label(),
    key: match self.key {
      Some(key) => key.value
      None => ""
    },
    child_count: self.children.length(),
    needs_build: self.dirty.needs_build,
    needs_layout: self.dirty.needs_layout,
    needs_paint: self.dirty.needs_paint,
  })
  for child in self.children {
    child.collect_view_node_summaries(nodes)
  }
}

///|
fn ElementNode::inspector_component_count(self : ElementNode) -> Int {
  let mut count = if self.spec is ComponentSpec(_) { 1 } else { 0 }
  for child in self.children {
    count = count + child.inspector_component_count()
  }
  count
}

///|
fn ElementNode::inspector_control_count(self : ElementNode) -> Int {
  let mut count = if self.spec.inspector_is_control() { 1 } else { 0 }
  for child in self.children {
    count = count + child.inspector_control_count()
  }
  count
}

///|
fn ElementNode::inspector_modified_count(self : ElementNode) -> Int {
  let mut count = if self.spec is ModifiedSpec(_) { 1 } else { 0 }
  for child in self.children {
    count = count + child.inspector_modified_count()
  }
  count
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
    self.render_cache.clear()
    true
  } else {
    let mut found = false
    for child in self.children {
      found = child.mark_paint_dirty_by_id(id) || found
    }
    if found {
      self.dirty.mark_paint()
      self.render_cache.clear()
    }
    found
  }
}

///|
fn ElementNode::collect_dirty_element_ids_by_kind(
  self : ElementNode,
  all_ids : Array[ElementId],
  build_ids : Array[ElementId],
  layout_ids : Array[ElementId],
  paint_ids : Array[ElementId],
) -> Unit {
  if self.dirty.needs_build || self.dirty.needs_layout || self.dirty.needs_paint {
    push_unique_element_id(all_ids, self.id)
  }
  if self.dirty.needs_build {
    push_unique_element_id(build_ids, self.id)
  }
  if self.dirty.needs_layout {
    push_unique_element_id(layout_ids, self.id)
  }
  if self.dirty.needs_paint {
    push_unique_element_id(paint_ids, self.id)
  }
  for child in self.children {
    child.collect_dirty_element_ids_by_kind(
      all_ids, build_ids, layout_ids, paint_ids,
    )
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
fn ElementNode::cancel_component_tree_subscriptions(
  self : ElementNode,
  reason? : ComponentEffectCancelReason = ComponentEffectCancelReason::EffectUnmounted,
) -> Unit {
  self.cancel_component_subscriptions()
  self.cancel_component_effects(reason~)
  for child in self.children {
    child.cancel_component_tree_subscriptions(reason~)
  }
}

///|
fn ElementNode::cancel_component_subscriptions(self : ElementNode) -> Unit {
  for subscription in self.component.component_subscriptions {
    subscription.cancel()
  }
  self.component.component_subscriptions.clear()
}

///|
fn ElementNode::cancel_component_effects(
  self : ElementNode,
  reason~ : ComponentEffectCancelReason,
) -> Unit {
  cancel_component_effects(self.component.component_effects, reason~)
  self.component.component_effects.clear()
}

///|
fn ElementNode::clear_cached_layout_and_paint(self : ElementNode) -> Unit {
  self.layout_cache.clear()
  self.render_cache.clear()
}
