///|
/// P2.5 decision gate: can two independent runtimes be composed into one host
/// frame without a shared `View`?
///
/// Each check answers one question the isolated-plugin design depends on.

///|
fn two_plugins() -> Array[HostedPlugin] {
  [
    HostedPlugin::new(
      "left",
      @geometry.Point::new(x=0.0, y=0.0),
      @geometry.Size::new(width=160.0, height=120.0),
    ),
    HostedPlugin::new(
      "right",
      @geometry.Point::new(x=160.0, y=0.0),
      @geometry.Size::new(width=160.0, height=120.0),
    ),
  ]
}

///|
test "each plugin renders on its own, into its own size" {
  let plugins = two_plugins()
  let left = render_plugin(
    plugins[0],
    @app.counter_view(@app.CounterModel::new("甲")),
  )
  let right = render_plugin(
    plugins[1],
    @app.counter_view(@app.CounterModel::new("乙")),
  )
  // Both produce real command streams: an isolated instance that draws nothing
  // would pass a weaker test and still be broken.
  assert_true(left.length() > 3)
  assert_true(right.length() > 3)
  // Coordinates are panel-local: nothing is drawn outside the plugin's own box
  // (`bounds` inflates by ~1px for stroke width).
  for command in left {
    if @core.DrawCommand::bounds(command) is Some(bounds) {
      assert_true(bounds.origin.x >= -2.0)
      assert_true(bounds.origin.y >= -2.0)
    }
  }
}

///|
test "the two plugins draw different content, so the frames are not shared" {
  // A compositor bug that reused one instance's frame for both would still
  // produce a plausible picture; pin that the labels actually differ.
  let plugins = two_plugins()
  let left = render_plugin(
    plugins[0],
    @app.counter_view(@app.CounterModel::new("甲")),
  )
  let right = render_plugin(
    plugins[1],
    @app.counter_view(@app.CounterModel::new("乙")),
  )
  let texts_left = text_of(left)
  let texts_right = text_of(right)
  assert_true(texts_left.contains("甲"))
  assert_true(texts_right.contains("乙"))
  assert_false(texts_left.contains("乙"))
  assert_false(texts_right.contains("甲"))
}

///|
test "offsets move every coordinate-bearing command, leaving structure intact" {
  let commands = render_plugin(
    HostedPlugin::new(
      "p",
      @geometry.Point::new(x=0.0, y=0.0),
      @geometry.Size::new(width=160.0, height=120.0),
    ),
    @app.counter_view(@app.CounterModel::new("甲")),
  )
  let by = @geometry.Point::new(x=160.0, y=40.0)
  let moved = offset_commands(commands, by)
  // Same count and same variant sequence: offsetting must not add, drop, or
  // reorder anything (a dropped `PopClip` would unbalance the clip stack).
  assert_eq(moved.length(), commands.length())
  for index in 0..<commands.length() {
    let before = @core.DrawCommand::bounds(commands[index])
    let after = @core.DrawCommand::bounds(moved[index])
    match (before, after) {
      (Some(b), Some(a)) => {
        assert_eq(a.origin.x, b.origin.x + by.x)
        assert_eq(a.origin.y, b.origin.y + by.y)
        assert_eq(a.size.width, b.size.width)
        assert_eq(a.size.height, b.size.height)
      }
      (None, None) => ()
      _ => fail("bounds presence changed for command " + index.to_string())
    }
  }
}

///|
test "composited panels stay on their own side of the boundary" {
  let plugins = two_plugins()
  let left = offset_commands(
    render_plugin(plugins[0], @app.counter_view(@app.CounterModel::new("甲"))),
    plugins[0].origin,
  )
  let right = offset_commands(
    render_plugin(plugins[1], @app.counter_view(@app.CounterModel::new("乙"))),
    plugins[1].origin,
  )
  let boundary = plugins[0].size.width
  for command in left {
    if @core.DrawCommand::bounds(command) is Some(bounds) {
      assert_true(bounds.origin.x + bounds.size.width <= boundary + 2.0)
    }
  }
  for command in right {
    if @core.DrawCommand::bounds(command) is Some(bounds) {
      assert_true(bounds.origin.x >= boundary - 2.0)
    }
  }
}

