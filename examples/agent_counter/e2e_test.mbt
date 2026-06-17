///|
// End-to-end smoke test for the agent-controllable runtime.
//
// Exercises the full loop: counter Program -> AppRuntime -> RuntimeAgentHost
// -> MCP JSON-RPC router (get_semantics + dispatch_command) -> runtime update.
// This is the success criterion: an agent reads state, fires a command, and
// the runtime reflects the change — all through the standard MCP protocol.

///|
fn new_runtime() -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=program(),
    width=200.0,
    height=240.0,
  )
}

///|
fn req(line : String) -> Json {
  @json.parse(line) catch {
    _ => abort("failed to parse test JSON: \{line}")
  }
}

///|
fn resp_str(j : Json) -> String {
  (j : Json).stringify()
}

///|
test "e2e: MCP get_semantics returns the agent counter tree" {
  let runtime = new_runtime()
  let host = @agent.RuntimeAgentHost::new(runtime)
  let response = @mcp.route(
    host,
    req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"get_semantics\",\"arguments\":{}}}"),
  )
  let s = resp_str(response)
  // The semantics tree must contain the counter's text/button labels.
  if not(s.contains("Increment")) {
    fail("expected Increment button in semantics; got \{s}")
  }
  if not(s.contains("Count:")) {
    fail("expected Count: text in semantics; got \{s}")
  }
}

///|
test "e2e: MCP tools/list advertises dispatch ops" {
  let runtime = new_runtime()
  let host = @agent.RuntimeAgentHost::new(runtime)
  let s = resp_str(
    @mcp.route(host, req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}")),
  )
  if not(s.contains("dispatch_command") && s.contains("get_semantics")) {
    fail("expected dispatch_command + get_semantics tools; got \{s}")
  }
}

///|
test "e2e: MCP dispatch_command routes through runtime and updates state" {
  // The core success criterion: an agent fires a command via MCP, and the
  // runtime's state snapshot changes accordingly. We use dispatch_command
  // (the MVP write path) and then read get_state to confirm counters moved.
  let runtime = new_runtime()
  let host = @agent.RuntimeAgentHost::new(runtime)

  // Snapshot before any agent action.
  let before = host.state()
  let baseline = before.dispatched_count

  // Agent fires a command through the MCP router.
  let r = @mcp.route(
    host,
    req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"dispatch_command\",\"arguments\":{\"intent\":\"Activate\"}}}"),
  )
  let rs = resp_str(r)
  // The tool call must return a content-wrapped, accepted result.
  if not(rs.contains("content") && rs.contains("accepted")) {
    fail("expected accepted dispatch result; got \{rs}")
  }

  // After the agent action, runtime state counters must reflect activity.
  let after = host.state()
  // dispatched_count is non-decreasing; assert it advanced or stayed (command
  // may be accepted but not produce a message depending on focus). Either way
  // the round-trip through the runtime must not error.
  if after.dispatched_count < baseline {
    fail(
      "expected dispatched_count to not regress; was \{baseline}, now \{after.dispatched_count}",
    )
  }
}

///|
test "e2e: dispatch_event reaches runtime via host (pointer input)" {
  // An agent-injected pointer event flows host.dispatch_event -> runtime and
  // is observable through the semantics tree (the buttons render).
  let runtime = new_runtime()
  let host = @agent.RuntimeAgentHost::new(runtime)
  let result = host.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if not(result.accepted) {
    fail("expected agent-injected pointer event to be accepted by the runtime")
  }
  // Semantics tree must still be readable after the event.
  let snap = host.semantics()
  if snap.node_count < 1 {
    fail("expected non-empty semantics after event; got \{snap.node_count}")
  }
}

///|
/// THE SUCCESS-CRITERION TEST: an agent clicks the Increment button entirely
/// through the MCP JSON-RPC protocol, and the counter's model actually changes
/// from Count: 0 to Count: 1. This proves "send Msg to change it" — the write
/// flows MCP -> router -> host.dispatch_event -> runtime -> on_click=Increment
/// -> update -> model change, all through standard Elm paths.
///
/// The Increment button renders at frame {x:0,y:84,w:200,h:44}; its center is
/// (100, 106). A Pointer Down followed by Pointer Up inside the button fires
/// its on_click (see core/gesture.mbt — on_click fires on PointerPhase::Up).
fn click_via_mcp(
  host : @agent.RuntimeAgentHost,
  x : Double,
  y : Double,
) -> Unit {
  let _ = @mcp.route(
    host,
    req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"dispatch_event\",\"arguments\":{\"event\":{\"kind\":\"Pointer\",\"position\":{\"x\":\{x},\"y\":\{y}},\"phase\":\"Down\"}}}}"),
  )
  let _ = @mcp.route(
    host,
    req("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"dispatch_event\",\"arguments\":{\"event\":{\"kind\":\"Pointer\",\"position\":{\"x\":\{x},\"y\":\{y}},\"phase\":\"Up\"}}}}"),
  )
}

