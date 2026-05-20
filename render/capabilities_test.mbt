///|
test "renderer capability report tracks draw command support" {
  let report = @render.renderer_feature_capability_report()
  inspect(report.length(), content="9")
  guard @render.renderer_feature_capability(@render.RendererFeature::Image)
    is Some(image) else {
    fail("expected image capability")
  }
  assert_true(image.native_status == @render.RendererFeatureStatus::Partial)
  assert_true(image.web_status == @render.RendererFeatureStatus::Ready)
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
  inspect(follow_ups.length(), content="3")
  assert_true(follow_ups[0].feature == @render.RendererFeature::Image)
  assert_true(follow_ups[1].feature == @render.RendererFeature::Clip)
  assert_true(follow_ups[2].feature == @render.RendererFeature::Transform)
}
