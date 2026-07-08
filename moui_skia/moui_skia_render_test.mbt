///|
test "render pass descriptor clips clear and present boundaries" {
  let surface = @moui_skia.SurfaceDescriptor::window_n32_premul(
    @moui_skia.ISize::new(20, 10),
    sample_count=4,
    stencil_bits=8,
  )
  let pass = @moui_skia.RenderPassDescriptor::clear(
    surface,
    @moui_skia.Color::black(),
    bounds=Some(@moui_skia.IRect::from_xywh(5, -5, 20, 20)),
    store_op=PresentPixels,
  )
  assert_true(pass.surface == surface)
  assert_true(pass.bounds == @moui_skia.IRect::new(5, 0, 20, 10))
  assert_true(pass.load_op == ClearBeforeDraw)
  assert_true(pass.clear_color == Some(@moui_skia.Color::black()))
  assert_true(pass.store_op == PresentPixels)
  assert_true(pass.needs_clear())
  assert_true(pass.needs_present())
  assert_true(pass.keeps_pixels())
  assert_true(pass.is_msaa())
  assert_true(pass.resource_descriptor().key.kind == SurfaceResource)
  assert_true(pass.resource_descriptor().key == surface.resource_key())
  assert_eq(pass.resource_descriptor().byte_size, 3200L)

  let load = @moui_skia.RenderPassDescriptor::new(surface)
  let unbound_target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(20, 10),
    sample_count=4,
    stencil_bits=8,
  )
  assert_true(!load.has_target_binding())
  assert_true(load.is_bound_to_target(unbound_target))
  assert_true(load.load_op == LoadExisting)
  assert_true(load.clear_color is None)
  assert_true(load.store_op == StorePixels)
  assert_true(load.bounds == surface.bounds())
  assert_true(load.with_store_op(DiscardPixels).store_op == DiscardPixels)
  assert_true(load.with_clear_color(@moui_skia.Color::red()).needs_clear())
  assert_true(
    load.with_clear_color(@moui_skia.Color::red()).without_clear().clear_color
    is None,
  )

  let outside = pass.with_bounds(@moui_skia.IRect::from_xywh(99, 99, 4, 4))
  assert_true(outside.is_empty())
  assert_true(outside.bounds == @moui_skia.IRect::empty())
}

///|
test "render pass descriptor derives present defaults from surface targets" {
  let raster_target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(16, 16),
  )
  let raster_pass = @moui_skia.RenderPassDescriptor::for_target(raster_target)
  assert_true(raster_pass.has_target_binding())
  assert_true(raster_pass.is_bound_to_target(raster_target))
  assert_true(
    raster_pass.resource_descriptor().key == raster_target.resource_key(),
  )
  assert_true(
    raster_pass.resource_descriptor().key !=
    raster_target.surface.resource_key(),
  )
  assert_true(!raster_pass.needs_present())
  assert_true(raster_pass.keeps_pixels())
  assert_true(raster_pass.store_op == StorePixels)

  let window_target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(20, 10),
    sample_count=4,
    stencil_bits=8,
  )
  let present_pass = @moui_skia.RenderPassDescriptor::for_target(
    window_target,
    bounds=Some(@moui_skia.IRect::from_xywh(4, 2, 30, 30)),
  )
  assert_true(present_pass.needs_present())
  assert_true(present_pass.has_target_binding())
  assert_true(present_pass.is_bound_to_target(window_target))
  assert_true(
    !present_pass.is_bound_to_target(window_target.with_target_id(b"other")),
  )
  assert_true(
    present_pass.resource_descriptor().key == window_target.resource_key(),
  )
  assert_true(
    present_pass.resource_descriptor().key !=
    window_target.surface.resource_key(),
  )
  assert_true(present_pass.keeps_pixels())
  assert_true(present_pass.store_op == PresentPixels)
  assert_true(present_pass.bounds == @moui_skia.IRect::new(4, 2, 20, 10))
  assert_true(present_pass.is_msaa())

  let clear_pass = @moui_skia.RenderPassDescriptor::clear_target(
    window_target,
    @moui_skia.Color::blue(),
  )
  assert_true(clear_pass.needs_clear())
  assert_true(clear_pass.needs_present())
  assert_true(clear_pass.clear_color == Some(@moui_skia.Color::blue()))
  assert_true(
    clear_pass.resource_descriptor().key == window_target.resource_key(),
  )

  let discard_pass = @moui_skia.RenderPassDescriptor::for_target(
    window_target.without_present(),
    store_op=Some(DiscardPixels),
  )
  assert_true(!discard_pass.needs_present())
  assert_true(!discard_pass.keeps_pixels())
  assert_true(discard_pass.store_op == DiscardPixels)
}

///|
test "render command list tracks stats balance and touched bounds" {
  let target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(40, 20),
  )
  let path = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(5, 5))
    .line_to(@moui_skia.Point::new(12, 7))
  let commands = @moui_skia.RenderCommandList::for_target(
      target,
      bounds=Some(@moui_skia.IRect::from_xywh(0, 0, 30, 10)),
    )
    .save()
    .clip_rect(@moui_skia.Rect::from_xywh(0, 0, 12, 8))
    .draw_rect(
      @moui_skia.Rect::from_xywh(2, 2, 8, 4),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::red()),
    )
    .draw_path(
      path,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::blue()),
    )
    .draw_text_utf8(
      b"Skia",
      @moui_skia.Point::new(4, 8),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::black()),
    )
    .restore()
    .finish()
  let stats = commands.stats()
  assert_eq(commands.length(), 7)
  assert_eq(stats.command_count, 7)
  assert_eq(stats.draw_count, 3)
  assert_eq(stats.clip_count, 1)
  assert_eq(stats.state_count, 2)
  assert_eq(stats.transform_count, 0)
  assert_eq(stats.present_count, 1)
  assert_eq(stats.text_count, 1)
  assert_eq(stats.resource_declaration_count, 0)
  assert_eq(stats.image_resource_count, 0)
  assert_eq(stats.shader_resource_count, 0)
  assert_eq(stats.filter_resource_count, 0)
  assert_eq(stats.path_resource_count, 1)
  assert_eq(stats.text_resource_count, 0)
  assert_eq(stats.max_save_depth, 1)
  assert_true(stats.is_state_balanced())
  assert_true(commands.is_state_balanced())
  assert_true(commands.has_present())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::new(2, 0, 12, 8)),
  )
  assert_true(commands.finish().length() == commands.length())

  let raster_commands = @moui_skia.RenderCommandList::for_target(
      @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
        @moui_skia.ISize::new(8, 8),
      ),
    )
    .clear(@moui_skia.Color::white())
    .finish()
  assert_true(!raster_commands.has_present())
  assert_true(
    raster_commands.touched_bounds() == Some(@moui_skia.Rect::from_iwh(8, 8)),
  )

  let unbalanced = @moui_skia.RenderCommandList::for_target(target).restore()
  assert_true(!unbalanced.is_state_balanced())
  assert_eq(unbalanced.stats().unbalanced_restore_count, 1)
}