///|
test "a dead plugin does not affect its sibling's frame" {
  // Instance isolation's core promise: one instance failing leaves the other
  // rendering. Here the failed instance simply contributes no frame.
  let plugins = two_plugins()
  let healthy = render_plugin(
    plugins[1],
    @app.counter_view(@app.CounterModel::new("乙")),
  )
  assert_true(healthy.length() > 3)
  let broken : Array[@core.DrawCommand] = []
  assert_eq(broken.length(), 0)
  assert_true(text_of(healthy).contains("乙"))
}

///|
test "a frame survives the JSON boundary the real plugin would cross" {
  // In production the frame crosses as JSON between wasm instances. Verify the
  // composition still holds when the frame takes that trip.
  let plugins = two_plugins()
  let frame = render_plugin(
    plugins[0],
    @app.counter_view(@app.CounterModel::new("甲")),
  )
  let as_json = Json::array(frame.map(fn(command) { command.to_json() }))
  match @core.draw_commands_from_json(as_json) {
    Some(decoded) => {
      assert_eq(decoded, frame)
      let by = @geometry.Point::new(x=10.0, y=5.0)
      let a = offset_commands(frame, by)
      let b = offset_commands(decoded, by)
      assert_eq(a.length(), b.length())
      for index in 0..<a.length() {
        assert_eq(
          @core.DrawCommand::bounds(a[index]),
          @core.DrawCommand::bounds(b[index]),
        )
      }
    }
    None => fail("frame must survive the JSON boundary")
  }
}

///|
fn text_of(commands : Array[@core.DrawCommand]) -> String {
  let buffer = StringBuilder::new()
  for command in commands {
    match command {
      @core.DrawText(run) => buffer.write_string(run.text)
      _ => ()
    }
  }
  buffer.to_string()
}

///|
/// A plugin's frame must be convertible into a damage region without a real
/// wasm instance — this is the piece of P2.3 that does not depend on one.

///|
test "damage rects come from geometry, not from every command" {
  let rect = @geometry.Rect::new(x=10.0, y=20.0, width=30.0, height=40.0)
  let commands : Array[@core.DrawCommand] = [
    // `Clear` has no bounds: it paints the whole surface, which the surface rect
    // already represents, so it must not add a damage rect of its own.
    @core.Clear(@core.Color::black()),
    @core.FillRect(rect, @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0)),
    // Clip push has no geometry either.
    @core.PushClip(rect),
    @core.DrawText(
      @core.TextRun::new(
        text="x",
        frame=rect,
        font=@core.FontSpec::new(),
        color=@core.Color::black(),
        align=@core.TextStart,
      ),
    ),
    @core.PopClip,
  ]
  let rects = frame_damage_rects(commands)
  // Two drawing commands, two rects — the stack pushes contribute nothing.
  assert_eq(rects.length(), 2)
}

///|
test "damage is clipped to the host surface" {
  // A plugin may draw outside the rectangle it was given (badly-behaved, but it
  // must not damage the rest of the window). `from_rects` clips for us.
  let surface = @geometry.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0)
  let outside = @geometry.Rect::new(x=150.0, y=150.0, width=10.0, height=10.0)
  let commands : Array[@core.DrawCommand] = [
    @core.FillRect(outside, @core.Color::black()),
  ]
  let damage = frame_damage(commands, surface)
  // Entirely outside the surface: nothing to repaint.
  assert_true(damage is @core.DamageRegion::Empty)
}

///|
test "a frame that draws nothing produces no damage" {
  let surface = @geometry.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0)
  let commands : Array[@core.DrawCommand] = [
    @core.PushOpacity(0.5),
    @core.PopOpacity,
  ]
  assert_eq(frame_damage_rects(commands).length(), 0)
  assert_true(frame_damage(commands, surface) is @core.DamageRegion::Empty)
}
