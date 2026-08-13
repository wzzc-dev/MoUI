///|
priv struct SemanticsBuildContext {
  nodes : Map[SemanticsNodeId, SemanticsNode]
  routes : Map[SemanticsNodeId, SemanticsNodeRoute]
  relation_declarations : Map[SemanticsNodeId, SemanticsRelationsDeclaration]
  mut next_focus_order : Int
}

///|
fn SemanticsBuildContext::from_tree(
  tree : SemanticsTree,
) -> SemanticsBuildContext {
  {
    nodes: tree.nodes.copy(),
    routes: tree.routes.copy(),
    relation_declarations: tree.relation_declarations.copy(),
    next_focus_order: 0,
  }
}

///|
fn SemanticsBuildContext::put(
  self : SemanticsBuildContext,
  node : SemanticsNode,
  route : SemanticsNodeRoute,
) -> Unit {
  self.nodes[node.node_id] = node
  self.routes[node.node_id] = route
}

///|
fn SemanticsBuildContext::put_relation_declaration(
  self : SemanticsBuildContext,
  node_id : SemanticsNodeId,
  declaration : SemanticsRelationsDeclaration?,
) -> Unit {
  match declaration {
    Some(value) => self.relation_declarations[node_id] = value
    None => self.relation_declarations.remove(node_id) |> ignore
  }
}

///|
fn SemanticsBuildContext::node(
  self : SemanticsBuildContext,
  id : SemanticsNodeId,
) -> SemanticsNode? {
  self.nodes.get(id)
}

///|
fn clone_semantic_action_route(
  route : SemanticActionRoute,
) -> SemanticActionRoute {
  {
    kind: route.kind,
    element: route.element,
    layout: route.layout,
    environment: route.environment,
    style: route.style,
  }
}

///|
fn clone_semantics_node_route(route : SemanticsNodeRoute) -> SemanticsNodeRoute {
  {
    focus_element: route.focus_element,
    actions: route.actions.map(clone_semantic_action_route),
  }
}

///|
fn ElementSemanticsCache::matches(
  self : ElementSemanticsCache,
  frame : Rect,
  environment : Environment,
  style : ViewStyle,
) -> Bool {
  self.frame == Some(frame) &&
  self.environment == Some(environment) &&
  self.style == Some(style)
}

///|
fn ElementSemanticsCache::can_replay(
  self : ElementSemanticsCache,
  context : SemanticsBuildContext,
  frame : Rect,
  environment : Environment,
  style : ViewStyle,
) -> Bool {
  if !self.matches(frame, environment, style) {
    return false
  }
  self.roots.all(root => context.nodes.contains(root))
}

///|
fn ElementSemanticsCache::replay(
  self : ElementSemanticsCache,
) -> Array[SemanticsNodeId] {
  self.roots.copy()
}

///|
fn ElementSemanticsCache::capture(
  self : ElementSemanticsCache,
  roots : Array[SemanticsNodeId],
  frame : Rect,
  environment : Environment,
  style : ViewStyle,
) -> Unit {
  self.frame = Some(frame)
  self.environment = Some(environment)
  self.style = Some(style)
  self.roots.clear()
  self.roots.append(roots)
}

///|
let semantics_uint64_max : UInt64 = 18446744073709551615UL

///|
fn RuntimeState::semantics_node_id_for_element(
  self : RuntimeState,
  element : ElementNode,
) -> SemanticsNodeId {
  match element.semantics_node_id {
    Some(id) => id
    None => {
      if self.semantics.next_semantics_node_id == 0UL ||
        self.semantics.next_semantics_node_id == semantics_uint64_max {
        // Exhausting a session identity space is terminal. Closing preserves
        // the stronger invariant that node IDs never wrap to zero or repeat.
        self.closed = true
        return SemanticsNodeId::new(0UL)
      }
      let id = SemanticsNodeId::new(self.semantics.next_semantics_node_id)
      self.semantics.next_semantics_node_id = self.semantics.next_semantics_node_id +
        1UL
      element.semantics_node_id = Some(id)
      id
    }
  }
}

///|
fn append_action_kind(
  actions : Array[SemanticsActionKind],
  kind : SemanticsActionKind,
) -> Unit {
  if !actions.contains(kind) {
    actions.push(kind)
  }
}

///|
fn join_semantics_text(left : String, right : String) -> String {
  if left == "" {
    right
  } else if right == "" || left == right {
    left
  } else {
    "\{left} \{right}"
  }
}

