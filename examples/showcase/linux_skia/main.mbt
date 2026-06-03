///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(
    @linux_backend.linux_capability_summary(),
  )
  let exit_after_first_present = @env.get_env_var(
      "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  let font_resolution = if exit_after_first_present {
    @skia_renderer.SkiaFontResolution::EmptyTypeface
  } else {
    @skia_renderer.SkiaFontResolution::SystemFontMgr
  }
  @linux_skia_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(
      font_resolution~,
      exit_after_first_present~,
    ),
  )
}
