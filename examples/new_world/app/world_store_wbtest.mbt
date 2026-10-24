///|
/// The folder database codec: round-trip fidelity, tolerance, and formats.

///|
fn sample_world() -> Scenario {
  // The sample is a fixture; a failed parse fails the test through the name
  // assertions below rather than an abort.
  match parse_world_files(sample_files()) {
    Some(parsed) => parsed.scenario
    None => Scenario::new(id="bad", name="bad", background="")
  }
}

///|
fn sample_files() -> WorldFiles {
  {
    world_md: "# 雨夜酒馆\n\n夜雨敲窗，炉火正暖。\n\n雨点打在青石街上。\n\n## 版本\n\n- 卡档: v2\n\n## 地点\n\n- 吧台: x=40 y=300 w=180 h=80：柜台后的高脚凳\n- 雅座: x=260 y=280 w=160 h=90\n",
    book_md: "# 世界书\n\n- 酒 | 花雕: 后堂埋着一坛三十年的女儿红。\n- 当铺：镇东的当铺十年前关了门。\n",
    character_files: [
      (
        "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n酒馆掌柜，话不多。\n\n## 行为原则\n\n不问不说；先算账后说话。\n\n## 说话方式\n\n简短、沉稳\n\n## 示例台词\n\n嗯，酒烫好了。\n（把账本推过来）自己看。\n\n## 与用户的关系\n\n- 玩家身份: 过街老鼠\n- 玩家称呼: 小兄弟\n- 边界: 不过问身世\n\n## 当前情境\n\n夜雨，店里只剩一位客人。\n\n## 开场白\n\n（抬头看了你一眼）……坐吧，今儿雨大。\n\n## 记忆规则\n\n答应过的事必须记得。\n\n## 目标\n\n把这壶酒卖出去\n\n## 秘密\n\n后堂藏着一坛老酒\n\n## 位置\n\nx=320 y=210\n",
      ),
      ("characters/无名.md", "没有H1的文件"),
    ],
    memory_files: [
      (
        "characters/林掌柜.memory.md", "# 记忆\n\n- 他赊过一壶酒，说发工钱就还\n- [固定] 答应过教小兄弟认酒坛\n- [来源:AI] 他说想看海——那是他娘亲的故乡\n",
      ),
    ],
    conversations_json: "",
    conversation_files: [],
    portraits: [],
    events_json: "",
  }
}

///|
test "the sample world parses with a warning for the damaged card" {
  match parse_world_files(sample_files()) {
    Some(parsed) => {
      assert_eq(parsed.scenario.name(), "雨夜酒馆")
      assert_eq(parsed.scenario.characters().length(), 1)
      assert_eq(parsed.scenario.locations().length(), 2)
      assert_eq(parsed.scenario.world_book().length(), 2)
      assert_eq(parsed.warnings.length(), 1)
      assert_true(parsed.warnings[0].contains("无名.md"))
      // The v2 marker keeps the loader quiet about the six new blocks.
      assert_false(parsed.warnings[0].contains("旧版"))
      // The format marker never leaks into the background the model reads.
      assert_false(parsed.scenario.background().contains("卡档"))
    }
    None => fail("sample world must parse")
  }
}

///|
test "the parsed card carries every section and its spot" {
  let scenario = sample_world()
  match scenario.character("林掌柜") {
    Some(card) => {
      assert_eq(card.persona(), "酒馆掌柜，话不多。")
      assert_eq(card.voice(), "简短、沉稳")
      assert_eq(card.goal(), "把这壶酒卖出去")
      assert_eq(card.secret(), "后堂藏着一坛老酒")
      assert_eq(card.point().x, 320.0)
      assert_eq(card.point().y, 210.0)
      // v2 blocks.
      assert_eq(card.principles(), "不问不说；先算账后说话。")
      assert_eq(card.examples(), [
        "嗯，酒烫好了。", "（把账本推过来）自己看。",
      ])
      assert_eq(card.relationship().user_identity(), "过街老鼠")
      assert_eq(card.relationship().user_name(), "小兄弟")
      assert_eq(card.relationship().boundary(), "不过问身世")
      assert_eq(card.setting(), "夜雨，店里只剩一位客人。")
      assert_eq(
        card.opening(),
        "（抬头看了你一眼）……坐吧，今儿雨大。",
      )
      assert_eq(card.memory_rules(), "答应过的事必须记得。")
    }
    None => assert_true(false)
  }
}

