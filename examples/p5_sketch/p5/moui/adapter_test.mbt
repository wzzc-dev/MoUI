///|
/// Adapter tests: a sketch becomes ordinary MoUI draw commands.

///|
test "sketch frame becomes MoUI draw commands" {
  let surface = @moui.MoUISurface::new()
  let sketch = @p5.Sketch::new(surface as &@p5.Surface, 120.0, 80.0)
  sketch.setup(p => {
    p.background((12.0, 14.0, 20.0))
    p.fill((240.0, 90.0, 30.0))
    p.no_stroke()
    p.rect(10.0, 10.0, 40.0, 20.0)
    p.text_size(16.0)
    p.text("hello", 12.0, 60.0)
  })
  ignore(sketch.frame(0.0))
  let commands = surface.finish()
  let mut rects = 0
  let mut paths = 0
  let mut texts = 0
  for command in commands {
    match command {
      @core.FillRect(_, _) => rects = rects + 1
      @core.DrawPath(_) => paths = paths + 1
      @core.DrawText(_) => texts = texts + 1
      _ => ()
    }
  }
  assert_eq(rects, 1)
  assert_eq(paths, 1)
  assert_eq(texts, 1)
}

///|
test "transforms become PushTransform commands" {
  let surface = @moui.MoUISurface::new()
  let sketch = @p5.Sketch::new(surface as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    p.translate(10.0, 5.0)
    p.no_stroke()
    p.rect(0.0, 0.0, 4.0, 4.0)
  })
  ignore(sketch.frame(0.0))
  let commands = surface.finish()
  let mut translated = false
  for command in commands {
    match command {
      @core.PushTransform(transform) =>
        if transform.tx == 10.0 && transform.ty == 5.0 {
          translated = true
        }
      _ => ()
    }
  }
  assert_true(translated)
}

///|
test "clip emits a path clip and pop" {
  let surface = @moui.MoUISurface::new()
  let sketch = @p5.Sketch::new(surface as &@p5.Surface, 100.0, 100.0)
  sketch.setup(p => {
    let clip = @p5.Path::new()
    clip.rect_at(0.0, 0.0, 50.0, 50.0)
    p.clip_path_begin(clip)
    p.fill("red")
    p.no_stroke()
    p.rect(10.0, 10.0, 10.0, 10.0)
    p.clip_path_end()
  })
  ignore(sketch.frame(0.0))
  let commands = surface.finish()
  let mut clips = 0
  let mut pops = 0
  let mut rect_clips = 0
  for command in commands {
    match command {
      @core.PushPathClip(spec) => {
        clips = clips + 1
        let bounds = spec.shape_bounds().unwrap()
        inspect(bounds.origin.x, content="0")
        inspect(bounds.origin.y, content="0")
        inspect(bounds.size.width, content="50")
        inspect(bounds.size.height, content="50")
      }
      @core.PopPathClip => pops = pops + 1
      @core.PushClip(_) | @core.PopClip => rect_clips = rect_clips + 1
      _ => ()
    }
  }
  assert_eq(clips, 1)
  assert_eq(pops, 1)
  assert_eq(rect_clips, 0)
}

///|
priv struct InputCounter {
  mut clicked : Int32
  mut double_clicked : Int32
  mut wheel : Double
  mut typed : Int32
  mut touch_started : Int32
  mut touch_ended : Int32
}

