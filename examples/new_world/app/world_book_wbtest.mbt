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

///|
fn book_world() -> WorldModel {
  let scenario = Scenario::new(
    id="tavern",
    name="雨夜酒馆",
    background="夜雨敲窗。",
    characters=[
      CharacterCard::new(id="lin", name="林掌柜", persona="掌柜。"),
    ],
    world_book=[
      WorldEntry::new(keys=["当铺"], content="当铺在巷子尽头。"),
    ],
  )
  step(WorldModel::new(), WorldFilesArrived("tavern", true, world_files_of(scenario)))
}

///|
fn world_files_of(scenario : Scenario) -> Array[(String, String)] {
  scenario.world_files()
}

///|
test "opening the world book loads its entries" {
  let model = step(book_world(), OpenDrawer(WorldBook))
  assert_eq(model.world_book_draft().length(), 1)
  assert_eq(model.world_book_draft()[0].content(), "当铺在巷子尽头。")
  // Nothing is open for editing yet.
  assert_eq(model.world_book_edit(), -1)
}

///|
test "editing an entry changes the working copy, not the world" {
  let model = step(book_world(), OpenDrawer(WorldBook))
  let editing = step(model, WorldBookEdit(0))
  assert_eq(editing.world_book_edit(), 0)
  let rekeyed = step(editing, WorldBookKeysChanged("当铺，典当"))
  assert_eq(rekeyed.world_book_draft()[0].keys().length(), 2)
  let reworded = step(rekeyed, WorldBookContentChanged("当铺在巷子最深处，夜里不点灯。"))
  assert_eq(
    reworded.world_book_draft()[0].content(),
    "当铺在巷子最深处，夜里不点灯。",
  )
  // The world itself is untouched until 保存.
  assert_eq(
    reworded.scenario.world_book()[0].content(),
    "当铺在巷子尽头。",
  )
}

///|
test "saving writes the book into the world" {
  let model = step(book_world(), OpenDrawer(WorldBook))
  let edited = step(
    step(model, WorldBookEdit(0)),
    WorldBookContentChanged("当铺在巷子最深处。"),
  )
  let saved = step(edited, WorldBookSave)
  assert_eq(
    saved.scenario.world_book()[0].content(),
    "当铺在巷子最深处。",
  )
  // And the world's own file carries it.
  let files = saved.scenario.world_files()
  let mut book = ""
  for pair in files {
    if pair.0 == "world_book.md" {
      book = pair.1
    }
  }
  assert_true(book.contains("当铺在巷子最深处。"))
}

///|
test "an entry can be added and removed" {
  let model = step(book_world(), OpenDrawer(WorldBook))
  let added = step(model, WorldBookAdd)
  assert_eq(added.world_book_draft().length(), 2)
  // The new entry is open for editing straight away.
  assert_eq(added.world_book_edit(), 1)
  let removed = step(added, WorldBookDelete(1))
  assert_eq(removed.world_book_draft().length(), 1)
}
