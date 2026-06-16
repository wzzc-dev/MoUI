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
  let info = (self.widget.semantics)()
  let actions = self.semantics_actions(info.actions)
  let focusable = actions.any(action => action == SemanticsAction::Focus)
  let focus_order = if focusable {
    let order = next_order.val
    next_order.val = next_order.val + 1
    Some(order)
  } else {
    None
  }
  let state : SemanticsState = {
    focused: focused == Some(self.id),
    disabled: self.widget.state.disabled,
    selected: self.widget.state.selected,
    pressed: self.widget.state.pressed,
    checked: self.widget.state.checked,
    expanded: self.widget.state.expanded,
    invalid: false,
    required: false,
  }
  let children : Array[SemanticsNode] = []
  for index, child in self.children {
    if index < render.children.length() {
      children.push(
        child.build_semantics(render.children[index], focused, next_order),
      )
    }
  }
  {
    element_id: self.id,
    role: info.role,
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
  let info = (self.widget.semantics)()
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
  let info = (self.widget.semantics)()
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
  let info = (self.widget.semantics)()
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
  let info = (self.widget.semantics)()
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
