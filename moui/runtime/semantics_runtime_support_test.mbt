///|
priv struct RuntimeSemanticTestNode {
  kind : String
  declaration : @core.ViewDeclaration
  semantic_id : @core.SemanticId?
  role : @core.SemanticsRole
  label : String
  value : String
  description : String
  disabled : Bool
  selected : Bool
  expanded : Bool
  composition : @core.SemanticsComposition
  focusable : Bool
}

///|
fn runtime_semantic_optional_id_key(
  semantic_id : @core.SemanticId?,
) -> @core.DeclarationKey {
  @core.DeclarationKey::option(
    match semantic_id {
      Some(id) => Some(@core.DeclarationKey::string(id.value()))
      None => None
    },
  )
}

///|
fn runtime_semantic_composition_key(
  composition : @core.SemanticsComposition,
) -> @core.DeclarationKey {
  @core.DeclarationKey::int(
    match composition {
      @core.SemanticsComposition::Transparent => 0
      @core.SemanticsComposition::Boundary => 1
      @core.SemanticsComposition::MergeDescendants => 2
      @core.SemanticsComposition::Hidden => 3
    },
  )
}

///|
fn runtime_semantic_role_key(
  role : @core.SemanticsRole,
) -> @core.DeclarationKey {
  @core.DeclarationKey::int(
    match role {
      @core.SemanticsRole::None => 0
      @core.SemanticsRole::Text => 1
      @core.SemanticsRole::Link => 2
      @core.SemanticsRole::Heading => 3
      @core.SemanticsRole::Navigation => 4
      @core.SemanticsRole::Main => 5
      @core.SemanticsRole::Button => 6
      @core.SemanticsRole::Checkbox => 7
      @core.SemanticsRole::TextField => 8
      @core.SemanticsRole::List => 9
      @core.SemanticsRole::ListItem => 10
      @core.SemanticsRole::Grid => 11
      @core.SemanticsRole::ScrollView => 12
      @core.SemanticsRole::Switch => 13
      @core.SemanticsRole::Radio => 14
      @core.SemanticsRole::Slider => 15
      @core.SemanticsRole::Progress => 16
      @core.SemanticsRole::Tab => 17
      @core.SemanticsRole::Dialog => 18
      @core.SemanticsRole::Tooltip => 19
      @core.SemanticsRole::Menu => 20
      @core.SemanticsRole::ButtonGroup => 21
      @core.SemanticsRole::Form => 22
      @core.SemanticsRole::FormField => 23
      @core.SemanticsRole::Tree => 24
      @core.SemanticsRole::TreeItem => 25
      @core.SemanticsRole::Group => 26
      @core.SemanticsRole::WebView => 27
      @core.SemanticsRole::Image => 28
      @core.SemanticsRole::Alert => 29
      @core.SemanticsRole::Status => 30
      @core.SemanticsRole::ComboBox => 31
      @core.SemanticsRole::Option => 32
      @core.SemanticsRole::Table => 33
      @core.SemanticsRole::Row => 34
      @core.SemanticsRole::Cell => 35
      @core.SemanticsRole::Separator => 36
    },
  )
}

///|
fn runtime_semantic_test_declaration(
  semantic_id : @core.SemanticId?,
  role : @core.SemanticsRole,
  label : String,
  value : String,
  description : String,
  disabled : Bool,
  selected : Bool,
  expanded : Bool,
  composition : @core.SemanticsComposition,
  focusable : Bool,
) -> @core.ViewDeclaration {
  @core.ViewDeclaration::channels(
    layout=@core.DeclarationChannel::Constant,
    paint=@core.DeclarationChannel::Constant,
    semantics=@core.DeclarationChannel::Exact(
      @core.DeclarationKey::record(type_tag="RuntimeSemanticTestNode", fields=[
        ("semantic_id", runtime_semantic_optional_id_key(semantic_id)),
        ("role", runtime_semantic_role_key(role)),
        ("label", @core.DeclarationKey::string(label)),
        ("value", @core.DeclarationKey::string(value)),
        ("description", @core.DeclarationKey::string(description)),
        ("disabled", @core.DeclarationKey::bool(disabled)),
        ("selected", @core.DeclarationKey::bool(selected)),
        ("expanded", @core.DeclarationKey::bool(expanded)),
        ("composition", runtime_semantic_composition_key(composition)),
        ("focusable", @core.DeclarationKey::bool(focusable)),
      ]),
    ),
    platform=@core.DeclarationChannel::Constant,
  )
}

///|
impl @core.ViewNode for RuntimeSemanticTestNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind)
}

///|
impl @core.ViewNode for RuntimeSemanticTestNode with fn declaration(self) {
  self.declaration
}

///|
impl @core.ViewNode for RuntimeSemanticTestNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=120.0, height=28.0),
    ),
  )
}

///|
impl @core.ViewNode for RuntimeSemanticTestNode with fn semantics(self) {
  let semantic_id = self.semantic_id
  @core.ViewSemanticsInfo::new(
    composition=self.composition,
    semantic_id?,
    role=self.role,
    label=self.label,
    value=self.value,
    description=self.description,
    disabled=self.disabled,
    selected=self.selected,
    expanded=self.expanded,
  )
}

