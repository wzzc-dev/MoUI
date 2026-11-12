///|
test "inspect text prefers the published report text" {
  let text = "{\"schema_version\":1,\"reportText\":\"hello\",\"diagnostics\":[]}"
  inspect(inspect_document_text(text), content="hello")
}

///|
test "inspect text appends trace text and diagnostics" {
  let text = "{\"schema_version\":1,\"reportText\":\"report\",\"traceText\":\"trace\",\"diagnostics\":[{},{}]}"
  let rendered = inspect_document_text(text)
  assert_true(rendered.contains("report"))
  assert_true(rendered.contains("trace"))
  assert_true(rendered.contains("diagnostics: 2"))
}

///|
test "inspect text falls back to raw JSON when fields are absent" {
  let text = "{\"schema_version\":1}"
  inspect(inspect_document_text(text), content=text)
}

///|
test "inspect parser accepts --file and --json" {
  let parsed = match
    parse_inspect_args(["--file", "custom.json", "--json"], "/tmp") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(parsed.json, content="true")
  inspect(parsed.file.unwrap(), content="/tmp/custom.json")
}
