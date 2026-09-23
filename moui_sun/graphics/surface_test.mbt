///|
test "MemorySurface::present_pixels copies RGBA rows" {
  let surface = @graphics.MemorySurface::new(2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  write_rgba(pixels, 12, @graphics.Color::white())
  let result = surface.present_pixels(2, 2, 8, pixels)
  assert_true(result == Ok(()))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_present_pixel_count(), 4)
  assert_eq(surface.get_present_byte_count(), 16)
  assert_eq(surface.get_present_source_byte_count(), 16)
  assert_eq(surface.get_present_source_padding_byte_count(), 0)
  assert_eq(surface.get_present_records().length(), 1)
  match surface.get_last_present_record() {
    Some(record) => {
      assert_true(
        record.get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=2, height=2),
      )
      assert_eq(record.get_row_bytes(), 8)
      assert_eq(record.get_present_pixel_count(), 4)
      assert_eq(record.get_present_byte_count(), 16)
      assert_eq(record.get_source_byte_count(), 16)
      assert_eq(record.get_source_padding_byte_count(), 0)
    }
    None => abort("expected full present record")
  }
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(surface.get_pixel(1, 0), @graphics.Color::green())
  assert_eq(surface.get_pixel(0, 1), @graphics.Color::blue())
  assert_eq(surface.get_pixel(1, 1), @graphics.Color::white())
}

///|
test "MemorySurface::get_present_records returns isolated telemetry" {
  let surface = @graphics.MemorySurface::new(2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  write_rgba(pixels, 12, @graphics.Color::white())
  assert_true(surface.present_pixels(2, 2, 8, pixels) == Ok(()))
  assert_true(surface.present_pixels_rect(1, 0, 1, 1, 4, pixels) == Ok(()))

  let records = surface.get_present_records()
  assert_eq(records.length(), 2)
  records[0] = records[1]
  records.push(records[1])

  assert_eq(surface.get_present_records().length(), 2)
  assert_eq(surface.get_present_count(), 2)
  assert_eq(surface.get_present_pixel_count(), 5)
  assert_true(
    surface.get_present_records()[0].get_rect() ==
    @graphics.PixelRect::new(x=0, y=0, width=2, height=2),
  )
  assert_true(
    surface.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=2)),
  )
}

///|
test "MemorySurface::get_pixels returns isolated pixel snapshots" {
  let surface = @graphics.MemorySurface::new(2, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  assert_true(surface.present_pixels(2, 1, 8, pixels) == Ok(()))

  let snapshot = surface.get_pixels()
  assert_eq(snapshot.length(), 8)
  snapshot[0] = @graphics.Color::blue().r
  snapshot[1] = @graphics.Color::blue().g
  snapshot[2] = @graphics.Color::blue().b

  assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
  let fresh = surface.get_pixels()
  assert_eq(fresh[0], @graphics.Color::red().r)
  assert_eq(fresh[1], @graphics.Color::red().g)
  assert_eq(fresh[2], @graphics.Color::red().b)
}

///|
test "MemorySurface::present_pixels supports padded row bytes" {
  let surface = @graphics.MemorySurface::new(1, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  pixels[4] = 99
  pixels[5] = 98
  pixels[6] = 97
  pixels[7] = 96
  write_rgba(pixels, 8, @graphics.Color::blue())
  let result = surface.present_pixels(1, 2, 8, pixels)
  assert_true(result == Ok(()))
  assert_eq(surface.get_present_pixel_count(), 2)
  assert_eq(surface.get_present_byte_count(), 8)
  assert_eq(surface.get_present_source_byte_count(), 16)
  assert_eq(surface.get_present_source_padding_byte_count(), 8)
  match surface.get_last_present_record() {
    Some(record) => {
      assert_true(
        record.get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=1, height=2),
      )
      assert_eq(record.get_row_bytes(), 8)
      assert_eq(record.get_present_pixel_count(), 2)
      assert_eq(record.get_present_byte_count(), 8)
      assert_eq(record.get_source_byte_count(), 16)
      assert_eq(record.get_source_padding_byte_count(), 8)
    }
    None => abort("expected padded present record")
  }
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(surface.get_pixel(0, 1), @graphics.Color::blue())
  assert_eq(surface.get_pixels().length(), 8)
}

///|
test "MemorySurface::present_pixels_rect updates only destination rectangle" {
  let surface = @graphics.MemorySurface::new(3, 3)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  write_rgba(pixels, 12, @graphics.Color::white())
  let result = surface.present_pixels_rect(1, 1, 2, 2, 8, pixels)
  assert_true(result == Ok(()))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_present_pixel_count(), 4)
  assert_eq(surface.get_present_byte_count(), 16)
  assert_eq(surface.get_present_source_byte_count(), 16)
  assert_eq(surface.get_present_source_padding_byte_count(), 0)
  match surface.get_last_present_record() {
    Some(record) => {
      assert_true(
        record.get_rect() ==
        @graphics.PixelRect::new(x=1, y=1, width=2, height=2),
      )
      assert_eq(record.get_row_bytes(), 8)
      assert_eq(record.get_present_pixel_count(), 4)
      assert_eq(record.get_present_byte_count(), 16)
      assert_eq(record.get_source_byte_count(), 16)
      assert_eq(record.get_source_padding_byte_count(), 0)
    }
    None => abort("expected rect present record")
  }
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(surface.get_pixel(1, 1), @graphics.Color::red())
  assert_eq(surface.get_pixel(2, 1), @graphics.Color::green())
  assert_eq(surface.get_pixel(1, 2), @graphics.Color::blue())
  assert_eq(surface.get_pixel(2, 2), @graphics.Color::white())
}

///|
test "MemorySurface::get_present_bounds aggregates recorded target rectangles" {
  let surface = @graphics.MemorySurface::new(4, 3)
  assert_true(surface.get_present_bounds() == None)

  let one_pixel : FixedArray[Byte] = FixedArray::make(4, 0)
  write_rgba(one_pixel, 0, @graphics.Color::red())
  assert_true(surface.present_pixels_rect(1, 1, 1, 1, 4, one_pixel) == Ok(()))

  let two_pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  write_rgba(two_pixels, 0, @graphics.Color::green())
  write_rgba(two_pixels, 4, @graphics.Color::blue())
  assert_true(surface.present_pixels_rect(3, 0, 1, 2, 4, two_pixels) == Ok(()))

  assert_true(
    surface.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=3, height=2)),
  )

  surface.reset_present_telemetry()
  assert_true(surface.get_present_bounds() == None)
}

///|
test "MemorySurface::reset_present_telemetry clears records but keeps pixels" {
  let surface = @graphics.MemorySurface::new(2, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::blue())
  assert_true(surface.present_pixels(2, 1, 8, pixels) == Ok(()))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_present_pixel_count(), 2)
  assert_eq(surface.get_present_byte_count(), 8)
  assert_eq(surface.get_present_source_byte_count(), 8)
  assert_eq(surface.get_present_records().length(), 1)

  surface.reset_present_telemetry()
  assert_eq(surface.get_present_count(), 0)
  assert_eq(surface.get_present_pixel_count(), 0)
  assert_eq(surface.get_present_byte_count(), 0)
  assert_eq(surface.get_present_source_byte_count(), 0)
  assert_eq(surface.get_present_records().length(), 0)
  assert_true(surface.get_last_present_record() is None)
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(surface.get_pixel(1, 0), @graphics.Color::blue())
}

///|
test "MemorySurface::to_pixmap snapshots pixels with isolated storage" {
  let surface = @graphics.MemorySurface::new(2, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::blue())
  assert_true(surface.present_pixels(2, 1, 8, pixels) == Ok(()))

  let pixmap = surface.to_pixmap()
  assert_eq(pixmap.get_width(), 2)
  assert_eq(pixmap.get_height(), 1)
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::blue())

  pixmap.set_pixel(0, 0, @graphics.Color::green())
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
}

