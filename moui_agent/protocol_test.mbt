///|
test "agent errors expose stable wire codes" {
  assert_eq(@moui_agent.AgentReadError::HostClosed.code(), "host_closed")
  assert_eq(@moui_agent.AgentActionError::HostClosed.code(), "host_closed")
  assert_eq(
    @moui_agent.AgentActionError::ReentrantDispatch.code(),
    "reentrant_dispatch",
  )
  let id = @core.SemanticId::parse("missing").unwrap()
  assert_eq(
    @moui_agent.AgentActionError::TargetAmbiguous(id).code(),
    "target_ambiguous",
  )
}