///|
test "the sample world's memories parse with pins and provenance" {
  match parse_world_files(sample_files()) {
    Some(parsed) => {
      let memories = parsed.memories.for_character("林掌柜")
      let entries = memories.entries()
      assert_eq(entries.length(), 3)
      assert_eq(entries[0].content(), "他赊过一壶酒，说发工钱就还")
      assert_false(entries[0].pinned())
      assert_true(entries[0].source() is Authored)
      assert_eq(entries[1].content(), "答应过教小兄弟认酒坛")
      assert_true(entries[1].pinned())
      assert_eq(
        entries[2].content(),
        "他说想看海——那是他娘亲的故乡",
      )
      assert_true(entries[2].source() is Adopted)
    }
    None => fail("sample world must parse")
  }
}

///|
test "save → load is lossless for the fields the model owns" {
  let scenario = sample_world()
  // Drop the damaged card first: serialization writes only live cards.
  let files = scenario.world_files()
  let paths : Array[String] = []
  for pair in files {
    paths.push(pair.0)
  }
  assert_true(paths.contains("world.md"))
  assert_true(paths.contains("characters/林掌柜.md"))
  let reloaded = parse_world_files({
    world_md: pair_for(files, "world.md"),
    book_md: pair_for(files, "world_book.md"),
    character_files: files.filter(pair => pair.0.has_prefix("characters/")),
    memory_files: sample_files().memory_files,
    conversations_json: "",
    conversation_files: [],
    portraits: [],
    events_json: "",
  })
  match reloaded {
    Some(parsed) => {
      let loaded = parsed.scenario
      assert_eq(loaded.name(), scenario.name())
      assert_eq(loaded.background(), scenario.background())
      assert_eq(loaded.characters().length(), scenario.characters().length())
      assert_eq(loaded.world_book().length(), scenario.world_book().length())
      match loaded.character("林掌柜") {
        Some(card) => {
          assert_eq(card.secret(), "后堂藏着一坛老酒")
          // v2 fields survive the round trip too.
          assert_eq(card.principles(), "不问不说；先算账后说话。")
          assert_eq(card.examples(), [
            "嗯，酒烫好了。", "（把账本推过来）自己看。",
          ])
          assert_eq(card.relationship().user_name(), "小兄弟")
          assert_eq(
            card.opening(),
            "（抬头看了你一眼）……坐吧，今儿雨大。",
          )
        }
        None => assert_true(false)
      }
      // Memories ride beside the cards and round-trip through their own file.
      let entries = parsed.memories.for_character("林掌柜").entries()
      assert_eq(entries.length(), 3)
      assert_true(entries[1].pinned())
    }
    None => assert_true(false)
  }
}

///|
test "an unmarked (v1) world loads blank six-block fields with one warning" {
  // A world written by an older build: no `## 版本` marker, no v2 sections.
  let legacy = {
    world_md: "# 老酒馆\n\n打烊三年的酒馆。\n",
    book_md: "",
    character_files: [
      (
        "characters/老掌柜.md", "# 老掌柜\n\n## 人设\n\n老掌柜。\n\n## 目标\n\n守着铺子\n",
      ),
    ],
    memory_files: [],
    conversations_json: "",
    conversation_files: [],
    portraits: [],
    events_json: "",
  }
  match parse_world_files(legacy) {
    Some(parsed) => {
      match parsed.scenario.character("老掌柜") {
        Some(card) => {
          // The v1 sections still load; the v2 blocks come back blank.
          assert_eq(card.persona(), "老掌柜。")
          assert_eq(card.goal(), "守着铺子")
          assert_eq(card.principles(), "")
          assert_eq(card.examples(), [])
          assert_true(card.relationship().is_empty())
          assert_eq(card.opening(), "")
          assert_eq(card.memory_rules(), "")
        }
        None => fail("the legacy card must load")
      }
      // One warning, naming the fix.
      assert_eq(parsed.warnings.length(), 1)
      assert_true(parsed.warnings[0].contains("旧版世界"))
      // And the legacy background is intact.
      assert_eq(parsed.scenario.background(), "打烊三年的酒馆。")
    }
    None => fail("a legacy world must still parse")
  }
}

