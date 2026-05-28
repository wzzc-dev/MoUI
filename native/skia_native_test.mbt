///|
test "native backend reports availability" {
  inspect(@native.skia_available(), content="false")
}

///|
test "raster surface is unavailable without linked skia" {
  let surface = @native.Surface::raster_n32_premul(@skia.ISize::new(16, 16))
  assert_true(surface is None)
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
  assert_true(@native.Typeface::from_name(b"") is None)
  match @native.Font::default(size=14.0) {
    None => ()
    Some(font) => {
      assert_true(font.is_available())
      assert_eq(font.size(), 14.0)
      font.set_size(18.0)
      assert_eq(font.size(), 18.0)
    }
  }
  match @native.Typeface::default() {
    None => ()
    Some(typeface) => {
      assert_true(typeface.is_available())
      ignore(typeface.is_bold())
      ignore(typeface.is_italic())
      ignore(typeface.is_fixed_pitch())
      match @native.Font::from_typeface(typeface, size=16.0) {
        None => ()
        Some(font) => {
          assert_true(font.is_available())
          assert_eq(font.size(), 16.0)
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
        canvas.draw_rect_shader(
          @skia.Rect::from_xywh(1, 1, 6, 6),
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
      Some(font) =>
        canvas.draw_text_utf8(
          b"MoonBit Skia",
          @skia.Point::new(2, 12),
          font,
          paint,
        )
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
