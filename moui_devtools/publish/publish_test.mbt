///|
test "devtools publisher builds a versioned document from a live runtime" {
  let root : @core.View[Unit] = @views.text("hello")
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=160.0, height=40.0),
  )
  ignore(runtime.layout())
  let publisher = @publish.DevtoolsPublisher::new(
    path="/tmp/moui-devtools-document-test.json",
    snapshot=() => Some(runtime.inspector_snapshot()),
    trace=() => None,
    diagnostics=() => [],
  )
  let document = match publisher.document() {
    Some(value) => value
    None => fail("expected a DevTools document")
  }
  inspect(document.schema_version, content="1")
  assert_true(document.report_text.length() > 0)
  let text = document.to_json_string()
  assert_true(text.contains("\"schema_version\": 1"))
  assert_true(text.contains("\"report_text\""))
}

///|
test "devtools publisher writes the document and skips missing snapshots" {
  let path = "/tmp/moui-devtools-publish-test.json"
  let root : @core.View[Unit] = @views.text("hello")
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=160.0, height=40.0),
  )
  ignore(runtime.layout())
  let publisher = @publish.DevtoolsPublisher::new(
    path~,
    snapshot=() => Some(runtime.inspector_snapshot()),
    trace=() => None,
    diagnostics=() => [],
  )
  publisher.publish()
  assert_true(@fs.path_exists(path))
  let text = @fs.read_file_to_string(path) catch { _ => "" }
  assert_true(text.contains("\"schema_version\": 1"))
  let empty = @publish.DevtoolsPublisher::new(
    path="/tmp/moui-devtools-empty-test.json",
    snapshot=() => None,
    trace=() => None,
    diagnostics=() => [],
  )
  empty.publish()
  assert_true(!@fs.path_exists("/tmp/moui-devtools-empty-test.json"))
}