///|
fn ViewSemanticsInfo::has_overlay(self : ViewSemanticsInfo) -> Bool {
  self.semantic_id is Some(_) ||
  self.role is Some(_) ||
  self.level is Some(_) ||
  self.url is Some(_) ||
  self.label is Some(_) ||
  self.value is Some(_) ||
  self.description is Some(_) ||
  self.disabled is Some(_) ||
  self.selected is Some(_) ||
  self.pressed is Some(_) ||
  self.checked is Some(_) ||
  self.expanded is Some(_) ||
  self.invalid is Some(_) ||
  self.required is Some(_) ||
  self.read_only is Some(_) ||
  self.busy is Some(_) ||
  self.multiline is Some(_) ||
  self.password is Some(_) ||
  self.modal is Some(_) ||
  self.numeric is Some(_) ||
  self.text is Some(_) ||
  self.collection is Some(_) ||
  self.relations is Some(_) ||
  self.live is Some(_) ||
  self.live_atomic is Some(_)
}

///|
fn semantics_state_for_element(
  element : ElementNode,
  info : ViewSemanticsInfo,
  focused : Bool,
  environment : Environment,
) -> SemanticsState {
  let state = element.control.view_state
  {
    focused,
    disabled: info.disabled.unwrap_or(state.disabled || !environment.enabled),
    selected: info.selected.unwrap_or(state.selected),
    pressed: info.pressed.unwrap_or(state.pressed),
    checked: match info.checked {
      Some(value) => Some(value)
      None =>
        match info.role {
          Some(Checkbox | Switch | Radio) =>
            Some(
              if state.checked {
                SemanticsCheckedState::Checked
              } else {
                SemanticsCheckedState::Unchecked
              },
            )
          _ => None
        }
    },
    expanded: info.expanded.unwrap_or(state.expanded),
    invalid: info.invalid.unwrap_or(false),
    required: info.required.unwrap_or(false),
    read_only: info.read_only.unwrap_or(false),
    busy: info.busy.unwrap_or(false),
    multiline: info.multiline.unwrap_or(false),
    password: info.password.unwrap_or(false),
    modal: info.modal.unwrap_or(false),
  }
}

///|
fn RuntimeState::route_for_element(
  _self : RuntimeState,
  context : SemanticsBuildContext,
  element : ElementNode,
  layout : PlacedNode,
  environment : Environment,
  style : ViewStyle,
) -> SemanticsNodeRoute {
  let kinds = element.view_node.semantics_action_kinds()
  let actions : Array[SemanticActionRoute] = []
  for kind in kinds {
    if kind != SemanticsActionKind::Focus {
      actions.push({ kind, element, layout, environment, style })
    }
  }
  let focus_element = if kinds.contains(SemanticsActionKind::Focus) {
    Some(element.id)
  } else {
    None
  }
  if focus_element is Some(_) {
    context.next_focus_order = context.next_focus_order + 1
  }
  { focus_element, actions }
}

///|
fn RuntimeState::boundary_node(
  self : RuntimeState,
  context : SemanticsBuildContext,
  element : ElementNode,
  layout : PlacedNode,
  info : ViewSemanticsInfo,
  children : Array[SemanticsNodeId],
  environment : Environment,
  style : ViewStyle,
) -> SemanticsNodeId {
  let id = self.semantics_node_id_for_element(element)
  let route = self.route_for_element(
    context, element, layout, environment, style,
  )
  let focus_order = match route.focus_element {
    Some(_) => Some(context.next_focus_order - 1)
    None => None
  }
  let node : SemanticsNode = {
    node_id: id,
    semantic_id: info.semantic_id,
    role: info.role.unwrap_or(SemanticsRole::Group),
    level: info.level,
    url: info.url.unwrap_or(""),
    label: info.label.unwrap_or(""),
    value: info.value.unwrap_or(""),
    description: info.description.unwrap_or(""),
    state: semantics_state_for_element(
      element,
      info,
      self.animfocus.focused_element == Some(element.id),
      environment,
    ),
    numeric: info.numeric,
    text: match info.text {
      Some(text) =>
        Some({
          ..text,
          selection: element.control.selection,
          caret: Some(element.control.caret),
        })
      None => None
    },
    collection: info.collection,
    relations: SemanticsRelations::empty(),
    live: info.live.unwrap_or(SemanticsLive::Off),
    live_atomic: info.live_atomic.unwrap_or(false),
    actions: element.view_node.semantics_action_kinds(),
    focus_order,
    frame: layout.frame,
    children,
  }
  context.put(node, route)
  context.put_relation_declaration(id, info.relations)
  id
}

