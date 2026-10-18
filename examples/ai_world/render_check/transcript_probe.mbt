///|
/// Layout probe for the conversation transcript.
///
/// Round 21 recorded an unresolved defect: with a multi-paragraph Markdown reply
/// the newest paragraphs painted *below* the transcript's clip rect, so the
/// player waited for an answer and only saw older messages. `scroll_view` keeps
/// its own offset and never follows new content, while the transcript grows
/// downward from the top of its viewport.
///
/// This probe pins the fix as geometry rather than eyeballing a screenshot: it
/// finds the transcript's clip rect (the stage-width clip that is tall but not
/// the whole stage) and asserts that the content inside it ends before the clip
/// does — i.e. the newest line is actually visible.

///|
fn talking_world() -> @app.WorldModel {
  let files : Array[(String, String)] = [
    ("world.md", "# 探针世界\n\nb\n"),
    ("characters/周跛子.md", "# 周跛子\n\n## 人设\n\nx\n"),
  ]
  let (model, _effect) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("probe", true, files),
  )
  let (selected, _s) = @app.update(model, @app.Select(Some("周跛子")))
  // Enough turns that the transcript must overflow its viewport; with a short
  // history nothing is clipped and the probe proves nothing.
  let mut current = selected
  for round in 0..<4 {
    let (asked, _a) = @app.update(current, @app.Send("第 \{round} 句"))
    let (replied, _r) = @app.update(
      asked,
      @app.Reply(
        "周跛子",
        Some("第一段。\n\n第二段。\n\n第三段。"),
      ),
    )
    current = replied
  }
  current
}

///|
test "the newest reply stays inside the transcript's clip rect" {
  let runtime = @runtime.new_view(
    root=@app.view(talking_world()),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let commands = runtime.draw_commands()
  // The transcript is the stage-width clip that is taller than a button row but
  // shorter than the whole stage column.
  let mut clip = None
  for command in commands {
    match command {
      @core.PushClip(rect) =>
        if rect.size.width == 520.0 &&
          rect.size.height > 100.0 &&
          rect.size.height < 400.0 {
          clip = Some(rect)
        }
      _ => ()
    }
  }
  let rect = match clip {
    Some(value) => value
    None => fail("the transcript clip rect must exist")
  }
  // Rows painted inside the transcript's clip rect. Anything past the bottom
  // edge is clipped away and invisible to the player, which is the defect this
  // test guards.
  let clip_bottom = rect.origin.y + rect.size.height
  let mut lowest = 0.0
  let mut rows = 0
  for command in commands {
    match command {
      @core.DrawText(run) => {
        let top = run.frame.origin.y
        let bottom = top + run.frame.size.height
        if run.frame.origin.x >= rect.origin.x &&
          run.frame.origin.x < rect.origin.x + rect.size.width &&
          top >= rect.origin.y &&
          bottom <= clip_bottom {
          rows = rows + 1
          if bottom > lowest {
            lowest = bottom
          }
        }
      }
      _ => ()
    }
  }
  // The transcript must show several rows (not just its first), and the last
  // visible one must sit near the bottom of the clip: following the tail rather
  // than leaving the player at the top of the history.
  assert_true(rows >= 4)
  // Following the tail means the last visible row reaches the clip's bottom
  // edge. Without it the transcript stays anchored at the top of the history and
  // the newest reply is painted below `clip_bottom`, then cut away.
  assert_true(lowest >= clip_bottom - 1.0)
}

///|
test "the swipe buttons fit inside the transcript column" {
  // `‹ 上一版` / `1/2` / `下一版 ›` plus 改/删/分叉 is a long row. If it exceeds
  // the stage width the last buttons are cut off, which no model test notices.
  let runtime = @runtime.new_view(
    root=@app.view(talking_world()),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let mut rightmost = 0.0
  let mut stage_right = 0.0
  for command in runtime.draw_commands() {
    match command {
      @core.PushClip(rect) =>
        if rect.size.width == 520.0 &&
          rect.size.height > 100.0 &&
          rect.size.height < 400.0 {
          stage_right = rect.origin.x + rect.size.width
        }
      @core.DrawText(run) =>
        if run.text.contains("版") ||
          run.text.contains("改") ||
          run.text.contains("分叉") {
          let right = run.frame.origin.x + run.frame.size.width
          if right > rightmost {
            rightmost = right
          }
        }
      _ => ()
    }
  }
  // Non-vacuous: both numbers must be real, or the test proves nothing.
  assert_true(stage_right > 0.0)
  assert_true(rightmost > 0.0)
  assert_true(rightmost <= stage_right + 1.0)
}

///|
test "a short history is not scrolled off the top" {
  // The follow-tail request asks to scroll down; with content SHORTER than the
  // viewport there is nothing to scroll, so the rows must stay on screen. An
  // offset applied unchecked made a two-line conversation disappear entirely —
  // which is what a freshly loaded world would show.
  let runtime = @runtime.new_view(
    root=@app.view(short_world()),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let commands = runtime.draw_commands()
  // The transcript's clip: the stage-width rect that is taller than a button row.
  let mut stage = None
  for command in commands {
    match command {
      @core.PushClip(rect) =>
        if rect.size.width >= 500.0 &&
          rect.size.width <= 540.0 &&
          rect.size.height > 40.0 &&
          rect.size.height < 600.0 {
          stage = Some(rect)
        }
      _ => ()
    }
  }
  let rect = match stage {
    Some(value) => value
    None => fail("the transcript clip must exist")
  }
  // Both lines must be painted inside that clip.
  let mut seen = 0
  for command in commands {
    match command {
      @core.DrawText(run) =>
        if (run.text.contains("温一壶酒") || run.text.contains("酒温着")) &&
          run.frame.origin.y >= rect.origin.y - 1.0 &&
          run.frame.origin.y <= rect.origin.y + rect.size.height {
          seen = seen + 1
        }
      _ => ()
    }
  }
  assert_eq(seen, 2)
}

///|
fn short_world() -> @app.WorldModel {
  let files : Array[(String, String)] = [
    ("world.md", "# 探针世界\n\nb\n"),
    ("characters/周跛子.md", "# 周跛子\n\n## 人设\n\nx\n"),
    (
      "conversations/周跛子.json", "{\"conversations\":[{\"character\":\"周跛子\",\"lines\":[{\"speaker\":\"user\",\"text\":\"温一壶酒\"},{\"speaker\":\"assistant\",\"text\":\"酒温着。\"}],\"summary\":\"\"}]}",
    ),
  ]
  let (model, _e) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("probe", true, files),
  )
  let (selected, _s) = @app.update(model, @app.Select(Some("周跛子")))
  selected
}