///|
test "MemorySurface::to_ppm_bytes exports current RGB pixels" {
  let surface = @graphics.MemorySurface::new(1, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  write_rgba(pixels, 0, @graphics.Color::new(r=9, g=8, b=7, a=6))
  write_rgba(pixels, 4, @graphics.Color::new(r=1, g=2, b=3, a=4))
  assert_true(surface.present_pixels(1, 2, 4, pixels) == Ok(()))

  let expected : Array[Byte] = [
    80, 54, 10, 49, 32, 50, 10, 50, 53, 53, 10, 9, 8, 7, 1, 2, 3,
  ]
  assert_eq(surface.to_ppm_bytes(), Bytes::from_array(expected))
}

///|
test "MemorySurface::to_bmp_bytes exports current BGRA pixels" {
  let surface = @graphics.MemorySurface::new(1, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  write_rgba(pixels, 0, @graphics.Color::new(r=9, g=8, b=7, a=6))
  write_rgba(pixels, 4, @graphics.Color::new(r=1, g=2, b=3, a=4))
  assert_true(surface.present_pixels(1, 2, 4, pixels) == Ok(()))

  let expected : Array[Byte] = [
    66, 77, 62, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0, 0, 2, 0,
    0, 0, 1, 0, 32, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 3, 2, 1, 4, 7, 8, 9, 6,
  ]
  assert_eq(surface.to_bmp_bytes(), Bytes::from_array(expected))
}

///|
test "MemorySurface::to_png_bytes exports current RGBA pixels" {
  let surface = @graphics.MemorySurface::new(1, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  write_rgba(pixels, 0, @graphics.Color::new(r=255, g=0, b=0, a=255))
  assert_true(surface.present_pixels(1, 1, 4, pixels) == Ok(()))

  let expected = @graphics.Pixmap::new(1, 1)
  expected.set_pixel(0, 0, @graphics.Color::red())
  match expected.to_png_bytes() {
    Ok(expected_png) =>
      match surface.to_png_bytes() {
        Ok(png) => assert_eq(png, expected_png)
        Err(_) => abort("expected surface PNG")
      }
    Err(_) => abort("expected pixmap PNG")
  }
}

///|
test "MemorySurface::to_png_bytes rejects empty dimensions" {
  match @graphics.MemorySurface::new(0, 0).to_png_bytes() {
    Err(InvalidPngDimensions(0, 0)) => ()
    _ => abort("expected surface PNG dimensions error")
  }
}

///|
test "MemorySurface::checksum reports deterministic raw byte checksum" {
  let surface = @graphics.MemorySurface::new(2, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  write_rgba(pixels, 0, @graphics.Color::new(r=1, g=2, b=3, a=4))
  write_rgba(pixels, 4, @graphics.Color::new(r=5, g=6, b=7, a=8))
  assert_true(surface.present_pixels(2, 1, 8, pixels) == Ok(()))
  assert_eq(surface.checksum(), 204)
}

///|
test "MemorySurface::to_rgba_bytes exports current raw bytes" {
  let surface = @graphics.MemorySurface::new(2, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  write_rgba(pixels, 0, @graphics.Color::new(r=1, g=2, b=3, a=4))
  write_rgba(pixels, 4, @graphics.Color::new(r=5, g=6, b=7, a=8))
  assert_true(surface.present_pixels(2, 1, 8, pixels) == Ok(()))

  let expected : Array[Byte] = [1, 2, 3, 4, 5, 6, 7, 8]
  assert_eq(surface.to_rgba_bytes(), Bytes::from_array(expected))
}

///|
test "MemorySurface::to_pixmap_rect snapshots a clipped-free rectangle" {
  let surface = @graphics.MemorySurface::new(3, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(24, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  write_rgba(pixels, 12, @graphics.Color::white())
  write_rgba(pixels, 16, @graphics.Color::black())
  write_rgba(pixels, 20, @graphics.Color::transparent())
  assert_true(surface.present_pixels(3, 2, 12, pixels) == Ok(()))

  match
    surface.to_pixmap_rect(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=2),
    ) {
    Ok(snapshot) => {
      assert_eq(snapshot.get_width(), 2)
      assert_eq(snapshot.get_height(), 2)
      assert_eq(snapshot.get_pixel(0, 0), @graphics.Color::green())
      assert_eq(snapshot.get_pixel(1, 0), @graphics.Color::blue())
      assert_eq(snapshot.get_pixel(0, 1), @graphics.Color::black())
      assert_eq(snapshot.get_pixel(1, 1), @graphics.Color::transparent())
      snapshot.set_pixel(0, 0, @graphics.Color::red())
      assert_eq(surface.get_pixel(1, 0), @graphics.Color::green())
    }
    Err(_) => abort("expected surface rect snapshot")
  }
}

///|
test "MemorySurface::to_ppm_rect_bytes exports a surface rectangle" {
  let surface = @graphics.MemorySurface::new(3, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  assert_true(surface.present_pixels(3, 1, 12, pixels) == Ok(()))

  let expected : Array[Byte] = [
    80, 54, 10, 50, 32, 49, 10, 50, 53, 53, 10, 0, 255, 0, 0, 0, 255,
  ]
  match
    surface.to_ppm_rect_bytes(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
    ) {
    Ok(ppm) => assert_eq(ppm, Bytes::from_array(expected))
    Err(_) => abort("expected surface rect ppm")
  }
}

///|
test "MemorySurface::to_bmp_rect_bytes exports a surface rectangle" {
  let surface = @graphics.MemorySurface::new(3, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  assert_true(surface.present_pixels(3, 1, 12, pixels) == Ok(()))

  let expected : Array[Byte] = [
    66, 77, 62, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 2, 0, 0, 0, 1, 0,
    0, 0, 1, 0, 32, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 255, 0, 255, 255, 0, 0, 255,
  ]
  match
    surface.to_bmp_rect_bytes(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
    ) {
    Ok(bmp) => assert_eq(bmp, Bytes::from_array(expected))
    Err(_) => abort("expected surface rect bmp")
  }
}

///|
test "MemorySurface::to_png_rect_bytes exports a surface rectangle" {
  let surface = @graphics.MemorySurface::new(3, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  assert_true(surface.present_pixels(3, 1, 12, pixels) == Ok(()))

  let expected = @graphics.Pixmap::new(1, 1)
  expected.set_pixel(0, 0, @graphics.Color::green())
  match expected.to_png_bytes() {
    Ok(expected_png) =>
      match
        surface.to_png_rect_bytes(
          @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
        ) {
        Ok(png) => assert_eq(png, expected_png)
        Err(_) => abort("expected surface rect png")
      }
    Err(_) => abort("expected pixmap png")
  }
}

///|
test "MemorySurface::to_rgba_rect_bytes exports packed surface rectangle" {
  let surface = @graphics.MemorySurface::new(3, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  assert_true(surface.present_pixels(3, 1, 12, pixels) == Ok(()))

  let expected : Array[Byte] = [0, 255, 0, 255, 0, 0, 255, 255]
  match
    surface.to_rgba_rect_bytes(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
    ) {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array(expected))
    Err(_) => abort("expected surface rect rgba bytes")
  }
}

///|
test "MemorySurface::checksum_rect reports deterministic rect checksum" {
  let surface = @graphics.MemorySurface::new(3, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  write_rgba(pixels, 8, @graphics.Color::blue())
  assert_true(surface.present_pixels(3, 1, 12, pixels) == Ok(()))

  match
    surface.checksum_rect(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)) {
    Ok(checksum) => assert_eq(checksum, 5355)
    Err(_) => abort("expected surface rect checksum")
  }
}

///|
test "MemorySurface rect snapshots reject invalid rectangles" {
  let surface = @graphics.MemorySurface::new(2, 2)
  match
    surface.to_pixmap_rect(
      @graphics.PixelRect::new(x=1, y=1, width=2, height=1),
    ) {
    Err(RectOutOfBounds(1, 1, 2, 1, 2, 2)) => ()
    _ => abort("expected surface rect snapshot bounds error")
  }
  match
    surface.to_ppm_rect_bytes(
      @graphics.PixelRect::new(x=0, y=0, width=0, height=1),
    ) {
    Err(InvalidDimensions(0, 1)) => ()
    _ => abort("expected surface rect ppm dimension error")
  }
  match
    surface.to_bmp_rect_bytes(
      @graphics.PixelRect::new(x=0, y=0, width=0, height=1),
    ) {
    Err(InvalidDimensions(0, 1)) => ()
    _ => abort("expected surface rect bmp dimension error")
  }
  match
    surface.to_png_rect_bytes(
      @graphics.PixelRect::new(x=0, y=0, width=0, height=1),
    ) {
    Err(InvalidDimensions(0, 1)) => ()
    _ => abort("expected surface rect png dimension error")
  }
  match
    surface.to_rgba_rect_bytes(
      @graphics.PixelRect::new(x=0, y=0, width=1, height=0),
    ) {
    Err(InvalidDimensions(1, 0)) => ()
    _ => abort("expected surface rect rgba dimension error")
  }
  match
    surface.checksum_rect(@graphics.PixelRect::new(x=0, y=0, width=3, height=1)) {
    Err(RectOutOfBounds(0, 0, 3, 1, 2, 2)) => ()
    _ => abort("expected surface rect checksum bounds error")
  }
}

///|
test "MemorySurface::present_pixels_rect validates destination bounds" {
  let surface = @graphics.MemorySurface::new(3, 3)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  assert_true(
    surface.present_pixels_rect(2, 1, 2, 2, 8, pixels) ==
    Err(RectOutOfBounds(2, 1, 2, 2, 3, 3)),
  )
  assert_true(
    surface.present_pixels_rect(-1, 0, 1, 1, 4, pixels) ==
    Err(RectOutOfBounds(-1, 0, 1, 1, 3, 3)),
  )
  assert_eq(surface.get_present_count(), 0)
  assert_eq(surface.get_present_pixel_count(), 0)
  assert_eq(surface.get_present_byte_count(), 0)
  assert_eq(surface.get_present_source_byte_count(), 0)
  assert_eq(surface.get_present_records().length(), 0)
}

///|
test "validate_present_rect reports shared row-stride contract" {
  let pixels : FixedArray[Byte] = FixedArray::make(20, 0)
  match @graphics.validate_present_rect(4, 3, 1, 1, 2, 2, 12, pixels) {
    Ok(info) => {
      assert_eq(info.required_row_bytes(), 8)
      assert_eq(info.required_len(), 20)
    }
    Err(_) => abort("expected valid present rect")
  }
  assert_true(
    @graphics.validate_present_rect(4, 3, 3, 1, 2, 1, 8, pixels) ==
    Err(RectOutOfBounds(3, 1, 2, 1, 4, 3)),
  )
  assert_true(
    @graphics.validate_present_rect(4, 3, 1, 1, 2, 2, 4, pixels) ==
    Err(InvalidRowBytes(4, 8)),
  )
  let short_pixels : FixedArray[Byte] = FixedArray::make(19, 0)
  assert_true(
    @graphics.validate_present_rect(4, 3, 1, 1, 2, 2, 12, short_pixels) ==
    Err(PixelBufferTooSmall(19, 20)),
  )
}

///|
test "MemorySurface::present_pixels validates dimensions and buffer" {
  let surface = @graphics.MemorySurface::new(2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  assert_true(
    surface.present_pixels(0, 2, 8, pixels) == Err(InvalidDimensions(0, 2)),
  )
  assert_true(
    surface.present_pixels(1, 2, 4, pixels) == Err(SizeMismatch(2, 2, 1, 2)),
  )
  assert_true(
    surface.present_pixels(2, 2, 4, pixels) == Err(InvalidRowBytes(4, 8)),
  )
  let short_pixels : FixedArray[Byte] = FixedArray::make(15, 0)
  assert_true(
    surface.present_pixels(2, 2, 8, short_pixels) ==
    Err(PixelBufferTooSmall(15, 16)),
  )
}

///|
test "Pixmap::present_to presents pixmap pixels to surface" {
  let pixmap = @graphics.Pixmap::new(2, 1)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::blue())
  let surface = @graphics.MemorySurface::new(2, 1)
  let result = pixmap.present_to(surface)
  assert_true(result == Ok(()))
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(surface.get_pixel(1, 0), @graphics.Color::blue())
}

///|
test "Pixmap::present_rect_to presents a packed sub-rectangle" {
  let pixmap = @graphics.Pixmap::new(3, 2)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::green())
  pixmap.set_pixel(2, 0, @graphics.Color::blue())
  pixmap.set_pixel(0, 1, @graphics.Color::white())
  pixmap.set_pixel(1, 1, @graphics.Color::black())
  pixmap.set_pixel(2, 1, @graphics.Color::transparent())
  let surface = @graphics.MemorySurface::new(3, 2)
  let result = pixmap.present_rect_to(
    surface,
    @graphics.PixelRect::new(x=1, y=0, width=2, height=2),
  )
  assert_true(result == Ok(()))
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(surface.get_pixel(1, 0), @graphics.Color::green())
  assert_eq(surface.get_pixel(2, 0), @graphics.Color::blue())
  assert_eq(surface.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(surface.get_pixel(2, 1), @graphics.Color::transparent())
}

///|
test "Pixmap::present_rect_payload materializes packed pixels" {
  let pixmap = @graphics.Pixmap::new(3, 2)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::green())
  pixmap.set_pixel(2, 0, @graphics.Color::blue())
  pixmap.set_pixel(0, 1, @graphics.Color::white())
  pixmap.set_pixel(1, 1, @graphics.Color::black())
  pixmap.set_pixel(2, 1, @graphics.Color::transparent())

  match
    pixmap.present_rect_payload(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=2),
    ) {
    Ok(payload) => {
      assert_true(
        payload.get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=2, height=2),
      )
      assert_eq(payload.get_row_bytes(), 8)
      assert_eq(payload.get_present_pixel_count(), 4)
      assert_eq(payload.get_present_byte_count(), 16)
      assert_eq(payload.get_source_byte_count(), 16)
      assert_eq(payload.get_source_padding_byte_count(), 0)
      let pixels = payload.get_pixels()
      assert_eq(pixels.length(), 16)
      assert_rgba(pixels, 0, @graphics.Color::green())
      assert_rgba(pixels, 4, @graphics.Color::blue())
      assert_rgba(pixels, 8, @graphics.Color::black())
      assert_rgba(pixels, 12, @graphics.Color::transparent())
    }
    Err(_) => abort("expected packed present payload")
  }
}

///|
test "PresentRectPayload separates present bytes from padded source rows" {
  let pixels : FixedArray[Byte] = FixedArray::make(24, 0)
  write_rgba(pixels, 0, @graphics.Color::red())
  write_rgba(pixels, 4, @graphics.Color::green())
  pixels[8] = 99
  pixels[9] = 98
  pixels[10] = 97
  pixels[11] = 96
  write_rgba(pixels, 12, @graphics.Color::blue())
  write_rgba(pixels, 16, @graphics.Color::white())
  pixels[20] = 95
  pixels[21] = 94
  pixels[22] = 93
  pixels[23] = 92
  let payload = match
    @graphics.PresentRectPayload::new(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=2),
      12,
      pixels,
    ) {
    Ok(value) => value
    Err(_) => abort("expected padded present payload")
  }
  pixels[0] = @graphics.Color::black().r
  assert_eq(payload.get_present_pixel_count(), 4)
  assert_eq(payload.get_present_byte_count(), 16)
  assert_eq(payload.get_source_byte_count(), 24)
  assert_eq(payload.get_source_padding_byte_count(), 8)
  assert_rgba(payload.get_pixels(), 0, @graphics.Color::red())

  let surface = @graphics.MemorySurface::new(3, 2)
  assert_true(payload.submit_to(surface) == Ok(()))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_present_pixel_count(), 4)
  assert_eq(surface.get_present_byte_count(), 16)
  assert_eq(surface.get_present_source_byte_count(), 24)
  assert_eq(surface.get_present_source_padding_byte_count(), 8)
  assert_eq(surface.get_pixel(1, 0), @graphics.Color::red())
  assert_eq(surface.get_pixel(2, 0), @graphics.Color::green())
  assert_eq(surface.get_pixel(1, 1), @graphics.Color::blue())
  assert_eq(surface.get_pixel(2, 1), @graphics.Color::white())

  match
    @graphics.PresentRectPayload::new(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=2),
      4,
      pixels,
    ) {
    Err(InvalidRowBytes(4, 8)) => ()
    _ => abort("expected padded present payload row-byte validation")
  }
  let short_pixels : FixedArray[Byte] = FixedArray::make(19, 0)
  match
    @graphics.PresentRectPayload::new(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=2),
      12,
      short_pixels,
    ) {
    Err(PixelBufferTooSmall(19, 20)) => ()
    _ => abort("expected padded present payload size validation")
  }
}

///|
test "Pixmap::copy_rect snapshots a source rectangle" {
  let pixmap = @graphics.Pixmap::new(3, 2)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::green())
  pixmap.set_pixel(2, 0, @graphics.Color::blue())
  pixmap.set_pixel(1, 1, @graphics.Color::black())
  pixmap.set_pixel(2, 1, @graphics.Color::white())

  match
    pixmap.copy_rect(@graphics.PixelRect::new(x=1, y=0, width=2, height=2)) {
    Ok(snapshot) => {
      assert_eq(snapshot.get_width(), 2)
      assert_eq(snapshot.get_height(), 2)
      assert_eq(snapshot.get_pixel(0, 0), @graphics.Color::green())
      assert_eq(snapshot.get_pixel(1, 0), @graphics.Color::blue())
      assert_eq(snapshot.get_pixel(0, 1), @graphics.Color::black())
      assert_eq(snapshot.get_pixel(1, 1), @graphics.Color::white())
      snapshot.set_pixel(0, 0, @graphics.Color::red())
      assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::green())
    }
    Err(_) => abort("expected pixmap rect snapshot")
  }
}

