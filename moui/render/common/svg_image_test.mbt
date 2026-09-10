///|
test "svg_source_is_svg recognizes suffixes and root tags" {
  // Path suffix, independent of payload.
  assert_true(svg_source_is_svg("assets/logo.svg", Bytes::make(0, 0)))
  assert_true(svg_source_is_svg("assets/logo.SVG", Bytes::make(0, 0)))
  assert_true(svg_source_is_svg("assets/logo.svgz", Bytes::make(0, 0)))
  // Tag sniffing, for sources served without a useful extension.
  assert_true(
    svg_source_is_svg(
      "https://example.com/asset", b"<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\"/>",
    ),
  )
  // A raster payload is not SVG.
  assert_false(svg_source_is_svg("photo.png", b"\x89PNG\r\n\x1a\n"))
  assert_false(svg_source_is_svg("photo.jpg", b"\xff\xd8\xff\xe0"))
}

///|
test "svg_intrinsic_size prefers viewBox and falls back to viewport" {
  let with_view_box = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 32 16\">" +
    "<rect width=\"32\" height=\"16\" fill=\"black\"/></svg>"
  match svg_intrinsic_size(with_view_box) {
    Some(size) => {
      inspect(size.width, content="32")
      inspect(size.height, content="16")
    }
    None => fail("expected a viewBox-derived size")
  }

  let with_attributes = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\">" +
    "<rect width=\"64\" height=\"48\" fill=\"black\"/></svg>"
  match svg_intrinsic_size(with_attributes) {
    Some(size) => {
      inspect(size.width, content="64")
      inspect(size.height, content="48")
    }
    None => fail("expected a viewport-derived size")
  }

  assert_true(svg_intrinsic_size("not an svg at all") is None)
}

///|
test "svg_raster_target_size preserves aspect ratio within the budget" {
  let (wide_w, wide_h) = svg_raster_target_size(
    @core.Size::new(width=20.0, height=10.0),
  )
  inspect(wide_w, content="40")
  inspect(wide_h, content="20")

  // Oversized inputs are clamped to the longest-edge bound instead of
  // allocating an unbounded bitmap.
  let (big_w, big_h) = svg_raster_target_size(
    @core.Size::new(width=20000.0, height=10000.0),
  )
  assert_true(big_w <= 2048)
  assert_true(big_h <= 2048)
  assert_true(big_w > big_h)
}

///|
test "svg_rasterize_rgba emits premultiplied rgba for a filled shape" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 10\">" +
    "<rect width=\"20\" height=\"10\" fill=\"#ff0000\"/></svg>"
  match svg_rasterize_rgba(svg, 40, 20) {
    Some(pixels) => {
      inspect(pixels.length(), content="3200")
      // Center pixel of an opaque red fill: premultiplication is a no-op.
      let offset = 10 * (40 * 4) + 20 * 4
      inspect(pixels[offset].to_int(), content="255")
      inspect(pixels[offset + 1].to_int(), content="0")
      inspect(pixels[offset + 2].to_int(), content="0")
      inspect(pixels[offset + 3].to_int(), content="255")
    }
    None => fail("expected rasterized pixels")
  }

  assert_true(svg_rasterize_rgba("not svg", 8, 8) is None)
}

///|
test "svg image decoder produces a ready rgba completion for svg sources" {
  let decoder = svg_image_decoder()
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 10\">" +
    "<rect width=\"20\" height=\"10\" fill=\"#3366cc\"/></svg>"
  let completion = decoder.decode(
    "assets/mark.svg",
    Some(@utf8.encode(svg, bom=false)),
  )
  assert_true(completion.has_decoded_rgba_payload())
  assert_true(
    completion.status ==
    @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
  )
  inspect(completion.width, content="40")
  inspect(completion.height, content="20")
  inspect(completion.decoded_row_bytes, content="160")
}

///|
test "svg image decoder declines non-svg and missing bytes" {
  let decoder = svg_image_decoder()

  let raster = decoder.decode("photo.png", Some(b"\x89PNG\r\n\x1a\n"))
  assert_true(
    raster.status == @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
  )
  assert_false(raster.has_decoded_rgba_payload())

  let missing = decoder.decode("assets/mark.svg", None)
  assert_true(
    missing.status == @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
  )
}

