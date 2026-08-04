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
