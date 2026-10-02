///|
/// 按链下标选中积木（测试助手）：生产代码用位置命中（`BlocksCanvasTap`）与
/// 路径寻址（`select_block_by_path`），`Msg::SelectBlock` 已删除——它没有
/// 生产者（由 `scripts/validate-dead-messages.mjs` 抓出）。测试改走同一寻址。
fn select_block_index(model : Model, index : Int) -> Model {
  let chain = block_chain_of(model)
  if index < 0 || index >= chain.length() {
    return model
  }
  select_block_by_path(model, chain[index].path)
}

///|
/// 窗格与选中的**生命周期**验证：隐藏/恢复路径、AI 药丸态、面板头对齐、
/// 窗格内容不越界、积木窗格的出场条件。
///
/// 从 `shell_responsive_wbtest.mbt` 拆出（原文件 1225 行，超过 1200 硬上限）。
/// 分工：那个文件管**响应式与溢出扫描**（视口从 1440 收到 1000，枚举所有
/// 绘制文字找越界），本文件管**交互状态机**（点一下之后谁该出现、谁该消失）。
/// 两者判据不同：前者是「画得下吗」，后者是「该不该画」。
///
/// 共享的渲染助手（`shell_draw` / `shell_texts` / `shell_rects` /
/// `paint_signature` 等）在同包的 `shell_layout_wbtest.mbt` 与
/// `shell_responsive_wbtest.mbt` 里。

///|
/// 窗格被隐藏之后**必须**还能把它加回来。
///
/// 设计稿的规则（`btnHideLive`/`btnHideBlocks`）：
/// `if(!S.blocks) S.ws='empty'`——关掉**最后一个**窗格就进**空舞台**，
/// 而空舞台自带 `+ Live App` / `+ 积木` 两个入口。
///
/// 回归意义：单窗格分支一度直接 `return live_pane(...)`——两个「隐藏此窗格」
/// 按钮都能点，点了之后那个窗格就**再也回不来**（只能重启）。这是真实可用性
/// 缺陷，不是外观问题。
///
/// 另外钉住一件事：恢复入口**只在空舞台**，单窗格时**不加**恢复带。
/// 曾经在 Live App 头顶压过一条「+ 积木窗格」工具带，那是自己发明的、
/// 设计稿里没有的东西——凭空多一条带子，还挤掉舞台高度。
test "hiding panes funnels into the empty stage with restore entries" {
  let model = initial_model()
  // 隐藏积木窗格：Live App 占满**整列**，且没有恢复带
  let no_blocks = apply_shell(model, TogglePaneBlocks)
  assert_eq(no_blocks.pane_blocks, false)
  let commands = shell_draw(no_blocks, 1280.0, 800.0)
  assert_false(blocks_pane_wanted(no_blocks))
  if shell_has_text(commands, "+ 积木窗格") {
    fail("single-pane layout must not add a restore strip above the pane")
  }
  // Live App 窗格头仍占满：窗格从顶栏正下方开始（没有带子插在中间）
  guard shell_find_text(commands, "实时应用") is Some(head) else {
    fail("live pane head missing")
  }
  if head.frame.origin.y > TOPBAR_HEIGHT + PANEL_HEAD_HEIGHT + 1.0 {
    fail(
      "live pane is pushed down by a restore strip: head y=" +
      head.frame.origin.y.to_string(),
    )
  }
  // 隐藏实时应用：只剩积木，同样没有恢复带
  let no_live = apply_shell(model, TogglePaneLive)
  assert_eq(no_live.pane_live, false)
  if shell_has_text(shell_draw(no_live, 1280.0, 800.0), "+ 实时应用") {
    fail("single-pane layout must not add a restore strip above the pane")
  }
  // 两个都隐藏 → 空舞台，且两个恢复入口都在（这是唯一的恢复路径）
  let none = apply_shell(no_live, TogglePaneBlocks)
  assert_eq(none.pane_live, false)
  assert_eq(none.pane_blocks, false)
  let empty_commands = shell_draw(none, 1280.0, 800.0)
  for label in ["+ 实时应用", "+ 积木窗格"] {
    if !shell_has_text(empty_commands, label) {
      fail("empty stage is missing the restore entry: " + label)
    }
  }
  // 恢复入口必须**真的能点回来**（不是画着好看）
  let back_live = apply_shell(none, ShowPaneLive)
  assert_eq(back_live.pane_live, true)
  assert_true(back_live.workspace is WsVisual)
  assert_true(
    shell_has_text(shell_draw(back_live, 1280.0, 800.0), "实时应用"),
  )
  let back_blocks = apply_shell(none, ShowPaneBlocks)
  assert_eq(back_blocks.pane_blocks, true)
  assert_true(back_blocks.workspace is WsVisual)
  // 积木窗格要画出来还得有选中的子程序——恢复入口必须顺带选上，
  // 否则用户点了按钮只看到 Live App，像是没反应。
  assert_true(blocks_pane_wanted(back_blocks))
  assert_true(
    shell_has_text(shell_draw(back_blocks, 1280.0, 800.0), "IR 映射"),
  )
}

