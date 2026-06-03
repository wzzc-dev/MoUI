///|
test "renderer capability report tracks draw command support" {
  let report = @render.renderer_feature_capability_report()
  inspect(report.length(), content="17")
  guard @render.renderer_feature_capability(@render.RendererFeature::Image)
    is Some(image) else {
    fail("expected image capability")
  }
  assert_true(
    image.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    image.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    image.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    image
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("mizchi/image"),
  )
  assert_true(
    image
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("PNG"),
  )
  assert_true(
    image
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("data URI"),
  )
  assert_true(
    image
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("JPEG/BMP"),
  )
  assert_true(
    image
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("local PNG/JPEG/BMP"),
  )
  assert_true(
    image
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("contain/cover/stretch placement geometry"),
  )
  assert_true(
    image
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("failed-image placeholders"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::Rect)
    is Some(rect) else {
    fail("expected rect capability")
  }
  assert_true(
    rect.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  guard @render.renderer_feature_capability(
      @render.RendererFeature::RoundedRect,
    )
    is Some(rounded) else {
    fail("expected rounded rect capability")
  }
  assert_true(
    rounded.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::Gradient)
    is Some(gradient) else {
    fail("expected gradient capability")
  }
  assert_true(
    gradient.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    gradient
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("fills and strokes"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::Shadow)
    is Some(shadow) else {
    fail("expected shadow capability")
  }
  assert_true(
    shadow.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    shadow
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("MaskFilter"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::Text)
    is Some(text) else {
    fail("expected text capability")
  }
  assert_true(
    text.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    text
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("TextRun frame"),
  )
  assert_true(
    text
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("mixed-run fallback"),
  )
  assert_true(
    text
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("real native renderer smoke"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::Transform)
    is Some(transform) else {
    fail("expected transform capability")
  }
  assert_true(
    transform.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Partial,
  )
  assert_true(
    transform.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Partial,
  )
  assert_true(
    transform.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("scoped layer"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("transform and clip"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("shader-effect advanced vertices"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("layer composite vertices"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("Filter scopes"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("transformed clip scissors"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("scaled-and-clipped"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("layer-masked opacity"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("filter-scoped"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::WebGpuWasm)
    .contains("shader-effect advanced vertices"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::WebGpuWasm)
    .contains("shader effects"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::WebGpuWasm)
    .contains("filters"),
  )
  assert_true(
    transform
    .note_for_backend(@render.RendererBackendKind::WebGpuWasm)
    .contains("clone"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::Clip)
    is Some(clip) else {
    fail("expected clip capability")
  }
  assert_true(
    clip.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    clip.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    clip.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    clip
    .note_for_backend(@render.RendererBackendKind::WebGpuWasm)
    .contains("offscreen layer masks"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::Opacity)
    is Some(opacity) else {
    fail("expected opacity capability")
  }
  assert_true(
    opacity.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    opacity.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    opacity.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  guard @render.renderer_feature_capability(
      @render.RendererFeature::LayerCompositing,
    )
    is Some(layer) else {
    fail("expected layer compositing capability")
  }
  assert_true(
    layer.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    layer.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    layer.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    layer
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("offscreen"),
  )
  assert_true(
    layer
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("nested layer/filter"),
  )
  assert_true(
    layer
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("renderer-local pixel tests"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::BlendMode)
    is Some(blend) else {
    fail("expected blend capability")
  }
  assert_true(
    blend.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    blend.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    blend.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    blend
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("backdrop-sampling"),
  )
  assert_true(
    blend
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("overlay"),
  )
  assert_true(
    blend
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("renderer-local multiply pixel coverage"),
  )
  guard @render.renderer_feature_capability(
      @render.RendererFeature::FilterEffect,
    )
    is Some(filter) else {
    fail("expected filter capability")
  }
  assert_true(
    filter.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    filter.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    filter.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    filter
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("color matrix"),
  )
  assert_true(
    filter
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("color matrix"),
  )
  assert_true(
    filter
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("identity-normalized"),
  )
  assert_true(
    filter
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("renderer-local saturation/color-matrix coverage"),
  )
  guard @render.renderer_feature_capability(
      @render.RendererFeature::ShaderEffect,
    )
    is Some(shader) else {
    fail("expected shader capability")
  }
  assert_true(
    shader.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    shader.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    shader.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    shader
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("solid"),
  )
  assert_true(
    shader
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("linear-gradient-debug"),
  )
  assert_true(
    shader
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("vignette"),
  )
  assert_true(
    shader
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("renderer-local pixel tests"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::PathVector)
    is Some(path) else {
    fail("expected path capability")
  }
  assert_true(
    path.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    path.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    path.status_for_backend(@render.RendererBackendKind::SkiaRasterNative) ==
    @render.RendererFeatureStatus::Ready,
  )
  assert_true(
    path
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("quadratic and cubic"),
  )
  assert_true(
    path
    .note_for_backend(@render.RendererBackendKind::SkiaRasterNative)
    .contains("renderer-local pixel tests"),
  )
  assert_true(
    path
    .note_for_backend(@render.RendererBackendKind::NativeWgpu)
    .contains("moon_zeno"),
  )
  assert_true(
    path
    .note_for_backend(@render.RendererBackendKind::WebGpuWasm)
    .contains("mesh payload"),
  )
  guard @render.renderer_feature_capability(
      @render.RendererFeature::TextShaping,
    )
    is Some(text_shaping) else {
    fail("expected text shaping capability")
  }
  assert_true(
    text_shaping.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Partial,
  )
  let native_text_note = text_shaping.note_for_backend(
    @render.RendererBackendKind::NativeWgpu,
  )
  assert_true(native_text_note.contains("CoreText"))
  assert_true(native_text_note.contains("DirectWrite scaffold"))
  assert_true(native_text_note.contains("fontconfig"))
  assert_true(native_text_note.contains("Cosmic"))
  assert_true(native_text_note.contains("run layout"))
  assert_true(native_text_note.contains("caret coverage"))
  assert_true(native_text_note.contains("coverage checks"))
  let skia_text_note = text_shaping.note_for_backend(
    @render.RendererBackendKind::SkiaRasterNative,
  )
  assert_true(skia_text_note.contains("FontSpec"))
  assert_true(skia_text_note.contains("FontMgr"))
  assert_true(skia_text_note.contains("FontFallbackRequest"))
  assert_true(skia_text_note.contains("representative emoji/non-ASCII"))
  assert_true(skia_text_note.contains("grapheme-safe fallback segments"))
  assert_true(skia_text_note.contains("weight"))
  assert_true(skia_text_note.contains("baseline"))
  assert_true(skia_text_note.contains("shaped-run cluster carets"))
  assert_true(skia_text_note.contains("prefix carets"))
  assert_true(skia_text_note.contains("both caret paths"))
  assert_true(skia_text_note.contains("combining-mark/Indic-matra/Arabic-mark"))
  assert_true(skia_text_note.contains("keycap/emoji-modifier"))
  assert_true(skia_text_note.contains("regional-indicator"))
  assert_true(skia_text_note.contains("emoji-family fonts"))
  assert_true(skia_text_note.contains("glyph-run drawing"))
  assert_true(skia_text_note.contains("SkShaper"))
  guard @render.renderer_feature_capability(@render.RendererFeature::EmojiText)
    is Some(emoji) else {
    fail("expected emoji capability")
  }
  assert_true(
    emoji.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Partial,
  )
  assert_true(
    emoji.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Partial,
  )
  let native_emoji_note = emoji.note_for_backend(
    @render.RendererBackendKind::NativeWgpu,
  )
  assert_true(native_emoji_note.contains("RGBA"))
  assert_true(native_emoji_note.contains("text vertices"))
  assert_true(native_emoji_note.contains("Cosmic"))
  assert_true(native_emoji_note.contains("platform emoji fallback"))
  assert_true(native_emoji_note.contains("variation-selector"))
  assert_true(native_emoji_note.contains("ZWJ"))
  assert_true(native_emoji_note.contains("AppleColorEmoji"))
  assert_true(native_emoji_note.contains("grapheme"))
  let skia_emoji_note = emoji.note_for_backend(
    @render.RendererBackendKind::SkiaRasterNative,
  )
  assert_true(skia_emoji_note.contains("single-codepoint"))
  assert_true(skia_emoji_note.contains("variation-selector"))
  assert_true(skia_emoji_note.contains("keycap"))
  assert_true(skia_emoji_note.contains("emoji-modifier"))
  assert_true(skia_emoji_note.contains("ZWJ"))
  assert_true(skia_emoji_note.contains("regional-indicator"))
  assert_true(skia_emoji_note.contains("FontFallbackRequest"))
  assert_true(skia_emoji_note.contains("cluster interior carets"))
  assert_true(skia_emoji_note.contains("platform emoji font candidates"))
  assert_true(skia_emoji_note.contains("default-font fallback"))
  assert_true(skia_emoji_note.contains("grapheme"))
  assert_true(
    emoji
    .note_for_backend(@render.RendererBackendKind::WebGpuWasm)
    .contains("grapheme"),
  )
  guard @render.renderer_feature_capability(@render.RendererFeature::AsyncImage)
    is Some(async_image) else {
    fail("expected async image capability")
  }
  assert_true(
    async_image.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
    @render.RendererFeatureStatus::Partial,
  )
  let native_image_note = async_image.note_for_backend(
    @render.RendererBackendKind::NativeWgpu,
  )
  assert_true(native_image_note.contains("HostWindowRenderer"))
  assert_true(
    async_image.status_for_backend(@render.RendererBackendKind::WebGpuWasm) ==
    @render.RendererFeatureStatus::Partial,
  )
  let skia_image_note = async_image.note_for_backend(
    @render.RendererBackendKind::SkiaRasterNative,
  )
  assert_true(skia_image_note.contains("HostWindowRenderer"))
  assert_true(skia_image_note.contains("failed-image placeholder"))
  assert_true(skia_image_note.contains("failed-cache snapshot"))
  assert_true(skia_image_note.contains("local-file retry"))
  assert_true(skia_image_note.contains("dispose-record"))
  let web_image_note = async_image.note_for_backend(
    @render.RendererBackendKind::WebGpuWasm,
  )
  assert_true(web_image_note.contains("browser cache"))
  assert_true(web_image_note.contains("backend WebRenderer facade"))
  assert_true(web_image_note.contains("app-visible"))
  assert_true(web_image_note.contains("ready"))
  assert_true(web_image_note.contains("failed"))
  assert_true(web_image_note.contains("redraw"))
  assert_true(web_image_note.contains("Image.onload"))
  assert_true(web_image_note.contains("Image.onerror"))
}

///|
test "renderer neutral draw command scopes keep visible path out of fallback plan" {
  let rect = @core.Rect::new(x=0.0, y=0.0, width=24.0, height=24.0)
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::PushClip(rect),
    @core.DrawCommand::PushRoundedClip(
      @core.RoundedRect::new(rect~, radius=4.0),
    ),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=2.0, dy=3.0),
    ),
    @core.DrawCommand::PushOpacity(0.75),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(opacity=0.5, offscreen=true),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::blur(4.0)),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=0.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=10.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(@core.Color::blue())),
      ),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(name="checker", frame=rect, uniforms=[
        1.0, 2.0,
      ]),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopRoundedClip,
    @core.DrawCommand::PopClip,
  ]
  inspect(@render.collect_rect_batches(commands).length(), content="0")
  let plan = @render.plan_renderer_command_fallbacks(commands)
  inspect(plan.total_commands, content="14")
  inspect(plan.fallback_count, content="0")
  inspect(plan.final_layer_depth, content="0")
  inspect(plan.final_filter_depth, content="0")
  guard commands[6] is @core.DrawCommand::DrawPath(path) else {
    fail("expected path command")
  }
  inspect(@render.tessellate_path(path).vertices.length(), content="3")
}

///|
test "renderer command planner reports unbalanced draw command scopes" {
  let plan = @render.plan_renderer_command_fallbacks([
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopRoundedClip,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PushFilter(@core.FilterEffect::blur(2.0)),
  ])
  inspect(plan.fallback_count, content="6")
  assert_true(
    plan.fallbacks[0].kind == @render.RendererCommandFallbackKind::UnbalancedPop,
  )
  assert_true(plan.fallbacks[0].feature == @render.RendererFeature::Clip)
  inspect(plan.fallbacks[1].command, content="PopRoundedClip")
  assert_true(plan.fallbacks[2].feature == @render.RendererFeature::Transform)
  assert_true(plan.fallbacks[3].feature == @render.RendererFeature::Opacity)
  assert_true(
    plan.fallbacks[4].feature == @render.RendererFeature::LayerCompositing,
  )
  assert_true(
    plan.fallbacks[5].kind == @render.RendererCommandFallbackKind::UnclosedScope,
  )
  inspect(plan.final_filter_depth, content="1")
}

///|
test "renderer command planner reports unclosed draw command scopes" {
  let rect = @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0)
  let plan = @render.plan_renderer_command_fallbacks([
    @core.DrawCommand::PushClip(rect),
    @core.DrawCommand::PushRoundedClip(
      @core.RoundedRect::new(rect~, radius=2.0),
    ),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=1.0, dy=1.0),
    ),
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::PushLayer(@core.LayerSpec::new()),
    @core.DrawCommand::PushFilter(@core.FilterEffect::blur(2.0)),
  ])
  inspect(plan.fallback_count, content="6")
  inspect(plan.fallbacks[0].command, content="PushClip")
  inspect(plan.fallbacks[1].command, content="PushRoundedClip")
  inspect(plan.fallbacks[2].command, content="PushTransform")
  inspect(plan.fallbacks[3].command, content="PushOpacity")
  inspect(plan.fallbacks[4].command, content="PushLayer")
  inspect(plan.fallbacks[5].command, content="PushFilter")
  for fallback in plan.fallbacks {
    assert_true(
      fallback.kind == @render.RendererCommandFallbackKind::UnclosedScope,
    )
  }
  inspect(plan.final_layer_depth, content="1")
  inspect(plan.final_filter_depth, content="1")
}

///|
test "renderer capability follow ups stay focused on incomplete features" {
  let follow_ups = @render.renderer_feature_follow_ups()
  assert_true(follow_ups.length() >= 3)
  let mut has_transform = false
  let mut has_text_shaping = false
  let mut has_emoji_text = false
  let mut has_async_image = false
  for entry in follow_ups {
    if entry.feature == @render.RendererFeature::Transform {
      has_transform = true
    }
    if entry.feature == @render.RendererFeature::TextShaping {
      has_text_shaping = true
      assert_true(
        entry
        .note_for_backend(@render.RendererBackendKind::NativeWgpu)
        .contains("follow-up"),
      )
    }
    if entry.feature == @render.RendererFeature::EmojiText {
      has_emoji_text = true
      assert_true(
        entry.status_for_backend(@render.RendererBackendKind::NativeWgpu) ==
        @render.RendererFeatureStatus::Partial,
      )
    }
    if entry.feature == @render.RendererFeature::AsyncImage {
      has_async_image = true
    }
  }
  assert_true(has_transform)
  assert_true(has_text_shaping)
  assert_true(has_emoji_text)
  assert_true(has_async_image)
}

///|
test "renderer capability report exposes backend-driven entries" {
  let backends = @render.renderer_capability_backends()
  inspect(backends.length(), content="3")
  assert_true(backends[0] == @render.RendererBackendKind::NativeWgpu)
  assert_true(backends[1] == @render.RendererBackendKind::SkiaRasterNative)
  assert_true(backends[2] == @render.RendererBackendKind::WebGpuWasm)
  let wgpu = @render.renderer_backend_capabilities(
    @render.RendererBackendKind::NativeWgpu,
  )
  let skia = @render.renderer_backend_capabilities(
    @render.RendererBackendKind::SkiaRasterNative,
  )
  inspect(wgpu.length(), content="17")
  inspect(skia.length(), content="17")
  assert_true(skia.any(capability => capability.note.contains("skia_mbt")))
}

///|
test "path tessellator lowers fill stroke and curves into vertices" {
  let path = @core.PathSpec::new(
    verbs=[
      @core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.0)),
      @core.PathVerb::LineTo(@core.Point::new(x=10.0, y=0.0)),
      @core.PathVerb::QuadTo(
        @core.Point::new(x=12.0, y=4.0),
        @core.Point::new(x=10.0, y=8.0),
      ),
      @core.PathVerb::Close,
    ],
    fill=Some(@core.Brush::solid(@core.Color::blue())),
    stroke=Some(@core.Brush::solid(@core.Color::black())),
    stroke_width=2.0,
  )
  let mesh = @render.tessellate_path(path)
  assert_true(mesh.vertices.length() > 3)
  inspect(mesh.diagnostics.length(), content="0")
}

///|
test "path tessellator lowers open line stroke into local quad" {
  let path = @core.PathSpec::new(
    verbs=[
      @core.PathVerb::MoveTo(@core.Point::new(x=10.0, y=20.0)),
      @core.PathVerb::LineTo(@core.Point::new(x=14.0, y=24.0)),
    ],
    stroke=Some(@core.Brush::solid(@core.Color::black())),
    stroke_width=2.0,
  )
  let mesh = @render.tessellate_path(path)
  inspect(mesh.vertices.length(), content="6")
  inspect(mesh.diagnostics.length(), content="0")
  for vertex in mesh.vertices {
    assert_true(vertex.x >= 9.0 && vertex.x <= 15.0)
    assert_true(vertex.y >= 19.0 && vertex.y <= 25.0)
  }
}

///|
test "path tessellator uses zeno for cubic and degenerate paths" {
  let cubic = @core.PathSpec::new(
    verbs=[
      @core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.0)),
      @core.PathVerb::CubicTo(
        @core.Point::new(x=4.0, y=0.0),
        @core.Point::new(x=8.0, y=8.0),
        @core.Point::new(x=12.0, y=0.0),
      ),
      @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=8.0)),
      @core.PathVerb::Close,
    ],
    fill=Some(@core.Brush::solid(@core.Color::rgba(r=1.0, g=0.0, b=0.0))),
    stroke=Some(@core.Brush::solid(@core.Color::black())),
    stroke_width=1.0,
  )
  let cubic_mesh = @render.tessellate_path(cubic)
  assert_true(cubic_mesh.vertices.length() > 0)
  inspect(cubic_mesh.diagnostics.length(), content="0")
  let degenerate = @core.PathSpec::new(
    verbs=[
      @core.PathVerb::LineTo(@core.Point::new(x=1.0, y=1.0)),
      @core.PathVerb::Close,
    ],
    fill=Some(@core.Brush::solid(@core.Color::rgba(r=1.0, g=0.0, b=0.0))),
  )
  let degenerate_mesh = @render.tessellate_path(degenerate)
  inspect(degenerate_mesh.vertices.length(), content="0")
  inspect(degenerate_mesh.diagnostics.length(), content="2")
}

///|
test "shader registry resolves builtins and reports fallback" {
  let rect = @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0)
  let ready = @render.resolve_shader_effect(
    @core.ShaderEffectSpec::new(name="checker", frame=rect),
  )
  assert_true(ready.status == @render.ShaderRegistryStatus::ShaderReady)
  let fallback = @render.resolve_shader_effect(
    @core.ShaderEffectSpec::new(name="missing", frame=rect),
  )
  assert_true(fallback.status == @render.ShaderRegistryStatus::ShaderFallback)
  assert_true(fallback.diagnostic.contains("missing"))
}

///|
test "image lifecycle records loading ready failure and eviction" {
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("a.png"))
  match lifecycle.lookup("a.png") {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected loading record")
  }
  ignore(lifecycle.mark_ready("a.png", width=24, height=12))
  match lifecycle.lookup("a.png") {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageReady)
      inspect(record.width, content="24")
      inspect(record.height, content="12")
    }
    None => fail("expected ready record")
  }
  ignore(lifecycle.mark_failed("b.png", diagnostic="decode failed"))
  match lifecycle.lookup("b.png") {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageFailed)
      assert_true(record.diagnostic.contains("decode"))
    }
    None => fail("expected failed record")
  }
  ignore(lifecycle.dispose("a.png"))
  inspect(lifecycle.evict_disposed(), content="1")
  match lifecycle.lookup("a.png") {
    Some(_) => fail("expected disposed record eviction")
    None => ()
  }
}

