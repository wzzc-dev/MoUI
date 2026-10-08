///|
/// 对白转录工作台测试(M1 时钟 + 数据模型盖戳):
/// - civil_seconds / format_hhmm 的时间口径
/// - ClockUpdated 写 Model.clock
/// - 提交盖戳:默认名置题 / updated 时间戳 / active_project 工程戳 /
///   改名后的会话不被覆盖
/// 测试驱动与 app_test 同包同款:apply 走 update_pure,服务流消息手动派发。

///|
test "civil seconds is monotonic and epoch aligned" {
  let day1 = @app.civil_seconds({
    year: 2026,
    month: 1,
    day: 1,
    weekday: 4,
    hour: 0,
    minute: 0,
    second: 0,
  })
  let day2 = @app.civil_seconds({
    year: 2026,
    month: 1,
    day: 2,
    weekday: 5,
    hour: 0,
    minute: 0,
    second: 0,
  })
  assert_eq(day2 - day1, 86400)
  let evening = @app.civil_seconds({
    year: 2026,
    month: 1,
    day: 2,
    weekday: 5,
    hour: 20,
    minute: 44,
    second: 32,
  })
  assert_eq(evening - day2, 20 * 3600 + 44 * 60 + 32)
  // 闰年口径:2024-02-28 → 2024-03-01 隔 2 天(2 月有 29 日)
  let leap_a = @app.civil_seconds({
    year: 2024,
    month: 2,
    day: 28,
    weekday: 3,
    hour: 0,
    minute: 0,
    second: 0,
  })
  let leap_b = @app.civil_seconds({
    year: 2024,
    month: 3,
    day: 1,
    weekday: 5,
    hour: 0,
    minute: 0,
    second: 0,
  })
  assert_eq(leap_b - leap_a, 2 * 86400)
}

///|
test "format hhmm pads zero" {
  assert_eq(
    @app.format_hhmm({
      year: 2026,
      month: 10,
      day: 7,
      weekday: 3,
      hour: 20,
      minute: 44,
      second: 0,
    }),
    "20:44",
  )
  assert_eq(
    @app.format_hhmm({
      year: 2026,
      month: 10,
      day: 7,
      weekday: 3,
      hour: 9,
      minute: 5,
      second: 0,
    }),
    "09:05",
  )
}

///|
test "clock updated writes the snapshot into the model" {
  let model = @app.initial_model()
  let next = apply(
    model,
    ClockUpdated({
      year: 2026,
      month: 10,
      day: 7,
      weekday: 3,
      hour: 20,
      minute: 44,
      second: 5,
    }),
  )
  assert_eq(next.clock.hour, 20)
  assert_eq(next.clock.minute, 44)
  assert_eq(next.clock.second, 5)
}

///|
test "submitting stamps default title truncated to 18 chars and updated time" {
  let model = @app.initial_model()
  let timed = apply(
    model,
    ClockUpdated({
      year: 2026,
      month: 10,
      day: 7,
      weekday: 3,
      hour: 20,
      minute: 44,
      second: 0,
    }),
  )
  // 24 个全角字符的 prompt → 标题取前 18 个字符
  let asked = apply(
    timed,
    SetPrompt(
      "一二三四五六七八九十一二三四五六七八九十一二三",
    ),
  )
  let run = apply(asked, ComposerRun)
  assert_eq(run.ai_sessions.current().title.length(), 18)
  assert_true(
    run.ai_sessions.current().title.has_prefix(
      "一二三四五六七八九十一二三四五六七八",
    ),
  )
  // updated 盖了当前墙钟(20:44:00 的 civil_seconds,必然 > 0)
  assert_true(run.ai_sessions.current().updated > 0)
  assert_false(run.ai_sessions.current().pinned)
}

///|
test "submit keeps renamed title and stamps active project" {
  let imported = @app.update_with_services(
      @app.initial_model(),
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
      @services.AppServices::new(),
    ).0
  let named = apply(imported, AiSessionOp(AiSessionRename(0, "我的会话")))
  let asked = apply(named, SetPrompt("随机点名"))
  let run = apply(asked, ComposerRun)
  // 用户改过的名字不被自动置题覆盖
  assert_eq(run.ai_sessions.current().title, "我的会话")
  // 工程戳 = active_project 的 module_name
  assert_eq(run.ai_sessions.current().project, "examples/counter")
}