///|
fn overlay_state(
  current : SemanticsState,
  info : ViewSemanticsInfo,
  element_focused : Bool,
  environment : Environment,
) -> SemanticsState {
  {
    focused: current.focused || element_focused,
    disabled: info.disabled.unwrap_or(current.disabled || !environment.enabled),
    selected: info.selected.unwrap_or(current.selected),
    pressed: info.pressed.unwrap_or(current.pressed),
    checked: match info.checked {
      Some(value) => Some(value)
      None => current.checked
    },
    expanded: info.expanded.unwrap_or(current.expanded),
    invalid: info.invalid.unwrap_or(current.invalid),
    required: info.required.unwrap_or(current.required),
    read_only: info.read_only.unwrap_or(current.read_only),
    busy: info.busy.unwrap_or(current.busy),
    multiline: info.multiline.unwrap_or(current.multiline),
    password: info.password.unwrap_or(current.password),
    modal: info.modal.unwrap_or(current.modal),
  }
}

///|
fn RuntimeState::apply_semantics_overlay(
  self : RuntimeState,
  context : SemanticsBuildContext,
  target : SemanticsNodeId,
  element : ElementNode,
  layout : PlacedNode,
  info : ViewSemanticsInfo,
  environment : Environment,
  style : ViewStyle,
) -> Unit {
  guard context.node(target) is Some(current) else { return }
  let overlay_route = self.route_for_element(
    context, element, layout, environment, style,
  )
  let route = context.routes
    .get(target)
    .map(clone_semantics_node_route)
    .unwrap_or({ focus_element: None, actions: [] })
  match overlay_route.focus_element {
    Some(element_id) => route.focus_element = Some(element_id)
    None => ()
  }
  for next_route in overlay_route.actions {
    let retained = route.actions.filter(item => item.kind != next_route.kind)
    route.actions.clear()
    route.actions.append(retained)
    route.actions.push(next_route)
  }
  let actions = current.actions.copy()
  for kind in element.view_node.semantics_action_kinds() {
    append_action_kind(actions, kind)
  }
  let focus_order = if current.focus_order is None &&
    overlay_route.focus_element is Some(_) {
    Some(context.next_focus_order - 1)
  } else {
    current.focus_order
  }
  context.put(
    {
      ..current,
      semantic_id: match info.semantic_id {
        Some(id) => Some(id)
        None => current.semantic_id
      },
      role: info.role.unwrap_or(current.role),
      level: match info.level {
        Some(level) => Some(level)
        None => current.level
      },
      url: info.url.unwrap_or(current.url),
      label: info.label.unwrap_or(current.label),
      value: info.value.unwrap_or(current.value),
      description: info.description.unwrap_or(current.description),
      numeric: match info.numeric {
        Some(value) => Some(value)
        None => current.numeric
      },
      text: match info.text {
        Some(value) =>
          Some({
            ..value,
            selection: element.control.selection,
            caret: Some(element.control.caret),
          })
        None => current.text
      },
      collection: match info.collection {
        Some(value) => Some(value)
        None => current.collection
      },
      live: info.live.unwrap_or(current.live),
      live_atomic: info.live_atomic.unwrap_or(current.live_atomic),
      state: overlay_state(
        current.state,
        info,
        self.animfocus.focused_element == Some(element.id),
        environment,
      ),
      actions,
      focus_order,
    },
    route,
  )
  match info.relations {
    Some(relations) => context.put_relation_declaration(target, Some(relations))
    None => ()
  }
}

///|
fn SemanticsBuildContext::collect_reachable_ids(
  self : SemanticsBuildContext,
  root : SemanticsNodeId,
  seen : Map[SemanticsNodeId, Bool],
  output : Array[SemanticsNodeId],
) -> Unit {
  if seen.contains(root) {
    return
  }
  seen[root] = true
  output.push(root)
  match self.node(root) {
    Some(node) =>
      for child in node.children {
        self.collect_reachable_ids(child, seen, output)
      }
    None => ()
  }
}

