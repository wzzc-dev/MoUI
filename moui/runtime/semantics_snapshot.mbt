///|
pub(all) enum SemanticsIssue {
  DuplicateSemanticId(@core.SemanticId, Array[@core.SemanticsNodeId])
} derive(Eq, Debug, ToJson)

///|
/// One atomically committed, flat semantics tree.
///
/// Mutable arrays are kept private. Every accessor returns a fresh projection
/// so consumers cannot mutate runtime-owned committed state.
pub struct SemanticsSnapshot {
  priv generation : @core.SemanticsGeneration
  priv root : @core.SemanticsNodeId?
  priv focused : @core.SemanticsNodeId?
  priv nodes : Array[@core.SemanticsNode]
  priv issues : Array[SemanticsIssue]
} derive(Eq, Debug)

///|
pub struct SemanticsDelta {
  priv from : @core.SemanticsGeneration
  priv to : @core.SemanticsGeneration
  priv root : @core.SemanticsNodeId?
  priv focused : @core.SemanticsNodeId?
  priv upserted : Array[@core.SemanticsNode]
  priv removed : Array[@core.SemanticsNodeId]
  priv issues : Array[SemanticsIssue]
} derive(Eq, Debug)

///|
pub(all) enum SemanticsRead {
  Full(SemanticsSnapshot)
  Delta(SemanticsDelta)
  Unchanged(@core.SemanticsGeneration)
} derive(Eq, Debug)

///|
pub(all) enum SemanticsReadError {
  RuntimeClosed
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SemanticsGenerationPrecondition {
  Exact(@core.SemanticsGeneration)
  Latest
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PerformSemanticsActionRequest {
  target : @core.SemanticsTarget
  action : @core.SemanticsAction
  precondition : SemanticsGenerationPrecondition
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SemanticsActionReceipt {
  before : @core.SemanticsGeneration
  after : @core.SemanticsGeneration
  pending_work : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SemanticsActionDispatchError {
  RuntimeClosed
  StaleGeneration(@core.SemanticsGeneration, @core.SemanticsGeneration)
  TargetNotFound(@core.SemanticsTarget)
  TargetAmbiguous(@core.SemanticId)
  TargetDisabled(@core.SemanticsTarget)
  ActionUnavailable(@core.SemanticsTarget, @core.SemanticsActionKind)
  HandlerRejected(@core.SemanticsTarget, @core.SemanticsActionKind)
  ReentrantDispatch
} derive(Eq, Debug, ToJson)

///|
priv enum SemanticIdIndexEntry {
  Unique(@core.SemanticsNodeId)
  Ambiguous
}

///|
priv struct SemanticActionRoute {
  kind : @core.SemanticsActionKind
  element : ElementNode
  layout : PlacedNode
  environment : @core.Environment
  style : @core.ViewStyle
}

///|
priv struct SemanticsNodeRoute {
  mut focus_element : ElementId?
  actions : Array[SemanticActionRoute]
}

///|
fn clone_semantics_node(node : @core.SemanticsNode) -> @core.SemanticsNode {
  { ..node, actions: node.actions.copy(), children: node.children.copy() }
}

///|
fn clone_semantics_issue(issue : SemanticsIssue) -> SemanticsIssue {
  match issue {
    DuplicateSemanticId(id, nodes) => DuplicateSemanticId(id, nodes.copy())
  }
}

///|
fn SemanticsSnapshot::empty() -> SemanticsSnapshot {
  {
    generation: @core.SemanticsGeneration::new(0UL),
    root: None,
    focused: None,
    nodes: [],
    issues: [],
  }
}

///|
pub fn SemanticsSnapshot::generation(
  self : SemanticsSnapshot,
) -> @core.SemanticsGeneration {
  self.generation
}

///|
pub fn SemanticsSnapshot::root(
  self : SemanticsSnapshot,
) -> @core.SemanticsNodeId? {
  self.root
}

///|
pub fn SemanticsSnapshot::focused(
  self : SemanticsSnapshot,
) -> @core.SemanticsNodeId? {
  self.focused
}

///|
pub fn SemanticsSnapshot::nodes(
  self : SemanticsSnapshot,
) -> Array[@core.SemanticsNode] {
  self.nodes.map(clone_semantics_node)
}

///|
pub fn SemanticsSnapshot::issues(
  self : SemanticsSnapshot,
) -> Array[SemanticsIssue] {
  self.issues.map(clone_semantics_issue)
}

///|
pub fn SemanticsDelta::from(self : SemanticsDelta) -> @core.SemanticsGeneration {
  self.from
}

///|
pub fn SemanticsDelta::to(self : SemanticsDelta) -> @core.SemanticsGeneration {
  self.to
}

///|
pub fn SemanticsDelta::root(self : SemanticsDelta) -> @core.SemanticsNodeId? {
  self.root
}

///|
pub fn SemanticsDelta::focused(self : SemanticsDelta) -> @core.SemanticsNodeId? {
  self.focused
}

///|
pub fn SemanticsDelta::upserted(
  self : SemanticsDelta,
) -> Array[@core.SemanticsNode] {
  self.upserted.map(clone_semantics_node)
}

///|
pub fn SemanticsDelta::removed(
  self : SemanticsDelta,
) -> Array[@core.SemanticsNodeId] {
  self.removed.copy()
}

///|
pub fn SemanticsDelta::issues(self : SemanticsDelta) -> Array[SemanticsIssue] {
  self.issues.map(clone_semantics_issue)
}
