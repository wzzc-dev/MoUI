///|
using @p5 {
  type Color,
  type Random,
  type Noise,
  type Matrix,
  type Path,
  type Sketch,
  type Recorder,
  type Vector,
  type Image,
  type Filter,
  constrain,
  map,
  round,
  fract,
  hsb_to_rgb,
  parse_color,
}

///|
/// Core tests run on the native backend with no window: the `Recorder`
/// surface makes every drawing call observable and text measurement
/// deterministic.

///|
priv struct TestCounter {
  mut setup : Int32
  mut draw : Int32
}

///|
priv struct TestInputCounter {
  mut pressed : Int32
  mut dragged : Int32
  mut released : Int32
  mut keyed : Int32
}

///|
test "p5 random matches the p5.js LCG sequence" {
  let random = Random::new(99.0)
  inspect(random.next(), content="0.27443566313013434")
  inspect(random.next(), content="0.2582396597135812")
  inspect(random.range(10.0, 20.0), content="16.056527215987444")
  inspect(random.range(0.0, 5.0), content="1.6624356142710894")
}

///|
test "p5 random seed is reproducible" {
  let a = Random::new(7.0)
  let b = Random::new(7.0)
  for _ in 0..<8 {
    assert_eq(a.next(), b.next())
  }
}

///|
test "p5 noise is deterministic and in range" {
  let a = Noise::new(42.0)
  let b = Noise::new(42.0)
  inspect(a.noise(0.5), content="0.2027877284999704")
  inspect(a.noise(0.5, y=0.25), content="0.39451964056898436")
  inspect(a.noise(1.7, y=2.3, z=3.1), content="0.47469508278664296")
  for index in 0..<10 {
    let x = index.to_double() * 0.37
    let value = a.noise(x, y=0.25, z=0.5)
    assert_true(value >= 0.0 && value <= 1.0)
    assert_eq(value, b.noise(x, y=0.25, z=0.5))
  }
}

///|
test "scalar helpers follow p5 semantics" {
  inspect(constrain(15.0, 0.0, 10.0), content="10")
  inspect(map(5.0, 0.0, 10.0, 0.0, 100.0), content="50")
  inspect(round(2.5), content="3")
  inspect(round(-2.5), content="-2")
  inspect(round(3.14159, decimals=2), content="3.14")
  inspect(fract(-1.25), content="0.75")
}

///|
test "HSB and RGB color conversions" {
  let red = hsb_to_rgb(0.0, 1.0, 1.0, 1.0)
  inspect(red.r, content="1")
  inspect(red.g, content="0")
  inspect(red.b, content="0")
  let red = Color::rgb(255.0, 0.0, 0.0)
  inspect(red.hue(), content="0")
  inspect(red.saturation(), content="100")
  inspect(red.brightness(), content="100")
}

///|
test "CSS color parsing" {
  let orange = parse_color("#ff8000").unwrap()
  inspect(orange.r, content="1")
  inspect(orange.g, content="0.5019607843137255")
  assert_eq(parse_color("red").unwrap(), Color::rgb(255.0, 0.0, 0.0))
}

///|
test "matrix composition and inverse" {
  let matrix = Matrix::translation(10.0, 20.0).compose(
    Matrix::rotation(@p5.HALF_PI),
  )
  let (x, y) = matrix.transform_point(1.0, 0.0)
  inspect(x, content="10")
  inspect(y, content="21")
  let (rx, ry) = matrix.inverse().transform_point(x, y)
  assert_true((rx - 1.0).abs() < 1.0e-9)
  assert_true(ry.abs() < 1.0e-9)
}

///|
test "ellipse path has a conservative bound" {
  let path = Path::new()
  path.ellipse_at(50.0, 40.0, 20.0, 10.0)
  let (x, y, width, height) = path.bounds()
  inspect(x, content="30")
  inspect(y, content="30")
  inspect(width, content="40")
  inspect(height, content="20")
}

