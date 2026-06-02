///|
fn native_test_assert_red_dominant_pixel(pixmap : @skia.Pixmap) -> Unit raise {
  assert_true(pixmap.pixels[0] > pixmap.pixels[1])
  assert_true(pixmap.pixels[0] > pixmap.pixels[2])
  assert_eq(pixmap.pixels[3], 0xff)
}

///|
fn native_test_assert_pixel(
  pixmap : @skia.Pixmap,
  red : Byte,
  green : Byte,
  blue : Byte,
  alpha : Byte,
) -> Unit raise {
  assert_eq(pixmap.pixels[0], red)
  assert_eq(pixmap.pixels[1], green)
  assert_eq(pixmap.pixels[2], blue)
  assert_eq(pixmap.pixels[3], alpha)
}

///|
fn native_test_assert_replay_resource_counts(
  stats : @native.CanvasReplayStats,
  command_stats : @skia.RenderCommandStats,
) -> Unit raise {
  assert_eq(
    stats.resource_declaration_count,
    command_stats.resource_declaration_count,
  )
  assert_eq(stats.image_resource_count, command_stats.image_resource_count)
  assert_eq(stats.shader_resource_count, command_stats.shader_resource_count)
  assert_eq(stats.filter_resource_count, command_stats.filter_resource_count)
  assert_eq(stats.path_resource_count, command_stats.path_resource_count)
  assert_eq(stats.text_resource_count, command_stats.text_resource_count)
}

///|
test "canvas replays rounded and path clips" {
  let replay_size = @skia.ISize::new(16, 16)
  let replay_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(
    replay_size,
  )
  let clip_path = @skia.Path::new().add_rect(@skia.Rect::from_xywh(4, 4, 4, 4))
  let commands = @skia.RenderCommandList::for_target(replay_target)
    .clip_rrect(
      @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(2, 2, 8, 8), 2.0, 2.0),
    )
    .clip_path(clip_path)
    .draw_rect(
      @skia.Rect::from_xywh(0, 0, 16, 16),
      paint=@skia.Paint::new(color=@skia.Color::red()),
    )
  assert_true(
    commands.touched_bounds() == Some(@skia.Rect::from_xywh(4, 4, 4, 4)),
  )
  let command_stats = commands.stats()
  assert_eq(command_stats.command_count, 3)
  assert_eq(command_stats.clip_count, 2)
  assert_eq(command_stats.clear_count, 0)
  assert_eq(command_stats.path_resource_count, 1)
  assert_true(commands.resource_plan().contains_key(clip_path.resource_key()))
  match @native.Surface::raster_n32_premul(replay_size) {
    None => ()
    Some(surface) =>
      match surface.canvas() {
        None => ()
        Some(canvas) => {
          canvas.clear(@skia.Color::white())
          let resources = @native.NativeReplayResources::new(
            path_max_bytes=1024L,
          )
          let stats = canvas.replay_with_resources(commands, resources)
          assert_true(stats.is_complete())
          assert_eq(stats.clip_count, 2)
          assert_eq(stats.clear_count, 0)
          assert_eq(stats.path_resource_count, 1)
          assert_eq(resources.path_cache.length(), 1)
          match surface.read_pixels(bounds=@skia.IRect::from_xywh(4, 4, 1, 1)) {
            None => ()
            Some(pixmap) =>
              native_test_assert_pixel(pixmap, 0xff, 0x00, 0x00, 0xff)
          }
          match surface.read_pixels(bounds=@skia.IRect::from_xywh(1, 1, 1, 1)) {
            None => ()
            Some(pixmap) =>
              native_test_assert_pixel(pixmap, 0xff, 0xff, 0xff, 0xff)
          }
        }
      }
  }
}

///|
test "canvas replays color and paint fills" {
  let replay_size = @skia.ISize::new(8, 8)
  let replay_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(
    replay_size,
  )
  let commands = @skia.RenderCommandList::for_target(replay_target)
    .draw_color(@skia.Color::red(), blend_mode=@skia.Src)
    .clip_rect(@skia.Rect::from_xywh(2, 2, 3, 3))
    .draw_paint(
      paint=@skia.Paint::new(color=@skia.Color::blue(), blend_mode=@skia.Src),
    )
  let command_stats = commands.stats()
  assert_eq(command_stats.command_count, 3)
  assert_eq(command_stats.draw_count, 2)
  assert_eq(command_stats.clip_count, 1)
  assert_eq(command_stats.clear_count, 0)
  assert_true(
    commands.touched_bounds() == Some(@skia.Rect::from_xywh(0, 0, 8, 8)),
  )
  match @native.Surface::raster_n32_premul(replay_size) {
    None => ()
    Some(surface) =>
      match surface.canvas() {
        None => ()
        Some(canvas) => {
          let stats = canvas.replay(commands)
          assert_true(stats.is_complete())
          assert_eq(stats.draw_count, 2)
          assert_eq(stats.clip_count, 1)
          assert_eq(stats.clear_count, 0)
          match surface.read_pixels(bounds=@skia.IRect::from_xywh(0, 0, 1, 1)) {
            None => ()
            Some(pixmap) =>
              native_test_assert_pixel(pixmap, 0xff, 0x00, 0x00, 0xff)
          }
          match surface.read_pixels(bounds=@skia.IRect::from_xywh(2, 2, 1, 1)) {
            None => ()
            Some(pixmap) =>
              native_test_assert_pixel(pixmap, 0x00, 0x00, 0xff, 0xff)
          }
        }
      }
  }
}

///|
test "canvas replays paint shader fills" {
  let replay_size = @skia.ISize::new(8, 8)
  let replay_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(
    replay_size,
  )
  let shader = @skia.ShaderDescriptor::color(@skia.Color::cyan())
  let commands = @skia.RenderCommandList::for_target(replay_target)
    .clear(@skia.Color::white())
    .clip_rect(@skia.Rect::from_xywh(2, 2, 3, 3))
    .draw_paint_shader(shader)
  let command_stats = commands.stats()
  assert_eq(command_stats.command_count, 3)
  assert_eq(command_stats.draw_count, 1)
  assert_eq(command_stats.clip_count, 1)
  assert_eq(command_stats.clear_count, 1)
  assert_eq(command_stats.shader_resource_count, 1)
  assert_true(commands.resource_plan().contains_key(shader.resource_key()))
  match @native.Surface::raster_n32_premul(replay_size) {
    None => ()
    Some(surface) =>
      match surface.canvas() {
        None => ()
        Some(canvas) => {
          let resources = @native.NativeReplayResources::new(
            shader_max_bytes=1024L,
          )
          let stats = canvas.replay_with_resources(commands, resources)
          assert_true(stats.is_complete())
          assert_eq(stats.draw_count, 1)
          assert_eq(stats.clip_count, 1)
          assert_eq(stats.clear_count, 1)
          assert_eq(stats.shader_resource_count, 1)
          assert_eq(resources.shader_cache.length(), 1)
          match surface.read_pixels(bounds=@skia.IRect::from_xywh(0, 0, 1, 1)) {
            None => ()
            Some(pixmap) =>
              native_test_assert_pixel(pixmap, 0xff, 0xff, 0xff, 0xff)
          }
          match surface.read_pixels(bounds=@skia.IRect::from_xywh(2, 2, 1, 1)) {
            None => ()
            Some(pixmap) =>
              native_test_assert_pixel(pixmap, 0x00, 0xff, 0xff, 0xff)
          }
        }
      }
  }
}

///|
test "native backend reports availability" {
  ignore(@native.skia_available())
}

///|
test "filter api is fallback-safe" {
  let matrix : Array[Float] = [
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
  ]
  if @native.skia_available() {
    assert_true(@native.ColorFilter::matrix(matrix) is Some(_))
    assert_true(@native.ColorFilter::saturation(0.5) is Some(_))
    assert_true(@native.ColorFilter::brightness(1.2) is Some(_))
    assert_true(@native.ColorFilter::contrast(1.1) is Some(_))
    assert_true(@native.ImageFilter::blur(2.0, 3.0) is Some(_))
    assert_true(@native.MaskFilter::blur(2.0) is Some(_))
  } else {
    assert_true(@native.ColorFilter::matrix(matrix) is None)
    assert_true(@native.ColorFilter::saturation(0.5) is None)
    assert_true(@native.ColorFilter::brightness(1.2) is None)
    assert_true(@native.ColorFilter::contrast(1.1) is None)
    assert_true(@native.ImageFilter::blur(2.0, 3.0) is None)
    assert_true(@native.MaskFilter::blur(2.0) is None)
  }
  assert_true(@native.ColorFilter::matrix([1.0, 0.0]) is None)
  assert_true(@native.ImageFilter::blur(0.0, 3.0) is None)
  assert_true(@native.MaskFilter::blur(0.0) is None)
}

