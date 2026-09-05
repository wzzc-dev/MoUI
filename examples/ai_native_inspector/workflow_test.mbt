///|
fn workbench_action(
  id : String,
  action : @core.SemanticsAction,
) -> @agent.AgentActionRequest {
  {
    target: @core.SemanticsTarget::BySemanticId(
      @core.SemanticId::parse(id).unwrap(),
    ),
    action,
    precondition: @agent.AgentGenerationPrecondition::Latest,
  }
}

///|
test "workbench composition root protects submit and export" {
  let host = agent_host(runtime())
  let submit = host.perform_action(
    workbench_action("workbench.submit", @core.SemanticsAction::Activate),
  )
  guard submit is Err(@agent.AgentActionError::ConfirmationRequired(request_id)) else {
    fail("submit must require confirmation")
  }
  assert_eq(host.pending().length(), 1)
  assert_true(host.approve(request_id) is Ok(_))

  let export_result = host.perform_action(
    workbench_action("workbench.export", @core.SemanticsAction::Activate),
  )
  assert_true(
    export_result is Err(@agent.AgentActionError::ConfirmationRequired(_)),
  )
}

///|
test "search Skill is autonomous while edit Skill remains gated" {
  let search = skill_registry().call(
    agent_host(runtime()),
    @agent.AgentSkillCall::new(skill_id="workbench.search", inputs={
      "query": "MoonBit",
    }),
  )
  assert_true(search.success())
  let edit = skill_registry().call(
    agent_host(runtime()),
    @agent.AgentSkillCall::new(skill_id="workbench.update", inputs={
      "name": "Reviewed renewal",
    }),
  )
  assert_true(
    edit.error()
    is Some(
      @agent.AgentSkillError::Action(
        @agent.AgentActionError::ConfirmationRequired(_)
      )
    ),
  )
}

///|
test "secure MCP Skill flow feeds the live trace and policy state" {
  let host = secure_agent_host(runtime())
  let search_response = route_agent_with_skills(
    host,
    (
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
          "name": "skills/call",
          "arguments": {
            "skill_id": "workbench.search",
            "inputs": { "query": "MoonBit" },
          },
        },
      } : Json),
  )
  assert_true(search_response.stringify().contains("\"isError\":false"))
  let transition_response = route_agent_with_skills(
    host,
    (
      {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
          "name": "skills/call",
          "arguments": { "skill_id": "workbench.transition" },
        },
      } : Json),
  )
  assert_true(transition_response.stringify().contains("confirmation_required"))
  let policy = @agent.AgentTraceHost::read_policy_state(host)
  assert_eq(policy.pending().length(), 1)
  assert_true(policy.trace_count() >= 2)
  let request_id = policy.pending()[0].request_id()
  assert_true(host.inner().approve(request_id) is Ok(_))
  let after = @agent.AgentTraceHost::read_policy_state(host)
  assert_eq(after.pending().length(), 0)
  assert_true(after.trace_count() >= 3)
}
