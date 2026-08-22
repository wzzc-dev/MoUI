///|
test "FakeAppServices records deterministic file clipboard and settings work" {
  let fake = @services.FakeAppServices::new()
  fake.set_text_file("/doc.md", "hello")
  let values : Array[String] = []
  let clipboard_succeeded = Ref(false)
  let settings_succeeded = Ref(false)
  ignore(
    fake
    .services()
    .files()
    .read_text("/doc.md")
    .start(result => {
      match result {
        Success(text) => values.push(text)
        _ => ()
      }
    }),
  )
  ignore(
    fake
    .services()
    .clipboard()
    .write_text("copied")
    .start(result => {
      match result {
        Success(_) => clipboard_succeeded.val = true
        _ => ()
      }
    }),
  )
  ignore(
    fake
    .services()
    .settings()
    .write("theme", "dark")
    .start(result => {
      match result {
        Success(_) => settings_succeeded.val = true
        _ => ()
      }
    }),
  )
  assert_eq(values, ["hello"])
  assert_true(clipboard_succeeded.val)
  assert_true(settings_succeeded.val)
  assert_eq(fake.clipboard_text(), "copied")
  assert_eq(fake.calls(), [
    "file:read-text:/doc.md", "clipboard:write-text", "settings:write:theme",
  ])
}

///|
test "FakeAppServices provides deterministic system appearance" {
  let fake = FakeAppServices::new()
  fake.set_system_color_scheme(@core.ColorScheme::Dark)
  let result : Ref[ServiceTaskResult[@core.ColorScheme]?] = Ref(None)
  ignore(
    fake
    .services()
    .appearance()
    .system_color_scheme()
    .start(value => result.val = Some(value)),
  )
  assert_eq(result.val, Some(Success(@core.ColorScheme::Dark)))
  assert_eq(fake.calls(), ["appearance:system-color-scheme"])
}

///|
test "FakeAppServices covers platform services and lifecycle" {
  let fake = @services.FakeAppServices::new()
  fake.set_permission_status(
    @services.PermissionKind::Notifications,
    @services.PermissionStatus::Granted,
  )
  let notification = @services.NotificationRequest::new(
    id="build-finished",
    title="Build",
    body="Complete",
  )
  let tray = @services.TrayItem::new(
    id="moui",
    label="MoUI",
    tooltip="MoUI status",
  )
  let permission : Ref[@services.ServiceTaskResult[@services.PermissionStatus]?] = Ref(
    None,
  )
  let lifecycle_events : Array[@services.AppLifecycleEvent] = []
  match fake.services().platform().lifecycle() {
    Some(source) => {
      let subscription = source.subscription(map=event => event)
      ignore(
        subscription.runtime_sources()[0].start(event => {
          lifecycle_events.push(event)
        }),
      )
    }
    None => fail("expected fake lifecycle source")
  }
  ignore(
    fake
    .services()
    .platform()
    .notifications()
    .notify(notification)
    .start(_ => ()),
  )
  ignore(fake.services().platform().tray().set(tray).start(_ => ()))
  ignore(
    fake
    .services()
    .platform()
    .permissions()
    .request(@services.PermissionKind::Notifications)
    .start(result => permission.val = Some(result)),
  )
  ignore(
    fake
    .services()
    .platform()
    .window_state()
    .write("main", "{\"x\":10}")
    .start(_ => ()),
  )
  ignore(fake.publish_lifecycle(@services.AppLifecycleEvent::Background))
  assert_eq(permission.val, Some(Success(@services.PermissionStatus::Granted)))
  assert_eq(lifecycle_events, [@services.AppLifecycleEvent::Background])
  assert_true(fake.notification("build-finished") is Some(_))
  assert_true(fake.tray_item("moui") is Some(_))
  assert_eq(fake.calls(), [
    "notification:send:build-finished", "tray:set:moui", "permission:request", "window-state:write:main",
    "lifecycle:publish",
  ])
}