///|
test "raster surface follows native availability" {
  let surface = @native.Surface::raster_n32_premul(@skia.ISize::new(16, 16))
  if @native.skia_available() {
    assert_true(surface is Some(_))
  } else {
    assert_true(surface is None)
  }
}

///|
test "surface factory follows target descriptor support" {
  let size = @skia.ISize::new(16, 16)
  let raster_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(size)
  let raster_surface = @native.Surface::for_target(raster_target)
  if @native.skia_available() {
    assert_true(
      @native.Surface::target_support_status(raster_target) ==
      @native.SurfaceTargetSupported,
    )
    assert_true(
      @native.Surface::target_support_status(raster_target).is_supported(),
    )
    match raster_surface {
      Some(surface) => {
        assert_true(surface.dimensions() == size)
        assert_true(surface.descriptor() == raster_target.surface)
      }
      None => fail("@native.Surface::for_target should create raster surfaces")
    }
  } else {
    assert_true(
      @native.Surface::target_support_status(raster_target) ==
      @native.SurfaceTargetSkiaUnavailable,
    )
    assert_true(
      !@native.Surface::target_support_status(raster_target).is_supported(),
    )
    assert_true(raster_surface is None)
  }
  assert_true(
    @native.Surface::target_support_status(
      @skia.SurfaceTargetDescriptor::raster_n32_premul(@skia.ISize::new(0, 16)),
    ) ==
    @native.SurfaceTargetEmpty,
  )
  assert_true(
    @native.Surface::for_target(
      @skia.SurfaceTargetDescriptor::raster_n32_premul(@skia.ISize::new(0, 16)),
    )
    is None,
  )

  let window_target = @skia.SurfaceTargetDescriptor::window_n32_premul(
    size,
    target_id=b"native-test-window",
  )
  assert_true(@native.Surface::for_target(window_target) is None)
  if @native.skia_available() {
    assert_true(
      @native.Surface::target_support_status(window_target) ==
      @native.SurfaceTargetWindowUnsupported,
    )
  } else {
    assert_true(
      @native.Surface::target_support_status(window_target) ==
      @native.SurfaceTargetSkiaUnavailable,
    )
  }
  let window_plan = window_target.resource_plan()
  assert_eq(window_plan.count_kind(@skia.SurfaceResource), 1)
  assert_eq(window_plan.length(), 1)

  let gpu_context = @skia.GpuContextDescriptor::mock(
    id=b"native-test-gpu-context",
  )
  let gpu_target = @skia.SurfaceTargetDescriptor::gpu_n32_premul(
    size,
    gpu_context_key=Some(gpu_context.resource_key()),
  )
  assert_true(@native.Surface::for_target(gpu_target) is None)
  if @native.skia_available() {
    assert_true(
      @native.Surface::target_support_status(gpu_target) ==
      @native.SurfaceTargetGpuUnsupported,
    )
  } else {
    assert_true(
      @native.Surface::target_support_status(gpu_target) ==
      @native.SurfaceTargetSkiaUnavailable,
    )
  }
  let gpu_plan = gpu_target.resource_plan()
  assert_eq(gpu_plan.count_kind(@skia.GpuSurfaceResource), 1)
  assert_eq(gpu_plan.count_kind(@skia.GpuContextResource), 1)
  assert_eq(gpu_plan.length(), 2)
}

///|
test "image snapshot is unavailable without linked skia" {
  if !@native.skia_available() {
    let surface = @native.Surface::raster_n32_premul(@skia.ISize::new(16, 16))
    assert_true(surface is None)
    assert_true(@native.Data::from_bytes(b"not an image") is None)
    assert_true(@native.Image::from_encoded_bytes(b"not an image") is None)
    assert_true(@native.Codec::from_bytes(b"not an image") is None)
  }
}

///|
test "image api typechecks" {
  match @native.Surface::raster_n32_premul(@skia.ISize::new(16, 16)) {
    None => ()
    Some(surface) => {
      match surface.image_snapshot() {
        None => ()
        Some(image) => {
          assert_true(image.is_available())
          assert_eq(image.width(), 16)
          assert_eq(image.height(), 16)
          assert_true(image.dimensions() == @skia.ISize::new(16, 16))
          assert_true(
            image.image_info() ==
            @skia.ImageInfo::n32_premul(@skia.ISize::new(16, 16)),
          )
        }
      }
      match surface.image_snapshot() {
        None => ()
        Some(image) =>
          match image.encode_to_data(format=@skia.PNG, quality=100) {
            None => ()
            Some(data) => {
              assert_true(data.is_available())
              assert_true(data.size() > 0)
              assert_true(!data.is_empty())
              let encoded = data.to_bytes()
              assert_eq(encoded.length(), data.size())
              match @native.Image::from_encoded_data(data) {
                None => ()
                Some(decoded) => {
                  assert_true(decoded.is_available())
                  assert_eq(decoded.width(), 16)
                  assert_eq(decoded.height(), 16)
                }
              }
              match @native.Image::from_encoded_bytes(encoded) {
                None => ()
                Some(decoded) => {
                  assert_true(decoded.is_available())
                  assert_eq(decoded.width(), 16)
                  assert_eq(decoded.height(), 16)
                }
              }
              match @native.Codec::from_data(data) {
                None => ()
                Some(codec) => {
                  assert_true(codec.is_available())
                  assert_eq(codec.width(), 16)
                  assert_eq(codec.height(), 16)
                  assert_true(codec.dimensions() == @skia.ISize::new(16, 16))
                  assert_true(
                    codec.image_info() ==
                    @skia.ImageInfo::n32_premul(@skia.ISize::new(16, 16)),
                  )
                  assert_true(codec.encoded_format() == Some(@skia.PNG))
                  match codec.decode_n32_premul() {
                    None => ()
                    Some(bitmap) => {
                      assert_true(bitmap.is_available())
                      assert_eq(bitmap.width(), 16)
                      assert_eq(bitmap.height(), 16)
                    }
                  }
                }
              }
            }
          }
      }
      match
        surface.image_snapshot_with_bounds(@skia.IRect::from_xywh(0, 0, 8, 8)) {
        None => ()
        Some(image) => {
          assert_true(image.is_available())
          assert_eq(image.width(), 8)
          assert_eq(image.height(), 8)
        }
      }
      match surface.read_pixels() {
        None => ()
        Some(pixmap) => {
          assert_eq(pixmap.width(), 16)
          assert_eq(pixmap.height(), 16)
          assert_eq(pixmap.pixels.length(), pixmap.byte_size())
        }
      }
      match surface.read_pixels(bounds=@skia.IRect::from_xywh(2, 2, 4, 4)) {
        None => ()
        Some(pixmap) => {
          assert_eq(pixmap.width(), 4)
          assert_eq(pixmap.height(), 4)
          assert_eq(pixmap.row_bytes, 16)
        }
      }
      let descriptor = surface.descriptor()
      assert_true(descriptor.is_raster())
      assert_true(descriptor.image_info == surface.image_info())
      assert_true(descriptor.dimensions() == @skia.ISize::new(16, 16))
      assert_true(!descriptor.is_gpu())
      assert_true(surface.flush_and_submit())
    }
  }
}

