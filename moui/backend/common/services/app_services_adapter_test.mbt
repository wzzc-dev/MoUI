///|
test "app service adapter hides host request ids and maps completion" {
  let queue = ServiceAsyncQueue::new()
  let services = app_services(
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
    queue.complete(
      pending[0].id,
      @backend_host.HostServiceResponse::TextFileContent("/doc.md", "hello"),
    ),
  )
  assert_eq(results, [@app_services.ServiceTaskResult::Success("hello")])
  assert_true(cleanup is Some(_))
}

///|
test "cancelled app service task suppresses late host completion" {
  let queue = ServiceAsyncQueue::new()
  let services = app_services(
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
  assert_true(
    queue.complete(
      pending[0].id,
      @backend_host.HostServiceResponse::ClipboardText("late"),
    ),
  )
  assert_true(results.is_empty())
  assert_eq(queue.completed_count(), 1)
}

///|
test "app service adapter maps system appearance without exposing host protocol" {
  let services = app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(system_theme=true),
      handle=request => {
        match request {
          @backend_host.HostServiceRequest::QuerySystemTheme =>
            @backend_host.HostServiceResponse::SystemTheme(
              @core.ColorScheme::Dark,
            )
          _ => @backend_host.HostServiceResponse::Unavailable("unsupported")
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
  assert_eq(
    result.val,
    Some(@app_services.ServiceTaskResult::Success(@core.ColorScheme::Dark)),
  )
}

///|
test "app service adapter maps persistent settings operations" {
  let values : Map[String, String] = Map([])
  let app = app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(settings=true),
      handle=request => {
        match request {
          @backend_host.HostServiceRequest::Settings(
            @backend_host.HostSettingsRequest::Read(key)
          ) => @backend_host.HostServiceResponse::SettingValue(values.get(key))
          @backend_host.HostServiceRequest::Settings(
            @backend_host.HostSettingsRequest::Write(key, value)
          ) => {
            values[key] = value
            @backend_host.HostServiceResponse::SettingWritten
          }
          @backend_host.HostServiceRequest::Settings(
            @backend_host.HostSettingsRequest::Remove(key)
          ) => {
            values.remove(key)
            @backend_host.HostServiceResponse::SettingRemoved
          }
          _ => @backend_host.HostServiceResponse::Unavailable("unsupported")
        }
      },
    ),
  )
  let services = app.settings()
  let writes : Array[@app_services.ServiceTaskResult[Unit]] = []
  ignore(
    services.write("editor/theme", "dark").start(result => writes.push(result)),
  )
  assert_eq(writes, [@app_services.ServiceTaskResult::Success(())])
  let reads : Array[@app_services.ServiceTaskResult[String?]] = []
  ignore(services.read("editor/theme").start(result => reads.push(result)))
  assert_eq(reads, [@app_services.ServiceTaskResult::Success(Some("dark"))])
  let removes : Array[@app_services.ServiceTaskResult[Unit]] = []
  ignore(services.remove("editor/theme").start(result => removes.push(result)))
  assert_eq(removes, [@app_services.ServiceTaskResult::Success(())])
  let missing : Array[@app_services.ServiceTaskResult[String?]] = []
  ignore(services.read("editor/theme").start(result => missing.push(result)))
  assert_eq(missing, [@app_services.ServiceTaskResult::Success(None)])
}

///|
test "app service adapter preserves application menu placement" {
  let received : Ref[@backend_host.HostServiceRequest?] = Ref(None)
  let services = app_services(
    bridge=@backend_host.HostServiceBridge::new(
      capabilities=@backend_host.HostServiceCapabilities::new(menus=true),
      handle=request => {
        received.val = Some(request)
        @backend_host.HostServiceResponse::ApplicationMenuInstalled
      },
    ),
  )
  let command = @core.ActionCommand::new(
    intent=@core.CommandIntent::Activate,
    label="Settings",
  )
  ignore(
    services
    .menus()
    .install_application([
      @app_services.ApplicationMenu::application(items=[
        @app_services.ApplicationMenuItem::MenuCommand(command),
      ]),
    ])
    .start(_ => ()),
  )
  match received.val {
    Some(@backend_host.HostServiceRequest::SetApplicationMenu([menu])) => {
      assert_true(
        menu.placement
        is @backend_host.HostApplicationMenuPlacement::ApplicationMenu,
      )
      assert_eq(menu.items.length(), 1)
    }
    _ => fail("expected one application-menu host request")
  }
}
