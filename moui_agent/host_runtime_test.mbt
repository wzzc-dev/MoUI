///|
priv struct AgentFixtureNode {}

///|
impl @core.ViewNode for AgentFixtureNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="AgentFixture")
}

///|
impl @core.ViewNode for AgentFixtureNode with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for AgentFixtureNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width=80.0, height=32.0)),
  )
}

///|
impl @core.ViewNode for AgentFixtureNode with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    semantic_id=@core.SemanticId::parse("fixture.activate").unwrap(),
    role=@core.SemanticsRole::Button,
    label="Activate fixture",
  )
}

///|
fn agent_fixture_view() -> @core.View[Unit] {
  @core.View::from_node(AgentFixtureNode::{  }, semantics_actions=_node => {
    [
      @core.ViewSemanticsActionHandler::activate(_context => {
        @core.ViewSemanticsActionResult::accepted(messages=[()])
      }),
    ]
  })
}

///|
test "RuntimeAgentHost reads committed semantics and performs typed actions" {
  let runtime = @runtime.AppRuntime::new_view(
    root=agent_fixture_view(),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  let host = RuntimeAgentHost::new(runtime)
  let generation = match host.read_semantics(None) {
    Ok(AgentSemanticsRead::Full(snapshot)) => {
      assert_eq(snapshot.nodes.length(), 1)
      assert_true(snapshot.root is Some(_))
      assert_eq(snapshot.nodes[0].label, "Activate fixture")
      snapshot.generation
    }
    Ok(_) => fail("first read must return a full snapshot")
    Err(error) => fail("unexpected read error: \{Repr(error)}")
  }
  let semantic_id = @core.SemanticId::parse("fixture.activate").unwrap()
  match
    host.perform_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: AgentGenerationPrecondition::Exact(generation),
    }) {
    Ok(receipt) => assert_true(receipt.after >= receipt.before)
    Err(error) => fail("unexpected action error: \{Repr(error)}")
  }
}

///|
test "RuntimeAgentHost returns HostClosed after runtime destruction" {
  let runtime = @runtime.AppRuntime::new_view(
    root=agent_fixture_view(),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  let host = RuntimeAgentHost::new(runtime)
  runtime.destroy()
  assert_true(host.read_semantics(None) == Err(AgentReadError::HostClosed))
  let semantic_id = @core.SemanticId::parse("fixture.activate").unwrap()
  assert_true(
    host.perform_action({
      target: @core.SemanticsTarget::BySemanticId(semantic_id),
      action: @core.SemanticsAction::Activate,
      precondition: AgentGenerationPrecondition::Latest,
    }) ==
    Err(AgentActionError::HostClosed),
  )
}
