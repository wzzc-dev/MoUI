///|
/// The creation wizard: archetype seeding and AI-assisted drafting.

///|
test "an archetype fills every field of a blank draft" {
  let archetypes = creator_archetypes()
  assert_eq(archetypes.length(), 5)
  let seeded = CharacterDraft::new().with_archetype(archetypes[0])
  assert_eq(seeded.name, "掌柜")
  assert_true(seeded.persona != "")
  assert_true(seeded.voice != "")
  assert_true(seeded.goal != "")
  assert_true(seeded.secret != "")
  // v2 blocks: an archetype is a complete card, not a name and a blurb.
  assert_true(seeded.principles != "")
  assert_true(seeded.examples.length() > 0)
  assert_true(seeded.user_name != "")
  assert_true(seeded.setting != "")
  assert_true(seeded.opening != "")
  assert_true(seeded.memory_rules != "")
}

///|
test "an archetype never overwrites a name the player already typed" {
  let archetypes = creator_archetypes()
  let named = CharacterDraft::new().with_name("阿七")
  let seeded = named.with_archetype(archetypes[1])
  // The name the player chose survives; everything else is seeded.
  assert_eq(seeded.name, "阿七")
  assert_eq(seeded.persona, archetypes[1].persona)
  // Appearance is the player's too.
  let described = named.with_appearance("一身白衣")
  let kept = described.with_archetype(archetypes[0])
  assert_eq(kept.appearance, "一身白衣")
}

///|
test "UseArchetype fills the creator and ignores out-of-range indices" {
  let model = step(WorldModel::new(), ToggleCreator)
  let filled = step(model, UseArchetype(2))
  assert_eq(filled.creator_draft().name, "师父")
  assert_true(filled.creator_draft().persona != "")
  // The seeded relationship makes the player someone in the story.
  assert_eq(filled.creator_draft().user_identity, "徒弟")
  // Out of range is inert rather than trapping.
  let unchanged = step(model, UseArchetype(99))
  assert_eq(unchanged.creator_draft().name, "")
  let negative = step(model, UseArchetype(-1))
  assert_eq(negative.creator_draft().name, "")
}

///|
test "drafting without a key seeds an archetype instead of pretending" {
  let based = step(WorldModel::new(), ToggleCreator)
  let with_idea = step(based, CharacterIdeaChanged("一个卖伞的老太太"))
  let (drafted, effect) = update(with_idea, DraftCharacter)
  ignore(effect)
  // No key: no network call, but the form is still usefully filled.
  assert_true(drafted.creator_draft().persona != "")
  assert_true(
    drafted.log().filter(line => line.contains("无 key")).length() > 0,
  )
  // A blank idea is refused with a hint.
  let blank = step(based, DraftCharacter)
  assert_true(blank.log()[0].contains("一句话"))
}

///|
test "drafting with a key sends the idea and the world name" {
  let seen : Array[String] = []
  let runner : TurnRunner = (request, _on_reply, _on_delta) => {
    seen.push(request.system())
    seen.push(request.user())
  }
  let keyed = step(
    step(
      step(WorldModel::new(), WorldFilesArrived("tavern", true, tavern_files())),
      ApiKeyChanged("sk-test"),
    ),
    ToggleCreator,
  )
  let with_idea = step(keyed, CharacterIdeaChanged("一个卖伞的老太太"))
  let (_asked, effect) = update(with_idea, DraftCharacter, turn_runner=runner)
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(seen.length(), 2)
  assert_true(seen[0].contains("JSON"))
  assert_true(seen[1].contains("卖伞的老太太"))
  assert_true(seen[1].contains("雨夜酒馆"))
}

///|
test "a drafted card fills the form but keeps the player's name" {
  let model = step(WorldModel::new(), ToggleCreator)
  let typed = step(
    model,
    CreatorChanged(model.creator_draft().with_name("我自己起的")),
  )
  let drafted = step(
    typed,
    CharacterDrafted(
      Some(
        "{\"name\":\"伞婆\",\"persona\":\"卖了四十年伞。\",\"voice\":\"慢\",\"goal\":\"等一个人\",\"secret\":\"伞里藏着东西\"}",
      ),
    ),
  )
  // The player's name wins; the rest is filled from the draft.
  assert_eq(drafted.creator_draft().name, "我自己起的")
  assert_eq(drafted.creator_draft().persona, "卖了四十年伞。")
  assert_eq(drafted.creator_draft().secret, "伞里藏着东西")
  assert_true(drafted.log()[0].contains("已起草"))
}