///|
test "Pixmap::to_ppm_rect_bytes exports a source rectangle" {
  let pixmap = @graphics.Pixmap::new(3, 1)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::new(r=4, g=5, b=6, a=7))
  pixmap.set_pixel(2, 0, @graphics.Color::new(r=8, g=9, b=10, a=11))
  let expected : Array[Byte] = [
    80, 54, 10, 50, 32, 49, 10, 50, 53, 53, 10, 4, 5, 6, 8, 9, 10,
  ]

  match
    pixmap.to_ppm_rect_bytes(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
    ) {
    Ok(ppm) => assert_eq(ppm, Bytes::from_array(expected))
    Err(_) => abort("expected pixmap rect ppm")
  }
}

///|
test "Pixmap::to_bmp_rect_bytes exports a source rectangle" {
  let pixmap = @graphics.Pixmap::new(3, 1)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::new(r=4, g=5, b=6, a=7))
  pixmap.set_pixel(2, 0, @graphics.Color::new(r=8, g=9, b=10, a=11))
  let expected : Array[Byte] = [
    66, 77, 62, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 2, 0, 0, 0, 1, 0,
    0, 0, 1, 0, 32, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 6, 5, 4, 7, 10, 9, 8, 11,
  ]

  match
    pixmap.to_bmp_rect_bytes(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
    ) {
    Ok(bmp) => assert_eq(bmp, Bytes::from_array(expected))
    Err(_) => abort("expected pixmap rect bmp")
  }
}

