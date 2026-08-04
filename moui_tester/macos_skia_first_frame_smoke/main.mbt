///|
fn main {
  @runtime.run_app("MoUI Text Input Smoke", @fixture.runtime())
  .render(
    @render_skia.raster(
      font_resolution=@render_skia.SkiaFontResolution::EmptyTypeface,
    ),
  )
  .backend(
    @macos.entry(
      smoke_options=@macos.MacosHostSmokeOptions::new(
        first_frame_smoke_auto_exit=true,
      ),
    ),
  )
  .run()
}
