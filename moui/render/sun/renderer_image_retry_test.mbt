///|
fn sun_retry_test_png_bytes() -> Bytes {
  try! @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==",
    ignore_whitespace=true,
  )
}

///|
fn sun_retry_test_temp_env(name : String) -> String? {
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
fn sun_retry_test_temp_dir() -> String {
  let names = ["MOUI_TEST_TMPDIR", "TMPDIR", "TEMP", "TMP"]
  for name in names {
    match sun_retry_test_temp_env(name) {
      Some(value) => return value
      None => ()
    }
  }
  "/tmp"
}

///|
fn sun_retry_test_temp_path(filename : String) -> String {
  let dir = sun_retry_test_temp_dir()
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
test "sun renderer retries async local image failures when file appears" {
  let source = sun_retry_test_temp_path("moui-sun-local-image-retry.png")
  @fs.remove_file(source) catch {
    _ => ()
  }
  defer (@fs.remove_file(source) catch { _ => () })
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
    async_image_loading=true,
  )
  let revisions : Array[Int] = []
  renderer.set_image_resource_change_callback(
    Some(snapshot => revisions.push(snapshot.revision)),
  )
  let commands = [
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]

  renderer.render(commands)
  inspect(renderer.image_resource_snapshot().revision, content="1")
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageLoading, .. } else {
    fail("expected initial loading local image record")
  }
  let failed_snapshot = renderer.apply_image_resource_load_completion(
    sun_image_load_completion(source),
  )
  inspect(failed_snapshot.revision, content="2")
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageFailed, diagnostic, .. } else {
    fail("expected failed local image record")
  }
  assert_true(diagnostic.contains("could not decode image source"))

  renderer.render(commands)
  inspect(renderer.image_resource_snapshot().revision, content="2")
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageFailed, .. } else {
    fail("expected missing local image to stay failed before file appears")
  }

  @fs.write_bytes_to_file(source, sun_retry_test_png_bytes()) catch {
    _ => fail("expected local image retry fixture write")
  }
  renderer.render(commands)
  inspect(renderer.image_resource_snapshot().revision, content="3")
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageLoading, .. } else {
    fail("expected failed local image to retry as loading after file appears")
  }
  let ready_snapshot = renderer.apply_image_resource_load_completion(
    sun_image_load_completion(source),
  )
  inspect(ready_snapshot.revision, content="4")
  guard renderer.image_resources()[0]
    is {
      status: @render.ImageResourceStatus::ImageReady,
      width: 1,
      height: 1,
      ..,
    } else {
    fail("expected ready local image record after retry")
  }
  assert_true(revisions == [1, 2, 3, 4])
  renderer.render(commands)
  inspect(renderer.image_resource_snapshot().revision, content="4")
  inspect(renderer.unsupported_command_count(), content="0")
}
