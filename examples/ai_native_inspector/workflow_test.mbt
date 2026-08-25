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