///|
test "@moui.SketchView routes pointer input" {
  let view = @moui.SketchView::new(200.0, 120.0)
  let sketch = view.sketch()
  let counter = InputCounter::{
    clicked: 0,
    double_clicked: 0,
    wheel: 0.0,
    typed: 0,
    touch_started: 0,
    touch_ended: 0,
  }
  sketch.on_mouse_clicked(_ => counter.clicked = counter.clicked + 1)
  sketch.on_double_clicked(_ => {
    counter.double_clicked = counter.double_clicked + 1
  })
  sketch.on_mouse_wheel((_, delta) => counter.wheel = delta)
  sketch.on_key_pressed(_ => counter.typed = counter.typed + 1)
  sketch.on_touch_started(_ => counter.touch_started = counter.touch_started + 1)
  sketch.on_touch_ended(_ => counter.touch_ended = counter.touch_ended + 1)
  view.handle_input(@moui.Pointer(@moui.Down, 10.0, 20.0, 0, 0, 0.5))
  assert_true(sketch.mouse_is_pressed)
  assert_eq(sketch.touches.length(), 1)
  inspect(sketch.touches[0].pressure, content="0.5")
  view.handle_input(@moui.Pointer(@moui.Move, 30.0, 40.0, 0, 0, 1.0))
  inspect(sketch.mouse_x, content="30")
  inspect(sketch.mouse_y, content="40")
  view.handle_input(@moui.Pointer(@moui.Up, 30.0, 40.0, 0, 0, 1.0))
  assert_false(sketch.mouse_is_pressed)
  assert_eq(counter.clicked, 0)
  // A short press/release pair becomes a click.
  view.handle_input(@moui.Pointer(@moui.Down, 50.0, 50.0, 0, 0, 1.0))
  view.handle_input(@moui.Pointer(@moui.Up, 52.0, 52.0, 0, 0, 1.0))
  assert_eq(counter.clicked, 1)
  view.handle_input(@moui.Pointer(@moui.Down, 50.0, 50.0, 0, 0, 1.0))
  view.handle_input(@moui.Pointer(@moui.Up, 50.0, 50.0, 0, 0, 1.0))
  assert_eq(counter.clicked, 2)
  assert_eq(counter.double_clicked, 1)
  // Wheel updates the cursor position and forwards the delta.
  view.handle_input(@moui.Wheel(60.0, 60.0, 12.0))
  inspect(sketch.mouse_x, content="60")
  inspect(counter.wheel, content="12")
  // Key events feed p5 key state and the typed callback.
  view.handle_input(@moui.Key("a", "KeyA", true, Some("a")))
  inspect(sketch.code, content="KeyA")
  assert_true(sketch.key_is_pressed)
  inspect(sketch.key_code, content="65")
  assert_eq(counter.typed, 1)
  view.handle_input(@moui.Key("a", "KeyA", false, None))
  assert_false(sketch.key_is_pressed)
  inspect(sketch.code, content="KeyA")
}

///|
test "@moui.SketchView tracks multiple contacts and pressure" {
  let view = @moui.SketchView::new(200.0, 120.0)
  let sketch = view.sketch()
  let counter = InputCounter::{
    clicked: 0,
    double_clicked: 0,
    wheel: 0.0,
    typed: 0,
    touch_started: 0,
    touch_ended: 0,
  }
  sketch.on_touch_started(_ => counter.touch_started = counter.touch_started + 1)
  sketch.on_touch_ended(_ => counter.touch_ended = counter.touch_ended + 1)
  view.handle_input(@moui.Pointer(@moui.Down, 10.0, 20.0, 0, 1, 0.35))
  view.handle_input(@moui.Pointer(@moui.Down, 30.0, 40.0, 0, 2, 1.5))
  assert_eq(sketch.touches.length(), 2)
  inspect(sketch.touches[1].pressure, content="1")
  assert_eq(counter.touch_started, 2)
  // A non-primary stream must not overwrite the mouse position.
  inspect(sketch.mouse_x, content="0")
  view.handle_input(@moui.Pointer(@moui.Move, 12.0, 22.0, 0, 1, 0.6))
  let mut moved_pressure = 0.0
  for touch in sketch.touches {
    if touch.id == 1 {
      moved_pressure = touch.pressure
    }
  }
  inspect(moved_pressure, content="0.6")
  view.handle_input(@moui.Pointer(@moui.Up, 12.0, 22.0, 0, 1, 1.0))
  assert_eq(sketch.touches.length(), 1)
  assert_eq(sketch.touches[0].id, 2)
  assert_eq(counter.touch_ended, 1)
  view.handle_input(@moui.Pointer(@moui.Up, 30.0, 40.0, 0, 2, 1.0))
  assert_eq(sketch.touches.length(), 0)
  assert_eq(counter.touch_ended, 2)
}

