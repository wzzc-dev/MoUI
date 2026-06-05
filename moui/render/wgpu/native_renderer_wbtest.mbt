///|
test "renderer remembers resize and batches" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  inspect(renderer.size.width, content="320")
  renderer.render([
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      @core.Color::gray(),
    ),
  ])
  inspect(renderer.last_batches.length(), content="1")
}

///|
test "native renderer tracks logical and physical resize metrics" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=320.0, height=200.0),
      physical_size=@core.Size::new(width=640.0, height=400.0),
      scale_factor=2.0,
    ),
  )
  inspect(renderer.size.width, content="320")
  inspect(renderer.physical_size.width, content="640")
  inspect(renderer.scale_factor, content="2")
}

///|
test "native renderer default scissor uses physical surface size" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=320.0, height=200.0),
      physical_size=@core.Size::new(width=640.0, height=400.0),
      scale_factor=2.0,
    ),
  )
  inspect(renderer.effective_physical_size().width, content="640")
  inspect(renderer.effective_physical_size().height, content="400")
}

///|
test "native renderer clipped scissor uses physical pixels" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=320.0, height=200.0),
      physical_size=@core.Size::new(width=640.0, height=400.0),
      scale_factor=2.0,
    ),
  )
  renderer.render([
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=10.0, y=20.0, width=30.0, height=40.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
  ])
  match renderer.draw_items[0] {
    NativeDrawItem::NativeVisual(_, _, Some(scissor)) => {
      inspect(scissor.x, content="20")
      inspect(scissor.y, content="40")
      inspect(scissor.width, content="60")
      inspect(scissor.height, content="80")
    }
    _ => inspect("missing scissor", content="native visual scissor")
  }
}

///|
test "native renderer skips draw items for empty nested clip" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=20.0, y=20.0, width=10.0, height=10.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopClip,
  ])
  inspect(renderer.draw_items.length(), content="0")
  inspect(renderer.visual_vertices.length(), content="0")
}

///|
test "native renderer skips clip that lands exactly on surface edge" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=760.0, height=420.0),
      physical_size=@core.Size::new(width=1520.0, height=840.0),
      scale_factor=2.0,
    ),
  )
  renderer.render([
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=28.0, y=420.0, width=120.0, height=72.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=28.0, y=420.0, width=120.0, height=72.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
  ])
  inspect(renderer.draw_items.length(), content="0")
  inspect(renderer.visual_vertices.length(), content="0")
}

///|
test "native renderer transforms clip before computing scissor" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=100.0, height=100.0),
      physical_size=@core.Size::new(width=200.0, height=200.0),
      scale_factor=2.0,
    ),
  )
  renderer.render([
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=5.0, dy=7.0),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=10.0, y=10.0, width=20.0, height=20.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=40.0, height=40.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopTransform,
  ])
  match renderer.draw_items[0] {
    NativeDrawItem::NativeVisual(_, _, Some(scissor)) => {
      inspect(scissor.x, content="30")
      inspect(scissor.y, content="34")
      inspect(scissor.width, content="40")
      inspect(scissor.height, content="40")
    }
    _ => fail("expected transformed native visual scissor")
  }
}

///|
test "native renderer plans visual primitives instead of fallback-only batches" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  let rounded = @core.RoundedRect::new(
    rect=@core.Rect::new(x=10.0, y=20.0, width=80.0, height=40.0),
    radius=8.0,
  )
  renderer.render([
    @core.DrawCommand::FillRoundedRectBrush(
      rounded,
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=10.0, y=20.0),
        end=@core.Point::new(x=90.0, y=60.0),
        start_color=@core.Color::blue(),
        end_color=@core.Color::gray(),
      ),
    ),
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=rounded,
        color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.35),
        blur_radius=12.0,
        spread=2.0,
      ),
    ),
  ])
  inspect(renderer.visual_vertices.length(), content="12")
  inspect(renderer.draw_items.length(), content="2")
  assert_true(renderer.visual_vertices[0].r0 == @core.Color::blue().r)
  assert_true(renderer.visual_vertices[0].r1 == @core.Color::gray().r)
  assert_true(renderer.visual_vertices[6].mode == visual_mode_shadow)
  assert_true(renderer.visual_vertices[6].blur_radius == 12.0)
}