///|
fn RuntimeState::merged_boundary_node(
  self : RuntimeState,
  context : SemanticsBuildContext,
  element : ElementNode,
  layout : PlacedNode,
  info : ViewSemanticsInfo,
  descendant_roots : Array[SemanticsNodeId],
  environment : Environment,
  style : ViewStyle,
) -> SemanticsNodeId {
  let id = self.boundary_node(
    context,
    element,
    layout,
    info,
    [],
    environment,
    style,
  )
  guard context.node(id) is Some(own) else { return id }
  let merged_actions = own.actions.copy()
  let merged_route = context.routes.get(id).unwrap()
  let descendant_ids : Array[SemanticsNodeId] = []
  let seen : Map[SemanticsNodeId, Bool] = Map([])
  for root in descendant_roots {
    context.collect_reachable_ids(root, seen, descendant_ids)
  }
  let mut label = own.label
  let mut value = own.value
  let mut description = own.description
  let mut state = own.state
  let mut focus_order = own.focus_order
  for descendant_id in descendant_ids {
    match context.node(descendant_id) {
      Some(descendant) => {
        label = join_semantics_text(label, descendant.label)
        value = join_semantics_text(value, descendant.value)
        description = join_semantics_text(description, descendant.description)
        state = {
          focused: state.focused || descendant.state.focused,
          disabled: state.disabled || descendant.state.disabled,
          selected: state.selected || descendant.state.selected,
          pressed: state.pressed || descendant.state.pressed,
          checked: match (state.checked, descendant.state.checked) {
            (None, next) => next
            (current, None) => current
            (Some(current), Some(next)) =>
              if current == next {
                Some(current)
              } else {
                Some(SemanticsCheckedState::Mixed)
              }
          },
          expanded: state.expanded || descendant.state.expanded,
          invalid: state.invalid || descendant.state.invalid,
          required: state.required || descendant.state.required,
          read_only: state.read_only || descendant.state.read_only,
          busy: state.busy || descendant.state.busy,
          multiline: state.multiline || descendant.state.multiline,
          password: state.password || descendant.state.password,
          modal: state.modal || descendant.state.modal,
        }
        for kind in descendant.actions {
          append_action_kind(merged_actions, kind)
        }
        match context.routes.get(descendant_id) {
          Some(route) => {
            if merged_route.focus_element is None {
              merged_route.focus_element = route.focus_element
            }
            for action_route in route.actions {
              if !merged_route.actions.any(item => {
                  item.kind == action_route.kind
                }) {
                merged_route.actions.push(action_route)
              }
            }
          }
          None => ()
        }
        match (focus_order, descendant.focus_order) {
          (None, Some(order)) => focus_order = Some(order)
          _ => ()
        }
      }
      None => ()
    }
  }
  context.put(
    {
      ..own,
      label,
      value,
      description,
      state,
      actions: merged_actions,
      focus_order,
      children: [],
    },
    merged_route,
  )
  id
}

///|
fn RuntimeState::build_semantics_for_element(
  self : RuntimeState,
  context : SemanticsBuildContext,
  element : ElementNode,
  layout : PlacedNode,
  environment : Environment,
  style : ViewStyle,
) -> Array[SemanticsNodeId] {
  if !element.has_dirty_semantics() &&
    element.semantics_cache.can_replay(
      context,
      layout.frame,
      environment,
      style,
    ) {
    return element.semantics_cache.replay()
  }
  self.stats.semantics_recompute_count = self.stats.semantics_recompute_count +
    1
  let info = element.view_node.semantics()
  let roots : Array[SemanticsNodeId] = if info.composition ==
    SemanticsComposition::Hidden {
    for child in element.children {
      child.invalidate_uncommitted_semantics()
    }
    []
  } else {
    let child_environment = element.view_node.child_environment(environment)
    let child_style = element.view_node.child_style(style)
    let child_roots : Array[SemanticsNodeId] = []
    for index, child in element.children {
      if index < layout.children.length() {
        child_roots.append(
          self.build_semantics_for_element(
            context,
            child,
            layout.children[index],
            child_environment,
            child_style,
          ),
        )
      }
    }
    match info.composition {
      Hidden => []
      Boundary =>
        [
          self.boundary_node(
            context, element, layout, info, child_roots, environment, style,
          ),
        ]
      MergeDescendants => {
        let merged = self.merged_boundary_node(
          context, element, layout, info, child_roots, environment, style,
        )
        for child in element.children {
          child.invalidate_uncommitted_semantics()
        }
        [merged]
      }
      Transparent => {
        let contributes = info.has_overlay() ||
          !element.view_node.semantics_action_kinds().is_empty()
        if !contributes {
          child_roots
        } else if child_roots.length() == 1 {
          self.apply_semantics_overlay(
            context,
            child_roots[0],
            element,
            layout,
            info,
            environment,
            style,
          )
          child_roots
        } else {
          [
            self.boundary_node(
              context, element, layout, info, child_roots, environment, style,
            ),
          ]
        }
      }
    }
  }
  element.semantics_cache.capture(roots, layout.frame, environment, style)
  element.dirty.needs_semantics = false
  element.refresh_descendant_dirty_flags()
  if info.composition == SemanticsComposition::Hidden ||
    info.composition == SemanticsComposition::MergeDescendants {
    element.dirty.descendant_semantics = false
  }
  roots
}

