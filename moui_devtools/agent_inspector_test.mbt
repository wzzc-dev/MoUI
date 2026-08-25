///|
test "agent inspector report has stable empty and export states" {
  let report = agent_inspector_report(
    None,
    policy=@agent.AgentPolicyState::new(trace_count=3),
    trace=[],
  )
  let text = agent_inspector_report_text(report)
  assert_true(text.contains("[semantics] closed"))
  assert_true(text.contains("traces=3"))
  assert_true(text.contains("[audit] checked=0; issues=0"))
  let json = agent_inspector_report_json(report)
  assert_true(json.contains("\"audit\""))
  assert_true(json.contains("\"trace\""))
}
