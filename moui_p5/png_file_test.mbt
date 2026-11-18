///|
/// Local-file `load_image` tests. The addon owns no host filesystem, so these
/// tests inject in-memory `FilePorts` instead of touching the real one.

///|
fn png_file_test_bytes() -> Bytes {
  try! @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8DwHwQBEPgD/U6VwW8AAAAASUVORK5CYII=",
    ignore_whitespace=true,
  )
}

///|
/// In-memory ports over `store`: a save stores the bytes, a load returns them.
fn png_file_test_ports(store : Map[String, Bytes]) -> @moui_p5.FilePorts {
  @moui_p5.FilePorts::new(load=fn(path) { store.get(path) }, save=fn(
    path,
    bytes,
  ) {
    store[path] = bytes
    true
  })
}

///|
test "load_image decodes a local PNG file and file URL" {
  let store : Map[String, Bytes] = Map([])
  store["fixture.png"] = png_file_test_bytes()
  let sketch = Sketch::new(
    Recorder::new() as &Surface,
    10.0,
    10.0,
    file_ports=png_file_test_ports(store),
  )
  let image = sketch.try_load_image("fixture.png").unwrap()
  inspect(image.width(), content="2")
  inspect(image.height(), content="1")
  let red = image.get(0, 0)
  inspect(red.r, content="1")
  inspect(red.g, content="0")
  let green = image.get(1, 0)
  inspect(green.r, content="0")
  inspect(green.g, content="1")
  // `file://` paths use the same decoder.
  let file_url = sketch.try_load_image("file://fixture.png").unwrap()
  inspect(file_url.width(), content="2")
  inspect(file_url.height(), content="1")
  // A missing file is reported by try_load_image and becomes a placeholder.
  let missing = "fixture.missing.png"
  assert_true(sketch.try_load_image(missing) is None)
  let mut loaded = false
  let placeholder = sketch.load_image(missing, on_load=fn(_image) {
    loaded = true
  })
  assert_true(loaded)
  inspect(placeholder.width(), content="1")
  inspect(placeholder.height(), content="1")
}

///|
test "Image::save writes a PNG that load_image can read back" {
  let store : Map[String, Bytes] = Map([])
  let ports = png_file_test_ports(store)
  let path = "saved.png"
  let image = Image::new(3, 2)
  image.set(0, 0, Color::rgb(10.0, 20.0, 30.0))
  image.set(2, 1, Color::rgb(200.0, 100.0, 50.0))
  assert_true(
    image.save(path, saver=fn(path, bytes) { ports.save(path, bytes) }),
  )
  let sketch = Sketch::new(
    Recorder::new() as &Surface,
    10.0,
    10.0,
    file_ports=ports,
  )
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
  // A saver that rejects the path fails without raising.
  let rejecting = @moui_p5.FilePorts::new(load=fn(_path) { None }, save=fn(
    _path,
    _bytes,
  ) {
    false
  })
  assert_false(image.save("nested/out.png", saver=rejecting.save))
  // `Sketch::save_image` routes the same way, through the sketch's ports.
  assert_true(sketch.save_image(image, "via_ports.png"))
  match store.get("via_ports.png") {
    Some(_) => ()
    None => fail("Sketch::save_image did not reach the sketch ports")
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
