///|
struct SkillFixture {
  mut generation : UInt64
}

///|
fn SkillFixture::new() -> SkillFixture {
  { generation: 1UL }
}

///|
fn skill_fixture_snapshot(fixture : SkillFixture) -> AgentSemanticsSnapshot {
  {
    generation: @core.SemanticsGeneration::new(fixture.generation),
    root: Some(@core.SemanticsNodeId::new(1UL)),
    focused: None,
    nodes: [
      {
        node_id: @core.SemanticsNodeId::new(1UL),
        semantic_id: Some(
          @core.SemanticId::parse("workbench.search.query").unwrap(),
        ),
        role: @core.SemanticsRole::TextField,
        level: None,
        url: "",
        label: "Search query",
        value: "secret-value",
        description: "",
        state: @core.SemanticsState::default(),
        numeric: Some(
          @core.SemanticsNumericValue::new(value_text="secret-number"),
        ),
        text: Some(@core.SemanticsTextValue::new(editable=true)),
        collection: None,
        relations: @core.SemanticsRelations::empty(),
        live: @core.SemanticsLive::Off,
        live_atomic: false,
        actions: [
          @core.SemanticsActionKind::Focus,
          @core.SemanticsActionKind::SetText,
        ],
        focus_order: Some(0),
        frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=32.0),
        children: [],
      },
    ],
    issues: [],
  }
}

///|
pub impl AgentHost for SkillFixture with fn read_semantics(self, _since) {
  Ok(AgentSemanticsRead::Full(skill_fixture_snapshot(self)))
}

///|
pub impl AgentHost for SkillFixture with fn perform_action(self, _request) {
  self.generation = self.generation + 1UL
  Ok({
    before: @core.SemanticsGeneration::new(self.generation - 1UL),
    after: @core.SemanticsGeneration::new(self.generation),
    pending_work: false,
  })
}

///|
test "declarative Skill executes typed action and checks generation" {
  let registry = AgentSkillRegistry::new()
  let skill = AgentSkillManifest::new(
    id="workbench.search",
    version="1.0.0",
    description="Search records",
    input_schema=({ "type": "object" } : Json),
    steps=[
      AgentSkillStep::ReadSemantics,
      AgentSkillStep::AssertTarget("workbench.search.query"),
      AgentSkillStep::AssertAction(
        "workbench.search.query",
        @core.SemanticsActionKind::SetText,
      ),
      AgentSkillStep::Perform(
        "workbench.search.query",
        AgentSkillAction::SetText(AgentSkillValue::Input("query")),
      ),
      AgentSkillStep::AssertGenerationChanged,
    ],
  )
  assert_true(registry.register(skill) is Ok(_))
  let inputs : Map[String, String] = { "query": "MoonBit" }
  let result = registry.call(
    SkillFixture::new(),
    AgentSkillCall::new(skill_id="workbench.search", inputs~),
  )
  assert_true(result.success())
  assert_eq(result.completed_steps(), 5)
  assert_eq(result.receipts().length(), 1)
}

///|
test "Skill scope is required before action dispatch" {
  let registry = AgentSkillRegistry::new()
  let skill = AgentSkillManifest::new(
    id="workbench.read_sensitive",
    version="1.0.0",
    description="Read protected data",
    input_schema=Json::empty_object(),
    required_scopes=["records.sensitive.read"],
    steps=[AgentSkillStep::ReadSemantics],
  )
  assert_true(registry.register(skill) is Ok(_))
  let result = registry.call(
    SkillFixture::new(),
    AgentSkillCall::new(skill_id="workbench.read_sensitive"),
  )
  assert_true(result.error() is Some(AgentSkillError::MissingScope(_)))
  assert_false(result.success())
}

///|
test "Skill input schema rejects unknown and missing fields" {
  let registry = AgentSkillRegistry::new()
  let skill = AgentSkillManifest::new(
    id="schema-checked",
    version="1.0.0",
    description="Schema checked Skill",
    input_schema=(
      {
        "type": "object",
        "properties": { "query": { "type": "string" } },
        "required": ["query"],
      } : Json),
    steps=[AgentSkillStep::ReadSemantics],
  )
  assert_true(registry.register(skill) is Ok(_))
  let missing = registry.call(
    SkillFixture::new(),
    AgentSkillCall::new(skill_id="schema-checked"),
  )
  assert_true(missing.error() is Some(AgentSkillError::InvalidManifest(_)))
  let unknown = registry.call(
    SkillFixture::new(),
    AgentSkillCall::new(skill_id="schema-checked", inputs={
      "query": "MoonBit",
      "extra": "rejected",
    }),
  )
  assert_true(unknown.error() is Some(AgentSkillError::InvalidManifest(_)))
}

