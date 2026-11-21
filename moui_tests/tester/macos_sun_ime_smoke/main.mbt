///|
/// Native IME runtime smoke over the Sun CPU renderer route. Mirrors
/// `macos_skia_ime_smoke` so the macOS IME evidence covers both presentation
/// backends: same fixture app, same `NSTextInputClient` path, different
/// renderer.
fn main {
  @apphost.run_app("MoUI Text Input Smoke", @fixture.runtime())
  .render(@render_sun.raster())
  .backend(
    @macos.entry(
      smoke_options=@macos.MacosHostSmokeOptions::new(
        first_frame_smoke_auto_exit=true,
        native_ime_runtime_smoke=true,
      ),
    ),
  )
  .run()
}