///|
/// 药丸态必须**水平居中**在中心列，且浮动层的外层只做定位、不铺底板。
///
/// 真实缺陷（用户截图）：药丸写死 180 宽、水平只放**右侧**权重 spacer，于是
/// 它贴在中心列右下角（实测中心 x≈900，而列中心是 644）——设计稿
/// `#aiLayer` 是 `left:50%;transform:translateX(-50%)`，收起态同样居中。
///
/// 第二件事是**结构性**的：药丸的定位外层原先是无背景 `@views.container`，
/// 它回落到环境 Base 刷子（不透明面板色），整帧被刷成一块底板把工作区内容
/// 盖掉。同文件 `ai_floating` 的注释里已经记录过这个坑（「位置对、文字也在
/// 绘制流里，但屏幕上什么都没有」），药丸这条路径漏改了。这里断言「药丸带里
/// 没有任何横跨整个中心列宽度的填充」把这个结构钉住。
///
/// 注：这条 slab 断言在 **Web 目标下不会复现**（浏览器里那个无背景 container
/// 没画出填充，实测中心列填充只有 398/321 宽），它主要在原生沉浸式窗口里
/// 可见。所以这里钉的是结构（外层不许有表面绘制），而不是某次渲染的具体像素。
test "AI pill stays centred and paints no slab over the workspace" {
  let model = initial_model()
  let pill = apply_shell(model, ToggleAiPill)
  assert_true(pill.ai_pill)
  let commands = shell_draw(pill, 1280.0, 800.0)
  // 中心列的水平范围（图标栏 + 左栏之后，右栏之前）
  let widths = shell_chrome_widths(pill, 1280.0 - ICONBAR_WIDTH)
  let center_left = ICONBAR_WIDTH + 2.0 + LEFTBAR_WIDTH + 1.0
  let center_right = center_left + widths.center
  // 药丸本体：找「Agent」标签所在的那颗圆角盒。
  guard shell_find_text(commands, "Agent") is Some(agent) else {
    fail("AI pill label missing")
  }
  let mut pill_box : @core.Rect? = None
  for rect in shell_rects(commands) {
    let contains = rect.origin.x <= agent.frame.origin.x + 0.5 &&
      rect.origin.x + rect.size.width >=
      agent.frame.origin.x + agent.frame.size.width - 0.5 &&
      rect.origin.y <= agent.frame.origin.y + 0.5 &&
      rect.origin.y + rect.size.height >=
      agent.frame.origin.y + agent.frame.size.height - 0.5
    // 药丸盒比文字宽（有内垫）但不可能是整列
    if contains &&
      rect.size.width > agent.frame.size.width &&
      rect.size.width < widths.center / 2.0 {
      pill_box = Some(rect)
    }
  }
  guard pill_box is Some(box) else {
    fail("could not locate the AI pill box around its label")
  }
  let pill_center = box.origin.x + box.size.width / 2.0
  let column_center = center_left + widths.center / 2.0
  if (pill_center - column_center).abs() > 6.0 {
    fail(
      "AI pill is not centred in the workspace column: pill centre=" +
      pill_center.to_string() +
      " column centre=" +
      column_center.to_string(),
    )
  }
  // 药丸必须留在中心列内（不能横跨到右栏或左栏）
  if box.origin.x < center_left - 0.5 ||
    box.origin.x + box.size.width > center_right + 0.5 {
    fail("AI pill escapes the workspace column")
  }
  // 定位外层不许铺底板：药丸那条纵向带里不得出现「从中心列左缘起、横跨
  // 整列宽度」的填充。根窗口底色从 x=0 起铺满整窗（早于所有内容），所以
  // 用「起点贴中心列左缘」把它排除掉。
  for rect in shell_rects(commands) {
    let starts_at_column = (rect.origin.x - center_left).abs() < 2.0
    let spans_column = rect.size.width >= widths.center * 0.9
    let in_pill_band = rect.origin.y + rect.size.height >= agent.frame.origin.y &&
      rect.origin.y <= agent.frame.origin.y + agent.frame.size.height
    if starts_at_column && spans_column && in_pill_band {
      fail(
        "pill wrapper paints a column-wide slab (width=" +
        rect.size.width.to_string() +
        " at y=" +
        rect.origin.y.to_string() +
        ")",
      )
    }
  }
}

