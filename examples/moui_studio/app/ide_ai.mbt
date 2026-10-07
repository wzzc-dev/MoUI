///|
/// v4 IDE 的 AI 浮动层：锚点（居中/左/右/停靠）+ 药丸收起 + 线程卡 +
/// 计划卡进度 + diff 待审计 + 副作用确认 + 上下文芯片 + 输入条。
///
/// 定位方式：`align` + `offset` 在 stack 里做绝对摆放。
/// 这里不用 StageLayout（那是给「按 IR 矩形摆真控件」用的）——浮动层是
/// 单个卡片，尺寸由内容决定，所以用 stack 的「整帧」语义 + align 定位，
/// 卡片自身用显式 width 收窄。align 的 x/y 会被钳到 [-1,1]。
///
/// 保留带（ai_reserve）：浮动层压在内容上会挡住底部——底栏展开时把锚点
/// 从「贴底」抬到「贴底 + reserve」。这是纯视图补偿，不做 DOM 式测量。

// ============================================================================
// 浮动层
// ============================================================================

///|
/// 浮动卡各段高度：视图层与避让预留（ai_reserve）都从这里取，
/// 两处各写一个字面量就会出现「预留了但还是被挡住」。
pub const FOLD_BAR_HEIGHT : Double = 27.0

///|
/// 上下文芯片行高（无芯片时不占位）。
pub const CHIPS_HEIGHT : Double = 26.0

///|
/// 输入盒高：两行文本域 + 盒内脚注一行（模式胶囊 | ghost 操作 | 圆形发送）
/// + 盒内垫。Codex/ZCode 口径——输入区是两行高的「书写区」，不是单行框。
/// 高度必须给 `lines × line_height + 16`：text_area 内部有 8pt×2 垂直内垫，
/// 只传 `lines=2` 时可见文本区只剩一行——这就是「输入区还是一行」的根因。
/// 这里 lines=3 × 20 = 60 → 可见 44 = 两整行（长 prompt 折行可读）。
pub const COMPOSER_HEIGHT : Double = 88.0

///|
/// 输入盒高度唯一计算源（视图层与 card_chrome_height 共用——两处各算
/// 一份就会把 composer 顶出卡片）。
pub fn composer_height(width : Double) -> Double {
  ignore(width)
  COMPOSER_HEIGHT
}

///|
/// composer 信息层（对白转录）：工程芯片（有 active 工程才在）+ 模型芯片
/// （离线/真实读数恒在）。只在宽卡（≥420）显示——右栏停靠/窄底栏放不下，
/// 强行显示会把脚注挤出面板。
pub fn context_chips_height(width : Double) -> Double {
  if width >= 420.0 {
    CHIPS_HEIGHT + 2.0
  } else {
    0.0
  }
}

///|
/// composer 块高 = 输入盒 + 上方上下文芯片行 + 空会话提示头条（仅中心态）。
/// 中心态与紧凑宿主的高度预算都从这里取——两处各算一份，芯片行/提示条
/// 就会把输入盒顶出宿主。
pub fn composer_block_height(width : Double) -> Double {
  composer_height(width) + context_chips_height(width)
}

///|
/// 下拉芯片（VS Code 智能体模式口径）：图标 + 文案 + ChevronDown，
/// 点击走真实命令（工程 → 打开资源管理器切换上下文；模型 → 设置）。
fn dropdown_chip(
  icon : @style.IconName,
  label : String,
  on_click : Msg,
) -> @moui.View[Msg] {
  let label_w = (text_estimate_width(label) * 1.05 + 8.0).max(24.0)
  let chip_w = label_w + 44.0
  @views.container(
    @views.center(
      @views.row(
        [
          @views.icon(icon, size=11.0, color=ide_text_muted()),
          @views.text(
            label,
            theme=studio_theme(),
            width=label_w,
            height=16.0,
          ).foreground(ide_text_muted()),
          @views.icon(ChevronDown, size=10.0, color=ide_text_faint()),
        ],
        spacing=4.0,
        align=Center,
      ).frame(width=chip_w - 16.0),
      width=chip_w,
      height=22.0,
    ),
    background=ide_panel_alt(),
    corner_radius=11.0,
    width=chip_w,
    height=22.0,
    padding=0.0,
  ).on_tap(on_click)
}

///|
/// 上下文芯片行（VS Code 口径）：工程下拉芯片 + 模型下拉芯片。
fn context_chips_row(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = []
  let project_label = match active_project_of(model) {
    Some(record) => fit_label(record.module_name, 160.0)
    None => text(t, "app.ai.group.default_project")
  }
  // 工程 → 打开资源管理器（切换工程上下文的既有通道）
  cells.push(dropdown_chip(FolderOpen, project_label, SetLeftView(LeftProject)))
  let model_label = if model.provider_mode is Fake {
    text(t, "app.ai.fake")
  } else {
    fit_label(model.provider_model, 160.0)
  }
  cells.push(dropdown_chip(Gear, model_label, StudioCommandRun("studio.settings")))
  // 外层容器必须显式给底色：无背景 container 在 paint 期回落到环境
  // Base 刷子（实测抓到的 ambient 回落缺陷），与输入盒同色读作一块。
  @views.container(
    fill_row(cells, width, 6.0, Start),
    background=ide_panel(),
    width~,
    height=CHIPS_HEIGHT,
    padding=0.0,
  )
}


///|
/// 提示头条：「提示: 」+ 着色关键词 + 其余；整行可点 = 打开提案历史
/// （给着色词真实行为,不做死链接）。带 hairline 下边与输入区分隔。
///|
/// 信息芯片：小圆角读数。`on_click` 为 None = 纯信息展示（不可点）。
fn info_chip(
  label : String,
  background : @graphics.Color,
  foreground : @core.Color,
  on_click : Msg?,
) -> @moui.View[Msg] {
  let chip_w = (text_estimate_width(label) * 1.05 + 16.0).max(36.0)
  let chip = @views.container(
    @views.center(
      @views.text(
        label,
        theme=studio_theme(),
        width=(chip_w - 12.0).max(20.0),
        height=16.0,
      ).foreground(foreground),
      width=chip_w,
      height=20.0,
    ),
    background~,
    corner_radius=10.0,
    width=chip_w,
    height=20.0,
    padding=0.0,
  )
  match on_click {
    Some(msg) => chip.on_tap(msg)
    None => chip
  }
}

///|
/// composer 的四周留白（VS Code 智能体模式口径）：输入面浮在中心区里,
/// 与左右缘、底部各留一圈,不顶满。中心态两个分支共用（底栏/停靠宿主不套,
/// 面板内的输入面仍贴边）。
fn ai_composer_framed(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let side = 16.0
  @views.padding_edges(
    composer(model, t, (width - side * 2.0).max(280.0)),
    left=side,
    right=side,
    bottom=8.0,
  )
}

