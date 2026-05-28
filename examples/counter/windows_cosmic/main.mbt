///|
fn main {
  @windows_backend.run_app_with_options(
    "MoUI Counter App",
    @counter_app.runtime(),
    options=@windows_backend.WindowsAppOptions::new(text_engine=MoonCosmic),
  )
}
