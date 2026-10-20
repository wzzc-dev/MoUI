///|
/// Measure every panel's clip rect and the text that falls outside it.
///
/// Round 22 found the transcript defect by reading `PushClip` rects instead of
/// guessing. This probe applies the same instrument to the rest of the shell: a
/// control that renders outside its clip is invisible to the player even though
/// the view is "correct", and nothing else in the suite would notice.

///|
fn probe_world() -> @app.WorldModel {
  let files : Array[(String, String)] = [
    (
      "world.md", "# 探针世界\n\n背景一句。\n\n## 地点\n\n- 吧台: x=20 y=20 w=240 h=150\n",
    ),
    (
      "characters/甲.md", "# 甲\n\n## 人设\n\n甲的设定。\n\n## 位置\n\nx=100 y=90\n",
    ),
    (
      "characters/乙.md", "# 乙\n\n## 人设\n\n乙的设定。\n\n## 位置\n\nx=160 y=110\n",
    ),
    ("world_book.md", "# 世界书\n\n- 酒: 老酒。\n"),
  ]
  let (model, _e) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("probe", true, files),
  )
  let (selected, _s) = @app.update(model, @app.Select(Some("甲")))
  let (sent, _x) = @app.update(selected, @app.Send("你好"))
  sent
}

///|
test "the clip detector actually rejects an escaping run" {
  // The assertion above only means something if the geometry test itself works.
  // Pin it on a synthetic pair: a run inside a rect passes, one below it fails.
  let rect = @core.Rect::new(x=0.0, y=0.0, width=100.0, height=50.0)
  let inside = @core.Rect::new(x=10.0, y=10.0, width=20.0, height=10.0)
  let outside = @core.Rect::new(x=10.0, y=60.0, width=20.0, height=10.0)
  let fits = (frame : @core.Rect) => {
    let right = rect.origin.x + rect.size.width
    let bottom = rect.origin.y + rect.size.height
    frame.origin.x >= rect.origin.x - 1.0 &&
    frame.origin.y >= rect.origin.y - 1.0 &&
    frame.origin.x < right &&
    frame.origin.y < bottom
  }
  assert_true(fits(inside))
  assert_false(fits(outside))
}