///|
test "sketch lifecycle advances once per clock tick" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  let counter = TestCounter::{ setup: 0, draw: 0, }
  sketch.setup(_ => counter.setup = counter.setup + 1)
  sketch.draw(p => {
    counter.draw = counter.draw + 1
    p.background(20.0)
    p.fill((255.0, 80.0, 0.0))
    p.rect(10.0, 10.0, 20.0, 20.0)
  })
  assert_true(sketch.frame(0.0))
  assert_eq(counter.setup, 1)
  assert_eq(counter.draw, 1)
  assert_eq(sketch.frame_count, 1)
  assert_false(sketch.frame(0.0))
  assert_eq(counter.draw, 1)
  assert_eq(sketch.frame_count, 1)
  assert_true(sketch.frame(16.0))
  assert_eq(counter.draw, 2)
  assert_eq(sketch.frame_count, 2)
  sketch.no_loop()
  assert_false(sketch.frame(32.0))
  sketch.redraw(frames=1)
  assert_true(sketch.frame(32.0))
  assert_eq(counter.draw, 3)
  let log = recorder.take().join("\n")
  assert_true(log.contains("fill_rect rgb(20,20,20) 0,0,100,100"))
  assert_true(log.contains("fill rgb(255,80,0) M10,10 L30,10 L30,30 L10,30 Z"))
}

///|
test "transform is emitted before geometry" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.no_stroke()
    p.fill("red")
    p.translate(10.0, 5.0)
    p.rect(0.0, 0.0, 4.0, 4.0)
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("transform 1 0 0 1 10 5"))
  assert_true(log.contains("M0,0 L4,0 L4,4 L0,4 Z"))
}

///|
test "text uses the current font and alignment" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.text_size(20.0)
    p.text("Hi", 50.0, 50.0)
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("text rgb(255,255,255) Hi at 50,50 size=20"))
  assert_eq(sketch.text_width("Hi"), 20.0)
}

///|
test "pointer and keyboard callbacks update sketch input state" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  let counter = TestInputCounter::{
    pressed: 0,
    dragged: 0,
    released: 0,
    keyed: 0,
  }
  sketch.on_mouse_pressed(_ => counter.pressed = counter.pressed + 1)
  sketch.on_mouse_dragged(_ => counter.dragged = counter.dragged + 1)
  sketch.on_mouse_released(_ => counter.released = counter.released + 1)
  sketch.on_key_pressed(_ => counter.keyed = counter.keyed + 1)
  sketch.pointer_down(10.0, 20.0)
  assert_true(sketch.mouse_is_pressed)
  inspect(sketch.mouse_x, content="10")
  inspect(sketch.mouse_y, content="20")
  sketch.pointer_move(30.0, 40.0)
  inspect(sketch.moved_x, content="20")
  inspect(sketch.moved_y, content="20")
  sketch.pointer_up(30.0, 40.0)
  assert_false(sketch.mouse_is_pressed)
  sketch.key_down("a", code="KeyA", key_code=65)
  assert_true(sketch.key_is_down("a"))
  inspect(sketch.code, content="KeyA")
  sketch.key_up("a", code="KeyA", key_code=65)
  assert_false(sketch.key_is_down("a"))
  inspect(sketch.code, content="KeyA")
  inspect(counter.pressed, content="1")
  inspect(counter.dragged, content="1")
  inspect(counter.released, content="1")
  inspect(counter.keyed, content="1")
}

///|
test "vector operations" {
  let a = Vector::new(x=3.0, y=4.0)
  inspect(a.mag(), content="5")
  a.normalize()
  inspect(a.mag(), content="1")
  let b = Vector::new(x=1.0, y=0.0)
  b.rotate(@p5.HALF_PI)
  assert_true(b.x.abs() < 1.0e-9)
  inspect(b.y, content="1")
}

///|
test "pmouse is the previous drawn-frame position, not the previous event" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => p.set_mouse_position(1.0, 2.0))
  sketch.draw(_ => ())
  assert_true(sketch.frame(0.0))
  inspect(sketch.pmouse_x, content="1")
  inspect(sketch.pmouse_y, content="2")
  sketch.pointer_move(10.0, 20.0)
  // Inter-frame events update the cursor but not pmouse.
  inspect(sketch.pmouse_x, content="1")
  assert_true(sketch.frame(16.0))
  inspect(sketch.pmouse_x, content="1")
  inspect(sketch.pmouse_y, content="2")
  assert_true(sketch.frame(32.0))
  inspect(sketch.pmouse_x, content="10")
  inspect(sketch.pmouse_y, content="20")
}