///|
/// 拖拽区避开动作簇这条约束**必须在两种语言下都成立**。
///
/// 回归意义：动作簇宽度随文案变化（英文 "Compile MoonBit" 比中文「编译
/// MoonBit」更宽），而拖拽区宽度是按标签估算出来的。只测中文会把「英文下
/// 盖住按钮」整个漏掉——而英文恰恰是更宽的那一侧。
test "drag region clears the top bar actions in both locales" {
  let cases : Array[(String, Model)] = [
    ("zh", initial_model(immersive=true)),
    ("en", apply_shell(initial_model(immersive=true), SwitchLanguage)),
  ]
  for case in cases {
    let (locale, model) = case
    let t = translator(model)
    for width in [1440.0, 1280.0, 1000.0, 900.0] {
      let drag_width = topbar_drag_width(model, t, width)
      let commands = shell_draw(model, width, 800.0)
      // 边界取**按钮盒**左缘，不是标签左缘：标签两侧各有 16pt 内垫，按钮盒
      // 比它的文字宽 32pt。只比标签会漏掉「拖拽区盖住按钮左半边内垫」——
      // 那一样点不动（落在内垫上的按下也被拖拽区吃掉）。
      let labels = [
        text(t, "app.run.start"),
        text(t, "app.run.stop"),
        text(t, "app.run.step"),
        text(t, "app.topbar.compile"),
      ]
      let mut leftmost_box = 100000.0
      for label in labels {
        match shell_find_text(commands, label) {
          Some(run) =>
            for rect in shell_rects(commands) {
              let contains = rect.origin.x <= run.frame.origin.x + 0.5 &&
                rect.origin.y <= run.frame.origin.y + 0.5 &&
                rect.origin.x + rect.size.width >=
                run.frame.origin.x + run.frame.size.width - 0.5 &&
                rect.origin.y + rect.size.height >=
                run.frame.origin.y + run.frame.size.height - 0.5
              if contains &&
                rect.size.width > run.frame.size.width &&
                rect.size.width < width * 0.5 {
                leftmost_box = leftmost_box.min(rect.origin.x)
              }
            }
          None => ()
        }
      }
      if leftmost_box > 99999.0 {
        fail(
          locale + ": no action button box found at width " + width.to_string(),
        )
      }
      if drag_width > leftmost_box {
        fail(
          locale +
          " at width " +
          width.to_string() +
          ": drag region (right edge " +
          drag_width.to_string() +
          ") overruns the leftmost action button box (x=" +
          leftmost_box.to_string() +
          ")",
        )
      }
    }
  }
}

