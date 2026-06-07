///|
fn main {
  let exit_after_first_present = @env.get_env_var(
      "MOUI_BUTTON_FREEZE_PROBE_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  let font_resolution = if exit_after_first_present {
    @skia_renderer.SkiaFontResolution::EmptyTypeface
  } else {
    @skia_renderer.SkiaFontResolution::SystemFontMgr
  }
  @macos_skia_backend.run_app_with_options(
    "MoUI Button Freeze Probe",
    @app.runtime(),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      font_resolution~,
      exit_after_first_present~,
    ),
  )
}