///|
test "path api typechecks" {
  let value_path = @skia.Path::new()
    .move_to(@skia.Point::new(0, 0))
    .line_to(@skia.Point::new(10, 0))
    .quad_to(@skia.Point::new(12, 4), @skia.Point::new(10, 10))
    .conic_to(@skia.Point::new(12, 12), @skia.Point::new(10, 14), 0.5)
    .cubic_to(
      @skia.Point::new(7, 12),
      @skia.Point::new(3, 12),
      @skia.Point::new(0, 10),
    )
    .close()
  match @native.Path::from_value(value_path) {
    None => ()
    Some(path) => {
      assert_true(path.is_available())
      assert_true(!path.is_empty())
      assert_true(path.is_finite())
      assert_true(path.fill_type() == value_path.fill_type)
      assert_true(path.bounds() == value_path.bounds())
      assert_eq(path.count_verbs(), value_path.count_verbs())
      assert_eq(path.count_points(), value_path.count_points())
      assert_true(path.segment_masks() == value_path.segment_masks())
      assert_true(path.is_last_contour_closed())
    }
  }
  match @native.Path::new() {
    None => ()
    Some(path) => {
      assert_true(path.is_available())
      assert_true(path.is_empty())
      assert_true(path.is_finite())
      assert_true(path.last_point() is None)
      assert_true(path.is_line() is None)
      assert_eq(path.count_verbs(), 0)
      assert_eq(path.count_points(), 0)
      assert_true(!path.is_last_contour_closed())
      assert_true(path.bounds() is None)
      path.set_fill_type(@skia.EvenOdd)
      assert_true(path.fill_type() == @skia.EvenOdd)
      assert_true(!path.is_inverse_fill_type())
      path.set_fill_type(@skia.InverseEvenOdd)
      assert_true(path.is_inverse_fill_type())
      path.set_fill_type(@skia.EvenOdd)
      path.move_to(@skia.Point::new(1, 2))
      path.line_to(@skia.Point::new(3, 4))
      assert_true(path.last_point() == Some(@skia.Point::new(3, 4)))
      assert_true(
        path.is_line() ==
        Some(
          @skia.PathLine::new(@skia.Point::new(1, 2), @skia.Point::new(3, 4)),
        ),
      )
      path.rewind()
      path.add_rect(@skia.Rect::from_xywh(1, 2, 3, 4))
      assert_true(path.bounds() == Some(@skia.Rect::from_xywh(1, 2, 3, 4)))
      assert_true(
        path.is_rect() ==
        Some(
          @skia.PathRect::new(@skia.Rect::from_xywh(1, 2, 3, 4), true, @skia.CW),
        ),
      )
      assert_true(path.contains(@skia.Point::new(2, 3)))
      assert_true(!path.contains(@skia.Point::new(9, 9)))
      assert_true(path.segment_masks().contains(@skia.PathSegmentMask::line()))
      assert_eq(path.count_verbs(), 5)
      assert_eq(path.count_points(), 4)
      assert_true(path.is_last_contour_closed())
      path.rewind()
      path.add_poly(
        [
          @skia.Point::new(0, 0),
          @skia.Point::new(10, 0),
          @skia.Point::new(10, 10),
        ],
        close=true,
      )
      assert_true(path.bounds() == Some(@skia.Rect::from_xywh(0, 0, 10, 10)))
      assert_eq(path.count_verbs(), 4)
      assert_eq(path.count_points(), 3)
      assert_true(path.is_last_contour_closed())
      assert_true(path.contains(@skia.Point::new(8, 2)))
      let empty : Array[@skia.Point] = []
      path.rewind()
      path.add_poly(empty)
      assert_true(path.is_empty())
      path.rewind()
      path.add_rect(@skia.Rect::from_xywh(0, 0, 2, 2))
      let portable_triangle = @skia.Path::new().add_poly(
        [
          @skia.Point::new(0, 0),
          @skia.Point::new(10, 0),
          @skia.Point::new(10, 10),
        ],
        close=true,
      )
      path.add_path_value(
        portable_triangle,
        matrix=@skia.Matrix::translate(10, 0),
      )
      assert_true(path.bounds() == Some(@skia.Rect::new(0, 0, 20, 10)))
      assert_eq(path.count_verbs(), 9)
      assert_eq(path.count_points(), 7)
      assert_true(path.contains(@skia.Point::new(18, 2)))
      path.rewind()
      path.add_rect(@skia.Rect::from_xywh(0, 0, 2, 2))
      path.add_path_value_offset(portable_triangle, @skia.Point::new(10, 0))
      assert_true(path.bounds() == Some(@skia.Rect::new(0, 0, 20, 10)))
      assert_eq(path.count_verbs(), 9)
      assert_eq(path.count_points(), 7)
      path.rewind()
      path.move_to(@skia.Point::new(0, 0))
      path.line_to(@skia.Point::new(2, 0))
      path.add_path_value(
        @skia.Path::new()
        .move_to(@skia.Point::new(10, 0))
        .line_to(@skia.Point::new(12, 0)),
        mode=@skia.Extend,
      )
      assert_eq(path.count_verbs(), 4)
      assert_eq(path.count_points(), 4)
      assert_true(path.last_point() == Some(@skia.Point::new(12, 0)))
      assert_true(path.bounds() == Some(@skia.Rect::from_xywh(0, 0, 12, 0)))
      path.rewind()
      path.add_oval(@skia.Rect::from_xywh(0, 0, 10, 20), direction=@skia.CCW)
      assert_true(path.bounds() == Some(@skia.Rect::from_xywh(0, 0, 10, 20)))
      assert_true(path.is_oval() == Some(@skia.Rect::from_xywh(0, 0, 10, 20)))
      assert_true(path.compute_tight_bounds() == path.bounds())
      assert_true(path.count_verbs() >= 5)
      assert_true(path.is_last_contour_closed())
      path.rewind()
      path.add_circle(@skia.Point::new(5, 5), 3)
      assert_true(path.bounds() == Some(@skia.Rect::from_xywh(2, 2, 6, 6)))
      assert_true(path.is_oval() == Some(@skia.Rect::from_xywh(2, 2, 6, 6)))
      assert_true(path.is_last_contour_closed())
      path.rewind()
      path.add_round_rect(@skia.Rect::from_xywh(0, 0, 10, 8), 2, 3)
      assert_true(path.bounds() == Some(@skia.Rect::from_xywh(0, 0, 10, 8)))
      assert_true(path.compute_tight_bounds() == path.bounds())
      assert_true(path.is_last_contour_closed())
      path.rewind()
      path.add_rrect(
        @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(0, 0, 10, 8), 2, 3),
      )
      assert_true(path.bounds() == Some(@skia.Rect::from_xywh(0, 0, 10, 8)))
      assert_true(path.is_last_contour_closed())
      path.rewind()
      path.add_rect(@skia.Rect::from_xywh(1, 2, 3, 4))
      path.offset(10, 20)
      assert_true(path.bounds() == Some(@skia.Rect::from_xywh(11, 22, 3, 4)))
      path.transform(@skia.Matrix::scale_translate(2, 3, 1, 2))
      assert_true(path.bounds() == Some(@skia.Rect::new(23, 68, 29, 80)))
      path.rewind()
      path.move_to(@skia.Point::new(0, 0))
      path.line_to(@skia.Point::new(10, 0))
      path.quad_to(@skia.Point::new(12, 4), @skia.Point::new(10, 10))
      path.conic_to(@skia.Point::new(12, 12), @skia.Point::new(10, 14), 0.5)
      path.cubic_to(
        @skia.Point::new(7, 12),
        @skia.Point::new(3, 12),
        @skia.Point::new(0, 10),
      )
      path.close()
      assert_true(path.bounds() == value_path.bounds())
      assert_true(
        path.compute_tight_bounds() == value_path.compute_tight_bounds(),
      )
      assert_eq(path.count_verbs(), value_path.count_verbs())
      assert_eq(path.count_points(), value_path.count_points())
      assert_true(path.is_last_contour_closed())
      path.set_fill_type(@skia.EvenOdd)
      path.rewind()
      assert_true(path.is_empty())
      assert_eq(path.count_verbs(), 0)
      assert_eq(path.count_points(), 0)
      assert_true(path.segment_masks() == @skia.PathSegmentMask::empty())
      assert_true(!path.is_last_contour_closed())
      assert_true(path.bounds() is None)
      assert_true(path.fill_type() == @skia.Winding)
      path.reset()
      assert_true(path.bounds() is None)
    }
  }
}

///|
test "bitmap api typechecks" {
  assert_true(@native.Bitmap::alloc_n32_premul(@skia.ISize::empty()) is None)
  match @native.Bitmap::alloc_n32_premul(@skia.ISize::new(4, 4)) {
    None => ()
    Some(bitmap) => {
      assert_true(bitmap.is_available())
      assert_eq(bitmap.width(), 4)
      assert_eq(bitmap.height(), 4)
      assert_true(bitmap.dimensions() == @skia.ISize::new(4, 4))
      assert_true(
        bitmap.image_info() ==
        @skia.ImageInfo::n32_premul(@skia.ISize::new(4, 4)),
      )
      assert_true(bitmap.row_bytes() >= 16)
      assert_true(bitmap.byte_size() >= 64)
      bitmap.erase_color(@skia.Color::blue())
      let pixels = bitmap.to_bytes()
      assert_eq(pixels.length(), bitmap.byte_size())
      match bitmap.to_pixmap() {
        None => ()
        Some(pixmap) => {
          assert_eq(pixmap.width(), 4)
          assert_eq(pixmap.height(), 4)
          assert_eq(pixmap.byte_size(), bitmap.byte_size())
        }
      }
      match @native.Image::from_bitmap(bitmap) {
        None => ()
        Some(image) => {
          assert_true(image.is_available())
          assert_eq(image.width(), 4)
          assert_eq(image.height(), 4)
        }
      }
    }
  }
}

