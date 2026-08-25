///|
struct RuntimeFixture {
  mut actions : Int
}

///|
fn RuntimeFixture::new() -> RuntimeFixture {
  { actions: 0 }
}

///|
fn fixture_request(kind : @core.SemanticsAction) -> AgentActionRequest {
  {
    target: @core.SemanticsTarget::BySemanticId(
      @core.SemanticId::parse("fixture.action").unwrap(),
    ),
    action: kind,
    precondition: AgentGenerationPrecondition::Latest,
  }
}

///|
pub impl AgentHost for RuntimeFixture with fn read_semantics(_self, _since) {
  Ok(
    AgentSemanticsRead::Full({
      generation: @core.SemanticsGeneration::new(1UL),
      root: None,
      focused: None,
      nodes: [],
      issues: [],
    }),
  )
}

///|
pub impl AgentHost for RuntimeFixture with fn perform_action(self, _request) {
  self.actions = self.actions + 1
  Ok({
    before: @core.SemanticsGeneration::new(self.actions.to_uint64()),
    after: @core.SemanticsGeneration::new((self.actions + 1).to_uint64()),
    pending_work: false,
  })
}

///|
test "policy deny is returned before dispatch" {
  let fixture = RuntimeFixture::new()
  let host = PolicyAgentHost::with_policy(fixture, _request => {
    AgentActionPolicy::Deny("requires review")
  })
  let result = host.perform_action(
    fixture_request(@core.SemanticsAction::Activate),
  )
  assert_true(result is Err(AgentActionError::PolicyDenied("requires review")))
  assert_eq(host.inner().actions, 0)
}

///|
test "confirmation can be approved once and then is removed" {
  let fixture = RuntimeFixture::new()
  let host = PolicyAgentHost::with_policy(fixture, _request => {
    AgentActionPolicy::RequireConfirmation("submit changes")
  })
  let pending = fixture_request(@core.SemanticsAction::Submit)
  let first = host.perform_action(pending)
  guard first is Err(AgentActionError::ConfirmationRequired(request_id)) else {
    fail("expected confirmation request")
  }
  assert_eq(host.pending().length(), 1)
  let receipt = host.approve(request_id)
  assert_true(receipt is Ok(_))
  assert_eq(host.pending().length(), 0)
  assert_eq(host.inner().actions, 1)
}

///|
test "trace redacts SetText values and keeps cursor monotonic" {
  let fixture = RuntimeFixture::new()
  let host = PolicyAgentHost::new(fixture)
  ignore(
    host.perform_action(
      fixture_request(@core.SemanticsAction::SetText("secret-token")),
    ),
  )
  let trace = host.trace()
  assert_eq(trace.length(), 1)
  let wire = ToJson::to_json(trace[0]).stringify()
  assert_true(wire.contains("<redacted>"))
  assert_false(wire.contains("secret-token"))
  let read = host.read_trace(0UL).unwrap()
  assert_eq(read.cursor(), 1UL)
  assert_eq(read.entries().length(), 1)
}

///|
test "replay stops before high-risk action when confirmation is required" {
  let fixture = RuntimeFixture::new()
  let host = PolicyAgentHost::new(fixture)
  ignore(host.perform_action(fixture_request(@core.SemanticsAction::Submit)))
  let result = host.replay_trace(
    AgentReplayRequest::new(cursor=0UL, require_confirmation=true),
  )
  guard result is Ok(value) else { fail("replay should return a result") }
  assert_false(value.success())
  assert_eq(value.completed(), 0)
  assert_true(
    value.failure() is Some(AgentActionError::ConfirmationRequired(_)),
  )
}

///|
test "default policy protects high-risk actions" {
  let host = PolicyAgentHost::with_default_policy(RuntimeFixture::new())
  let result = host.perform_action(
    fixture_request(@core.SemanticsAction::SetText("secret")),
  )
  assert_true(result is Err(AgentActionError::ConfirmationRequired(_)))
  assert_eq(host.pending().length(), 1)
}

///|
test "scenario generation assertion requires an actual change" {
  let unchanged = AgentScenario::new(name="unchanged", steps=[
    AgentScenarioStep::ReadSemantics,
    AgentScenarioStep::AssertGenerationChanged,
  ])
  let unchanged_result = unchanged.run(RuntimeFixture::new())
  assert_false(unchanged_result.passed())

  let changed = AgentScenario::new(name="changed", steps=[
    AgentScenarioStep::ReadSemantics,
    AgentScenarioStep::Perform(fixture_request(@core.SemanticsAction::Activate)),
    AgentScenarioStep::AssertGenerationChanged,
  ])
  let changed_result = changed.run(RuntimeFixture::new())
  assert_true(changed_result.passed())
}

///|
test "replay skips rejected trace entries and preserves successful actions" {
  let fixture = RuntimeFixture::new()
  let host = PolicyAgentHost::with_policy(fixture, request => {
    match request.action {
      @core.SemanticsAction::Submit => AgentActionPolicy::Deny("blocked")
      _ => AgentActionPolicy::Allow
    }
  })
  ignore(host.perform_action(fixture_request(@core.SemanticsAction::Submit)))
  ignore(host.perform_action(fixture_request(@core.SemanticsAction::Activate)))
  let replay = host
    .replay_trace(
      AgentReplayRequest::new(cursor=0UL, require_confirmation=false),
    )
    .unwrap()
  assert_true(replay.success())
  assert_eq(replay.completed(), 1)
}
