///|
pub(all) enum SemanticsIssue {
  DuplicateSemanticId(@core.SemanticId, Array[@core.SemanticsNodeId])
  MissingRelationTarget(
    @core.SemanticsNodeId,
    @core.SemanticsRelationKind,
    @core.SemanticId
  )
  AmbiguousRelationTarget(
    @core.SemanticsNodeId,
    @core.SemanticsRelationKind,
    @core.SemanticId,
    Array[@core.SemanticsNodeId]
  )
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
  priv semantic_focused : @core.SemanticsNodeId?
  priv nodes : Array[@core.SemanticsNode]
  priv issues : Array[SemanticsIssue]
} derive(Eq, Debug)

///|
pub struct SemanticsDelta {
  priv from : @core.SemanticsGeneration
  priv to : @core.SemanticsGeneration
  priv root : @core.SemanticsNodeId?
  priv focused : @core.SemanticsNodeId?
  priv semantic_focused : @core.SemanticsNodeId?
  priv upserted : Array[@core.SemanticsNode]
  priv removed : Array[@core.SemanticsNodeId]
  priv issues : Array[SemanticsIssue]
  priv announcements : Array[AccessibilityAnnouncement]
} derive(Eq, Debug)

///|
/// A live-region change for platform adapters to publish without moving focus.
pub(all) struct AccessibilityAnnouncement {
  node_id : @core.SemanticsNodeId
  generation : @core.SemanticsGeneration
  live : @core.SemanticsLive
  is_atomic : Bool
  text : String
} derive(Eq, Debug, ToJson)

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
  {
    ..node,
    relations: {
      labelled_by: node.relations.labelled_by.copy(),
      described_by: node.relations.described_by.copy(),
      controls: node.relations.controls.copy(),
      error_message: node.relations.error_message.copy(),
      active_descendant: node.relations.active_descendant.copy(),
    },
    actions: node.actions.copy(),
    children: node.children.copy(),
  }
}

///|
fn clone_semantics_issue(issue : SemanticsIssue) -> SemanticsIssue {
  match issue {
    DuplicateSemanticId(id, nodes) => DuplicateSemanticId(id, nodes.copy())
    MissingRelationTarget(source, kind, id) =>
      MissingRelationTarget(source, kind, id)
    AmbiguousRelationTarget(source, kind, id, nodes) =>
      AmbiguousRelationTarget(source, kind, id, nodes.copy())
  }
}

///|
fn SemanticsSnapshot::empty() -> SemanticsSnapshot {
  {
    generation: @core.SemanticsGeneration::new(0UL),
    root: None,
    focused: None,
    semantic_focused: None,
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
/// Assistive-technology browsing focus, kept independent from keyboard/input
/// focus. Platform navigation may update this value without stealing input.
pub fn SemanticsSnapshot::semantic_focused(
  self : SemanticsSnapshot,
) -> @core.SemanticsNodeId? {
  self.semantic_focused
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
pub fn SemanticsDelta::semantic_focused(
  self : SemanticsDelta,
) -> @core.SemanticsNodeId? {
  self.semantic_focused
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

///|
pub fn SemanticsDelta::announcements(
  self : SemanticsDelta,
) -> Array[AccessibilityAnnouncement] {
  self.announcements.copy()
}

///|
/// Update assistive-technology browsing focus without moving keyboard/input
/// focus. The target must exist in the committed semantics tree; `None`
/// clears browsing focus.
pub fn AppRuntime::set_semantic_focus(
  self : AppRuntime,
  node_id : @core.SemanticsNodeId?,
) -> Bool {
  self.state.set_semantic_focus(node_id)
}