///|
test "font api typechecks" {
  assert_true(@native.Font::default(size=0.0) is None)
  assert_true(@native.Font::empty(size=0.0) is None)
  match @native.Font::empty(size=14.0) {
    None => assert_true(!@native.skia_available())
    Some(font) => {
      assert_true(font.is_available())
      assert_eq(font.size(), 14.0)
      assert_eq(font.measure_text_utf8(b""), 0.0)
      assert_eq(font.count_text_utf8(b""), 0)
      assert_eq(font.text_to_glyphs_utf8(b"").length(), 0)
      font.set_size(18.0)
      assert_eq(font.size(), 18.0)
    }
  }
  assert_true(@native.Typeface::from_name(b"") is None)
  assert_true(
    @native.Typeface::from_name(b"", weight=700, width=5, slant=1) is None,
  )
  assert_true(
    @native.Typeface::from_name_style(
      b"",
      @skia.FontStyleRequest::new(weight=700, width=5, slant=1),
    )
    is None,
  )
  match @native.Font::default(size=14.0) {
    None => ()
    Some(font) => {
      assert_true(font.is_available())
      assert_eq(font.size(), 14.0)
      font.set_size(18.0)
      assert_eq(font.size(), 18.0)
      assert_eq(font.measure_text_utf8(b""), 0.0)
      assert_eq(font.count_text_utf8(b""), 0)
      assert_eq(font.text_to_glyphs_utf8(b"").length(), 0)
      assert_true(font.measure_text_bounds_utf8(b"") is None)
      assert_true(font.measure_text_utf8(b"Skia") > 0.0)
      assert_eq(font.count_text_utf8(b"Skia"), 4)
      let glyphs = font.text_to_glyphs_utf8(b"Skia")
      assert_eq(glyphs.length(), 4)
      assert_true(glyphs[0].to_int() > 0)
      let cjk_glyphs = font.text_to_glyphs_utf8(b"\xe4\xbd\xa0S")
      assert_eq(cjk_glyphs.length(), 2)
      assert_true(cjk_glyphs.all(glyph => glyph.to_int() > 0))
      assert_true(font.glyph_width(glyphs[0]) > 0.0)
      let glyph_widths = font.glyph_widths(glyphs)
      assert_eq(glyph_widths.length(), glyphs.length())
      assert_true(glyph_widths[0] > 0.0)
      let glyph_x_positions = font.glyph_x_positions(glyphs, origin=3.0)
      assert_eq(glyph_x_positions.length(), glyphs.length())
      assert_eq(glyph_x_positions[0], 3.0)
      assert_true(glyph_x_positions[1] > glyph_x_positions[0])
      let glyph_positions = font.glyph_positions(
        glyphs,
        origin=@skia.Point::new(3.0, 5.0),
      )
      assert_eq(glyph_positions.length(), glyphs.length())
      assert_true(glyph_positions[0] == @skia.Point::new(3.0, 5.0))
      assert_true(glyph_positions[1].x > glyph_positions[0].x)
      let text_glyph_x_positions = font.text_glyph_x_positions_utf8(
        b"Skia",
        origin=3.0,
      )
      assert_eq(text_glyph_x_positions.length(), glyphs.length())
      assert_eq(text_glyph_x_positions[0], 3.0)
      assert_true(text_glyph_x_positions[1] > text_glyph_x_positions[0])
      let text_glyph_positions = font.text_glyph_positions_utf8(
        b"Skia",
        origin=@skia.Point::new(3.0, 5.0),
      )
      assert_eq(text_glyph_positions.length(), glyphs.length())
      assert_true(text_glyph_positions[0] == @skia.Point::new(3.0, 5.0))
      assert_true(text_glyph_positions[1].x > text_glyph_positions[0].x)
      let glyph_bounds = font.glyph_bounds(glyphs[0])
      assert_true(glyph_bounds.width() > 0.0)
      assert_true(glyph_bounds.height() > 0.0)
      let glyph_bounds_many = font.glyph_bounds_many(glyphs)
      assert_eq(glyph_bounds_many.length(), glyphs.length())
      assert_true(glyph_bounds_many[0].width() > 0.0)
      match font.measure_text_bounds_utf8(b"Skia") {
        None => ()
        Some(bounds) => {
          assert_true(bounds.width() > 0.0)
          assert_true(bounds.height() >= 0.0)
        }
      }
      match font.shape_text_utf8(b"Skia") {
        None => assert_true(!@native.skia_shaper_available())
        Some(run) => {
          assert_true(@native.skia_shaper_available())
          assert_true(run.is_available())
          let shaped_glyph_count = run.glyph_count()
          assert_true(shaped_glyph_count > 0)
          let shaped_glyphs = run.glyphs()
          let shaped_positions = run.positions()
          let shaped_clusters = run.clusters()
          assert_eq(shaped_glyphs.length(), shaped_glyph_count)
          assert_eq(shaped_positions.length(), shaped_glyph_count)
          assert_eq(shaped_clusters.length(), shaped_glyph_count)
          assert_true(shaped_glyphs[0].to_int() > 0)
          assert_true(shaped_positions[0].x >= 0.0)
          assert_true(shaped_clusters[0] >= 0)
          assert_true(run.advance().x > 0.0)
        }
      }
      let shaping = @skia.TextShapingDescriptor::new(
        run=@skia.TextRunDescriptor::new(
          range=@skia.TextRange::new(0, b"Skia".length()),
        ),
        font_key=@skia.RendererResourceKey::font(b"native-test-default"),
      )
      match font.shape_text_run_utf8(b"Skia", shaping) {
        None => assert_true(!@native.skia_shaper_available())
        Some(glyph_run) => {
          assert_true(@native.skia_shaper_available())
          assert_true(glyph_run.is_valid())
          assert_true(glyph_run.glyph_count() > 0)
          let glyph_run_plan = glyph_run.resource_plan(b"Skia")
          assert_eq(glyph_run_plan.count_kind(@skia.TextRunResource), 4)
          assert_eq(glyph_run_plan.count_kind(@skia.FontResource), 1)
        }
      }
      assert_true(font.shape_text_utf8(b"") is None)
      assert_true(font.shape_text_utf8(b"Skia", width=0.0) is None)
      assert_true(font.shape_text_run_utf8(b"", shaping) is None)
      assert_true(
        font.shape_text_run_utf8(
          b"Skia",
          @skia.TextShapingDescriptor::new(
            run=@skia.TextRunDescriptor::new(range=@skia.TextRange::new(0, 0)),
          ),
        )
        is None,
      )
      let metrics = font.metrics()
      assert_true(metrics.ascent <= 0.0)
      assert_true(metrics.descent >= 0.0)
      assert_true(font.spacing() >= metrics.descent - metrics.ascent)
      ignore(metrics.underline_thickness)
      ignore(metrics.underline_position)
      ignore(metrics.strikeout_thickness)
      ignore(metrics.strikeout_position)
      ignore(metrics.has_bounds)
    }
  }
  match @native.Typeface::default() {
    None => ()
    Some(typeface) => {
      assert_true(typeface.is_available())
      ignore(typeface.is_bold())
      ignore(typeface.is_italic())
      ignore(typeface.is_fixed_pitch())
      match typeface.family_name() {
        None => ()
        Some(family_name) => assert_true(!family_name.is_empty())
      }
      match @native.Font::from_typeface(typeface, size=16.0) {
        None => ()
        Some(font) => {
          assert_true(font.is_available())
          assert_eq(font.size(), 16.0)
          assert_true(font.measure_text_utf8(b"MoonBit") > 0.0)
          assert_eq(font.count_text_utf8(b"MoonBit"), 7)
          let glyphs = font.text_to_glyphs_utf8(b"MoonBit")
          assert_eq(glyphs.length(), 7)
          assert_eq(font.glyph_widths(glyphs).length(), 7)
          assert_eq(font.glyph_positions(glyphs).length(), 7)
          assert_eq(font.text_glyph_positions_utf8(b"MoonBit").length(), 7)
          assert_eq(font.glyph_bounds_many(glyphs).length(), 7)
          match font.measure_text_bounds_utf8(b"MoonBit") {
            None => ()
            Some(bounds) => assert_true(bounds.width() > 0.0)
          }
          assert_true(font.spacing() > 0.0)
        }
      }
    }
  }
  match @native.FontMgr::default() {
    None => ()
    Some(font_mgr) => {
      assert_true(font_mgr.is_available())
      assert_true(@native.Typeface::from_font_mgr_family(font_mgr, b"") is None)
      let bold_italic = @skia.FontStyleRequest::new(
        weight=700,
        width=5,
        slant=1,
      )
      assert_true(font_mgr.match_family_style_request(b"", bold_italic) is None)
      assert_true(
        font_mgr.match_family_style_character(
          b"",
          [b"en"],
          0,
          style=bold_italic,
        )
        is None,
      )
      assert_true(
        @native.Typeface::from_font_mgr_request(
          font_mgr,
          @skia.FontFallbackRequest::new(),
        )
        is None,
      )
      assert_true(
        font_mgr.resolve_fallback_request(@skia.FontFallbackRequest::new())
        is None,
      )
      assert_true(
        @native.Typeface::from_font_mgr_family(
          font_mgr,
          b"",
          weight=700,
          width=5,
          slant=1,
        )
        is None,
      )
      let family_count = font_mgr.count_families()
      assert_true(family_count >= 0)
      assert_true(font_mgr.family_name(-1) is None)
      assert_true(font_mgr.family_name(family_count) is None)
      if family_count > 0 {
        match font_mgr.family_name(0) {
          None => ()
          Some(family_name) => {
            assert_true(!family_name.is_empty())
            match font_mgr.match_family_style(family_name) {
              None => ()
              Some(typeface) => {
                assert_true(typeface.is_available())
                match typeface.family_name() {
                  None => ()
                  Some(matched_family_name) =>
                    assert_true(!matched_family_name.is_empty())
                }
                assert_true(
                  @native.Typeface::from_font_mgr_family(font_mgr, family_name)
                  is Some(_),
                )
                let fallback_request = @skia.FontFallbackRequest::new(
                  families=@skia.FontFallbackChain::new(fallback_families=[
                    b"", family_name,
                  ]),
                  bcp47=[b"zh-Hans"],
                  character=0x4F60,
                  style=bold_italic,
                )
                match font_mgr.match_fallback_request(fallback_request) {
                  None => ()
                  Some(fallback_typeface) =>
                    assert_true(fallback_typeface.is_available())
                }
                match font_mgr.resolve_fallback_request(fallback_request) {
                  None => ()
                  Some(resolved) => {
                    assert_true(resolved.is_available())
                    assert_true(resolved.typeface.is_available())
                    assert_true(resolved.resolution.is_valid())
                    assert_true(!resolved.resolution.resource_key().is_empty())
                    let resolved_plan = resolved.resource_plan(size=14.0)
                    assert_eq(
                      resolved_plan.count_kind(@skia.TypefaceResource),
                      3,
                    )
                    assert_eq(resolved_plan.count_kind(@skia.FontResource), 1)
                  }
                }
                let latin_fallback_request = @skia.FontFallbackRequest::new(
                  families=@skia.FontFallbackChain::new(
                    primary_family=family_name,
                  ),
                  bcp47=[b"en"],
                  character=0x53,
                  style=bold_italic,
                )
                match font_mgr.match_fallback_request(latin_fallback_request) {
                  None => ()
                  Some(fallback_typeface) =>
                    assert_true(fallback_typeface.is_available())
                }
                match
                  font_mgr.match_family_style_character(
                    family_name,
                    [b"en"],
                    0x53,
                    style=bold_italic,
                  ) {
                  None => ()
                  Some(fallback_typeface) =>
                    assert_true(fallback_typeface.is_available())
                }
                match
                  font_mgr.match_family_style(
                    family_name,
                    weight=700,
                    width=5,
                    slant=1,
                  ) {
                  None => ()
                  Some(styled_typeface) =>
                    assert_true(styled_typeface.is_available())
                }
              }
            }
          }
        }
      }
    }
  }
  match @native.Typeface::from_name(b"Arial") {
    None => ()
    Some(typeface) => {
      assert_true(typeface.is_available())
      match @native.Font::from_typeface(typeface, size=13.0) {
        None => ()
        Some(font) => assert_eq(font.size(), 13.0)
      }
    }
  }
  match @native.Typeface::from_name(b"Arial", weight=700, width=5, slant=1) {
    None => ()
    Some(typeface) => {
      assert_true(typeface.is_available())
      match @native.Font::from_typeface(typeface, size=13.0) {
        None => ()
        Some(font) => assert_true(font.measure_text_utf8(b"Styled") > 0.0)
      }
    }
  }
}

