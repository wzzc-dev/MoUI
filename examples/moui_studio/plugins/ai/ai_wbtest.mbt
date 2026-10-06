///|
/// AI 插件测试：多会话互不串线（M3 验收①）——切换/新建/删除的隔离语义。

///|
/// 造一个带内容的会话切片：会话 0 有点名草稿与卡片，会话 1 空。
fn seeded_sessions() -> AiSessions {
  let sessions = AiSessions::new()
  sessions.current().cards.push(AiCard::{
    kind: CardPlan,
    title: "计划",
    body: "先加按钮",
    steps: ["加按钮"],
    steps_done: 1,
    progress: 100,
    diff_lines: [],
    settled: true,
    settled_note: "",
    seq: 1,
  })
  sessions.amend({
    ..sessions.current(),
    prompt_draft: "帮我做一个点名册",
    card_seq: 1,
  })
  sessions
}

///|
test "ai sessions start with one empty default session" {
  let sessions = AiSessions::new()
  assert_eq(sessions.count(), 1)
  assert_eq(sessions.active_index(), 0)
  assert_eq(sessions.current().cards.length(), 0)
  assert_eq(sessions.current().prompt_draft, "")
}

///|
test "ai session switch isolates drafts and cards" {
  let sessions = seeded_sessions()
  // 新建：切到空会话
  let created = sessions.create()
  assert_eq(created, 1)
  assert_eq(sessions.current().prompt_draft, "")
  assert_eq(sessions.current().cards.length(), 0)
  // 新会话里写草稿 + 推卡（标量经 amend 重建；数组共享引用可直接 push）
  sessions.amend({
    ..sessions.current(),
    prompt_draft: "第二个会话的问题",
    card_seq: 1,
  })
  sessions.current().cards.push(AiCard::{
    kind: CardExplanation,
    title: "讲解",
    body: "解释",
    steps: [],
    steps_done: 0,
    progress: 0,
    diff_lines: [],
    settled: true,
    settled_note: "",
    seq: 1,
  })
  // 切回会话 0：原内容原样在（互不串线）
  assert_true(sessions.switch(0))
  assert_eq(sessions.current().prompt_draft, "帮我做一个点名册")
  assert_eq(sessions.current().cards.length(), 1)
  assert_eq(sessions.current().cards[0].body, "先加按钮")
  // 再切回来：第二个会话的内容也在
  assert_true(sessions.switch(1))
  assert_eq(sessions.current().prompt_draft, "第二个会话的问题")
  assert_eq(sessions.current().cards.length(), 1)
  assert_eq(sessions.current().cards[0].body, "解释")
}

///|
test "ai session remove follows the remove-project convention" {
  // 删当前（0）→ 落到同位的下一个（原会话 1 成为新 0）
  let sessions = seeded_sessions()
  let _ = sessions.create()
  sessions.amend({ ..sessions.current(), prompt_draft: "第二", })
  let _ = sessions.switch(0)
  sessions.remove(0)
  assert_eq(sessions.count(), 1)
  assert_eq(sessions.active_index(), 0)
  assert_eq(sessions.current().prompt_draft, "第二")
  // 删前面的 → 指针左移（仍指向切换时的那个会话：原会话 4）
  let _ = sessions.create()
  let _ = sessions.create()
  let _ = sessions.switch(2)
  sessions.remove(0)
  assert_eq(sessions.active_index(), 1)
  assert_eq(sessions.current().prompt_draft, "")
  // 剩余顺序保持：0 = 原会话 3（未动过）
  match sessions.session_at(0) {
    Some(session) => assert_eq(session.title, "会话 3")
    None => fail("session 0 should exist")
  }
  // 删最后一个 → 重建全新会话（列表永不为空，composer 永有落点）
  sessions.remove(0)
  sessions.remove(0)
  assert_eq(sessions.count(), 1)
  assert_eq(sessions.current().prompt_draft, "")
  // 重建续名（单调序号，不与历史重名）
  assert_eq(sessions.current().title, "会话 5")
  // 越界删除：no-op
  sessions.remove(5)
  assert_eq(sessions.count(), 1)
}

///|
test "ai session feature update handles the three ops" {
  let (state, effect) = ai_sessions_feature().runtime_init()
  assert_eq(state.count(), 1)
  assert_no_effect_ai(effect)
  let (state, effect) = state.update(AiSessionCreate)
  assert_eq(state.count(), 2)
  assert_eq(state.active_index(), 1)
  let (state, effect) = state.update(AiSessionSwitch(0))
  assert_eq(state.active_index(), 0)
  let (state, effect) = state.update(AiSessionRemove(0))
  assert_eq(state.count(), 1)
  assert_eq(state.active_index(), 0)
  assert_no_effect_ai(effect)
  // 列表投影：名 + 当前高亮
  let entries = state.list_entries()
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].2, true)
}

///|
fn assert_no_effect_ai(effect : @moui.Effect[AiSessionMsg]) -> Unit {
  match effect {
    @moui.Effect::NoEffect => ()
    _ => abort("expected NoEffect")
  }
}

///|
test "fake stream chunks are deterministic and cover the whole text" {
  let chunks = fake_stream_chunks("abcdefghij", 3)
  assert_eq(chunks.length(), 4)
  assert_eq(chunks[0], "abc")
  assert_eq(chunks[3], "j")
  // 同一文本永远同一序列
  let again = fake_stream_chunks("abcdefghij", 3)
  assert_eq(chunks, again)
  // 空文本 → 零分片
  assert_eq(fake_stream_chunks("", 3).length(), 0)
}

///|
test "ai session append_to_last_card only touches the last card" {
  let sessions = seeded_sessions()
  let before = sessions.current().cards[0].body
  sessions.current().cards.push(AiCard::{
    kind: CardExplanation,
    title: "讲解",
    body: "",
    steps: [],
    steps_done: 0,
    progress: 0,
    diff_lines: [],
    settled: false,
    settled_note: "",
    seq: 2,
  })
  sessions.append_to_last_card("增量一")
  sessions.append_to_last_card("增量二")
  // 最后一张（流式卡）追加了两个分片
  assert_eq(sessions.current().cards[1].body, "增量一增量二")
  // 前面的卡零改动
  assert_eq(sessions.current().cards[0].body, before)
  // 空线程（0 张卡）：追加是安全 no-op（不凭空造卡，流式卡由调用方推入）
  let empty = AiSessions::new()
  empty.append_to_last_card("x")
  assert_eq(empty.current().cards.length(), 0)
}
