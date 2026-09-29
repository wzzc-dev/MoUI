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
/// 输入条高：字段 26 + 上下 4+4 内垫。
pub const COMPOSER_HEIGHT : Double = 82.0

///|
/// 输入条工具行高度（设计稿 `.ctools{height:24px}`，这里压到 20 更贴紧凑感）。
pub const COMPOSER_TOOLS_HEIGHT : Double = 20.0

///|
/// AI 浮动层：停靠模式返回右栏内联视图（由调用方放进右栏）；
/// 其余锚点返回可叠在 stack 上的浮动卡。返回 None 表示药丸收起，
/// 调用方改画药丸。
pub fn ai_layer(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
  reserve : Double,
) -> @moui.View[Msg]? {
  if model.ai_pill {
    return None
  }
  if model.ai_anchor is AiDocked {
    return Some(ai_docked(model, t, width, height))
  }
  Some(ai_floating(model, t, width, height, reserve))
}

///|
/// 浮动卡：宽度按锚点收窄（左/右锚 360，居中 480），
/// 高度自适应内容但钳在可用高度内。
fn ai_floating(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
  reserve : Double,
) -> @moui.View[Msg] {
  // 设计稿：底部居中 680（窄窗口按容器收），左右锚 360，hero 700。
  let hero = ai_hero(model)
  let card_width = if hero {
    (width - 20.0).max(320.0).min(700.0)
  } else {
    match model.ai_anchor {
      AiCenter => (width - 20.0).max(320.0).min(680.0)
      _ => (width * 0.42).max(300.0).min(360.0)
    }
  }
  let card_height = ai_card_height(model, card_width)
  // 卡高由内容决定；**线程区只能拿剩下的**，不能拿「可用高度减去一个常数」。
  // 后者在线程卡多起来时长到超出卡片自身帧高，把输入条和决策行顶出可视区
  // （实测：一张 diff 卡就把 composer 挤没了）。这里按
  // 「卡高 − 卡内其它部分」反推线程区预算，滚动条因此出现在线程区而不是
  // 整张卡上。
  let card = ai_card_body(model, t, card_width, thread_area_height(model))
  // 锚点 → stack 内的绝对摆放：stack 给每个子整帧，align 在帧内按
  // 「已量尺寸」贴边（mod_aligned_rect 取 min(帧, 子)），所以这里只需
  // 给出承载帧，卡片自己量出来的高度就决定它贴哪。
  // 贴底摆放**不能**用 .align()：AlignModifier 把自己量成子节点尺寸
  // （mod_aligned_rect 的 bounds 就是 `constrain(child)`），所以它在
  // 更大的帧里永远拿不到 slack，居中/贴底都是空操作。
  // 这里用「权重 spacer + 定高卡片」的列，把卡片确定性地压到带底。
  let usable = (height - 12.0).max(card_height)
  // 左右锚点：水平方向同样用 spacer 推，而不是 align。
  let (lead, trail) = match model.ai_anchor {
    AiCenter => (0.0, 0.0)
    AiLeft => (12.0, 0.0)
    AiRight | AiDocked => (0.0, 12.0)
  }
  let row : Array[@moui.View[Msg]] = []
  if lead > 0.0 {
    row.push(@views.spacer(min_length=lead, weight=0.0))
  }
  row.push(
    @views.container(card, width=card_width, height=card_height, padding=0.0),
  )
  if trail > 0.0 {
    row.push(@views.spacer(min_length=trail, weight=1.0))
  }
  // hero 贴「上方 42%」而不是贴底：设计稿 `.hero{bottom:auto;top:42%}`。
  // 用两个权重 spacer 按 42:58 分配余量，等价于把卡放在 42% 处。
  let lead_space = (usable - card_height).max(0.0)
  let (top_weight, bottom_weight) = if hero { (42.0, 58.0) } else { (0.0, 1.0) }
  ignore(lead_space)
  // 外层只用 `center` 定位，**不能用 container**：无 background 的 container
  // 会回落到环境 Base 变体的刷子（不透明面板色），于是整帧被刷成一块底板，
  // 把下面工作区的内容（空舞台的引导语、按钮）整片盖掉——位置对、文字在
  // 绘制流里，但屏幕上什么都没有。
  @views.center(
    @views.column(
      [
        @views.spacer(min_length=0.0, weight=top_weight),
        @views.row(row, spacing=0.0, align=Start).frame(
          width=width.max(card_width),
          height=card_height,
        ),
        @views.spacer(min_length=0.0, weight=bottom_weight),
      ],
      spacing=0.0,
    ).frame(width=width.max(card_width), height=usable),
    width=width.max(card_width),
    height=usable,
  )
}

