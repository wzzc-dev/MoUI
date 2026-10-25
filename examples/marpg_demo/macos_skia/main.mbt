///|
/// The composition root: the only place the slice names a renderer and a platform
/// backend.  The window is the J2ME canvas the engine was written for (240x320), so
/// the map, sprites and text are drawn 1:1 -- no frame rate is claimed here.
fn main raise {
  let environment = @macos.app_environment()
  @runtime.run_app(
    "仙剑问情 · 引擎竖切",
    @runtime.new_program_with_dimensions(
      program=@marpg.program(environment~),
      width=240.0,
      height=320.0,
    ),
  )
  .render_all(@render_skia.from_env(platform=MacOS))
  .backend(@macos.entry())
  .run()
}
