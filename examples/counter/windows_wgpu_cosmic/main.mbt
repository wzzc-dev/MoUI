///|
fn main {
  @windows_wgpu_backend.run_app_with_options(
    "MoUI Counter App",
    @runtime.new_program_with_dimensions(
      program=@counter_app.program(),
      width=520.0,
      height=360.0,
    ),
    options=@windows_wgpu_backend.WindowsWgpuAppOptions::new(
      text_engine=@wgpu_renderer.NativeTextEngineSetting::MoonCosmic,
    ),
  )
}