///|
test "Pixmap::to_png_rect_bytes exports a source rectangle" {
  let pixmap = @graphics.Pixmap::new(3, 1)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::green())
  pixmap.set_pixel(2, 0, @graphics.Color::blue())

  let expected = @graphics.Pixmap::new(1, 1)
  expected.set_pixel(0, 0, @graphics.Color::green())
  match expected.to_png_bytes() {
    Ok(expected_png) =>
      match
        pixmap.to_png_rect_bytes(
          @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
        ) {
        Ok(png) => assert_eq(png, expected_png)
        Err(_) => abort("expected pixmap rect png")
      }
    Err(_) => abort("expected pixmap png")
  }
}

///|
test "Pixmap::checksum_rect reports deterministic rect checksum" {
  let pixmap = @graphics.Pixmap::new(3, 1)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::green())
  pixmap.set_pixel(2, 0, @graphics.Color::blue())

  match
    pixmap.checksum_rect(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)) {
    Ok(checksum) => assert_eq(checksum, 5355)
    Err(_) => abort("expected pixmap rect checksum")
  }
}

///|
test "Pixmap::to_rgba_rect_bytes exports packed source rectangle" {
  let pixmap = @graphics.Pixmap::new(3, 1)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(1, 0, @graphics.Color::green())
  pixmap.set_pixel(2, 0, @graphics.Color::blue())
  let expected : Array[Byte] = [0, 255, 0, 255, 0, 0, 255, 255]

  match
    pixmap.to_rgba_rect_bytes(
      @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
    ) {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array(expected))
    Err(_) => abort("expected pixmap rect rgba bytes")
  }
}

///|
test "Pixmap rect snapshots reuse present rect validation" {
  let pixmap = @graphics.Pixmap::new(2, 2)
  match
    pixmap.copy_rect(@graphics.PixelRect::new(x=-1, y=0, width=1, height=1)) {
    Err(RectOutOfBounds(-1, 0, 1, 1, 2, 2)) => ()
    _ => abort("expected pixmap rect snapshot bounds error")
  }
  match
    pixmap.to_ppm_rect_bytes(
      @graphics.PixelRect::new(x=0, y=0, width=1, height=0),
    ) {
    Err(InvalidDimensions(1, 0)) => ()
    _ => abort("expected pixmap rect ppm dimension error")
  }
  match
    pixmap.to_bmp_rect_bytes(
      @graphics.PixelRect::new(x=0, y=0, width=1, height=0),
    ) {
    Err(InvalidDimensions(1, 0)) => ()
    _ => abort("expected pixmap rect bmp dimension error")
  }
  match
    pixmap.to_png_rect_bytes(
      @graphics.PixelRect::new(x=0, y=0, width=1, height=0),
    ) {
    Err(InvalidDimensions(1, 0)) => ()
    _ => abort("expected pixmap rect png dimension error")
  }
  match
    pixmap.to_rgba_rect_bytes(
      @graphics.PixelRect::new(x=-1, y=0, width=1, height=1),
    ) {
    Err(RectOutOfBounds(-1, 0, 1, 1, 2, 2)) => ()
    _ => abort("expected pixmap rect rgba bounds error")
  }
  match
    pixmap.checksum_rect(@graphics.PixelRect::new(x=2, y=0, width=1, height=1)) {
    Err(RectOutOfBounds(2, 0, 1, 1, 2, 2)) => ()
    _ => abort("expected pixmap rect checksum bounds error")
  }
}