///|
test "native renderer plans radial brush as true radial visual payload" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=80.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=10.0, y=20.0, width=40.0, height=24.0),
        radius=8.0,
      ),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=18.0, y=32.0),
        radius=12.0,
        center_color=@core.Color::blue(),
        edge_color=@core.Color::gray(),
      ),
    ),
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.visual_vertices.length(), content="6")
  let vertex = renderer.visual_vertices[0]
  inspect(vertex.mode, content="0")
  inspect(vertex.start_x, content="8")
  inspect(vertex.start_y, content="12")
  inspect(vertex.end_x, content="12")
  inspect(vertex.end_y, content="0")
  inspect(vertex.blur_radius, content="1")
  assert_true(vertex.r0 == @core.Color::blue().r)
  assert_true(vertex.r1 == @core.Color::gray().r)
}

///|
test "native renderer plans radial stroke brush as true radial visual payload" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=80.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::StrokeRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=10.0, y=20.0, width=40.0, height=24.0),
        radius=8.0,
      ),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=18.0, y=32.0),
        radius=12.0,
        center_color=@core.Color::blue(),
        edge_color=@core.Color::gray(),
      ),
      3.0,
    ),
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.visual_vertices.length(), content="6")
  let vertex = renderer.visual_vertices[0]
  inspect(vertex.mode, content="1")
  inspect(vertex.stroke_width, content="3")
  inspect(vertex.start_x, content="8")
  inspect(vertex.start_y, content="12")
  inspect(vertex.end_x, content="12")
  inspect(vertex.end_y, content="0")
  inspect(vertex.blur_radius, content="1")
  assert_true(vertex.r0 == @core.Color::blue().r)
  assert_true(vertex.r1 == @core.Color::gray().r)
}

///|
test "native renderer plans DrawPath mesh as visible visual triangles" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=10.0, dy=20.0),
    ),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=0.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=0.0, y=20.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(@core.Color::blue())),
      ),
    ),
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopOpacity,
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.draw_items.length(), content="1")
  inspect(renderer.visual_vertices.length(), content="3")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeVisual(_, count, None) => inspect(count, content="3")
    _ => fail("expected native visual path item")
  }
  let vertex = renderer.visual_vertices[0]
  inspect(vertex.mode, content="3")
  inspect(vertex.x, content="-0.8")
  inspect(vertex.y, content="0.6")
  inspect(vertex.a0, content="0.5")
}

///|
test "native renderer plans radial DrawPath as true radial path payload" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=0.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=0.0, y=20.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(
          @core.Brush::radial_gradient(
            center=@core.Point::new(x=6.0, y=6.0),
            radius=12.0,
            center_color=@core.Color::blue(),
            edge_color=@core.Color::gray(),
          ),
        ),
      ),
    ),
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.draw_items.length(), content="1")
  inspect(renderer.visual_vertices.length(), content="3")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeVisual(_, count, None) => inspect(count, content="3")
    _ => fail("expected native visual path item")
  }
  let vertex = renderer.visual_vertices[0]
  inspect(vertex.mode, content="3")
  inspect(vertex.blur_radius, content="1")
  inspect(vertex.start_x, content="6")
  inspect(vertex.start_y, content="6")
  inspect(vertex.end_x, content="12")
  inspect(vertex.end_y, content="0")
  assert_true(vertex.r0 == @core.Color::blue().r)
  assert_true(vertex.g0 == @core.Color::blue().g)
  assert_true(vertex.b0 == @core.Color::blue().b)
  assert_true(vertex.r1 == @core.Color::gray().r)
  assert_true(vertex.g1 == @core.Color::gray().g)
  assert_true(vertex.b1 == @core.Color::gray().b)
}

///|
test "native visual shader shades radial path payloads" {
  let shader = visual_shader_wgsl()
  assert_true(shader.contains("radial_gradient_color"))
  assert_true(
    shader.contains(
      "return brush_color(in.local, start, end, in.color0, in.color1, blur_radius);",
    ),
  )
}

///|
test "native renderer plans image clip transform and opacity commands" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushOpacity(0.6),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
    ),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=4.0, dy=8.0),
    ),
    @core.DrawCommand::DrawImage({
      source: "logo.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      opacity: 0.8,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopOpacity,
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.draw_items.length(), content="1")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeImage(_, _, Some(scissor), run) => {
      inspect(scissor.x, content="0")
      inspect(scissor.y, content="0")
      inspect(scissor.width, content="20")
      inspect(scissor.height, content="20")
      inspect(run.source, content="logo.png")
      assert_true(run.fit == @core.ImageFit::Contain)
      assert_true(run.opacity > 0.47)
      assert_true(run.opacity < 0.49)
      inspect(run.transform.tx, content="4")
      inspect(run.transform.ty, content="8")
    }
    _ => fail("expected native image item")
  }
}

