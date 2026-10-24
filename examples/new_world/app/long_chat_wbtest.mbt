///|
/// A conversation that outlives the history cap.
///
/// The cap plus the rolling summary is the one feature whose absence is only
/// visible after dozens of turns: without it the character silently forgets the
/// opening of the story, or the prompt grows without bound. These tests hold the
/// continuity contract at the boundary.

///|
test "the history stays capped however many turns are played" {
  let mut model = step(crowded_world(), ApiKeyChanged("sk-test"))
  model = step(model, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
  for turn in 0..<40 {
    let (asked, _e) = update(model, Send("第 \{turn} 句"), turn_runner=never)
    let (replied, _r) = update(
      asked,
      Reply("林掌柜", Some("回 \{turn}")),
      turn_runner=never,
    )
    model = replied
  }
  let conversation = model.conversations.for_character("林掌柜")
  // The cap is a hard bound on what is kept, not a hint.
  assert_true(conversation.lines().length() <= chat_history_limit)
  // And the newest turn is still there: truncation must drop the oldest, never
  // the line the player just wrote.
  let last = conversation.lines()[conversation.lines().length() - 1]
  assert_eq(last.text(), "回 39")
  // The counter keeps counting past the cap, because the compression trigger
  // measures how much new material arrived.
  assert_true(conversation.appended() > conversation.lines().length())
}

///|
test "a compaction request only asks for lines the summary does not cover" {
  // The compression source must exclude the recent window, or the summary would
  // repeat what the prompt still shows verbatim.
  let mut conversation = Conversation::new(character_id="林掌柜")
  for index in 0..<30 {
    conversation = conversation.append(ChatLine::player("第 \{index} 句"))
  }
  let source = compression_source(conversation)
  assert_true(source.length() > 0)
  // `compression_source` returns ChatLines, so compare their text.
  let texts : Array[String] = []
  for line in source {
    texts.push(line.text())
  }
  let joined = texts.join("\n")
  // The newest lines must not be in the source: the prompt still shows them
  // verbatim, and folding them in would duplicate them.
  assert_false(joined.contains("第 29 句"))
  assert_false(joined.contains("第 28 句"))
  // An older line must be.
  assert_true(joined.contains("第 0 句"))
  // Exactly `length - summary_keep_recent` lines are handed over.
  assert_eq(source.length(), 30 - summary_keep_recent)
}

///|
test "compression is not requested twice for the same material" {
  // The trigger needs the history to be under pressure: at least
  // `chat_history_limit - summary_keep_recent` lines (60 - 10 = 50) or an
  // eviction. Using fewer lines here made the first assertion fail — the code
  // was right and the fixture was wrong.
  let mut conversation = Conversation::new(character_id="林掌柜")
  for index in 0..<55 {
    conversation = conversation.append(ChatLine::player("第 \{index} 句"))
  }
  // Under pressure, with plenty of uncovered lines: yes.
  assert_true(needs_compression(conversation, 0))
  // After a successful compaction covering everything, no: the summary is fresh
  // and asking again would burn a provider call for nothing.
  let compacted = conversation.with_summary(
    "覆盖了全部。",
    conversation.appended(),
  )
  assert_false(needs_compression(compacted, 0))
  // A few more turns after that do not immediately re-trigger either:
  // `summary_min_new_lines` (10) new lines are required first.
  let mut later = compacted
  for index in 0..<5 {
    later = later.append(ChatLine::player("新 \{index}"))
  }
  assert_false(needs_compression(later, 0))
  // Once enough new material accumulates, it does.
  let mut plenty = later
  for index in 0..<10 {
    plenty = plenty.append(ChatLine::player("更多 \{index}"))
  }
  assert_true(needs_compression(plenty, 0))
}

///|
test "the summary survives the 60-line cap trimming the original lines away" {
  // The point of the summary is continuity after the lines are gone, so it must
  // reach the prompt even when none of its source lines are still retained.
  let mut conversation = Conversation::new(character_id="林掌柜")
  for index in 0..<40 {
    conversation = conversation.append(ChatLine::player("旧 \{index}"))
  }
  conversation = conversation.with_summary(
    "开头他们约定在雨夜见面。", 30,
  )
  let card = crowded_world().scenario().character("林掌柜").unwrap()
  let plan = plan_messages(
    crowded_world().scenario(),
    card,
    conversation,
    "现在呢",
  )
  let joined : Array[String] = []
  for message in plan.messages {
    joined.push(message.1)
  }
  let text = joined.join("\n")
  assert_true(text.contains("开头他们约定在雨夜见面。"))
}

///|
test "a scene conversation is capped by the same rule" {
  // Scenes share the Conversation type, so the cap must apply there too —
  // otherwise a long scene grows without bound while private chats do not.
  let mut model = step(crowded_world(), ApiKeyChanged("sk-test"))
  model = step(model, EnterScene("吧台"))
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
  for turn in 0..<40 {
    let (asked, _e) = update(model, Send("说 \{turn}"), turn_runner=never)
    let (replied, _r) = update(
      asked,
      SceneReply(scene_key("吧台"), "林掌柜", Some("答 \{turn}")),
      turn_runner=never,
    )
    model = replied
  }
  let conversation = model.conversations.for_character(scene_key("吧台"))
  assert_true(conversation.lines().length() <= chat_history_limit)
  let last = conversation.lines()[conversation.lines().length() - 1]
  assert_eq(last.text(), "答 39")
}

///|
test "a long conversation with memories still fits the budget" {
  // The memory layer rides between the system prompt and the summary, so a
  // chatty memory book must not push the request past the budget: the newest
  // line is reserved, the rest is trimmed, and the total stays bounded.
  let scenario = Scenario::new(id="t", name="t", background="b", characters=[
    CharacterCard::new(id="lin", name="林", persona="p"),
  ])
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let mut conversation = Conversation::new(character_id="lin")
  let mut index = 0
  while index < 60 {
    conversation = conversation.append(
      ChatLine::player(
        "第 \{index} 句，一句相当长的话用来占满小小的预算，像真的聊了很久。",
      ),
    )
    index += 1
  }
  let memories : Array[MemoryEntry] = []
  let mut m = 0
  while m < 12 {
    memories.push(MemoryEntry::authored("第 \{m} 条记忆，一条不太短的事实。"))
    m += 1
  }
  let plan = plan_messages(
    scenario,
    card,
    conversation,
    "你好",
    budget=1200,
    memories=select_memories(memories, "你好"),
  )
  let mut total = 0
  for message in plan.messages {
    total += message.0.length() + message.1.length()
  }
  assert_true(total <= 1200)
  // The layered transcript bound: only the recent window renders Markdown,
  // so the viewer count stays small even at the cap.
  assert_true(markdown_recent_lines < chat_history_limit)
}

///|
test "a three-hundred-line conversation only builds the window" {
  // The transcript is windowed: a long run must cost the same as a short one,
  // or the app slowly becomes unusable exactly when the player is most
  // invested. The older lines stay one click away.
  let mut conversation = Conversation::new(character_id="林掌柜")
  for index in 0..<300 {
    conversation = conversation.append(
      ChatLine::player("第 \{index} 句"),
    )
    conversation = conversation.append(
      ChatLine::character("林掌柜", "回 \{index}"),
    )
  }
  let model = step(crowded_world(), Select(Some("林掌柜")))
  let with_history = {
    ..model,
    conversations: {
      entries: [
        {
          ..conversation,
        },
      ],
    },
  }
  // Three hundred turns do not accumulate: the conversation keeps its capped
  // window of raw lines (the rest lives in the rolling summary), and the
  // transcript shows only part of that.
  assert_true(conversation.lines().length() <= chat_history_limit)
  let screen = Screen::for_viewport(1600.0, 900.0)
  let view = view_for(with_history, screen)
  // The window is on screen: the lines before it are not built, and the reader
  // is told how many there are.
  let older = conversation.lines().length() - transcript_window_default
  assert_true(older > 0)
  assert_true(
    tree_has_text(view, "更早的对话（还有 " + older.to_string() + " 条）"),
  )
  assert_false(tree_has_text(view, "第 0 句"))
  // The newest lines are.
  assert_true(tree_has_text(view, "第 299 句"))
  // And revealing more grows the window instead of rebuilding everything.
  let wider = step(with_history, ExtendTranscript(transcript_window_step))
  assert_true(wider.transcript_window() > with_history.transcript_window())
}