///|
test "Pixmap::present_batch materializes dirty present plan" {
  let pixmap = @graphics.Pixmap::new(4, 2)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(2, 1, @graphics.Color::blue())
  let region = @graphics.DirtyRegion::new()
  region.add_rect(@graphics.PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(@graphics.PixelRect::new(x=2, y=1, width=1, height=1))
  let plan = region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width=4, height=2),
    4,
  )

  match pixmap.present_batch(plan) {
    Ok(batch) => {
      assert_true(!batch.is_empty())
      assert_eq(batch.get_rect_count(), 2)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=2)),
      )
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_eq(batch.get_source_byte_count(), 8)
      assert_eq(batch.get_source_padding_byte_count(), 0)
      assert_true(batch.get_present_strategy(4, 2) == Partial)
      assert_true(batch.saves_full_present_pixels(4, 2))
      assert_eq(batch.get_full_present_pixel_savings(4, 2), 6)
      assert_eq(batch.get_full_present_byte_savings(4, 2), 24)
      assert_true(batch.get_present_strategy(2, 1) == Full)
      assert_true(!batch.saves_full_present_pixels(2, 1))
      assert_eq(batch.get_full_present_pixel_savings(2, 1), 0)
      assert_eq(batch.get_full_present_byte_savings(2, 1), 0)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
      )
      assert_true(
        payloads[1].get_rect() ==
        @graphics.PixelRect::new(x=2, y=1, width=1, height=1),
      )
      let surface = @graphics.MemorySurface::new(4, 2)
      assert_true(batch.submit_to(surface) == Ok(2))
      assert_eq(surface.get_present_count(), 2)
      assert_eq(surface.get_present_pixel_count(), 2)
      assert_eq(surface.get_present_byte_count(), 8)
      assert_eq(surface.get_present_source_byte_count(), 8)
      assert_eq(surface.get_present_source_padding_byte_count(), 0)
      let records = surface.get_present_records()
      assert_eq(records.length(), 2)
      assert_true(
        records[0].get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
      )
      assert_true(
        records[1].get_rect() ==
        @graphics.PixelRect::new(x=2, y=1, width=1, height=1),
      )
      assert_eq(records[0].get_row_bytes(), 4)
      assert_eq(records[1].get_row_bytes(), 4)
      assert_eq(records[0].get_present_pixel_count(), 1)
      assert_eq(records[1].get_present_byte_count(), 4)
      assert_eq(payloads[0].get_source_byte_count(), 4)
      assert_eq(payloads[1].get_source_byte_count(), 4)
      assert_eq(payloads[0].get_source_padding_byte_count(), 0)
      assert_eq(payloads[1].get_source_padding_byte_count(), 0)
      assert_eq(records[0].get_source_byte_count(), 4)
      assert_eq(records[1].get_source_byte_count(), 4)
      assert_eq(records[0].get_source_padding_byte_count(), 0)
      assert_eq(records[1].get_source_padding_byte_count(), 0)
      assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
      assert_eq(surface.get_pixel(2, 1), @graphics.Color::blue())
      assert_true(batch.validate_for(surface) == Ok(()))
    }
    Err(_) => abort("expected dirty present batch")
  }
}

///|
test "Present payload and batch getters return isolated snapshots" {
  let pixmap = @graphics.Pixmap::new(4, 1)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(3, 0, @graphics.Color::blue())
  let region = @graphics.DirtyRegion::new()
  region.add_rect(@graphics.PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let plan = region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width=4, height=1),
    4,
  )

  match pixmap.present_batch(plan) {
    Ok(batch) => {
      let payloads = batch.get_payloads()
      assert_eq(payloads.length(), 2)
      payloads[0] = payloads[1]
      payloads.push(payloads[1])
      assert_eq(batch.get_rect_count(), 2)
      assert_true(
        batch.get_payloads()[0].get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
      )

      let first_pixels = batch.get_payloads()[0].get_pixels()
      assert_eq(first_pixels[0], @graphics.Color::red().r)
      first_pixels[0] = @graphics.Color::green().r
      assert_eq(
        batch.get_payloads()[0].get_pixels()[0],
        @graphics.Color::red().r,
      )

      let surface = @graphics.MemorySurface::new(4, 1)
      assert_true(batch.submit_to(surface) == Ok(2))
      assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
      assert_eq(surface.get_pixel(3, 0), @graphics.Color::blue())
    }
    Err(_) => abort("expected isolated present batch")
  }
}

///|
test "PresentBatch::submit_to preserves materialized payload snapshots" {
  let pixmap = @graphics.Pixmap::new(4, 1)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(3, 0, @graphics.Color::blue())
  let region = @graphics.DirtyRegion::new()
  region.add_rect(@graphics.PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let plan = region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width=4, height=1),
    4,
  )

  match pixmap.present_batch(plan) {
    Ok(batch) => {
      let mutating = MutatingSurface::new(4, 1)
      assert_true(batch.submit_to(mutating) == Ok(2))
      assert_eq(mutating.get_present_count(), 2)

      let payloads = batch.get_payloads()
      assert_rgba(payloads[0].get_pixels(), 0, @graphics.Color::red())
      assert_rgba(payloads[1].get_pixels(), 0, @graphics.Color::blue())

      let surface = @graphics.MemorySurface::new(4, 1)
      assert_true(batch.submit_to(surface) == Ok(2))
      assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
      assert_eq(surface.get_pixel(3, 0), @graphics.Color::blue())
    }
    Err(_) => abort("expected reusable present batch")
  }
}

///|
test "PresentBatch exposes skip partial and full present strategy" {
  let empty_region = @graphics.DirtyRegion::new()
  let pixmap = @graphics.Pixmap::new(4, 2)
  match
    pixmap.present_batch(
      empty_region.present_plan(
        @graphics.PixelRect::new(x=0, y=0, width=4, height=2),
        4,
      ),
    ) {
    Ok(empty) => {
      assert_true(empty.is_empty())
      assert_true(empty.get_present_strategy(4, 2) == Skip)
      assert_true(!empty.saves_full_present_pixels(4, 2))
      assert_eq(empty.get_full_present_pixel_savings(4, 2), 0)
      assert_eq(empty.get_full_present_byte_savings(4, 2), 0)
    }
    Err(_) => abort("expected empty present batch")
  }

  let full_region = @graphics.DirtyRegion::new()
  full_region.add_rect(@graphics.PixelRect::new(x=0, y=0, width=4, height=2))
  match
    pixmap.present_batch(
      full_region.present_plan(
        @graphics.PixelRect::new(x=0, y=0, width=4, height=2),
        4,
      ),
    ) {
    Ok(full) => {
      assert_true(!full.is_empty())
      assert_eq(full.get_present_pixel_count(), 8)
      assert_true(full.get_present_strategy(4, 2) == Full)
      assert_true(!full.saves_full_present_pixels(4, 2))
      assert_eq(full.get_full_present_pixel_savings(4, 2), 0)
      assert_eq(full.get_full_present_byte_savings(4, 2), 0)
    }
    Err(_) => abort("expected full present batch")
  }
}