///|
/// **窗格头里的每一段文字都必须落在它自己的窗格内**。
///
/// 回归意义（真实截图）：积木窗格头的固定需求是
/// `8+8 + 标题90 + 副标题120 + (IR尾巴140 + 24 + 24) + 5×6 = 444`，而积木
/// 窗格在 1280 窗口下只有 ~398（中心列 724 × split 0.55）。副标题是按钮前
/// 最后一格，于是「IR 映射 · 与代码同步」被裁成「IR 映射 · 与」——实测右缘
/// 1077.2 越出中心列右缘 1006 达 71pt。
///
/// 为什么这条要单独测：`overflow_report` 只查**未裁剪**的文字，而窗格头是
/// 被面板裁剪区包着的，所以那一整套越界扫描**看不见**这处溢出。这是第三类
/// 盲区：裁剪区内的溢出。
test "pane head text stays inside its own pane" {
  let base = initial_model()
  for width in [1440.0, 1280.0, 1100.0, 1000.0] {
    let chrome = shell_chrome_widths(base, width - ICONBAR_WIDTH)
    let iconbar = ICONBAR_WIDTH
    let left_edge = iconbar + 1.0
    let left_right = left_edge + LEFTBAR_WIDTH
    let centre_left = left_right + 1.0
    let centre_right = centre_left + chrome.center
    let right_left = centre_right + 1.0
    let right_right = right_left + chrome.right
    let code = apply_shell(base, SetWorkSpace(WsCode))
    let empty = apply_shell(code, SetWorkSpace(WsEmpty))
    let cases : Array[(String, Model)] = [
      ("visual", base),
      ("code", code),
      ("empty", empty),
    ]
    for case in cases {
      let (name, model) = case
      let commands = shell_draw(model, width, 800.0)
      for run in shell_texts(commands) {
        // 只看窗格头那一行（顶栏之下、内容之上）
        let in_head_band = run.frame.origin.y > TOPBAR_HEIGHT - 1.0 &&
          run.frame.origin.y < TOPBAR_HEIGHT + PANEL_HEAD_HEIGHT
        if !in_head_band {
          continue
        }
        let right = run.frame.origin.x + run.frame.size.width
        let left = run.frame.origin.x
        // 这一段属于哪个窗格：按它的左缘落点判定
        let (pane_name, pane_left, pane_right) = if left >= right_left - 0.5 {
          ("right", right_left, right_right)
        } else if left >= centre_left - 0.5 {
          ("centre", centre_left, centre_right)
        } else {
          ("left", left_edge, left_right)
        }
        if right > pane_right + 0.5 || left < pane_left - 0.5 {
          fail(
            "pane head text escapes its " +
            pane_name +
            " pane at width " +
            width.to_string() +
            " (" +
            name +
            "): '" +
            run.text +
            "' spans " +
            left.to_string() +
            ".." +
            right.to_string() +
            " but the pane is " +
            pane_left.to_string() +
            ".." +
            pane_right.to_string(),
          )
        }
      }
    }
  }
}

///|
/// **裁剪区内部的溢出**也要扫：`overflow_report` 只查未被裁剪的文字，而面板
/// 内容是被裁剪区包着的——面板里画到面板外的文字，它一个字都看不见。
///
/// 这条专门覆盖积木编辑条：`8 + text_area(width-190) + 64 + 64 + 2×6 = width`
/// 这类「减一个常数」的算法一旦常数写错，最右一个按钮就被面板裁掉半个词
/// （实际截图里「删除语句」只露出「删除语句」的左半边）。

///|
/// **裁剪区内部的溢出**也必须扫。
///
/// `overflow_report` 只查**未被裁剪**的文字（理由充分：滚动区里的内容越出
/// 视口是设计如此）。但它因此看不见另一半问题：面板内容画到面板外——那段
/// 文字是被面板的裁剪区切掉的，`clips.length() == 0` 不成立，整套扫描直接
/// 跳过。这是第三类盲区，和「窗格头」那条同源。
///
/// 判据：对每段文字，找**包住它的最内层裁剪区**（就是它所属的面板），断言
/// 文字的右缘不越过这个裁剪区。用裁剪区而不是「中心列 x 范围」是因为右栏
/// 也在中心列右侧：按 x 过滤会把右栏自己的页签误判成溢出（第一版就这么
/// 误报过）。
test "text never escapes its own clip region" {
  let base = initial_model()
  let code = apply_shell(base, SetWorkSpace(WsCode))
  let empty = apply_shell(code, SetWorkSpace(WsEmpty))
  let cases : Array[(String, Model)] = [
    ("visual", base),
    ("code", code),
    ("empty", empty),
  ]
  for width in [1440.0, 1280.0, 1100.0, 1000.0] {
    for case in cases {
      let (name, model) = case
      let commands = shell_draw(model, width, 800.0)
      let clips : Array[@core.Rect] = []
      for command in commands {
        match command {
          @core.PushClip(rect) => clips.push(rect)
          @core.PopClip => if clips.length() > 0 { ignore(clips.pop()) }
          @core.DrawText(run) =>
            // 空文字只是占位（如 `@views.text("")` 撑宽度的 spacing 占位），
            // 画不出任何像素，越界也无害——把它算进来只会制造噪音。
            if clips.length() > 0 && run.text != "" {
              // 最内层裁剪区 = 这段文字所属的面板
              let pane = clips[clips.length() - 1]
              let right = run.frame.origin.x + run.frame.size.width
              // 容差 1.5：裁剪区边界与文字帧之间有亚像素舍入
              if right > pane.origin.x + pane.size.width + 1.5 {
                fail(
                  name +
                  " at width " +
                  width.to_string() +
                  ": text '" +
                  run.text +
                  "' right=" +
                  right.to_string() +
                  " escapes its clip region right=" +
                  (pane.origin.x + pane.size.width).to_string(),
                )
              }
            }
          _ => ()
        }
      }
    }
  }
}

