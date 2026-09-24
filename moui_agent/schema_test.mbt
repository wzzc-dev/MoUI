///|
test "agent action request is typed" {
  let id = @core.SemanticId::new("editor.body")
  let request : @moui_agent.AgentActionRequest = {
    target: BySemanticId(id),
    action: SetText("next"),
    precondition: Latest,
  }
  assert_true(request.action == SetText("next"))
  assert_true(request.target == BySemanticId(id))
}