///|
/// 浮动卡的内容高度：头 + （折叠条 + 线程区）+ 上下文芯片 + 输入行 + 决策行。
/// 卡片高度必须**统一算**——视图层与避让预留（ai_reserve）各算一份，
/// 预留量就会和实际遮挡对不上。
pub fn ai_card_height(model : Model, card_width : Double) -> Double {
  ignore(card_width)
  card_chrome_height(model) + thread_area_height(model)
}

///|
/// 线程区高度：`ai_card_body` 的 scroll_view 用它，`ai_card_height` 也用它。
/// **只能有一处算**——视图层和高度预算各算一份，卡片就会裁掉自己的内容
/// （或反过来留一块空白）。
fn thread_area_height(model : Model) -> Double {
  if model.ai_cards.length() == 0 || model.ai_cards_folded {
    0.0
  } else {
    // 线程区有 280 的上限（见 ai_card_body 的 scroll_view）
    (6.0 * model.ai_cards.length().to_double() + 40.0).min(280.0)
  }
}

///|
/// 卡内除线程区以外的固定高度（头 + 折叠条 + #seeAll + 芯片 + 输入条 +
/// 决策行 + 内边距）。线程区的预算是「卡高 − 这个数」。
fn card_chrome_height(model : Model) -> Double {
  // 芯片行恒占位（没有用户芯片时显示「+ @按钮」快捷建议，不是空行）。
  let mut height = PANEL_HEAD_HEIGHT +
    CHIPS_HEIGHT +
    COMPOSER_HEIGHT +
    decision_bar_height(model) +
    12.0
  if model.ai_cards.length() > 0 {
    height = height + FOLD_BAR_HEIGHT
    // 「查看全部会话 →」与线程区同条件出现（>3 条且未折叠）——
    // 视图层加了行而这里不加高度，卡片就会把它裁掉。
    if !model.ai_cards_folded && model.ai_cards.length() > 3 {
      height = height + SEE_ALL_HEIGHT
    }
  }
  if ai_hero(model) {
    height = height + HERO_HINT_HEIGHT
  }
  height
}

///|
/// 设计稿 `#aiLayer.hero`：**空舞台**时输入框升格成主角——升到上方、
/// 加宽到 700、并列出示例指令。这是「从零开始」时唯一有意义的入口，
/// 所以只有 `WsEmpty` 触发（有内容时抢焦点反而碍事）。
pub fn ai_hero(model : Model) -> Bool {
  model.workspace is WsEmpty && !model.ai_pill && !(model.ai_anchor is AiDocked)
}

