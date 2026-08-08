///|
fn sun_codec_test_jpeg_bytes() -> Bytes {
  let image : @image.ImageData = {
    width: 1,
    height: 1,
    data: Bytes::from_array([255, 24, 16, 255]),
  }
  try! @image.encode_jpeg(image, quality=92)
}

///|
fn sun_codec_test_jpeg_data_uri() -> String {
  "data:image/jpeg;base64," +
  @base64.encode(sun_codec_test_jpeg_bytes(), padding=true)
}

///|
fn sun_codec_test_bmp_bytes() -> Bytes {
  let pixmap = @sun_graphics.Pixmap::new(1, 1)
  pixmap.set_pixel(0, 0, @sun_graphics.Color::new(r=24, g=255, b=16, a=255))
  pixmap.to_bmp_bytes()
}

///|
fn sun_codec_test_bmp_data_uri_uppercase_type() -> String {
  "data:image/BMP;base64," +
  @base64.encode(sun_codec_test_bmp_bytes(), padding=true)
}

///|
fn sun_codec_test_temp_env(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let clean = value.trim().to_owned()
      if clean == "" {
        None
      } else {
        Some(clean)
      }
    }
    None => None
  }
}

///|
fn sun_codec_test_temp_dir() -> String {
  let names = ["MOUI_TEST_TMPDIR", "TMPDIR", "TEMP", "TMP"]
  for name in names {
    match sun_codec_test_temp_env(name) {
      Some(value) => return value
      None => ()
    }
  }
  "/tmp"
}

///|
fn sun_codec_test_temp_path(filename : String) -> String {
  let dir = sun_codec_test_temp_dir()
  let chars = dir.to_array()
  if chars.length() == 0 {
    filename
  } else if chars[chars.length() - 1] == '/' ||
    chars[chars.length() - 1] == '\\' {
    dir + filename
  } else {
    dir + "/" + filename
  }
}

///|
fn sun_codec_test_image_command(source : String) -> @core.DrawCommand {
  @core.DrawCommand::DrawImage(@core.ImageRun::{
    source,
    frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
    opacity: 1.0,
    fit: @core.ImageFit::Contain,
  })
}

///|
fn sun_codec_test_image_record(
  records : Array[@render.ImageResourceRecord],
  source : String,
) -> @render.ImageResourceRecord? {
  for record in records {
    if record.source == source {
      return Some(record)
    }
  }
  None
}

///|
fn sun_codec_test_assert_ready_jpeg(
  records : Array[@render.ImageResourceRecord],
  source : String,
) -> Unit raise {
  match sun_codec_test_image_record(records, source) {
    Some(
      {
        status: @render.ImageResourceStatus::ImageReady,
        width: 1,
        height: 1,
        ..,
      }
    ) => ()
    _ => fail("expected ready 1x1 Sun JPEG image record")
  }
}

///|
fn sun_codec_test_assert_ready_bmp(
  records : Array[@render.ImageResourceRecord],
  source : String,
) -> Unit raise {
  match sun_codec_test_image_record(records, source) {
    Some(
      {
        status: @render.ImageResourceStatus::ImageReady,
        width: 1,
        height: 1,
        ..,
      }
    ) => ()
    _ => fail("expected ready 1x1 Sun BMP image record")
  }
}

