///|
/// What survives when a world changes underneath its own history?
///
/// A folder database is edited by hand — that is the point — so a world can gain
/// and lose characters between sessions. These tests pin what happens to the
/// conversations that referenced the old cast, because "silently dropped" and
/// "silently kept" are very different promises.

///|
test "a conversation for a removed character is dropped with a warning" {
  let files : Array[(String, String)] = [
    ("world.md", "# 世界\n\n背景。\n"),
    ("characters/甲.md", "# 甲\n\n## 人设\n\n甲。\n"),
    (
      "conversations/甲.json", "{\"conversations\":[{\"character\":\"甲\",\"lines\":[{\"speaker\":\"user\",\"text\":\"hi\"}],\"summary\":\"\"}]}",
    ),
    // 乙 is gone from the cards, but the journal still mentions them.
    (
      "conversations/乙.json", "{\"conversations\":[{\"character\":\"乙\",\"lines\":[{\"speaker\":\"user\",\"text\":\"bye\"}],\"summary\":\"\"}]}",
    ),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      // The orphan is not resurrected as a ghost character.
      assert_true(parsed.scenario.character("乙") is None)
      assert_eq(parsed.scenario.characters().length(), 1)
      // And it is not silently kept as an unreachable conversation either.
      let keys : Array[String] = []
      for conversation in parsed.conversations {
        keys.push(conversation.character_id())
      }
      assert_eq(keys, ["甲"])
      // The player is told, so a vanished history is not a mystery.
      let warned = parsed.warnings.filter(line => line.contains("乙")).length()
      assert_true(warned > 0)
    }
    None => fail("the world must still parse")
  }
}

///|
test "a scene outlives a change to the cast list" {
  // Scenes are keyed by location, not by character, so they must survive a
  // character being removed — otherwise editing the cast silently deleted every
  // multi-party transcript.
  let files : Array[(String, String)] = [
    (
      "world.md", "# 世界\n\n背景。\n\n## 地点\n\n- 吧台: x=0 y=0 w=100 h=100\n",
    ),
    (
      "characters/甲.md", "# 甲\n\n## 人设\n\n甲。\n\n## 所在\n\n吧台\n",
    ),
    (
      "conversations/scene_吧台.json", "{\"conversations\":[{\"character\":\"scene:吧台\",\"lines\":[{\"speaker\":\"user\",\"text\":\"干杯\"}],\"summary\":\"\"}]}",
    ),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      let keys : Array[String] = []
      for conversation in parsed.conversations {
        keys.push(conversation.character_id())
      }
      assert_eq(keys, ["scene:吧台"])
      // With only one character present the scene has a cast of one, which is
      // still a valid scene (the player may add another later).
      let in_scene = cast_at(parsed.scenario, "吧台")
      assert_eq(in_scene.length(), 1)
    }
    None => fail("the world must still parse")
  }
}

///|
test "a branch whose base character was removed is dropped too" {
  // A branch key is `<角色>~N`; if the base character disappears the branch has
  // nothing to attach to, so it must go with the same warning rather than linger
  // as an unreachable file.
  let files : Array[(String, String)] = [
    ("world.md", "# 世界\n\n背景。\n"),
    (
      "conversations/幽灵~2.json", "{\"conversations\":[{\"character\":\"幽灵~2\",\"lines\":[{\"speaker\":\"user\",\"text\":\"x\"}],\"summary\":\"\"}]}",
    ),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      assert_eq(parsed.conversations.length(), 0)
      assert_true(
        parsed.warnings.filter(line => line.contains("幽灵")).length() > 0,
      )
    }
    None => fail("the world must still parse")
  }
}