///|
test "native renderer records image lifecycle diagnostics while planning" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawImage({
      source: "logo.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
  match renderer.image_lifecycle.lookup("logo.png") {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected native image loading record")
  }
  renderer.failed_images["missing.png"] = true
  renderer.render([
    @core.DrawCommand::DrawImage({
      source: "missing.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
  match renderer.image_lifecycle.lookup("missing.png") {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageFailed)
      assert_true(record.diagnostic.contains("decode"))
    }
    None => fail("expected native image failure record")
  }
}

///|
test "native wgpu renderer applies image load completions to lifecycle" {
  let renderer : WgpuRenderer = { backend: new_test_renderer_handle() }
  ignore(renderer.backend.image_lifecycle.mark_loading("async.png"))
  let ready = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("async.png", width=48, height=24),
  )
  inspect(ready.revision, content="2")
  guard renderer.backend.image_lifecycle.lookup("async.png") is Some(record) else {
    fail("expected applied ready completion")
  }
  assert_true(record.status == @render.ImageResourceStatus::ImageReady)
  inspect(record.width, content="48")
  inspect(record.height, content="24")
  ignore(renderer.backend.image_lifecycle.mark_loading("missing.png"))
  let failed = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      "missing.png",
      diagnostic="decode failed",
    ),
  )
  inspect(failed.revision, content="4")
  assert_true(
    renderer.backend.failed_images.get("missing.png").unwrap_or(false),
  )
  guard renderer.backend.image_lifecycle.lookup("missing.png") is Some(missing) else {
    fail("expected applied failed completion")
  }
  assert_true(missing.status == @render.ImageResourceStatus::ImageFailed)
  assert_true(missing.diagnostic.contains("decode"))
  let stale = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("missing.png", width=8, height=8),
  )
  inspect(stale.revision, content="4")
  guard renderer.backend.image_lifecycle.lookup("missing.png")
    is Some(still_failed) else {
    fail("expected stale completion to leave failed record")
  }
  assert_true(still_failed.status == @render.ImageResourceStatus::ImageFailed)
}

///|
test "native renderer plans advanced GPU layer filter and shader items" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  let mask = @core.RoundedRect::new(
    rect=@core.Rect::new(x=10.0, y=12.0, width=40.0, height=24.0),
    radius=6.0,
  )
  renderer.render([
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.5,
        blend_mode=@core.BlendMode::Multiply,
        mask=@core.LayerMask::RoundedMask(mask),
        offscreen=true,
      ),
    ),
    @core.DrawCommand::PushFilter(
      @core.FilterEffect::ColorMatrix([
        0.5, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0,
        1.0, 0.1, 0.2, 0.3, 0.0,
      ]),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="missing-effect",
        frame=@core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
        fallback=@core.Brush::solid(@core.Color::blue()),
      ),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PopLayer,
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.draw_items.length(), content="1")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeLayer(layer) => {
      inspect(layer.opacity, content="0.5")
      assert_true(layer.blend_mode == @core.BlendMode::Multiply)
      match layer.mask {
        Some(mask) => {
          assert_true(mask.rounded)
          inspect(mask.radius, content="6")
        }
        None => fail("expected rounded layer mask")
      }
      inspect(layer.plan.items.length(), content="1")
      match layer.plan.items[0] {
        NativeDrawItem::NativeLayer(filter_layer) => {
          assert_true(
            filter_layer.filter is Some(@core.FilterEffect::ColorMatrix(_)),
          )
          inspect(filter_layer.plan.items.length(), content="1")
          match filter_layer.plan.items[0] {
            NativeDrawItem::NativeShaderEffect(effect) => {
              inspect(native_shader_kind(effect.name), content="5")
              let colors = native_shader_effect_colors(effect)
              assert_true(colors.0 == @core.Color::blue())
            }
            _ => fail("expected nested shader effect")
          }
        }
        _ => fail("expected nested filter layer")
      }
      let vertices = advanced_layer_vertices(renderer.size, layer)
      inspect(vertices.length(), content="6")
      inspect(vertices[0].filter_kind, content="0")
      inspect(vertices[0].mask_radius, content="6")
      inspect(vertices[0].mask_kind, content="1")
      inspect(vertices[0].u, content="0.1")
      inspect(vertices[0].v, content="0.12")
    }
    _ => fail("expected native layer item")
  }
}