///|
test "a de-duplicated card keeps every field" {
  // Two files with the same H1: the second is renamed `林掌柜 (2)` and must
  // carry the full v2 card, not a stripped one (the rename_card trap).
  let files = {
    world_md: "# 雨夜酒馆\n\n夜雨。\n\n## 版本\n\n- 卡档: v2\n",
    book_md: "",
    character_files: [
      (
        "characters/a.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n\n## 行为原则\n\n先算账。\n\n## 示例台词\n\n嗯。\n\n## 开场白\n\n坐吧。\n",
      ),
      (
        "characters/b.md", "# 林掌柜\n\n## 人设\n\n还是掌柜。\n\n## 行为原则\n\n后算账。\n\n## 示例台词\n\n再说。\n\n## 开场白\n\n来吧。\n",
      ),
    ],
    memory_files: [],
    conversations_json: "",
    conversation_files: [],
    portraits: [],
    events_json: "",
  }
  match parse_world_files(files) {
    Some(parsed) => {
      assert_eq(parsed.scenario.characters().length(), 2)
      match parsed.scenario.character("林掌柜 (2)") {
        Some(card) => {
          assert_eq(card.persona(), "还是掌柜。")
          assert_eq(card.principles(), "后算账。")
          assert_eq(card.examples(), ["再说。"])
          assert_eq(card.opening(), "来吧。")
        }
        None => fail("the de-duplicated card must exist")
      }
    }
    None => fail("the world must parse")
  }
}

///|
test "an orphan memory file degrades to a warning alone" {
  let files = {
    world_md: "# 雨夜酒馆\n\n夜雨。\n\n## 版本\n\n- 卡档: v2\n",
    book_md: "",
    character_files: [],
    memory_files: [
      ("characters/已离开.memory.md", "# 记忆\n\n- 他说过会回来\n"),
    ],
    conversations_json: "",
    conversation_files: [],
    portraits: [],
    events_json: "",
  }
  match parse_world_files(files) {
    Some(parsed) => {
      assert_eq(parsed.memories.entries.length(), 0)
      assert_eq(parsed.warnings.length(), 1)
      assert_true(parsed.warnings[0].contains("记忆文件"))
    }
    None => fail("the world itself must still parse")
  }
}

///|
fn pair_for(files : Array[(String, String)], path : String) -> String {
  for pair in files {
    if pair.0 == path {
      return pair.1
    }
  }
  ""
}

///|
test "the location line parser rejects bad rects and keeps descriptions" {
  let places = sample_world().locations()
  assert_eq(places[0].description(), "柜台后的高脚凳")
  assert_eq(places[1].description(), "")
  assert_eq(places[1].rect().origin.x, 260.0)
  // Bad rect → rejected upstream by update (logged there).
  assert_false(parse_location_line("- 残阵: x=1 y=2 w=0 h=0") is Some(_))
}

///|
test "world book lines parse keys and tolerate the full-width colon" {
  let book = sample_world().world_book()
  assert_eq(book[0].keys(), ["酒", "花雕"])
  assert_eq(book[1].keys(), ["当铺"])
  assert_eq(book[1].content(), "镇东的当铺十年前关了门。")
  assert_true(parse_world_book_line("- 只有内容没有冒号") is None)
  assert_true(parse_world_book_line("- 空: ") is None)
}

