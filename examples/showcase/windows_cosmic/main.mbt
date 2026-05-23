///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime()
  @windows_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@windows_backend.WindowsAppOptions::new(
      text_engine=MoonCosmic,
    ),
  )
}
