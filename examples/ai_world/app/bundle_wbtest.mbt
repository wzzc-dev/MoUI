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
      "{\"format\":\"moui.ai-world/1\",\"name\":\"x\",\"files\":[]}",
    )
    is None,
  )
}

///|
test "a bundle cannot smuggle a path outside the world folder" {
  // The decoder is the last line of defence for a file a stranger sent you.
  let text = "{\"format\":\"moui.ai-world/1\",\"name\":\"x\",\"files\":[" +
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
  let text = "{\"format\":\"moui.ai-world/1\",\"name\":\"../../../etc\",\"files\":[[\"world.md\",\"# x\"]]}"
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
