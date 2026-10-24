///|
/// World bundles: a world folder as one shareable file.

///|
fn sample_bundle() -> WorldBundle {
  match
    bundle_decode(
      bundle_encode("雨夜酒馆", [
        ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
        ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
        ("conversations/林掌柜.json", "{\"conversations\":[]}"),
        ("events.json", "{\"events\":[]}"),
      ]),
    ) {
    Some(bundle) => bundle
    None => WorldBundle::{ name: "", files: [], }
  }
}

///|
test "a bundle round-trips every world file" {
  let bundle = sample_bundle()
  assert_eq(bundle.name, "雨夜酒馆")
  assert_eq(bundle.files.length(), 4)
  assert_eq(
    pair_for(bundle.files, "world.md"),
    "# 雨夜酒馆\n\n夜雨敲窗。\n",
  )
}

///|
test "a damaged or foreign bundle is rejected whole" {
  // There is nothing sensible to salvage from a truncated archive.
  assert_true(bundle_decode("") is None)
  assert_true(bundle_decode("not json") is None)
  assert_true(bundle_decode("{}") is None)
  // Right shape, wrong format marker: a future version must not be mis-read.
  assert_true(
    bundle_decode(
      "{\"format\":\"other/9\",\"name\":\"x\",\"files\":[[\"world.md\",\"# x\"]]}",
    )
    is None,
  )
  // No usable files.
  assert_true(
    bundle_decode(
      "{\"format\":\"moui.new-world/1\",\"name\":\"x\",\"files\":[]}",
    )
    is None,
  )
}

///|
test "a bundle cannot smuggle a path outside the world folder" {
  // The decoder is the last line of defence for a file a stranger sent you.
  let text = "{\"format\":\"moui.new-world/1\",\"name\":\"x\",\"files\":[" +
    "[\"world.md\",\"# x\"]," +
    "[\"../../.ssh/authorized_keys\",\"pwned\"]," +
    "[\"notes.txt\",\"not a world file\"]]}"
  match bundle_decode(text) {
    Some(bundle) => {
      let paths : Array[String] = []
      for pair in bundle.files {
        paths.push(pair.0)
      }
      // Only the world file survives: traversal and non-world extensions are
      // both refused.
      assert_eq(paths, ["world.md"])
    }
    None => fail("the valid file should still import")
  }
}

///|
test "an unusable bundle name is sanitized, not trusted" {
  let text = "{\"format\":\"moui.new-world/1\",\"name\":\"../../../etc\",\"files\":[[\"world.md\",\"# x\"]]}"
  match bundle_decode(text) {
    Some(bundle) => {
      // The name is one path component: no separator survives, so the `..`
      // that remains cannot walk anywhere.
      assert_false(bundle.name.contains("/"))
      assert_false(bundle.name.contains("\\"))
      assert_true(bundle.name != "." && bundle.name != "..")
    }
    None => fail("a bundle with a hostile name is still importable")
  }
}

///|
test "exporting an open world builds a bundle with its journal" {
  let model = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, tavern_files()),
  )
  match model.bundle_text() {
    Some(text) =>
      match bundle_decode(text) {
        Some(bundle) => {
          assert_eq(bundle.name, "tavern")
          let paths : Array[String] = []
          for pair in bundle.files {
            paths.push(pair.0)
          }
          assert_true(paths.contains("world.md"))
          assert_true(paths.contains("events.json"))
          // config.json belongs to the library, never to a world.
          assert_false(paths.contains("config.json"))
        }
        None => fail("the export must decode")
      }
    None => fail("an open world must export")
  }
  // Nothing open: nothing to export.
  assert_true(WorldModel::new().bundle_text() is None)
}