///|
test "paused sketches still repaint after input" {
  let view = @moui.SketchView::new(100.0, 100.0)
  let sketch = view.sketch()
  sketch.setup(p => p.background((0.0, 0.0, 0.0)))
  sketch.no_loop()
  assert_true(sketch.frame(0.0))
  assert_false(sketch.frame(16.0))
  assert_eq(sketch.frame_count, 1)
  view.handle_input(@moui.Pointer(@moui.Down, 5.0, 5.0, 0, 0, 1.0))
  view.handle_input(@moui.Pointer(@moui.Up, 5.0, 5.0, 0, 0, 1.0))
  assert_true(sketch.frame(16.0))
  assert_eq(sketch.frame_count, 2)
}

///|
test "@moui.SketchView routes text input and IME composition" {
  let view = @moui.SketchView::new(200.0, 120.0)
  let sketch = view.sketch()
  let events : Array[String] = []
  sketch.on_text_input((_, text) => events.push("input:" + text))
  sketch.on_composition_start(_ => events.push("start"))
  sketch.on_composition_update((_, text) => events.push("update:" + text))
  sketch.on_composition_end((_, text) => events.push("end:" + text))
  view.handle_input(@moui.TextInput(@core.TextInputEvent::InsertText("a")))
  inspect(sketch.last_input_text, content="a")
  view.handle_input(@moui.TextInput(@core.TextInputEvent::CompositionStart))
  assert_true(sketch.composing)
  view.handle_input(
    @moui.TextInput(
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(text="に"),
      ),
    ),
  )
  inspect(sketch.composition_text, content="に")
  view.handle_input(
    @moui.TextInput(@core.TextInputEvent::CompositionEnd("日本")),
  )
  assert_false(sketch.composing)
  inspect(sketch.last_input_text, content="日本")
  assert_eq(events, ["input:a", "start", "update:に", "end:日本"])
}

///|
test "image buffer becomes a DrawImage PNG data URI" {
  let surface = @moui.MoUISurface::new()
  let sketch = @p5.Sketch::new(surface as &@p5.Surface, 20.0, 20.0)
  sketch.setup(p => {
    let image = p.create_image(2, 2)
    image.set(0, 0, @p5.Color::rgb(255.0, 0.0, 0.0))
    image.set(1, 0, @p5.Color::rgb(0.0, 255.0, 0.0))
    p.image(image, 4.0, 5.0, width=8.0, height=8.0)
  })
  ignore(sketch.frame(0.0))
  let commands = surface.finish()
  let mut source = ""
  let mut frame = @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)
  for command in commands {
    match command {
      @core.DrawImage(run) => {
        source = run.source
        frame = run.frame
      }
      _ => ()
    }
  }
  assert_true(source.has_prefix("data:image/png;base64,"))
  let payload = source.split(",").to_array()[1].to_owned()
  let png = try! @base64.decode(payload, ignore_whitespace=true)
  assert_true(png.length() > 8)
  inspect(png[0].to_uint(), content="137")
  inspect(png[1].to_uint(), content="80")
  inspect(png[2].to_uint(), content="78")
  inspect(png[3].to_uint(), content="71")
  inspect(frame.origin.x, content="4")
  inspect(frame.origin.y, content="5")
  inspect(frame.size.width, content="8")
  inspect(frame.size.height, content="8")
}

///|
fn count_draw_paths(commands : Array[@core.DrawCommand]) -> Int32 {
  let mut count = 0
  for command in commands {
    if command is @core.DrawPath(_) {
      count = count + 1
    }
  }
  count
}