///|
test "render command list records canvas fill commands" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(20, 20),
  )
  let paint = @moui_skia.Paint::new(
    color=@moui_skia.Color::blue(),
    blend_mode=Src,
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(4, 4, 8, 8))
    .draw_color(@moui_skia.Color::red(), blend_mode=Src)
    .draw_paint(paint~)
  let stats = commands.stats()
  assert_eq(commands.length(), 3)
  assert_eq(stats.draw_count, 2)
  assert_eq(stats.clip_count, 1)
  assert_eq(stats.clear_count, 0)
  assert_eq(stats.resource_declaration_count, 0)
  assert_true(commands.commands[1].is_draw())
  assert_true(commands.commands[2].is_draw())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::from_xywh(4, 4, 8, 8)),
  )

  let unclipped = @moui_skia.RenderCommandList::for_target(target).draw_color(
    @moui_skia.Color::green(),
  )
  assert_true(
    unclipped.touched_bounds() == Some(@moui_skia.Rect::from_iwh(20, 20)),
  )

  let shader = @moui_skia.ShaderDescriptor::color(@moui_skia.Color::cyan())
  let shader_fill = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(5, 5, 6, 6))
    .draw_paint_shader(shader)
  let shader_fill_stats = shader_fill.stats()
  assert_eq(shader_fill.length(), 2)
  assert_eq(shader_fill_stats.draw_count, 1)
  assert_eq(shader_fill_stats.clip_count, 1)
  assert_eq(shader_fill_stats.shader_resource_count, 1)
  assert_true(
    shader_fill.commands[1].resource_descriptor() ==
    Some(shader.resource_descriptor()),
  )
  assert_true(shader_fill.resource_plan().contains_key(shader.resource_key()))
  assert_true(
    shader_fill.touched_bounds() == Some(@moui_skia.Rect::from_xywh(5, 5, 6, 6)),
  )
}

///|
test "render command list estimates text touched bounds" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(80, 40),
  )
  let legacy = @moui_skia.RenderCommandList::for_target(target).draw_text_utf8(
    b"abc",
    @moui_skia.Point::new(4, 20),
  )
  assert_true(
    legacy.touched_bounds() == Some(@moui_skia.Rect::new(4, 8, 28, 24)),
  )

  let ltr_run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(1, 4),
  )
  let ltr = @moui_skia.RenderCommandList::for_target(target).draw_text_run_utf8(
    b"abcde",
    @moui_skia.Point::new(10, 20),
    descriptor=Some(ltr_run),
  )
  assert_true(ltr.touched_bounds() == Some(@moui_skia.Rect::new(10, 8, 34, 24)))

  let rtl_run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(1, 4),
    direction=RightToLeft,
  )
  let rtl = @moui_skia.RenderCommandList::for_target(target).draw_text_run_utf8(
    b"abcde",
    @moui_skia.Point::new(30, 20),
    descriptor=Some(rtl_run),
  )
  assert_true(rtl.touched_bounds() == Some(@moui_skia.Rect::new(6, 8, 30, 24)))

  let clipped = @moui_skia.RenderCommandList::for_target(target)
    .translate(@moui_skia.Point::new(10, 0))
    .clip_rect(@moui_skia.Rect::from_xywh(0, 0, 20, 16))
    .draw_text_utf8(b"abcd", @moui_skia.Point::new(0, 12))
  assert_true(
    clipped.touched_bounds() == Some(@moui_skia.Rect::from_xywh(10, 0, 20, 16)),
  )

  let empty = @moui_skia.RenderCommandList::for_target(target)
    .draw_text_utf8(b"", @moui_skia.Point::new(4, 20))
    .draw_text_run_utf8(
      b"abc",
      @moui_skia.Point::new(10, 20),
      descriptor=Some(
        @moui_skia.TextRunDescriptor::new(range=@moui_skia.TextRange::new(3, 3)),
      ),
    )
  assert_true(empty.touched_bounds() is None)
}

///|
test "render command list records transform commands" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(24, 24),
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .save()
    .translate(@moui_skia.Point::new(2, 3))
    .scale(@moui_skia.Size::new(2, 2))
    .rotate(45)
    .skew(@moui_skia.Point::new(0.1, 0.2))
    .concat(@moui_skia.Matrix::translate(1, 2))
    .reset_matrix()
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
    .restore()
  let stats = commands.stats()
  assert_eq(commands.length(), 9)
  assert_eq(stats.command_count, 9)
  assert_eq(stats.state_count, 8)
  assert_eq(stats.transform_count, 6)
  assert_eq(stats.draw_count, 1)
  assert_eq(stats.max_save_depth, 1)
  assert_true(stats.is_state_balanced())
  assert_true(commands.commands[1].is_transform())
  assert_true(commands.commands[6].is_transform())
  assert_true(!commands.commands[7].is_transform())

  let translated = @moui_skia.RenderCommandList::for_target(target)
    .translate(@moui_skia.Point::new(10, 2))
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
  assert_true(
    translated.touched_bounds() == Some(@moui_skia.Rect::from_xywh(11, 3, 4, 4)),
  )

  let restored = @moui_skia.RenderCommandList::for_target(target)
    .save()
    .translate(@moui_skia.Point::new(10, 2))
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
    .restore()
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
  assert_true(
    restored.touched_bounds() == Some(@moui_skia.Rect::new(1, 1, 15, 7)),
  )

  let rotated = @moui_skia.RenderCommandList::for_target(target)
    .rotate(90)
    .draw_rect(@moui_skia.Rect::from_xywh(1, -3, 4, 2))
  assert_true(
    test_optional_rect_near(
      rotated.touched_bounds(),
      @moui_skia.Rect::new(1, 1, 3, 5),
    ),
  )
}