///|
fn SemanticsBuildContext::collect_dfs(
  self : SemanticsBuildContext,
  id : SemanticsNodeId,
  seen : Map[SemanticsNodeId, Bool],
  output : Array[SemanticsNode],
) -> Unit {
  if seen.contains(id) {
    return
  }
  seen[id] = true
  match self.node(id) {
    Some(node) => {
      output.push(node)
      for child in node.children {
        self.collect_dfs(child, seen, output)
      }
    }
    None => ()
  }
}

///|
/// Returns the deepest modal boundary; later siblings win equal-depth ties.
fn deepest_modal_semantics_node_at(
  nodes : Map[SemanticsNodeId, SemanticsNode],
  id : SemanticsNodeId,
  depth : Int,
) -> (SemanticsNodeId, Int)? {
  guard nodes.get(id) is Some(node) else { return None }
  let mut best = if node.state.modal { Some((id, depth)) } else { None }
  for child in node.children {
    match deepest_modal_semantics_node_at(nodes, child, depth + 1) {
      Some(candidate) =>
        match best {
          Some(current) =>
            if candidate.1 >= current.1 {
              best = Some(candidate)
            }
          None => best = Some(candidate)
        }
      None => ()
    }
  }
  best
}

///|
fn deepest_modal_semantics_node(
  nodes : Array[SemanticsNode],
) -> SemanticsNodeId? {
  guard nodes.get(0) is Some(root) else { return None }
  let index : Map[SemanticsNodeId, SemanticsNode] = Map([])
  for node in nodes {
    index[node.node_id] = node
  }
  deepest_modal_semantics_node_at(index, root.node_id, 0).map(result => result.0)
}

///|
fn assign_semantics_focus_order(nodes : Array[SemanticsNode]) -> Unit {
  let mut next_order = 0
  for index, node in nodes {
    if node.actions.contains(SemanticsActionKind::Focus) {
      nodes[index] = { ..node, focus_order: Some(next_order) }
      next_order = next_order + 1
    } else if node.focus_order is Some(_) {
      nodes[index] = { ..node, focus_order: None }
    }
  }
}

///|
fn resolve_semantics_relation_targets(
  source : SemanticsNodeId,
  kind : SemanticsRelationKind,
  targets : Array[SemanticId],
  occurrences : Map[SemanticId, Array[SemanticsNodeId]],
  resolved : Array[SemanticsNodeId],
  issues : Array[SemanticsIssue],
) -> Unit {
  for target in targets {
    match occurrences.get(target) {
      Some(ids) =>
        if ids.length() == 1 {
          if !resolved.contains(ids[0]) {
            resolved.push(ids[0])
          }
        } else {
          issues.push(AmbiguousRelationTarget(source, kind, target, ids.copy()))
        }
      None => issues.push(MissingRelationTarget(source, kind, target))
    }
  }
}

///|
/// Resolves stable declaration relations after the entire tree is known.
fn resolve_semantics_relations_and_issues(
  nodes : Array[SemanticsNode],
  declarations : Map[SemanticsNodeId, SemanticsRelationsDeclaration],
) -> Array[SemanticsIssue] {
  let occurrences : Map[SemanticId, Array[SemanticsNodeId]] = Map([])
  for node in nodes {
    match node.semantic_id {
      Some(id) =>
        match occurrences.get(id) {
          Some(existing) => existing.push(node.node_id)
          None => occurrences[id] = [node.node_id]
        }
      None => ()
    }
  }
  let emitted : Map[SemanticId, Bool] = Map([])
  let issues : Array[SemanticsIssue] = []
  for node in nodes {
    match node.semantic_id {
      Some(id) =>
        if !emitted.contains(id) {
          emitted[id] = true
          match occurrences.get(id) {
            Some(ids) =>
              if ids.length() > 1 {
                issues.push(DuplicateSemanticId(id, ids.copy()))
              }
            None => ()
          }
        }
      None => ()
    }
  }
  for index, node in nodes {
    match declarations.get(node.node_id) {
      Some(declaration) => {
        let relations = SemanticsRelations::empty()
        resolve_semantics_relation_targets(
          node.node_id,
          SemanticsRelationKind::LabelledBy,
          declaration.labelled_by,
          occurrences,
          relations.labelled_by,
          issues,
        )
        resolve_semantics_relation_targets(
          node.node_id,
          SemanticsRelationKind::DescribedBy,
          declaration.described_by,
          occurrences,
          relations.described_by,
          issues,
        )
        resolve_semantics_relation_targets(
          node.node_id,
          SemanticsRelationKind::Controls,
          declaration.controls,
          occurrences,
          relations.controls,
          issues,
        )
        resolve_semantics_relation_targets(
          node.node_id,
          SemanticsRelationKind::ErrorMessage,
          declaration.error_message,
          occurrences,
          relations.error_message,
          issues,
        )
        resolve_semantics_relation_targets(
          node.node_id,
          SemanticsRelationKind::ActiveDescendant,
          declaration.active_descendant,
          occurrences,
          relations.active_descendant,
          issues,
        )
        nodes[index] = { ..node, relations, }
      }
      None => ()
    }
  }
  issues
}