///|
test "importing a world goes on stage and keeps its history" {
  let book = ConversationBook::new()
  book.set(
    Conversation::new(character_id="林掌柜")
    .append(ChatLine::player("温一壶酒"))
    .append(ChatLine::character("林掌柜", "客官里边坐。")),
  )
  let text = bundle_encode("雨夜酒馆", [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
    (conversation_path("林掌柜"), book.to_json_text()),
  ])
  match bundle_decode(text) {
    Some(bundle) => {
      // The import path is the same one a folder open takes.
      let files = bundle.files
      let model = step(
        WorldModel::new(),
        WorldImported(true, "雨夜酒馆", files),
      )
      assert_eq(model.current(), Some("雨夜酒馆"))
      assert_eq(model.scenario().name(), "雨夜酒馆")
      assert_eq(
        model.conversations.for_character("林掌柜").lines().length(),
        2,
      )
      assert_true(model.log()[0].contains("已导入"))
    }
    None => fail("the bundle must decode")
  }
  // A failed import changes nothing and says so.
  let untouched = step(WorldModel::new(), WorldImported(false, "", []))
  assert_eq(untouched.current(), None)
  assert_true(untouched.log()[0].contains("导入"))
}

///|
test "a bundle carries portrait assets" {
  let png = base64_encode(b"\x89PNG\r\n\x1a\n")
  let text = bundle_encode("雨夜酒馆", [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    (
      "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n\n## 立绘\n\n林掌柜.png\n",
    ),
    ("林掌柜.png", png),
  ])
  match bundle_decode(text) {
    Some(bundle) => {
      let paths : Array[String] = []
      for pair in bundle.files {
        paths.push(pair.0)
      }
      assert_true(paths.contains("林掌柜.png"))
      assert_eq(pair_for(bundle.files, "林掌柜.png"), png)
      // And the card can resolve it once the world is on stage.
      match parse_world_files(world_files_from_paths(bundle.files)) {
        Some(parsed) =>
          match parsed.scenario.character("林掌柜") {
            Some(card) => {
              assert_eq(card.portrait(), "林掌柜.png")
              assert_true(
                portrait_uri(card, [("林掌柜.png", png)]).has_prefix(
                  "data:image/png;base64,",
                ),
              )
            }
            None => fail("the card should parse")
          }
        None => fail("the world should parse")
      }
    }
    None => fail("a bundle with a portrait must decode")
  }
}

///|
test "a bundle carries a portrait, and the card resolves it" {
  // A world sent to a friend must arrive with its faces: the portrait rides
  // as base64 beside the card, and the card names it in its 立绘 section.
  // A one-pixel PNG is enough to prove the plumbing.
  let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  let card = "# 温衍\n\n## 人设\n\n清心寡欲的散仙。\n\n## 立绘\n\n温衍.png\n"
  // The app's own encoder writes the bundle, so the escaping is the app's.
  let text = bundle_encode("WenYan", [
    ("world.md", "# WenYan\n\n风雪不停。\n"),
    ("characters/温衍.md", card),
    ("characters/温衍.png", png),
  ])
  match bundle_decode(text) {
    Some(bundle) => {
      assert_eq(bundle.name, "WenYan")
      assert_eq(bundle.files.length(), 3)
      // The card parses, and it points at the portrait.
      let card_text = pair_for(bundle.files, "characters/温衍.md")
      match parse_character_md(card_text) {
        Some(parsed) => {
          assert_eq(parsed.name(), "温衍")
          assert_eq(parsed.portrait(), "温衍.png")
          // And the portrait resolves to a data URI the image view can render.
          let portraits : Array[(String, String)] = []
          for pair in bundle.files {
            if is_portrait_file_name(pair.0) {
              portraits.push(pair)
            }
          }
          let uri = portrait_uri(parsed, portraits)
          assert_true(uri.has_prefix("data:image/png;base64,"))
        }
        None => fail("the card must parse")
      }
    }
    None => fail("a v2 bundle with a portrait must decode")
  }
}