///|
test "sun renderer decodes jpeg data uri and local files" {
  let local_source = sun_codec_test_temp_path("moui-sun-local-image-codec.jpg")
  @fs.remove_file(local_source) catch {
    _ => ()
  }
  defer (@fs.remove_file(local_source) catch { _ => () })
  @fs.write_bytes_to_file(local_source, sun_codec_test_jpeg_bytes()) catch {
    _ => fail("expected local JPEG fixture write")
  }
  let data_uri_source = sun_codec_test_jpeg_data_uri()
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    SunPresentTarget::new(description="test", present=_ => true),
    async_image_loading=true,
  )

  renderer.render([sun_codec_test_image_command(data_uri_source)])
  renderer.render([sun_codec_test_image_command(local_source)])
  ignore(
    renderer.apply_image_resource_load_completion(
      sun_image_load_completion(data_uri_source),
    ),
  )
  ignore(
    renderer.apply_image_resource_load_completion(
      sun_image_load_completion_from_bytes(
        local_source,
        @fs.read_file_to_bytes(local_source) catch {
          _ => fail("expected host JPEG byte read")
        },
        background_io=true,
      ),
    ),
  )
  renderer.render([
    sun_codec_test_image_command(data_uri_source),
    sun_codec_test_image_command(local_source),
  ])
  let records = renderer.image_resources()
  sun_codec_test_assert_ready_jpeg(records, data_uri_source)
  sun_codec_test_assert_ready_jpeg(records, local_source)
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun renderer decodes bmp sources with uppercase type and extension" {
  let local_source = sun_codec_test_temp_path("moui-sun-local-image-codec.BMP")
  @fs.remove_file(local_source) catch {
    _ => ()
  }
  defer (@fs.remove_file(local_source) catch { _ => () })
  @fs.write_bytes_to_file(local_source, sun_codec_test_bmp_bytes()) catch {
    _ => fail("expected local BMP fixture write")
  }
  let data_uri_source = sun_codec_test_bmp_data_uri_uppercase_type()
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    SunPresentTarget::new(description="test", present=_ => true),
    async_image_loading=true,
  )

  renderer.render([sun_codec_test_image_command(data_uri_source)])
  renderer.render([sun_codec_test_image_command(local_source)])
  ignore(
    renderer.apply_image_resource_load_completion(
      sun_image_load_completion(data_uri_source),
    ),
  )
  ignore(
    renderer.apply_image_resource_load_completion(
      sun_image_load_completion_from_bytes(
        local_source,
        @fs.read_file_to_bytes(local_source) catch {
          _ => fail("expected host BMP byte read")
        },
        background_io=true,
      ),
    ),
  )
  renderer.render([
    sun_codec_test_image_command(data_uri_source),
    sun_codec_test_image_command(local_source),
  ])
  let records = renderer.image_resources()
  sun_codec_test_assert_ready_bmp(records, data_uri_source)
  sun_codec_test_assert_ready_bmp(records, local_source)
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun renderer decodes image sources by byte signature fallback" {
  let local_source = sun_codec_test_temp_path(
    "moui-sun-local-image-codec-misleading.jpg",
  )
  @fs.remove_file(local_source) catch {
    _ => ()
  }
  defer (@fs.remove_file(local_source) catch { _ => () })
  @fs.write_bytes_to_file(local_source, sun_codec_test_bmp_bytes()) catch {
    _ => fail("expected misleading local BMP fixture write")
  }
  let data_uri_source = "data:image/jpeg;base64," +
    @base64.encode(sun_codec_test_bmp_bytes(), padding=true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    SunPresentTarget::new(description="test", present=_ => true),
    async_image_loading=true,
  )

  renderer.render([sun_codec_test_image_command(data_uri_source)])
  renderer.render([sun_codec_test_image_command(local_source)])
  ignore(
    renderer.apply_image_resource_load_completion(
      sun_image_load_completion(data_uri_source),
    ),
  )
  ignore(
    renderer.apply_image_resource_load_completion(
      sun_image_load_completion_from_bytes(
        local_source,
        @fs.read_file_to_bytes(local_source) catch {
          _ => fail("expected host signature-fallback byte read")
        },
        background_io=true,
      ),
    ),
  )
  renderer.render([
    sun_codec_test_image_command(data_uri_source),
    sun_codec_test_image_command(local_source),
  ])
  let records = renderer.image_resources()
  sun_codec_test_assert_ready_bmp(records, data_uri_source)
  sun_codec_test_assert_ready_bmp(records, local_source)
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun image load completion from bytes decodes jpeg" {
  let completion = sun_image_load_completion_from_bytes(
    "fixture.jpeg",
    sun_codec_test_jpeg_bytes(),
    background_io=true,
  )
  assert_true(
    completion.status ==
    @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
  )
  inspect(completion.width, content="1")
  inspect(completion.height, content="1")
  inspect(completion.background_io, content="true")
  let failed = sun_image_load_completion_from_bytes(
    "invalid.jpg", b"not-a-jpeg",
  )
  assert_true(
    failed.status == @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
  )
  assert_true(failed.diagnostic.contains("could not decode JPEG image bytes"))
}

///|
test "sun image load completion from bytes infers format from bytes" {
  let completion = sun_image_load_completion_from_bytes(
    "fixture-without-extension",
    sun_codec_test_bmp_bytes(),
  )
  assert_true(
    completion.status ==
    @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
  )
  inspect(completion.width, content="1")
  inspect(completion.height, content="1")
}

///|
test "sun image load completion from bytes handles misleading extensions" {
  let completion = sun_image_load_completion_from_bytes(
    "fixture.jpg",
    sun_codec_test_bmp_bytes(),
  )
  assert_true(
    completion.status ==
    @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
  )
  inspect(completion.width, content="1")
  inspect(completion.height, content="1")
}
