///|
fn openseek_test_config() -> OpenSeekBackendConfig {
  {
    api_key: "test-key",
    api_url: None,
    model: @deepseek.Model::V4Flash,
    thinking: @deepseek.ThinkingMode::No,
    workspace_root: ".",
    session_root: ".openseek-test",
  }
}

///|
fn openseek_test_session(id : String) -> @agent_session.Session {
  @agent_session.Session(
    @agent_session.SessionId::SessionId(id),
    system_prompt="system",
  )
}

///|
async test "worker steer queues into active turn runtime" {
  @async.with_task_group() <| group => {
    let config = openseek_test_config()
    let owner = OpenSeekBackendOwner::new(config)
    let state = openseek_engine_state(config, openseek_test_session("active"))
    let active = group.spawn(no_wait=true, allow_failure=true) <| () => {
      @async.sleep(1000)
    }
    state.turn_task = Some(active)
    owner.engine.val = Some(state)
    let events : Array[@app.AgentEvent] = []
    openseek_worker_steer(owner, "go left", event => events.push(event))
    let steers = state.runtime.drain_steers()
    inspect(steers.length(), content="1")
    guard steers[0] is Prompt(text) else { fail("expected prompt steer") }
    inspect(text, content="go left")
    guard events[0] is @app.AgentEvent::RuntimeNoticeAdded(notice) else {
      fail("expected steer notice")
    }
    inspect(notice, content="Steer queued: go left")
    active.cancel()
  }
}

///|
async test "worker steer is rejected when no turn is running" {
  let config = openseek_test_config()
  let owner = OpenSeekBackendOwner::new(config)
  let state = openseek_engine_state(config, openseek_test_session("idle"))
  owner.engine.val = Some(state)
  let events : Array[@app.AgentEvent] = []
  openseek_worker_steer(owner, "too late", event => events.push(event))
  inspect(state.runtime.drain_steers().length(), content="0")
  guard events[0] is @app.AgentEvent::RuntimeNoticeAdded(notice) else {
    fail("expected idle steer notice")
  }
  inspect(notice, content="Steer ignored: no running turn")
}

///|
async test "worker send task is rejected while a turn is running" {
  @async.with_task_group() <| group => {
    let config = openseek_test_config()
    let owner = OpenSeekBackendOwner::new(config)
    let state = openseek_engine_state(config, openseek_test_session("active"))
    let active = group.spawn(no_wait=true, allow_failure=true) <| () => {
      @async.sleep(1000)
    }
    state.turn_task = Some(active)
    owner.engine.val = Some(state)
    let events : Array[@app.AgentEvent] = []
    openseek_worker_send_task(owner, group, "second task", event => {
      events.push(event)
    })
    inspect(events.length(), content="1")
    guard events[0] is @app.AgentEvent::RuntimeNoticeAdded(notice) else {
      fail("expected duplicate turn notice")
    }
    inspect(
      notice,
      content="OpenSeek turn already running; use Steer to adjust it.",
    )
    active.cancel()
  }
}