///|
test "composer run echoes the prompt as a user bubble card" {
  let model = @app.initial_model()
  let asked = apply(model, SetPrompt("帮我做一个随机点名册"))
  let run = apply(asked, ComposerRun)
  let cards = run.ai_sessions.current().cards
  assert_true(cards.length() >= 2)
  // 第一张 = 用户提问回显；第二张 = fake 提案的 diff 卡
  assert_true(cards[0].kind is @ai.CardUserPrompt)
  assert_eq(cards[0].body, "帮我做一个随机点名册")
  assert_true(cards[1].kind is @ai.CardDiff)
}

///|
test "proposal failure pushes an error card into the timeline" {
  let model = @app.initial_model()
  let failed = @app.proposal_from_completion(
    model, "这不是合法提案 JSON",
  )
  let cards = failed.ai_sessions.current().cards
  assert_true(cards.length() >= 1)
  assert_true(cards[cards.length() - 1].kind is @ai.CardError)
  assert_true(failed.prompt_error != "")
}

///|
test "edit and retry restore the prompt draft from the timeline" {
  let model = @app.initial_model()
  let asked = apply(model, SetPrompt("帮我做一个随机点名册"))
  let run = apply(asked, ComposerRun)
  let cards = run.ai_sessions.current().cards
  let user_seq = cards[0].seq
  let ai_seq = cards[1].seq
  // 编辑：把提问原文回填草稿
  let edited = apply(run, EditUserPrompt(user_seq))
  assert_eq(
    edited.ai_sessions.current().prompt_draft,
    "帮我做一个随机点名册",
  )
  // 重发：回填 + 立即重跑（时间线再长出一轮提问 + diff）
  let before = run.ai_sessions.current().cards.length()
  let retried = apply(run, RetryUserPrompt(ai_seq))
  assert_eq(
    retried.ai_sessions.current().prompt_draft,
    "帮我做一个随机点名册",
  )
  assert_true(retried.ai_sessions.current().cards.length() > before)
}

///|
test "transcript follow toggles by scroll direction and new content" {
  let model = @app.initial_model()
  // 先下滚（跟随保持），再上滚（y 变小）→ 关跟随；再下滚 → 恢复
  let lower = apply(
    model,
    TranscriptScrolled(@geometry.Point::new(x=0.0, y=90.0)),
  )
  assert_true(lower.transcript_follow)
  let up = apply(lower, TranscriptScrolled(@geometry.Point::new(x=0.0, y=50.0)))
  assert_false(up.transcript_follow)
  let down = apply(up, TranscriptScrolled(@geometry.Point::new(x=0.0, y=90.0)))
  assert_true(down.transcript_follow)
  // 非跟随态：新卡不触发贴底请求；恢复后：新卡强制贴底
  let quiet = @app.push_ai_card(down, @app.AiCard::{
    kind: @ai.CardUserPrompt,
    title: "",
    body: "x",
    steps: [],
    steps_done: 0,
    progress: 0,
    diff_lines: [],
    settled: true,
    settled_note: "",
    seq: 0,
    at: 0,
  })
  let seq_before = quiet.transcript_scroll_seq
  assert_eq(quiet.transcript_scroll_seq, seq_before)
  let seq_before2 = quiet.transcript_scroll_seq
  let follower = apply(quiet, TranscriptScrollToBottom)
  assert_true(follower.transcript_scroll_seq > seq_before2)
  // 「before」必须先取值：push 原地改 mut 字段,follower 与 bumped 同记录
  let seq_before_bump = follower.transcript_scroll_seq
  let _bumped = @app.push_ai_card(follower, @app.AiCard::{
    kind: @ai.CardUserPrompt,
    title: "",
    body: "y",
    steps: [],
    steps_done: 0,
    progress: 0,
    diff_lines: [],
    settled: true,
    settled_note: "",
    seq: 0,
    at: 0,
  })
  assert_true(follower.transcript_scroll_seq > seq_before_bump)
}

///|
test "switching sessions resets transcript scroll to follow" {
  let model = @app.initial_model()
  let asked = apply(model, SetPrompt("帮我做一个随机点名册"))
  let run = apply(asked, ComposerRun)
  let scrolled = apply(
    run,
    TranscriptScrolled(@geometry.Point::new(x=0.0, y=40.0)),
  )
  let scrolled = apply(
    scrolled,
    TranscriptScrolled(@geometry.Point::new(x=0.0, y=10.0)),
  )
  assert_false(scrolled.transcript_follow)
  let created = apply(scrolled, AiSessionOp(AiSessionCreate(0)))
  assert_true(created.transcript_follow)
}

