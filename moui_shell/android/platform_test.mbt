///|
test "Android platform descriptor carries the typed native surface contract" {
  let surface = AndroidNativeSurface::new(raw=42UL)
  inspect(surface.raw, content="42")
  let descriptor = android_descriptor()
  assert_true(
    descriptor.negotiate(shell_api_version=1, embedding_api_version=1, required_capabilities=[
      Surface,
      FrameScheduling,
      HostChannel,
    ])
    is Compatible,
  )
}