///|
/// 示例指令芯片行高（hero 专属）。
pub const HERO_HINT_HEIGHT : Double = 30.0

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
  let head = @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.text(
            text(t, "app.ai.title"),
            theme=studio_theme(),
            width=120.0,
            height=18.0,
            align=TextStart,
          ).foreground(ide_text()),
          count_badge(
            if model.provider_mode is Fake {
              text(t, "app.ai.fake")
            } else {
              text(t, "app.ai.real")
            },
            if model.provider_mode is Fake {
              0
            } else {
              4
            },
          ),
          @views.spacer(min_length=4.0, weight=1.0),
          icon_button(
            Focus,
            text(t, "app.ai.anchor"),
            false,
            CycleAiAnchor,
            24.0,
            22.0,
            12.0,
          ),
          icon_button(
            Minus,
            text(t, "app.ai.pill"),
            model.ai_pill,
            ToggleAiPill,
            24.0,
            22.0,
            12.0,
          ),
          icon_button(
            Columns,
            text(t, "app.ai.dock"),
            model.ai_anchor is AiDocked,
            SetAiAnchor(
              if model.ai_anchor is AiDocked {
                AiCenter
              } else {
                AiDocked
              },
            ),
            24.0,
            22.0,
            12.0,
          ),
          icon_button(
            Settings,
            text(t, "app.ai.settings"),
            model.provider_settings_open,
            ToggleProviderSettings,
            24.0,
            22.0,
            12.0,
          ),
        ],
        (width - 16.0).max(80.0),
        4.0,
        Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel_alt(),
    height=PANEL_HEAD_HEIGHT,
    width~,
    padding=0.0,
  )
  let body : Array[@moui.View[Msg]] = [head]
  // 折叠条：有待审计卡时显示计数并允许折叠线程
  let pending = pending_ai_cards(model)
  if model.ai_cards.length() > 0 {
    body.push(fold_bar(model, t, width, pending))
    if !model.ai_cards_folded {
      body.push(
        @views.scroll_view(
          @views.column(ai_card_views(model, t, width), spacing=6.0),
          width~,
          // thread_height 已是共享 helper 算出的线程区预算（含 280 上限），
          // 这里不再二次钳制——两处各钳一次，改了上限就会漏改一处。
          height=thread_height,
          shows_indicator=true,
        ),
      )
      // 设计稿 `#seeAll`：线程超过 3 条时给一个「查看全部会话 →」的出口
      // （折叠态不显示——折叠时线程区本来就收起了）。跳的是既有 AI 历史
      // 对话框，不新开一页。
      if model.ai_cards.length() > 3 {
        body.push(see_all_row(t, width))
      }
    }
  }
  body.push(context_chips(model, t, width))
  body.push(composer(model, t, width))
  if ai_hero(model) {
    body.push(hero_hints(model, t, width))
  }
  body.push(decision_bar(model, t, width))
  @views.container(
    @views.column(body, spacing=0.0),
    background=ide_elevated(),
    corner_radius=6.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(ide_border()),
        width=1.0,
      ),
    ),
    width~,
    padding=0.0,
  )
}