///|
test "begin_contour/end_contour emit separate closed subpaths" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.no_fill()
    p.stroke("red")
    p.begin_shape()
    p.vertex(0.0, 0.0)
    p.vertex(10.0, 0.0)
    p.vertex(10.0, 10.0)
    p.end_contour(close=true)
    p.begin_contour()
    p.vertex(20.0, 0.0)
    p.vertex(30.0, 0.0)
    p.vertex(30.0, 10.0)
    p.end_contour(close=true)
    p.end_shape()
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("M0,0 L10,0 L10,10 Z M20,0 L30,0 L30,10 Z"))
}

///|
test "spline_vertex converts Catmull-Rom to cubic Bezier" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.no_fill()
    p.stroke("red")
    p.begin_shape()
    p.spline_vertex(0.0, 0.0)
    p.spline_vertex(10.0, 0.0)
    p.spline_vertex(20.0, 10.0)
    p.spline_vertex(30.0, 10.0)
    p.spline_vertex(40.0, 0.0)
    p.end_shape()
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(
    log.contains(
      "M10,0 C13.333,1.667 16.667,8.333 20,10 C23.333,11.667 26.667,11.667 30,10",
    ),
  )
}

///|
test "curve_vertex aliases spline_vertex and honors tightness" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.no_fill()
    p.stroke("red")
    p.curve_tightness(0.5)
    p.begin_shape()
    p.curve_vertex(0.0, 0.0)
    p.curve_vertex(10.0, 0.0)
    p.curve_vertex(20.0, 10.0)
    p.curve_vertex(30.0, 10.0)
    p.end_shape()
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("M10,0 C11.667,0.833 18.333,9.167 20,10"))
}

///|
test "primitive shape commands record stable path output" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.no_fill()
    p.stroke("red")
    p.line(0.0, 0.0, 10.0, 10.0)
    p.rect(0.0, 0.0, 10.0, 10.0)
    p.triangle(0.0, 0.0, 10.0, 0.0, 5.0, 8.0)
    p.bezier(0.0, 0.0, 10.0, 0.0, 10.0, 10.0, 20.0, 10.0)
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("M0,0 L10,10"))
  assert_true(log.contains("M0,0 L10,0 L10,10 L0,10 Z"))
  assert_true(log.contains("M0,0 L10,0 L5,8 Z"))
  assert_true(log.contains("M0,0 C10,0 10,10 20,10"))
}

///|
test "touch callbacks track ids, positions and pressure" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  let events : Array[String] = []
  sketch.on_touch_started(p => events.push("start:\{p.touches.length()}"))
  sketch.on_touch_moved(p => events.push("move:\{p.touches.length()}"))
  sketch.on_touch_ended(p => events.push("end:\{p.touches.length()}"))
  sketch.touch_started_at(3, 10.0, 20.0, pressure=0.35)
  assert_eq(sketch.touches.length(), 1)
  inspect(sketch.touches[0].id, content="3")
  inspect(sketch.touches[0].pressure, content="0.35")
  inspect(sketch.touches[0].win_x, content="10")
  // A duplicate Down with the same id replaces the entry.
  sketch.touch_started_at(3, 11.0, 21.0, pressure=0.5)
  assert_eq(sketch.touches.length(), 1)
  inspect(sketch.touches[0].x, content="11")
  // Pressure is clamped to 0..1.
  sketch.touch_started_at(7, 30.0, 40.0, pressure=1.5)
  assert_eq(sketch.touches.length(), 2)
  inspect(sketch.touches[1].pressure, content="1")
  sketch.touch_moved_to(3, 12.0, 22.0, pressure=0.6)
  inspect(sketch.touches[0].pressure, content="0.6")
  sketch.touch_ended_at(7)
  assert_eq(sketch.touches.length(), 1)
  inspect(sketch.touches[0].id, content="3")
  sketch.touch_ended_at(99)
  assert_eq(events.length(), 5)
  sketch.touch_ended_at(3)
  assert_eq(sketch.touches.length(), 0)
  assert_eq(events, [
    "start:1", "start:1", "start:2", "move:2", "end:1", "end:0",
  ])
}

