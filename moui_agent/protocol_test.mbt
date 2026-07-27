///|
test "agent errors expose stable wire codes" {
  assert_eq(AgentReadError::HostClosed.code(), "host_closed")
  assert_eq(AgentActionError::HostClosed.code(), "host_closed")
  assert_eq(AgentActionError::ReentrantDispatch.code(), "reentrant_dispatch")
  let id = @core.SemanticId::parse("missing").unwrap()
  assert_eq(AgentActionError::TargetAmbiguous(id).code(), "target_ambiguous")
}
