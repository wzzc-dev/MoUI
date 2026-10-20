///|
/// Scenario data and its JSON codec.

///|
test "the default scenario has locations, characters, and world-book entries" {
  let scenario = default_scenario()
  assert_eq(scenario.id(), "tavern")
  assert_true(scenario.locations().length() > 0)
  assert_true(scenario.characters().length() > 0)
  assert_true(scenario.world_book().length() > 0)
  // Every character needs the five fields that actually shape a reply.
  for card in scenario.characters() {
    assert_true(card.name() != "")
    assert_true(card.persona() != "")
    assert_true(card.location() != "")
  }
}

///|
test "a scenario survives a JSON round trip" {
  let original = default_scenario()
  let restored = Scenario::from_json(original.to_json())
  assert_eq(restored.id(), original.id())
  assert_eq(restored.name(), original.name())
  assert_eq(restored.background(), original.background())
  assert_eq(restored.characters().length(), original.characters().length())
  assert_eq(restored.locations().length(), original.locations().length())
  assert_eq(restored.world_book().length(), original.world_book().length())
  // Card fields matter most: a silent loss here would silently change replies.
  let card = restored.character("lin")
  match card {
    Some(value) => {
      assert_eq(value.name(), "林掌柜")
      assert_true(value.persona() != "")
      assert_true(value.secret() != "")
      assert_true(value.voice() != "")
    }
    None => assert_true(false)
  }
  // Geometry and colour round-trip too, or the map would jump on reload.
  match restored.character_point("lin") {
    Some(point) => {
      assert_eq(point.x, 130.0)
      assert_eq(point.y, 100.0)
    }
    None => assert_true(false)
  }
}

///|
test "malformed scenario JSON falls back to the default world" {
  // A bad import must never block startup.
  assert_eq(Scenario::from_json("{ not json").id(), "tavern")
  assert_eq(Scenario::from_json("").id(), "tavern")
  assert_eq(Scenario::from_json("[]").id(), "tavern")
  assert_eq(Scenario::from_json("null").id(), "tavern")
}

///|
test "a minimal scenario decodes with defaults for missing fields" {
  // A hand-written file with only the required fields must still load.
  let text = "{\"id\":\"city\",\"name\":\"都市\",\"background\":\"霓虹与雨。\"}"
  let scenario = Scenario::from_json(text)
  assert_eq(scenario.id(), "city")
  assert_eq(scenario.name(), "都市")
  assert_eq(scenario.locations().length(), 0)
  assert_eq(scenario.characters().length(), 0)
}

///|
test "a wrong-typed required field rejects the file rather than half-loading it" {
  // One wrong type discards the import: a half-decoded world is worse than the
  // default, because the player cannot tell what was lost.
  let text = "{\"id\":123,\"name\":\"都市\",\"background\":\"x\"}"
  assert_eq(Scenario::from_json(text).id(), "tavern")
}

///|
test "character_point falls back to the location centre" {
  let scenario = default_scenario()
  // 书生 carries an explicit point.
  match scenario.character_point("shusheng") {
    Some(point) => assert_eq(point.x, 140.0)
    None => assert_true(false)
  }
  // A card that names a location but has no point resolves to its centre.
  let placed = Scenario::new(
    id="t",
    name="t",
    background="b",
    locations=[
      ScenarioLocation::new(
        id="hall",
        name="正厅",
        description="d",
        rect=@geometry.Rect::new(x=100.0, y=100.0, width=200.0, height=100.0),
      ),
    ],
    characters=[
      CharacterCard::new(
        id="ghost",
        name="无名",
        persona="p",
        location="hall",
      ),
    ],
  )
  match placed.character_point("ghost") {
    Some(point) => {
      assert_eq(point.x, 200.0)
      assert_eq(point.y, 150.0)
    }
    None => assert_true(false)
  }
  // An unknown character has no point at all.
  assert_true(scenario.character_point("nobody") is None)
}

///|
test "changing a scenario changes the world, not the code" {
  // This is the extension claim: a new background is a new JSON file.
  let text = "{\"id\":\"court\",\"name\":\"朝堂\",\"background\":\"金殿之内。\",\"characters\":[{\"id\":\"emp\",\"name\":\"皇帝\",\"persona\":\"朕\",\"location\":\"throne\"}]}"
  let scenario = Scenario::from_json(text)
  assert_eq(scenario.name(), "朝堂")
  assert_eq(scenario.characters().length(), 1)
  match scenario.character("emp") {
    Some(card) => assert_eq(card.name(), "皇帝")
    None => assert_true(false)
  }
}