///|
test "retained canvas accumulates commands until an opaque background" {
  let view = @moui.SketchView::new(100.0, 100.0)
  let sketch = view.sketch()
  sketch.draw(p => {
    p.no_stroke()
    p.fill("red")
    p.rect(0.0, 0.0, 10.0, 10.0)
  })
  let first = view.render_commands(0.0)
  assert_eq(count_draw_paths(first), 1)
  let second = view.render_commands(16.0)
  assert_eq(count_draw_paths(second), 2)
  // An opaque background starts a new canvas epoch; history drops.
  sketch.background(@p5.Color::rgb(0.0, 0.0, 0.0))
  let third = view.render_commands(32.0)
  assert_eq(count_draw_paths(third), 1)
}

///|
test "stateless canvas replaces commands every frame" {
  let view = @moui.SketchView::new_stateless(100.0, 100.0)
  let sketch = view.sketch()
  sketch.draw(p => {
    p.no_stroke()
    p.fill("red")
    p.rect(0.0, 0.0, 10.0, 10.0)
  })
  assert_eq(count_draw_paths(view.render_commands(0.0)), 1)
  assert_eq(count_draw_paths(view.render_commands(16.0)), 1)
}

///|
fn solid_image(width : Int32, height : Int32) -> @p5.Image {
  let image = @p5.Image::new(width, height)
  image.fill(@p5.Color::rgb(255.0, 0.0, 0.0))
  image
}

///|
test "SketchView captures painted commands through a host rasterizer" {
  let view = @moui.SketchView::new(8.0, 6.0)
  let sketch = view.sketch()
  sketch.draw(p => {
    p.background((0.0, 0.0, 0.0))
    p.no_stroke()
    p.fill("red")
    p.rect(0.0, 0.0, 4.0, 4.0)
  })
  let captured_commands : Ref[Int32] = Ref(0)
  let captured_width : Ref[Double] = Ref(0.0)
  let captured_height : Ref[Double] = Ref(0.0)
  view.set_rasterizer((commands, metrics) => {
    captured_commands.val = commands.length()
    captured_width.val = metrics.logical_size().width
    captured_height.val = metrics.logical_size().height
    Some(solid_image(2, 2))
  })
  let painted = view.render_commands(0.0)
  let image = view.capture_image().unwrap()
  assert_eq(captured_commands.val, painted.length())
  inspect(captured_width.val, content="8")
  inspect(captured_height.val, content="6")
  inspect(image.width(), content="2")
  inspect(image.get(0, 0).r, content="1")
}

///|
test "SketchView load/set/update pixels appends a DrawImage overlay" {
  let view = @moui.SketchView::new(2.0, 2.0)
  let sketch = view.sketch()
  sketch.draw(p => {
    p.background((0.0, 0.0, 0.0))
    p.no_stroke()
    p.fill("red")
    p.rect(0.0, 0.0, 1.0, 1.0)
  })
  view.set_rasterizer((_commands, _metrics) => Some(solid_image(2, 2)))
  ignore(view.render_commands(0.0))
  let buffer = view.load_pixels().unwrap()
  inspect(buffer.width(), content="2")
  inspect(buffer.get(0, 0).r, content="1")
  assert_true(view.set_pixel(0, 0, @p5.Color::rgb(0.0, 0.0, 255.0)))
  let edited = view.get_pixel(0, 0)
  inspect(edited.r, content="0")
  inspect(edited.b, content="1")
  assert_true(view.update_pixels())
  let commands = view.render_commands(16.0)
  let mut overlay : @p5.Image? = None
  let mut source_layers = 0
  for command in commands {
    match command {
      @core.PushLayer(spec) =>
        if spec.blend_mode is @core.BlendMode::Source {
          source_layers = source_layers + 1
        }
      _ => ()
    }
  }
  // The overlay commits through a Source layer: exact replace, erasable.
  assert_eq(source_layers, 1)
  for command in commands {
    match command {
      @core.DrawImage(run) => {
        let payload = run.source.split(",").to_array()[1].to_owned()
        let png = try! @base64.decode(payload, ignore_whitespace=true)
        overlay = @p5.Image::from_png_bytes(png)
      }
      _ => ()
    }
  }
  let image = overlay.unwrap()
  inspect(image.width(), content="2")
  let changed = image.get(0, 0)
  inspect(changed.r, content="0")
  inspect(changed.b, content="1")
  let untouched = image.get(1, 0)
  inspect(untouched.r, content="1")
  view.clear_pixel_overlay()
  let after = view.render_commands(32.0)
  let mut still_overlay = false
  for command in after {
    if command is @core.DrawImage(_) {
      still_overlay = true
    }
  }
  assert_false(still_overlay)
}