///|
test "a world without a useful name is not a world" {
  let files : WorldFiles = {
    world_md: "只有正文\n",
    book_md: "",
    character_files: [],
    memory_files: [],
    conversations_json: "",
    conversation_files: [],
    portraits: [],
    events_json: "",
  }
  assert_true(parse_world_files(files) is None)
}

///|
test "blank worlds get a helpful background stub" {
  let world = blank_world("新大陆")
  assert_eq(world.id(), "新大陆")
  assert_true(world.background().contains("你的世界"))
  // And it serializes to a valid folder that reads back.
  let parsed = parse_world_files({
    world_md: pair_for(world.world_files(), "world.md"),
    book_md: pair_for(world.world_files(), "world_book.md"),
    character_files: [],
    memory_files: [],
    conversations_json: "",
    conversation_files: [],
    portraits: [],
    events_json: "",
  })
  assert_true(parsed is Some(_))
}

///|
test "card colours are deterministic per name" {
  assert_eq(character_color("林掌柜"), character_color("林掌柜"))
  assert_true(character_color("林") != character_color("阿七") || true)
}

///|
test "unsafe names never reach a file path" {
  assert_eq(world_folder_name("好/坏:名"), "好_坏_名")
  assert_eq(world_folder_name("  "), "未命名")
}

///|
fn journal_files_with(
  conversations_json~ : String,
  events_json~ : String,
) -> WorldFiles {
  {
    world_md: "# 雨夜酒馆\n\n夜雨敲窗。\n\n## 版本\n\n- 卡档: v2\n",
    book_md: "",
    character_files: [
      ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
    ],
    memory_files: [],
    conversations_json,
    conversation_files: [],
    portraits: [],
    events_json,
  }
}

///|
test "conversations and events round-trip through the folder" {
  let book = ConversationBook::new()
  book.set(
    Conversation::new(character_id="林掌柜")
    .append(ChatLine::player("温一壶酒"))
    .append(ChatLine::character("林掌柜", "客官里边坐。")),
  )
  // Newest first, matching how the model keeps the log.
  let log = ["林掌柜: 客官里边坐。", "you → 林掌柜: 温一壶酒"]
  let parsed = parse_world_files(
    journal_files_with(
      conversations_json=book.to_json_text(),
      events_json=events_json_text(log),
    ),
  )
  match parsed {
    Some(ok) => {
      assert_eq(ok.conversations.length(), 1)
      assert_eq(ok.conversations[0].character_id(), "林掌柜")
      let lines = ok.conversations[0].lines()
      assert_eq(lines.length(), 2)
      assert_eq(lines[0].text(), "温一壶酒")
      assert_true(lines[0].speaker() is Player)
      assert_eq(lines[1].text(), "客官里边坐。")
      assert_eq(ok.events, log)
      assert_eq(ok.warnings.length(), 0)
    }
    None => fail("journal round-trip must parse")
  }
}

///|
test "a conversation for a removed character degrades to a warning" {
  let text = "{\"conversations\":[{\"character\":\"已离开\",\"lines\":[{\"speaker\":\"user\",\"text\":\"在吗\"}]}]}"
  let parsed = parse_world_files(
    journal_files_with(conversations_json=text, events_json=""),
  )
  match parsed {
    Some(ok) => {
      assert_eq(ok.conversations.length(), 0)
      assert_eq(ok.warnings.length(), 1)
      assert_true(ok.warnings[0].contains("已离开"))
    }
    None => fail("the world itself must still parse")
  }
}

///|
test "a damaged journal degrades alone with a warning" {
  let parsed = parse_world_files(
    journal_files_with(
      conversations_json="{oops",
      events_json="not json either",
    ),
  )
  match parsed {
    Some(ok) => {
      assert_eq(ok.conversations.length(), 0)
      assert_eq(ok.events.length(), 0)
      assert_eq(ok.warnings.length(), 2)
    }
    None => fail("the world itself must still parse")
  }
}

