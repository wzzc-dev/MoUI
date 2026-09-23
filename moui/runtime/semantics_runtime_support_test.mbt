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
      Transparent => 0
      Boundary => 1
      MergeDescendants => 2
      Hidden => 3
    },
  )
}

///|
fn runtime_semantic_role_key(
  role : @core.SemanticsRole,
) -> @core.DeclarationKey {
  @core.DeclarationKey::int(
    match role {
      None => 0
      Text => 1
      Link => 2
      Heading => 3
      Navigation => 4
      Main => 5
      Button => 6
      Checkbox => 7
      TextField => 8
      List => 9
      ListItem => 10
      Grid => 11
      ScrollView => 12
      Switch => 13
      Radio => 14
      Slider => 15
      Progress => 16
      Tab => 17
      Dialog => 18
      Tooltip => 19
      Menu => 20
      ButtonGroup => 21
      Form => 22
      FormField => 23
      Tree => 24
      TreeItem => 25
      Group => 26
      WebView => 27
      Image => 28
      Alert => 29
      Status => 30
      ComboBox => 31
      Option => 32
      Table => 33
      Row => 34
      Cell => 35
      Separator => 36
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
    layout=Constant,
    paint=Constant,
    semantics=Exact(
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
    platform=Constant,
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
  role? : @core.SemanticsRole = Button,
  label? : String = "",
  value? : String = "",
  description? : String = "",
  disabled? : Bool = false,
  selected? : Bool = false,
  expanded? : Bool = false,
  composition? : @core.SemanticsComposition = Boundary,
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
  composition? : @core.SemanticsComposition = Transparent,
  semantic_id? : @core.SemanticId,
  focus_trap? : Bool = false,
) -> @core.View[Msg] {
  let node = RuntimeSemanticContainerNode::{
    kind,
    declaration: @core.ViewDeclaration::channels(
      layout=Constant,
      paint=Constant,
      semantics=Exact(
        @core.DeclarationKey::record(type_tag="RuntimeSemanticContainer", fields=[
          ("composition", runtime_semantic_composition_key(composition)),
          ("semantic_id", runtime_semantic_optional_id_key(semantic_id)),
          ("focus_trap", @core.DeclarationKey::bool(focus_trap)),
        ]),
      ),
      platform=Constant,
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
fn runtime_expect_full_semantics(
  runtime : @runtime.AppRuntime,
) -> @runtime.SemanticsSnapshot {
  match runtime.read_semantics() {
    Ok(Full(snapshot)) => snapshot
    _ => abort("expected full semantics snapshot")
  }
}

///|
fn runtime_semantic_node_by_id(
  snapshot : @runtime.SemanticsSnapshot,
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
  runtime : @runtime.AppRuntime,
  target : @core.SemanticsTarget,
  action : @core.SemanticsAction,
  generation : @core.SemanticsGeneration,
) -> @runtime.SemanticsActionReceipt {
  match
    runtime.perform_semantics_action({
      target,
      action,
      precondition: Exact(generation),
    }) {
    Ok(receipt) => receipt
    Err(error) => abort("unexpected semantics action error: \{Repr(error)}")
  }
}
