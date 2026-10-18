///|
/// Does a world's portrait actually reach the renderer?
///
/// The portrait chain has four links — the card's `portrait:` field, the
/// `characters/<name>.png` asset, `portrait_data_uri`, and `@views.image` — and
/// every earlier test stops at the *model* (the URI string). This probe follows
/// the chain to the draw command list, because a URI that never becomes a
/// `DrawImage` renders as nothing at all.

///|
fn portrait_world() -> @app.WorldModel {
  let files : Array[(String, String)] = [
    ("world.md", "# 立绘世界\n\nb\n"),
    (
      "characters/甲.md", "# 甲\n\n## 人设\n\n甲的设定。\n\n## 立绘\n\n甲.png\n",
    ),
    // A 1x1 PNG, base64. The renderer does not decode it at this layer: the
    // text system only has to accept the `data:` source.
    (
      "characters/甲.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
    ),
  ]
  let (model, _e) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("probe", true, files),
  )
  let (selected, _s) = @app.update(model, @app.Select(Some("甲")))
  selected
}

///|
test "a portrait becomes a draw-image command carrying a data URI" {
  let runtime = @runtime.new_view(
    root=@app.view(portrait_world()),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let sources : Array[String] = []
  for command in runtime.draw_commands() {
    match command {
      @core.DrawImage(run) => sources.push(run.source)
      _ => ()
    }
  }
  // The roster avatar and the stage portrait both draw the same asset, so at
  // least one image command must exist and it must be our data URI.
  assert_true(!sources.is_empty())
  let mut has_data_uri = false
  for source in sources {
    if source.has_prefix("data:image/png;base64,") {
      has_data_uri = true
    }
  }
  assert_true(has_data_uri)
}

///|
test "a world without a portrait draws no image, and still renders" {
  // The colour-block fallback must not depend on an image command existing.
  let files : Array[(String, String)] = [
    ("world.md", "# 无图世界\n\nb\n"),
    ("characters/甲.md", "# 甲\n\n## 人设\n\n甲的设定。\n"),
  ]
  let (model, _e) = @app.update(
    @app.WorldModel::new(),
    @app.WorldFilesArrived("probe", true, files),
  )
  let (selected, _s) = @app.update(model, @app.Select(Some("甲")))
  let runtime = @runtime.new_view(
    root=@app.view(selected),
    size=@core.Size::new(width=1560.0, height=1080.0),
  )
  let mut images = 0
  let mut texts = 0
  for command in runtime.draw_commands() {
    match command {
      @core.DrawImage(_) => images = images + 1
      @core.DrawText(_) => texts = texts + 1
      _ => ()
    }
  }
  assert_eq(images, 0)
  // The fallback is a text glyph, so the stage is not simply blank.
  assert_true(texts > 10)
}