///|
test "PresentBatch::submit_to_result reports lifecycle telemetry" {
  let pixmap = @graphics.Pixmap::new(4, 2)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(2, 1, @graphics.Color::blue())
  let region = @graphics.DirtyRegion::new()
  region.add_rect(@graphics.PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(@graphics.PixelRect::new(x=2, y=1, width=1, height=1))
  let plan = region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width=4, height=2),
    4,
  )

  match pixmap.present_batch(plan) {
    Ok(batch) => {
      let surface = @graphics.MemorySurface::new(4, 2)
      match batch.submit_plan_for(surface) {
        Ok(submit_plan) => {
          assert_eq(surface.get_present_count(), 0)
          assert_eq(submit_plan.get_surface_width(), 4)
          assert_eq(submit_plan.get_surface_height(), 2)
          assert_eq(submit_plan.get_rect_count(), 2)
          assert_true(submit_plan.needs_present())
          assert_true(submit_plan.get_present_strategy() == Partial)
          assert_true(submit_plan.saves_full_present_pixels())
          assert_true(
            submit_plan.get_present_bounds() ==
            Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=2)),
          )
          assert_eq(submit_plan.get_present_pixel_count(), 2)
          assert_eq(submit_plan.get_present_byte_count(), 8)
          assert_eq(submit_plan.get_source_byte_count(), 8)
          assert_eq(submit_plan.get_source_padding_byte_count(), 0)
          assert_eq(submit_plan.get_full_present_pixel_savings(), 6)
          assert_eq(submit_plan.get_full_present_byte_savings(), 24)
          let plan_batch = submit_plan.get_batch()
          assert_eq(plan_batch.get_rect_count(), 2)
          let plan_payloads = plan_batch.get_payloads()
          plan_payloads[0] = plan_payloads[1]
          plan_payloads[0].get_pixels()[0] = @graphics.Color::green().r
          assert_true(
            submit_plan.get_batch().get_payloads()[0].get_rect() ==
            @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
          )
          assert_eq(
            submit_plan.get_batch().get_payloads()[0].get_pixels()[0],
            @graphics.Color::red().r,
          )
        }
        Err(_) => abort("expected present batch submit plan")
      }
      match batch.submit_to_result(surface) {
        Ok(result) => {
          assert_eq(result.get_surface_width(), 4)
          assert_eq(result.get_surface_height(), 2)
          assert_eq(result.get_rect_count(), 2)
          assert_eq(result.get_presented_rect_count(), 2)
          assert_true(result.did_present())
          assert_true(result.needs_present())
          assert_true(result.get_present_strategy() == Partial)
          assert_true(result.saves_full_present_pixels())
          assert_true(
            result.get_present_bounds() ==
            Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=2)),
          )
          assert_eq(result.get_present_pixel_count(), 2)
          assert_eq(result.get_present_byte_count(), 8)
          assert_eq(result.get_source_byte_count(), 8)
          assert_eq(result.get_source_padding_byte_count(), 0)
          assert_eq(result.get_full_present_pixel_savings(), 6)
          assert_eq(result.get_full_present_byte_savings(), 24)
          let result_batch = result.get_batch()
          assert_eq(result_batch.get_rect_count(), 2)
          let result_payloads = result_batch.get_payloads()
          result_payloads[0] = result_payloads[1]
          result_payloads[0].get_pixels()[0] = @graphics.Color::green().r
          assert_true(
            result.get_batch().get_payloads()[0].get_rect() ==
            @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
          )
          assert_eq(
            result.get_batch().get_payloads()[0].get_pixels()[0],
            @graphics.Color::red().r,
          )
          let returned_plan = result.get_submit_plan()
          assert_eq(returned_plan.get_rect_count(), 2)
          returned_plan.batch.payloads[0] = returned_plan.batch.payloads[1]
          returned_plan.batch.payloads[0].pixels[0] = @graphics.Color::green().r
          assert_true(
            result.get_submit_plan().batch.payloads[0].rect ==
            @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
          )
          assert_eq(
            result.get_submit_plan().batch.payloads[0].pixels[0],
            @graphics.Color::red().r,
          )
        }
        Err(_) => abort("expected present batch submit result")
      }
    }
    Err(_) => abort("expected dirty present batch")
  }
}

///|
test "PresentBatchSubmitPlan submits prevalidated batches" {
  let pixmap = @graphics.Pixmap::new(4, 2)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(2, 1, @graphics.Color::blue())
  let region = @graphics.DirtyRegion::new()
  region.add_rect(@graphics.PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(@graphics.PixelRect::new(x=2, y=1, width=1, height=1))
  let dirty_plan = region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width=4, height=2),
    4,
  )

  let batch = match pixmap.present_batch(dirty_plan) {
    Ok(value) => value
    Err(_) => abort("expected dirty present batch")
  }
  let plan = match batch.submit_plan_for(@graphics.MemorySurface::new(4, 2)) {
    Ok(value) => value
    Err(_) => abort("expected present batch submit plan")
  }

  let stale_surface = @graphics.MemorySurface::new(2, 2)
  match plan.submit_to_result(stale_surface) {
    Err(SizeMismatch(4, 2, 2, 2)) => ()
    _ => abort("expected stale submit plan dimensions error")
  }
  assert_eq(stale_surface.get_present_count(), 0)
  assert_eq(stale_surface.get_present_records().length(), 0)
  assert_eq(stale_surface.get_pixel(0, 0), @graphics.Color::transparent())

  let result_surface = @graphics.MemorySurface::new(4, 2)
  match plan.submit_to_result(result_surface) {
    Ok(result) => {
      assert_eq(result.get_surface_width(), 4)
      assert_eq(result.get_surface_height(), 2)
      assert_eq(result.get_rect_count(), 2)
      assert_eq(result.get_presented_rect_count(), 2)
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(result.get_present_strategy() == Partial)
      assert_true(result.saves_full_present_pixels())
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=2)),
      )
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_eq(result.get_source_byte_count(), 8)
      assert_eq(result.get_full_present_pixel_savings(), 6)
      assert_eq(result.get_full_present_byte_savings(), 24)
    }
    Err(_) => abort("expected present batch submit result")
  }
  assert_eq(result_surface.get_present_count(), 2)
  assert_eq(result_surface.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(result_surface.get_pixel(2, 1), @graphics.Color::blue())

  let count_surface = @graphics.MemorySurface::new(4, 2)
  assert_true(plan.submit_to(count_surface) == Ok(2))
  assert_eq(count_surface.get_present_count(), 2)
  assert_eq(count_surface.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(count_surface.get_pixel(2, 1), @graphics.Color::blue())
}

///|
test "PresentBatch::submit_to_result reports empty skip lifecycle" {
  let pixmap = @graphics.Pixmap::new(4, 2)
  let region = @graphics.DirtyRegion::new()
  match
    pixmap.present_batch(
      region.present_plan(
        @graphics.PixelRect::new(x=0, y=0, width=4, height=2),
        4,
      ),
    ) {
    Ok(batch) => {
      let surface = @graphics.MemorySurface::new(4, 2)
      match batch.submit_plan_for(surface) {
        Ok(submit_plan) => {
          assert_eq(surface.get_present_count(), 0)
          assert_eq(submit_plan.get_rect_count(), 0)
          assert_true(!submit_plan.needs_present())
          assert_true(submit_plan.get_present_strategy() == Skip)
          assert_true(!submit_plan.saves_full_present_pixels())
          assert_true(submit_plan.get_present_bounds() == None)
          assert_eq(submit_plan.get_present_pixel_count(), 0)
          assert_eq(submit_plan.get_present_byte_count(), 0)
          assert_eq(submit_plan.get_source_byte_count(), 0)
          assert_eq(submit_plan.get_source_padding_byte_count(), 0)
          assert_eq(submit_plan.get_full_present_pixel_savings(), 0)
          assert_eq(submit_plan.get_full_present_byte_savings(), 0)
        }
        Err(_) => abort("expected empty present batch submit plan")
      }
      match batch.submit_to_result(surface) {
        Ok(result) => {
          assert_eq(result.get_rect_count(), 0)
          assert_eq(result.get_presented_rect_count(), 0)
          assert_true(!result.did_present())
          assert_true(!result.needs_present())
          assert_true(result.get_present_strategy() == Skip)
          assert_true(!result.saves_full_present_pixels())
          assert_true(result.get_present_bounds() == None)
          assert_eq(result.get_present_pixel_count(), 0)
          assert_eq(result.get_present_byte_count(), 0)
          assert_eq(result.get_source_byte_count(), 0)
          assert_eq(result.get_source_padding_byte_count(), 0)
          assert_eq(result.get_full_present_pixel_savings(), 0)
          assert_eq(result.get_full_present_byte_savings(), 0)
        }
        Err(_) => abort("expected empty present batch submit result")
      }
    }
    Err(_) => abort("expected empty present batch")
  }
}

///|
test "PresentBatch::submit_to preflights every payload before presenting" {
  let pixmap = @graphics.Pixmap::new(4, 2)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(2, 1, @graphics.Color::blue())
  let region = @graphics.DirtyRegion::new()
  region.add_rect(@graphics.PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(@graphics.PixelRect::new(x=2, y=1, width=1, height=1))
  let plan = region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width=4, height=2),
    4,
  )

  match pixmap.present_batch(plan) {
    Ok(batch) => {
      let surface = @graphics.MemorySurface::new(2, 2)
      assert_true(
        batch.validate_for(surface) == Err(RectOutOfBounds(2, 1, 1, 1, 2, 2)),
      )
      match batch.submit_plan_for(surface) {
        Err(RectOutOfBounds(2, 1, 1, 1, 2, 2)) => ()
        _ => abort("expected submit plan bounds error")
      }
      assert_true(
        batch.submit_to(surface) == Err(RectOutOfBounds(2, 1, 1, 1, 2, 2)),
      )
      match batch.submit_to_result(surface) {
        Err(RectOutOfBounds(2, 1, 1, 1, 2, 2)) => ()
        _ => abort("expected submit result bounds error")
      }
      assert_eq(surface.get_present_count(), 0)
      assert_eq(surface.get_present_records().length(), 0)
      assert_eq(surface.get_pixel(0, 0), @graphics.Color::transparent())
    }
    Err(_) => abort("expected dirty present batch")
  }
}

