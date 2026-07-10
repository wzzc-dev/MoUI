///|
fn ElementNode::semantics(
  self : ElementNode,
  render : RenderNode,
  focused? : ElementId? = None,
) -> SemanticsNode {
  let next_order = Ref(0)
  self.build_semantics(render, focused, next_order)
}

///|
fn ElementNode::build_semantics(
  self : ElementNode,
  render : RenderNode,
  focused : ElementId?,
  next_order : Ref[Int],
) -> SemanticsNode {
  let info = (self.erased_view_node.semantics)()
  let actions = self.semantics_actions(info.actions)
  let focusable = actions.any(action => action == SemanticsAction::Focus)
  let focus_order = if focusable {
    let order = next_order.val
    next_order.val = next_order.val + 1
    Some(order)
  } else {
    None
  }
  let children : Array[SemanticsNode] = []
  for index, child in self.children {
    if index < render.children.length() {
      children.push(
        child.build_semantics(render.children[index], focused, next_order),
      )
    }
  }
  let state = self.semantics_state(info, children, focused)
  {
    element_id: self.id,
    role: self.semantics_role(info.role),
    level: self.semantics_level(info.level),
    url: self.semantics_url(info.url),
    label: self.semantics_label(info.label),
    value: self.semantics_value(info.value),
    description: self.semantics_description(info.description),
    state,
    actions,
    focus_order,
    frame: render.frame,
    children,
  }
}

///|
fn ElementNode::semantics_role(
  self : ElementNode,
  role : @core.SemanticsRole,
) -> @core.SemanticsRole {
  if role != @core.SemanticsRole::Group {
    role
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_role()
  } else {
    role
  }
}

///|
fn ElementNode::semantics_level(self : ElementNode, level : Int?) -> Int? {
  match level {
    Some(_) => level
    None =>
      if self.children.length() > 0 {
        self.children[0].primary_semantics_level()
      } else {
        None
      }
  }
}

///|
fn ElementNode::semantics_url(self : ElementNode, url : String) -> String {
  if url != "" {
    url
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_url()
  } else {
    ""
  }
}

///|
fn ElementNode::primary_semantics_role(
  self : ElementNode,
) -> @core.SemanticsRole {
  let info = (self.erased_view_node.semantics)()
  if info.role != @core.SemanticsRole::Group {
    info.role
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_role()
  } else {
    info.role
  }
}

///|
fn ElementNode::primary_semantics_level(self : ElementNode) -> Int? {
  let info = (self.erased_view_node.semantics)()
  match info.level {
    Some(_) => info.level
    None =>
      if self.children.length() > 0 {
        self.children[0].primary_semantics_level()
      } else {
        None
      }
  }
}

///|
fn ElementNode::primary_semantics_url(self : ElementNode) -> String {
  let info = (self.erased_view_node.semantics)()
  if info.url != "" {
    info.url
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_url()
  } else {
    ""
  }
}

///|
fn ElementNode::semantics_state(
  self : ElementNode,
  info : ViewSemanticsInfo,
  children : Array[SemanticsNode],
  focused : ElementId?,
) -> SemanticsState {
  let inherited = match children {
    [child, ..] => child.state
    [] => SemanticsState::default()
  }
  {
    focused: focused == Some(self.id),
    disabled: option_bool(
      info.disabled,
      self.erased_view_node.state.disabled || inherited.disabled,
    ),
    selected: option_bool(
      info.selected,
      self.erased_view_node.state.selected || inherited.selected,
    ),
    pressed: option_bool(
      info.pressed,
      self.erased_view_node.state.pressed || inherited.pressed,
    ),
    checked: option_bool(
      info.checked,
      self.erased_view_node.state.checked || inherited.checked,
    ),
    expanded: option_bool(
      info.expanded,
      self.erased_view_node.state.expanded || inherited.expanded,
    ),
    invalid: option_bool(info.invalid, inherited.invalid),
    required: option_bool(info.required, inherited.required),
  }
}

///|
fn ElementNode::semantics_label(self : ElementNode, label : String) -> String {
  if label != "" {
    label
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_label()
  } else {
    ""
  }
}

///|
fn ElementNode::semantics_value(self : ElementNode, value : String) -> String {
  if value != "" {
    value
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_value()
  } else {
    ""
  }
}

///|
fn ElementNode::semantics_description(
  self : ElementNode,
  description : String,
) -> String {
  if description != "" {
    description
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_description()
  } else {
    ""
  }
}

///|
fn ElementNode::semantics_actions(
  self : ElementNode,
  actions : Array[SemanticsAction],
) -> Array[SemanticsAction] {
  let merged = actions.copy()
  if self.children.length() > 0 {
    append_unique_semantics_actions(
      merged,
      self.children[0].primary_semantics_actions(),
    )
  }
  merged
}

///|
fn ElementNode::primary_semantics_label(self : ElementNode) -> String {
  let info = (self.erased_view_node.semantics)()
  if info.label != "" {
    info.label
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_label()
  } else {
    ""
  }
}

///|
fn ElementNode::primary_semantics_value(self : ElementNode) -> String {
  let info = (self.erased_view_node.semantics)()
  if info.value != "" {
    info.value
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_value()
  } else {
    ""
  }
}

///|
fn ElementNode::primary_semantics_description(self : ElementNode) -> String {
  let info = (self.erased_view_node.semantics)()
  if info.description != "" {
    info.description
  } else if self.children.length() > 0 {
    self.children[0].primary_semantics_description()
  } else {
    ""
  }
}

///|
fn ElementNode::primary_semantics_actions(
  self : ElementNode,
) -> Array[SemanticsAction] {
  let info = (self.erased_view_node.semantics)()
  let actions = info.actions.copy()
  if self.children.length() > 0 {
    append_unique_semantics_actions(
      actions,
      self.children[0].primary_semantics_actions(),
    )
  }
  actions
}

///|
fn append_unique_semantics_actions(
  target : Array[SemanticsAction],
  source : Array[SemanticsAction],
) -> Unit {
  for action in source {
    if !target.any(existing => existing == action) {
      target.push(action)
    }
  }
}

///|
fn option_bool(value : Bool?, fallback : Bool) -> Bool {
  match value {
    Some(value) => value
    None => fallback
  }
}