///|
/// 积木编辑卡（选中块下方就地展开的那张卡）必须完整塞进窗格。
///
/// 回归意义：编辑面曾在积木链条里就地展开（Scratch 口径），把画布切成
/// 三段——块一多，上下两段各只剩几行，用户读到的是「点积木后下面内容
/// 显示不全」。现在编辑面在**右栏**（成熟 IDE 的「选中在画布、编辑在
/// 检查器」分工），本用例锁定三件事：
///
/// 1. 编辑卡的文字落在**右栏**里，不再出现在积木窗格；
/// 2. 卡内可见文字不越过右栏左右缘（旧版编辑条把两颗文字按钮挤在一行，
///    真实总宽超出窗格 6pt，最右按钮被裁掉半个词）；
/// 3. 画布高度**不随选中变化**——这是「链条不再被切开」的可判定证据
///    （旧版选中会让画布高度 -34，滚动位置跟着跳一次）。
test "block editor lives in the right panel and fits it" {
  let base = initial_model()
  // 选中一个块才会出现编辑卡（未选中时右栏没有这一段），再把草稿清空：
  // 占位提示只在空草稿下渲染（有草稿时显示的是语句源码）。
  let selected = select_block_index(base, 0)
  let cleared = apply_shell(selected, EditBlock(""))
  let blocks = block_chain_of(cleared)
  assert_true(
    cleared.selected_block >= 0 && cleared.selected_block < blocks.length(),
  )
  let chip_label = text(
    translator(cleared),
    @blocks.block_label_key(blocks[cleared.selected_block].kind),
  )
  // 编辑卡的**唯一**文案（种类徽章的文字与分类轨重名，不能单独当判据）：
  // 卡标题 + 输入框占位提示。两者都只在右栏编辑卡里出现。
  let title_label = text(translator(cleared), "app.block.edit_title")
  let placeholder = text(translator(cleared), "app.block.editor_hint")
  let chrome = shell_chrome_widths(cleared, 1280.0 - ICONBAR_WIDTH)
  // 右栏左缘 = 图标栏 + 左栏 + 中心列 + 两条发丝线；右缘 = 窗口右缘。
  let right_left = ICONBAR_WIDTH +
    1.0 +
    LEFTBAR_WIDTH +
    1.0 +
    chrome.center +
    1.0
  let right_right = 1280.0
  let commands = shell_draw(cleared, 1280.0, 800.0)
  for needle in [title_label, placeholder] {
    let mut hits = 0
    for run in shell_texts(commands) {
      if !run.text.contains(needle) {
        continue
      }
      hits = hits + 1
      let left = run.frame.origin.x
      let right = run.frame.origin.x + run.frame.size.width
      if left < right_left - 0.5 || right > right_right + 0.5 {
        fail(
          "block editor text '" +
          needle +
          "' is not inside the right panel: " +
          left.to_string() +
          ".." +
          right.to_string() +
          " panel=" +
          right_left.to_string() +
          ".." +
          right_right.to_string(),
        )
      }
    }
    if hits == 0 {
      fail("block editor is missing visible text '" + needle + "'")
    }
  }
  // 种类徽章确实在右栏编辑卡里（同一文字在分类轨也有一份，所以判据是
  // 「右栏内至少出现一次」而不是「唯一出现」）。
  let mut chip_in_panel = false
  for run in shell_texts(commands) {
    if run.text.contains(chip_label) && run.frame.origin.x >= right_left - 0.5 {
      chip_in_panel = true
    }
  }
  assert_true(chip_in_panel)
  // 编辑面搬出链条之后，画布高度与选中无关（链条永远是一条连续链）。
  assert_eq(blocks_body_height(cleared, 800.0), blocks_body_height(base, 800.0))
}