///|
test "PresentBatch::submit_to_result stops after backend failure" {
  let pixmap = @graphics.Pixmap::new(4, 2)
  pixmap.set_pixel(0, 0, @graphics.Color::red())
  pixmap.set_pixel(2, 1, @graphics.Color::blue())
  let region = @graphics.DirtyRegion::new()
  region.add_rect(@graphics.PixelRect::new(x=0, y=0, width=1, height=1))
  region.add_rect(@graphics.PixelRect::new(x=2, y=1, width=1, height=1))
  let plan = region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width=4, height=2),
    4,
  )

  match pixmap.present_batch(plan) {
    Ok(batch) => {
      let surface = BackendFailingSurface::new(4, 2)
      assert_true(batch.validate_for(surface) == Ok(()))
      match batch.submit_plan_for(surface) {
        Ok(submit_plan) => {
          assert_eq(submit_plan.get_rect_count(), 2)
          assert_true(submit_plan.needs_present())
        }
        Err(_) => abort("expected present batch submit plan")
      }
      assert_eq(surface.get_present_rect_count(), 0)

      match batch.submit_to_result(surface) {
        Err(InvalidDimensions(0, 0)) => ()
        _ => abort("expected backend present failure")
      }
      assert_eq(surface.get_present_rect_count(), 1)
      assert_true(
        surface.get_present_rect(0) ==
        @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
      )
    }
    Err(_) => abort("expected dirty present batch")
  }
}

///|
test "Pixmap::present_batch rejects out-of-bounds rects" {
  let pixmap = @graphics.Pixmap::new(2, 2)
  let region = @graphics.DirtyRegion::new()
  region.add_rect(@graphics.PixelRect::new(x=1, y=1, width=2, height=1))
  let plan = region.present_plan(
    @graphics.PixelRect::new(x=0, y=0, width=3, height=2),
    4,
  )
  match pixmap.present_batch(plan) {
    Err(RectOutOfBounds(1, 1, 2, 1, 2, 2)) => ()
    _ => abort("expected out-of-bounds present batch error")
  }
}

///|
test "Canvas::present_to presents rendered canvas pixels to surface" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let surface = @graphics.MemorySurface::new(2, 1)
  let result = canvas.present_to(surface)
  assert_true(result == Ok(()))
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::black())
  assert_eq(surface.get_pixel(1, 0), @graphics.Color::white())
}

///|
test "Canvas::present_dirty_to presents dirty rectangles and clears tracking" {
  let canvas = @graphics.Canvas::new(4, 3)
  canvas.draw_pixel(1, 1, @graphics.Color::red())
  canvas.draw_pixel(3, 2, @graphics.Color::blue())
  let surface = @graphics.MemorySurface::new(4, 3)
  let result = canvas.present_dirty_to(surface)
  assert_true(result == Ok(2))
  assert_eq(surface.get_present_count(), 2)
  assert_eq(surface.get_present_records().length(), 2)
  assert_eq(surface.get_pixel(1, 1), @graphics.Color::red())
  assert_eq(surface.get_pixel(3, 2), @graphics.Color::blue())
  assert_true(canvas.get_dirty_region().is_empty())
  assert_true(canvas.present_dirty_to(surface) == Ok(0))
}

///|
test "Canvas::present_dirty_to presents merged adjacent dirty rectangles" {
  let canvas = @graphics.Canvas::new(4, 2)
  canvas.draw_pixel(1, 0, @graphics.Color::red())
  canvas.draw_pixel(2, 0, @graphics.Color::green())
  let surface = @graphics.MemorySurface::new(4, 2)
  let result = canvas.present_dirty_to(surface)
  assert_true(result == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), @graphics.Color::red())
  assert_eq(surface.get_pixel(2, 0), @graphics.Color::green())
}

///|
test "Canvas::present_dirty_to_with_limit falls back to dirty bounds" {
  let canvas = @graphics.Canvas::new(8, 2)
  canvas.draw_pixel(0, 0, @graphics.Color::red())
  canvas.draw_pixel(3, 0, @graphics.Color::green())
  canvas.draw_pixel(6, 0, @graphics.Color::blue())
  let surface = @graphics.MemorySurface::new(8, 2)
  let result = canvas.present_dirty_to_with_limit(surface, 2)
  assert_true(result == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_present_pixel_count(), 7)
  assert_eq(surface.get_present_byte_count(), 28)
  assert_eq(surface.get_present_source_byte_count(), 28)
  match surface.get_last_present_record() {
    Some(record) => {
      assert_true(
        record.get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=7, height=1),
      )
      assert_eq(record.get_present_pixel_count(), 7)
      assert_eq(record.get_present_byte_count(), 28)
      assert_eq(record.get_source_byte_count(), 28)
    }
    None => abort("expected dirty bounds present record")
  }
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(surface.get_pixel(3, 0), @graphics.Color::green())
  assert_eq(surface.get_pixel(6, 0), @graphics.Color::blue())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::dirty_present_plan matches bounded dirty submit strategy" {
  let canvas = @graphics.Canvas::new(8, 2)
  canvas.draw_pixel(0, 0, @graphics.Color::red())
  canvas.draw_pixel(3, 0, @graphics.Color::green())
  canvas.draw_pixel(6, 0, @graphics.Color::blue())

  let surface = @graphics.MemorySurface::new(8, 2)
  let rect_plan = canvas.dirty_present_plan(surface, 4)
  assert_true(rect_plan.get_mode() == Rects)
  assert_eq(rect_plan.get_rect_count(), 3)
  assert_true(
    rect_plan.get_rects()[2] ==
    @graphics.PixelRect::new(x=6, y=0, width=1, height=1),
  )

  let bounds_plan = canvas.dirty_present_plan(surface, 2)
  assert_true(bounds_plan.get_mode() == Bounds)
  assert_true(bounds_plan.uses_bounds_fallback())
  assert_eq(bounds_plan.get_rect_count(), 1)
  assert_true(
    bounds_plan.get_rects()[0] ==
    @graphics.PixelRect::new(x=0, y=0, width=7, height=1),
  )
  assert_true(!canvas.get_dirty_region().is_empty())

  assert_true(canvas.present_dirty_to_with_limit(surface, 2) == Ok(1))
  assert_true(canvas.get_dirty_region().is_empty())

  let empty_plan = canvas.dirty_present_plan(surface, 2)
  assert_true(empty_plan.is_empty())
  assert_true(empty_plan.get_mode() == Empty)
}