///|
impl @core.ViewNode for RuntimeSemanticTestNode with fn focusable(self) {
  self.focusable
}

///|
fn[Msg] runtime_semantic_test_view(
  kind? : String = "RuntimeSemanticTestNode",
  semantic_id? : @core.SemanticId,
  role? : @core.SemanticsRole = @core.SemanticsRole::Button,
  label? : String = "",
  value? : String = "",
  description? : String = "",
  disabled? : Bool = false,
  selected? : Bool = false,
  expanded? : Bool = false,
  composition? : @core.SemanticsComposition = @core.SemanticsComposition::Boundary,
  focusable? : Bool = false,
  handlers? : Array[@core.ViewSemanticsActionHandler[Msg]] = [],
) -> @core.View[Msg] {
  let node = RuntimeSemanticTestNode::{
    kind,
    declaration: runtime_semantic_test_declaration(
      semantic_id, role, label, value, description, disabled, selected, expanded,
      composition, focusable,
    ),
    semantic_id,
    role,
    label,
    value,
    description,
    disabled,
    selected,
    expanded,
    composition,
    focusable,
  }
  @core.View::from_node(node, semantics_actions=_node => handlers)
}

///|
priv struct RuntimeSemanticContainerNode {
  kind : String
  declaration : @core.ViewDeclaration
  semantic_id : @core.SemanticId?
  composition : @core.SemanticsComposition
  focus_trap : Bool
}

///|
impl @core.ViewNode for RuntimeSemanticContainerNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind)
}

///|
impl @core.ViewNode for RuntimeSemanticContainerNode with fn declaration(self) {
  self.declaration
}

///|
impl @core.ViewNode for RuntimeSemanticContainerNode with fn layout(
  _self,
  context,
) {
  let child_frames : Array[@core.Rect] = []
  let mut y = 0.0
  let mut width = 0.0
  for size in context.child_sizes {
    child_frames.push(
      @core.Rect::new(x=0.0, y~, width=size.width, height=size.height),
    )
    y = y + size.height
    if size.width > width {
      width = size.width
    }
  }
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width~, height=y)),
    child_frames~,
  )
}

///|
impl @core.ViewNode for RuntimeSemanticContainerNode with fn semantics(self) {
  let semantic_id = self.semantic_id
  @core.ViewSemanticsInfo::new(composition=self.composition, semantic_id?)
}

///|
impl @core.ViewNode for RuntimeSemanticContainerNode with fn focus_trap(self) {
  self.focus_trap
}

///|
fn[Msg] runtime_semantic_container(
  children : Array[@core.View[Msg]],
  kind? : String = "RuntimeSemanticContainer",
  composition? : @core.SemanticsComposition = @core.SemanticsComposition::Transparent,
  semantic_id? : @core.SemanticId,
  focus_trap? : Bool = false,
) -> @core.View[Msg] {
  let node = RuntimeSemanticContainerNode::{
    kind,
    declaration: @core.ViewDeclaration::channels(
      layout=@core.DeclarationChannel::Constant,
      paint=@core.DeclarationChannel::Constant,
      semantics=@core.DeclarationChannel::Exact(
        @core.DeclarationKey::record(type_tag="RuntimeSemanticContainer", fields=[
          ("composition", runtime_semantic_composition_key(composition)),
          ("semantic_id", runtime_semantic_optional_id_key(semantic_id)),
          ("focus_trap", @core.DeclarationKey::bool(focus_trap)),
        ]),
      ),
      platform=@core.DeclarationChannel::Constant,
    ),
    semantic_id,
    composition,
    focus_trap,
  }
  @core.View::from_node(node, children=_node => children)
}

///|
fn runtime_test_semantic_id(value : String) -> @core.SemanticId {
  match @core.SemanticId::parse(value) {
    Some(id) => id
    None => abort("invalid semantic test id")
  }
}

///|
fn runtime_expect_full_semantics(runtime : AppRuntime) -> SemanticsSnapshot {
  match runtime.read_semantics() {
    Ok(SemanticsRead::Full(snapshot)) => snapshot
    _ => abort("expected full semantics snapshot")
  }
}

///|
fn runtime_semantic_node_by_id(
  snapshot : SemanticsSnapshot,
  semantic_id : @core.SemanticId,
) -> @core.SemanticsNode? {
  for node in snapshot.nodes() {
    if node.semantic_id == Some(semantic_id) {
      return Some(node)
    }
  }
  None
}

///|
fn runtime_expect_semantics_action(
  runtime : AppRuntime,
  target : @core.SemanticsTarget,
  action : @core.SemanticsAction,
  generation : @core.SemanticsGeneration,
) -> SemanticsActionReceipt {
  match
    runtime.perform_semantics_action({
      target,
      action,
      precondition: SemanticsGenerationPrecondition::Exact(generation),
    }) {
    Ok(receipt) => receipt
    Err(error) => abort("unexpected semantics action error: \{Repr(error)}")
  }
}
