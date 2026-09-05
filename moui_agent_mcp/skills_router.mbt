///|
/// Skill tools are kept in their own module so the transport router remains
/// focused on MCP envelopes and the default two-tool compatibility surface.
fn[Host : @agent.AgentHost] skill_tool_registry(
  registry : @agent.AgentSkillRegistry,
) -> Array[ToolSpec[Host]] {
  [
    {
      name: "skills/list",
      description: "List declarative Agent Skills exposed by this application.",
      input: agent_skills_list_input_codec(),
      output: {
        schema: tool_output_schema(({ "type": "array" } : Json)),
        dispatch: (host, id, invocation) => {
          dispatch_agent_skills_tool(registry, host, id, invocation)
        },
      },
    },
    {
      name: "skills/get",
      description: "Read one Skill manifest and its required scopes.",
      input: agent_skills_get_input_codec(),
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: (host, id, invocation) => {
          dispatch_agent_skills_tool(registry, host, id, invocation)
        },
      },
    },
    {
      name: "skills/call",
      description: "Execute a bounded declarative Skill with typed actions.",
      input: agent_skills_call_input_codec(),
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: (host, id, invocation) => {
          dispatch_agent_skills_tool(registry, host, id, invocation)
        },
      },
    },
  ]
}

///|
/// Skill tools for a secure session. The secure route is explicit so the
/// default generic route keeps its existing host behavior and compatibility.
fn[Inner : @agent.AgentHost] secure_skill_tool_registry(
  registry : @agent.AgentSkillRegistry,
) -> Array[ToolSpec[@agent.AgentSecureSession[Inner]]] {
  [
    {
      name: "skills/list",
      description: "List declarative Agent Skills exposed by this application.",
      input: agent_skills_list_input_codec(),
      output: {
        schema: tool_output_schema(({ "type": "array" } : Json)),
        dispatch: (host, id, invocation) => {
          dispatch_secure_agent_skills_tool(registry, host, id, invocation)
        },
      },
    },
    {
      name: "skills/get",
      description: "Read one Skill manifest and its required scopes.",
      input: agent_skills_get_input_codec(),
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: (host, id, invocation) => {
          dispatch_secure_agent_skills_tool(registry, host, id, invocation)
        },
      },
    },
    {
      name: "skills/call",
      description: "Execute a bounded declarative Skill with typed actions.",
      input: agent_skills_call_input_codec(),
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: (host, id, invocation) => {
          dispatch_secure_agent_skills_tool(registry, host, id, invocation)
        },
      },
    },
  ]
}

///|
/// Route semantic tools, Inspector tools and the explicit Skill registry.
/// This is opt-in so existing MCP clients still see exactly two default tools.
pub fn[Host : @agent.AgentHost + @agent.AgentTraceHost] route_with_skills(
  host : Host,
  registry : @agent.AgentSkillRegistry,
  request : Json,
) -> Json {
  let id = rpc_id(request)
  let tools = semantic_tool_registry(host)
  tools.append(agent_tool_registry(host))
  tools.append(skill_tool_registry(registry))
  match rpc_method(request) {
    None => rpc_error(id, -32600, "Invalid Request: missing method")
    Some("initialize") => rpc_result(id, initialize_result())
    Some("tools/list") => list_tools(id, tools)
    Some("tools/call") => route_tool_call(host, id, request, tools)
    Some(method_name) =>
      rpc_error(id, -32601, "Method not found: \{method_name}")
  }
}

///|
/// Route Skills through an AgentSecureSession so invocation scopes are applied
/// to the short-lived session used by the Skill. This is the opt-in entrypoint
/// composition roots should use when protected semantic values are enabled.
pub fn[Inner : @agent.AgentHost + @agent.AgentTraceHost] route_with_secure_skills(
  host : @agent.AgentSecureSession[Inner],
  registry : @agent.AgentSkillRegistry,
  request : Json,
) -> Json {
  let id = rpc_id(request)
  let tools = semantic_tool_registry(host)
  tools.append(agent_tool_registry(host))
  tools.append(secure_skill_tool_registry(registry))
  match rpc_method(request) {
    None => rpc_error(id, -32600, "Invalid Request: missing method")
    Some("initialize") => rpc_result(id, initialize_result())
    Some("tools/list") => list_tools(id, tools)
    Some("tools/call") => route_tool_call(host, id, request, tools)
    Some(method_name) =>
      rpc_error(id, -32601, "Method not found: \{method_name}")
  }
}

///|
fn[Host : @agent.AgentHost] dispatch_agent_skills_tool(
  registry : @agent.AgentSkillRegistry,
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    ToolInvocation::AgentSkillsList =>
      tool_success(id, registry.list().to_json())
    ToolInvocation::AgentSkillsGet(skill_id) =>
      match registry.get(skill_id) {
        Some(skill) => tool_success(id, skill.to_json())
        None => tool_failure(id, "unknown_skill", "Unknown Skill.")
      }
    ToolInvocation::AgentSkillsCall(call) => {
      let result = registry.call(host, call)
      match result.error() {
        None => tool_success(id, result.to_json())
        Some(error) =>
          tool_failure(
            id,
            error.code(),
            "Agent Skill execution failed.",
            details=result.to_json(),
          )
      }
    }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Inner : @agent.AgentHost] dispatch_secure_agent_skills_tool(
  registry : @agent.AgentSkillRegistry,
  host : @agent.AgentSecureSession[Inner],
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    ToolInvocation::AgentSkillsList =>
      tool_success(id, registry.list().to_json())
    ToolInvocation::AgentSkillsGet(skill_id) =>
      match registry.get(skill_id) {
        Some(skill) => tool_success(id, skill.to_json())
        None => tool_failure(id, "unknown_skill", "Unknown Skill.")
      }
    ToolInvocation::AgentSkillsCall(call) => {
      let result = host.execute_skill(registry, call)
      match result.error() {
        None => tool_success(id, result.to_json())
        Some(error) =>
          tool_failure(
            id,
            error.code(),
            "Agent Skill execution failed.",
            details=result.to_json(),
          )
      }
    }
    _ => tool_registry_mismatch(id)
  }
}
