///|
fn host_test_image_renderer(revision : Ref[Int]) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(
      image_resource_snapshot=Some(() => {
        @render.ImageResourceSnapshot::new(revision=revision.val, records=[])
      }),
    ),
  )
}