///|
/// 面板头的**尾部动作必须贴住面板右缘**。
///
/// 回归意义：`panel_head` 里权重 spacer 曾写成 `weight=0.0`——它分不到
/// slack，右端剩下的 40pt 空白就堆在动作**之后**。左栏的关闭 ✕ 因此停在离
/// 右缘 40pt 的地方（实测 ✕ 中心 css x 221.8，面板右缘 281），看起来
/// 「位置不对」。这正是用户报的那条。
test "panel head trailing actions hug the panel right edge" {
  let model = initial_model()
  let _chrome = shell_chrome_widths(model, 1280.0 - ICONBAR_WIDTH)
  let left_edge = ICONBAR_WIDTH + 1.0
  let left_right = left_edge + LEFTBAR_WIDTH
  let commands = shell_draw(model, 1280.0, 800.0)
  // 左栏头行的关闭图标：在头行带内、落在左栏 x 范围里
  let mut rightmost = 0.0
  for rect in shell_rects(commands) {
    let in_head = rect.origin.y >= TOPBAR_HEIGHT - 1.0 &&
      rect.origin.y < TOPBAR_HEIGHT + PANEL_HEAD_HEIGHT
    let in_left = rect.origin.x >= left_edge - 1.0 && rect.origin.x < left_right
    // 关闭按钮是 22 宽的小方块（20 宽图标盒 + 圆角底）
    if in_head && in_left && rect.size.width >= 16.0 && rect.size.width <= 30.0 {
      rightmost = rightmost.max(rect.origin.x + rect.size.width)
    }
  }
  if rightmost == 0.0 {
    fail("no panel-head trailing action found in the left panel head")
  }
  // 内垫 8pt，允许 4pt 误差
  let expected = left_right - 8.0
  if rightmost < expected - 4.0 {
    fail(
      "panel head action does not hug the right edge: right=" +
      rightmost.to_string() +
      " expected ~" +
      expected.to_string() +
      " (panel right " +
      left_right.to_string() +
      ")",
    )
  }
}

///|
/// 清空选中必须**同时**清掉控件与事件子程序。
///
/// 回归意义：只清控件的话，`context_head` 会回退到 `current_handler`，
/// 右栏继续显示上一个子程序——用户点了「清空选中」却发现内容没变。
test "clearing the selection leaves nothing selected" {
  let model = initial_model()
  assert_true(model.selected_control != "")
  assert_true(model.selected_handler != "")
  let cleared = apply_shell(model, ClearSelection)
  assert_eq(cleared.selected_control, "")
  assert_eq(cleared.selected_handler, "")
  assert_eq(cleared.selected_block, -1)
  let commands = shell_draw(cleared, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "未选中对象"))
}

///|
/// 积木窗格**跟随选中**：只有选中事件子程序时才在场。
///
/// 回归意义：积木是 `Handler.body` 的投影——没选子程序时它必然是空画布，
/// 却占掉一半中心列。用户要求「积木界面只有在需要的时候才出来」。
test "blocks pane appears only while an event handler is selected" {
  let model = initial_model()
  // 默认选中「按钮」控件 + 它的 on_click 子程序 → 需要积木
  assert_true(blocks_pane_wanted(model))
  // 判据用积木窗格**独有**的副标题，不能用「积木」两个字：积木分类轨里
  // 也有一个叫「积木」的分类项，`shell_has_text` 会撞上（本会话踩过
  // 「同名字符串出现在多个面板」这个坑）。
  // 用前缀而不是整串：`fit_label` 会按窗格宽截断成「IR 映射 · …」，
  // 断言整串会在窄窗格下误报。
  let pane_marker = "IR 映射"
  let commands = shell_draw(model, 1280.0, 800.0)
  assert_true(shell_has_text(commands, pane_marker))
  // 只选控件（树里点控件）→ 不再需要积木，Live App 占满
  let control_only = apply_shell(model, SelectControl("按钮"))
  assert_eq(control_only.selected_handler, "")
  assert_false(blocks_pane_wanted(control_only))
  let control_commands = shell_draw(control_only, 1280.0, 800.0)
  // 积木窗格头不在了。这里**不再断言恢复带**：单窗格不加带子，恢复入口统一
  // 在空舞台（见 "hiding panes funnels into the empty stage"）。
  if shell_find_text(control_commands, pane_marker) is Some(_) {
    fail("blocks pane is still on screen after selecting a control")
  }
  // Live App 窗格必须还在（隐藏积木不等于隐藏一切），且占满整列
  assert_true(shell_has_text(control_commands, "实时应用"))
  // 选回子程序 → 积木回来
  let back = apply_shell(control_only, SelectHandler("按钮@on_click"))
  assert_true(blocks_pane_wanted(back))
  assert_true(shell_has_text(shell_draw(back, 1280.0, 800.0), pane_marker))
  // 清空选中 → 也不需要积木
  assert_false(blocks_pane_wanted(apply_shell(model, ClearSelection)))
}