///|
test "svg intrinsic size honors pixel units and rejects percentages" {
  let pixels = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48px\" height=\"24px\">" +
    "<rect width=\"48\" height=\"24\" fill=\"black\"/></svg>"
  match svg_intrinsic_size(pixels) {
    Some(size) => {
      inspect(size.width, content="48")
      inspect(size.height, content="24")
    }
    None => fail("expected px units to resolve")
  }

  let fractional = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10.5\" height=\"5\">" +
    "<rect width=\"10\" height=\"5\" fill=\"black\"/></svg>"
  match svg_intrinsic_size(fractional) {
    Some(size) => inspect(size.width, content="10.5")
    None => fail("expected a fractional width to resolve")
  }

  // Percentages cannot be resolved without a containing viewport.
  let percent = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" height=\"50%\">" +
    "<rect width=\"10\" height=\"10\" fill=\"black\"/></svg>"
  assert_true(svg_intrinsic_size(percent) is None)
}

///|
test "svg decoder falls back to the default box when size is undeclared" {
  let decoder = svg_image_decoder()
  // No viewBox and no root width/height: the document is still renderable.
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\">" +
    "<rect width=\"10\" height=\"10\" fill=\"black\"/></svg>"
  let completion = decoder.decode(
    "mark.svg",
    Some(@utf8.encode(svg, bom=false)),
  )
  assert_true(completion.has_decoded_rgba_payload())
  inspect(completion.width, content="600")
  inspect(completion.height, content="300")
}

///|
test "svg rasterization scales documents that declare only width and height" {
  // A document without a viewBox still has to fill the raster canvas: the
  // shields.io badges are `width`/`height` only, and without the synthesized
  // viewBox their artwork lands shrunken in one corner.
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"120\" height=\"20\">" +
    "<rect width=\"120\" height=\"20\" fill=\"#555555\"/></svg>"
  match svg_rasterize_rgba(svg, 240, 40) {
    Some(pixels) => {
      inspect(pixels.length(), content="38400")
      // Bottom-right corner: painted only when the document is scaled to fit.
      let last = 39 * (240 * 4) + 239 * 4
      inspect(pixels[last + 3].to_int(), content="255")
      inspect(pixels[last].to_int(), content="85")
    }
    None => fail("expected rasterized pixels")
  }
}

///|
test "svg translucent overlay composites over the shapes beneath it" {
  // Shape order matters: the 10%-opacity overlay is painted last and must
  // blend, not replace, or it erases the badge body (shields.io shades its
  // badges exactly this way).
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"120\" height=\"20\">" +
    "<linearGradient id=\"s\" x2=\"0\" y2=\"100%\">" +
    "<stop offset=\"0\" stop-color=\"#bbbbbb\" stop-opacity=\".1\"/>" +
    "<stop offset=\"1\" stop-opacity=\".1\"/></linearGradient>" +
    "<rect width=\"47\" height=\"20\" fill=\"#555555\"/>" +
    "<rect x=\"47\" width=\"73\" height=\"20\" fill=\"#007ec6\"/>" +
    "<rect width=\"120\" height=\"20\" fill=\"url(#s)\"/>" +
    "</svg>"
  match svg_rasterize_rgba(svg, 120, 20) {
    Some(pixels) => {
      let row_bytes = 120 * 4
      // Left segment stays solid grey, only slightly lightened by the overlay.
      let grey = row_bytes * 10 + 20 * 4
      assert_true(pixels[grey + 3].to_int() >= 200)
      assert_true(pixels[grey].to_int() > 60)
      assert_true(pixels[grey].to_int() < 140)
      // Right segment stays solid and distinctly blue.
      let blue = row_bytes * 10 + 100 * 4
      assert_true(pixels[blue + 3].to_int() >= 200)
      assert_true(pixels[blue + 2].to_int() > pixels[blue].to_int())
    }
    None => fail("expected rasterized pixels")
  }
}
