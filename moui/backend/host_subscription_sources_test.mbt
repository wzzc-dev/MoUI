///|
test "host event source subscription dispatches mapped host events" {
  let source = @runtime.HostEventSource::new()
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=240.0, height=24.0),
      subscriptions=_model => {
        source.subscription(key="host:event", label="Host event adapter", map=event => {
          match event {
            Event::ThemeChanged(_) => Some("theme changed")
            _ => None
          }
        })
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count(), content="1")
  inspect(initial.active_subscriptions()[0].key(), content="host:event")
  inspect(initial.active_subscriptions()[0].kind(), content="host-event")
  inspect(
    initial.active_subscriptions()[0].label(),
    content="Host event adapter",
  )
  inspect(source.publish(Event::RedrawRequested), content="1")
  inspect(runtime.program_runtime_snapshot().dispatched_count(), content="0")
  inspect(
    source.publish(Event::ThemeChanged(@core.ColorScheme::Dark)),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count(), content="1")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text, .. }) &&
      text == "theme changed"
    }),
  )
}

///|
test "host event source subscription cleanup removes late publishers" {
  let source = @runtime.HostEventSource::new()
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=240.0, height=24.0),
      subscriptions=_model => {
        source.subscription(key="host:event", label="Host event adapter", map=event => {
          match event {
            Event::ThemeChanged(_) => Some("theme changed")
            _ => None
          }
        })
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  runtime.destroy()
  inspect(source.active_handler_count(), content="0")
  inspect(
    source.publish(Event::ThemeChanged(@core.ColorScheme::Dark)),
    content="0",
  )
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.cancelled_subscription_count(), content="1")
  inspect(destroyed.ignored_subscription_dispatch_count(), content="0")
}

///|
test "host platform event sources publish host and window subscriptions" {
  let sources = @runtime.HostPlatformEventSources::new()
  let window_id = WindowId::new(9)
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=280.0, height=24.0),
      subscriptions=_model => {
        @core.Subscription::batch([
          sources
          .host_events()
          .subscription(key="host:event", label="Host event adapter", map=event => {
            match event {
              Event::ThemeChanged(_) => Some("host theme")
              _ => None
            }
          }),
          sources
          .window_events()
          .subscription(
            key="host:window-event",
            label="Host window event adapter",
            map=event => {
              if event.window_id == window_id {
                Some("window \{event.window_id.value.to_string()}")
              } else {
                None
              }
            },
          ),
        ])
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(sources.host_events().active_handler_count(), content="1")
  inspect(sources.window_events().active_handler_count(), content="1")
  let result = sources.publish(
    window_id~,
    event=Event::ThemeChanged(@core.ColorScheme::Dark),
  )
  inspect(result.host_event_count, content="1")
  inspect(result.window_event_count, content="1")
  inspect(runtime.program_runtime_snapshot().dispatched_count(), content="2")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text, .. }) && text == "window 9"
    }),
  )
}

///|
test "host window event source subscription dispatches mapped window events" {
  let source = @runtime.HostWindowEventSource::new()
  let target = WindowId::new(7)
  let other = WindowId::new(8)
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=240.0, height=24.0),
      subscriptions=_model => {
        source.subscription(
          key="host:window-event",
          label="Host window event adapter",
          map=window_event => {
            if window_event.window_id == target {
              match window_event.event {
                Event::CloseRequested =>
                  Some(
                    "window \{window_event.window_id.value.to_string()} close",
                  )
                _ => None
              }
            } else {
              None
            }
          },
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  let initial = runtime.program_runtime_snapshot()
  inspect(initial.active_subscription_count(), content="1")
  inspect(initial.active_subscriptions()[0].key(), content="host:window-event")
  inspect(initial.active_subscriptions()[0].kind(), content="window-event")
  inspect(
    initial.active_subscriptions()[0].label(),
    content="Host window event adapter",
  )
  inspect(
    source.publish(window_id=other, event=Event::CloseRequested),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count(), content="0")
  inspect(
    source.publish(window_id=target, event=Event::RedrawRequested),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count(), content="0")
  inspect(
    source.publish(window_id=target, event=Event::CloseRequested),
    content="1",
  )
  inspect(runtime.program_runtime_snapshot().dispatched_count(), content="1")
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text, .. }) &&
      text == "window 7 close"
    }),
  )
}

///|
test "host window event source subscription cleanup removes late publishers" {
  let source = @runtime.HostWindowEventSource::new()
  let window_id = WindowId::new(1)
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init="idle",
      update=(_model, message : String) => message,
      view=model => @views.text(model, width=240.0, height=24.0),
      subscriptions=_model => {
        source.subscription(
          key="host:window-event",
          label="Host window event adapter",
          map=_window_event => Some("window event"),
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  inspect(source.active_handler_count(), content="1")
  runtime.destroy()
  inspect(source.active_handler_count(), content="0")
  inspect(source.publish(window_id~, event=Event::CloseRequested), content="0")
  let destroyed = runtime.program_runtime_snapshot()
  inspect(destroyed.cancelled_subscription_count(), content="1")
  inspect(destroyed.ignored_subscription_dispatch_count(), content="0")
}