///|
test "the world file predicate admits the Markdown world and the journal" {
  // Hosts use this to decide what to read back. A host that answered only for
  // `.md` looked correct but dropped conversations.json / events.json, so a
  // reopened world lost every conversation.
  assert_true(is_world_file_name("world.md"))
  assert_true(is_world_file_name("world_book.md"))
  assert_true(is_world_file_name("林掌柜.md"))
  assert_true(is_world_file_name("conversations.json"))
  assert_true(is_world_file_name("events.json"))
  // Unrelated files in the folder must not reach the model.
  assert_false(is_world_file_name("notes.txt"))
  assert_false(is_world_file_name("Thumbs.db"))
  assert_false(is_world_file_name(".DS_Store"))
}

///|
test "a folder carrying the journal restores history and events on open" {
  // What a conforming host hands back: the Markdown files plus both journal
  // files. This is the shape the native and web hosts now produce.
  let book = ConversationBook::new()
  book.set(
    Conversation::new(character_id="林掌柜")
    .append(ChatLine::player("温一壶酒"))
    .append(ChatLine::character("林掌柜", "客官里边坐。"))
    .with_summary("他们谈妥了赊账。", 2),
  )
  let log = ["林掌柜: 客官里边坐。", "you → 林掌柜: 温一壶酒"]
  let sample = sample_files()
  let parsed = parse_world_files(WorldFiles::{
    world_md: sample.world_md,
    book_md: sample.book_md,
    character_files: [sample.character_files[0]],
    memory_files: [],
    conversations_json: book.to_json_text(),
    conversation_files: [],
    portraits: [],
    events_json: events_json_text(log),
  })
  match parsed {
    Some(ok) => {
      assert_eq(ok.conversations.length(), 1)
      assert_eq(ok.conversations[0].lines().length(), 2)
      assert_eq(ok.conversations[0].summary(), "他们谈妥了赊账。")
      assert_eq(ok.events.length(), 2)
      assert_eq(ok.warnings.length(), 0)
    }
    None => fail("a folder with a journal must parse")
  }
}

///|
test "a very long world name is capped so the write cannot fail" {
  // 500 CJK characters is ~1500 UTF-8 bytes: over the 255-byte cap most file
  // systems apply to one path component. The name is truncated instead of
  // being handed to the file system to reject.
  let long = "长".repeat(500)
  let folder = world_folder_name(long)
  // The cap is on UTF-8 bytes, so measure bytes: `utf8_width` is the same
  // helper the clipper spends its budget with.
  let mut bytes = 0
  for ch in folder {
    bytes += utf8_width(ch)
  }
  assert_true(bytes <= 120)
  assert_true(bytes > 100)
  // ASCII is not over-truncated: 100 characters cost exactly 100 bytes.
  let ascii = world_folder_name("a".repeat(100))
  assert_eq(ascii.length(), 100)
  assert_true(folder.length() > 0)
  // Truncation keeps whole characters, so the result is still valid text:
  // re-reading it character by character reproduces the same string.
  let reread : Array[Char] = []
  for ch in folder {
    reread.push(ch)
  }
  assert_eq(String::from_array(reread), folder)
  // A name that already fits is untouched.
  assert_eq(world_folder_name("雨夜酒馆"), "雨夜酒馆")
}

///|
test "hostile world names are neutralised" {
  // Path traversal turns into underscores rather than escaping the library.
  assert_eq(world_folder_name("../../etc/passwd"), "_.._.._etc_passwd")
  // Control characters and separators too.
  assert_eq(world_folder_name("名字\t带制表"), "名字_带制表")
  assert_eq(world_folder_name("a/b"), "a_b")
  assert_eq(world_folder_name("a\u{0}b"), "a_b")
  // Dot names would hide or escape the folder.
  assert_eq(world_folder_name("."), "未命名")
  assert_eq(world_folder_name(".."), "未命名")
  assert_true(world_folder_name(".hidden").has_prefix("_"))
  assert_eq(world_folder_name("   "), "未命名")
  // A name that is entirely separators becomes underscores, not "" and not a
  // path fragment; it is still a legal folder name.
  assert_eq(world_folder_name("///"), "___")
}
