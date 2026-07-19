///|
test "iOS platform descriptor carries the typed view contract" {
  let view = IosNativeView::new(raw=42UL)
  inspect(view.raw, content="42")
  let descriptor = ios_descriptor()
  assert_true(
    descriptor.negotiate(shell_api_version=1, embedding_api_version=1, required_capabilities=[
      Surface,
      FrameScheduling,
      HostChannel,
    ])
    is Compatible,
  )
}