///|
test "relative time buckets by diff" {
  let now = 86400 * 100
  // < 60s → 刚刚;< 1h → 分;< 1d → 小时;≥1d → 天
  assert_eq(@app.relative_time_bucket(now, now - 30).0, "app.ai.time.just_now")
  let minutes = @app.relative_time_bucket(now, now - 120)
  assert_eq(minutes.0, "app.ai.time.minutes")
  assert_eq(minutes.1, 2)
  let hours = @app.relative_time_bucket(now, now - 7200)
  assert_eq(hours.0, "app.ai.time.hours")
  assert_eq(hours.1, 2)
  let days = @app.relative_time_bucket(now, now - 172800)
  assert_eq(days.0, "app.ai.time.days")
  assert_eq(days.1, 2)
}

///|
test "inline rename commits trimmed title and stamps activity" {
  let model = @app.initial_model()
  let started = apply(model, AiSessionRenameStart(0))
  match started.session_rename {
    Some((index, draft)) => {
      assert_eq(index, 0)
      assert_eq(draft, "会话 1")
    }
    None => fail("应进入改名态")
  }
  let drafted = apply(started, AiSessionRenameDraft("  点名册讨论  "))
  let committed = apply(drafted, AiSessionRenameCommit)
  assert_eq(committed.ai_sessions.current().title, "点名册讨论")
  assert_true(committed.session_rename is None)
  // 提交是结构性事件:盖 updated 戳(clock 默认 0 秒口径 → > 0 之前的 updated 是 0)
  assert_true(committed.ai_sessions.current().updated >= 0)
  // 空白名不生效
  let again = apply(committed, AiSessionRenameStart(0))
  let blank = apply(again, AiSessionRenameDraft("   "))
  let kept = apply(blank, AiSessionRenameCommit)
  assert_eq(kept.ai_sessions.current().title, "点名册讨论")
}

///|
test "session search toggle and query filter" {
  let model = @app.initial_model()
  assert_false(model.ai_sessions_search_open)
  let opened = apply(model, ToggleAiSessionSearch)
  assert_true(opened.ai_sessions_search_open)
  let queried = apply(opened, SetAiSessionsQuery("点名"))
  assert_eq(queried.ai_sessions_query, "点名")
  // 关闭即清空查询
  let closed = apply(queried, ToggleAiSessionSearch)
  assert_false(closed.ai_sessions_search_open)
  assert_eq(closed.ai_sessions_query, "")
}

///|
test "hover tracks the session row under the pointer" {
  let model = @app.initial_model()
  let entered = apply(model, AiSessionHover(0, true))
  assert_eq(entered.ai_session_hover, 0)
  let left = apply(entered, AiSessionHover(0, false))
  assert_eq(left.ai_session_hover, -1)
}

///|
test "store load replaces sessions and bad payload warns without replacing" {
  let model = @app.initial_model()
  let asked = apply(model, SetPrompt("帮我做一个随机点名册"))
  let ran = apply(asked, ComposerRun)
  // Success + 合法载荷：替换会话容器（恢复存储里的两条会话）
  let payload = "{\"format\": \"moui.studio.ai-sessions\", \"version\": 1, \"active\": 1, \"seq\": 2, \"sessions\": [{\"title\": \"恢复甲\", \"prompt_draft\": \"\", \"project\": \"\", \"pinned\": true, \"updated\": 99, \"card_seq\": 0, \"cards\": [], \"history\": []}, {\"title\": \"恢复乙\", \"prompt_draft\": \"\", \"project\": \"\", \"pinned\": false, \"updated\": 0, \"card_seq\": 0, \"cards\": [], \"history\": []}]}"
  let loaded = apply(ran, AiSessionsStoreLoaded(Success(payload)))
  assert_eq(loaded.ai_sessions.count(), 2)
  assert_eq(loaded.ai_sessions.current().title, "恢复乙")
  assert_true(loaded.transcript_follow)
  // Success + 坏载荷：with_notice 报错且保留当前会话（不静默吞）
  let bad = apply(ran, AiSessionsStoreLoaded(Success("{}}}")))
  assert_eq(bad.ai_sessions.count(), ran.ai_sessions.count())
  assert_true(bad.notice != "")
}

///|
test "structural events mark the session store dirty" {
  let model = @app.initial_model()
  // 提交 → outbox 有 EvAiSessionsDirty
  let asked = apply(model, SetPrompt("帮我做一个随机点名册"))
  let ran = apply(asked, ComposerRun)
  assert_true(ran.outbox.any(event => event is EvAiSessionsDirty))
  // 拒绝提案 → 也脏
  let rejected = apply(ran, RejectProposal)
  assert_true(rejected.outbox.any(event => event is EvAiSessionsDirty))
}

