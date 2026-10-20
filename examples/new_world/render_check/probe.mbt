///|
/// Render probe: build the real view tree through `AppRuntime` and inspect
/// the emitted draw commands for the scenario map. Pins canvas-space bugs to
/// either the view's commands or the renderer's application of them: the
/// canvas draw callback paints in canvas-global coordinates, so the floor and
/// every marker must land at (view-x + map-x, view-y + map-y).

///|
/// Build a probe world through the same folder path the product uses. The
/// Markdown fixture keeps the probe honest: it exercises the real codec
/// (`world.md` + a character card) rather than a test-only JSON import.
fn robot_world() -> @app.WorldModel {
  let files : Array[(String, String)] = [
    (
      "world.md", "# 探针世界\n\nb\n\n## 地点\n\n- 当铺: x=400 y=250 w=180 h=120\n",
    ),
    (
      "characters/周跛子.md", "# 周跛子\n\n## 人设\n\nx\n\n## 位置\n\nx=490 y=310\n",
    ),
  ]
  let (model, _effect) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("probe", true, files),
  )
  model
}

///|
fn draw_commands() -> Array[@core.DrawCommand] {
  let runtime = @runtime.new_view(
    root=@app.view_for(robot_world(), @app.Screen::for_viewport(1560.0, 1080.0)),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  runtime.draw_commands()
}

///|
test "location and character land at clip origin plus map coordinates" {
  {
    let runtime = @runtime.new_view(
      root=@app.view_for(
        robot_world(),
        @app.Screen::for_viewport(1560.0, 1080.0),
      ),
      size=@core.Size::new(width=1560.0, height=1080.0),
    )
    for command in runtime.draw_commands() {
      match command {
        @core.PushClip(rect) =>
          println(
            "clip: \{rect.origin.x},\{rect.origin.y} \{rect.size.width}x\{rect.size.height}",
          )
        _ => ()
      }
    }
  }
  let commands = draw_commands()
  let mut clip : @core.Rect? = None
  let mut shop : @core.Rect? = None
  let mut plate : @core.Rect? = None
  for command in commands {
    match command {
      @core.PushClip(rect) =>
        if rect.origin.x > 300.0 &&
          rect.origin.y > 100.0 &&
          rect.size.width >= 500.0 &&
          rect.size.height >= 100.0 {
          clip = Some(rect)
        }
      @core.DrawText(run) =>
        if run.text == "当铺" {
          shop = Some(run.frame)
        } else if run.text == "周跛子" {
          // The roster chip also carries the name; the map plate comes later
          // (the map draws after the roster in view order), so the last one
          // wins.
          plate = Some(run.frame)
        }
      _ => ()
    }
  }
  let viewport = match clip {
    Some(rect) => rect
    None => {
      for command in commands {
        match command {
          @core.PushClip(rect) =>
            println(
              "clip?: \{rect.origin.x},\{rect.origin.y} \{rect.size.width}x\{rect.size.height}",
            )
          _ => ()
        }
      }
      abort("no map clip")
    }
  }
  let label = match shop {
    Some(run) => run
    None => abort("no 当铺 text")
  }
  // 当铺 sits at map (400,250), +8,+8 inside its 180x120 block.
  inspect(label.origin.x - viewport.origin.x, content="408")
  inspect(label.origin.y - viewport.origin.y, content="258")
  // The map plate (the LAST 周跛子 text) is centred under the marker at map
  // (490,310): left edge = map-x + 490 - 60; top = map-y + 310 + 11 + 2.
  let mark = match plate {
    Some(run) => run
    None => abort("no 周跛子 text")
  }
  inspect(mark.origin.x - viewport.origin.x, content="430")
  inspect(mark.origin.y - viewport.origin.y, content="323")
}

///|
test "the real main view keeps the composer visible in a short window" {
  {
    let runtime = @runtime.new_view(
      root=@app.view_for(robot_world(), @app.Screen::for_viewport(780.0, 780.0)),
      size=@core.Size::new(width=780.0, height=780.0),
    )
    for command in runtime.draw_commands() {
      match command {
        @core.DrawText(run) =>
          if run.text == "（先选择一个角色）" {
            println(
              "composer at y=\{run.frame.origin.y} h=\{run.frame.size.height}",
            )
          }
        _ => ()
      }
    }
  }
  // 780px window: map and transcript flex-shrink; the composer stays inside.
  let short = @runtime.new_view(
    root=@app.view_for(robot_world(), @app.Screen::for_viewport(1400.0, 780.0)),
    size=@core.Size::new(width=1400.0, height=780.0),
  )
  let mut composer_bottom = 0.0
  for command in short.draw_commands() {
    match command {
      @core.DrawText(run) =>
        if run.text == "（先选择一个角色）" {
          composer_bottom = run.frame.origin.y + run.frame.size.height
        }
      _ => ()
    }
  }
  assert_true(composer_bottom > 0.0)
  assert_true(composer_bottom <= 780.0)
  // Tall window: nothing clipped either, and the map gets real height.
  let tall = @runtime.new_view(
    root=@app.view_for(robot_world(), @app.Screen::for_viewport(1560.0, 1080.0)),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let mut map_height = 0.0
  let mut composer_bottom_tall = 0.0
  for command in tall.draw_commands() {
    match command {
      // The map paints its own dark backdrop over its frame; the canvas does not
      // push a clip, so the backdrop rect is how the probe measures the map.
      // Both fill variants count: a solid color and a brush are the same rect.
      @core.FillRoundedRect(rounded, color) =>
        if map_height == 0.0 &&
          color.r < 0.10 &&
          rounded.rect.size.width >= 500.0 &&
          rounded.rect.origin.x > 300.0 {
          map_height = rounded.rect.size.height
        }
      @core.FillRoundedRectBrush(rounded, _brush) =>
        if map_height == 0.0 &&
          rounded.rect.size.width >= 500.0 &&
          rounded.rect.origin.x > 300.0 &&
          rounded.rect.size.height > 200.0 {
          map_height = rounded.rect.size.height
        }
      @core.DrawText(run) =>
        if run.text == "（先选择一个角色）" {
          composer_bottom_tall = run.frame.origin.y + run.frame.size.height
        }
      _ => ()
    }
  }
  assert_true(composer_bottom_tall <= 1080.0 && composer_bottom_tall > 0.0)
  assert_true(map_height >= 200.0)
}
