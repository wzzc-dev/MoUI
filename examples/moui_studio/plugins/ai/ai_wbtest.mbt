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
    at: 0,
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
  let created = sessions.create(0)
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
    at: 0,
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
  let _ = sessions.create(0)
  sessions.amend({ ..sessions.current(), prompt_draft: "第二", })
  let _ = sessions.switch(0)
  sessions.remove(0)
  assert_eq(sessions.count(), 1)
  assert_eq(sessions.active_index(), 0)
  assert_eq(sessions.current().prompt_draft, "第二")
  // 删前面的 → 指针左移（仍指向切换时的那个会话：原会话 4）
  let _ = sessions.create(0)
  let _ = sessions.create(0)
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
  let (state, _) = state.update(AiSessionCreate(0))
  assert_eq(state.count(), 2)
  assert_eq(state.active_index(), 1)
  let (state, _) = state.update(AiSessionSwitch(0))
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
    at: 0,
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

///|
test "ai session rename pin and touch operate by index" {
  let sessions = AiSessions::fresh(1)
  let _ = sessions.create(0)
  // 改名 + 置顶：按下标生效
  assert_true(sessions.rename(0, "点名册讨论"))
  assert_true(sessions.set_pinned(0, true))
  match sessions.session_at(0) {
    Some(session) => {
      assert_eq(session.title, "点名册讨论")
      assert_true(session.pinned)
    }
    None => fail("会话 0 应存在")
  }
  match sessions.session_at(1) {
    Some(session) => {
      assert_eq(session.title, "会话 2")
      assert_false(session.pinned)
    }
    None => fail("会话 1 应存在")
  }
  // 越界：no-op 返回 false
  assert_false(sessions.rename(9, "x"))
  assert_false(sessions.set_pinned(9, true))
  // touch 只盖当前会话
  let _ = sessions.switch(1)
  sessions.touch(1234)
  let zero_updated = match sessions.session_at(0) {
    Some(s) => s.updated
    None => -1
  }
  let one_updated = match sessions.session_at(1) {
    Some(s) => s.updated
    None => -1
  }
  assert_eq(one_updated, 1234)
  assert_eq(zero_updated, 0)
}

///|
test "ai session update handles rename and pin messages" {
  let (state, _) = ai_sessions_feature().runtime_init()
  let (state, _) = state.update(AiSessionRename(0, "重命名"))
  assert_eq(state.current().title, "重命名")
  let (state, effect) = state.update(AiSessionPin(0, true))
  assert_true(state.current().pinned)
  assert_no_effect_ai(effect)
}

///|
test "ai session defaults carry new fields" {
  let sessions = AiSessions::new()
  let session = sessions.current()
  assert_eq(session.project, "")
  assert_false(session.pinned)
  assert_eq(session.updated, 0)
}

///|
test "ai sessions codec round trips the full container" {
  let sessions = AiSessions::fresh(1)
  let _ = sessions.create(0)
  let _ = sessions.rename(0, "点名册讨论")
  let _ = sessions.set_pinned(0, true)
  // 卡与历史推给会话 0（先切回去；create 已把 active 指向会话 1）
  let _ = sessions.switch(0)
  sessions.current().cards.push(AiCard::{
    kind: CardUserPrompt,
    title: "",
    body: "帮我做一个随机点名册",
    steps: [],
    steps_done: 0,
    progress: 0,
    diff_lines: [],
    settled: true,
    settled_note: "",
    seq: 1,
    at: 1799366640,
  })
  sessions.current().cards.push(AiCard::{
    kind: CardDiff,
    title: "两处改动",
    body: "2 处变更",
    steps: [],
    steps_done: 0,
    progress: 100,
    diff_lines: [("+", "form.mbt +1"), ("-", "handlers.mbt -2")],
    settled: false,
    settled_note: "",
    seq: 2,
    at: 1799366650,
  })
  sessions.current().proposal_history.push(ProposalRecord::{
    summary: "点名册",
    diff: [
      @proposals.DiffEntry::{
        op: @proposals.Added,
        path: "controls.按钮.text",
        old_text: "",
        new_text: "点我",
      },
    ],
    code_diff: [("+", "pub fn on_click() {}")],
    accepted: true,
    seq: 1,
  })
  let _ = sessions.switch(1)
  sessions.amend({ ..sessions.current(), project: "examples/counter", })
  sessions.touch(1799366700)
  let encoded = encode_ai_sessions(sessions)
  match decode_ai_sessions(encoded) {
    Ok(decoded) => {
      assert_eq(decoded.count(), 2)
      assert_eq(decoded.seq, sessions.seq)
      assert_eq(decoded.active_index(), 1)
      match decoded.session_at(0) {
        Some(session) => {
          assert_eq(session.title, "点名册讨论")
          assert_true(session.pinned)
          assert_eq(session.cards.length(), 2)
          assert_true(session.cards[0].kind is CardUserPrompt)
          assert_eq(session.cards[0].at, 1799366640)
          assert_eq(session.cards[1].diff_lines.length(), 2)
          assert_eq(session.proposal_history.length(), 1)
          assert_true(session.proposal_history[0].accepted)
        }
        None => fail("会话 0 应存在")
      }
      match decoded.session_at(1) {
        Some(session) => {
          assert_eq(session.project, "examples/counter")
          assert_eq(session.updated, 1799366700)
        }
        None => fail("会话 1 应存在")
      }
    }
    Err(_) => fail("往返解码应成功")
  }
}

///|
test "ai sessions codec rejects bad json format and unknown versions" {
  match decode_ai_sessions("{{{不是 JSON") {
    Err(StoreBadJson) => ()
    _ => fail("坏 JSON 应报 StoreBadJson")
  }
  match decode_ai_sessions("{\"version\": 1}") {
    Err(StoreBadFormat) => ()
    _ => fail("缺 format 应报 StoreBadFormat")
  }
  match
    decode_ai_sessions(
      "{\"format\": \"moui.studio.ai-sessions\", \"version\": 99}",
    ) {
    Err(StoreBadVersion(99)) => ()
    _ => fail("未知版本应报 StoreBadVersion(99)")
  }
}

///|
test "ai sessions codec rebuilds fresh when the store is empty" {
  match
    decode_ai_sessions(
      "{\"format\": \"moui.studio.ai-sessions\", \"version\": 1, \"sessions\": []}",
    ) {
    Ok(container) => {
      assert_eq(container.count(), 1)
      assert_eq(container.current().cards.length(), 0)
    }
    Err(_) => fail("空存储应重建新会话")
  }
}