///|
test "render command touched bounds respect rectangular clips" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(32, 32),
  )
  let clipped = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(4, 4, 8, 8))
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
  assert_true(
    clipped.touched_bounds() == Some(@moui_skia.Rect::from_xywh(4, 4, 8, 8)),
  )

  let empty_clip = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(20, 20, 4, 4))
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
  assert_true(empty_clip.touched_bounds() is None)

  let restored_clip = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(4, 4, 8, 8))
    .save()
    .clip_rect(@moui_skia.Rect::from_xywh(6, 6, 2, 2))
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
    .restore()
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
  assert_true(
    restored_clip.touched_bounds() ==
    Some(@moui_skia.Rect::from_xywh(4, 4, 8, 8)),
  )

  let transformed_clip = @moui_skia.RenderCommandList::for_target(target)
    .translate(@moui_skia.Point::new(4, 0))
    .clip_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 4))
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 8, 8))
  assert_true(
    transformed_clip.touched_bounds() ==
    Some(@moui_skia.Rect::from_xywh(4, 0, 4, 4)),
  )

  let rounded_clip = @moui_skia.RRect::from_rect_xy(
    @moui_skia.Rect::from_xywh(4, 4, 12, 12),
    3.0,
    3.0,
  )
  let path_clip = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(6, 6, 6, 6),
  )
  let rounded_path_clip = @moui_skia.RenderCommandList::for_target(target)
    .clip_rrect(rounded_clip)
    .clip_path(path_clip)
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
  let rounded_path_stats = rounded_path_clip.stats()
  assert_eq(rounded_path_stats.clip_count, 2)
  assert_eq(rounded_path_stats.path_resource_count, 1)
  assert_true(rounded_path_clip.commands[0].is_clip())
  assert_true(rounded_path_clip.commands[1].is_clip())
  assert_true(
    rounded_path_clip.commands[1].resource_descriptor() ==
    Some(path_clip.resource_descriptor()),
  )
  assert_true(
    rounded_path_clip.resource_plan().contains_key(path_clip.resource_key()),
  )
  assert_true(
    rounded_path_clip.touched_bounds() ==
    Some(@moui_skia.Rect::from_xywh(6, 6, 6, 6)),
  )

  let difference_clip = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(4, 4, 8, 8), op=Difference)
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
  assert_true(
    difference_clip.touched_bounds() ==
    Some(@moui_skia.Rect::from_xywh(0, 0, 16, 16)),
  )
}

///|
test "render command list records rounded geometry draw commands" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(32, 32),
  )
  let rrect = @moui_skia.RRect::from_rect_xy(
    @moui_skia.Rect::from_xywh(12, 3, 8, 5),
    2.0,
    2.0,
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .draw_oval(@moui_skia.Rect::from_xywh(2, 2, 6, 4))
    .draw_circle(@moui_skia.Point::new(12, 12), 3.0)
    .draw_round_rect(@moui_skia.Rect::from_xywh(4, 16, 9, 5), 2.0, 2.0)
    .draw_rrect(rrect)
    .draw_drrect(
      @moui_skia.RRect::from_rect_xy(
        @moui_skia.Rect::from_xywh(18, 18, 10, 10),
        3.0,
        3.0,
      ),
      @moui_skia.RRect::from_rect_xy(
        @moui_skia.Rect::from_xywh(20, 20, 4, 4),
        1.0,
        1.0,
      ),
    )
  let stats = commands.stats()
  assert_eq(commands.length(), 5)
  assert_eq(stats.draw_count, 5)
  assert_eq(stats.text_count, 0)
  assert_true(stats.is_state_balanced())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::from_xywh(2, 2, 26, 26)),
  )
}

///|
test "render command list records point line and arc draw commands" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(32, 32),
  )
  let stroke = @moui_skia.Paint::new(
    color=@moui_skia.Color::green(),
    style=Stroke,
    stroke_width=2.0,
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .draw_point(@moui_skia.Point::new(2, 2), paint=stroke)
    .draw_line(
      @moui_skia.Point::new(6, 2),
      @moui_skia.Point::new(12, 2),
      paint=stroke,
    )
    .draw_points(
      [
        @moui_skia.Point::new(4, 12),
        @moui_skia.Point::new(10, 12),
        @moui_skia.Point::new(16, 12),
      ],
      paint=stroke,
      mode=Polygon,
    )
    .draw_arc(
      @moui_skia.Rect::from_xywh(18, 18, 6, 6),
      0.0,
      180.0,
      false,
      paint=stroke,
    )
  let stats = commands.stats()
  assert_eq(commands.length(), 4)
  assert_eq(stats.draw_count, 4)
  assert_eq(stats.text_count, 0)
  assert_true(stats.is_state_balanced())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::from_xywh(1, 1, 24, 24)),
  )

  let line_pairs = @moui_skia.RenderCommandList::for_target(target).draw_points(
    [
      @moui_skia.Point::new(2, 2),
      @moui_skia.Point::new(6, 2),
      @moui_skia.Point::new(30, 30),
    ],
    paint=stroke,
    mode=Lines,
  )
  assert_true(
    line_pairs.touched_bounds() == Some(@moui_skia.Rect::new(1, 1, 7, 3)),
  )
}

