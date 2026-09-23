///|
test "app service adapter hides host request ids and maps completion" {
  let queue = @services.ServiceAsyncQueue::new()
  let services = @services.app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(file_access=true),
      handle=request => queue.submit(request),
    ),
    async_queue=Some(queue),
  )
  let results : Array[@app_services.ServiceTaskResult[String]] = []
  let task = services.files().read_text("/doc.md")
  let cleanup = task.start(result => results.push(result))
  let pending = queue.drain_pending()
  assert_eq(pending.length(), 1)
  assert_true(
    queue.complete(pending[0].id, TextFileContent("/doc.md", "hello")),
  )
  assert_eq(results, [Success("hello")])
  assert_true(cleanup is Some(_))
}

///|
test "cancelled app service task suppresses late host completion" {
  let queue = @services.ServiceAsyncQueue::new()
  let services = @services.app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(clipboard=true),
      handle=request => queue.submit(request),
    ),
    async_queue=Some(queue),
  )
  let results : Array[@app_services.ServiceTaskResult[String]] = []
  let cleanup = services
    .clipboard()
    .read_text()
    .start(result => results.push(result))
  let pending = queue.drain_pending()
  match cleanup {
    Some(cancel) => cancel()
    None => fail("expected cancellation cleanup")
  }
  assert_true(queue.complete(pending[0].id, ClipboardText("late")))
  assert_true(results.is_empty())
  assert_eq(queue.completed_count(), 1)
}

///|
test "app service adapter maps system appearance without exposing host protocol" {
  let services = @services.app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(system_theme=true),
      handle=request => {
        match request {
          QuerySystemTheme => SystemTheme(Dark)
          _ => Unavailable("unsupported")
        }
      },
    ),
  )
  let result : Ref[@app_services.ServiceTaskResult[@core.ColorScheme]?] = Ref(
    None,
  )
  ignore(
    services
    .appearance()
    .system_color_scheme()
    .start(value => result.val = Some(value)),
  )
  assert_eq(result.val, Some(Success(Dark)))
}

///|
test "app service adapter maps persistent settings operations" {
  let values : Map[String, String] = Map([])
  let app = @services.app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(settings=true),
      handle=request => {
        match request {
          Settings(Read(key)) => SettingValue(values.get(key))
          Settings(Write(key, value)) => {
            values[key] = value
            SettingWritten
          }
          Settings(Remove(key)) => {
            values.remove(key)
            SettingRemoved
          }
          _ => Unavailable("unsupported")
        }
      },
    ),
  )
  let services = app.settings()
  let writes : Array[@app_services.ServiceTaskResult[Unit]] = []
  ignore(
    services.write("editor/theme", "dark").start(result => writes.push(result)),
  )
  assert_eq(writes, [Success(())])
  let reads : Array[@app_services.ServiceTaskResult[String?]] = []
  ignore(services.read("editor/theme").start(result => reads.push(result)))
  assert_eq(reads, [Success(Some("dark"))])
  let removes : Array[@app_services.ServiceTaskResult[Unit]] = []
  ignore(services.remove("editor/theme").start(result => removes.push(result)))
  assert_eq(removes, [Success(())])
  let missing : Array[@app_services.ServiceTaskResult[String?]] = []
  ignore(services.read("editor/theme").start(result => missing.push(result)))
  assert_eq(missing, [Success(None)])
}

///|
test "app service adapter preserves application menu placement" {
  let received : Ref[@backend_host.HostServiceRequest?] = Ref(None)
  let services = @services.app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(menus=true),
      handle=request => {
        received.val = Some(request)
        ApplicationMenuInstalled
      },
    ),
  )
  let command = @core.ActionCommand::new(intent=Activate, label="Settings")
  ignore(
    services
    .menus()
    .install_application([
      @app_services.ApplicationMenu::application(items=[MenuCommand(command)]),
    ])
    .start(_ => ()),
  )
  match received.val {
    Some(SetApplicationMenu([menu])) => {
      assert_true(menu.placement is ApplicationMenu)
      assert_eq(menu.items.length(), 1)
    }
    _ => fail("expected one application-menu host request")
  }
}

///|
test "app service adapter routes platform services through typed operations" {
  let requests : Array[@backend_host.PlatformChannelRequest] = []
  let services = @services.app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::none(),
      handle=request => {
        match request {
          PlatformChannel(value) => {
            requests.push(value)
            match value.operation {
              "permission.request" => PlatformChannel(Ok("granted"))
              _ => PlatformChannel(Ok("ok"))
            }
          }
          _ => Unavailable("unexpected")
        }
      },
    ),
  )
  let notification = @app_services.NotificationRequest::new(
    id="ready",
    title="Ready",
    body="Done",
  )
  let permission : Ref[
    @app_services.ServiceTaskResult[@app_services.PermissionStatus]?,
  ] = Ref(None)
  ignore(
    services.platform().notifications().notify(notification).start(_ => ()),
  )
  ignore(
    services
    .platform()
    .permissions()
    .request(Notifications)
    .start(result => permission.val = Some(result)),
  )
  assert_eq(requests.length(), 2)
  assert_eq(requests[0].channel, "moui.platform")
  assert_eq(requests[0].operation, "notification.send")
  assert_true(requests[0].payload.contains("\"ready\""))
  assert_eq(requests[1].operation, "permission.request")
  assert_eq(permission.val, Some(Success(Granted)))
}

///|
test "app service adapter preserves platform unavailable responses" {
  let services = @services.app_services(
    bridge=@backend_host.HostServiceBridge::unavailable(),
  )
  let results : Array[@app_services.ServiceTaskResult[Unit]] = []
  ignore(
    services
    .platform()
    .printing()
    .print(@app_services.PrintRequest::new(title="Export", text="hello"))
    .start(result => results.push(result)),
  )
  match results {
    [Failure(error)] => assert_eq(error.code, "unavailable")
    _ => fail("expected unavailable platform service")
  }
}

///|
test "app environment accepts a host lifecycle source" {
  let lifecycle = @app_services.AppLifecycleSource::new()
  let environment = @services.app_environment(
    bridge=@backend_host.HostServiceBridge::unavailable(),
    lifecycle=Some(lifecycle),
  )
  assert_true(environment.services().platform().lifecycle() is Some(_))
}
