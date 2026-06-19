///|
fn ErasedViewNode::identity_key(self : ErasedViewNode) -> Key? {
  self.identity.key
}

///|
fn ErasedViewNode::kind(self : ErasedViewNode) -> Int {
  stable_erased_view_node_kind(self.identity.kind)
}

///|
fn ErasedViewNode::inspector_kind_label(self : ErasedViewNode) -> String {
  self.identity.kind
}

///|
fn ErasedViewNode::inspector_is_control(self : ErasedViewNode) -> Bool {
  (self.focusable)()
}

///|
fn ErasedViewNode::same_identity(
  self : ErasedViewNode,
  next : ErasedViewNode,
) -> Bool {
  self.kind() == next.kind() && self.identity_key() == next.identity_key()
}

///|
fn ErasedViewNode::is_building_erased_view_node(self : ErasedViewNode) -> Bool {
  self.build_child is Some(_)
}

///|
fn ErasedViewNode::reconcile_dirty_kind(
  self : ErasedViewNode,
  next : ErasedViewNode,
) -> ReconcileDirtyKind {
  if self.revision != "" && self.revision == next.revision {
    ReconcileClean
  } else {
    ReconcileLayout
  }
}

///|
fn empty_erased_view_node() -> ErasedViewNode {
  {
    identity: @core.ViewIdentity::new(kind="Empty"),
    revision: "empty",
    children: () => [],
    build_child: None,
    child_constraints: constraints => constraints.loosen(),
    child_environment: environment => environment,
    child_style: style => style,
    layout: context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(Size::new(width=0.0, height=0.0)),
      )
    },
    paint: _context => @core.ViewPaintPlan::empty(),
    event: _context => @core.ViewEventResult::ignored(),
    text_input_state: _context => None,
    text_command: (_context, _intent, _paste_text) => {
      @core.ViewTextCommandResult::ignored()
    },
    semantics: () => @core.ViewSemanticsInfo::new(),
    focusable: () => false,
    state: erased_view_node_state_context_default(),
  }
}

///|
fn stable_erased_view_node_kind(kind : String) -> Int {
  let mut hash = 0
  for ch in kind {
    hash = (hash * 31 + ch.to_int()) % 1000000007
  }
  1000 + (if hash < 0 { -hash } else { hash })
}