///|
fn semantics_same_public_content(
  snapshot : SemanticsSnapshot,
  root : SemanticsNodeId?,
  focused : SemanticsNodeId?,
  semantic_focused : SemanticsNodeId?,
  nodes : Array[SemanticsNode],
  issues : Array[SemanticsIssue],
) -> Bool {
  snapshot.root == root &&
  snapshot.focused == focused &&
  snapshot.semantic_focused == semantic_focused &&
  snapshot.nodes == nodes &&
  snapshot.issues == issues
}

///|
fn RuntimeState::refresh_semantic_id_index(
  self : RuntimeState,
  snapshot : SemanticsSnapshot,
) -> Unit {
  self.semantics.semantic_id_index.clear()
  let occurrences : Map[SemanticId, Array[SemanticsNodeId]] = Map([])
  for node in snapshot.nodes {
    match node.semantic_id {
      Some(id) =>
        match occurrences.get(id) {
          Some(ids) => ids.push(node.node_id)
          None => occurrences[id] = [node.node_id]
        }
      None => ()
    }
  }
  occurrences.each((id, nodes) => {
    self.semantics.semantic_id_index[id] = if nodes.length() == 1 {
      Unique(nodes[0])
    } else {
      Ambiguous
    }
  })
}

///|
fn RuntimeState::commit_semantics(self : RuntimeState) -> Unit {
  if self.semantics.semantics_commit_in_progress {
    return
  }
  self.semantics.semantics_commit_in_progress = true
  self.rebuild_if_possible()
  self.ensure_layout_tree()
  if self.closed {
    self.semantics.semantics_commit_in_progress = false
    return
  }
  if self.semantics.semantics_initialized && !self.dirty.needs_semantics {
    self.dirty.dirty_semantics_elements.clear()
    self.refresh_dirty_element_queue()
    self.settle_rebuild_wakeup()
    self.semantics.semantics_commit_in_progress = false
    return
  }
  let context = SemanticsBuildContext::from_tree(self.semantics.semantics_tree)
  let roots = self.build_semantics_for_element(
    context,
    self.element_tree.root,
    self.layout_tree.root,
    self.environment,
    ViewStyle::empty(),
  )
  if self.closed {
    self.semantics.semantics_commit_in_progress = false
    return
  }
  let root = if roots.length() == 0 {
    None
  } else if roots.length() == 1 {
    Some(roots[0])
  } else {
    Some(
      self.boundary_node(
        context,
        self.element_tree.root,
        self.layout_tree.root,
        ViewSemanticsInfo::new(composition=SemanticsComposition::Boundary),
        roots,
        self.environment,
        ViewStyle::empty(),
      ),
    )
  }
  let all_nodes : Array[SemanticsNode] = []
  match root {
    Some(id) => context.collect_dfs(id, Map([]), all_nodes)
    None => ()
  }
  let root : SemanticsNodeId? = match deepest_modal_semantics_node(all_nodes) {
    Some(id) => Some(id)
    None => root
  }
  let nodes : Array[SemanticsNode] = []
  match root {
    Some(id) => context.collect_dfs(id, Map([]), nodes)
    None => ()
  }
  assign_semantics_focus_order(nodes)
  for node in nodes {
    context.nodes[node.node_id] = node
  }
  let mut focused : SemanticsNodeId? = None
  for node in nodes {
    if node.state.focused {
      focused = Some(node.node_id)
      break
    }
  }
  let semantic_focused = match self.animfocus.semantic_focused {
    Some(id) if nodes.any(node => node.node_id == id) => Some(id)
    _ => None
  }
  let issues = resolve_semantics_relations_and_issues(
    nodes,
    context.relation_declarations,
  )
  let previous = self.semantics.committed_semantics
  let changed = !semantics_same_public_content(
    previous, root, focused, semantic_focused, nodes, issues,
  )
  if changed && previous.generation.value() == semantics_uint64_max {
    // A wrapped generation could make a stale consumer look current. Stop
    // the runtime before publishing any ambiguous snapshot instead.
    self.closed = true
    self.semantics.semantics_commit_in_progress = false
    return
  }
  let generation = if changed {
    SemanticsGeneration::new(previous.generation.value() + 1UL)
  } else {
    previous.generation
  }
  let next_tree = SemanticsTree::from_reachable(
    root,
    nodes,
    context.routes,
    context.relation_declarations,
  )
  let next = {
    generation,
    root: next_tree.root,
    focused,
    semantic_focused,
    nodes,
    issues,
  }
  self.refresh_semantic_id_index(next)
  self.semantics.semantics_tree = next_tree
  self.semantics.committed_semantics = next
  self.semantics.semantics_initialized = true
  if changed {
    let delta = semantics_delta_between(previous, next)
    self.semantics.semantics_journal.push(delta)
    if self.semantics.semantics_journal.length() > 64 {
      ignore(self.semantics.semantics_journal.remove(0))
    }
  }
  self.dirty.needs_semantics = false
  self.dirty.dirty_semantics_elements.clear()
  self.refresh_dirty_element_queue()
  self.settle_rebuild_wakeup()
  self.semantics.semantics_commit_in_progress = false
}