///|
test "render command list exposes text run resource keys" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(32, 16),
  )
  let fallback = @moui_skia.FontFallbackRequest::new(
    families=@moui_skia.FontFallbackChain::new(primary_family=b"Inter"),
    bcp47=[b"en"],
    character=0x68,
    style=@moui_skia.FontStyleRequest::normal(),
  )
  let descriptor = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(0, 5),
    fallback~,
  )
  let font_key = @moui_skia.RendererResourceKey::font(b"Inter:16:400")
  let expected_key = descriptor.resource_key(b"hello", font_key~)
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .draw_text_run_utf8(
      b"hello",
      @moui_skia.Point::new(2, 12),
      descriptor=Some(descriptor),
      font_key~,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::black()),
    )
    .draw_text_utf8(b"legacy", @moui_skia.Point::new(2, 8))
  let stats = commands.stats()
  assert_eq(stats.draw_count, 2)
  assert_eq(stats.text_count, 2)
  assert_true(
    commands.commands[0].text_run_resource_key() == Some(expected_key),
  )
  assert_true(commands.commands[1].text_run_resource_key() is None)
  let keys = commands.text_run_resource_keys()
  assert_eq(keys.length(), 1)
  assert_true(keys[0] == expected_key)

  let descriptors = commands
    .draw_path(
      @moui_skia.Path::new().add_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 4)),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::blue()),
    )
    .draw_text_run_utf8(
      b"hello",
      @moui_skia.Point::new(4, 12),
      descriptor=Some(descriptor),
      font_key~,
    )
    .resource_descriptors()
  assert_eq(descriptors.length(), 5)
  assert_true(descriptors[0].key.kind == SurfaceResource)
  assert_true(descriptors[0].key == target.resource_key())
  assert_true(descriptors[0].key != target.surface.resource_key())
  assert_eq(descriptors[0].byte_size, 2048L)
  let mut path_descriptor_seen = false
  let mut text_descriptor : @moui_skia.RendererResourceDescriptor? = None
  let mut font_descriptor_seen = false
  let mut fallback_descriptor_seen = false
  for descriptor in descriptors {
    if descriptor.key.kind == PathResource {
      path_descriptor_seen = descriptor.is_cacheable()
    }
    if descriptor.key == expected_key {
      text_descriptor = Some(descriptor)
    }
    if descriptor.key == font_key {
      font_descriptor_seen = descriptor.is_cacheable()
    }
    if descriptor.key == fallback.resource_key() {
      fallback_descriptor_seen = descriptor.is_cacheable()
    }
  }
  assert_true(path_descriptor_seen)
  assert_true(font_descriptor_seen)
  assert_true(fallback_descriptor_seen)
  guard text_descriptor is Some(text_descriptor) else {
    fail("text run descriptor should be included in resource plan")
  }
  assert_eq(text_descriptor.byte_size, 5L)
  assert_true(text_descriptor.is_cacheable())
  let plan = commands
    .draw_path(
      @moui_skia.Path::new().add_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 4)),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::blue()),
    )
    .draw_text_run_utf8(
      b"hello",
      @moui_skia.Point::new(4, 12),
      descriptor=Some(descriptor),
      font_key~,
    )
    .resource_plan()
  assert_eq(plan.length(), 5)
  assert_true(plan.byte_size > 2053L)
  assert_eq(plan.cacheable_count, 5)
  assert_eq(plan.uncacheable_count, 0)
  assert_eq(plan.gpu_backed_count, 0)
  assert_eq(plan.count_kind(FontResource), 1)
  assert_eq(plan.count_kind(TypefaceResource), 1)

  let cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new(max_bytes=8L)
  assert_true(
    cache.insert(
      text_descriptor.key,
      text_descriptor,
      byte_size=text_descriptor.byte_size,
    ),
  )
  assert_true(cache.contains(expected_key))
}

///|
test "render command list records shaped glyph run resources" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(48, 24),
  )
  let fallback = @moui_skia.FontFallbackRequest::new(
    families=@moui_skia.FontFallbackChain::new(primary_family=b"Inter"),
    bcp47=[b"en"],
    character=0x68,
  )
  let run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(0, 5),
    fallback~,
  )
  let shaping = @moui_skia.TextShapingDescriptor::new(
    run~,
    font_key=@moui_skia.RendererResourceKey::font(b"Inter:14"),
    width=128.0,
  )
  let shaped = shaping.shaped_run_descriptor(
    glyph_count=5,
    cluster_count=5,
    advance=@moui_skia.Point::new(18.0, 6.0),
  )
  let glyph_run = shaped.glyph_run_descriptor(
    glyph_ids=[7, 8, 9, 10, 11],
    positions=[
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(4.0, 0.0),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(12.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters=[0, 1, 2, 3, 4],
  )
  let command = @moui_skia.RenderCommand::draw_shaped_glyph_run_utf8(
    b"hello",
    glyph_run,
    @moui_skia.Point::new(2.0, 3.0),
    paint=@moui_skia.Paint::new(color=@moui_skia.Color::black()),
  )
  assert_true(command.is_draw())
  assert_true(command.is_text())
  assert_true(
    command.text_run_resource_key() == Some(glyph_run.resource_key(b"hello")),
  )
  guard command.resource_descriptor() is Some(glyph_descriptor) else {
    fail("shaped glyph command should expose its primary resource descriptor")
  }
  assert_true(glyph_descriptor.key == glyph_run.resource_key(b"hello"))
  let command_descriptors = command.resource_descriptors()
  assert_eq(command_descriptors.length(), 6)
  assert_true(command_descriptors[0].key == glyph_run.resource_key(b"hello"))
  assert_eq(command.text_resource_count(), 6)

  let commands = @moui_skia.RenderCommandList::for_target(target).draw_shaped_glyph_run_utf8(
    b"hello",
    glyph_run,
    @moui_skia.Point::new(2.0, 3.0),
    paint=@moui_skia.Paint::new(color=@moui_skia.Color::black()),
  )
  let stats = commands.stats()
  assert_eq(stats.command_count, 1)
  assert_eq(stats.draw_count, 1)
  assert_eq(stats.text_count, 1)
  assert_eq(stats.resource_declaration_count, 0)
  assert_eq(stats.image_resource_count, 0)
  assert_eq(stats.shader_resource_count, 0)
  assert_eq(stats.filter_resource_count, 0)
  assert_eq(stats.path_resource_count, 0)
  assert_eq(stats.text_resource_count, 6)
  assert_true(
    commands.text_run_resource_keys() == [glyph_run.resource_key(b"hello")],
  )
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::new(2.0, 3.0, 20.0, 9.0)),
  )
  let descriptors = commands.resource_descriptors()
  assert_eq(descriptors.length(), 7)
  assert_true(descriptors[0].key == target.resource_key())
  let plan = commands.resource_plan()
  assert_eq(plan.length(), 7)
  assert_eq(plan.count_kind(SurfaceResource), 1)
  assert_eq(plan.count_kind(TextRunResource), 4)
  assert_eq(plan.count_kind(FontResource), 1)
  assert_eq(plan.count_kind(TypefaceResource), 1)
  assert_true(plan.contains_key(glyph_run.resource_key(b"hello")))
  assert_true(plan.contains_key(shaped.resource_key(b"hello")))
  assert_true(plan.contains_key(shaping.resource_key(b"hello")))
  assert_true(
    plan.contains_key(run.resource_key(b"hello", font_key=shaping.font_key)),
  )
  let frame = commands.frame_descriptor(target)
  assert_true(frame.is_ready())
  assert_eq(frame.resource_plan.length(), 7)
  assert_true(
    frame.resource_plan.contains_key(glyph_run.resource_key(b"hello")),
  )

  let invalid_glyph_run = shaping
    .shaped_run_descriptor(glyph_count=0)
    .glyph_run_descriptor()
  assert_true(!invalid_glyph_run.is_valid())
  assert_eq(invalid_glyph_run.resource_plan(b"hello").length(), 1)
  assert_eq(invalid_glyph_run.resource_plan(b"hello").cacheable_count, 0)
  assert_eq(invalid_glyph_run.resource_plan(b"hello").uncacheable_count, 1)
  let invalid_commands = @moui_skia.RenderCommandList::for_target(target).draw_shaped_glyph_run_utf8(
    b"hello",
    invalid_glyph_run,
    @moui_skia.Point::new(2.0, 3.0),
  )
  assert_true(invalid_commands.touched_bounds() is None)
  assert_eq(invalid_commands.commands[0].resource_descriptors().length(), 1)
  assert_eq(invalid_commands.resource_plan().length(), 1)
  assert_eq(invalid_commands.resource_plan().count_kind(SurfaceResource), 1)
  assert_eq(invalid_commands.resource_plan().count_kind(TextRunResource), 0)
}