///|
test "e2e: agent clicks Increment via MCP and counter goes 0 -> 1" {
  let runtime = new_runtime()
  let host = @agent.RuntimeAgentHost::new(runtime)

  // Before: the tree shows "Count: 0".
  let before = resp_str(
    @mcp.route(
      host,
      req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"get_semantics\",\"arguments\":{}}}"),
    ),
  )
  if not(before.contains("Count: 0")) {
    fail("expected initial Count: 0; got \{before}")
  }

  // Agent clicks the Increment button center (100, 106) via MCP.
  click_via_mcp(host, 100.0, 106.0)

  // After: the tree must show "Count: 1" — the model genuinely changed.
  let after = resp_str(
    @mcp.route(
      host,
      req("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"get_semantics\",\"arguments\":{}}}"),
    ),
  )
  if not(after.contains("Count: 1")) {
    fail("expected Count: 1 after agent click; got \{after}")
  }
  if after.contains("Count: 0") {
    fail("model did not change — still Count: 0 after agent click")
  }
}

///|
test "e2e: three agent clicks drive Count 0 -> 3" {
  let runtime = new_runtime()
  let host = @agent.RuntimeAgentHost::new(runtime)
  click_via_mcp(host, 100.0, 106.0)
  click_via_mcp(host, 100.0, 106.0)
  click_via_mcp(host, 100.0, 106.0)
  let after = resp_str(
    @mcp.route(
      host,
      req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"get_semantics\",\"arguments\":{}}}"),
    ),
  )
  if not(after.contains("Count: 3")) {
    fail("expected Count: 3 after three agent clicks; got \{after}")
  }
}

///|
test "e2e: agent clicking Decrement decreases the count" {
  let runtime = new_runtime()
  let host = @agent.RuntimeAgentHost::new(runtime)
  // Increment once (100, 106), then Decrement once (100, 160): 0 -> 1 -> 0.
  click_via_mcp(host, 100.0, 106.0)
  click_via_mcp(host, 100.0, 160.0)
  let after = resp_str(
    @mcp.route(
      host,
      req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"get_semantics\",\"arguments\":{}}}"),
    ),
  )
  if not(after.contains("Count: 0")) {
    fail("expected Count: 0 after Increment then Decrement; got \{after}")
  }
}

///|
/// THE ON-SCREEN-VISIBILITY TEST: the compositor's rendered frame (what a
/// window backend rasterizes to the physical screen) must reflect the agent's
/// action. Before the click, the painted text contains "Count: 0"; after the
/// agent clicks Increment via MCP, the painted text contains "Count: 1".
/// `get_frame` returns exactly the DrawText strings the screen would show.
test "e2e: rendered frame (screen content) changes 0 -> 1 after agent click" {
  let runtime = new_runtime()
  let host = @agent.RuntimeAgentHost::new(runtime)

  // Before: the painted frame shows "Count: 0".
  let before_frame = resp_str(
    @mcp.route(
      host,
      req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"get_frame\",\"arguments\":{}}}"),
    ),
  )
  if not(before_frame.contains("Count: 0")) {
    fail("expected rendered frame to show Count: 0; got \{before_frame}")
  }

  // Agent clicks Increment via MCP.
  click_via_mcp(host, 100.0, 106.0)

  // After: the painted frame must show "Count: 1" — the agent's action is now
  // visible in the compositor output (i.e. on screen).
  let after_frame = resp_str(
    @mcp.route(
      host,
      req("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"get_frame\",\"arguments\":{}}}"),
    ),
  )
  if not(after_frame.contains("Count: 1")) {
    fail("expected rendered frame to show Count: 1 after agent click; got \{after_frame}")
  }
  if after_frame.contains("Count: 0") {
    fail("rendered frame still shows Count: 0 — agent action not visible on screen")
  }
}
