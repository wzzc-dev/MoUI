///|
struct HostCompletionSubscriptionModel {
  pending : HostServiceRequestId?
  selected : String
}

///|
test "host app services completion subscription dispatches typed messages" {
  let queue = HostServiceAsyncQueue::new()
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(file_dialogs=true),
    handle=request => {
      match request {
        FileDialog(_) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = HostAppServices::new(bridge~, async_queue=Some(queue))
  let pending_id = match services.open_file(title="Open") {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file dialog")
  }
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init={ pending: Some(pending_id), selected: "Pending completion" },
      update=(model, completion : HostCompletedServiceResponse) => {
        match completion.response {
          HostServiceResponse::FileDialogSelection(paths) =>
            {
              pending: None,
              selected: if paths.length() > 0 {
                paths[0]
              } else {
                "empty"
              },
            }
          HostServiceResponse::Unavailable(reason) =>
            { pending: None, selected: reason }
          _ => model
        }
      },
      view=model => @views.text(model.selected, width=260.0, height=24.0),
      subscriptions=model => {
        match model.pending {
          Some(id) =>
            services.completion_subscription(
              id,
              map=completion => completion,
              label="File dialog completion",
            )
          None => @core.Subscription::none()
        }
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  inspect(
    initial.active_subscriptions[0].key,
    content="host-service:completion:1",
  )
  inspect(initial.active_subscriptions[0].kind, content="host-service")
  inspect(
    initial.active_subscriptions[0].label,
    content="File dialog completion",
  )
  let pending = services.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    services.complete(
      pending_id,
      HostServiceResponse::FileDialogSelection(["/tmp/subscription.txt"]),
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: value, .. }) &&
      value == "/tmp/subscription.txt"
    }),
  )
  let completed = runtime.program_runtime_snapshot()
  inspect(completed.dispatched_count, content="1")
  inspect(completed.update_count, content="1")
  inspect(completed.active_subscription_count, content="0")
  inspect(completed.cancelled_subscription_count, content="1")
  inspect(services.completed_count(), content="0")
}

///|
test "host app services completion subscription cancels queue handler" {
  let queue = HostServiceAsyncQueue::new()
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(file_dialogs=true),
    handle=request => {
      match request {
        FileDialog(_) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = HostAppServices::new(bridge~, async_queue=Some(queue))
  let pending_id = match services.open_file(title="Open") {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file dialog")
  }
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init={ pending: Some(pending_id), selected: "Pending completion" },
      update=(model, completion : HostCompletedServiceResponse) => {
        match completion.response {
          HostServiceResponse::FileDialogSelection(paths) =>
            {
              pending: None,
              selected: if paths.length() > 0 {
                paths[0]
              } else {
                "empty"
              },
            }
          _ => model
        }
      },
      view=model => @views.text(model.selected, width=260.0, height=24.0),
      subscriptions=model => {
        match model.pending {
          Some(id) =>
            services.completion_subscription(
              id,
              map=completion => completion,
              label="File dialog completion",
            )
          None => @core.Subscription::none()
        }
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count, content="1")
  let pending = services.drain_pending()
  inspect(pending.length(), content="1")
  runtime.destroy()
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.active_subscription_count, content="0")
  inspect(destroyed.cancelled_subscription_count, content="1")
  assert_true(
    services.complete(
      pending_id,
      HostServiceResponse::FileDialogSelection(["/tmp/cancelled.txt"]),
    ),
  )
  inspect(services.completed_count(), content="1")
  inspect(
    runtime.program_runtime_snapshot().ignored_subscription_dispatch_count,
    content="0",
  )
  match services.take_completed(pending_id) {
    Some({ response: HostServiceResponse::FileDialogSelection(paths), .. }) =>
      inspect(paths[0], content="/tmp/cancelled.txt")
    _ => fail("expected cancelled subscription completion to remain queued")
  }
}