///|
test "Canvas::dirty_present_batch materializes without clearing dirty" {
  let canvas = @graphics.Canvas::new(8, 2)
  canvas.draw_pixel(0, 0, @graphics.Color::red())
  canvas.draw_pixel(3, 0, @graphics.Color::green())
  canvas.draw_pixel(6, 0, @graphics.Color::blue())
  let surface = @graphics.MemorySurface::new(8, 2)

  match canvas.dirty_present_batch(surface, 2) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 7)
      assert_eq(batch.get_present_byte_count(), 28)
      assert_eq(batch.get_source_byte_count(), 28)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=7, height=1),
      )
      assert_eq(payloads[0].get_row_bytes(), 28)
    }
    Err(_) => abort("expected dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_true(!canvas.get_dirty_region().is_empty())
  assert_true(canvas.present_dirty_to_with_limit(surface, 2) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::dirty_present_batch clips partially visible dirty rectangles" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.draw_pixel(1, 0, @graphics.Color::green())
  canvas.draw_pixel(2, 0, @graphics.Color::blue())
  let surface = @graphics.MemorySurface::new(2, 1)

  match canvas.dirty_present_batch(surface, 4) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_eq(batch.get_source_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      assert_eq(payloads[0].get_row_bytes(), 4)
      assert_rgba(payloads[0].get_pixels(), 0, @graphics.Color::green())
    }
    Err(_) => abort("expected clipped dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(surface.get_pixel(1, 0), @graphics.Color::transparent())
  assert_true(!canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::dirty_present_batch returns empty batch for clipped dirty" {
  let canvas = @graphics.Canvas::new(3, 3)
  canvas.draw_pixel(2, 2, @graphics.Color::white())
  let surface = @graphics.MemorySurface::new(2, 2)

  match canvas.dirty_present_batch(surface, 4) {
    Ok(batch) => {
      assert_true(batch.is_empty())
      assert_eq(batch.get_rect_count(), 0)
      assert_eq(batch.get_present_pixel_count(), 0)
      assert_eq(batch.get_present_byte_count(), 0)
      assert_eq(batch.get_source_byte_count(), 0)
    }
    Err(_) => abort("expected empty dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_true(!canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::present_dirty_to clips dirty rectangles to surface bounds" {
  let canvas = @graphics.Canvas::new(3, 3)
  canvas.draw_pixel(2, 2, @graphics.Color::white())
  let surface = @graphics.MemorySurface::new(2, 2)
  let result = canvas.present_dirty_to(surface)
  assert_true(result == Ok(0))
  assert_true(canvas.get_dirty_region().is_empty())
  assert_eq(surface.get_present_count(), 0)
}

///|
test "present_pixels helper dispatches through Surface trait" {
  let surface = @graphics.MemorySurface::new(1, 1)
  let pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  write_rgba(pixels, 0, @graphics.Color::green())
  let result = @graphics.present_pixels(surface, 1, 1, 4, pixels)
  assert_true(result == Ok(()))
  assert_eq(surface.get_pixel(0, 0), @graphics.Color::green())
}

///|
test "present_pixels_rect helper dispatches through Surface trait" {
  let surface = @graphics.MemorySurface::new(2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  write_rgba(pixels, 0, @graphics.Color::blue())
  let result = @graphics.present_pixels_rect(surface, 1, 1, 1, 1, 4, pixels)
  assert_true(result == Ok(()))
  assert_eq(surface.get_pixel(1, 1), @graphics.Color::blue())
}

///|
struct MutatingSurface {
  width : Int
  height : Int
  mut present_count : Int
} derive(Debug)

///|
fn MutatingSurface::new(width : Int, height : Int) -> MutatingSurface {
  { width, height, present_count: 0, }
}

///|
fn MutatingSurface::get_present_count(self : MutatingSurface) -> Int {
  self.present_count
}

///|
fn MutatingSurface::present_rect(
  self : MutatingSurface,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[Unit, @graphics.PresentError] {
  match
    @graphics.validate_present_rect(
      self.width,
      self.height,
      x,
      y,
      width,
      height,
      row_bytes,
      pixels,
    ) {
    Err(error) => Err(error)
    Ok(_) => {
      write_rgba(pixels, 0, @graphics.Color::green())
      self.present_count = self.present_count + 1
      Ok(())
    }
  }
}

///|
impl Surface for MutatingSurface with fn get_width(self) {
  self.width
}

///|
impl Surface for MutatingSurface with fn get_height(self) {
  self.height
}

///|
impl Surface for MutatingSurface with fn present_pixels(
  self,
  width,
  height,
  row_bytes,
  pixels,
) {
  self.present_rect(0, 0, width, height, row_bytes, pixels)
}

///|
impl Surface for MutatingSurface with fn present_pixels_rect(
  self,
  x,
  y,
  width,
  height,
  row_bytes,
  pixels,
) {
  self.present_rect(x, y, width, height, row_bytes, pixels)
}

///|
struct BackendFailingSurface {
  width : Int
  height : Int
  present_rects : Array[@graphics.PixelRect]
} derive(Debug)

///|
fn BackendFailingSurface::new(
  width : Int,
  height : Int,
) -> BackendFailingSurface {
  { width, height, present_rects: [], }
}

///|
fn BackendFailingSurface::get_present_rect_count(
  self : BackendFailingSurface,
) -> Int {
  self.present_rects.length()
}

///|
fn BackendFailingSurface::get_present_rect(
  self : BackendFailingSurface,
  index : Int,
) -> @graphics.PixelRect {
  self.present_rects[index]
}

///|
fn BackendFailingSurface::present_rect(
  self : BackendFailingSurface,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : FixedArray[Byte],
) -> Result[Unit, @graphics.PresentError] {
  match
    @graphics.validate_present_rect(
      self.width,
      self.height,
      x,
      y,
      width,
      height,
      row_bytes,
      pixels,
    ) {
    Err(error) => Err(error)
    Ok(_) =>
      if self.present_rects.length() > 0 {
        Err(InvalidDimensions(0, 0))
      } else {
        self.present_rects.push(
          @graphics.PixelRect::new(x~, y~, width~, height~),
        )
        Ok(())
      }
  }
}

///|
impl Surface for BackendFailingSurface with fn get_width(self) {
  self.width
}

///|
impl Surface for BackendFailingSurface with fn get_height(self) {
  self.height
}

///|
impl Surface for BackendFailingSurface with fn present_pixels(
  self,
  width,
  height,
  row_bytes,
  pixels,
) {
  self.present_rect(0, 0, width, height, row_bytes, pixels)
}

///|
impl Surface for BackendFailingSurface with fn present_pixels_rect(
  self,
  x,
  y,
  width,
  height,
  row_bytes,
  pixels,
) {
  self.present_rect(x, y, width, height, row_bytes, pixels)
}

///|
fn write_rgba(
  pixels : FixedArray[Byte],
  offset : Int,
  color : @graphics.Color,
) -> Unit {
  pixels[offset] = color.r
  pixels[offset + 1] = color.g
  pixels[offset + 2] = color.b
  pixels[offset + 3] = color.a
}

///|
fn assert_rgba(
  pixels : FixedArray[Byte],
  offset : Int,
  color : @graphics.Color,
) -> Unit raise {
  assert_eq(pixels[offset], color.r)
  assert_eq(pixels[offset + 1], color.g)
  assert_eq(pixels[offset + 2], color.b)
  assert_eq(pixels[offset + 3], color.a)
}