///|
test "shader api typechecks" {
  match @native.Shader::color(@skia.Color::red()) {
    None => ()
    Some(shader) => assert_true(shader.is_available())
  }
  match
    @native.Shader::linear_gradient(
      @skia.Point::new(0, 0),
      @skia.Point::new(16, 0),
      @skia.Color::red(),
      @skia.Color::blue(),
      tile_mode=@skia.Mirror,
    ) {
    None => ()
    Some(shader) => assert_true(shader.is_available())
  }
  assert_true(
    @native.Shader::radial_gradient(
      @skia.Point::new(8, 8),
      0.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is None,
  )
  match
    @native.Shader::radial_gradient(
      @skia.Point::new(8, 8),
      8.0,
      @skia.Color::white(),
      @skia.Color::black(),
      tile_mode=@skia.Clamp,
    ) {
    None => ()
    Some(shader) => assert_true(shader.is_available())
  }
}

///|
test "canvas draw api typechecks" {
  fn exercise_canvas_api(canvas : @native.Canvas) -> Unit raise {
    let paint = @skia.Paint::new(color=@skia.Color::green(), anti_alias=true).set_stroke_width(
      2.0,
    )
    let save_count = canvas.save()
    assert_true(save_count >= 0)
    assert_true(canvas.save_count() >= 0)
    let layer_count = canvas.save_layer()
    assert_true(layer_count >= 0)
    canvas.restore_to_count(save_count)
    let bounded_layer_count = canvas.save_layer(
      bounds=Some(@skia.Rect::from_xywh(0, 0, 12, 12)),
      paint~,
    )
    assert_true(bounded_layer_count >= 0)
    match @native.ImageFilter::blur(2.0, 2.0) {
      Some(image_filter) => {
        let filtered_layer_count = canvas.save_layer(
          image_filter=Some(image_filter),
        )
        assert_true(filtered_layer_count >= 0)
        canvas.restore_to_count(save_count)
      }
      None => ()
    }
    canvas.translate(@skia.Point::new(1, 2))
    canvas.scale(@skia.Size::new(2, 2))
    canvas.rotate(45)
    canvas.skew(@skia.Point::new(0.1, 0.2))
    canvas.concat(@skia.Matrix::translate(3, 4))
    canvas.reset_matrix()
    canvas.restore_to_count(save_count)
    ignore(canvas.save())
    canvas.clip_rect(@skia.Rect::from_xywh(0, 0, 16, 16))
    canvas.clip_rect(
      @skia.Rect::from_xywh(2, 2, 8, 8),
      op=@skia.Difference,
      anti_alias=true,
    )
    let clip_rrect = @skia.RRect::from_rect_xy(
      @skia.Rect::from_xywh(1, 1, 14, 14),
      2,
      3,
    )
    canvas.clip_rrect(clip_rrect)
    canvas.clip_rrect(clip_rrect, op=@skia.Difference, anti_alias=true)
    ignore(canvas.local_clip_bounds())
    ignore(canvas.device_clip_bounds())
    assert_true(!canvas.quick_reject_rect(@skia.Rect::from_xywh(1, 1, 2, 2)))
    match @native.Path::new() {
      None => ()
      Some(path) => {
        path.move_to(@skia.Point::new(0, 0))
        path.line_to(@skia.Point::new(8, 0))
        path.line_to(@skia.Point::new(8, 8))
        path.close()
        canvas.clip_path(path, anti_alias=true)
        ignore(canvas.quick_reject_path(path))
      }
    }
    canvas.restore()
    canvas.discard()
    canvas.clear(@skia.Color::transparent())
    canvas.draw_color(@skia.Color::blue())
    canvas.draw_color(@skia.Color::red(), blend_mode=@skia.Src)
    canvas.draw_paint(paint)
    canvas.draw_point(@skia.Point::new(0, 0), paint)
    canvas.draw_line(@skia.Point::new(0, 0), @skia.Point::new(15, 15), paint)
    canvas.draw_rect(@skia.Rect::from_xywh(1, 2, 3, 4), paint)
    canvas.draw_oval(@skia.Rect::from_xywh(2, 2, 8, 6), paint)
    canvas.draw_circle(@skia.Point::new(5, 6), 7, paint)
    canvas.draw_arc(@skia.Rect::from_xywh(2, 2, 8, 8), 0, 180, false, paint)
    canvas.draw_round_rect(@skia.Rect::from_xywh(2, 2, 8, 6), 2, 2, paint)
    canvas.draw_rrect(
      @skia.RRect::new(
        @skia.Rect::from_xywh(2, 2, 10, 8),
        @skia.Size::new(2, 2),
        @skia.Size::new(3, 1),
        @skia.Size::new(1, 2),
        @skia.Size::empty(),
      ),
      paint,
    )
    canvas.draw_drrect(
      @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(1, 1, 14, 14), 4, 4),
      @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(4, 4, 8, 8), 2, 2),
      paint,
    )
    canvas.draw_path_value(
      @skia.Path::new().add_rect(
        @skia.Rect::from_xywh(1, 1, 7, 7),
        direction=@skia.CCW,
      ),
      paint,
    )
    canvas.draw_path_value(
      @skia.Path::new().add_circle(@skia.Point::new(8, 8), 4),
      paint,
    )
    canvas.draw_path_value(
      @skia.Path::new().add_round_rect(@skia.Rect::from_xywh(2, 2, 10, 8), 2, 2),
      paint,
    )
    match @native.Shader::color(@skia.Color::blue()) {
      None => ()
      Some(shader) => {
        canvas.draw_paint_shader(shader, paint)
        match @native.Path::new() {
          None => ()
          Some(path) => {
            path.add_rect(@skia.Rect::from_xywh(0, 0, 8, 8))
            canvas.draw_path_shader(path, shader, paint)
          }
        }
        canvas.draw_rect_shader(
          @skia.Rect::from_xywh(1, 1, 6, 6),
          shader,
          paint,
        )
        canvas.draw_round_rect_shader(
          @skia.Rect::from_xywh(1, 1, 6, 6),
          2,
          2,
          shader,
          paint,
        )
      }
    }
    match
      @native.Shader::linear_gradient(
        @skia.Point::new(0, 0),
        @skia.Point::new(8, 8),
        @skia.Color::red(),
        @skia.Color::green(),
      ) {
      None => ()
      Some(shader) =>
        canvas.draw_rect_shader(
          @skia.Rect::from_xywh(0, 0, 8, 8),
          shader,
          paint,
        )
    }
    match
      @native.Shader::radial_gradient(
        @skia.Point::new(4, 4),
        4.0,
        @skia.Color::yellow(),
        @skia.Color::magenta(),
      ) {
      None => ()
      Some(shader) =>
        canvas.draw_rect_shader(
          @skia.Rect::from_xywh(0, 0, 8, 8),
          shader,
          paint,
        )
    }
    match @native.Font::default(size=12.0) {
      None => ()
      Some(font) => {
        assert_true(font.measure_text_utf8(b"MoonBit Skia") > 0.0)
        assert_eq(font.count_text_utf8(b"MoonBit Skia"), 12)
        let glyphs = font.text_to_glyphs_utf8(b"MoonBit Skia")
        assert_eq(glyphs.length(), 12)
        assert_eq(font.glyph_widths(glyphs).length(), 12)
        assert_eq(font.glyph_positions(glyphs).length(), 12)
        assert_eq(font.text_glyph_positions_utf8(b"MoonBit Skia").length(), 12)
        assert_eq(font.glyph_bounds_many(glyphs).length(), 12)
        match font.measure_text_bounds_utf8(b"MoonBit Skia") {
          None => ()
          Some(bounds) => assert_true(bounds.width() > 0.0)
        }
        canvas.draw_text_utf8(
          b"MoonBit Skia",
          @skia.Point::new(2, 12),
          font,
          paint,
        )
        canvas.draw_glyphs(
          glyphs,
          font.glyph_positions(glyphs),
          font,
          paint,
          origin=@skia.Point::new(2, 12),
        )
        canvas.draw_glyphs(glyphs, [], font, paint)
      }
    }
    match @native.Surface::raster_n32_premul(@skia.ISize::new(4, 4)) {
      None => ()
      Some(surface) =>
        match surface.image_snapshot() {
          None => ()
          Some(image) => {
            canvas.draw_image(image, @skia.Point::new(0, 0))
            canvas.draw_image_rect(
              image,
              @skia.Rect::from_xywh(0, 0, 4, 4),
              @skia.Rect::from_xywh(1, 1, 8, 8),
              paint,
            )
            canvas.draw_image_rect(
              image,
              @skia.Rect::from_xywh(0, 0, 4, 4),
              @skia.Rect::from_xywh(2, 2, 6, 6),
              paint,
              sampling=@skia.SamplingOptions::mitchell(),
            )
          }
        }
    }
    match @native.Path::new() {
      None => ()
      Some(path) => {
        path.move_to(@skia.Point::new(0, 0))
        path.line_to(@skia.Point::new(15, 15))
        canvas.draw_path(path, paint)
      }
    }
  }

  let surface = @native.Surface::raster_n32_premul(@skia.ISize::new(16, 16))
  match surface {
    None => ()
    Some(surface) =>
      match surface.canvas() {
        None => ()
        Some(canvas) => exercise_canvas_api(canvas)
      }
  }
}

