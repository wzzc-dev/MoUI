///|
fn main {
  let binding = @moui_3d.ThreeDViewportBinding::new()
  let viewport_host = @moui_3d.ThreeDViewportHost::new(binding~)
  let provider = @three_d_web.create_host_provider()
  @three_d_render.connect_viewport_host(
    provider,
    viewport_host,
    unavailable_reason="WebGPU host imports or adapter are unavailable",
  )
  @runtime.run_app(
    "MoUI 3D Viewer",
    @runtime.new_program_with_dimensions(
      program=@viewer_app.program_with_binding(binding),
      width=900.0,
      height=640.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(
    @web.entry(
      options=@web.WebAppOptions::new(platform_view_plugins=[
        @three_d_web_backend.plugin(host=Some(viewport_host)),
      ]),
    ),
  )
  .run()
}