///|
fn RuntimeState::combined_semantics_delta(
  self : RuntimeState,
  since : SemanticsGeneration,
) -> SemanticsDelta? {
  let current = self.semantics.committed_semantics
  let mut start = -1
  for index, delta in self.semantics.semantics_journal {
    if delta.from == since {
      start = index
      break
    }
  }
  if start < 0 {
    return None
  }
  let changed : Map[SemanticsNodeId, Bool] = Map([])
  let removed : Map[SemanticsNodeId, Bool] = Map([])
  let removed_order : Array[SemanticsNodeId] = []
  let mut expected = since
  let announcements : Array[AccessibilityAnnouncement] = []
  for index in start..<self.semantics.semantics_journal.length() {
    let delta = self.semantics.semantics_journal[index]
    if delta.from != expected {
      return None
    }
    for id in delta.removed {
      changed.remove(id)
      if !removed.contains(id) {
        removed_order.push(id)
      }
      removed[id] = true
    }
    for node in delta.upserted {
      removed.remove(node.node_id)
      changed[node.node_id] = true
    }
    announcements.append(delta.announcements)
    expected = delta.to
    if expected == current.generation {
      let upserted = current.nodes.filter(node => changed.contains(node.node_id))
      return Some({
        from: since,
        to: current.generation,
        root: current.root,
        focused: current.focused,
        semantic_focused: current.semantic_focused,
        upserted,
        removed: removed_order.filter(id => removed.contains(id)),
        issues: current.issues.map(clone_semantics_issue),
        announcements,
      })
    }
  }
  None
}

///|
fn RuntimeState::read_semantics(
  self : RuntimeState,
  since : SemanticsGeneration?,
) -> Result[SemanticsRead, SemanticsReadError] {
  if self.closed {
    return Err(SemanticsReadError::RuntimeClosed)
  }
  if !self.semantics.semantics_action_dispatching &&
    !self.semantics.semantics_commit_in_progress {
    self.commit_semantics()
  }
  if self.closed {
    return Err(SemanticsReadError::RuntimeClosed)
  }
  match since {
    None => Ok(Full(self.semantics.committed_semantics))
    Some(cursor) =>
      if cursor == self.semantics.committed_semantics.generation {
        Ok(Unchanged(cursor))
      } else {
        match self.combined_semantics_delta(cursor) {
          Some(delta) => Ok(Delta(delta))
          None => Ok(Full(self.semantics.committed_semantics))
        }
      }
  }
}

///|
fn RuntimeState::set_semantic_focus(
  self : RuntimeState,
  node_id : SemanticsNodeId?,
) -> Bool {
  if self.closed {
    return false
  }
  self.commit_semantics()
  match node_id {
    Some(id) if !self.semantics.semantics_tree.nodes.contains(id) => false
    _ => {
      if self.animfocus.semantic_focused != node_id {
        self.animfocus.semantic_focused = node_id
        self.dirty.needs_semantics = true
        self.dirty.needs_platform = true
        self.commit_semantics()
      }
      true
    }
  }
}

///|
fn RuntimeState::resolve_semantics_target(
  self : RuntimeState,
  target : SemanticsTarget,
) -> Result[SemanticsNodeId, SemanticsActionDispatchError] {
  match target {
    BySemanticId(id) =>
      match self.semantics.semantic_id_index.get(id) {
        Some(Unique(node_id)) => Ok(node_id)
        Some(Ambiguous) => Err(TargetAmbiguous(id))
        None => Err(TargetNotFound(target))
      }
    ByNodeId(node_id) =>
      if self.semantics.semantics_tree.nodes.contains(node_id) {
        Ok(node_id)
      } else {
        Err(TargetNotFound(target))
      }
  }
}