///|
test "render command list includes declared resource descriptors" {
  guard @moui_skia.ShaderDescriptor::linear_gradient(
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(16, 0),
      @moui_skia.Color::red(),
      @moui_skia.Color::blue(),
    )
    is Some(shader) else {
    fail("linear shader descriptor should be accepted")
  }
  guard @moui_skia.ColorFilterDescriptor::saturation(0.8) is Some(color_filter) else {
    fail("color filter descriptor should be accepted")
  }
  guard @moui_skia.ColorFilterDescriptor::brightness(1.1)
    is Some(layer_color_filter) else {
    fail("layer color filter descriptor should be accepted")
  }
  guard @moui_skia.ImageFilterDescriptor::blur(1.0, 2.0) is Some(image_filter) else {
    fail("image filter descriptor should be accepted")
  }
  guard @moui_skia.MaskFilterDescriptor::blur(2.0) is Some(mask_filter) else {
    fail("mask filter descriptor should be accepted")
  }
  let shader_descriptor = shader.resource_descriptor()
  let color_filter_descriptor = color_filter.resource_descriptor()
  let layer_color_filter_descriptor = layer_color_filter.resource_descriptor()
  let image_filter_descriptor = image_filter.resource_descriptor()
  let mask_filter_descriptor = mask_filter.resource_descriptor()
  guard @moui_skia.ImageDescriptor::encoded(
      b"render-command-image",
      format=Some(PNG),
      dimensions=Some(@moui_skia.ISize::new(2, 3)),
    )
    is Some(image) else {
    fail("encoded image descriptor should be accepted")
  }
  let image_descriptor = image.resource_descriptor()
  let shader_path = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(6, 9, 3, 2),
  )
  let shader_path_descriptor = shader_path.resource_descriptor()
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(16, 16),
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .declare_resource(shader_descriptor)
    .declare_resources([
      color_filter_descriptor, image_filter_descriptor, mask_filter_descriptor, shader_descriptor,
    ])
    .declare_resource(@moui_skia.RendererResourceDescriptor::shader(b""))
    .save_layer(
      bounds=Some(@moui_skia.Rect::from_xywh(0, 0, 16, 16)),
      color_filter=Some(layer_color_filter),
      image_filter=Some(image_filter),
      mask_filter=Some(mask_filter),
    )
    .draw_rect_shader(
      @moui_skia.Rect::from_xywh(8, 2, 4, 4),
      shader,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::white()),
    )
    .draw_round_rect_shader(
      @moui_skia.Rect::from_xywh(10, 8, 3, 3),
      1.0,
      1.0,
      shader,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::white()),
    )
    .draw_path_shader(
      shader_path,
      shader,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::white()),
    )
    .draw_image(image, @moui_skia.Point::new(13, 1))
    .draw_image_rect(
      image,
      @moui_skia.Rect::from_xywh(0, 0, 2, 3),
      @moui_skia.Rect::from_xywh(11, 12, 3, 2),
      sampling=@moui_skia.SamplingOptions::linear(),
    )
    .draw_rect(
      @moui_skia.Rect::from_xywh(2, 2, 4, 4),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::green()),
    )
    .restore()

  assert_true(
    @moui_skia.RenderCommand::declare_resource(shader_descriptor).is_resource_declaration(),
  )
  assert_true(
    @moui_skia.RenderCommand::draw_rect_shader(
      @moui_skia.Rect::from_xywh(8, 2, 4, 4),
      shader,
    ).resource_descriptor() ==
    Some(shader_descriptor),
  )
  assert_true(
    @moui_skia.RenderCommand::draw_round_rect_shader(
      @moui_skia.Rect::from_xywh(10, 8, 3, 3),
      1.0,
      1.0,
      shader,
    ).resource_descriptor() ==
    Some(shader_descriptor),
  )
  let path_shader_command = @moui_skia.RenderCommand::draw_path_shader(
    shader_path, shader,
  )
  let path_shader_descriptors = path_shader_command.resource_descriptors()
  assert_true(path_shader_command.resource_descriptor() is None)
  assert_eq(path_shader_descriptors.length(), 2)
  assert_true(path_shader_descriptors[0].key == shader_path_descriptor.key)
  assert_true(path_shader_descriptors[1].key == shader_descriptor.key)
  assert_eq(path_shader_command.resource_count_for_kind(PathResource), 1)
  assert_eq(path_shader_command.resource_count_for_kind(ShaderResource), 1)
  assert_eq(path_shader_command.filter_resource_count(), 0)
  assert_eq(path_shader_command.text_resource_count(), 0)
  assert_true(
    @moui_skia.RenderCommand::draw_image(image, @moui_skia.Point::new(13, 1)).resource_descriptor() ==
    Some(image_descriptor),
  )
  assert_true(
    @moui_skia.RenderCommand::draw_image_rect(
      image,
      @moui_skia.Rect::from_xywh(0, 0, 2, 3),
      @moui_skia.Rect::from_xywh(11, 12, 3, 2),
    ).resource_descriptor() ==
    Some(image_descriptor),
  )
  assert_eq(commands.length(), 13)
  let stats = commands.stats()
  assert_eq(stats.command_count, 13)
  assert_eq(stats.draw_count, 6)
  assert_eq(stats.state_count, 2)
  assert_eq(stats.text_count, 0)
  assert_eq(stats.resource_declaration_count, 5)
  assert_eq(stats.image_resource_count, 2)
  assert_eq(stats.shader_resource_count, 5)
  assert_eq(stats.filter_resource_count, 6)
  assert_eq(stats.path_resource_count, 1)
  assert_eq(stats.text_resource_count, 0)
  assert_eq(stats.max_save_depth, 1)
  assert_true(stats.is_state_balanced())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::from_xywh(2, 1, 13, 13)),
  )
  let descriptors = commands.resource_descriptors()
  assert_eq(descriptors.length(), 8)
  assert_true(descriptors[0].key.kind == SurfaceResource)
  assert_true(descriptors[0].key == target.resource_key())
  assert_true(descriptors[0].key != target.surface.resource_key())
  let plan = commands.resource_plan()
  assert_eq(plan.length(), 8)
  assert_eq(plan.cacheable_count, 8)
  assert_eq(plan.uncacheable_count, 0)
  assert_eq(plan.gpu_backed_count, 0)
  let mut shader_seen = false
  let mut shader_path_seen = false
  let mut image_seen = false
  let mut color_filter_seen = false
  let mut layer_color_filter_seen = false
  let mut image_filter_seen = false
  let mut mask_filter_seen = false
  for descriptor in descriptors {
    if descriptor.key == shader_descriptor.key {
      shader_seen = true
    }
    if descriptor.key == shader_path_descriptor.key {
      shader_path_seen = true
    }
    if descriptor.key == image_descriptor.key {
      image_seen = true
    }
    if descriptor.key == color_filter_descriptor.key {
      color_filter_seen = true
    }
    if descriptor.key == layer_color_filter_descriptor.key {
      layer_color_filter_seen = true
    }
    if descriptor.key == image_filter_descriptor.key {
      image_filter_seen = true
    }
    if descriptor.key == mask_filter_descriptor.key {
      mask_filter_seen = true
    }
  }
  assert_true(shader_seen)
  assert_true(shader_path_seen)
  assert_true(image_seen)
  assert_true(color_filter_seen)
  assert_true(layer_color_filter_seen)
  assert_true(image_filter_seen)
  assert_true(mask_filter_seen)
}

