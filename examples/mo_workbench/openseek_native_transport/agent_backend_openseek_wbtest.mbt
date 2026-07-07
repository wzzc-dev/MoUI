///|
test "finished terminal answer projects as assistant message" {
  let answer =
    #|我可以帮助你完成各种 MoonBit 编程任务，包括但不限于：
    #|
    #|## 核心能力
    #|
    #|1. **代码实现** - 根据你的需求编写 MoonBit 代码
    #|2. **类型检查与修复** - 运行 `moon check` 并修复错误
  let events = openseek_item_to_agent_events(
    @agent_session.SessionItem::Terminal(
      @agent_session.TurnTerminal::Finished(answer),
    ),
  )
  inspect(events.length(), content="2")
  guard events[0] is @app.AgentEvent::AssistantMessageAdded(content, reasoning) else {
    fail("expected assistant message")
  }
  assert_true(content.contains("## 核心能力"))
  assert_true(content.contains("**代码实现**"))
  match reasoning {
    None => ()
    Some(_) => fail("expected no reasoning for terminal answer projection")
  }
  guard events[1] is @app.AgentEvent::TurnTerminal(status, message) else {
    fail("expected terminal status")
  }
  inspect(status == @app.TurnStatus::Finished, content="true")
  inspect(message, content="")
}
