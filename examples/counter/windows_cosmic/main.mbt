///|
fn main {
  @windows_wgpu.run_app_with_options(
    "MoUI Counter App",
    @counter_app.runtime(),
    options=@windows_wgpu.WindowsWgpuAppOptions::new(
      text_engine=@wgpu_renderer.NativeTextEngineSetting::MoonCosmic,
    ),
  )
}