///|
test "Skill executor refuses an unregistered manifest" {
  let registry = AgentSkillRegistry::new()
  let manifest = AgentSkillManifest::new(
    id="unregistered",
    version="1.0.0",
    description="not registered",
    input_schema=Json::empty_object(),
    steps=[AgentSkillStep::ReadSemantics],
  )
  let result = registry.execute(
    SkillFixture::new(),
    manifest,
    AgentSkillCall::new(skill_id="unregistered"),
  )
  assert_true(result.error() is Some(AgentSkillError::UnknownSkill(_)))
  let executor = AgentSkillExecutor::new()
  let unknown = executor.execute(
    registry,
    SkillFixture::new(),
    AgentSkillCall::new(skill_id="missing"),
  )
  assert_true(unknown.error() is Some(AgentSkillError::UnknownSkill(_)))
}

///|
test "secure session redacts protected semantic values and denies actions" {
  let policy = AgentVisibilityPolicy::new().protect(
    semantic_id="workbench.search.query",
    scope="records.sensitive.read",
  )
  let session = AgentSecureSession::new(SkillFixture::new(), policy)
  match session.read_semantics(None) {
    Ok(AgentSemanticsRead::Full(snapshot)) => {
      assert_eq(snapshot.nodes()[0].value, "<redacted>")
      assert_true(snapshot.nodes()[0].numeric is None)
    }
    _ => fail("expected a full snapshot")
  }
  let id = @core.SemanticId::parse("workbench.search.query").unwrap()
  let result = session.perform_action({
    target: @core.SemanticsTarget::BySemanticId(id),
    action: @core.SemanticsAction::SetText("secret"),
    precondition: AgentGenerationPrecondition::Latest,
  })
  assert_true(result is Err(AgentActionError::PolicyDenied(_)))
}

///|
test "sensitive Skill requires both Scope and confirmation" {
  let registry = AgentSkillRegistry::new()
  let skill = AgentSkillManifest::new(
    id="read-sensitive",
    version="1.0.0",
    description="Read protected value",
    input_schema=Json::empty_object(),
    required_scopes=["records.sensitive.read"],
    steps=[
      AgentSkillStep::RequireScope("records.sensitive.read"),
      AgentSkillStep::RequireConfirmation("read-sensitive"),
      AgentSkillStep::ReadSemantics,
    ],
  )
  assert_true(registry.register(skill) is Ok(_))
  let waiting = registry.call(
    SkillFixture::new(),
    AgentSkillCall::new(skill_id="read-sensitive", scopes=[
      "records.sensitive.read",
    ]),
  )
  assert_true(waiting.error() is Some(AgentSkillError::ConfirmationRequired(_)))
  let approved = registry.call(
    SkillFixture::new(),
    AgentSkillCall::new(
      skill_id="read-sensitive",
      scopes=["records.sensitive.read"],
      confirmation="read-sensitive",
    ),
  )
  assert_true(approved.success())
}

///|
test "secure Skill execution applies invocation Scope to protected targets" {
  let registry = AgentSkillRegistry::new()
  let skill = AgentSkillManifest::new(
    id="protected-update",
    version="1.0.0",
    description="Update a protected field",
    input_schema=Json::empty_object(),
    required_scopes=["records.sensitive.write"],
    steps=[
      AgentSkillStep::ReadSemantics,
      AgentSkillStep::AssertTarget("workbench.search.query"),
      AgentSkillStep::AssertAction(
        "workbench.search.query",
        @core.SemanticsActionKind::SetText,
      ),
      AgentSkillStep::Perform(
        "workbench.search.query",
        AgentSkillAction::SetText(AgentSkillValue::Literal("approved")),
      ),
    ],
  )
  assert_true(registry.register(skill) is Ok(_))
  let visibility = AgentVisibilityPolicy::new().protect(
    semantic_id="workbench.search.query",
    scope="records.sensitive.write",
  )
  let session = AgentSecureSession::new(SkillFixture::new(), visibility)
  let denied = session.execute_skill(
    registry,
    AgentSkillCall::new(skill_id="protected-update"),
  )
  assert_true(denied.error() is Some(AgentSkillError::MissingScope(_)))
  assert_false(denied.output().stringify().contains("secret-value"))
  let approved = session.execute_skill(
    registry,
    AgentSkillCall::new(skill_id="protected-update", scopes=[
      "records.sensitive.write",
    ]),
  )
  assert_true(approved.success())
  assert_true(approved.output().stringify().contains("secret-value"))
  assert_true(approved.output().stringify().contains("secret-number"))
}