///|
test "touch callback draws through the recorder surface" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.on_touch_started(p => {
    p.no_stroke()
    p.fill("red")
    p.circle(p.touches[0].x, p.touches[0].y, 10.0)
  })
  sketch.touch_started_at(0, 10.0, 20.0, pressure=0.5)
  let log = recorder.take().join("\n")
  assert_true(log.contains("rrect rgb(255,0,0) 5,15,10,10 r=5"))
}

///|
test "text input and IME composition update sketch state and callbacks" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  let events : Array[String] = []
  sketch.on_text_input((_, text) => events.push("input:" + text))
  sketch.on_composition_start(_ => events.push("start"))
  sketch.on_composition_update((_, text) => events.push("update:" + text))
  sketch.on_composition_end((_, text) => events.push("end:" + text))
  sketch.composition_start()
  assert_true(sketch.composing)
  inspect(sketch.composition_text, content="")
  sketch.composition_update("に")
  assert_true(sketch.composing)
  inspect(sketch.composition_text, content="に")
  sketch.composition_update("日本")
  inspect(sketch.composition_text, content="日本")
  sketch.composition_end("日本語")
  assert_false(sketch.composing)
  inspect(sketch.composition_text, content="")
  inspect(sketch.last_input_text, content="日本語")
  sketch.text_input("!")
  inspect(sketch.last_input_text, content="!")
  assert_eq(events, [
    "start", "update:に", "update:日本", "end:日本語", "input:!",
  ])
}

///|
test "image buffers support create/set/get/pixels" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  let image = sketch.create_image(2, 2)
  inspect(image.width(), content="2")
  inspect(image.height(), content="2")
  assert_eq(image.pixels.length(), 16)
  image.set(1, 1, Color::rgb(255.0, 0.0, 0.0))
  let pixel = image.get(1, 1)
  inspect(pixel.r, content="1")
  inspect(pixel.g, content="0")
  inspect(pixel.a, content="1")
  // Direct pixel writes are visible through get().
  image.pixels[4] = (255 : Byte)
  inspect(image.get(1, 0).r, content="1")
  image.fill(Color::rgb(0.0, 255.0, 0.0))
  inspect(image.get(0, 0).g, content="1")
  assert_eq(image.get(9, 9), Color::transparent())
  let graphics = sketch.create_graphics(4, 3)
  inspect(graphics.width, content="4")
  inspect(graphics.height, content="3")
}

///|
test "image draws through the recorder surface" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    let image = p.create_image(2, 1)
    image.set(0, 0, Color::rgb(255.0, 0.0, 0.0))
    p.image(image, 10.0, 20.0, width=4.0, height=2.0)
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("image 2x1 at 10,20 size=4x2 opacity=1 tint=none"))
}

///|
test "image filters follow p5 CPU semantics" {
  let red = Image::new(1, 1, fill=Color::rgb(255.0, 0.0, 0.0))
  image_filter_assert(red.copy(), Gray, 54, 54, 54)
  image_filter_assert(red.copy(), Invert, 0, 255, 255)
  image_filter_assert(red.copy(), Threshold(0.5), 0, 0, 0)
  let white = Image::new(1, 1, fill=Color::rgb(255.0, 255.0, 255.0))
  image_filter_assert(white.copy(), Threshold(0.5), 255, 255, 255)
  let translucent = Image::new(1, 1, fill=Color::new(1.0, 1.0, 1.0, 0.2))
  translucent.filter(Opaque)
  inspect(translucent.get(0, 0).a, content="1")
  let posterized = Image::new(1, 1, fill=Color::rgb(128.0, 128.0, 128.0))
  posterized.filter(Posterize(4))
  assert_true(posterized.get(0, 0).r < 0.9)
  // Dilate takes the brightest neighbour; erode the darkest.
  let strip = Image::new(3, 1)
  strip.set(0, 0, Color::rgb(255.0, 255.0, 255.0))
  strip.set(1, 0, Color::rgb(0.0, 0.0, 0.0))
  strip.set(2, 0, Color::rgb(255.0, 255.0, 255.0))
  strip.filter(Dilate)
  inspect(strip.get(1, 0).r, content="1")
  let strip = Image::new(3, 1)
  strip.set(0, 0, Color::rgb(255.0, 255.0, 255.0))
  strip.set(1, 0, Color::rgb(255.0, 255.0, 255.0))
  strip.set(2, 0, Color::rgb(0.0, 0.0, 0.0))
  strip.filter(Erode)
  inspect(strip.get(1, 0).r, content="0")
  let blurred = Image::new(3, 1, fill=Color::rgb(255.0, 255.0, 255.0))
  blurred.set(1, 0, Color::rgb(0.0, 0.0, 0.0))
  blurred.filter(Blur(1.0))
  inspect(blurred.width(), content="3")
}

