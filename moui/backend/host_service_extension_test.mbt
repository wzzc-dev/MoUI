///|
test "host service capability labels include registered extensions" {
  let capabilities = @backend.HostServiceCapabilities::new(clipboard=true, extension_labels=[
    "database",
  ])
  let labels = capabilities.enabled_labels()
  assert_true(labels.contains("clipboard"))
  assert_true(labels.contains("database"))
}
