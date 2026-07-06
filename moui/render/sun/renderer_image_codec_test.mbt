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
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    SunPresentTarget::new(description="test", present=_ => true),
  )

  renderer.render([sun_codec_test_image_command(data_uri_source)])
  renderer.render([sun_codec_test_image_command(local_source)])
  let records = renderer.image_resources()
  sun_codec_test_assert_ready_jpeg(records, data_uri_source)
  sun_codec_test_assert_ready_jpeg(records, local_source)
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
