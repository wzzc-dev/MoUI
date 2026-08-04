///|
test "app service adapter hides host request ids and maps completion" {
  let queue = HostServiceAsyncQueue::new()
  let services = app_services(
    bridge=HostServiceBridge::new(
      capabilities=HostServiceCapabilities::new(file_access=true),
      handle=request => queue.submit(request),
    ),
    async_queue=Some(queue),
  )
  let results : Array[@services.ServiceTaskResult[String]] = []
  let task = services.files().read_text("/doc.md")
  let cleanup = task.start(result => results.push(result))
  let pending = queue.drain_pending()
  assert_eq(pending.length(), 1)
  assert_true(
    queue.complete(
      pending[0].id,
      HostServiceResponse::TextFileContent("/doc.md", "hello"),
    ),
  )
  assert_eq(results, [@services.ServiceTaskResult::Success("hello")])
  assert_true(cleanup is Some(_))
}

///|
test "cancelled app service task suppresses late host completion" {
  let queue = HostServiceAsyncQueue::new()
  let services = app_services(
    bridge=HostServiceBridge::new(
      capabilities=HostServiceCapabilities::new(clipboard=true),
      handle=request => queue.submit(request),
    ),
    async_queue=Some(queue),
  )
  let results : Array[@services.ServiceTaskResult[String]] = []
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
    queue.complete(pending[0].id, HostServiceResponse::ClipboardText("late")),
  )
  assert_true(results.is_empty())
  assert_eq(queue.completed_count(), 1)
}

///|
test "app service adapter maps system appearance without exposing host protocol" {
  let services = app_services(
    bridge=HostServiceBridge::new(
      capabilities=HostServiceCapabilities::new(system_theme=true),
      handle=request => {
        match request {
          QuerySystemTheme =>
            HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
          _ => HostServiceResponse::Unavailable("unsupported")
        }
      },
    ),
  )
  let result : Ref[@services.ServiceTaskResult[@core.ColorScheme]?] = Ref(None)
  ignore(
    services
    .appearance()
    .system_color_scheme()
    .start(value => result.val = Some(value)),
  )
  assert_eq(
    result.val,
    Some(@services.ServiceTaskResult::Success(@core.ColorScheme::Dark)),
  )
}

///|
test "app service adapter maps persistent settings operations" {
  let values : Map[String, String] = Map([])
  let app = app_services(
    bridge=HostServiceBridge::new(
      capabilities=HostServiceCapabilities::new(settings=true),
      handle=request => {
        match request {
          Settings(Read(key)) =>
            HostServiceResponse::SettingValue(values.get(key))
          Settings(Write(key, value)) => {
            values[key] = value
            HostServiceResponse::SettingWritten
          }
          Settings(Remove(key)) => {
            values.remove(key)
            HostServiceResponse::SettingRemoved
          }
          _ => HostServiceResponse::Unavailable("unsupported")
        }
      },
    ),
  )
  let services = app.settings()
  let writes : Array[@services.ServiceTaskResult[Unit]] = []
  ignore(
    services.write("editor/theme", "dark").start(result => writes.push(result)),
  )
  assert_eq(writes, [@services.ServiceTaskResult::Success(())])
  let reads : Array[@services.ServiceTaskResult[String?]] = []
  ignore(services.read("editor/theme").start(result => reads.push(result)))
  assert_eq(reads, [@services.ServiceTaskResult::Success(Some("dark"))])
  let removes : Array[@services.ServiceTaskResult[Unit]] = []
  ignore(services.remove("editor/theme").start(result => removes.push(result)))
  assert_eq(removes, [@services.ServiceTaskResult::Success(())])
  let missing : Array[@services.ServiceTaskResult[String?]] = []
  ignore(services.read("editor/theme").start(result => missing.push(result)))
  assert_eq(missing, [@services.ServiceTaskResult::Success(None)])
}