///|
test "p5 stroke cap and join reach the DrawPath spec" {
  let surface = @moui.MoUISurface::new()
  let sketch = @p5.Sketch::new(surface as &@p5.Surface, 20.0, 20.0)
  sketch.setup(p => {
    p.stroke_cap(@p5.Project)
    p.stroke_join(@p5.Bevel)
    p.line(1.0, 2.0, 10.0, 12.0)
  })
  ignore(sketch.frame(0.0))
  let commands = surface.finish()
  let mut found = false
  for command in commands {
    match command {
      @core.DrawPath(spec) => {
        assert_eq(spec.stroke_cap, Some(@core.Square))
        assert_eq(spec.stroke_join, Some(@core.Bevel))
        found = true
      }
      _ => ()
    }
  }
  assert_true(found)
}

///|
test "p5 text stroke reaches the TextRun" {
  let surface = @moui.MoUISurface::new()
  let sketch = @p5.Sketch::new(surface as &@p5.Surface, 60.0, 30.0)
  sketch.setup(p => {
    p.fill((255.0, 0.0, 0.0))
    p.stroke((0.0, 0.0, 255.0))
    p.stroke_weight(2.0)
    p.text_size(12.0)
    p.text("Hi", 10.0, 20.0)
  })
  ignore(sketch.frame(0.0))
  let commands = surface.finish()
  let mut found = false
  for command in commands {
    match command {
      @core.DrawText(run) => {
        assert_true(run.stroke_color is Some(_))
        inspect(run.stroke_width, content="2")
        found = true
      }
      _ => ()
    }
  }
  assert_true(found)
}

///|
test "p5 advanced blend modes reach the layer spec" {
  let surface = @moui.MoUISurface::new()
  let sketch = @p5.Sketch::new(surface as &@p5.Surface, 20.0, 20.0)
  sketch.setup(p => {
    p.blend_mode(@p5.Difference)
    p.no_stroke()
    p.fill("red")
    p.rect(0.0, 0.0, 10.0, 10.0)
  })
  ignore(sketch.frame(0.0))
  let surface2 = @moui.MoUISurface::new()
  let sketch2 = @p5.Sketch::new(surface2 as &@p5.Surface, 20.0, 20.0)
  sketch2.setup(p => {
    p.blend_mode(@p5.Dodge)
    p.no_stroke()
    p.fill("red")
    p.rect(0.0, 0.0, 10.0, 10.0)
  })
  ignore(sketch2.frame(0.0))
  let mut difference = false
  for command in surface.finish() {
    match command {
      @core.PushLayer(spec) =>
        if spec.blend_mode is @core.BlendMode::Difference {
          difference = true
        }
      _ => ()
    }
  }
  let mut dodge = false
  for command in surface2.finish() {
    match command {
      @core.PushLayer(spec) =>
        if spec.blend_mode is @core.BlendMode::ColorDodge {
          dodge = true
        }
      _ => ()
    }
  }
  assert_true(difference)
  assert_true(dodge)
}
