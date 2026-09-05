///|
fn main {
  @runtime.run_app("MoUI AI-Native UI Inspector", @app.runtime())
  .render_all(@skia.from_env(platform=@skia.NativeGpuPlatform::Linux))
  .backend(@linux.entry())
  .run()
}