///|
/// AI 模式的中心工作区（宿主 2；对白转录）：
/// **空会话** = composer 垂直居中于大画布（「Pitch your idea」形态）；
/// **有内容** = 会话头 + 全幅对白时间线（滚动）+ composer 钉底。
pub fn ai_center(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let cards = model.ai_sessions.current().cards
  if model.right_view is RvAi {
    // 宿主唯一性（M2）:RvAi > PsAi 中心——AI 已停靠右栏时,中心只剩
    // 会话流（无 composer/姿态——输入面归停靠宿主,不画第二份）。
    return @views.container(
      @views.padding_edges(
        @views.scroll_view(
          @views.column(timeline_rows(model, t, width), spacing=8.0).frame(
            width=(width - 24.0).max(120.0),
          ),
          offset=model.transcript_scroll,
          on_scroll=Some(offset => TranscriptScrolled(offset)),
          request=@core.ScrollRequest::new(
            id=model.transcript_scroll_seq,
            offset=model.transcript_scroll,
          ),
          width~,
          height~,
          shows_indicator=true,
        ),
        left=12.0,
        right=12.0,
        top=4.0,
        bottom=4.0,
      ),
      background=ide_editor_background(),
      width~,
      height~,
      padding=0.0,
    )
  }
  if cards.length() == 0 {
    // 空会话：视觉居中（50/50）——上下**等重加权 spacer**。列必须显式
    // `.frame(height=height)`：ContainerBox 会把「量出来比容器矮」的子节点
    // 垂直居中（布局陷阱①）,加权 spacer 在测量期只报 min_length,不钉高度
    // 列就会缩成内容高、整体偏下（真机实测缺陷）。钉死高度后 spacer 才
    // 拿得到 slack,列恰好铺满。
    @views.container(
      @views.column(
        [
          @views.spacer(min_length=0.0, weight=1.0),
          ai_composer_framed(model, t, width),
          @views.spacer(min_length=4.0, weight=1.0),
          ai_posture_row(model, t, width),
        ],
        spacing=0.0,
      ).frame(height=height),
      background=ide_editor_background(),
      width~,
      height~,
      padding=0.0,
    )
  } else {
    // 有内容：会话头 + 全幅时间线（滚动）+ composer 钉底 + 姿态读数。
    // 「回到底部」芯片行夹在时间线与 composer 之间（非跟随态才占高）——
    // 不用 stack+align 叠放：叠放会遮住时间线末尾的内容，芯片行不遮。
    let composer_h = composer_block_height(width)
    let header_h = AI_SESSION_HEADER_HEIGHT
    let follow_h = if model.transcript_follow { 0.0 } else { 26.0 }
    let posture_h = POSTURE_HEIGHT
    let transcript_h = (height -
    header_h -
    composer_h -
    follow_h -
    posture_h).max(120.0)
    @views.container(
      @views.column(
        [
          ai_session_header(model, t, width),
          ai_transcript(model, t, width, transcript_h),
          ai_scroll_to_bottom_row(t, width, follow_h),
          ai_composer_framed(model, t, width),
          ai_posture_row(model, t, width),
        ],
        spacing=0.0,
      ),
      background=ide_editor_background(),
      width~,
      height~,
      padding=0.0,
    )
  }
}

///|
/// 会话头：标题（截断）+ 置顶切换 + 删除当前会话。
fn ai_session_header(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let session = model.ai_sessions.current()
  let index = model.ai_sessions.active_index()
  let title = fit_label(
    session.title,
    (width - 200.0).max(60.0),
  )
  let title_w = (text_estimate_width(title) * 1.02 + 8.0).min(width - 200.0).max(
    40.0,
  )
  let pin_label = if session.pinned {
    text(t, "app.ai.unpin")
  } else {
    text(t, "app.ai.pin")
  }
  @views.container(
    fill_row(
      [
        @views.text(
          title,
          theme=studio_theme(),
          width=title_w,
          height=18.0,
          align=TextStart,
        ).foreground(ide_text()),
        @views.spacer(min_length=6.0, weight=1.0),
        action_chip(
          pin_label,
          AiSessionOp(AiSessionPin(index, !session.pinned)),
          Ghost,
          22.0,
        ),
        action_chip(
          text(t, "app.ai.session.delete"),
          AiSessionOp(AiSessionRemove(index)),
          Ghost,
          22.0,
        ),
      ],
      width,
      6.0,
      Center,
    ),
    width~,
    height=AI_SESSION_HEADER_HEIGHT,
    padding=0.0,
  )
}

///|
/// 「回到底部」芯片行：非自动跟随态才渲染（跟随态 0 高不占位）。
/// 右对齐——与滚动位置语义一致（按钮把视口送回底部）。
fn ai_scroll_to_bottom_row(
  t : @i18n.Translator,
  width : Double,
  row_h : Double,
) -> @moui.View[Msg] {
  if row_h <= 0.0 {
    return @views.container(
      @views.text("", width=1.0, height=1.0),
      width~,
      height=0.0,
      padding=0.0,
    )
  }
  @views.container(
    fill_row(
      [
        @views.spacer(min_length=0.0, weight=1.0),
        action_chip(
          text(t, "app.ai.scroll_bottom"),
          TranscriptScrollToBottom,
          Quiet,
          20.0,
        ),
      ],
      width,
      6.0,
      Center,
    ),
    width~,
    height=row_h,
    padding=0.0,
  )
}

