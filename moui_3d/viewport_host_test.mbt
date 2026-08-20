///|
test "viewport host forwards latest snapshot and geometry" {
  let binding = ThreeDViewportBinding::new()
  let scene = Scene::empty()
  let snapshot = ViewportSnapshot::new(
    scene_revision=7L,
    scene~,
    camera=OrbitCamera::new(),
  )
  ignore(binding.publish(snapshot))
  let host = ThreeDViewportHost::new(binding~)
  let seen : @ref.Ref[(UInt64, Int, Int, Double, Int64)?] = @ref.Ref(None)
  host.set_surface_handler((handle, width, height, scale) => {
    seen.val = Some((handle, width, height, scale, 0L))
  })
  host.set_frame_handler((value, width, height, scale) => {
    seen.val = Some((99UL, width, height, scale, value.scene_revision()))
  })
  let placement = @core.PlatformViewPlacement::new(
    id="moui-3d-viewport",
    kind="moui_3d_viewport",
    frame=@core.Rect::new(x=0.0, y=0.0, width=320.0, height=200.0),
  )
  let frame = @core.DrawFrame::new(
    commands=[],
    platform_views=[placement],
    damage=@core.DamageRegion::full("test"),
  )
  host.sync_platform_view(5UL, placement, 8UL, frame, 0.0)
  match seen.val {
    Some((_handle, width, height, scale, revision)) => {
      inspect(width, content="320")
      inspect(height, content="200")
      inspect(scale, content="1")
      inspect(revision, content="7")
    }
    None => fail("expected host callback")
  }
}
