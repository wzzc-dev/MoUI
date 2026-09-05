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
        snapshot
        .nodes()
        .any(node => {
          node.semantic_id ==
          Some(@core.SemanticId::parse("workbench.search.query").unwrap())
        }),
      )
      assert_true(
        snapshot
        .nodes()
        .any(node => {
          node.semantic_id ==
          Some(@core.SemanticId::parse("workbench.submit").unwrap())
        }),
      )
    }
    _ => fail("expected a committed workbench semantics snapshot")
  }
}

///|
test "console starts with a selected record and actionable demo state" {
  let model = Model::new()
  assert_true(model.selected_record == Some(101))
  assert_true(model.editor_value == "Northwind renewal")
  assert_true(model.console.active_step == DemoStep::ReadSemantics)
  assert_true(model.console.trace_entries == 0)
}

///|
test "offline Run demo pauses at a real confirmation checkpoint" {
  let model = Model::new()
  let driver = DemoDriver::offline()
  let (running, effect) = update_with_driver(model, RunDemo, driver)
  match effect {
    @moui.Effect::Run(_, run) => {
      let received : Array[Msg] = []
      run(message => received.push(message))
      assert_true(received.length() == 1)
      let paused = match received[0] {
        DemoResultReceived(result) =>
          update(running, DemoResultReceived(result))
        _ => fail("expected DemoResultReceived")
      }
      assert_true(paused.console.demo_status == DemoStatus::WaitingConfirmation)
      assert_true(paused.console.pending_confirmation is Some(_))
      assert_true(paused.console.trace_entries >= 5)
      assert_true(!paused.console.last_result.contains("northwind-security"))
    }
    _ => fail("expected demo effect")
  }
}

///|
test "approve advances the checkpoint and v2 replay reports the changed ID" {
  let model = Model::new()
  let first = DemoDriver::offline().run(DemoCommand::RunAll, {
    fixture_version: 1,
    selected_record: Some(101),
    query: "Northwind",
    selected_status: "All",
    snapshot: model.console,
  })
  let paused = update(model, DemoResultReceived(first))
  let approved = DemoDriver::offline().run(DemoCommand::Approve, {
    fixture_version: 1,
    selected_record: Some(101),
    query: "Northwind",
    selected_status: "All",
    snapshot: paused.console,
  })
  let transitioned = update(paused, DemoResultReceived(approved))
  assert_true(transitioned.console.pending_confirmations == 1)
  assert_true(
    transitioned.console.active_step == DemoStep::RequestExportConfirmation,
  )
  let v2 = { ..transitioned, fixture_version: 2 }
  let replay = DemoDriver::offline().run(DemoCommand::Replay, {
    fixture_version: 2,
    selected_record: Some(101),
    query: "Northwind",
    selected_status: "All",
    snapshot: v2.console,
  })
  assert_true(replay.snapshot.replay.status == "FAILED")
  assert_true(replay.snapshot.replay.actual_target == "workbench.export.v2")
}

///|
test "next step advances one checkpoint and reject records policy evidence" {
  let model = Model::new()
  let context : DemoContext = {
    fixture_version: model.fixture_version,
    selected_record: model.selected_record,
    query: model.query,
    selected_status: model.selected_status,
    snapshot: model.console,
  }
  let first = DemoDriver::offline().run(DemoCommand::NextStep, context)
  let stepped = update(model, DemoResultReceived(first))
  assert_true(stepped.console.active_step == DemoStep::Search)
  assert_eq(stepped.console.trace_entries, 1)

  let run = DemoDriver::offline().run(DemoCommand::RunAll, {
    ..context,
    snapshot: stepped.console,
  })
  let waiting = update(stepped, DemoResultReceived(run))
  let rejected = DemoDriver::offline().run(DemoCommand::Reject, {
    ..context,
    snapshot: waiting.console,
  })
  let failed = update(waiting, DemoResultReceived(rejected))
  assert_true(failed.console.demo_status == DemoStatus::Failed)
  assert_eq(failed.console.pending_confirmations, 0)
  assert_true(failed.console.policy.any(item => item.decision == "DENY"))
  assert_true(
    !failed.console.trace.any(item => item.result == "northwind-security"),
  )
}

///|
test "reset restores the initial fixture and clears reports" {
  let model = Model::new()
  let waiting = update(
    model,
    DemoResultReceived(
      DemoDriver::offline().run(DemoCommand::RunAll, {
        fixture_version: 2,
        selected_record: Some(101),
        query: "Northwind",
        selected_status: "All",
        snapshot: model.console,
      }),
    ),
  )
  let changed = {
    ..waiting,
    fixture_version: 2,
    submitted: true,
    exported: true,
  }
  let reset = DemoDriver::offline().run(DemoCommand::Reset, {
    fixture_version: changed.fixture_version,
    selected_record: changed.selected_record,
    query: changed.query,
    selected_status: changed.selected_status,
    snapshot: changed.console,
  })
  let restored = update(changed, DemoResultReceived(reset))
  assert_eq(restored.fixture_version, 1)
  assert_eq(restored.selected_record, Some(101))
  assert_true(!restored.submitted)
  assert_true(!restored.exported)
  assert_eq(restored.console.trace_entries, 0)
  assert_eq(restored.console.replay.status, "not run")
  assert_eq(restored.console.audit.status, "not run")
}
