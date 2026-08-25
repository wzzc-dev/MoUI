///|
test "workbench exposes stable semantic targets for Agent QA" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=920.0,
    height=680.0,
  )
  let host = @agent.RuntimeAgentHost::new(runtime)
  match host.read_semantics(None) {
    Ok(@agent.AgentSemanticsRead::Full(snapshot)) => {
      assert_true(
        snapshot.nodes().any(node => node.semantic_id == Some(@core.SemanticId::parse("workbench.search.query").unwrap())),
      )
      assert_true(
        snapshot.nodes().any(node => node.semantic_id == Some(@core.SemanticId::parse("workbench.submit").unwrap())),
      )
    }
    _ => fail("expected a committed workbench semantics snapshot")
  }
}
