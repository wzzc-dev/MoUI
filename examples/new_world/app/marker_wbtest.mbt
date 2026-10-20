///|
/// Two characters in one place must be two visible markers.
///
/// A card may name a location instead of carrying coordinates — the common case
/// for AI-generated worlds, and for any hand-edited folder. Falling back to the
/// location's centre put every such character on the exact same pixel, so a scene
/// of three showed one marker and the map looked broken.

///|
test "characters sharing a location get distinct markers" {
  let files : Array[(String, String)] = [
    (
      "world.md", "# 世界\n\nb\n\n## 地点\n\n- 吧台: x=20 y=20 w=240 h=150\n",
    ),
    ("characters/甲.md", "# 甲\n\n## 人设\n\na\n\n## 所在\n\n吧台\n"),
    ("characters/乙.md", "# 乙\n\n## 人设\n\nb\n\n## 所在\n\n吧台\n"),
    ("characters/丙.md", "# 丙\n\n## 人设\n\nc\n\n## 所在\n\n吧台\n"),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      let scenario = parsed.scenario
      let a = scenario.character_point("甲").unwrap()
      let b = scenario.character_point("乙").unwrap()
      let c = scenario.character_point("丙").unwrap()
      // No two markers may coincide, or one hides the other.
      assert_true(!(a.x == b.x && a.y == b.y))
      assert_true(!(a.x == c.x && a.y == c.y))
      assert_true(!(b.x == c.x && b.y == c.y))
      // All three stay inside the place they belong to.
      let place = scenario.location("吧台").unwrap()
      for point in [a, b, c] {
        assert_true(point.x >= place.rect().origin.x)
        assert_true(point.y >= place.rect().origin.y)
        assert_true(point.x <= place.rect().origin.x + place.rect().size.width)
        assert_true(point.y <= place.rect().origin.y + place.rect().size.height)
      }
    }
    None => fail("must parse")
  }
}

///|
test "a lone character in a place stays at its centre, and explicit points win" {
  let files : Array[(String, String)] = [
    (
      "world.md", "# 世界\n\nb\n\n## 地点\n\n- 吧台: x=0 y=0 w=200 h=100\n",
    ),
    // One located character: no spreading, so it sits exactly at the centre.
    ("characters/独.md", "# 独\n\n## 人设\n\na\n\n## 所在\n\n吧台\n"),
    // One with coordinates: the author's point is authoritative.
    ("characters/定.md", "# 定\n\n## 人设\n\nb\n\n## 位置\n\nx=10 y=20\n"),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      let scenario = parsed.scenario
      let solo = scenario.character_point("独").unwrap()
      assert_eq(solo.x, 100.0)
      assert_eq(solo.y, 50.0)
      let fixed = scenario.character_point("定").unwrap()
      assert_eq(fixed.x, 10.0)
      assert_eq(fixed.y, 20.0)
    }
    None => fail("must parse")
  }
}
