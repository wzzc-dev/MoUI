///|
/// Portrait assets: base64 codec, resolution, and the no-portrait fallback.

///|
test "base64 round-trips every padding case" {
  // 1, 2, and 3 byte groups exercise all three padding shapes.
  let cases : Array[Bytes] = [
    b"", b"f", b"fo", b"foo", b"foob", b"fooba", b"foobar",
  ]
  for bytes in cases {
    let text = base64_encode(bytes)
    match base64_decode(text) {
      Some(back) => assert_true(back == bytes)
      None => fail("decode failed for \{text}")
    }
  }
  // The canonical vectors, so the encoder is not merely self-consistent.
  assert_eq(base64_encode(b"f"), "Zg==")
  assert_eq(base64_encode(b"fo"), "Zm8=")
  assert_eq(base64_encode(b"foo"), "Zm9v")
  assert_eq(base64_encode(b"foob"), "Zm9vYg==")
  assert_eq(base64_encode(b"fooba"), "Zm9vYmE=")
  assert_eq(base64_encode(b"foobar"), "Zm9vYmFy")
}

///|
test "damaged base64 decodes to nothing instead of noise" {
  assert_true(base64_decode("not base64!") is None)
  assert_true(base64_decode("Zm9vY") is None)
}

///|
test "a portrait resolves to a data URI and an unknown one resolves to empty" {
  let png = base64_encode(b"\x89PNG")
  let card = CharacterCard::new(
    id="林",
    name="林掌柜",
    persona="p",
    portrait="林掌柜.png",
  )
  let uri = portrait_uri(card, [("林掌柜.png", png)])
  assert_true(uri.has_prefix("data:image/png;base64,"))
  // A card whose portrait file is missing renders the fallback, not a broken
  // data URI.
  assert_eq(portrait_uri(card, []), "")
  assert_eq(portrait_uri(card, [("别人.png", png)]), "")
  // No portrait at all is the common case.
  let plain = CharacterCard::new(id="x", name="某人", persona="p")
  assert_eq(portrait_uri(plain, [("林掌柜.png", png)]), "")
}

///|
test "the portrait survives the Markdown card round trip" {
  let card = CharacterCard::new(
    id="林",
    name="林掌柜",
    persona="掌柜。",
    portrait="林掌柜.png",
  )
  let text = card.character_md_text()
  assert_true(text.contains("## 立绘"))
  match parse_character_md(text) {
    Some(parsed) => assert_eq(parsed.portrait(), "林掌柜.png")
    None => fail("the card must parse back")
  }
}

///|
test "portrait file names are recognised by extension, case-insensitively" {
  assert_true(is_portrait_file_name("林掌柜.png"))
  assert_true(is_portrait_file_name("a.JPG"))
  assert_true(is_portrait_file_name("a.jpeg"))
  assert_true(is_portrait_file_name("a.webp"))
  assert_false(is_portrait_file_name("world.md"))
  assert_false(is_portrait_file_name("conversations.json"))
}

///|
test "a generated world asks for a portrait prompt" {
  let prompt = world_idea_prompt("雨夜酒馆")
  // The schema must request the field, or a generated world can never carry the
  // one thing that makes its art reproducible.
  assert_true(prompt.system.contains("portrait_prompt"))
  assert_true(prompt.system.contains("立绘"))
  // And it must be explicit that the program does not call an image API.
  assert_true(prompt.system.contains("不会调用图像接口"))
}

///|
test "a portrait prompt round-trips through the world folder" {
  let scenario = Scenario::new(
    id="tavern",
    name="酒馆",
    background="雨夜。",
    characters=[
      CharacterCard::new(
        id="lin",
        name="林掌柜",
        persona="话少。",
        portrait_prompt="四十岁上下，深色短褂，靠柜台站着，油灯侧光。",
      ),
    ],
  )
  let files = scenario.world_files()
  let text = pair_for(files, "characters/林掌柜.md")
  assert_true(text.contains("## 立绘提示词"))
  assert_true(text.contains("油灯侧光"))
  // Parse it back: the prompt is what lets the player regenerate the same art.
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      // The id is the Markdown file's base name (`林掌柜`), not the `lin` the
      // in-memory card was constructed with: parsing derives ids from files.
      let card = parsed.scenario.character("林掌柜").unwrap()
      assert_true(card.portrait_prompt().contains("油灯侧光"))
      // The reference is still a filename-only field: no bytes in Markdown.
      assert_eq(card.portrait(), "")
    }
    None => fail("the world must parse")
  }
}

///|
test "a portrait prompt survives the JSON codec too" {
  let card = CharacterCard::new(
    id="lin",
    name="林掌柜",
    persona="话少。",
    portrait="林掌柜.png",
    portrait_prompt="四十岁上下，深色短褂。",
  )
  // Round-trip through a whole scenario: the character codec is internal, and
  // the scenario is what a generated world actually decodes.
  let scenario = Scenario::new(
    id="tavern",
    name="酒馆",
    background="雨夜。",
    characters=[card],
  )
  let json = scenario.to_json()
  assert_true(json.contains("portrait_prompt"))
  let back = Scenario::try_from_json(json).unwrap()
  let restored = back.character("lin").unwrap()
  assert_eq(restored.portrait_prompt(), "四十岁上下，深色短褂。")
  assert_eq(restored.portrait(), "林掌柜.png")
}

///|
test "the prompt is only surfaced while it is still actionable" {
  // Nothing to show when the player already has art.
  assert_eq(
    portrait_prompt_hint(
      CharacterCard::new(
        id="a",
        name="甲",
        persona="x",
        portrait="甲.png",
        portrait_prompt="提示词",
      ),
    ),
    "",
  )
  // Nothing to show for a hand-written card.
  assert_eq(
    portrait_prompt_hint(CharacterCard::new(id="a", name="甲", persona="x")),
    "",
  )
  // Otherwise it names the file to save, so the instruction is complete.
  let hint = portrait_prompt_hint(
    CharacterCard::new(
      id="a",
      name="甲",
      persona="x",
      portrait_prompt="提示词",
    ),
  )
  assert_true(hint.contains("提示词"))
  assert_true(hint.contains("characters/甲.png"))
}