///|
test "native shader effect carries transform into advanced vertices" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=10.0, dy=20.0),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=@core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      ),
    ),
    @core.DrawCommand::PopTransform,
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.draw_items.length(), content="1")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeShaderEffect(effect) => {
      inspect(effect.transform.tx, content="10")
      inspect(effect.transform.ty, content="20")
      let colors = native_shader_effect_colors(effect)
      let vertices = advanced_rect_vertices(
        renderer.size,
        effect.frame,
        opacity=effect.opacity,
        blend_mode=@core.BlendMode::SourceOver,
        shader_kind=native_shader_kind(effect.name),
        effect_amount=native_shader_effect_amount(effect),
        filter=None,
        color0=colors.0,
        color1=colors.1,
        transform=effect.transform,
      )
      inspect(vertices.length(), content="6")
      inspect(vertices[0].x, content="-0.8")
      inspect(vertices[0].y, content="0.6")
      inspect(vertices[0].local_x, content="0")
      inspect(vertices[0].local_y, content="0")
    }
    _ => fail("expected shader effect item")
  }
}

///|
test "native renderer scopes inherit transform and clip but composite opacity once" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=10.0, dy=20.0),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=40.0, height=30.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.75,
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=0.0, y=0.0, width=30.0, height=20.0),
        ),
        offscreen=true,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopOpacity,
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.draw_items.length(), content="1")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeLayer(layer) => {
      inspect(layer.opacity, content="0.375")
      match layer.mask {
        Some(mask) => {
          inspect(mask.rect.origin.x, content="10")
          inspect(mask.rect.origin.y, content="20")
          inspect(mask.rect.size.width, content="30")
          inspect(mask.rect.size.height, content="20")
        }
        None => fail("expected transformed layer mask")
      }
      match layer.scissor {
        Some(scissor) => {
          inspect(scissor.x, content="10")
          inspect(scissor.y, content="20")
          inspect(scissor.width, content="30")
          inspect(scissor.height, content="20")
        }
        None => fail("expected transformed layer scissor")
      }
      inspect(layer.plan.visual_vertices.length(), content="6")
      let vertex = layer.plan.visual_vertices[0]
      inspect(vertex.x, content="-0.8")
      inspect(vertex.y, content="0.6")
      inspect(vertex.a0, content="1")
      let advanced = advanced_layer_vertices(renderer.size, layer)
      inspect(advanced.length(), content="6")
      inspect(advanced[0].x, content="-0.8")
      inspect(advanced[0].y, content="0.6")
      inspect(advanced[0].u, content="0.1")
      inspect(advanced[0].v, content="0.2")
      inspect(advanced[0].mask_kind, content="0")
    }
    _ => fail("expected native layer item")
  }
}

///|
test "native renderer filter scope inherits transform and transformed clip" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=10.0, dy=20.0),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=40.0, height=30.0),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(3.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopTransform,
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.draw_items.length(), content="1")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeLayer(filter_layer) => {
      assert_true(filter_layer.filter is Some(@core.FilterEffect::Blur(3.0)))
      match filter_layer.scissor {
        Some(scissor) => {
          inspect(scissor.x, content="10")
          inspect(scissor.y, content="20")
          inspect(scissor.width, content="40")
          inspect(scissor.height, content="30")
        }
        None => fail("expected transformed filter scissor")
      }
      inspect(filter_layer.plan.visual_vertices.length(), content="6")
      let vertex = filter_layer.plan.visual_vertices[0]
      inspect(vertex.x, content="-0.8")
      inspect(vertex.y, content="0.6")
      let advanced = advanced_layer_vertices(renderer.size, filter_layer)
      inspect(advanced.length(), content="6")
      inspect(advanced[0].filter_kind, content="1")
      inspect(advanced[0].filter_amount, content="3")
    }
    _ => fail("expected native filter layer item")
  }
}

///|
test "native renderer plans overlay layer for backdrop sampling pass" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.75,
        blend_mode=@core.BlendMode::Overlay,
        offscreen=true,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopLayer,
  ])
  inspect(renderer.unsupported_command_count, content="0")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeLayer(layer) => {
      assert_true(layer.blend_mode == @core.BlendMode::Overlay)
      let vertices = advanced_layer_vertices(renderer.size, layer)
      inspect(vertices.length(), content="6")
      inspect(vertices[0].blend_mode, content="3")
      inspect(vertices[0].opacity, content="0.75")
    }
    _ => fail("expected overlay native layer item")
  }
}

///|
test "advanced layer shader keeps transparent blend samples neutral" {
  let shader = advanced_shader_wgsl()
  assert_true(shader.contains("source_rgb = clamp(sample.rgb / sample.a"))
  assert_true(
    shader.contains("source_rgb * source_alpha + vec3<f32>(1.0 - source_alpha)"),
  )
  assert_true(shader.contains("return vec4<f32>(source_rgb * source_alpha"))
}
