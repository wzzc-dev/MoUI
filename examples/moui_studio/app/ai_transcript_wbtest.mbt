///|
/// 对白转录（M2）的白盒布局验证：headless runtime 落真实视口，从
/// draw_commands 断言时间线的结构契约——用户气泡右对齐、AI 消息左对齐、
/// 会话头在场、「回到底部」按跟随态显隐、工作折叠组计数可见。
/// 纯转移/绘制基建与 shell_layout_wbtest 同款（wbtest 独立包需各留一份）。

///|
/// 纯转移（忽略 effect）。
fn apply_ai(model : Model, msg : Msg) -> Model {
  let (next, _) = update_pure(model, msg)
  next
}

///|
/// 在给定视口渲染一次，返回 draw_commands。
fn ai_draw(
  model : Model,
  width : Double,
  height : Double,
) -> Array[@core.DrawCommand] {
  let program : @core.Program[Model, Msg] = @moui.Program::new_with_environment(
    init=() => (model, @moui.Effect::none()),
    update=(current, msg) => update_pure(current, msg),
    view=(current, env) => view_with_viewport(current, env.viewport_size()),
  )
  @runtime.new_program_with_dimensions(program~, width~, height~).draw_commands()
}

///|
/// AI 模式 + 一轮「提问 → 提案」的会话（用户气泡 + diff 工作卡）。
fn ai_transcript_model() -> Model {
  let asked = apply_ai(initial_model(), SetPerspective(PsAi))
  let asked = apply_ai(asked, SetPrompt("帮我做一个班级随机点名册"))
  apply_ai(asked, ComposerRun)
}

///|
test "transcript shows user bubble right aligned and session header" {
  // 只推一张用户气泡卡（内容短于视口,贴底钳制回 0,气泡必在视口内）；
  // composer 草稿也会画同一段文字——断言「存在 x 在右半的那一条」即可。
  let model = push_ai_card(
    apply_ai(initial_model(), SetPerspective(PsAi)),
    AiCard::{
      kind: CardUserPrompt,
      title: "",
      body: "帮我做一个班级随机点名册",
      steps: [],
      steps_done: 0,
      progress: 0,
      diff_lines: [],
      settled: true,
      settled_note: "",
      seq: 0,
      at: 0,
    },
  )
  let commands = ai_draw(model, 1280.0, 800.0)
  let mut bubble_x = -1.0
  let mut header_found = false
  for run in shell_texts(commands) {
    if run.text.contains("帮我做一个班级随机点名册") {
      if run.frame.origin.x > bubble_x {
        bubble_x = run.frame.origin.x
      }
    }
    if run.text.has_prefix("会话 1") && run.frame.origin.y < 120.0 {
      // 会话头里的默认标题（贴近窗口顶部）
      header_found = true
    }
  }
  // 用户气泡右对齐：提问文字落在窗口右半
  assert_true(bubble_x > 640.0)
  assert_true(header_found)
}

///|
test "transcript hides scroll to bottom while following and shows when scrolled up" {
  let model = ai_transcript_model()
  // 跟随态：无「回到底部」
  let following = ai_draw(model, 1280.0, 800.0)
  let mut found = false
  for run in shell_texts(following) {
    if run.text.contains("回到底部") {
      found = true
    }
  }
  assert_false(found)
  // 用户上滚：出现「回到底部」
  let scrolled = apply_ai(
    model,
    TranscriptScrolled(@geometry.Point::new(x=0.0, y=100.0)),
  )
  assert_false(scrolled.transcript_follow)
  let commands = ai_draw(scrolled, 1280.0, 800.0)
  let mut visible = false
  for run in shell_texts(commands) {
    if run.text.contains("回到底部") {
      visible = true
    }
  }
  assert_true(visible)
  // 点「回到底部」：恢复跟随。seq 的「before」必须先取值——update 臂对
  // mut 字段是**原地改**，scrolled 与 restored 是同一条记录的别名，
  // 事后读 scrolled.transcript_scroll_seq 已经是新值（断言恒假）。
  let seq_before = scrolled.transcript_scroll_seq
  let restored = apply_ai(scrolled, TranscriptScrollToBottom)
  assert_true(restored.transcript_follow)
  assert_true(restored.transcript_scroll_seq > seq_before)
}