///|
fn native_test_encoded_image_descriptor() -> @skia.ImageDescriptor? {
  match @native.Surface::raster_n32_premul(@skia.ISize::new(4, 4)) {
    None => None
    Some(surface) =>
      match surface.canvas() {
        None => None
        Some(canvas) => {
          canvas.clear(@skia.Color::red())
          match surface.image_snapshot() {
            None => None
            Some(image) =>
              match image.encode_to_data(format=@skia.PNG, quality=100) {
                None => None
                Some(data) =>
                  @skia.ImageDescriptor::encoded(
                    data.to_bytes(),
                    format=Some(@skia.PNG),
                    dimensions=Some(@skia.ISize::new(4, 4)),
                  )
              }
          }
        }
      }
  }
}

///|
test "canvas replays render command lists" {
  let path = @skia.Path::new().add_rect(@skia.Rect::from_xywh(10, 2, 4, 4))
  let rrect = @skia.RRect::from_rect_xy(
    @skia.Rect::from_xywh(10, 18, 6, 4),
    2.0,
    2.0,
  )
  let layer_color_filter = @skia.ColorFilterDescriptor::saturation(0.8)
  let layer_image_filter = @skia.ImageFilterDescriptor::blur(1.0, 1.0)
  let layer_mask_filter = @skia.MaskFilterDescriptor::blur(1.0)
  let replay_image_descriptor = native_test_encoded_image_descriptor()
  let text_descriptor = @skia.TextRunDescriptor::new(
    range=@skia.TextRange::new(0, 5),
    fallback=@skia.FontFallbackRequest::new(
      families=@skia.FontFallbackChain::new(primary_family=b"Inter"),
      bcp47=[b"en"],
      character=0x68,
    ),
  )
  let replay_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(
    @skia.ISize::new(32, 32),
  )
  let base_commands = @skia.RenderCommandList::for_target(replay_target)
    .clear(@skia.Color::white())
    .clip_rect(@skia.Rect::from_xywh(0, 0, 32, 32))
    .save_layer(
      bounds=Some(@skia.Rect::from_xywh(0, 0, 32, 32)),
      color_filter=layer_color_filter,
      image_filter=layer_image_filter,
      mask_filter=layer_mask_filter,
    )
    .draw_point(
      @skia.Point::new(29, 2),
      paint=@skia.Paint::new(color=@skia.Color::black(), stroke_width=2.0),
    )
    .draw_line(
      @skia.Point::new(18, 8),
      @skia.Point::new(28, 8),
      paint=@skia.Paint::new(color=@skia.Color::black(), stroke_width=2.0),
    )
    .draw_points(
      [
        @skia.Point::new(18, 14),
        @skia.Point::new(22, 14),
        @skia.Point::new(26, 14),
      ],
      paint=@skia.Paint::new(color=@skia.Color::black(), stroke_width=2.0),
      mode=@skia.Polygon,
    )
    .draw_rect(
      @skia.Rect::from_xywh(2, 2, 4, 4),
      paint=@skia.Paint::new(color=@skia.Color::red()),
    )
    .draw_oval(
      @skia.Rect::from_xywh(18, 2, 6, 4),
      paint=@skia.Paint::new(color=@skia.Color::green()),
    )
    .draw_circle(
      @skia.Point::new(24, 12),
      3.0,
      paint=@skia.Paint::new(color=@skia.Color::blue()),
    )
    .draw_arc(
      @skia.Rect::from_xywh(24, 18, 6, 6),
      0.0,
      180.0,
      false,
      paint=@skia.Paint::new(color=@skia.Color::black(), stroke_width=2.0),
    )
    .draw_rect_shader(
      @skia.Rect::from_xywh(12, 24, 4, 4),
      @skia.ShaderDescriptor::color(@skia.Color::green()),
      paint=@skia.Paint::new(color=@skia.Color::white()),
    )
    .draw_round_rect_shader(
      @skia.Rect::from_xywh(16, 24, 4, 4),
      1.0,
      1.0,
      @skia.ShaderDescriptor::color(@skia.Color::cyan()),
      paint=@skia.Paint::new(color=@skia.Color::white()),
    )
    .draw_round_rect(
      @skia.Rect::from_xywh(2, 18, 6, 4),
      2.0,
      2.0,
      paint=@skia.Paint::new(color=@skia.Color::cyan()),
    )
    .draw_rrect(rrect, paint=@skia.Paint::new(color=@skia.Color::magenta()))
    .draw_drrect(
      @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(20, 20, 8, 8), 3.0, 3.0),
      @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(22, 22, 2, 2), 1.0, 1.0),
      paint=@skia.Paint::new(color=@skia.Color::yellow()),
    )
    .restore()
    .draw_path(path, paint=@skia.Paint::new(color=@skia.Color::blue()))
    .draw_path_shader(
      path,
      @skia.ShaderDescriptor::color(@skia.Color::green()),
      paint=@skia.Paint::new(color=@skia.Color::white()),
    )
    .draw_text_run_utf8(
      b"hello",
      @skia.Point::new(2, 12),
      descriptor=Some(text_descriptor),
      font_key=@skia.RendererResourceKey::font(b"default:8"),
      paint=@skia.Paint::new(color=@skia.Color::black()),
    )
  let commands = match replay_image_descriptor {
    None => base_commands
    Some(image) =>
      base_commands
      .draw_image(image, @skia.Point::new(20, 0))
      .draw_image_rect(
        image,
        @skia.Rect::from_xywh(0, 0, 4, 4),
        @skia.Rect::from_xywh(20, 4, 4, 4),
        sampling=@skia.SamplingOptions::linear(),
      )
  }
  assert_eq(commands.text_run_resource_keys().length(), 1)
  match replay_image_descriptor {
    None => ()
    Some(image) =>
      assert_true(commands.resource_plan().contains_key(image.resource_key()))
  }
  let replay_frame = commands.frame_descriptor(replay_target)
  let rejected_frame = commands.save().frame_descriptor(replay_target)
  let command_stats = commands.stats()
  assert_true(replay_frame.is_ready())
  assert_true(!rejected_frame.is_ready())
  match @native.Surface::raster_n32_premul(@skia.ISize::new(32, 32)) {
    None => ()
    Some(surface) =>
      match surface.canvas() {
        None => ()
        Some(canvas) => {
          let font = @native.Font::default(size=8.0)
          let stats = canvas.replay(commands, font~)
          let expected_draw_count = match replay_image_descriptor {
            None => 15
            Some(_) => 17
          }
          assert_eq(stats.command_count, commands.length())
          assert_eq(stats.draw_count, expected_draw_count)
          assert_eq(stats.state_count, command_stats.state_count)
          assert_eq(stats.transform_count, command_stats.transform_count)
          assert_eq(stats.clip_count, command_stats.clip_count)
          assert_eq(stats.clear_count, command_stats.clear_count)
          native_test_assert_replay_resource_counts(stats, command_stats)
          assert_eq(stats.text_count, 1)
          assert_eq(stats.present_count, 0)
          match font {
            None => assert_true(stats.skipped_count <= 1)
            Some(_) => {
              assert_true(stats.is_complete())
              assert_true(stats.status() == @native.CanvasReplayComplete)
              assert_true(stats.status().is_complete())
            }
          }
          assert_true(
            stats.replayed_count + stats.skipped_count == commands.length(),
          )
          let present_target = @skia.SurfaceTargetDescriptor::window_n32_premul(
            @skia.ISize::new(32, 32),
            target_id=b"native-canvas-present-status",
          )
          let present_frame = @skia.RenderCommandList::for_target(
              present_target,
            )
            .draw_rect(@skia.Rect::from_xywh(1, 1, 2, 2))
            .frame_descriptor(present_target)
          assert_true(present_frame.is_ready())
          assert_true(present_frame.has_present())
          let present_stats = canvas.replay_frame(present_frame, font~)
          assert_eq(present_stats.present_count, 1)
          assert_eq(present_stats.skipped_count, 0)
          assert_true(present_stats.is_complete())
          assert_true(
            present_stats.status() == @native.CanvasReplayDeferredPresent,
          )
          assert_true(present_stats.status().is_complete())
          let frame_stats = canvas.replay_frame(replay_frame, font~)
          assert_eq(frame_stats.command_count, commands.length())
          assert_eq(frame_stats.draw_count, expected_draw_count)
          assert_eq(frame_stats.state_count, command_stats.state_count)
          assert_eq(frame_stats.transform_count, command_stats.transform_count)
          assert_eq(frame_stats.clip_count, command_stats.clip_count)
          assert_eq(frame_stats.clear_count, command_stats.clear_count)
          native_test_assert_replay_resource_counts(frame_stats, command_stats)
          assert_eq(frame_stats.text_count, 1)
          assert_eq(frame_stats.present_count, 0)
          match font {
            None => assert_true(frame_stats.skipped_count <= 1)
            Some(_) => {
              assert_true(frame_stats.is_complete())
              assert_true(frame_stats.status() == @native.CanvasReplayComplete)
            }
          }
          let rejected_frame_stats = canvas.replay_frame(rejected_frame, font~)
          assert_eq(
            rejected_frame_stats.command_count,
            rejected_frame.command_list.length(),
          )
          assert_eq(rejected_frame_stats.replayed_count, 0)
          assert_true(rejected_frame_stats.skipped_count > 0)
          assert_true(!rejected_frame_stats.is_complete())
          assert_true(
            rejected_frame_stats.status() == @native.CanvasReplaySkippedCommands,
          )
          assert_true(!rejected_frame_stats.status().is_complete())
          native_test_assert_replay_resource_counts(
            rejected_frame_stats,
            rejected_frame.command_list.stats(),
          )
          match replay_image_descriptor {
            None => ()
            Some(_) => {
              let replay_resources = @native.NativeReplayResources::new(
                image_max_bytes=1024L * 1024L,
                shader_max_bytes=1024L,
                path_max_bytes=1024L,
                text_run_max_bytes=1024L,
                font_max_bytes=1024L,
                typeface_max_bytes=1024L,
                color_filter_max_bytes=1024L,
                image_filter_max_bytes=1024L,
                mask_filter_max_bytes=1024L,
              )
              let cached_stats = canvas.replay_with_resources(
                commands,
                replay_resources,
                font~,
              )
              assert_true(cached_stats.is_complete())
              assert_eq(cached_stats.command_count, commands.length())
              assert_eq(cached_stats.state_count, command_stats.state_count)
              assert_eq(
                cached_stats.transform_count,
                command_stats.transform_count,
              )
              assert_eq(cached_stats.clip_count, command_stats.clip_count)
              assert_eq(cached_stats.clear_count, command_stats.clear_count)
              native_test_assert_replay_resource_counts(
                cached_stats, command_stats,
              )
              let cached_again_stats = canvas.replay_with_resources(
                commands,
                replay_resources,
                font~,
              )
              let image_cache_stats = replay_resources.image_cache.stats()
              let shader_cache_stats = replay_resources.shader_cache.stats()
              let path_cache_stats = replay_resources.path_cache.stats()
              let text_run_cache_stats = replay_resources.text_run_cache.stats()
              let font_cache_stats = replay_resources.font_cache.stats()
              let typeface_cache_stats = replay_resources.typeface_cache.stats()
              let color_filter_cache_stats = replay_resources.color_filter_cache.stats()
              let image_filter_cache_stats = replay_resources.image_filter_cache.stats()
              let mask_filter_cache_stats = replay_resources.mask_filter_cache.stats()
              let replay_resource_stats = replay_resources.stats()
              assert_true(cached_again_stats.is_complete())
              assert_eq(cached_again_stats.command_count, commands.length())
              assert_eq(
                cached_again_stats.state_count,
                command_stats.state_count,
              )
              assert_eq(
                cached_again_stats.transform_count,
                command_stats.transform_count,
              )
              assert_eq(cached_again_stats.clip_count, command_stats.clip_count)
              assert_eq(
                cached_again_stats.clear_count,
                command_stats.clear_count,
              )
              native_test_assert_replay_resource_counts(
                cached_again_stats, command_stats,
              )
              assert_eq(replay_resource_stats.cache_count, 9)
              assert_eq(replay_resource_stats.resource_count, 10)
              assert_eq(
                replay_resource_stats.max_bytes,
                1024L * 1024L + 8L * 1024L,
              )
              assert_eq(replay_resource_stats.misses, 10)
              assert_eq(replay_resource_stats.hits, 16)
              assert_eq(replay_resource_stats.evictions, 0)
              assert_eq(replay_resources.image_cache.length(), 1)
              assert_eq(image_cache_stats.misses, 1)
              assert_eq(image_cache_stats.hits, 3)
              assert_eq(replay_resources.shader_cache.length(), 2)
              assert_eq(shader_cache_stats.misses, 2)
              assert_eq(shader_cache_stats.hits, 4)
              assert_eq(replay_resources.path_cache.length(), 1)
              assert_eq(path_cache_stats.misses, 1)
              assert_eq(path_cache_stats.hits, 3)
              assert_eq(replay_resources.text_run_cache.length(), 1)
              assert_eq(text_run_cache_stats.misses, 1)
              assert_eq(text_run_cache_stats.hits, 1)
              assert_eq(replay_resources.font_cache.length(), 1)
              assert_eq(font_cache_stats.misses, 1)
              assert_eq(font_cache_stats.hits, 1)
              assert_eq(replay_resources.typeface_cache.length(), 1)
              assert_eq(typeface_cache_stats.misses, 1)
              assert_eq(typeface_cache_stats.hits, 1)
              assert_eq(replay_resources.color_filter_cache.length(), 1)
              assert_eq(color_filter_cache_stats.misses, 1)
              assert_eq(color_filter_cache_stats.hits, 1)
              assert_eq(replay_resources.image_filter_cache.length(), 1)
              assert_eq(image_filter_cache_stats.misses, 1)
              assert_eq(image_filter_cache_stats.hits, 1)
              assert_eq(replay_resources.mask_filter_cache.length(), 1)
              assert_eq(mask_filter_cache_stats.misses, 1)
              assert_eq(mask_filter_cache_stats.hits, 1)
              let frame_resources = @native.NativeReplayResources::new(
                image_max_bytes=1024L * 1024L,
                shader_max_bytes=1024L,
                path_max_bytes=1024L,
                text_run_max_bytes=1024L,
                font_max_bytes=1024L,
                typeface_max_bytes=1024L,
                color_filter_max_bytes=1024L,
                image_filter_max_bytes=1024L,
                mask_filter_max_bytes=1024L,
              )
              let frame_cached_stats = canvas.replay_frame_with_resources(
                replay_frame,
                frame_resources,
                font~,
              )
              assert_true(frame_cached_stats.is_complete())
              assert_eq(frame_cached_stats.command_count, commands.length())
              assert_eq(
                frame_cached_stats.state_count,
                command_stats.state_count,
              )
              assert_eq(
                frame_cached_stats.transform_count,
                command_stats.transform_count,
              )
              assert_eq(frame_cached_stats.clip_count, command_stats.clip_count)
              assert_eq(
                frame_cached_stats.clear_count,
                command_stats.clear_count,
              )
              native_test_assert_replay_resource_counts(
                frame_cached_stats, command_stats,
              )
              assert_eq(frame_resources.image_cache.length(), 1)
              assert_eq(frame_resources.shader_cache.length(), 2)
              assert_eq(frame_resources.path_cache.length(), 1)
              assert_eq(frame_resources.text_run_cache.length(), 1)
              assert_eq(frame_resources.font_cache.length(), 1)
              assert_eq(frame_resources.typeface_cache.length(), 1)
              assert_eq(frame_resources.stats().cache_count, 9)
              assert_eq(frame_resources.stats().resource_count, 10)
            }
          }
          match @native.Surface::raster_n32_premul(@skia.ISize::new(32, 32)) {
            None => ()
            Some(frame_surface) => {
              let surface_resources = @native.NativeReplayResources::new(
                image_max_bytes=1024L * 1024L,
                shader_max_bytes=1024L,
                path_max_bytes=1024L,
                text_run_max_bytes=1024L,
                font_max_bytes=1024L,
                typeface_max_bytes=1024L,
                color_filter_max_bytes=1024L,
                image_filter_max_bytes=1024L,
                mask_filter_max_bytes=1024L,
              )
              let surface_frame_stats = frame_surface.render_frame_with_resources(
                replay_frame,
                surface_resources,
                font~,
                frame_index=5,
              )
              assert_true(surface_frame_stats.is_complete())
              assert_true(
                surface_frame_stats.status() ==
                @native.SurfaceFrameReplayComplete,
              )
              assert_true(surface_frame_stats.status().is_complete())
              assert_true(
                surface_frame_stats.validation_status == @skia.FrameReady,
              )
              assert_true(surface_frame_stats.surface_matches)
              assert_true(surface_frame_stats.finalized)
              assert_true(surface_frame_stats.finalization_is_ready())
              assert_eq(surface_frame_stats.finalization.frame_index, 5)
              assert_true(
                surface_frame_stats.finalization ==
                replay_frame.finalization_descriptor(frame_index=5),
              )
              assert_true(
                surface_frame_stats.finalization_resource_plan() ==
                replay_frame.finalization_resource_plan(frame_index=5),
              )
              assert_eq(
                surface_frame_stats.replay.command_count,
                commands.length(),
              )
              native_test_assert_replay_resource_counts(
                surface_frame_stats.replay,
                command_stats,
              )
              assert_eq(surface_resources.stats().cache_count, 9)
              assert_eq(surface_resources.stats().resource_count, 10)
              assert_eq(surface_resources.image_cache.length(), 1)
              match
                frame_surface.read_pixels(
                  bounds=@skia.IRect::from_xywh(2, 2, 1, 1),
                ) {
                None => ()
                Some(pixmap) => native_test_assert_red_dominant_pixel(pixmap)
              }
            }
          }
          match @native.Surface::raster_n32_premul(@skia.ISize::new(16, 16)) {
            None => ()
            Some(mismatch_surface) => {
              let mismatch_stats = mismatch_surface.render_frame(
                replay_frame,
                font~,
              )
              assert_true(!mismatch_stats.is_complete())
              assert_true(
                mismatch_stats.status() ==
                @native.SurfaceFrameReplaySurfaceMismatch,
              )
              assert_true(!mismatch_stats.status().is_complete())
              assert_true(!mismatch_stats.surface_matches)
              assert_true(!mismatch_stats.finalized)
              assert_true(mismatch_stats.finalization_is_ready())
              assert_eq(mismatch_stats.finalization.frame_index, 0)
              assert_eq(mismatch_stats.replay.replayed_count, 0)
              assert_true(mismatch_stats.replay.skipped_count > 0)
              native_test_assert_replay_resource_counts(
                mismatch_stats.replay,
                command_stats,
              )
            }
          }
          assert_true(surface.flush_and_submit())
          match surface.read_pixels(bounds=@skia.IRect::from_xywh(2, 2, 1, 1)) {
            None => ()
            Some(pixmap) => native_test_assert_red_dominant_pixel(pixmap)
          }
        }
      }
  }
}
