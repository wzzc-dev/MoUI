///|
/// Synthetic slider-drag latency smoke over the Skia GPU renderer route.
fn main {
  @apphost.run_app("MoUI Slider Drag Smoke", @fixture.runtime())
  .render(@render_skia.gpu(platform=MacOS))
  .backend(
    @macos.entry(
      smoke_options=@macos.MacosHostSmokeOptions::new(slider_drag_smoke=true),
    ),
  )
  .run()
}