///|
test "a base64-looking portrait file is recognised as encoded, not as bytes" {
  // A host without a byte writer leaves the encoded form in the folder; the
  // reader must not encode it a second time.
  assert_true(is_base64_text("aGVsbG8="))
  assert_true(is_base64_text("aGVsbG8=\n"))
  assert_false(is_base64_text(""))
  // Real image bytes are not base64 text.
  assert_false(is_base64_text("\u{FF}\u{D8}\u{FF}"))
}

///|
test "an imported bundle never merges into an existing world" {
  assert_eq(unique_world_name("雨夜酒馆", []), "雨夜酒馆")
  assert_eq(unique_world_name("雨夜酒馆", ["雨夜酒馆"]), "雨夜酒馆 (2)")
  assert_eq(
    unique_world_name("雨夜酒馆", ["雨夜酒馆", "雨夜酒馆 (2)"]),
    "雨夜酒馆 (3)",
  )
  // The bundle's own name is sanitised before it becomes a folder.
  assert_eq(unique_world_name("../坏名", []), "_.._坏名")
}

///|
test "export hands the host one encoded bundle, not a file list" {
  let sent : Array[(String, String)] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (_folder, _files, done) => done(true),
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (file_name, text, done) => {
      sent.push((file_name, text))
      done(true)
    },
    import_world: done => done(false, ""),
    copy_to_clipboard: _text => (),
  }
  let (model, effect) = update(tavern(), ExportWorld, world_host=host)
  let messages : Array[Msg] = []
  @moui.Effect::runtime_visit(
    effect,
    message => messages.push(message),
    _dispatch => (),
    (_descriptor, run) => run(message => messages.push(message)),
    (_descriptor, _start) => (),
  )
  assert_eq(sent.length(), 1)
  assert_eq(sent[0].0, "tavern.aiworld.json")
  // One format, encoded by the app: what the host writes is a v2 bundle the
  // app's own decoder accepts.
  match bundle_decode(sent[0].1) {
    Some(bundle) => {
      assert_eq(bundle.name, "tavern")
      assert_true(bundle.files.length() > 0)
    }
    None => fail("the exported text must be the app's own bundle format")
  }
  let mut exported = false
  for message in messages {
    match message {
      WorldExported(ok) => exported = ok
      _ => ()
    }
  }
  assert_true(exported)
  ignore(model)
}

///|
test "import decodes in the app and writes a fresh folder" {
  let text = bundle_encode("雨夜酒馆", [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    ("world_book.md", "# 世界书\n\n- 酒: 后堂老酒。\n"),
  ])
  let written : Array[(String, Array[(String, String)])] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (folder, files, done) => {
      written.push((folder, files))
      done(true)
    },
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_file_name, _text, done) => done(false),
    import_world: done => done(true, text),
    copy_to_clipboard: _text => (),
  }
  // The library already holds a world with this name.
  let base = step(WorldModel::new(), WorldListArrived(["雨夜酒馆"]))
  let (_model, effect) = update(base, ImportWorld, world_host=host)
  let messages : Array[Msg] = []
  @moui.Effect::runtime_visit(
    effect,
    message => messages.push(message),
    _dispatch => (),
    (_descriptor, run) => run(message => messages.push(message)),
    (_descriptor, _start) => (),
  )
  assert_eq(written.length(), 1)
  assert_eq(written[0].0, "雨夜酒馆 (2)")
  assert_eq(written[0].1.length(), 2)
  // The app — not the host — decided where the world goes, so the message it
  // emits carries that folder to the model.
  let mut landed = base
  for message in messages {
    landed = step_with_host(landed, message, host)
  }
  assert_eq(landed.current(), Some("雨夜酒馆 (2)"))
  assert_eq(landed.scenario().name(), "雨夜酒馆")
}

///|
/// Apply one message with a concrete host (the plain `step` helper uses none).
fn step_with_host(
  model : WorldModel,
  msg : Msg,
  host : WorldHost,
) -> WorldModel {
  let (next, _effect) = update(model, msg, world_host=host)
  next
}
