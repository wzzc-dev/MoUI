///|
test "image placement for contain fit - image wider than frame" {
  let image_size = @core.Size::new(width=200.0, height=100.0)
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)
  let result = calculate_image_placement(
    frame,
    image_size,
    @core.ImageFit::Contain,
  )
  inspect(result.frame.origin.x, content="10")
  inspect(result.frame.origin.y, content="45")
  inspect(result.frame.size.width, content="100")
  inspect(result.frame.size.height, content="50")
  inspect(result.u0, content="0")
  inspect(result.v0, content="0")
  inspect(result.u1, content="1")
  inspect(result.v1, content="1")
}

///|
test "image placement for contain fit - image taller than frame" {
  let image_size = @core.Size::new(width=100.0, height=200.0)
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)
  let result = calculate_image_placement(
    frame,
    image_size,
    @core.ImageFit::Contain,
  )
  inspect(result.frame.origin.x, content="35")
  inspect(result.frame.origin.y, content="20")
  inspect(result.frame.size.width, content="50")
  inspect(result.frame.size.height, content="100")
  inspect(result.u0, content="0")
  inspect(result.v0, content="0")
  inspect(result.u1, content="1")
  inspect(result.v1, content="1")
}

///|
test "image placement for contain fit - image same ratio as frame" {
  let image_size = @core.Size::new(width=100.0, height=100.0)
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)
  let result = calculate_image_placement(
    frame,
    image_size,
    @core.ImageFit::Contain,
  )
  inspect(result.frame.origin.x, content="10")
  inspect(result.frame.origin.y, content="20")
  inspect(result.frame.size.width, content="100")
  inspect(result.frame.size.height, content="100")
  inspect(result.u0, content="0")
  inspect(result.v0, content="0")
  inspect(result.u1, content="1")
  inspect(result.v1, content="1")
}

///|
test "image placement for cover fit - image wider than frame" {
  let image_size = @core.Size::new(width=200.0, height=100.0)
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)
  let result = calculate_image_placement(
    frame,
    image_size,
    @core.ImageFit::Cover,
  )
  inspect(result.frame.origin.x, content="10")
  inspect(result.frame.origin.y, content="20")
  inspect(result.frame.size.width, content="100")
  inspect(result.frame.size.height, content="100")
  inspect(result.u0, content="0.25")
  inspect(result.v0, content="0")
  inspect(result.u1, content="0.75")
  inspect(result.v1, content="1")
}

///|
test "image placement for cover fit - image taller than frame" {
  let image_size = @core.Size::new(width=100.0, height=200.0)
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)
  let result = calculate_image_placement(
    frame,
    image_size,
    @core.ImageFit::Cover,
  )
  inspect(result.u0, content="0")
  inspect(result.v0, content="0.25")
  inspect(result.u1, content="1")
  inspect(result.v1, content="0.75")
}

///|
test "image placement for cover fit - image same ratio as frame" {
  let image_size = @core.Size::new(width=100.0, height=100.0)
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)
  let result = calculate_image_placement(
    frame,
    image_size,
    @core.ImageFit::Cover,
  )
  inspect(result.u0, content="0")
  inspect(result.v0, content="0")
  inspect(result.u1, content="1")
  inspect(result.v1, content="1")
}