///|
test "no text paints outside the clip that contains its column" {
  let runtime = @runtime.new_view(
    root=@app.view_for(probe_world(), @app.Screen::for_viewport(1560.0, 1080.0)),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let commands = runtime.draw_commands()
  // Collect the clip stack per draw command: a text run is only visible if it
  // is inside every clip that was active when it was emitted.
  let clips : Array[@core.Rect] = []
  let escaped : Array[String] = []
  let mut total = 0
  for command in commands {
    match command {
      @core.PushClip(rect) => clips.push(rect)
      @core.PopClip => ignore(clips.pop())
      @core.DrawText(run) => {
        total = total + 1
        let inside = clips.all(rect => {
          let right = rect.origin.x + rect.size.width
          let bottom = rect.origin.y + rect.size.height
          run.frame.origin.x >= rect.origin.x - 1.0 &&
          run.frame.origin.y >= rect.origin.y - 1.0 &&
          run.frame.origin.x < right &&
          run.frame.origin.y < bottom
        })
        if !inside {
          escaped.push(run.text[:16].to_owned())
        }
      }
      _ => ()
    }
  }
  // A run painted outside every active clip is invisible even though the view
  // tree is "correct"; nothing else in the suite would catch that.
  assert_true(escaped.is_empty())
  assert_true(total > 20)
}

///|
test "an absurdly long reply scrolls rather than breaking the layout" {
  // A model that ignores the length hint, or a player pasting a wall of text,
  // must not break the stage. Scrolling the oldest content *above* the clip is
  // correct for a tall message, so the assertion is that every row still sits in
  // the column it belongs to (the stage's horizontal band), and the composer
  // survives.
  let files : Array[(String, String)] = [
    ("world.md", "# 长文本世界\n\nb\n"),
    ("characters/甲.md", "# 甲\n\n## 人设\n\nx\n"),
  ]
  let (model, _e) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("probe", true, files),
  )
  let (selected, _s) = @app.update(model, @app.Select(Some("甲")))
  let (asked, _a) = @app.update(selected, @app.Send("嗨"))
  let long = "很长的回答。".repeat(400)
  let (replied, _r) = @app.update(asked, @app.Reply("甲", Some(long)))
  let runtime = @runtime.new_view(
    root=@app.view_for(replied, @app.Screen::for_viewport(1560.0, 1080.0)),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let commands = runtime.draw_commands()
  // The stage column: the clip that is exactly the stage width.
  let mut stage = None
  for command in commands {
    match command {
      @core.PushClip(rect) =>
        if rect.size.width >= 500.0 && rect.size.width <= 540.0 {
          stage = Some(rect)
        }
      _ => ()
    }
  }
  let stage_rect = match stage {
    Some(value) => value
    None => fail("the stage column clip must exist")
  }
  let mut runs = 0
  let mut in_stage_rows = 0
  let mut overflow_right = 0
  for command in commands {
    match command {
      @core.DrawText(run) => {
        runs = runs + 1
        // Rows that belong to the transcript start inside the stage column.
        if run.frame.origin.x >= stage_rect.origin.x - 1.0 &&
          run.frame.origin.x <= stage_rect.origin.x + stage_rect.size.width {
          in_stage_rows = in_stage_rows + 1
          let right = run.frame.origin.x + run.frame.size.width
          if right > stage_rect.origin.x + stage_rect.size.width + 1.0 {
            overflow_right = overflow_right + 1
          }
        }
      }
      _ => ()
    }
  }
  // Non-vacuous: the long reply must have produced real draw commands, and the
  // stage must contain a meaningful number of them.
  assert_true(runs > 20)
  assert_true(in_stage_rows > 10)
  // A wrapped paragraph must never spill horizontally out of its column.
  assert_eq(overflow_right, 0)
  // And the composer is still on stage, so the player can keep typing: the
  // 说【 label opens the first composer field.
  let mut saw_composer = false
  for command in commands {
    match command {
      @core.DrawText(run) =>
        if run.text.contains("说【") {
          saw_composer = true
        }
      _ => ()
    }
  }
  assert_true(saw_composer)
}

///|
test "the lore hint reaches the screen, not just the model" {
  // "世界书命中在 UI 可见" is an acceptance item. Testing `lore_summary` alone
  // proves the string is built, not that it is painted — and a hint that never
  // renders is indistinguishable from no hint at all.
  let files : Array[(String, String)] = [
    ("world.md", "# 探针世界\n\nb\n"),
    ("characters/甲.md", "# 甲\n\n## 人设\n\nx\n"),
    (
      "world_book.md", "# 世界书\n\n- 酒 | 花雕 [priority=8]: 只温不冰。\n",
    ),
  ]
  let (model, _e) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("probe", true, files),
  )
  let (selected, _s) = @app.update(model, @app.Select(Some("甲")))
  // The hint describes the draft, so it needs text that matches the lore key.
  let (typing, _t) = @app.update(selected, @app.SayDraftChanged("温一壶酒"))
  let (asked, _a) = @app.update(typing, @app.Send("温一壶酒"))
  let runtime = @runtime.new_view(
    root=@app.view_for(asked, @app.Screen::for_viewport(1560.0, 1080.0)),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let mut saw_hint = false
  let mut saw_key = false
  for command in runtime.draw_commands() {
    match command {
      @core.DrawText(run) => {
        if run.text.contains("本轮注入世界书") {
          saw_hint = true
        }
        if run.text.contains("酒/花雕") {
          saw_key = true
        }
      }
      _ => ()
    }
  }
  assert_true(saw_hint)
  assert_true(saw_key)
}
