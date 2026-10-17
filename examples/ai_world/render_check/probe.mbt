///|
/// Render probe: build the real view tree through `AppRuntime` and inspect
/// the emitted draw commands for the scenario map. Pins canvas-space bugs to
/// either the view's commands or the renderer's application of them: the
/// canvas draw callback paints in canvas-global coordinates, so the floor and
/// every marker must land at (view-x + map-x, view-y + map-y).

///|
fn robot_world() -> @app.WorldModel {
  let json =
    #|{ "id": "probe", "name": "探针世界", "background": "b",
    #|  "map_width": 640, "map_height": 420,
    #|  "locations": [
    #|    { "id": "shop", "name": "当铺", "description": "",
    #|      "rect": { "origin": {"x": 400.0, "y": 250.0}, "size": {"width": 180.0, "height": 120.0} } }
    #|  ],
    #|  "characters": [
    #|    { "id": "zhou", "name": "周跛子", "persona": "x", "point": {"x": 490.0, "y": 310.0} }
    #|  ],
    #|  "world_book": [] }
  let (model, _effect) = @app.update(
    @app.WorldModel::new(),
    @app.ImportScenario(json),
  )
  model
}

///|
fn draw_commands() -> Array[@core.DrawCommand] {
  let runtime = @runtime.new_view(
    root=@app.view(robot_world()),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  runtime.draw_commands()
}

///|
test "location and character land at clip origin plus map coordinates" {
  {
    let runtime = @runtime.new_view(
      root=@app.view(robot_world()),
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
      root=@app.view(robot_world()),
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
    root=@app.view(robot_world()),
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
    root=@app.view(robot_world()),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let mut map_height = 0.0
  let mut composer_bottom_tall = 0.0
  for command in tall.draw_commands() {
    match command {
      @core.PushClip(rect) =>
        // The FIRST wide clip right of the rail is the map; the composer clip
        // shares the width but sits lower.
        if rect.origin.x > 300.0 &&
          rect.size.width >= 500.0 &&
          map_height == 0.0 {
          map_height = rect.size.height
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
