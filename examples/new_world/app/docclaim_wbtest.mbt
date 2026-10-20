///|
/// Do the examples printed in the README actually parse?
///
/// Documentation that shows a syntax the codec does not accept is worse than no
/// documentation: a player copies it, the entry silently degrades, and they blame
/// the app. These tests feed the README's own snippets through the real parser.

///|
test "the README's plain world-book line parses" {
  let files : Array[(String, String)] = [
    ("world.md", "# 世界\n\nb\n"),
    (
      "world_book.md", "# 世界书\n\n- 酒 | 花雕: 后堂埋着一坛三十年的女儿红。\n",
    ),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      let entries = parsed.scenario.world_book()
      assert_eq(entries.length(), 1)
      // Both keywords trigger the same entry.
      assert_eq(entries[0].keys, ["酒", "花雕"])
      assert_eq(
        entries[0].content,
        "后堂埋着一坛三十年的女儿红。",
      )
      assert_eq(entries[0].priority, 0)
      assert_eq(entries[0].probability, 100)
    }
    None => fail("must parse")
  }
}

///|
test "the README's modifier lines parse with every field" {
  let files : Array[(String, String)] = [
    ("world.md", "# 世界\n\nb\n"),
    (
      "world_book.md", "# 世界书\n\n- 花雕 [priority=8] [position=before]: 规矩：只温不冰。\n- 雨 [probability=25] [recursion=1]: 雨天路上不会有旅人。\n",
    ),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      let entries = parsed.scenario.world_book()
      assert_eq(entries.length(), 2)
      assert_eq(entries[0].priority, 8)
      assert_true(entries[0].position is Before)
      assert_eq(entries[1].probability, 25)
      assert_eq(entries[1].recursion, 1)
      // Only non-default modifiers are written back, so round-tripping the file
      // leaves the plain entry exactly as the player typed it.
      let mut text = ""
      for pair in parsed.scenario.world_files() {
        if pair.0 == "world_book.md" {
          text = pair.1
        }
      }
      assert_true(
        text.contains(
          "- 花雕 [priority=8] [position=before]: 规矩：只温不冰。",
        ),
      )
      assert_false(text.contains("probability=100"))
    }
    None => fail("must parse")
  }
}

///|
test "the README's location and map lines parse" {
  let files : Array[(String, String)] = [
    (
      "world.md", "# 世界\n\nb\n\n## 地图\n\n- 尺寸: w=700 h=460\n\n## 地点\n\n- 吧台 id=bar: x=20 y=20 w=240 h=150\n",
    ),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      assert_eq(parsed.scenario.map_width(), 700.0)
      assert_eq(parsed.scenario.map_height(), 460.0)
      let location = parsed.scenario.location("bar").unwrap()
      assert_eq(location.name, "吧台")
      // The written form must keep the id, or a later reload rewrites it to the
      // display name and `cast_at` stops matching.
      let mut world_md = ""
      for pair in parsed.scenario.world_files() {
        if pair.0 == "world.md" {
          world_md = pair.1
        }
      }
      assert_true(world_md.contains("id=bar"))
    }
    None => fail("must parse")
  }
}
