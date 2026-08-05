///|
fn host_test_image_renderer(revision : Ref[Int]) -> @render.WindowRenderer {
  @render.WindowRenderer::new(
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
