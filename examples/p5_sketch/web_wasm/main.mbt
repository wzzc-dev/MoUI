///|
fn main {
  // The JS side of the rasterizer lives in index.html's `p5_raster` import
  // namespace; the boot-log probe proves the readback loop end to end.
  @web_raster.install()
  @web_raster.self_test()
  @apphost.run_app(
    "MoUI p5 Sketch",
    @runtime.new_program_with_dimensions(
      program=@p5_app.program(),
      width=1000.0,
      height=720.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
