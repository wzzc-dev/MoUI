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
  guard @render.renderer_feature_capability(@render.RendererFeature::Transform)
    is Some(transform) else {
    fail("expected transform capability")
  }
  assert_true(transform.native_status == @render.RendererFeatureStatus::Partial)
  assert_true(transform.web_status == @render.RendererFeatureStatus::Partial)
  assert_true(transform.native_note.contains("scoped layer"))
  assert_true(transform.native_note.contains("transform and clip"))
  assert_true(transform.web_note.contains("clone"))
  guard @render.renderer_feature_capability(@render.RendererFeature::Clip)
    is Some(clip) else {
    fail("expected clip capability")
  }
  assert_true(clip.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(clip.web_status == @render.RendererFeatureStatus::Ready)
  assert_true(clip.web_note.contains("offscreen layer masks"))
  guard @render.renderer_feature_capability(@render.RendererFeature::Opacity)
    is Some(opacity) else {
    fail("expected opacity capability")
  }
  assert_true(opacity.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(opacity.web_status == @render.RendererFeatureStatus::Ready)
  guard @render.renderer_feature_capability(
      @render.RendererFeature::LayerCompositing,
    )
    is Some(layer) else {
    fail("expected layer compositing capability")
  }
  assert_true(layer.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(layer.web_status == @render.RendererFeatureStatus::Ready)
  assert_true(layer.native_note.contains("offscreen"))
  guard @render.renderer_feature_capability(@render.RendererFeature::BlendMode)
    is Some(blend) else {
    fail("expected blend capability")
  }
  assert_true(blend.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(blend.web_status == @render.RendererFeatureStatus::Ready)
  assert_true(blend.native_note.contains("backdrop-sampling"))
  guard @render.renderer_feature_capability(
      @render.RendererFeature::FilterEffect,
    )
    is Some(filter) else {
    fail("expected filter capability")
  }
  assert_true(filter.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(filter.web_status == @render.RendererFeatureStatus::Ready)
  assert_true(filter.native_note.contains("color matrix"))
  guard @render.renderer_feature_capability(
      @render.RendererFeature::ShaderEffect,
    )
    is Some(shader) else {
    fail("expected shader capability")
  }
  assert_true(shader.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(shader.web_status == @render.RendererFeatureStatus::Ready)
  guard @render.renderer_feature_capability(@render.RendererFeature::PathVector)
    is Some(path) else {
    fail("expected path capability")
  }
  assert_true(path.native_status == @render.RendererFeatureStatus::Ready)
  assert_true(path.web_status == @render.RendererFeatureStatus::Ready)
  assert_true(path.native_note.contains("moon_zeno"))
  assert_true(path.web_note.contains("mesh payload"))
  guard @render.renderer_feature_capability(
      @render.RendererFeature::TextShaping,
    )
    is Some(text_shaping) else {
    fail("expected text shaping capability")
  }
  assert_true(
    text_shaping.native_status == @render.RendererFeatureStatus::Partial,
  )
  assert_true(text_shaping.native_note.contains("CoreText"))
  assert_true(text_shaping.native_note.contains("DirectWrite scaffold"))
  assert_true(text_shaping.native_note.contains("fontconfig"))
  assert_true(text_shaping.native_note.contains("Cosmic"))
  guard @render.renderer_feature_capability(@render.RendererFeature::EmojiText)
    is Some(emoji) else {
    fail("expected emoji capability")
  }
  assert_true(emoji.native_status == @render.RendererFeatureStatus::Gap)
  assert_true(emoji.web_status == @render.RendererFeatureStatus::Partial)
  assert_true(emoji.native_note.contains("Diagnostic text conformance"))
  assert_true(emoji.web_note.contains("grapheme"))
  guard @render.renderer_feature_capability(@render.RendererFeature::AsyncImage)
    is Some(async_image) else {
    fail("expected async image capability")
  }
  assert_true(
    async_image.native_status == @render.RendererFeatureStatus::Partial,
  )
  assert_true(async_image.web_status == @render.RendererFeatureStatus::Partial)
  assert_true(async_image.web_note.contains("browser cache"))
  assert_true(async_image.web_note.contains("ready"))
  assert_true(async_image.web_note.contains("failed"))
}

///|
test "renderer neutral advanced commands keep visible path out of fallback plan" {
  let rect = @core.Rect::new(x=0.0, y=0.0, width=24.0, height=24.0)
  let commands : Array[@core.DrawCommand] = [
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
  ]
  inspect(@render.collect_rect_batches(commands).length(), content="0")
  let plan = @render.plan_renderer_command_fallbacks(commands)
  inspect(plan.total_commands, content="6")
  inspect(plan.fallback_count, content="0")
  inspect(plan.final_layer_depth, content="0")
  inspect(plan.final_filter_depth, content="0")
  guard commands[2] is @core.DrawCommand::DrawPath(path) else {
    fail("expected path command")
  }
  inspect(@render.tessellate_path(path).vertices.length(), content="3")
}

///|
test "renderer command planner reports unbalanced advanced scopes" {
  let plan = @render.plan_renderer_command_fallbacks([
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PushFilter(@core.FilterEffect::blur(2.0)),
  ])
  inspect(plan.fallback_count, content="2")
  assert_true(
    plan.fallbacks[0].kind == @render.RendererCommandFallbackKind::UnbalancedPop,
  )
  assert_true(
    plan.fallbacks[1].kind == @render.RendererCommandFallbackKind::UnclosedScope,
  )
  inspect(plan.final_filter_depth, content="1")
}

///|
test "renderer capability follow ups stay focused on native gaps" {
  let follow_ups = @render.renderer_feature_follow_ups()
  inspect(follow_ups.length(), content="4")
  let mut has_transform = false
  let mut has_text_shaping = false
  let mut has_emoji_text = false
  let mut has_async_image = false
  let mut has_path_vector = false
  for entry in follow_ups {
    if entry.feature == @render.RendererFeature::Transform {
      has_transform = true
    }
    if entry.feature == @render.RendererFeature::TextShaping {
      has_text_shaping = true
      assert_true(entry.native_note.contains("follow-up"))
    }
    if entry.feature == @render.RendererFeature::EmojiText {
      has_emoji_text = true
      assert_true(entry.native_status == @render.RendererFeatureStatus::Gap)
    }
    if entry.feature == @render.RendererFeature::AsyncImage {
      has_async_image = true
    }
    if entry.feature == @render.RendererFeature::PathVector {
      has_path_vector = true
    }
  }
  assert_true(has_transform)
  assert_true(has_text_shaping)
  assert_true(has_emoji_text)
  assert_true(has_async_image)
  assert_false(has_path_vector)
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