///|
test "a drafted card supplies the name when the field is empty" {
  let model = step(WorldModel::new(), ToggleCreator)
  let drafted = step(
    model,
    CharacterDrafted(
      Some("{\"name\":\"伞婆\",\"persona\":\"卖了四十年伞。\"}"),
    ),
  )
  assert_eq(drafted.creator_draft().name, "伞婆")
}

///|
test "a malformed draft is refused and changes nothing" {
  let model = step(
    step(WorldModel::new(), ToggleCreator),
    CreatorChanged(CharacterDraft::new().with_name("保留我")),
  )
  let after = step(model, CharacterDrafted(Some("not a card")))
  assert_eq(after.creator_draft().name, "保留我")
  assert_eq(after.creator_draft().persona, "")
  assert_true(after.log()[0].contains("不是角色卡"))
  // A failure message is also a no-op on the form.
  let failed = step(model, CharacterDrafted(None))
  assert_eq(failed.creator_draft().name, "保留我")
  assert_true(failed.log()[0].contains("失败"))
}

///|
test "a drafted card can go straight into the world" {
  // The wizard's whole point: two clicks from idea to a talking character.
  let based = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, tavern_files()),
  )
  let opened = step(based, ToggleCreator)
  let drafted = step(
    opened,
    CharacterDrafted(
      Some(
        "{\"name\":\"伞婆\",\"persona\":\"卖了四十年伞，话很少。\"}",
      ),
    ),
  )
  let (created, _commit) = update(drafted, CharacterCreated)
  match created.scenario().character("伞婆") {
    Some(card) => assert_eq(card.persona(), "卖了四十年伞，话很少。")
    None => fail("the drafted character should join the world")
  }
  assert_eq(created.selected(), Some("伞婆"))
  assert_false(created.creator_open())
}

///|
test "the generated character parser is defensive" {
  assert_true(parse_generated_character("") is None)
  assert_true(parse_generated_character("nope") is None)
  assert_true(parse_generated_character("{}") is None)
  // No persona means no usable card.
  assert_true(parse_generated_character("{\"name\":\"甲\"}") is None)
  // JSON wrapped in prose is still found.
  match
    parse_generated_character(
      "好的：\n{\"name\":\"甲\",\"persona\":\"乙。\"}\n以上。",
    ) {
    Some(draft) => {
      assert_eq(draft.name, "甲")
      assert_eq(draft.persona, "乙。")
      // Missing optional fields default to empty rather than failing.
      assert_eq(draft.goal, "")
    }
    None => fail("a wrapped card should parse")
  }
}

///|
test "the generated character parser reads the v2 schema" {
  let text = "{\"name\":\"温衍\",\"persona\":\"散仙。\",\"principles\":\"感情藏在细节里。\",\"voice\":\"舒缓克制\",\"examples\":[\"坐吧。\",\"既来了，便坐吧。\"],\"relationship\":{\"user_identity\":\"徒弟\",\"user_name\":\"狸奴\",\"boundary\":\"自己的事一概不提\"},\"setting\":\"夜深，洞府。\",\"opening\":\"搁下书卷，抬眸看你。\",\"memory_rules\":\"答应过的事必须记得。\"}"
  match parse_generated_character(text) {
    Some(draft) => {
      assert_eq(draft.principles, "感情藏在细节里。")
      assert_eq(draft.examples, ["坐吧。", "既来了，便坐吧。"])
      assert_eq(draft.user_identity, "徒弟")
      assert_eq(draft.user_name, "狸奴")
      assert_eq(draft.boundary, "自己的事一概不提")
      assert_eq(draft.setting, "夜深，洞府。")
      assert_eq(draft.opening, "搁下书卷，抬眸看你。")
      assert_eq(draft.memory_rules, "答应过的事必须记得。")
      // And the draft is a complete card: v2 fields survive to the card.
      let card = draft.to_card(point=@geometry.Point::new(x=1.0, y=2.0))
      assert_eq(card.principles(), "感情藏在细节里。")
      assert_eq(card.examples().length(), 2)
      assert_eq(card.relationship().user_name(), "狸奴")
      assert_eq(card.opening(), "搁下书卷，抬眸看你。")
    }
    None => fail("a v2 card should parse")
  }
}