///|
test "image lifecycle exposes app visible snapshot records" {
  let lifecycle = @render.ImageResourceLifecycle::new()
  ignore(lifecycle.mark_loading("a.png"))
  ignore(lifecycle.mark_failed("b.png", diagnostic="decode failed"))
  let snapshot = lifecycle.snapshot()
  inspect(snapshot.length(), content="2")
  assert_true(snapshot.any(record => record.source == "a.png"))
  assert_true(
    snapshot.any(record => {
      record.source == "b.png" &&
      record.status == @render.ImageResourceStatus::ImageFailed &&
      record.diagnostic.contains("decode")
    }),
  )
}

///|
test "svg importer lowers shapes to draw commands" {
  let svg = "<svg><rect x=\"1\" y=\"2\" width=\"10\" height=\"20\" fill=\"blue\"/><circle cx=\"8\" cy=\"8\" r=\"4\" fill=\"red\"/><line x1=\"0\" y1=\"0\" x2=\"10\" y2=\"0\" stroke=\"black\" stroke-width=\"2\"/><polygon points=\"0,0 10,0 10,10\" fill=\"green\"/></svg>"
  let result = @render.import_svg(svg)
  inspect(result.diagnostics.length(), content="0")
  inspect(result.commands.length(), content="4")
  guard result.commands[0] is @core.DrawCommand::FillRect(rect, color) else {
    fail("expected rect command")
  }
  inspect(rect.origin.x, content="1")
  assert_true(color == @core.Color::rgba(r=0.0, g=0.0, b=1.0))
  guard result.commands[1] is @core.DrawCommand::DrawPath(circle) else {
    fail("expected circle path")
  }
  assert_true(@render.tessellate_path(circle).vertices.length() > 0)
}

///|
test "svg importer reports unsupported embedded features" {
  let result = @render.import_svg(
    "<svg><foreignObject/><animate attributeName=\"x\"/></svg>",
  )
  inspect(result.diagnostics.length(), content="2")
}