///|
/// 右栏头的 ✕ **关闭整个右栏**，而不是清空选中。
///
/// 回归意义（用户报的）：上一版把 `ClearSelection` 放在了右栏头整行的**最右
/// 端**——那正是「关闭面板」按钮该在的位置（左栏的 ✕ 就在那里）。于是点它
/// 只是清了选中、面板纹丝不动，读到语义就是「关闭右栏关错了东西」。
/// 设计稿里两者是分开的：`#clearSel` 是对象芯片内部的小 ✕，面板关闭按钮
/// 属于窗格头。
///
/// 判据：右栏头必须同时存在两个不同语义的 ✕，且**收起右栏**的那个在更靠右
/// 的位置；点它之后右栏真的消失（宽度归零、不画分隔线），并且能从图标栏
/// 重新打开。
test "the right panel head closes the panel, not the selection" {
  let model = initial_model()
  assert_true(model.right_visible)
  // 收起：右栏宽度归零，中心列吃掉这份宽度
  let hidden = apply_shell(model, SetRightVisible(false))
  assert_eq(hidden.right_visible, false)
  let widths = shell_chrome_widths(model, 1280.0 - ICONBAR_WIDTH)
  let hidden_widths = shell_chrome_widths(hidden, 1280.0)
  assert_eq(hidden_widths.right, 0.0)
  if hidden_widths.center <= widths.center {
    fail(
      "hiding the right panel must give its width back to the centre: centre " +
      widths.center.to_string() +
      " -> " +
      hidden_widths.center.to_string(),
    )
  }
  // 面板内容与它左侧的分隔线都不再画
  let hidden_commands = shell_draw(hidden, 1280.0, 800.0)
  for label in ["快速操作", "运行时监视"] {
    if shell_has_text(hidden_commands, label) {
      fail("right panel content is still drawn after closing it: " + label)
    }
  }
  // 选中**不受影响**：关闭面板不是清空选中，两者语义必须独立
  assert_eq(hidden.selected_control, model.selected_control)
  assert_eq(hidden.selected_handler, model.selected_handler)
  // 重新打开：图标栏的入口必须能把它带回来
  let back = apply_shell(hidden, SetRightVisible(true))
  assert_true(back.right_visible)
  assert_true(shell_has_text(shell_draw(back, 1280.0, 800.0), "快速操作"))
  // 头的右上角那个 ✕ 是「关闭面板」，它必须比「清空选中」的 ✕ 更靠右。
  // 两个 ✕ 都是 20/18pt 的小按钮，用图标盒位置区分。
  let commands = shell_draw(model, 1280.0, 800.0)
  let right_edge = ICONBAR_WIDTH + 2.0 + LEFTBAR_WIDTH + 1.0 + widths.center
  let close_boxes : Array[Double] = []
  for rect in shell_rects(commands) {
    let in_head = rect.origin.y >= TOPBAR_HEIGHT - 1.0 &&
      rect.origin.y < TOPBAR_HEIGHT + PANEL_HEAD_HEIGHT
    if in_head &&
      rect.origin.x > right_edge &&
      rect.size.width >= 14.0 &&
      rect.size.width <= 24.0 {
      close_boxes.push(rect.origin.x)
    }
  }
  close_boxes.sort()
  if close_boxes.length() < 2 {
    fail(
      "expected two distinct head buttons (clear selection + close panel), found " +
      close_boxes.length().to_string(),
    )
  }
  // 最靠右的那个必须靠近面板右缘（关闭按钮），而不是停在中间
  let rightmost = close_boxes[close_boxes.length() - 1]
  let panel_right = right_edge + widths.right
  if rightmost < panel_right - 32.0 {
    fail(
      "the rightmost head button is not the panel-close one: x=" +
      rightmost.to_string() +
      " panel_right=" +
      panel_right.to_string(),
    )
  }
}
