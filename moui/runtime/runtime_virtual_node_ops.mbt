///|
fn VirtualNode::identity_key(self : VirtualNode) -> Key? {
  match self.identity.key {
    Some(key) => Some(Key::new(key.value()))
    None => None
  }
}

///|
fn VirtualNode::kind(self : VirtualNode) -> Int {
  stable_virtual_node_kind(self.identity.kind)
}

///|
fn VirtualNode::inspector_kind_label(self : VirtualNode) -> String {
  self.identity.kind
}

///|
fn VirtualNode::inspector_is_control(self : VirtualNode) -> Bool {
  (self.focusable)()
}

///|
fn VirtualNode::same_identity(self : VirtualNode, next : VirtualNode) -> Bool {
  self.kind() == next.kind() && self.identity_key() == next.identity_key()
}

///|
fn VirtualNode::is_building_virtual_node(self : VirtualNode) -> Bool {
  self.build_child is Some(_)
}

///|
fn VirtualNode::reconcile_dirty_kind(
  self : VirtualNode,
  next : VirtualNode,
) -> ReconcileDirtyKind {
  if self.revision != "" && self.revision == next.revision {
    ReconcileClean
  } else {
    ReconcileLayout
  }
}

///|
fn empty_virtual_node() -> VirtualNode {
  {
    identity: @core.VirtualNodeIdentity::new(kind="Empty"),
    revision: "empty",
    children: () => [],
    build_child: None,
    child_constraints: constraints => constraints.loosen(),
    layout: context => {
      @core.VirtualNodeLayoutResult::new(
        size=context.constraints.constrain(Size::new(width=0.0, height=0.0)),
      )
    },
    paint: _context => @core.VirtualNodePaintPlan::empty(),
    event: _context => @core.VirtualNodeEventResult::ignored(),
    text_input_state: _context => None,
    text_command: (_context, _intent, _paste_text) => {
      @core.VirtualNodeTextCommandResult::ignored()
    },
    semantics: () => @core.VirtualNodeSemanticsInfo::new(),
    focusable: () => false,
    state: virtual_node_state_context_default(),
  }
}

///|
fn stable_virtual_node_kind(kind : String) -> Int {
  let mut hash = 0
  for ch in kind {
    hash = (hash * 31 + ch.to_int()) % 1000000007
  }
  1000 + (if hash < 0 { -hash } else { hash })
}
