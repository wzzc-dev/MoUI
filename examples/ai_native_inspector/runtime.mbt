///|
pub fn runtime(
  width? : Double = 920.0,
  height? : Double = 680.0,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program=@app.program(), width~, height~)
}

///|
/// Composition-root policy for the reference workflow. Read and navigation
/// actions stay autonomous; text, numeric writes, submit and export require a
/// human confirmation request that the Inspector can display and approve.
pub fn agent_host(
  runtime : @runtime.AppRuntime,
) -> @agent.PolicyAgentHost[@agent.RuntimeAgentHost] {
  @agent.PolicyAgentHost::with_policy(@agent.RuntimeAgentHost::new(runtime), request => {
    let high_risk_target = match request.target {
      @core.SemanticsTarget::BySemanticId(id) =>
        id.value() == "workbench.submit" || id.value() == "workbench.export"
      _ => false
    }
    if high_risk_target {
      @agent.AgentActionPolicy::RequireConfirmation(
        "high-risk workbench action",
      )
    } else {
      match request.action {
        @core.SemanticsAction::SetText(_)
        | @core.SemanticsAction::SetNumericValue(_)
        | @core.SemanticsAction::Submit =>
          @agent.AgentActionPolicy::RequireConfirmation(
            "high-risk workbench action",
          )
        _ => @agent.AgentActionPolicy::Allow
      }
    }
  })
}

///|
/// Explicit opt-in MCP composition root used by the stdio host and test
/// harness. The app package itself never imports the transport package.
pub fn route_agent(
  host : @agent.PolicyAgentHost[@agent.RuntimeAgentHost],
  request : Json,
) -> Json {
  @mcp.route_with_agent_tools(host, request)
}