///|
test "image vertex generation" {
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=80.0)
  let vertices = generate_image_vertices(
    frame,
    @core.Transform2D::identity(),
    0.1,
    0.2,
    0.9,
    0.8,
    0.5,
    @core.Size::new(width=320.0, height=240.0),
  )
  inspect(vertices.length(), content="6")

  inspect(vertices[0].x, content="-0.9375")
  assert_double_close(vertices[0].y, 0.8333333333333334)
  inspect(vertices[0].u, content="0.1")
  inspect(vertices[0].v, content="0.2")
  inspect(vertices[0].opacity, content="0.5")

  inspect(vertices[1].x, content="-0.9375")
  assert_double_close(vertices[1].y, 0.16666666666666663)
  inspect(vertices[1].u, content="0.1")
  inspect(vertices[1].v, content="0.8")

  inspect(vertices[2].x, content="-0.3125")
  assert_double_close(vertices[2].y, 0.16666666666666663)
  inspect(vertices[2].u, content="0.9")
  inspect(vertices[2].v, content="0.8")

  inspect(vertices[3].x, content="-0.9375")
  assert_double_close(vertices[3].y, 0.8333333333333334)
  inspect(vertices[3].u, content="0.1")
  inspect(vertices[3].v, content="0.2")

  inspect(vertices[4].x, content="-0.3125")
  assert_double_close(vertices[4].y, 0.16666666666666663)
  inspect(vertices[4].u, content="0.9")
  inspect(vertices[4].v, content="0.8")

  inspect(vertices[5].x, content="-0.3125")
  assert_double_close(vertices[5].y, 0.8333333333333334)
  inspect(vertices[5].u, content="0.9")
  inspect(vertices[5].v, content="0.2")
}

///|
fn assert_double_close(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 0.000001)
}

///|
test "native image decodes png data uri through mizchi image" {
  let png = @image.encode_png({ width: 1, height: 1, data: b"\x20\x80\xff\xcc" }) catch {
    _ => panic()
  }
  let source = "data:image/png;base64," + @base64.encode(png)
  guard load_native_image_data(source) is Some(decoded) else {
    fail("expected decoded data uri image")
  }
  inspect(decoded.width, content="1")
  inspect(decoded.height, content="1")
  inspect(decoded.data[0].to_int(), content="32")
  inspect(decoded.data[1].to_int(), content="128")
  inspect(decoded.data[2].to_int(), content="255")
  inspect(decoded.data[3].to_int(), content="204")
}

///|
test "native image decodes jpeg data uri through mizchi image" {
  let jpeg = @image.encode_jpeg(
    {
      width: 8,
      height: 8,
      data: Bytes::makei(8 * 8 * 4, i => {
        let channel = i % 4
        if channel == 0 {
          b'\xDC'
        } else if channel == 1 {
          b'\x28'
        } else if channel == 2 {
          b'\x5A'
        } else {
          b'\xFF'
        }
      }),
    },
    quality=95,
  ) catch {
    _ => panic()
  }
  let source = "data:image/jpeg;base64," + @base64.encode(jpeg)
  guard load_native_image_data(source) is Some(decoded) else {
    fail("expected decoded jpeg data uri image")
  }
  inspect(decoded.width, content="8")
  inspect(decoded.height, content="8")
  assert_true(decoded.data.length() == 8 * 8 * 4)
  assert_true(decoded.data[3].to_int() == 255)
}

///|
test "native image decodes bmp data uri through mizchi image" {
  let bmp = @image.encode_bmp({
    width: 2,
    height: 1,
    data: b"\xff\x00\x00\xff\x00\x80\xff\xff",
  }) catch {
    _ => panic()
  }
  let source = "data:image/bmp;base64," + @base64.encode(bmp)
  guard load_native_image_data(source) is Some(decoded) else {
    fail("expected decoded bmp data uri image")
  }
  inspect(decoded.width, content="2")
  inspect(decoded.height, content="1")
  inspect(decoded.data[0].to_int(), content="255")
  inspect(decoded.data[6].to_int(), content="255")
}

///|
test "native image decodes local png file through mizchi image" {
  let path = "moui_native_image_test.tmp.png"
  let png = @image.encode_png({ width: 1, height: 1, data: b"\xff\x00\x40\xff" }) catch {
    _ => panic()
  }
  @fs.write_bytes_to_file(path, png) catch {
    _ => panic()
  }
  guard load_native_image_data(path) is Some(decoded) else {
    @fs.remove_file(path) catch {
      _ => ()
    }
    fail("expected decoded local image")
  }
  @fs.remove_file(path) catch {
    _ => ()
  }
  inspect(decoded.width, content="1")
  inspect(decoded.height, content="1")
  inspect(decoded.data[0].to_int(), content="255")
  inspect(decoded.data[2].to_int(), content="64")
}
