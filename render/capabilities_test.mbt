///|
test "renderer capability report tracks draw command support" {
  let report = @render.renderer_feature_capability_report()
  inspect(report.length(), content="17")
  guard @render.renderer_feature_capability(@render.RendererFeature::Image)
    is Some(image) else {
    fail("expected image capability")
  }
  assert_true(image.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(image.web_status == @render.RendererFeatureStatus::Ready)
  assert_true(image.native_note.contains("mizchi/image"))
  assert_true(image.native_note.contains("PNG"))
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
  guard @render.renderer_feature_capability(@render.RendererFeature::LayerCompositing)
    is Some(layer) else {
    fail("expected layer compositing capability")
  }
  assert_true(layer.native_status == @render.RendererFeatureStatus::Partial)
  assert_true(layer.native_note.contains("PushLayer"))
  guard @render.renderer_feature_capability(@render.RendererFeature::PathVector)
    is Some(path) else {
    fail("expected path capability")
  }
  assert_true(path.native_status == @render.RendererFeatureStatus::Partial)
  assert_true(path.native_note.contains("DrawPath"))
  guard @render.renderer_feature_capability(@render.RendererFeature::TextShaping)
    is Some(text_shaping) else {
    fail("expected text shaping capability")
  }
  assert_true(text_shaping.native_status == @render.RendererFeatureStatus::Partial)
}

///|
test "renderer neutral advanced commands are modeled but skipped by legacy batching" {
  let rect = @core.Rect::new(x=0.0, y=0.0, width=24.0, height=24.0)
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::PushLayer(@core.LayerSpec::new(opacity=0.5, offscreen=true)),
    @core.DrawCommand::PushFilter(@core.FilterEffect::blur(4.0)),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=0.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(@core.Color::blue())),
      ),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=rect,
        uniforms=[1.0, 2.0],
      ),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PopLayer,
  ]
  inspect(@render.collect_rect_batches(commands).length(), content="0")
}

///|
test "renderer capability follow ups stay focused on native gaps" {
  let follow_ups = @render.renderer_feature_follow_ups()
  inspect(follow_ups.length(), content="10")
  let mut has_transform = false
  let mut has_clip = false
  let mut has_layer = false
  let mut has_async_image = false
  for entry in follow_ups {
    if entry.feature == @render.RendererFeature::Transform {
      has_transform = true
    }
    if entry.feature == @render.RendererFeature::Clip {
      has_clip = true
    }
    if entry.feature == @render.RendererFeature::LayerCompositing {
      has_layer = true
    }
    if entry.feature == @render.RendererFeature::AsyncImage {
      has_async_image = true
    }
  }
  assert_true(has_transform)
  assert_true(has_clip)
  assert_true(has_layer)
  assert_true(has_async_image)
}