///|
test "render frame descriptor summarizes target commands and resources" {
  let target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(24, 16),
    present_mode=MailboxPresent,
  )
  let path = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(2, 3, 5, 6),
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .save()
    .draw_path(
      path,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::blue()),
    )
    .restore()
  let frame = commands.frame_descriptor(target)
  assert_true(frame.is_target_consistent())
  assert_true(frame.needs_present())
  assert_true(frame.has_present())
  assert_true(frame.is_ready())
  assert_true(frame.validation_status() == FrameReady)
  assert_true(frame.validation_status().is_ready())
  assert_eq(frame.stats.command_count, 4)
  assert_eq(frame.stats.present_count, 1)
  assert_true(
    frame.touched_bounds == Some(@moui_skia.Rect::from_xywh(2, 3, 5, 6)),
  )
  assert_true(frame.resource_plan.contains_key(target.resource_key()))
  assert_true(frame.resource_plan.contains_key(path.resource_key()))
  assert_true(
    frame.resource_plan.contains_key(
      frame.command_list.pass.resource_descriptor().key,
    ),
  )
  assert_true(!frame.resource_plan.contains_key(target.surface.resource_key()))
  assert_eq(frame.resource_plan.count_kind(SurfaceResource), 1)
  assert_eq(frame.resource_plan.count_kind(PathResource), 1)
  let frame_cacheable_plan = frame.cacheable_resource_plan()
  let frame_uncacheable_plan = frame.uncacheable_resource_plan()
  assert_true(
    frame_cacheable_plan == frame.resource_plan.cacheable_resource_plan(),
  )
  assert_eq(frame_cacheable_plan.length(), 2)
  assert_eq(frame_cacheable_plan.cacheable_count, 2)
  assert_true(frame_cacheable_plan.contains_key(target.resource_key()))
  assert_true(frame_cacheable_plan.contains_key(path.resource_key()))
  assert_true(frame_uncacheable_plan.is_empty())
  let cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_true(!cache.contains_resource_plan(frame.resource_plan))
  let frame_cached_before = frame.cached_cacheable_resource_plan(cache)
  let frame_missing_before = frame.missing_cacheable_resource_plan(cache)
  assert_true(frame_cached_before.is_empty())
  assert_eq(frame_missing_before.length(), 2)
  assert_true(frame_missing_before.contains_key(target.resource_key()))
  assert_true(frame_missing_before.contains_key(path.resource_key()))
  assert_eq(frame.cache_resources(cache), 2)
  assert_eq(cache.length(), 2)
  let frame_cached_after = frame.cached_cacheable_resource_plan(cache)
  let frame_missing_after = frame.missing_cacheable_resource_plan(cache)
  assert_eq(frame_cached_after.length(), 2)
  assert_true(frame_cached_after.contains_key(target.resource_key()))
  assert_true(frame_cached_after.contains_key(path.resource_key()))
  assert_true(frame_missing_after.is_empty())
  assert_true(cache.contains_resource_plan(frame.resource_plan))
  assert_true(cache.contains(target.resource_key()))
  assert_true(cache.contains(path.resource_key()))
  guard frame.present_descriptor(frame_index=5) is Some(present) else {
    fail("ready window frame should expose a present descriptor")
  }
  assert_eq(present.frame_index, 5)
  assert_eq(present.buffer_index, 1)
  assert_true(present.present_mode == Some(MailboxPresent))
  assert_true(present.resource_key().kind == SurfaceResource)
  assert_true(!present.resource_descriptor().is_cacheable())
  let present_plan = frame.present_resource_plan(frame_index=5)
  assert_eq(present_plan.length(), 2)
  assert_eq(present_plan.cacheable_count, 1)
  assert_eq(present_plan.uncacheable_count, 1)
  assert_true(present_plan.contains_key(target.resource_key()))
  assert_true(present_plan.contains_key(present.resource_key()))
  let submission = frame.submission_descriptor(frame_index=5)
  assert_true(submission.is_ready())
  assert_eq(submission.frame_index, 5)
  assert_true(submission.validation_status == FrameReady)
  assert_true(submission.has_present())
  assert_true(submission.present == Some(present))
  assert_eq(submission.resource_plan.length(), 3)
  assert_eq(submission.resource_plan.cacheable_count, 2)
  assert_eq(submission.resource_plan.uncacheable_count, 1)
  assert_eq(submission.resource_plan.count_kind(SurfaceResource), 2)
  assert_eq(submission.resource_plan.count_kind(PathResource), 1)
  assert_true(submission.resource_plan.contains_key(target.resource_key()))
  assert_true(submission.resource_plan.contains_key(path.resource_key()))
  assert_true(submission.resource_plan.contains_key(present.resource_key()))
  let submission_cacheable_plan = submission.cacheable_resource_plan()
  let submission_uncacheable_plan = submission.uncacheable_resource_plan()
  assert_true(
    submission_cacheable_plan ==
    submission.resource_plan.cacheable_resource_plan(),
  )
  assert_eq(submission_cacheable_plan.length(), 2)
  assert_eq(submission_cacheable_plan.cacheable_count, 2)
  assert_eq(submission_cacheable_plan.uncacheable_count, 0)
  assert_true(submission_cacheable_plan.contains_key(target.resource_key()))
  assert_true(submission_cacheable_plan.contains_key(path.resource_key()))
  assert_true(!submission_cacheable_plan.contains_key(present.resource_key()))
  assert_eq(submission_uncacheable_plan.length(), 1)
  assert_eq(submission_uncacheable_plan.cacheable_count, 0)
  assert_eq(submission_uncacheable_plan.uncacheable_count, 1)
  assert_true(submission_uncacheable_plan.contains_key(present.resource_key()))
  assert_true(!submission_uncacheable_plan.contains_key(target.resource_key()))
  let submission_cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_true(
    submission.cached_cacheable_resource_plan(submission_cache).is_empty(),
  )
  let submission_missing_before = submission.missing_cacheable_resource_plan(
    submission_cache,
  )
  assert_eq(submission_missing_before.length(), 2)
  assert_true(submission_missing_before.contains_key(target.resource_key()))
  assert_true(submission_missing_before.contains_key(path.resource_key()))
  assert_true(!submission_missing_before.contains_key(present.resource_key()))
  assert_eq(submission.cache_resources(submission_cache), 2)
  assert_eq(submission_cache.length(), 2)
  assert_eq(
    submission.cached_cacheable_resource_plan(submission_cache).length(),
    2,
  )
  assert_true(
    submission.missing_cacheable_resource_plan(submission_cache).is_empty(),
  )
  assert_true(submission_cache.contains(target.resource_key()))
  assert_true(submission_cache.contains(path.resource_key()))
  assert_true(!submission_cache.contains(present.resource_key()))
  let finalization = frame.finalization_descriptor(frame_index=5)
  assert_true(finalization.is_ready())
  assert_true(finalization.has_finalization())
  assert_eq(finalization.frame_index, 5)
  assert_true(finalization.validation_status == FrameReady)
  assert_true(!finalization.requires_gpu_context())
  guard finalization.finalization is Some(surface_finalization) else {
    fail("ready window frame should expose a finalization descriptor")
  }
  assert_true(
    surface_finalization == target.finalization_descriptor(frame_index=5),
  )
  assert_true(!surface_finalization.resource_descriptor().is_cacheable())
  assert_true(
    frame.finalization_resource_plan(frame_index=5) ==
    finalization.resource_plan,
  )
  assert_eq(finalization.resource_plan.length(), 3)
  assert_eq(finalization.resource_plan.cacheable_count, 2)
  assert_eq(finalization.resource_plan.uncacheable_count, 1)
  assert_eq(finalization.resource_plan.count_kind(SurfaceResource), 2)
  assert_eq(finalization.resource_plan.count_kind(PathResource), 1)
  assert_true(finalization.resource_plan.contains_key(target.resource_key()))
  assert_true(finalization.resource_plan.contains_key(path.resource_key()))
  assert_true(
    finalization.resource_plan.contains_key(surface_finalization.resource_key()),
  )
  let finalization_cacheable_plan = finalization.cacheable_resource_plan()
  let finalization_uncacheable_plan = finalization.uncacheable_resource_plan()
  assert_true(
    finalization_cacheable_plan ==
    finalization.resource_plan.cacheable_resource_plan(),
  )
  assert_eq(finalization_cacheable_plan.length(), 2)
  assert_eq(finalization_cacheable_plan.cacheable_count, 2)
  assert_eq(finalization_cacheable_plan.uncacheable_count, 0)
  assert_true(finalization_cacheable_plan.contains_key(target.resource_key()))
  assert_true(finalization_cacheable_plan.contains_key(path.resource_key()))
  assert_true(
    !finalization_cacheable_plan.contains_key(
      surface_finalization.resource_key(),
    ),
  )
  assert_eq(finalization_uncacheable_plan.length(), 1)
  assert_eq(finalization_uncacheable_plan.cacheable_count, 0)
  assert_eq(finalization_uncacheable_plan.uncacheable_count, 1)
  assert_true(
    finalization_uncacheable_plan.contains_key(
      surface_finalization.resource_key(),
    ),
  )
  assert_true(
    !finalization_uncacheable_plan.contains_key(target.resource_key()),
  )
  let finalization_cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_true(
    finalization.cached_cacheable_resource_plan(finalization_cache).is_empty(),
  )
  let finalization_missing_before = finalization.missing_cacheable_resource_plan(
    finalization_cache,
  )
  assert_eq(finalization_missing_before.length(), 2)
  assert_true(finalization_missing_before.contains_key(target.resource_key()))
  assert_true(finalization_missing_before.contains_key(path.resource_key()))
  assert_true(
    !finalization_missing_before.contains_key(
      surface_finalization.resource_key(),
    ),
  )
  assert_eq(finalization.cache_resources(finalization_cache), 2)
  assert_eq(finalization_cache.length(), 2)
  assert_eq(
    finalization.cached_cacheable_resource_plan(finalization_cache).length(),
    2,
  )
  assert_true(
    finalization.missing_cacheable_resource_plan(finalization_cache).is_empty(),
  )
  assert_true(finalization_cache.contains(target.resource_key()))
  assert_true(finalization_cache.contains(path.resource_key()))
  assert_true(!finalization_cache.contains(surface_finalization.resource_key()))

  let offscreen_target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(8, 8),
  )
  let offscreen_frame = @moui_skia.RenderCommandList::for_target(
      offscreen_target,
    )
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 2, 2))
    .frame_descriptor(offscreen_target)
  let offscreen_finalization = offscreen_frame.finalization_descriptor(
    frame_index=-2,
  )
  assert_true(!offscreen_frame.needs_present())
  assert_true(offscreen_finalization.is_ready())
  assert_true(offscreen_finalization.has_finalization())
  assert_eq(offscreen_finalization.frame_index, 0)
  assert_eq(offscreen_finalization.resource_plan.length(), 2)
  assert_eq(offscreen_finalization.resource_plan.cacheable_count, 1)
  assert_eq(offscreen_finalization.resource_plan.uncacheable_count, 1)
  assert_eq(offscreen_finalization.cacheable_resource_plan().length(), 1)
  assert_eq(offscreen_finalization.uncacheable_resource_plan().length(), 1)
  assert_true(
    offscreen_finalization.resource_plan.contains_key(
      offscreen_target.resource_key(),
    ),
  )

  let mismatch_target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(24, 16),
  )
  let mismatch_frame = @moui_skia.RenderCommandList::for_target(mismatch_target).frame_descriptor(
    target,
  )
  assert_true(!mismatch_frame.is_target_consistent())
  assert_true(mismatch_frame.validation_status() == FrameTargetMismatch)
  assert_true(!mismatch_frame.is_ready())
  assert_true(mismatch_frame.present_descriptor(frame_index=5) is None)
  assert_true(mismatch_frame.present_resource_plan(frame_index=5).is_empty())
  let mismatch_submission = mismatch_frame.submission_descriptor(frame_index=5)
  assert_true(!mismatch_submission.is_ready())
  assert_true(!mismatch_submission.has_present())
  assert_true(mismatch_submission.validation_status == FrameTargetMismatch)
  let mismatch_cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_eq(mismatch_submission.cache_resources(mismatch_cache), 0)
  assert_true(mismatch_cache.is_empty())
  let mismatch_finalization = mismatch_frame.finalization_descriptor(
    frame_index=5,
  )
  assert_true(!mismatch_finalization.is_ready())
  assert_true(!mismatch_finalization.has_finalization())
  assert_true(mismatch_finalization.validation_status == FrameTargetMismatch)
  let mismatch_finalization_cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_eq(
    mismatch_finalization.cache_resources(mismatch_finalization_cache),
    0,
  )
  assert_true(mismatch_finalization_cache.is_empty())

  let identity_target = target.with_target_id(b"frame-window")
  let identity_mismatch_target = identity_target.with_target_id(
    b"other-frame-window",
  )
  let identity_mismatch_frame = @moui_skia.RenderCommandList::for_target(
    identity_target,
  ).frame_descriptor(identity_mismatch_target)
  assert_true(!identity_mismatch_frame.is_target_consistent())
  assert_true(
    identity_mismatch_frame.validation_status() == FrameTargetMismatch,
  )
  assert_true(!identity_mismatch_frame.is_ready())

  let unbalanced_frame = @moui_skia.RenderCommandList::for_target(target)
    .save()
    .frame_descriptor(target)
  assert_true(unbalanced_frame.validation_status() == FrameUnbalancedState)
  assert_true(!unbalanced_frame.is_ready())

  let gpu_context = @moui_skia.GpuContextDescriptor::mock(
    id=b"frame-gpu-context",
  )
  let gpu_target = @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(16, 16),
    gpu_context_key=Some(gpu_context.resource_key()),
  )
  let gpu_frame = @moui_skia.RenderCommandList::for_target(gpu_target).frame_descriptor(
    gpu_target,
  )
  assert_true(gpu_frame.requires_gpu_context())
  assert_true(gpu_frame.has_gpu_context())
  assert_true(gpu_frame.is_ready())
  assert_eq(gpu_frame.resource_plan.gpu_backed_count, 2)
  let gpu_submission = gpu_frame.submission_descriptor(frame_index=2)
  let gpu_submission_plan = gpu_submission.gpu_backed_resource_plan()
  assert_true(gpu_submission.is_ready())
  assert_true(gpu_submission.has_present())
  assert_eq(gpu_submission.resource_plan.length(), 3)
  assert_eq(gpu_submission.resource_plan.gpu_backed_count, 3)
  assert_eq(gpu_submission_plan.length(), 3)
  assert_eq(gpu_submission_plan.gpu_backed_count, 3)
  assert_eq(gpu_submission_plan.cacheable_count, 2)
  assert_eq(gpu_submission_plan.uncacheable_count, 1)
  assert_true(gpu_submission_plan.contains_key(gpu_target.resource_key()))
  assert_true(gpu_submission_plan.contains_key(gpu_context.resource_key()))
  assert_eq(gpu_submission.cacheable_resource_plan().length(), 2)
  assert_eq(gpu_submission.uncacheable_resource_plan().length(), 1)
  guard gpu_submission.present is Some(gpu_present) else {
    fail("gpu frame submission should expose a present descriptor")
  }
  assert_true(gpu_submission_plan.contains_key(gpu_present.resource_key()))
  let gpu_finalization = gpu_frame.finalization_descriptor(frame_index=2)
  let gpu_finalization_plan = gpu_finalization.gpu_backed_resource_plan()
  assert_true(gpu_finalization.is_ready())
  assert_true(gpu_finalization.has_finalization())
  assert_true(gpu_finalization.requires_gpu_context())
  assert_eq(gpu_finalization.resource_plan.length(), 3)
  assert_eq(gpu_finalization.resource_plan.gpu_backed_count, 3)
  assert_eq(gpu_finalization_plan.length(), 3)
  assert_eq(gpu_finalization_plan.gpu_backed_count, 3)
  assert_eq(gpu_finalization_plan.cacheable_count, 2)
  assert_eq(gpu_finalization_plan.uncacheable_count, 1)
  assert_true(gpu_finalization_plan.contains_key(gpu_target.resource_key()))
  assert_true(gpu_finalization_plan.contains_key(gpu_context.resource_key()))
  assert_eq(gpu_finalization.cacheable_resource_plan().length(), 2)
  assert_eq(gpu_finalization.uncacheable_resource_plan().length(), 1)
  guard gpu_finalization.finalization is Some(gpu_surface_finalization) else {
    fail(
      "gpu frame finalization should expose a surface finalization descriptor",
    )
  }
  assert_true(
    gpu_finalization_plan.contains_key(gpu_surface_finalization.resource_key()),
  )

  let missing_context_target = gpu_target.without_gpu_context()
  let missing_context_frame = @moui_skia.RenderCommandList::for_target(
    missing_context_target,
  ).frame_descriptor(missing_context_target)
  assert_true(missing_context_frame.requires_gpu_context())
  assert_true(!missing_context_frame.has_gpu_context())
  assert_true(
    missing_context_frame.validation_status() == FrameMissingGpuContext,
  )
  assert_true(!missing_context_frame.is_ready())
  assert_true(missing_context_frame.present_descriptor(frame_index=1) is None)
  let missing_context_submission = missing_context_frame.submission_descriptor(
    frame_index=1,
  )
  assert_true(!missing_context_submission.is_ready())
  assert_true(!missing_context_submission.has_present())
  assert_eq(
    missing_context_submission
    .gpu_backed_resource_plan()
    .count_kind(GpuContextResource),
    0,
  )
  let missing_context_finalization = missing_context_frame.finalization_descriptor(
    frame_index=1,
  )
  assert_true(!missing_context_finalization.is_ready())
  assert_true(!missing_context_finalization.has_finalization())
  assert_true(missing_context_finalization.requires_gpu_context())
  assert_eq(
    missing_context_finalization
    .gpu_backed_resource_plan()
    .count_kind(GpuContextResource),
    0,
  )
}