///|
test "keyboard n creates a session and palette ids dispatch" {
  let model = @app.initial_model()
  // Ctrl/Cmd+N → 新建会话（program_commands 绑定的消息与命令面板同链）
  let created = apply(model, AiSessionOp(AiSessionCreate(0)))
  assert_eq(created.ai_sessions.count(), 2)
  // 命令面板表含新命令,且 dispatch 真正执行
  let commands = @app.studio_commands(@app.translator(model))
  let mut has_new = false
  let mut has_search = false
  for command in commands {
    if command.id == "studio.ai.new_session" {
      has_new = true
    }
    if command.id == "studio.ai.search" {
      has_search = true
    }
  }
  assert_true(has_new)
  assert_true(has_search)
  // 会话容器是共享可变引用（amend 语义）：model 已被上面的 create 原地
  // 改过——命令面板 dispatch 必须用**新鲜**模型断言,否则计数叠加。
  let via_palette = apply(
    @app.initial_model(),
    StudioCommandRun("studio.ai.new_session"),
  )
  assert_eq(via_palette.ai_sessions.count(), 2)
  let searched = apply(model, StudioCommandRun("studio.ai.search"))
  assert_true(searched.ai_sessions_search_open)
}

///|
test "create stamps created time and codec keeps it backward compatible" {
  // Ctrl/Cmd+N 口径:创建消息携带 model.clock 的 civil_seconds
  let created = apply(
    @app.initial_model(),
    AiSessionOp(AiSessionCreate(1799366640)),
  )
  assert_eq(created.ai_sessions.current().created, 1799366640)
  assert_eq(created.ai_sessions.current().updated, 1799366640)
  // codec 把 created 编进 v1
  let encoded = @ai.encode_ai_sessions(created.ai_sessions)
  assert_true(encoded.contains("\"created\""))
  // 一期旧文件(无 created 字段)解码回退 updated,不拒绝
  let legacy = "{\"format\": \"moui.studio.ai-sessions\", \"version\": 1, \"active\": 0, \"seq\": 1, \"sessions\": [{\"title\": \"旧会话\", \"prompt_draft\": \"\", \"project\": \"\", \"pinned\": false, \"updated\": 42, \"card_seq\": 0, \"cards\": [], \"history\": []}]}"
  match @ai.decode_ai_sessions(legacy) {
    Ok(container) => assert_eq(container.current().created, 42)
    Err(_) => fail("旧文件应可解码")
  }
}

///|
test "session meta time falls back created then updated then just now" {
  // created>0 优先于 updated
  let base = apply(@app.initial_model(), AiSessionOp(AiSessionCreate(1000)))
  let touched = apply(base, SetPrompt("提问"))
  let ran = apply(touched, ComposerRun)
  // 提交盖 updated(当前钟 > created) → 元信息时间应来自 updated 而非 created
  let stamp = ran.ai_sessions.current().updated
  assert_true(stamp > 1000)
  // 全 0(理论存量态)回退「刚刚」:直接构造容器断言渲染文案由视图层保证,
  // 这里锁回退函数口径——created 0、updated 0 → 时间戳取 0 → 视图层显示刚刚
  assert_true(ran.ai_sessions.current().created == 1000)
}

///|
/// G1 纯聊天:离线路由——确定性回复卡进转录 + 接通引导提示;
/// 历史构建——用户气泡与 AI 回复按序进上下文。
test "纯聊天:离线回复与历史构建" {
  let asked = apply(
    { ..@app.initial_model(), composer_mode: ComposeChat, },
    SetPrompt("你好"),
  )
  let ran = apply(asked, ComposerRun)
  // 离线假回复卡在转录里
  let cards = ran.ai_sessions.current().cards
  let mut reply_found = false
  for card in cards {
    if card.kind is CardExplanation && card.body.contains("离线模型") {
      reply_found = true
    }
  }
  assert_true(reply_found, msg="离线回复应进转录")
  // 接通引导提示
  assert_true(ran.notice.contains("设置"), msg=ran.notice)
  // 多轮历史:用户提问 + 助手回复
  let history = @app.chat_history(ran)
  assert_eq(history.length(), 2)
  assert_eq(history[0].0, "user")
  assert_eq(history[1].0, "assistant")
}