///|
fn semantics_action_route(
  route : SemanticsNodeRoute,
  kind : SemanticsActionKind,
) -> SemanticActionRoute? {
  for item in route.actions {
    if item.kind == kind {
      return Some(item)
    }
  }
  None
}

///|
fn RuntimeState::apply_semantics_action_outcome(
  self : RuntimeState,
  element : ElementNode,
  outcome : RuntimeSemanticsActionOutcome,
) -> Unit {
  match outcome.state {
    Some(state) => element.control.apply_view_context(state)
    None => ()
  }
  match outcome.text_control {
    Some(state) => element.control.apply_text_context(state)
    None => ()
  }
  match outcome.dirty {
    ViewBuildDirty => {
      self.mark_layout_dirty(element.id)
      self.request_root_rebuild(reason="semantics action changed view state")
    }
    ViewLayoutDirty => self.mark_layout_dirty(element.id)
    ViewPaintDirty => self.mark_dirty(element.id)
    ViewClean => ()
  }
  self.mark_semantics_dirty(element.id)
}

///|
fn RuntimeState::perform_semantics_action(
  self : RuntimeState,
  request : PerformSemanticsActionRequest,
) -> Result[SemanticsActionReceipt, SemanticsActionDispatchError] {
  if self.closed {
    return Err(SemanticsActionDispatchError::RuntimeClosed)
  }
  if self.semantics.semantics_action_dispatching {
    return Err(SemanticsActionDispatchError::ReentrantDispatch)
  }
  if self.semantics.semantics_commit_in_progress {
    return Err(SemanticsActionDispatchError::ReentrantDispatch)
  }
  self.commit_semantics()
  if self.closed {
    return Err(SemanticsActionDispatchError::RuntimeClosed)
  }
  let before = self.semantics.committed_semantics.generation
  match request.precondition {
    Exact(expected) =>
      if expected != before {
        return Err(StaleGeneration(expected, before))
      }
    Latest => ()
  }
  let node_id = match self.resolve_semantics_target(request.target) {
    Ok(node_id) => node_id
    Err(error) => return Err(error)
  }
  let node = self.semantics.semantics_tree.nodes.get(node_id).unwrap()
  let kind = request.action.kind()
  if node.state.disabled {
    return Err(TargetDisabled(request.target))
  }
  if !node.actions.contains(kind) {
    return Err(ActionUnavailable(request.target, kind))
  }
  let route = self.semantics.semantics_tree.routes
    .get(node_id)
    .unwrap_or({ focus_element: None, actions: [] })
  match request.action {
    SemanticsAction::Focus => {
      guard route.focus_element is Some(element_id) else {
        return Err(ActionUnavailable(request.target, kind))
      }
      let constrained = self.element_tree.root.constrained_focus_target(
        Some(element_id),
        current=self.animfocus.focused_element,
      )
      if constrained != Some(element_id) {
        return Err(HandlerRejected(request.target, kind))
      }
      self.semantics.semantics_action_dispatching = true
      self.discard_semantics_destroy_request()
      ignore(self.commit_focus(Some(element_id)))
    }
    _ => {
      guard semantics_action_route(route, kind) is Some(action_route) else {
        return Err(HandlerRejected(request.target, kind))
      }
      self.semantics.semantics_action_dispatching = true
      self.discard_semantics_destroy_request()
      let outcome = action_route.element.view_node.semantics_action(
        {
          frame: action_route.layout.frame,
          child_frames: action_route.layout.children.map(child => child.frame),
          focused: self.animfocus.focused_element ==
          Some(action_route.element.id),
          state: action_route.element.control.view_context(
            self.animfocus.focused_element == Some(action_route.element.id),
          ),
          text_control: action_route.element.control.text_context(),
          text_system: self.text_system,
          environment: action_route.environment,
          style: action_route.style,
        },
        request.action,
      )
      if !outcome.accepted {
        self.semantics.semantics_action_dispatching = false
        self.discard_semantics_destroy_request()
        return Err(HandlerRejected(request.target, kind))
      }
      self.apply_semantics_action_outcome(action_route.element, outcome)
      for commit in outcome.deferred_commits {
        commit()
      }
      self.deliver_messages(outcome.deliveries)
    }
  }
  self.commit_semantics()
  let receipt = {
    before,
    after: self.semantics.committed_semantics.generation,
    pending_work: self.dirty.needs_rebuild ||
    self.dirty.needs_layout ||
    self.dirty.needs_paint ||
    self.dirty.needs_semantics ||
    self.dirty.needs_platform ||
    self.dirty.needs_redraw,
  }
  self.semantics.semantics_action_dispatching = false
  if self.complete_semantics_destroy_request() {
    Ok({ ..receipt, pending_work: false })
  } else {
    Ok(receipt)
  }
}
