///|
/// The layout probe: what the app actually *measures*, not what its tree
/// contains.
///
/// The tree assertions in `shell_wbtest.mbt` proved the whole redesign was
/// built — and the app still rendered blank, because every frame below the
/// header had collapsed to zero height. A tree says a view exists; only a
/// layout says it has room.
///
/// The regression this guards: the app root is a `stack` of the themed shell
/// and an overlay host. The shell hands the rest of the window to its
/// weighted body (the stage), which only happens if the shell column keeps
/// the viewport's *minimum* height. A wrapper that relaxes those minimums —
/// a theme modifier, an overlay host — collapses the stage to nothing.
///
/// This is a black-box test (`_test.mbt`): it drives the package's public
/// surface only, and it needs the runtime's layout solver, which the package
/// imports for tests.

///|
/// Every frame in the laid-out tree.
fn collect_frames(
  node : @core.LayoutResult,
  into : Array[@core.Rect],
) -> Unit {
  into.push(node.frame)
  for child in node.children {
    collect_frames(child, into)
  }
}

///|
/// The first frame that satisfies the predicate.
fn find_in(
  frames : Array[@core.Rect],
  predicate : (@core.Rect) -> Bool,
) -> @core.Rect? {
  for frame in frames {
    if predicate(frame) {
      return Some(frame)
    }
  }
  None
}

///|
/// Lay the app out in a viewport and return the frames.
fn laid_out(
  model : @app.WorldModel,
  width : Double,
  height : Double,
) -> Array[@core.Rect] {
  let screen = @app.Screen::for_viewport(width, height)
  let runtime = @runtime.AppRuntime::new_view(
    root=@app.view_for(model, screen),
    size=@core.Size::new(width~, height~),
  )
  let layout = runtime.layout()
  let frames : Array[@core.Rect] = []
  collect_frames(layout, frames)
  frames
}

///|
/// A world with one character, opened through the real parser.
fn probe_world() -> @app.WorldModel {
  let files : Array[(String, String)] = [
    (
      "world.md",
      "# 雨夜酒馆\n\n夜雨敲窗。\n\n## 地点\n\n- 吧台: x=20 y=20 w=240 h=150\n",
    ),
    (
      "characters/林掌柜.md",
      "# 林掌柜\n\n## 人设\n\n掌柜。话不多。\n\n## 开场白\n\n（抬头看了你一眼）……坐吧。\n",
    ),
  ]
  let (model, _effect) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("tavern", true, files),
  )
  model
}

///|
/// A world with a character selected (the stage is showing).
fn probe_talking() -> @app.WorldModel {
  let (model, _effect) = @app.update(probe_world(), @app.Select(Some("林掌柜")))
  model
}

///|
test "the wide layout gives the stage a real height" {
  let frames = laid_out(probe_talking(), 1200.0, 800.0)
  // The stage: the wide reading column. Before the fix its frame was zero
  // tall — the header rendered, everything below it was a zero-height strip.
  // The stage column: ~768 wide *and* tall. Matching the width alone would
  // also catch the stage's own header row, which shares the width but is one
  // line high.
  let stage = find_in(
    frames,
    frame =>
      frame.size.width > 700.0 && frame.size.width < 800.0 &&
      frame.size.height > 400.0,
  )
  match stage {
    Some(frame) => {
      assert_true(frame.size.height > 400.0)
      // The stage sits inside the window: its right edge does not leave it.
      assert_true(frame.max_x() <= 1200.0)
      // And it keeps the width the layout gives it: a child that fills its
      // row (a divider, a full-width surface) used to stretch the stage to
      // the window and push the composer off the edge.
      assert_true(frame.size.width < 800.0)
    }
    None => fail("the wide layout must have a stage column")
  }
  // The rail: ~300 wide, and tall enough for a roster.
  let rail = find_in(
    frames,
    frame =>
      frame.size.width > 280.0 && frame.size.width < 320.0 &&
      frame.size.height > 400.0,
  )
  match rail {
    Some(frame) => assert_true(frame.size.height > 100.0)
    None => fail("the wide layout must have a character rail")
  }
}

///|
test "the app fills the window in every layout" {
  // The regression in one line: whatever the mode, the app measures tall
  // enough to hold a stage instead of collapsing to its header.
  let model = probe_talking()
  let viewports = [
    (1200.0, 800.0),
    (900.0, 700.0),
    (390.0, 844.0),
  ]
  for entry in viewports {
    let (width, height) = entry
    let frames = laid_out(model, width, height)
    let mut tallest = 0.0
    for frame in frames {
      if frame.size.height > tallest {
        tallest = frame.size.height
      }
    }
    assert_true(tallest > height * 0.5)
  }
}

///|
test "the root frame is the viewport" {
  // The shell keeps the window's minimum height, so the stage below the
  // header gets the rest.
  let screen = @app.Screen::for_viewport(1200.0, 800.0)
  let runtime = @runtime.AppRuntime::new_view(
    root=@app.view_for(probe_world(), screen),
    size=@core.Size::new(width=1200.0, height=800.0),
  )
  let layout = runtime.layout()
  assert_eq(layout.frame.size.width, 1200.0)
  assert_eq(layout.frame.size.height, 800.0)
}

