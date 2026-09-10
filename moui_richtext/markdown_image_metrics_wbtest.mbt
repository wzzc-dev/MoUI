///|
/// 1200x630 PNG: header + IHDR length + "IHDR" + be32 width/height.
let image_metrics_png_bytes : Bytes = b"\x89PNG\x0d\x0a\x1a\x0a\x00\x00\x00\x0dIHDR\x00\x00\x04\xb0\x00\x00\x02\x7c"

///|
test "image metrics parse intrinsic sizes from headers" {
  match markdown_image_metrics_size_from_bytes(image_metrics_png_bytes) {
    Some(size) => {
      assert_eq(size.width, 1200.0)
      assert_eq(size.height, 636.0)
    }
    None => fail("expected a PNG header size")
  }
  // GIF 800x528
  match markdown_image_metrics_size_from_bytes(b"GIF89a\x20\x03\x10\x02") {
    Some(size) => {
      assert_eq(size.width, 800.0)
      assert_eq(size.height, 528.0)
    }
    None => fail("expected a GIF header size")
  }
  // BMP 256x512
  match
    markdown_image_metrics_size_from_bytes(
      b"BM\x36\x00\x00\x00\x00\x00\x00\x00\x28\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x02\x00\x00",
    ) {
    Some(size) => {
      assert_eq(size.width, 256.0)
      assert_eq(size.height, 512.0)
    }
    None => fail("expected a BMP header size")
  }
  // WebP VP8 (lossy) 400x368
  match
    markdown_image_metrics_size_from_bytes(
      b"RIFF\x00\x00\x00\x00WEBPVP8 \x00\x00\x00\x00\x00\x00\x00\x9d\x01\x2a\x90\x01\x70\x01",
    ) {
    Some(size) => {
      assert_eq(size.width, 400.0)
      assert_eq(size.height, 368.0)
    }
    None => fail("expected a WebP VP8 header size")
  }
  // WebP VP8L (lossless) 101x51
  match
    markdown_image_metrics_size_from_bytes(
      b"RIFF\x00\x00\x00\x00WEBPVP8L\x00\x00\x00\x00\x2f\x64\x80\x0c\x00",
    ) {
    Some(size) => {
      assert_eq(size.width, 101.0)
      assert_eq(size.height, 51.0)
    }
    None => fail("expected a WebP VP8L header size")
  }
  // WebP VP8X (extended) 808x332: flags + reserved at 20..23, canvas
  // size minus one at 24..26 / 27..29.
  match
    markdown_image_metrics_size_from_bytes(
      b"RIFF\x00\x00\x00\x00WEBPVP8X\x0a\x00\x00\x00\x00\x00\x00\x00\x27\x03\x00\x4b\x01\x00",
    ) {
    Some(size) => {
      assert_eq(size.width, 808.0)
      assert_eq(size.height, 332.0)
    }
    None => fail("expected a WebP VP8X header size")
  }
  // JPEG baseline 1200x636
  match
    markdown_image_metrics_size_from_bytes(
      b"\xff\xd8\xff\xc0\x00\x11\x08\x02\x7c\x04\xb0\x00",
    ) {
    Some(size) => {
      assert_eq(size.width, 1200.0)
      assert_eq(size.height, 636.0)
    }
    None => fail("expected a JPEG start-of-frame size")
  }
  assert_true(
    markdown_image_metrics_size_from_bytes(b"NOTANIMAGE!!!!!!!!") is None,
  )
}

///|
test "image metrics lookup skips remote sources and caches misses" {
  let mut reads = 0
  markdown_set_image_metrics_reader(source => {
    reads = reads + 1
    if source == "/tmp/docs/resource/a.png" {
      Some(image_metrics_png_bytes)
    } else {
      None
    }
  })
  defer markdown_set_image_metrics_reader(_ => None)
  assert_true(
    markdown_image_metrics_size("https://img.shields.io/badge.svg") is None,
  )
  assert_true(markdown_image_metrics_size("data:image/png;base64,AAAA") is None)
  match markdown_image_metrics_size("/tmp/docs/resource/a.png") {
    Some(size) => assert_eq(size.width, 1200.0)
    None => fail("expected the registered reader's size")
  }
  match markdown_image_metrics_size("/tmp/docs/resource/a.png") {
    Some(size) => assert_eq(size.height, 636.0)
    None => fail("expected the cached size")
  }
  // The remote probes and the two local lookups: the cache must have served
  // the second local lookup without a second read.
  assert_eq(reads, 1)
  assert_true(markdown_image_metrics_size("/tmp/docs/missing.png") is None)
}

///|
test "html gallery percentage images use the intrinsic aspect ratio" {
  markdown_set_image_metrics_reader(source => {
    if source == "/tmp/docs/resource/a.png" {
      Some(image_metrics_png_bytes)
    } else {
      None
    }
  })
  defer markdown_set_image_metrics_reader(_ => None)
  let gallery =
    #|<div align="center">
    #|  <img src="resource/a.png" width="48%" alt="A"/>
    #|  <img src="resource/b.png" width="48%" alt="B"/>
    #|</div>
  let blocks = parse_markdown(gallery)
  let block = markdown_block_to_rich_text(
    blocks[0],
    @core.FontSpec::new(),
    base_dir=Some("/tmp/docs"),
  )
  guard block.runs.length() >= 2 else {
    fail("expected two gallery image runs")
  }
  // Probed image: the box keeps the real 1200x636 shape at 48% of the
  // column instead of the placeholder 16:9 aspect.
  guard block.runs[0]
    is { image_size: Some(probed), image_width_fraction: Some(_), .. } else {
    fail("expected a percentage gallery image")
  }
  assert_eq(probed.width, 1200.0)
  assert_eq(probed.height, 636.0)
  // Unprobed image: the placeholder aspect is retained.
  guard block.runs[1] is { image_size: Some(missing), .. } else {
    fail("expected the second gallery image")
  }
  assert_eq(missing.width / missing.height, 8.0 / 4.5)
}

///|
test "plain markdown images use the intrinsic size" {
  markdown_set_image_metrics_reader(source => {
    if source == "/tmp/docs/resource/a.png" {
      Some(image_metrics_png_bytes)
    } else {
      None
    }
  })
  defer markdown_set_image_metrics_reader(_ => None)
  let blocks = parse_markdown("![A](resource/a.png)")
  let block = markdown_block_to_rich_text(
    blocks[0],
    @core.FontSpec::new(),
    base_dir=Some("/tmp/docs"),
  )
  guard block.runs.length() >= 1 else { fail("expected an image run") }
  guard block.runs[0] is { image_size: Some(size), .. } else {
    fail("expected an image run size")
  }
  assert_eq(size.width, 1200.0)
  assert_eq(size.height, 636.0)
}
