///|
fn main {
  let binding = @moui_3d.ThreeDViewportBinding::new()
  let viewport_host = @moui_3d.ThreeDViewportHost::new(binding~)
  let provider = @three_d_wgpu.macos_provider()
  @three_d_render.connect_viewport_host(
    provider,
    viewport_host,
    unavailable_reason="Native WGPU device or CAMetalLayer surface is unavailable",
  )
  @runtime.run_app(
    "MoUI 3D Viewer",
    @runtime.new_program_with_dimensions(
      program=@viewer_app.program_with_binding(
        binding,
        environment=@macos_backend.app_environment(),
      ),
      width=900.0,
      height=640.0,
    ),
  )
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(
    @macos_backend.entry(
      options=@macos_backend.MacosHostAppOptions::new(platform_view_plugins=[
        @three_d_macos.plugin(host=Some(viewport_host)),
      ]),
    ),
  )
  .run()
}
