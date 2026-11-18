///|
/// Local-file `load_image` tests. These need host file I/O, so `moon.pkg`
/// restricts this file to the native target.

///|
fn png_file_test_bytes() -> Bytes {
  try! @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8DwHwQBEPgD/U6VwW8AAAAASUVORK5CYII=",
    ignore_whitespace=true,
  )
}

///|
/// Writes the fixture to the first writable candidate and returns its path.
/// The test working directory varies between hosts, so fall back to it last.
fn png_file_test_write_fixture() -> String {
  let bytes = png_file_test_bytes()
  let candidates = [
    "/tmp/moui_p5_load_image_fixture.png", "C:/Temp/moui_p5_load_image_fixture.png",
    "moui_p5_load_image_fixture.png",
  ]
  for path in candidates {
    try {
      @fs.write_bytes_to_file(path, bytes)
      return path
    } catch {
      _ => ()
    }
  }
  abort("no writable path for the p5 load_image fixture")
}

///|
test "load_image decodes a local PNG file and file URL" {
  let path = png_file_test_write_fixture()
  let sketch = Sketch::new(Recorder::new() as &Surface, 10.0, 10.0)
  let image = sketch.try_load_image(path).unwrap()
  inspect(image.width(), content="2")
  inspect(image.height(), content="1")
  let red = image.get(0, 0)
  inspect(red.r, content="1")
  inspect(red.g, content="0")
  let green = image.get(1, 0)
  inspect(green.r, content="0")
  inspect(green.g, content="1")
  // `file://` paths use the same decoder.
  let file_url = sketch.try_load_image("file://" + path).unwrap()
  inspect(file_url.width(), content="2")
  inspect(file_url.height(), content="1")
  // A missing file is reported by try_load_image and becomes a placeholder.
  let missing = path + ".missing"
  assert_true(sketch.try_load_image(missing) is None)
  let mut loaded = false
  let placeholder = sketch.load_image(missing, on_load=fn(_image) {
    loaded = true
  })
  assert_true(loaded)
  inspect(placeholder.width(), content="1")
  inspect(placeholder.height(), content="1")
  @fs.remove_file(path) catch {
    _ => ()
  }
}

///|
test "Image::save writes a PNG that load_image can read back" {
  let path = png_file_test_write_fixture() + ".saved.png"
  let image = Image::new(3, 2)
  image.set(0, 0, Color::rgb(10.0, 20.0, 30.0))
  image.set(2, 1, Color::rgb(200.0, 100.0, 50.0))
  assert_true(image.save(path))
  let sketch = Sketch::new(Recorder::new() as &Surface, 10.0, 10.0)
  let loaded = sketch.try_load_image(path).unwrap()
  inspect(loaded.width(), content="3")
  inspect(loaded.height(), content="2")
  let corner = loaded.get(0, 0)
  inspect((corner.r * 255.0).to_int(), content="10")
  inspect((corner.g * 255.0).to_int(), content="20")
  inspect((corner.b * 255.0).to_int(), content="30")
  let opposite = loaded.get(2, 1)
  inspect((opposite.r * 255.0).to_int(), content="200")
  inspect((opposite.g * 255.0).to_int(), content="100")
  inspect((opposite.b * 255.0).to_int(), content="50")
  // A path whose parent directory does not exist fails without raising.
  assert_false(image.save(path + "/nested/out.png"))
  @fs.remove_file(path) catch {
    _ => ()
  }
}

///|
test "load_image does not fetch HTTP sources synchronously" {
  let sketch = Sketch::new(Recorder::new() as &Surface, 10.0, 10.0)
  let source = "https://example.com/p5.png"
  assert_true(sketch.try_load_image(source) is None)
  let mut loaded = false
  let image = sketch.load_image(source, on_load=fn(_image) { loaded = true })
  assert_true(loaded)
  inspect(image.width(), content="1")
  inspect(image.height(), content="1")
}
