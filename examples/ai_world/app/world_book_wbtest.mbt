///|
/// World-book keyword triggering and injection.

///|
test "a keyword hit injects its entry" {
  let scenario = default_scenario()
  // "温一壶酒" matches the wine entry through the "酒" key.
  let matched = world_book_trigger(scenario, "温一壶酒")
  assert_true(matched.length() >= 1)
  assert_true(world_book_block(scenario, "温一壶酒").contains("土酿"))
}

///|
test "an unrelated turn injects nothing" {
  let scenario = default_scenario()
  assert_eq(world_book_trigger(scenario, "你好").length(), 0)
  assert_eq(world_book_block(scenario, "你好"), "")
  assert_false(world_book_has_hit(scenario, "今天天气不错"))
}

///|
test "empty input never matches" {
  let scenario = default_scenario()
  assert_eq(world_book_trigger(scenario, "").length(), 0)
  assert_eq(world_book_block(scenario, ""), "")
}

///|
test "matching is case-insensitive and substring-based" {
  // Deterministic and explainable beats linguistically clever: a substring
  // match is what the player can predict from the scenario file.
  let scenario = Scenario::new(id="t", name="t", background="b", world_book=[
    WorldEntry::new(keys=["Tavern"], content="a tavern"),
  ])
  assert_true(world_book_has_hit(scenario, "THE TAVERN IS LOUD"))
  assert_true(world_book_has_hit(scenario, "in the tavern, yes"))
}

///|
test "one turn can hit several entries and they are injected in order" {
  let scenario = default_scenario()
  // Both the wine entry and the official-government entry should fire.
  let block = world_book_block(
    scenario, "我打二两酒，再问问城里官府的海捕文书",
  )
  assert_true(block.contains("土酿"))
  assert_true(block.contains("海捕文书"))
}

///|
test "an entry with no keys never fires" {
  // An empty key list would otherwise match every turn and blow the prompt up.
  let scenario = Scenario::new(id="t", name="t", background="b", world_book=[
    WorldEntry::new(keys=[], content="always"),
  ])
  assert_false(world_book_has_hit(scenario, "anything at all"))
}

///|
test "a blank key is ignored rather than matching everything" {
  let scenario = Scenario::new(id="t", name="t", background="b", world_book=[
    WorldEntry::new(keys=["", "酒"], content="wine"),
  ])
  assert_false(world_book_has_hit(scenario, "nothing relevant here"))
  assert_true(world_book_has_hit(scenario, "来碗酒"))
}
