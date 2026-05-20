///|
test "renderer capability report tracks draw command support" {
  let report = @render.renderer_feature_capability_report()
  inspect(report.length(), content="9")
  guard @render.renderer_feature_capability(@render.RendererFeature::Image)
    is Some(image) else {
    fail("expected image capability")
  }
  assert_true(image.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(image.web_status == @render.RendererFeatureStatus::Ready)
  guard @render.renderer_feature_capability(@render.RendererFeature::Clip)
    is Some(clip) else {
    fail("expected clip capability")
  }
  assert_true(clip.native_status == @render.RendererFeatureStatus::Ready)
  guard @render.renderer_feature_capability(@render.RendererFeature::Opacity)
    is Some(opacity) else {
    fail("expected opacity capability")
  }
  assert_true(opacity.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(opacity.web_status == @render.RendererFeatureStatus::Ready)
}

///|
test "renderer capability follow ups stay focused on native gaps" {
  let follow_ups = @render.renderer_feature_follow_ups()
  inspect(follow_ups.length(), content="2")
  let mut has_transform = false
  let mut has_clip = false
  for entry in follow_ups {
    if entry.feature == @render.RendererFeature::Transform {
      has_transform = true
    }
    if entry.feature == @render.RendererFeature::Clip {
      has_clip = true
    }
  }
  assert_true(has_transform)
  assert_true(has_clip)
}