///|
test "transcript groups work cards with pending audit count" {
  let model = ai_transcript_model()
  // 提案 diff 卡未处理：折叠组头显示「待审计 1」（警告口径）
  let commands = ai_draw(model, 1280.0, 800.0)
  let mut pending_label = false
  for run in shell_texts(commands) {
    if run.text.contains("待审计 1") {
      pending_label = true
    }
  }
  assert_true(pending_label)
}

///|
test "transcript renders explanation card as ai message with retry action" {
  let model = ai_transcript_model()
  // 直接推一张讲解卡（流式完成后的形态）+ 已处理的 diff 卡
  let with_explain = push_ai_card(
    model,
    AiCard::{
      kind: CardExplanation,
      title: "",
      body: "## 讲解标题\n第一段说明",
      steps: [],
      steps_done: 0,
      progress: 0,
      diff_lines: [],
      settled: false,
      settled_note: "",
      seq: 0,
      at: 0,
    },
  )
  let commands = ai_draw(with_explain, 1280.0, 800.0)
  let mut heading = false
  let mut retry = false
  for run in shell_texts(commands) {
    if run.text == "讲解标题" {
      heading = true
    }
    if run.text.contains("重发") {
      retry = true
    }
  }
  // AI 消息走 markdown 渲染（标题在）+ 动作行有「重发」
  assert_true(heading)
  assert_true(retry)
  // 左对齐：讲解标题的 x 在窗口左半（中心列内）
  let mut heading_x = -1.0
  for run in shell_texts(commands) {
    if run.text == "讲解标题" {
      heading_x = run.frame.origin.x
    }
  }
  assert_true(heading_x < 640.0)
}

///|
test "composer info layer shows model chips and posture on wide center" {
  let model = apply_ai(initial_model(), SetPerspective(PsAi))
  let commands = ai_draw(model, 1280.0, 800.0)
  let mut model_chip = 0
  let mut posture = false
  for run in shell_texts(commands) {
    if run.text == "离线模型" {
      model_chip = model_chip + 1
    }
    if run.text.contains("闸门 · 逐条采纳") {
      posture = true
    }
  }
  // 宽卡：模型芯片出现两次（上下文芯片行 + 脚注）,姿态读数常驻
  // （空会话 = 闸门弱读数）。提示行已按用户口径移除——不得再出现。
  assert_true(model_chip >= 2)
  assert_true(posture)
  let mut tip = false
  for run in shell_texts(commands) {
    if run.text.contains("结构化提案") || run.text.contains("提示: ") {
      tip = true
    }
  }
  assert_false(tip)
}

///|
test "composer info layer hides on narrow docked host" {
  // 代码模式预设：AI 停靠右栏（右栏窄,~272pt < 420）→ 芯片行不显示
  let model = apply_ai(initial_model(), SetPerspective(PsCode))
  let commands = ai_draw(model, 1280.0, 800.0)
  let mut model_chip = false
  for run in shell_texts(commands) {
    if run.text == "离线模型" {
      model_chip = true
    }
  }
  assert_false(model_chip)
}

///|
test "posture chip shows pending count on wide composer" {
  let model = ai_transcript_model()
  let commands = ai_draw(model, 1280.0, 800.0)
  let mut pending_reads = 0
  for run in shell_texts(commands) {
    if run.text.contains("待审计 1") {
      pending_reads = pending_reads + 1
    }
  }
  // 工作折叠组头 + composer 姿态芯片各一条
  assert_true(pending_reads >= 2)
}

///|
test "session list renders pinned group and default project group with counts" {
  // 会话 0:已置顶 + 有工程戳 + 刚刚活动;会话 1:无工程、未活动
  let base = apply_ai(initial_model(), SetPerspective(PsAi))
  let asked = apply_ai(base, SetPrompt("帮我做一个随机点名册"))
  let ran = apply_ai(asked, ComposerRun)
  let pinned = apply_ai(ran, AiSessionOp(AiSessionPin(0, true)))
  let created = apply_ai(pinned, AiSessionOp(AiSessionCreate(0)))
  let commands = ai_draw(created, 1280.0, 800.0)
  let mut pinned_bar = false
  let mut default_bar = false
  let mut just_now = false
  for run in shell_texts(commands) {
    if run.text == "置顶" {
      pinned_bar = true
    }
    if run.text == "默认工程" {
      default_bar = true
    }
    if run.text == "刚刚" {
      just_now = true
    }
  }
  // 置顶组头 + 默认工程组头 + 相对时间读数(clock 常数钟 = 提交时刻 → 刚刚)
  assert_true(pinned_bar)
  assert_true(default_bar)
  assert_true(just_now)
}

