///|
/// Tavern character cards: the format the rest of the roleplay world speaks.

///|
fn tavern_card() -> CharacterCard {
  CharacterCard::new(
    id="wenyan",
    name="温衍",
    persona="清心寡欲的散仙。",
    principles="感情藏在细节里。",
    voice="舒缓、克制。",
    setting="夜深，清虚洞府。",
    opening="（搁下书卷）这么晚了，还不歇息？",
    examples=["坐吧。", "既来了，便坐吧。"],
    secret="他早已算出自己命里有一劫。",
    memory_rules="答应过的事必须记得。",
    appearance="乌黑长发半束。",
    goal="护徒弟走完这一关。",
  )
}

///|
test "a card round-trips through the Tavern v2 format" {
  let card = tavern_card()
  let json = tavern_v2_json(card)
  // The document is a v2 card.
  assert_true(json.contains("chara_card_v2"))
  assert_true(json.contains("\"spec_version\":\"2.0\""))
  // And it reads back as the same character.
  match tavern_card_from_json(json) {
    None => fail("a card we just wrote must read back")
    Some(parsed) => {
      assert_eq(parsed.name(), "温衍")
      assert_eq(parsed.persona(), "清心寡欲的散仙。")
      assert_eq(parsed.principles(), "感情藏在细节里。")
      assert_eq(parsed.setting(), "夜深，清虚洞府。")
      assert_eq(
        parsed.opening(),
        "（搁下书卷）这么晚了，还不歇息？",
      )
      assert_eq(parsed.examples().length(), 2)
      assert_eq(parsed.secret(), "他早已算出自己命里有一劫。")
      // The fields the spec has no place for ride in `extensions`.
      assert_eq(parsed.voice(), "舒缓、克制。")
      assert_eq(parsed.memory_rules(), "答应过的事必须记得。")
      assert_eq(parsed.appearance(), "乌黑长发半束。")
      assert_eq(parsed.goal(), "护徒弟走完这一关。")
    }
  }
}

///|
test "a card in the older flat shape is still read" {
  // Half the cards in the wild keep the fields at the top instead of under
  // `data`. Refusing them over their shape would be rude.
  let flat = "{\"name\":\"林掌柜\",\"description\":\"酒馆掌柜。\",\"personality\":\"话不多。\",\"scenario\":\"夜里。\",\"first_mes\":\"喝点什么？\"}"
  match tavern_card_from_json(flat) {
    None => fail("a flat card must be read")
    Some(card) => {
      assert_eq(card.name(), "林掌柜")
      assert_eq(card.persona(), "酒馆掌柜。")
      assert_eq(card.opening(), "喝点什么？")
    }
  }
}

///|
test "a broken document is not a card" {
  assert_eq(tavern_card_from_json("not json"), None)
  assert_eq(tavern_card_from_json("{}"), None)
  // A card without a name has no identity.
  assert_eq(
    tavern_card_from_json("{\"data\":{\"description\":\"无名\"}}"),
    None,
  )
}

///|
test "a PNG chunk's type and text are characters, not options" {
  // The chunk walk compares the type against "tEXt". When it was built with
  // `Int.to_char().to_string()` it produced `Some(t)Some(E)Some(X)Some(t)`,
  // matched nothing, and every PNG card imported as `None` without a word.
  let chunk_type = Bytes::from_array([116, 69, 88, 116])
  assert_eq(png_chunk_type(chunk_type, 0), "tEXt")
  let payload = Bytes::from_array([99, 104, 97, 114, 97, 0, 123, 125, 233])
  assert_eq(png_text(payload, 0, 5), "chara")
  // The keyword ends at the zero byte and the JSON follows it; a byte outside
  // ASCII is dropped rather than decoded as a character of its own.
  assert_eq(png_text(payload, 6, 9), "{}")
}
