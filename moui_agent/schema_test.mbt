///|
test "agent action request is typed" {
  let id = @core.SemanticId::parse("editor.body").unwrap()
  let request : AgentActionRequest = {
    target: @core.SemanticsTarget::BySemanticId(id),
    action: @core.SemanticsAction::SetText("next"),
    precondition: AgentGenerationPrecondition::Latest,
  }
  assert_true(request.action == @core.SemanticsAction::SetText("next"))
  assert_true(request.target == @core.SemanticsTarget::BySemanticId(id))
}