///|
fn image_filter_assert(
  image : Image,
  filter : Filter,
  r : Int32,
  g : Int32,
  b : Int32,
) -> Unit raise {
  image.filter(filter)
  assert_eq((image.get(0, 0).r * 255.0).round().to_int(), r)
  assert_eq((image.get(0, 0).g * 255.0).round().to_int(), g)
  assert_eq((image.get(0, 0).b * 255.0).round().to_int(), b)
}

///|
test "image tint multiplies channels on a copy" {
  let white = Image::new(1, 1, fill=Color::rgb(255.0, 255.0, 255.0))
  let tinted = white.tinted(Color::rgb(255.0, 0.0, 0.0))
  inspect(tinted.get(0, 0).r, content="1")
  inspect(tinted.get(0, 0).g, content="0")
  inspect(tinted.get(0, 0).b, content="0")
  // The source image is unchanged.
  inspect(white.get(0, 0).g, content="1")
  let translucent = white.tinted(Color::new(1.0, 1.0, 1.0, 0.5))
  assert_true((translucent.get(0, 0).a - 0.5).abs() < 0.01)
}

///|
test "tint state is recorded on image draws" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    let image = p.create_image(1, 1)
    p.tint(Color::rgb(255.0, 0.0, 0.0))
    p.image(image, 0.0, 0.0)
    p.no_tint()
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("tint=rgb(255,0,0)"))
}

///|
test "canvas epoch only advances when the canvas is fully replaced" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 10.0, 10.0)
  let start = sketch.canvas_epoch()
  sketch.background(Color::new(0.0, 0.0, 0.0, 0.5))
  assert_eq(sketch.canvas_epoch(), start)
  sketch.background(Color::rgb(0.0, 0.0, 0.0))
  assert_eq(sketch.canvas_epoch(), start + 1)
  sketch.clear()
  assert_eq(sketch.canvas_epoch(), start + 2)
  sketch.reset_sketch()
  assert_eq(sketch.canvas_epoch(), start + 3)
}

///|
test "create_graphics records vector ops for image() replay" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  let graphics = sketch.create_graphics(10, 10)
  graphics.no_stroke()
  graphics.fill(Color::rgb(255.0, 0.0, 0.0))
  graphics.rect(0.0, 0.0, 10.0, 10.0)
  sketch.image(graphics, 20.0, 30.0, width=20.0, height=20.0)
  let log = recorder.take().join("\n")
  assert_true(log.contains("transform 2 0 0 2 20 30"))
  assert_true(log.contains("fill rgb(255,0,0) M0,0 L10,0 L10,10 L0,10 Z"))
}

///|
test "load_image decodes a PNG data URI into pixels" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  let mut loaded = false
  let image = sketch.load_image(
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8DwHwQBEPgD/U6VwW8AAAAASUVORK5CYII=",
    on_load=fn(_image) { loaded = true },
  )
  assert_true(loaded)
  inspect(image.width(), content="2")
  inspect(image.height(), content="1")
  let red = image.get(0, 0)
  inspect(red.r, content="1")
  inspect(red.g, content="0")
  let green = image.get(1, 0)
  inspect(green.r, content="0")
  inspect(green.g, content="1")
  sketch.image(image, 0.0, 0.0)
  let log = recorder.take().join("\n")
  assert_true(log.contains("image 2x1 at 0,0"))
}

///|
fn png_test_bytes() -> Bytes {
  try! @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8DwHwQBEPgD/U6VwW8AAAAASUVORK5CYII=",
    ignore_whitespace=true,
  )
}

