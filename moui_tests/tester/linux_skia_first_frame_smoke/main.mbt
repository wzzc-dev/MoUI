///|
fn main {
  @runtime.run_app("MoUI Text Input Smoke", @fixture.runtime())
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Linux),
  )
  .backend(
    @linux.entry(
      smoke_options=@linux.LinuxHostSmokeOptions::new(
        first_frame_smoke_auto_exit=true,
      ),
    ),
  )
  .run()
}