///|
/// 全幅对白时间线（滚动）：用户气泡 / AI 消息 / 工作卡折叠组按序渲染。
/// 受控滚动 + 自动贴底与终端同一套机制（offset 回写 + ScrollRequest 钳底）。
fn ai_transcript(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let inner = (width - 24.0).max(120.0)
  let rows = timeline_rows(model, t, width)
  @views.container(
    @views.padding_edges(
      @views.scroll_view(
        @views.column(rows, spacing=8.0).frame(width=inner),
        offset=model.transcript_scroll,
        on_scroll=Some(offset => TranscriptScrolled(offset)),
        request=@core.ScrollRequest::new(
          id=model.transcript_scroll_seq,
          offset=model.transcript_scroll,
        ),
        width~,
        height~,
        shows_indicator=true,
      ),
      left=12.0,
      right=12.0,
      top=4.0,
      bottom=4.0,
    ),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 时间线行构建：连续的 Agent 工作卡（计划/diff/副作用）归入一组折叠区
/// （「已工作 N / 待审计 N」），用户气泡、AI 消息与错误卡独立成行。
fn timeline_rows(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> Array[@moui.View[Msg]] {
  let cards = model.ai_sessions.current().cards
  let rows : Array[@moui.View[Msg]] = []
  let mut group : Array[AiCard] = []
  let mut index = 0
  for card in cards {
    let is_work = card.kind is CardPlan ||
      card.kind is CardDiff ||
      card.kind is CardSideEffect
    if is_work {
      group.push(card)
    } else {
      if group.length() > 0 {
        rows.push(work_group_row(model, t, group, width))
        group = []
      }
      match card.kind {
        CardUserPrompt => rows.push(user_bubble_row(t, card, width))
        CardExplanation => rows.push(ai_message_row(model, t, card, width))
        _ => rows.push(ai_card_view(model, t, card, index, width - 24.0))
      }
    }
    index = index + 1
  }
  if group.length() > 0 {
    rows.push(work_group_row(model, t, group, width))
  }
  rows
}

///|
/// 「已工作」折叠组：连续工作卡的可见记录。有未处理卡显示「待审计 N」
/// （警告色），否则显示工作时长（≥1 秒）或中性「Agent 线程」。
fn work_group_row(
  model : Model,
  t : @i18n.Translator,
  group : Array[AiCard],
  width : Double,
) -> @moui.View[Msg] {
  let inner = (width - 24.0).max(120.0)
  let mut pending = 0
  for card in group {
    if !card.settled && (card.kind is CardDiff || card.kind is CardSideEffect) {
      pending = pending + 1
    }
  }
  let duration = (group[group.length() - 1].at - group[0].at).max(0)
  let label = if pending > 0 {
    text_with(t, "app.ai.fold_pending", [("count", pending.to_string())])
  } else if duration >= 1 {
    let minutes = duration / 60
    let seconds = duration % 60
    text_with(t, "app.ai.work.trace", [
      ("duration", text_with(t, "app.ai.work.duration", [
        ("m", minutes.to_string()),
        ("s", seconds.to_string()),
      ])),
    ])
  } else {
    text(t, "app.ai.fold_idle")
  }
  let body : Array[@moui.View[Msg]] = [work_group_bar(model, label, inner, pending > 0)]
  if !model.ai_cards_folded {
    let mut card_index = 0
    for card in group {
      body.push(ai_card_view(model, t, card, card_index, inner))
      card_index = card_index + 1
    }
  }
  @views.container(
    @views.column(body, spacing=4.0).frame(width=inner),
    width~,
    padding=0.0,
  )
}

///|
/// 折叠组头：chevron + 标签（待审计 = 警告色），点击折叠/展开。
fn work_group_bar(
  model : Model,
  label : String,
  width : Double,
  has_pending : Bool,
) -> @moui.View[Msg] {
  @views.container(
    @views.padding_xy(
      @views.row(
        [
          @views.icon(
            if model.ai_cards_folded {
              ChevronRight
            } else {
              ChevronDown
            },
            size=12.0,
            color=ide_text_muted(),
          ),
          @views.text(
            label,
            theme=studio_theme(),
            width=(width - 60.0).max(60.0),
            height=16.0,
            align=TextStart,
          ).foreground(if has_pending { ide_warning() } else { ide_text_faint() }),
        ],
        spacing=4.0,
        align=Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    height=22.0,
    width~,
    padding=0.0,
  ).on_tap(ToggleAiCardsFold)
}

///|
/// 用户提问气泡（右对齐，强调色淡底）：宽度按内容估宽钳在 70% 行宽内，
/// 长 prompt 贪心折行；动作行 = 复制 / 编辑（回填草稿）+ HH:MM。
fn user_bubble_row(
  t : @i18n.Translator,
  card : AiCard,
  width : Double,
) -> @moui.View[Msg] {
  let inner = (width - 24.0).max(120.0)
  let max_w = (inner * 0.7).max(160.0)
  let est = (text_estimate_width(card.body) + 20.0).min(max_w)
  let lines = wrap_text_lines(card.body, est - 16.0)
  let line_h = 18.0
  let bubble_w = est
  let bubble_h = lines.length().to_double() * line_h + 16.0
  let lines_view : Array[@moui.View[Msg]] = []
  for line in lines {
    lines_view.push(
      @views.text(
        line,
        theme=studio_theme(),
        width=bubble_w - 16.0,
        height=line_h,
        align=TextStart,
      ).foreground(ide_text()),
    )
  }
  let bubble = @views.container(
    @views.column(lines_view, spacing=0.0).frame(width=bubble_w - 16.0),
    background=ide_selection(),
    corner_radius=10.0,
    width=bubble_w,
    height=bubble_h,
    padding=8.0,
  )
  @views.container(
    @views.column(
      [
        fill_row(
          [@views.spacer(min_length=0.0, weight=1.0), bubble],
          inner,
          0.0,
          Center,
        ),
        message_actions_row(
          card,
          inner,
          [
            action_chip(
              text(t, "app.ai.action.copy"),
              CopyAiMessage(card.seq),
              Ghost,
              18.0,
            ),
            action_chip(
              text(t, "app.ai.action.edit"),
              EditUserPrompt(card.seq),
              Ghost,
              18.0,
            ),
          ],
        ),
      ],
      spacing=2.0,
    ).frame(width=inner),
    width~,
    padding=0.0,
  )
}

///|
/// AI 消息行（左对齐，无底色）：markdown 渲染 + 动作行（复制 / 重发）。
/// 重发 = 该轮用户提问回填并重跑（单一 ComposerRun 通道）。
fn ai_message_row(
  model : Model,
  t : @i18n.Translator,
  card : AiCard,
  width : Double,
) -> @moui.View[Msg] {
  ignore(model)
  let inner = (width - 24.0).max(120.0)
  let blocks = @markdown.parse_markdown(card.body)
  @views.container(
    @views.column(
      [
        markdown_blocks_view(blocks, inner),
        message_actions_row(
          card,
          inner,
          [
            action_chip(
              text(t, "app.ai.action.copy"),
              CopyAiMessage(card.seq),
              Ghost,
              18.0,
            ),
            action_chip(
              text(t, "app.ai.action.retry"),
              RetryUserPrompt(card.seq),
              Ghost,
              18.0,
            ),
          ],
        ),
      ],
      spacing=4.0,
    ).frame(width=inner),
    width~,
    padding=0.0,
  )
}

///|
/// 消息动作行：动作芯片 + HH:MM 时间戳（mono、淡色）。
fn message_actions_row(
  card : AiCard,
  width : Double,
  chips : Array[@moui.View[Msg]],
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = []
  for chip in chips {
    cells.push(chip)
  }
  cells.push(
    @views.text(
      hhmm_of_stamp(card.at),
      theme=studio_theme(),
      role=Mono,
      width=44.0,
      height=14.0,
    ).foreground(ide_text_faint()),
  )
  @views.container(
    fill_row(cells, width, 4.0, Start),
    width~,
    height=20.0,
    padding=0.0,
  )
}

///|
/// 停靠档的 AI 输入面：右栏的内联卡（钉底，见 ide_root 的装配）。
///
/// **只有停靠档会调用它。** 底栏档由底栏自己画（`ide_bottom_bar` 的
/// `BtAi` 页签 → `ai_bar_composer`）。两个落点共用同一个 `composer`，
/// 所以这里只负责「放到右栏里」这一件事。
pub fn ai_layer(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg]? {
  if model.right_view is RvAi {
    Some(ai_docked(model, t, width, height))
  } else {
    None
  }
}

///|
/// 卡片四周的内衬：输入盒与卡片边缘之间的呼吸缝。
///
/// 停靠档的卡片宽度由右栏决定、高度由内容决定，所以内衬是**预算的一部分**
/// （`card_chrome_height` 要计入它），视图层再用 `padding` 把它留出来。
/// 两处同源，卡片才不会裁掉自己的内容。
pub const AI_CARD_PAD : Double = 8.0

///|
/// AI 卡的内容高度：输入盒 + 决策行 + 线程区 + 卡片内衬。
///
/// 停靠档由右栏的列布局决定实际高度，但这个函数仍是**唯一**的
/// 「内容需要多高」口径——右栏层用它做高度钳制与测试断言。
pub fn ai_card_height(model : Model, card_width : Double) -> Double {
  card_chrome_height(model, card_width) + thread_area_height(model)
}

///|
/// 线程区高度：`ai_card_body` 的 scroll_view 用它，`ai_card_height` 也用它。
/// **只能有一处算**——视图层和高度预算各算一份，卡片就会裁掉自己的内容
/// （或反过来留一块空白）。
fn thread_area_height(model : Model) -> Double {
  if model.ai_sessions.current().cards.length() == 0 || model.ai_cards_folded {
    0.0
  } else {
    // 线程区有 280 的上限（见 ai_card_body 的 scroll_view）
    (6.0 * model.ai_sessions.current().cards.length().to_double() + 40.0).min(
      280.0,
    )
  }
}

///|
/// 卡内除线程区以外的固定高度（输入盒 + 决策行 + 四周内衬）。
///
/// 内衬**必须计入**：视图层用 `padding=AI_CARD_PAD` 把输入盒推进去，
/// 预算少算这一圈，卡片就会裁掉自己的内容。曾经这里是一个孤零零的
/// `+ 12.0`——视图层没有对应元素，那 12pt 被 ContainerBox 居中平摊，
/// 成了「上下不对称」的一半来源。现在它与 `AI_CARD_PAD` 同源。
fn card_chrome_height(model : Model, width : Double) -> Double {
  composer_block_height(width) +
  decision_bar_height(model) +
  AI_CARD_PAD * 2.0
}

///|
/// 停靠卡：铺满右栏宽度的内联版本（无浮动底边距）。
fn ai_docked(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  // 同 ai_floating：纯定位的外层用 center，避免无背景 container 回落到
  // 不透明面板刷子把右栏其余内容糊掉。
  @views.center(
    ai_card_body(model, t, width, height - PANEL_HEAD_HEIGHT - 8.0),
    width~,
    height~,
  )
}

///|
/// 卡片主体：头（标题 + 锚点循环 + 药丸 + 停靠）+ 折叠条 + 线程卡 +
/// 上下文芯片 + 输入条 + 生成/采纳/拒绝按钮。
fn ai_card_body(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  thread_height : Double,
) -> @moui.View[Msg] {
  // 无头部（Codex/ZCode 口径）：浮在画布上的输入盒不需要标题栏——
  // 「AI 提案 / 底部居中 / 离线模型」与一排图标都是冗余 chrome。
  // 卡片级操作收敛到输入盒脚注（收起/停靠/历史），锚点循环与 provider
  // 设置走命令面板（⌘K）。
  // 卡内可用宽 = 卡宽 − 四周内衬。**所有**子件都按这个宽建，谁都不许
  // 再声明「卡宽」——内衬是卡片提供的，子件自己再按卡宽算一遍就会溢出
  // （列会给它们 W−16 的约束，它们却声明 W）。
  let inner = (width - AI_CARD_PAD * 2.0).max(120.0)
  // 折叠条：有待审计卡时显示计数并允许折叠线程
  let pending = pending_ai_cards(model)
  // 固定部分 = composer 块 + 决策行 + 上下内衬;剩余全部给钉底占位/线程区。
  // **列必须显式钉高（见函数尾 .frame）**——否则 ContainerBox 把「量出来比
  // 宿主矮」的卡片垂直居中,composer 浮在中间、上下留空（真机实测缺陷）。
  let fixed = composer_block_height(width) +
    decision_bar_height(model) +
    AI_CARD_PAD * 2.0
  let thread_left = (thread_height - fixed).max(0.0)
  let body : Array[@moui.View[Msg]] = []
  if model.ai_sessions.current().cards.length() == 0 || model.ai_cards_folded {
    // 空线程/折叠：剩余空间全部给钉底占位（输入面沉底,空带在上方——
    // VS Code 面板口径）。占位用零高 container（text 有最小行高,会顶出空带）。
    if thread_left > 0.0 {
      body.push(
        @views.container(
          @views.text("", width=1.0, height=thread_left),
          width=1.0,
          height=thread_left,
          padding=0.0,
        ),
      )
    }
  } else {
    body.push(fold_bar(model, t, inner, pending))
    let fold_h = FOLD_BAR_HEIGHT
    // 线程区 = 钉底占位之外的剩余（ capped at 280 上限）
    let used = (thread_left - fold_h).min(thread_area_height(model)).max(0.0)
    body.push(
      @views.scroll_view(
        @views.column(ai_card_views(model, t, inner), spacing=6.0),
        width=inner,
        height=used,
        shows_indicator=true,
      ),
    )
    // 设计稿 `#seeAll`：线程超过 3 条时给一个「查看全部会话 →」的出口
    // （折叠态不显示——折叠时线程区本来就收起了）。跳的是既有 AI 历史
    // 对话框，不新开一页。
    if model.ai_sessions.current().cards.length() > 3 {
      body.push(see_all_row(t, inner))
      let rest = (thread_left - fold_h - used - SEE_ALL_HEIGHT).max(0.0)
      if rest > 0.0 {
        body.push(
          @views.container(
            @views.text("", width=1.0, height=rest),
            width=1.0,
            height=rest,
            padding=0.0,
          ),
        )
      }
    } else {
      let rest = (thread_left - fold_h - used).max(0.0)
      if rest > 0.0 {
        body.push(
          @views.container(
            @views.text("", width=1.0, height=rest),
            width=1.0,
            height=rest,
            padding=0.0,
          ),
        )
      }
    }
  }
  // 输入盒是卡内唯一的实体（线程区/决策行都在它之上/之下），所以
  // **它自己就是那道边界**：卡片只出填充，不再描边。
  //
  // 此前卡与外盒各画一圈、两圈又同为 `#414449`（`ide_border` 与
  // `ide_elevated` 在主题里一度是同一个 rgba），左右只隔 8pt、垂直相距 0，
  // 读起来像「画错的边框」而不是「抬起的卡片」。收敛成一道环之后，
  // 「这是输入区」由**填充 + 单环**表达，层级更少也更干净。
  //
  // **不要再套一层定宽 wrapper**：包一层没有 background 的 container，
  // 它在 paint 期会回落到环境 Base → `palette.surface`，于是一圈本该露出
  // 卡片底色的内衬被刷成另一个颜色（实测 `#1F2227` 夹在卡片 `#393B40` 与
  // 输入盒 `#2B2D30` 之间）。这一圈此前看不见，只是因为那个回落色**恰好**
  // 等于旧带的回落色；给带钉上显式底色后就露出来了——「无背景 container =
  // 不透明面板色」是本仓反复踩的坑，这里直接不创造它。
  body.push(composer(model, t, width))
  body.push(decision_bar(model, t, width))
  // 扁平（实测反馈：卡片要「阴影/色阶」感,与面板融为一块）——
  // 与 composer 同底色,无圆角无抬升。
  @views.container(
    // 列钉高 = 宿主给的线程区高:filler 吸收剩余,composer/决策行沉底
    @views.padding(
      @views.column(body, spacing=0.0).frame(height=thread_height),
      AI_CARD_PAD,
    ),
    background=ide_panel(),
    corner_radius=0.0,
    width~,
    padding=0.0,
  )
}

///|
/// 「查看全部会话 →」：线程多了以后卡片区只能滚动看，给一个直达既有
/// AI 历史对话框的出口（设计稿 `#seeAll`）。宽度按内容算（中英文案差近半）。
fn see_all_row(t : @i18n.Translator, width : Double) -> @moui.View[Msg] {
  let label = text(t, "app.ai.see_all")
  let label_width = (text_estimate_width(label) * 1.05 + 20.0).max(64.0)
  @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.spacer(min_length=0.0, weight=1.0),
          @views.container(
            @views.center(
              @views.text(
                label,
                theme=studio_theme(),
                width=(label_width - 20.0).max(40.0),
                height=16.0,
              ).foreground(ide_accent()),
              width=label_width,
              height=18.0,
            ),
            background=ide_panel_alt(),
            corner_radius=4.0,
            width=label_width,
            height=18.0,
            padding=0.0,
          ).on_tap(ToggleAiHistory),
        ],
        (width - 16.0).max(120.0),
        4.0,
        Center,
      ),
      horizontal=8.0,
      vertical=1.0,
    ),
    width~,
    height=SEE_ALL_HEIGHT,
    padding=0.0,
  )
}

///|
/// 「查看全部会话 →」行高。
pub const SEE_ALL_HEIGHT : Double = 20.0

///|
/// 折叠条：「Agent 待审计 N」——点一下折叠/展开线程卡。
fn fold_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  pending : Int,
) -> @moui.View[Msg] {
  ignore(model)
  @views.container(
    @views.padding_xy(
      @views.row(
        [
          @views.icon(
            if model.ai_cards_folded {
              ChevronRight
            } else {
              ChevronDown
            },
            size=12.0,
            color=ide_text_muted(),
          ),
          @views.text(
            if pending > 0 {
              text_with(t, "app.ai.fold_pending", [
                ("count", pending.to_string()),
              ])
            } else {
              text(t, "app.ai.fold_idle")
            },
            theme=studio_theme(),
            width=(width - 60.0).max(60.0),
            height=16.0,
            align=TextStart,
          ).foreground(
            if pending > 0 {
              ide_warning()
            } else {
              ide_text_faint()
            },
          ),
        ],
        spacing=4.0,
        align=Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    height=22.0,
    width~,
    padding=0.0,
  ).on_tap(ToggleAiCardsFold)
}

///|
/// 线程卡列表：每张卡按 kind 渲染（计划/ diff / 副作用 / 讲解 / 错误）。
fn ai_card_views(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> Array[@moui.View[Msg]] {
  let views : Array[@moui.View[Msg]] = []
  let inner = width - 20.0
  let mut index = 0
  for card in model.ai_sessions.current().cards {
    views.push(ai_card_view(model, t, card, index, inner))
    index = index + 1
  }
  views
}

///|
fn ai_card_view(
  model : Model,
  t : @i18n.Translator,
  card : AiCard,
  index : Int,
  width : Double,
) -> @moui.View[Msg] {
  let accent = match card.kind {
    CardUserPrompt => ide_accent()
    CardPlan => ide_accent()
    CardDiff => ide_success()
    CardSideEffect => ide_warning()
    CardExplanation => ide_text_muted()
    CardError => ide_danger()
  }
  let rows : Array[@moui.View[Msg]] = [
    fill_row(
      [
        @views.text(
          text(t, card.title),
          theme=studio_theme(),
          width=(width - 70.0).max(60.0),
          height=18.0,
          align=TextStart,
        ).foreground(ide_text()),
        if card.settled {
          count_badge(text(t, "app.ai.settled"), 1)
        } else {
          @views.text("", width=1.0, height=1.0)
        },
      ],
      width,
      4.0,
      Center,
    ),
  ]
  if card.body != "" {
    // M4：讲解/流式卡的 body 走 markdown 块渲染（子集 + 诚实降级）；
    // 其余卡保持单行摘要文本
    if card.kind is CardExplanation {
      rows.push(
        markdown_blocks_view(@markdown.parse_markdown(card.body), width),
      )
    } else {
      rows.push(
        @views.text(
          card.body,
          theme=studio_theme(),
          width=(width - 16.0).max(60.0),
          height=18.0,
          align=TextStart,
        ).foreground(ide_text_muted()),
      )
    }
  }
  // 计划卡：进度条 + 步骤清单
  if card.kind is CardPlan {
    rows.push(progress_bar(card.progress, width - 16.0))
    let mut step_index = 0
    for step in card.steps {
      let done = step_index < card.steps_done
      rows.push(
        @views.text(
          (if done { "✓ " } else { "○ " }) + step,
          theme=studio_theme(),
          width=(width - 16.0).max(60.0),
          height=16.0,
          align=TextStart,
        ).foreground(if done { ide_success() } else { ide_text_faint() }),
      )
      step_index = step_index + 1
    }
  }
  // diff 卡：逐行 ±
  for line in card.diff_lines {
    rows.push(diff_row(line.0, line.1, width))
  }
  // 副作用卡 / diff 卡：待审计时给采纳/拒绝。
  // 芯片严格 22 高——线程区预算按内容行算，36pt 的 @views.button 会撑爆。
  if !card.settled && (card.kind is CardDiff || card.kind is CardSideEffect) {
    rows.push(
      @views.row(
        [
          action_chip(text(t, "app.ai.accept"), AcceptProposal, Primary, 22.0),
          action_chip(text(t, "app.ai.reject"), RejectProposal, Quiet, 22.0),
          @views.text(
            "\{index + 1}",
            theme=studio_theme(),
            role=Mono,
            width=20.0,
            height=16.0,
          ).foreground(ide_text_faint()),
        ],
        spacing=6.0,
        align=Center,
      ),
    )
  } else if card.settled && card.settled_note != "" {
    rows.push(
      @views.text(
        text(t, card.settled_note),
        theme=studio_theme(),
        width=(width - 16.0).max(60.0),
        height=16.0,
        align=TextStart,
      ).foreground(ide_success()),
    )
  }
  ignore(model)
  inline_card(accent, @views.column(rows, spacing=4.0), width, card.settled)
}

///|
/// 输入条：单行 = 模式段 | 输入框 | 发送（成熟 AI 面板口径——旧版
/// 工具行 + 输入行 + 按钮行三层 chrome 占 ~100pt，且工具行与头部图标
/// 功能完全重复）。窄卡（放不下一行）折两行：输入独占一行。
/// 手搓模式段与发送而不用 @views.button：button 的 `width`/`height` 进的
/// 是 `min_size`，文字比声明的宽就会自己长大顶出卡片。

///|
/// 底栏档所需的最小底栏高度：页签头 + 输入面（不含线程区）。
///
/// 线程卡出现时底栏还要更高（见 `ai_bar_height`）——写死一个值会在有提案
/// 时把线程区裁掉，那正是「生成完什么都看不见」的形态。
pub const AI_BAR_HEIGHT : Double = PANEL_HEAD_HEIGHT +
  COMPOSER_HEIGHT +
  CHIPS_HEIGHT +
  2.0 +
  AI_CARD_PAD * 2.0 +
  4.0

///|
/// 底栏档的实际高度：按内容（含线程区）算，并钳在窗口可用高之内。
///
/// 与「底栏装得下输入面」同一纪律：高度是**算出来的**，不是写死的。
/// 上限 `max` 防止线程卡多起来把工作区压没（底栏超过屏幕一半时截断，
/// 线程区自己会滚动）。
pub fn ai_bar_height(
  model : Model,
  width : Double,
  viewport_height : Double,
) -> Double {
  let inner = (width - AI_CARD_PAD * 2.0).max(120.0)
  // ai_card_height **已含**卡片四周内衬（AI_CARD_PAD*2）——这里再计一次
  // 会让底栏比内容高出一截，页签头和输入盒之间留出一条空白带（实测缺陷）。
  let content = PANEL_HEAD_HEIGHT + ai_card_height(model, inner) + 4.0
  content.max(AI_BAR_HEIGHT).min((viewport_height * 0.5).max(AI_BAR_HEIGHT))
}

///|
/// 底栏档的输入面：**与停靠档逐段同构**——折叠条 +（线程区 + #seeAll）+
/// 输入盒 + 决策行，只是宿主换成底栏、宽度按底栏给。
///
/// **为什么不能只放一个 composer**：线程卡（提案 diff / 计划 / 闸门）是
/// 「Agent 干了什么」的唯一可见记录，必须与输入面**同宿主**——否则默认
/// 档下生成提案后什么都看不见（实测：底栏档只有输入盒，`#seeAll`、
/// 待审计计数、diff 卡全部消失）。所以这里复用 `ai_card_body`，而不是
/// 另写一个精简版。
///
/// `height` 由调用方给（底栏体区高）：卡片必须待在自己的格子里，否则会按
/// 自然高画出去、越过底栏边界露出窗口底色。
pub fn ai_bar_composer(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  // 线程区只能拿「体区 − 输入面固定部分」的剩余，不能拿满高——
  // 否则输入盒会被顶出底栏。
  let inner = (width - AI_CARD_PAD * 2.0).max(120.0)

  // **宽度只扣一次内衬**：`ai_card_body` 自己已经用 `width − 2×pad` 算内宽
  // 并声明`width`，这里再套一层 `padding_xy` 就等于扣两次——卡片声明整宽、
  // 却只被给了 `width − 16` 的格子，右侧那 16pt 连同发送钮一起被推出面板
  // （实测发送钮贴死在中心列右缘 2009，右边一个 padding 都不剩）。
  // 所以外层只给底色，不再加横向内衬。
  // **外层容器必须显式给底色**：无背景的 container 在 paint 期回落到环境
  // Base → `palette.surface`（`#1F2227`），于是卡片上下那两圈内衬被刷成
  // 另一个颜色，在底栏里读成「两段脏边」。底栏的底色是 `ide_panel()`，
  // 这里跟它对齐——回落色与宿主面板不同色，是同一个坑的第二次。
  @views.container(
    // 横向内衬 8:卡片按 inner(宽−16)建,两侧各 8 补齐整宽。**纵向不能再垫**:
    // ai_card_body 自己的容器已有四周 8 内衬,再垫 16 会双重计账——
    // V3 芯片行加宽块足迹后,这 16pt 刚好吃掉脚注（真机实测缺陷）。
    @views.padding_xy(
      ai_card_body(model, t, inner, height),
      horizontal=AI_CARD_PAD,
      vertical=0.0,
    ),
    background=ide_panel(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
fn composer(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  // 脚注左端：模式选择（VS Code 的 Agent ⌄ 口径）。收起 = 单个「当前模式 ⌄」
  // 下拉芯片；展开 = 原位切回四选一胶囊行（SetComposerMode 后收起）——
  // 不引入浮层，88 预算内原位切换。
  let mode_cells : Array[@moui.View[Msg]] = if model.composer_mode_picker_open {
    [
      composer_mode_chip(model, t, ComposeEdit, "app.ai.mode.edit"),
      composer_mode_chip(model, t, ComposeGenerate, "app.ai.mode.generate"),
      composer_mode_chip(model, t, ComposeExplain, "app.ai.mode.explain"),
      composer_mode_chip(model, t, ComposeRepair, "app.ai.mode.repair"),
    ]
  } else {
    [composer_mode_dropdown(model, t)]
  }
  // 输入盒（VS Code 智能体模式口径）：提示头条（空会话中心态）+ **两行**
  // 无边框文本域（Enter 直接发送）+ 盒内脚注（模式/模型靠左，ghost 与
  // 圆形发送靠右）。
  let box_width = (width - 16.0).max(120.0)
  let inner_width = box_width - 16.0
  let busy = model.ai_busy
  let send_msg = if busy { Msg::Noop } else { ComposerRun }
  // 盒内脚注的 ghost 操作：**两种内联落点之间的一步切换**。
  //
  // 底栏档显示「停靠右栏」按钮，停靠档显示「放到底栏」——两边互为出口，
  // 用户在任一形态下都只需一次点击就能换到另一种一等形态。浮动族（贴底
  // 浮层）是次要档，只保留「收起成药丸」这一个出口，不再各配一个按钮
  // （那会让脚注变成一排图标，而它本该只有两个动作）。
  //
  // 历史/锚点循环/provider 设置走命令面板（⌘K），不占盒内空间。
  let ghost_surface = ide_panel()
  let foot_cells : Array[@moui.View[Msg]] = [
    @views.row(mode_cells, spacing=3.0, align=Center),
    @views.spacer(min_length=6.0, weight=1.0),
  ]
  if inner_width >= 300.0 {
    foot_cells.push(
      ghost_icon_button(
        Columns,
        text(t, "app.ai.to_dock"),
        model.right_view is RvAi,
        StudioCommandRun("studio.ai.dock"),
        22.0,
        20.0,
        11.0,
        ghost_surface,
      ),
    )
    foot_cells.push(
      ghost_icon_button(
        // 底栏档用 ChevronDown：与底栏「展开/收起」同一个视觉语汇
        // （图标集里没有专用的 bottom-panel 图标，不为一个按钮加新图标）。
        ChevronDown,
        text(t, "app.ai.to_bar"),
        !(model.right_view is RvAi),
        StudioCommandRun("studio.ai.bar"),
        22.0,
        20.0,
        11.0,
        ghost_surface,
      ),
    )
    foot_cells.push(
      ghost_icon_button(
        Clipboard,
        text(t, "app.ai.history"),
        false,
        ToggleAiHistory,
        22.0,
        20.0,
        11.0,
        ghost_surface,
      ),
    )
  }
  // 模型 chip（VS Code 的 ⚡模型 口径）：离线/真实读数，点击开设置。
  // 无推理档/上下文数据——不虚构「极高 · 1.1M」式读数。
  if inner_width >= 300.0 {
    let model_label = if model.provider_mode is Fake {
      text(t, "app.ai.fake")
    } else {
      fit_label(model.provider_model, 140.0)
    }
    foot_cells.push(
      info_chip(
        model_label,
        ide_panel(),
        ide_text_muted(),
        Some(StudioCommandRun("studio.settings")),
      ),
    )
  }
  // 发送钮在模式行右端（**只有一个**——输入行内再放一个是实测的双钮缺陷）。
  // 流式生成进行中：发送换**停止**（截断入口，M4）——同一槽位两个互斥动作。
  if model.ai_streaming {
    foot_cells.push(
      action_chip(text(t, "app.ai.stop"), StopGeneration, Quiet, 24.0),
    )
  } else {
    foot_cells.push(
      round_send_button(text(t, "app.ai.send"), send_msg, !busy, 24.0),
    )
  }
  // 实测反馈第四轮：**输入在上，模式胶囊 + 发送在下**；输入域可见
  // **两行**（text_area 内部有 8pt×2 垂直内垫——lines=3 才可见两整行，
  // 见 COMPOSER_HEIGHT 的注释）；整体扁平无阴影。
  // 输入域**直接作为列子项**（包定高容器或塞 row 都会让它不渲染，
  // text_area 的高度语义只在列布局下可靠，两轮实测确认）。
  let foot = fill_row(foot_cells, inner_width, 6.0, Center)
  let field = @views.text_area(
    model.ai_sessions.current().prompt_draft,
    on_input=value => SetPrompt(value),
    placeholder=text(t, "app.ai.prompt"),
    lines=3,
    variant=Plain,
    width=inner_width,
    line_height=20.0,
    on_submit=Some(send_msg),
  )
  let box = @views.container(
    @views.padding_edges(
      @views.column([field, foot], spacing=2.0),
      left=8.0,
      right=8.0,
      top=2.0,
      bottom=3.0,
    ),
    background=ide_panel(),
    // 中心态（AI 模式大画布）圆角浮起 + 1px 描边；右栏/底栏嵌入宿主
    // 维持扁平无描边（「与面板融为一体」的实测口径只适用于嵌入面板）。
    corner_radius=if model.perspective is PsAi { 10.0 } else { 0.0 },
    border=if model.perspective is PsAi {
      Some(@core.BorderStyle::{ brush: @core.Brush::Solid(ide_border()), width: 1.0 })
    } else {
      None
    },
    width=box_width,
    height=composer_height(width),
    padding=0.0,
  )
  // 信息层芯片行在输入盒**上方**（宽卡才显示）——块高走
  // composer_block_height，调用方的高度预算与这里同源。
  let chips_h = context_chips_height(width)
  if chips_h > 0.0 {
    @views.column(
      [context_chips_row(model, t, box_width), box],
      spacing=2.0,
    ).frame(width=box_width, height=composer_height(width) + chips_h)
  } else {
    box
  }
}

///|
/// 模式下拉芯片（收起态）：「当前模式 ⌄」——VS Code 的 Agent ⌄ 口径。
/// 点击展开 = 脚注原位切回四选一胶囊行（ToggleComposerModePicker）。
fn composer_mode_dropdown(
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let label = match model.composer_mode {
    ComposeEdit => text(t, "app.ai.mode.edit")
    ComposeGenerate => text(t, "app.ai.mode.generate")
    ComposeExplain => text(t, "app.ai.mode.explain")
    ComposeRepair => text(t, "app.ai.mode.repair")
  }
  let label_w = (text_estimate_width(label) * 1.05 + 8.0).max(30.0)
  let chip_w = label_w + 26.0
  let open = model.composer_mode_picker_open
  @views.container(
    @views.center(
      @views.row(
        [
          @views.text(
            label,
            theme=studio_theme(),
            width=label_w,
            height=16.0,
          ).foreground(if open { ide_accent() } else { ide_text_muted() }),
          @views.icon(ChevronDown, size=10.0, color=ide_text_muted()),
        ],
        spacing=3.0,
        align=Center,
      ).frame(width=chip_w - 12.0),
      width=chip_w,
      height=20.0,
    ),
    background=if open { ide_selection() } else { ide_panel() },
    corner_radius=10.0,
    width=chip_w,
    height=20.0,
    padding=0.0,
  ).on_tap(ToggleComposerModePicker)
}

///|
/// 姿态读数行高（对白转录 V5：空态常驻,VS Code 的 Autopilot 行语义替换）。
pub const POSTURE_HEIGHT : Double = 20.0

///|
/// 姿态读数（闸门哲学常驻可见）：无未处理卡 = 「闸门 · 逐条采纳」弱读数；
/// 有卡 = 「待审计 N」警告色（pending_ai_cards）。右侧不放工作树/分支。
fn ai_posture_row(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let pending = pending_ai_cards(model)
  let label = if pending > 0 {
    text_with(t, "app.ai.pending_chip", [("count", pending.to_string())])
  } else {
    text(t, "app.ai.posture.gate")
  }
  @views.container(
    @views.padding_edges(
      fill_row(
        [
          @views.text(
            label,
            theme=studio_theme(),
            width=(text_estimate_width(label) + 4.0).max(40.0),
            height=14.0,
            align=TextStart,
          ).foreground(if pending > 0 { ide_warning() } else { ide_text_faint() }),
          @views.spacer(min_length=6.0, weight=1.0),
        ],
        width,
        4.0,
        Start,
      ),
      left=8.0,
      right=8.0,
    ),
    width~,
    height=POSTURE_HEIGHT,
    padding=0.0,
  )
}

///|
/// AI 宿主读数（设计稿 `#posHint`）：让人不用猜「现在输入面在哪」。
pub fn ai_host_hint_key(model : Model) -> String {
  if model.right_view is RvAi {
    "app.ai.anchor.docked"
  } else if model.perspective is PsAi {
    "app.ai.anchor.center"
  } else {
    "app.ai.anchor.bar"
  }
}

///|
/// composer 模式芯片宽：文案实测 × 1.05 + 两侧内垫 14，下限 36。
/// 段宽合计（composer）与芯片自身宽必须走同一函数——两处各算一份，
/// 输入框的剩余宽就会算错。
fn composer_chip_width(label : String) -> Double {
  (text_estimate_width(label) * 1.05 + 14.0).max(36.0)
}

///|
/// 模式芯片：手搓（理由同 composer），选中态用强调色 + 底色区分。
fn composer_mode_chip(
  model : Model,
  t : @i18n.Translator,
  mode : ComposerMode,
  key : String,
) -> @moui.View[Msg] {
  let selected = model.composer_mode == mode
  let label = text(t, key)
  let chip_width = composer_chip_width(label)
  @views.container(
    @views.center(
      @views.text(
        label,
        theme=studio_theme(),
        width=(chip_width - 14.0).max(20.0),
        height=16.0,
      ).foreground(if selected { ide_accent() } else { ide_text_muted() }),
      width=chip_width,
      height=20.0,
    ),
    background=if selected { ide_selection() } else { ide_panel() },
    corner_radius=10.0,
    width=chip_width,
    height=20.0,
    padding=0.0,
  ).on_tap(SetComposerMode(mode))
}

///|
/// 决策条是否该在场：只有真内容（待采纳提案 / 讲解 / 错误）才渲染——
/// 旧版空闲态常驻一行「待命 | 提案历史」，是纯占位噪音（历史入口已在
/// 卡片头部，忙碌态由发送芯片表态）。
fn has_decision_content(model : Model) -> Bool {
  model.pending is Some(_) ||
  model.explanation != "" ||
  model.prompt_error != ""
}

///|
/// 决策条：待采纳提案摘要 + 采纳/拒绝；无提案时显示讲解/错误文本。
fn decision_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  if !has_decision_content(model) {
    return @views.container(
      @views.text("", width=1.0, height=1.0),
      width~,
      height=0.0,
      padding=0.0,
    )
  }
  let rows : Array[@moui.View[Msg]] = []
  match model.pending {
    Some(pending) => {
      rows.push(
        @views.text(
          pending.summary,
          theme=studio_theme(),
          width=(width - 16.0).max(60.0),
          height=18.0,
          align=TextStart,
        ).foreground(if pending.valid { ide_success() } else { ide_danger() }),
      )
      // 校验失败时逐条列出原因（不静默丢弃，也不允许采纳）。
      // 错误文案是长句（英文 400pt+），按行宽截断——决策条高度是单点预算，
      // 折行会把预算撑爆。
      if !pending.valid {
        for error in pending.errors {
          rows.push(
            @views.text(
              fit_label("· \{error}", (width - 24.0).max(60.0)),
              theme=studio_theme(),
              width=(width - 16.0).max(60.0),
              height=16.0,
              align=TextStart,
            ).foreground(ide_danger()),
          )
        }
      }
      rows.push(
        fill_row(
          [
            action_chip(text(t, "app.ai.accept"), AcceptProposal, Primary, 24.0),
            action_chip(text(t, "app.ai.reject"), RejectProposal, Quiet, 24.0),
            action_chip(text(t, "app.ai.history"), ToggleAiHistory, Ghost, 24.0),
          ],
          (width - 16.0).max(80.0),
          6.0,
          Center,
        ),
      )
    }
    None => {
      if model.explanation != "" {
        rows.push(
          @views.text(
            model.explanation,
            theme=studio_theme(),
            width=(width - 16.0).max(60.0),
            height=54.0,
            align=TextStart,
          ).foreground(ide_text_muted()),
        )
      }
      if model.prompt_error != "" {
        rows.push(
          @views.text(
            model.prompt_error,
            theme=studio_theme(),
            width=(width - 16.0).max(60.0),
            height=16.0,
            align=TextStart,
          ).foreground(ide_danger()),
        )
      }
    }
  }
  @views.container(
    @views.padding_xy(
      @views.column(rows, spacing=4.0).frame(
        width=(width - 16.0).max(80.0),
        height=decision_bar_height(model),
      ),
      horizontal=8.0,
      vertical=6.0,
    ),
    background=ide_panel(),
    width~,
    height=decision_bar_height(model) + 12.0,
    padding=0.0,
  )
}

///|
/// 决策条内容高：有提案时是「摘要 + 采纳/拒绝/历史」两行，否则是
/// 「空闲/忙碌」一行加可选的讲解与错误行。
/// 视图层与 ai_card_height 共用这一个来源——两处各写一份，
/// 避让预留就会和实际遮挡对不上。
pub fn decision_bar_height(model : Model) -> Double {
  if !has_decision_content(model) {
    return 0.0
  }
  match model.pending {
    // 两个 24pt 芯片行（采纳/拒绝/历史）。芯片严格等高，预算才准。
    Some(_) => 24.0 + 4.0 + 24.0
    None => {
      let mut height = 0.0
      if model.explanation != "" {
        height = height + 4.0 + 54.0
      }
      if model.prompt_error != "" {
        height = height + 4.0 + 16.0
      }
      height
    }
  }
}

// ============================================================================
// 药丸
// ============================================================================