///|
test "load_image_async fills its placeholder from a synchronous fetcher" {
  let sketch = Sketch::new(Recorder::new() as &@p5.Surface, 10.0, 10.0)
  let requests : Array[String] = []
  sketch.set_image_fetcher((source, complete) => {
    requests.push(source)
    complete(Some(png_test_bytes()))
  })
  let mut loaded = 0
  let image = sketch.load_image_async("https://example.com/pic.png", on_load=fn(
    _image,
  ) {
    loaded = loaded + 1
  })
  assert_eq(requests.length(), 1)
  inspect(requests[0], content="https://example.com/pic.png")
  assert_eq(loaded, 1)
  inspect(image.width(), content="2")
  inspect(image.height(), content="1")
  let green = image.get(1, 0)
  inspect(green.g, content="1")
}

///|
test "load_image_async adopts bytes delivered after the call returns" {
  let sketch = Sketch::new(Recorder::new() as &@p5.Surface, 10.0, 10.0)
  sketch.no_loop()
  assert_true(sketch.frame(0.0))
  let pending : Ref[((Bytes?) -> Unit)?] = Ref(None)
  sketch.set_image_fetcher((_source, complete) => pending.val = Some(complete))
  let mut loaded = 0
  let image = sketch.load_image_async("https://example.com/pic.png", on_load=fn(
    _image,
  ) {
    loaded = loaded + 1
  })
  inspect(image.width(), content="1")
  inspect(image.height(), content="1")
  assert_eq(loaded, 0)
  match pending.val {
    Some(complete) => complete(Some(png_test_bytes()))
    None => fail("fetcher was not called")
  }
  assert_eq(loaded, 1)
  inspect(image.width(), content="2")
  inspect(image.height(), content="1")
  let red = image.get(0, 0)
  inspect(red.r, content="1")
  // Completion requests a frame even though the sketch is paused.
  assert_true(sketch.frame(16.0))
  // A second completion from a misbehaving host is ignored.
  match pending.val {
    Some(complete) => complete(Some(png_test_bytes()))
    None => ()
  }
  assert_eq(loaded, 1)
}

///|
test "load_image_async keeps the placeholder when the fetch fails" {
  let sketch = Sketch::new(Recorder::new() as &@p5.Surface, 10.0, 10.0)
  sketch.set_image_fetcher((_source, complete) => complete(None))
  let mut loaded = 0
  let image = sketch.load_image_async("https://example.com/missing.png", on_load=fn(
    _image,
  ) {
    loaded = loaded + 1
  })
  assert_eq(loaded, 1)
  inspect(image.width(), content="1")
  inspect(image.height(), content="1")
}

///|
test "Image::from_rgba and from_rgba_bytes copy host pixels" {
  let packed = FixedArray::make(8, (0 : Byte))
  packed[0] = b'\xff'
  packed[3] = b'\xff'
  let image = Image::from_rgba(1, 2, packed).unwrap()
  inspect(image.width(), content="1")
  inspect(image.height(), content="2")
  inspect(image.get(0, 0).r, content="1")
  assert_true(Image::from_rgba(1, 2, FixedArray::make(4, (0 : Byte))) is None)
  // Row stride larger than width * 4: padding is skipped.
  let strided = b"\x01\x02\x03\x04\xff\xff\xff\xff\x05\x06\x07\x08\xff\xff\xff\xff"
  let rows = Image::from_rgba_bytes(1, 2, 8, strided).unwrap()
  inspect((rows.get(0, 0).r * 255.0).to_int(), content="1")
  inspect((rows.get(0, 0).g * 255.0).to_int(), content="2")
  inspect((rows.get(0, 1).r * 255.0).to_int(), content="5")
  assert_true(Image::from_rgba_bytes(2, 1, 4, strided) is None)
  assert_true(Image::from_rgba_bytes(1, 2, 3, strided) is None)
}