///|
test "session list search row filters by query" {
  let base = apply_ai(initial_model(), SetPerspective(PsAi))
  let created = apply_ai(base, AiSessionOp(AiSessionCreate(0)))
  // 新建会话的默认名「会话 2」;原会话改名为点名册讨论
  let renamed = apply_ai(created, AiSessionRenameStart(0))
  let drafted = apply_ai(renamed, AiSessionRenameDraft("点名册讨论"))
  let committed = apply_ai(drafted, AiSessionRenameCommit)
  let opened = apply_ai(committed, ToggleAiSessionSearch)
  let queried = apply_ai(opened, SetAiSessionsQuery("点名"))
  let commands = ai_draw(queried, 1280.0, 800.0)
  let mut hit = false
  let mut miss = false
  for run in shell_texts(commands) {
    if run.text == "点名册讨论" {
      hit = true
    }
    if run.text == "会话 2" {
      miss = true
    }
  }
  // 命中的会话行还在,未命中的不出现
  assert_true(hit)
  assert_false(miss)
}

///|
test "empty session composer is vertically centered in a tall window" {
  // 真机缺陷回归:top_pad 定高公式让列只有面积一半,再被容器垂直居中
  // ——内容整体偏下。50/50 口径:芯片行到标题条的距离 ≈ 姿态行到底栏的距离。
  let model = apply_ai(initial_model(), SetPerspective(PsAi))
  let commands = ai_draw(model, 1600.0, 1000.0)
  let mut chips_y = -1.0
  let mut chips_x = -1.0
  let mut posture_y = -1.0
  let mut title_y = -1.0
  let mut status_y = -1.0
  for run in shell_texts(commands) {
    // 中心列的工程芯片:左栏组头与中心芯片同名——取 **x 最大**的那条
    if run.text == "默认工程" {
      if chips_y < 0.0 || run.frame.origin.x > chips_x {
        chips_y = run.frame.origin.y
        chips_x = run.frame.origin.x
      }
    }
    if run.text.contains("闸门 · 逐条采纳") {
      posture_y = run.frame.origin.y
    }
    if run.text.contains("MoUI Studio") {
      if title_y < 0.0 || run.frame.origin.y < title_y {
        title_y = run.frame.origin.y
      }
    }
    if run.text.contains("空闲") {
      if status_y < 0.0 || run.frame.origin.y > status_y {
        status_y = run.frame.origin.y
      }
    }
  }
  assert_true(chips_y > 0.0)
  assert_true(posture_y > 0.0)
  assert_true(title_y >= 0.0)
  assert_true(status_y > 0.0)
  // 帧钉高后的 50/50 契约:姿态行**贴区域底部**(列铺满,不再被容器居中);
  // composer 块在剩余空间里上下等重。缺陷形态(posture=454.9 / 间距 135)
  // 两条都会红。
  assert_true(posture_y > 700.0)
  assert_true(posture_y - chips_y > 300.0)
}

///|
test "bottom bar host reserves room for the composer block incl chips" {
  // 真机缺陷回归:底栏高度账漏算芯片行(≥420 宽渲染,28+2),脚注被裁。
  // ai_bar_height 必须装得下「面板头 + composer 块足迹(按底栏内宽) +
  // 决策条 + 四周内衬 + 余量」。
  let model = apply_ai(initial_model(), TogglePaneBlocks)
  let width = 900.0
  let inner = width - AI_CARD_PAD * 2.0
  let bar = ai_bar_height(model, width, 800.0)
  // 内衬在 card_chrome_height 里已计 pad*2;外层包装只补横向,纵向不再垫
  let needed = PANEL_HEAD_HEIGHT + composer_block_height(inner) +
    decision_bar_height(model) +
    AI_CARD_PAD * 2.0 +
    4.0
  assert_true(bar >= needed)
}
