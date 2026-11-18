///|
test "SketchView captures through the installed Skia rasterizer" {
  install()
  let view = @p5m.SketchView::new(4.0, 2.0)
  let sketch = view.sketch()
  sketch.draw(p => {
    p.background((0.0, 0.0, 0.0))
    p.no_stroke()
    p.fill("red")
    p.rect(0.0, 0.0, 2.0, 2.0)
  })
  ignore(view.render_commands(0.0))
  let image = view.capture_image().unwrap()
  inspect(image.width(), content="4")
  inspect(image.height(), content="2")
  let left = image.get(0, 0)
  inspect(left.r, content="1")
  inspect(left.g, content="0")
  let right = image.get(3, 1)
  inspect(right.r, content="0")
  inspect(right.g, content="0")
}

///|
test "SketchView save_canvas writes a PNG that load_image can read" {
  install()
  let view = @p5m.SketchView::new(4.0, 2.0)
  let sketch = view.sketch()
  sketch.draw(p => {
    p.background((0.0, 0.0, 0.0))
    p.no_stroke()
    p.fill("red")
    p.rect(0.0, 0.0, 2.0, 2.0)
  })
  ignore(view.render_commands(0.0))
  let candidates = [
    "/tmp/moui_p5_save_canvas.png", "C:/Temp/moui_p5_save_canvas.png", "moui_p5_save_canvas.png",
  ]
  let mut saved = ""
  for path in candidates {
    if view.save_canvas(path) {
      saved = path
      break
    }
  }
  assert_true(saved != "")
  let loaded = sketch.try_load_image(saved).unwrap()
  inspect(loaded.width(), content="4")
  inspect(loaded.height(), content="2")
  let left = loaded.get(0, 0)
  inspect(left.r, content="1")
  inspect(left.g, content="0")
  let right = loaded.get(3, 1)
  inspect(right.r, content="0")
}

///|
test "skia canvas rasterizer reads back opaque and translucent pixels" {
  let commands : Array[@core.DrawCommand] = [
    @core.Clear(@core.Color::rgba(r=1.0, g=1.0, b=1.0)),
    @core.FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=2.0, height=2.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
    @core.FillRect(
      @core.Rect::new(x=2.0, y=0.0, width=2.0, height=2.0),
      @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=0.5),
    ),
  ]
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=4.0, height=2.0),
    scale_factor=1.0,
  )
  let image = rasterize(commands, metrics).unwrap()
  inspect(image.width(), content="4")
  inspect(image.height(), content="2")
  let red = image.get(0, 0)
  inspect(red.r, content="1")
  inspect(red.g, content="0")
  inspect(red.a, content="1")
  // The translucent blue rect blends over white (Skia returns premultiplied
  // pixels; the rasterizer must unpremultiply before handing them to p5).
  let blended = image.get(2, 0)
  inspect((blended.r * 255.0).to_int(), content="127")
  inspect((blended.g * 255.0).to_int(), content="127")
  inspect((blended.b * 255.0).to_int(), content="255")
  inspect((blended.a * 255.0).to_int(), content="255")
}