///|
test "Image::to_png_bytes round-trips through the decoder" {
  let image = Image::new(2, 2)
  image.set(0, 0, Color::rgb(255.0, 0.0, 0.0))
  image.set(1, 0, Color::rgb(0.0, 255.0, 0.0))
  image.set(0, 1, Color::rgb(0.0, 0.0, 255.0))
  image.set(1, 1, Color::new(1.0, 1.0, 1.0, 0.5))
  let png = image.to_png_bytes()
  assert_true(png.length() > 8)
  inspect(png[0].to_uint(), content="137")
  inspect(png[1].to_uint(), content="80")
  inspect(png[2].to_uint(), content="78")
  inspect(png[3].to_uint(), content="71")
  let decoded = Image::from_png_bytes(png).unwrap()
  inspect(decoded.width(), content="2")
  inspect(decoded.height(), content="2")
  let red = decoded.get(0, 0)
  inspect(red.r, content="1")
  inspect(red.g, content="0")
  let green = decoded.get(1, 0)
  inspect(green.g, content="1")
  let blue = decoded.get(0, 1)
  inspect(blue.b, content="1")
  let translucent = decoded.get(1, 1)
  inspect(translucent.r, content="1")
  inspect(translucent.a, content="0.5019607843137255")
}

///|
test "text carries stroke state and renders stroke-only without fill" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.fill((255.0, 0.0, 0.0))
    p.stroke((0.0, 0.0, 255.0))
    p.stroke_weight(2.5)
    p.text("Hi", 10.0, 20.0)
    // Previously no_fill + stroke returned early; now the outline carries it.
    p.no_fill()
    p.stroke((0.0, 255.0, 0.0))
    p.text("Hollow", 10.0, 60.0)
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("text rgb(255,0,0) Hi at 10,"))
  assert_true(log.contains("stroke=rgb(0,0,255) w=2.5"))
  // Stroke-only: transparent fill, the outline carries the ink.
  assert_true(log.contains("text rgba(0,0,0,0) Hollow at 10,"))
  assert_true(log.contains("stroke=rgb(0,255,0) w=2.5"))
}

///|
test "rgb tuple alpha uses the 0..255 range while hsb uses 0..1" {
  // p5.js colorMode semantics: RGB alpha max is 255, HSB/HSL alpha max is 1.
  // This catches the classic "fill((r,g,b,0.5)) in RGB mode is invisible" bug.
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 10.0, 10.0)
  sketch.setup(p => {
    p.no_stroke()
    p.color_mode(@p5.RGB)
    p.fill((255.0, 0.0, 0.0, 128.0))
    p.rect(0.0, 0.0, 1.0, 1.0)
    p.color_mode(@p5.HSB)
    p.fill((0.0, 100.0, 100.0, 0.5))
    p.rect(0.0, 0.0, 1.0, 1.0)
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("fill rgba(255,0,0,0.502)"))
  assert_true(log.contains("fill rgba(255,0,0,0.5)"))
}

///|
test "uniform-radius rect and circle route through the rounded primitive" {
  let recorder = Recorder::new()
  let sketch = Sketch::new(recorder as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.no_stroke()
    p.fill("red")
    p.rect(10.0, 20.0, 40.0, 30.0, tl=8.0, tr=8.0, br=8.0, bl=8.0)
    p.circle(50.0, 50.0, 20.0)
    // Non-uniform corners still need the general path route.
    p.rect(60.0, 60.0, 20.0, 20.0, tl=4.0, tr=8.0, br=4.0, bl=8.0)
  })
  ignore(sketch.frame(0.0))
  let log = recorder.take().join("\n")
  assert_true(log.contains("rrect rgb(255,0,0) 10,20,40,30 r=8"))
  assert_true(log.contains("rrect rgb(255,0,0) 40,40,20,20 r=10"))
  assert_true(log.contains("fill rgb(255,0,0) M"))
}

///|
test "recording surface replays rounded primitives" {
  let surface = Recorder::new()
  let target = Sketch::new(surface as &@p5.Surface, 100.0, 100.0)
  let graphics = target.create_graphics(100, 100)
  graphics.no_stroke()
  graphics.fill("red")
  graphics.circle(30.0, 40.0, 20.0)
  graphics.no_fill()
  graphics.stroke("blue")
  graphics.stroke_weight(2.0)
  graphics.rect(50.0, 50.0, 30.0, 20.0, tl=6.0, tr=6.0, br=6.0, bl=6.0)
  target.image(graphics, 0.0, 0.0)
  let log = surface.take().join("\n")
  assert_true(log.contains("rrect rgb(255,0,0) 20,30,20,20 r=10"))
  assert_true(log.contains("srrect rgb(0,0,255) w=2 50,50,30,20 r=6"))
}