///|
/// 「查看全部会话 →」：线程多了以后卡片区只能滚动看，给一个直达既有
/// AI 历史对话框的出口（设计稿 `#seeAll`）。
fn see_all_row(t : @i18n.Translator, width : Double) -> @moui.View[Msg] {
  let label_width = 110.0
  @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.spacer(min_length=0.0, weight=1.0),
          @views.container(
            @views.center(
              @views.text(
                text(t, "app.ai.see_all"),
                theme=studio_theme(),
                width=label_width,
                height=16.0,
              ).foreground(ide_accent()),
              width=label_width + 12.0,
              height=18.0,
            ),
            background=ide_panel_alt(),
            corner_radius=4.0,
            width=label_width + 12.0,
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
  for card in model.ai_cards {
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
  // 副作用卡 / diff 卡：待审计时给采纳/拒绝
  if !card.settled && (card.kind is CardDiff || card.kind is CardSideEffect) {
    rows.push(
      @views.row(
        [
          @views.button(
            text(t, "app.ai.accept"),
            on_click=AcceptProposal,
            variant=Primary,
            width=72.0,
            height=24.0,
          ),
          @views.button(
            text(t, "app.ai.reject"),
            on_click=RejectProposal,
            variant=Outline,
            width=72.0,
            height=24.0,
          ),
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
/// 上下文芯片行：`+ @选中对象` 快捷加芯片，已有芯片可点掉。
fn context_chips(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let chips : Array[@moui.View[Msg]] = []
  let mut index = 0
  for chip in model.ai_context_chips {
    chips.push(
      @views.container(
        @views.center(
          @views.text(
            "\{chip} ×",
            theme=studio_theme(),
            width=68.0,
            height=16.0,
          ).foreground(ide_accent()),
          width=76.0,
          height=20.0,
        ),
        background=ide_selection(),
        corner_radius=10.0,
        width=76.0,
        height=20.0,
        padding=0.0,
      ).on_tap(RemoveAiContextChip(index)),
    )
    index = index + 1
  }
  // 快捷添加：当前选中对象（控件名或子程序键）
  let suggestion = match find_selected_control(model) {
    Some(control) => Some(control.name)
    None =>
      match current_handler(model) {
        Some(handler) => Some(handler.control_name)
        None => None
      }
  }
  match suggestion {
    Some(name) =>
      if !model.ai_context_chips.contains(name) {
        chips.push(
          @views.container(
            @views.center(
              @views.text(
                "+ @\{name}",
                theme=studio_theme(),
                width=92.0,
                height=16.0,
              ).foreground(ide_text_muted()),
              width=100.0,
              height=20.0,
            ),
            background=ide_panel_alt(),
            corner_radius=10.0,
            width=100.0,
            height=20.0,
            padding=0.0,
          ).on_tap(AddAiContextChip(name)),
        )
      }
    None => ()
  }
  if chips.length() == 0 {
    return @views.container(
      @views.padding_xy(
        @views.text(
          text(t, "app.ai.no_context"),
          theme=studio_theme(),
          width=(width - 20.0).max(60.0),
          height=16.0,
          align=TextStart,
        ).foreground(ide_text_faint()),
        horizontal=8.0,
        vertical=0.0,
      ),
      height=24.0,
      width~,
      padding=0.0,
    )
  }
  @views.container(
    @views.padding_xy(
      @views.row(chips, spacing=4.0, align=Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    height=26.0,
    width~,
    padding=0.0,
  )
}

///|
/// 输入条：模式段（修改/生成/解释/修复）+ 输入框 + 发送。
///
/// 设计稿的 `.cfoot` 是「模式段 + 弹性空隙 + 发送」，不是两个宽按钮。
/// 手搓模式段而不用 @views.button：button 的 `width`/`height` 进的是
/// `min_size`，文字比声明的宽就会自己长大顶出卡片（「解释这个程序」
/// 实测 92.8 > 声明的 72，就是这么溢出的）。
fn composer(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let modes : Array[@moui.View[Msg]] = [
    composer_mode_chip(model, t, ComposeEdit, "app.ai.mode.edit"),
    composer_mode_chip(model, t, ComposeGenerate, "app.ai.mode.generate"),
    composer_mode_chip(model, t, ComposeExplain, "app.ai.mode.explain"),
    composer_mode_chip(model, t, ComposeRepair, "app.ai.mode.repair"),
  ]
  let seg_width = 4.0 * 40.0 + 3.0 * 3.0
  let send_width = 62.0
  let field_width = (width - 16.0 - seg_width - send_width - 12.0).max(70.0)
  let foot = fill_row(
    [
      @views.row(modes, spacing=3.0, align=Center),
      @views.spacer(min_length=6.0, weight=1.0),
      // 发送按钮手搓：同上，避免按钮自撑宽顶出卡片。
      @views.container(
        @views.center(
          @views.text(
            text(t, "app.ai.send"),
            theme=studio_theme(),
            width=(send_width - 12.0).max(20.0),
            height=16.0,
          ).foreground(@core.Color::white()),
          width=send_width,
          height=22.0,
        ),
        background=ide_accent(),
        corner_radius=4.0,
        width=send_width,
        height=22.0,
        padding=0.0,
      ).on_tap(ComposerRun),
    ],
    (width - 16.0).max(120.0),
    6.0,
    Center,
  )
  @views.container(
    @views.column(
      [
        composer_tools(model, t, width),
        @views.padding_xy(
          @views.text_field(
            model.prompt_draft,
            on_input=value => SetPrompt(value),
            placeholder=text(t, "app.ai.prompt"),
            variant=Outline,
            width=(width - 16.0).max(80.0),
            height=FIELD_HEIGHT,
          ),
          horizontal=8.0,
          vertical=2.0,
        ),
        @views.padding_xy(foot, horizontal=8.0, vertical=2.0),
      ],
      spacing=0.0,
    ).frame(width~, height=COMPOSER_HEIGHT),
    width~,
    height=COMPOSER_HEIGHT,
    padding=0.0,
  )
}

///|
/// 锚点读数（设计稿 `#posHint`）：让人不用猜「现在这条会飘在哪」。
pub fn anchor_hint_key(anchor : AiAnchor) -> String {
  match anchor {
    AiCenter => "app.ai.anchor.center"
    AiLeft => "app.ai.anchor.left"
    AiRight => "app.ai.anchor.right"
    AiDocked => "app.ai.anchor.docked"
  }
}

///|
/// 输入条工具行（设计稿 `.ctools`）：锚点图标 + 当前锚点读数 + 弹性空隙
/// + 锚点/侧栏/收起三个**带名字**的按钮。
///
/// 设计稿这里靠 `:hover` 提亮（默认 `opacity:.4`），本实现没有 hover 回调
/// （`ctx.state.hovered` 拿不到逐元素悬停），所以常亮显示——把「锚点循环」
/// 和「收起」藏在一个要悬停才现形的地方，等于让人找不到这两个操作。
fn composer_tools(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let docked = model.ai_anchor is AiDocked
  let cells : Array[@moui.View[Msg]] = [
    @views.icon(Focus, size=11.0, color=ide_text_faint()),
    @views.text(
      text(t, anchor_hint_key(model.ai_anchor)),
      theme=studio_theme(),
      width=72.0,
      height=16.0,
    ).foreground(ide_text_faint()),
    @views.spacer(min_length=4.0, weight=1.0),
    composer_tool_chip(t, "app.ai.anchor", 62.0, CycleAiAnchor),
    composer_tool_chip(
      t,
      if docked {
        "app.ai.undock"
      } else {
        "app.ai.dock"
      },
      62.0,
      if docked {
        SetAiAnchor(AiCenter)
      } else {
        SetAiAnchor(AiDocked)
      },
    ),
    composer_tool_chip(t, "app.ai.collapse", 54.0, ToggleAiPill),
  ]
  @views.container(
    @views.padding_xy(
      fill_row(cells, (width - 16.0).max(120.0), 4.0, Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    width~,
    height=COMPOSER_TOOLS_HEIGHT,
    padding=0.0,
  )
}

///|
/// 工具行按钮：手搓（`@views.button` 的宽高是最小值，见 composer 注释）。
fn composer_tool_chip(
  t : @i18n.Translator,
  key : String,
  chip_width : Double,
  msg : Msg,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      @views.text(
        text(t, key),
        theme=studio_theme(),
        width=(chip_width - 10.0).max(20.0),
        height=16.0,
      ).foreground(ide_text_muted()),
      width=chip_width,
      height=18.0,
    ),
    background=ide_panel_alt(),
    corner_radius=4.0,
    width=chip_width,
    height=18.0,
    padding=0.0,
  ).on_tap(msg)
}

///|
/// hero 示例指令行（设计稿 `#heroChips`）：空舞台时给三条可点即填的
/// 例子——「从零开始」最缺的是「我能说什么」。点击只**填输入框**
/// （SetPrompt），不直接执行：用户仍要自己按发送，才看得清 Agent 收到
/// 的是什么。
fn hero_hints(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  ignore(model)
  let keys : Array[String] = [
    "app.ai.hero.roll_call", "app.ai.hero.history", "app.ai.hero.explain",
  ]
  let chips : Array[@moui.View[Msg]] = []
  // 三等分是错的：中文示例句比英文长得多，等分会把最长的那条截掉
  // （实测 1000px 宽时「生成一个班级点名册 App」需要 148.6 只拿到 136）。
  // 按每条**实测宽**的比例分配，间距先扣掉。
  let gap = 4.0
  let inner = (width - 16.0).max(120.0)
  // 卡片在窄窗只有 ~460pt，三条中文示例句**放不下**。等比压缩会把文字截成
  // 半个词——那比不显示更糟。所以按自然宽**贪心放得下几条就放几条**，
  // 一条都放不下就留空行（高度预算不变，卡片的排版不会跳）。
  //
  // 需求侧乘 1.05：`text_estimate_width` 比真实字形窄约 3%。
  let mut used = 0.0
  for key in keys {
    let need = text_estimate_width(text(t, key)) * 1.05 + 20.0
    let with_gap = if chips.length() == 0 { need } else { need + gap }
    if used + with_gap > inner && chips.length() > 0 {
      continue
    }
    let cell = need
    chips.push(
      @views.container(
        @views.center(
          @views.text(
            text(t, key),
            theme=studio_theme(),
            width=(cell - 12.0).max(40.0),
            height=16.0,
          ).foreground(ide_text_muted()),
          width=cell,
          height=24.0,
        ),
        background=ide_panel_alt(),
        corner_radius=4.0,
        width=cell,
        height=24.0,
        padding=0.0,
      ).on_tap(SetPrompt(text(t, key))),
    )
    used = used + with_gap
  }
  @views.container(
    @views.padding_xy(
      fill_row(chips, (width - 16.0).max(120.0), 4.0, Center),
      horizontal=8.0,
      vertical=3.0,
    ),
    width~,
    height=HERO_HINT_HEIGHT,
    padding=0.0,
  )
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
  @views.container(
    @views.center(
      @views.text(text(t, key), theme=studio_theme(), width=34.0, height=16.0).foreground(
        if selected {
          ide_accent()
        } else {
          ide_text_faint()
        },
      ),
      width=40.0,
      height=20.0,
    ),
    background=if selected { ide_selection() } else { ide_panel_alt() },
    corner_radius=4.0,
    width=40.0,
    height=20.0,
    padding=0.0,
  ).on_tap(SetComposerMode(mode))
}

///|
/// 决策条：待采纳提案摘要 + 采纳/拒绝 + 历史入口；无提案时显示讲解文本。
fn decision_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
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
      // 校验失败时逐条列出原因（不静默丢弃，也不允许采纳）
      if !pending.valid {
        for error in pending.errors {
          rows.push(
            @views.text(
              "· \{error}",
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
            @views.button(
              text(t, "app.ai.accept"),
              on_click=AcceptProposal,
              variant=Primary,
              width=72.0,
              height=26.0,
            ),
            @views.button(
              text(t, "app.ai.reject"),
              on_click=RejectProposal,
              variant=Outline,
              width=72.0,
              height=26.0,
            ),
            @views.button(
              text(t, "app.ai.history"),
              on_click=ToggleAiHistory,
              variant=Ghost,
              width=72.0,
              height=26.0,
            ),
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
      rows.push(
        @views.row(
          [
            @views.text(
              if model.ai_busy {
                text(t, "app.ai.busy")
              } else {
                text(t, "app.ai.idle")
              },
              theme=studio_theme(),
              width=(width - 100.0).max(60.0),
              height=16.0,
              align=TextStart,
            ).foreground(ide_text_faint()),
            @views.button(
              text(t, "app.ai.history"),
              on_click=ToggleAiHistory,
              variant=Ghost,
              width=72.0,
              height=24.0,
            ),
          ],
          spacing=6.0,
          align=Center,
        ),
      )
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
  match model.pending {
    Some(_) => 26.0 + 4.0 + 26.0
    None => {
      let mut height = 16.0
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

///|
/// AI 药丸：收起态的唯一入口（固定右下，带待审计徽标）。
pub fn ai_pill_view(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
  reserve : Double,
) -> @moui.View[Msg] {
  ignore(reserve)
  let pending = pending_ai_cards(model)
  // 设计稿药丸形态：`<spark/> Agent <span>待审计</span> <b>N</b>`。
  // 「待审计 N」是**待办摘要**不是装饰：药丸收起后卡片全不可见，这是唯一
  // 还告诉你有多少条待采纳提案的地方。
  let cells : Array[@moui.View[Msg]] = [
    @views.icon(Focus, size=13.0, color=ide_accent()),
    @views.text("Agent", theme=studio_theme(), width=44.0, height=18.0).foreground(
      ide_text(),
    ),
  ]
  if pending > 0 {
    cells.push(
      @views.text(
        text(t, "app.ai.pill_pending"),
        theme=studio_theme(),
        width=40.0,
        height=18.0,
      ).foreground(ide_text_muted()),
    )
    cells.push(count_badge(pending.to_string(), 2))
  }
  let pill_view = @views.container(
    @views.padding_xy(
      @views.row(cells, spacing=6.0, align=Center),
      horizontal=10.0,
      vertical=0.0,
    ),
    background=ide_elevated(),
    corner_radius=14.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(ide_border()),
        width=1.0,
      ),
    ),
    height=28.0,
    padding=0.0,
  ).on_tap(ToggleAiPill)
  // 同 ai_floating：贴底靠「权重 spacer + 定高」而不是 align。
  let usable = (height - 12.0).max(28.0)
  @views.container(
    @views.column(
      [
        @views.spacer(min_length=0.0, weight=1.0),
        @views.row(
          [
            @views.spacer(min_length=0.0, weight=1.0),
            @views.container(pill_view, width=180.0, height=28.0, padding=0.0),
          ],
          spacing=0.0,
          align=Center,
        ).frame(width=(width - 16.0).max(200.0), height=28.0),
      ],
      spacing=0.0,
    ).frame(width=(width - 16.0).max(200.0), height=usable),
    width=(width - 16.0).max(200.0),
    height=usable,
    padding=0.0,
  )
}
