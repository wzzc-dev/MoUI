///|
test "HarmonyOS platform descriptor carries the typed XComponent contract" {
  let surface = HarmonyosNativeSurface::new(raw=42UL)
  inspect(surface.raw, content="42")
  let descriptor = harmonyos_descriptor()
  assert_true(
    descriptor.negotiate(shell_api_version=1, embedding_api_version=1, required_capabilities=[
      Surface,
      FrameScheduling,
      HostChannel,
    ])
    is Compatible,
  )
}
