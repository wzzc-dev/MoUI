///|
test "Skia provider policy requires an explicit platform and GPU-first auto order" {
  let source =
    #|pub fn raster() {}
    #|pub fn gpu(platform~ : NativeGpuPlatform) {}
    #|pub fn from_env(
    #|  platform~ : NativeGpuPlatform,
    #|) {
    #|  let mode = @env.get_env_var("MOUI_SKIA_RENDERER")
    #|  ignore(NativeRendererMode::parse("auto"))
    #|  providers_for_mode(platform, mode)
    #|}
    #|fn providers_for_mode(platform : NativeGpuPlatform, mode) {
    #|  [gpu(platform~), raster()]
    #|}
  debug_inspect(
    validate_renderer_policy_source(source, "binding_factory.mbt"),
    content="[]",
  )
}

///|
test "legacy no-platform Skia factory policy is rejected" {
  let source =
    #|pub fn raster() {}
    #|pub fn gpu() {}
    #|pub fn from_env() {
    #|  ignore(@env.get_env_var("MOUI_SKIA_RENDERER"))
    #|  ignore(NativeRendererMode::parse("auto"))
    #|  [gpu(), raster()]
    #|}
  let failures = validate_renderer_policy_source(source, "binding_factory.mbt")
  assert_true(
    failures.any(failure => failure.contains("platform~ : NativeGpuPlatform")),
  )
  assert_true(
    failures.any(failure => {
      failure.contains("providers_for_mode(platform, mode)")
    }),
  )
  assert_true(
    failures.any(failure => failure.contains("[gpu(platform~), raster()]")),
  )
}