///|
test "the composer sits at the bottom of the stage with room" {
  // The composer is the last thing in the stage column: if the column had
  // no height, the input row would be the only thing visible — or nothing.
  let frames = laid_out(probe_talking(), 1200.0, 800.0)
  let composer = find_in(
    frames,
    frame =>
      frame.size.height >= 30.0 && frame.size.height <= 44.0 &&
      frame.max_y() > 700.0,
  )
  assert_true(composer is Some(_))
}

///|
test "the stage's text is queued for painting" {
  // The third layer of the guard: the tree exists, the layout has room, and
  // now the paint plan actually carries the stage's words. A collapsed stage
  // produced *no* text commands at all — the renderer never saw a frame to
  // draw, which is why the window came up blank.
  let screen = @app.Screen::for_viewport(1200.0, 800.0)
  let runtime = @runtime.AppRuntime::new_view(
    root=@app.view_for(probe_talking(), screen),
    size=@core.Size::new(width=1200.0, height=800.0),
  )
  ignore(runtime.layout())
  let commands = runtime.draw_commands()
  // Text inside the stage column (right of the rail, below the header).
  let mut stage_texts = 0
  let mut all_texts = 0
  for command in commands {
    match command {
      DrawText(run) => {
        all_texts += 1
        if run.frame.origin.x > 300.0 && run.frame.origin.y > 60.0 &&
          run.frame.size.height > 0.0 {
          stage_texts += 1
        }
      }
      _ => ()
    }
  }
  assert_true(all_texts > 0)
  assert_true(stage_texts > 0)
}

///|
test "the editor page covers the window and paints an opaque surface" {
  // The editor used to be a transparent overlay: the stage, the rail and the
  // composer showed through the form, and the portrait's transparent pixels
  // mixed with the text under them. Two things have to hold: the page takes
  // the whole viewport, and it paints a surface of its own.
  let screen = @app.Screen::for_viewport(1200.0, 800.0)
  let (model, _effect) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived(
      "tavern",
      true,
      [
        (
          "world.md",
          "# 雨夜酒馆\n\n夜雨敲窗。\n",
        ),
        (
          "characters/林掌柜.md",
          "# 林掌柜\n\n## 人设\n\n掌柜。话不多。\n",
        ),
      ],
    ),
  )
  let (opened, _e2) = @app.update(model, @app.EditCharacter("林掌柜"))
  let runtime = @runtime.AppRuntime::new_view(
    root=@app.view_for(opened, screen),
    size=@core.Size::new(width=1200.0, height=800.0),
  )
  ignore(runtime.layout())
  // The page's frame: the whole viewport.
  let frames : Array[@core.Rect] = []
  collect_frames(runtime.layout(), frames)
  let page = find_in(
    frames,
    frame => frame.size.width > 1100.0 && frame.size.height > 700.0,
  )
  assert_true(page is Some(_))
  // And the paint plan carries a surface that covers it: a filled rectangle
  // (rounded or not) over most of the window. A transparent editor would
  // paint nothing there.
  let mut surface = false
  for command in runtime.draw_commands() {
    match command {
      FillRect(rect, _color) =>
        if rect.size.width > 1100.0 && rect.size.height > 700.0 {
          surface = true
        }
      FillRoundedRect(rounded, _color) =>
        if rounded.rect.size.width > 1100.0 && rounded.rect.size.height > 700.0 {
          surface = true
        }
      FillRoundedRectBrush(rounded, _brush) =>
        if rounded.rect.size.width > 1100.0 && rounded.rect.size.height > 700.0 {
          surface = true
        }
      _ => ()
    }
  }
  assert_true(surface)
}

///|
test "the mood hairline is a hairline" {
  // The scene's accent under the stage header is one pixel. It used to be a
  // container around an empty text — and a text box is at least one line
  // tall, so the line came out as a 44px band of colour.
  let (model, _e) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived(
      "tavern",
      true,
      [
        ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
        ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
      ],
    ),
  )
  let (opened, _e2) = @app.update(model, @app.Select(Some("林掌柜")))
  let screen = @app.Screen::for_viewport(1200.0, 800.0)
  let runtime = @runtime.AppRuntime::new_view(
    root=@app.view_for(opened, screen),
    size=@core.Size::new(width=1200.0, height=800.0),
  )
  ignore(runtime.layout())
  let frames : Array[@core.Rect] = []
  collect_frames(runtime.layout(), frames)
  // A wide, hairline-thin rule under the header.
  let hairline = find_in(
    frames,
    frame => frame.size.width > 600.0 && frame.size.height <= 3.0,
  )
  assert_true(hairline is Some(_))
  // The band of colour *was* the rule: with a fat rule there is no hairline
  // to find, so the assertion above is the whole guard.
}
