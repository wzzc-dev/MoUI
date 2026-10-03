///|
/// 本轮 UI 批次的回归断言：AI 居中锚 / 舞台产品主题 / 提示换行。
/// 复用 shell_layout_wbtest 的白盒助手（同包共享）。

///|
test "docked AI card stays inside the right panel" {
  // 停靠档：输入卡是右栏顶部的内联卡，必须**完整落在右栏**内——
  // 不能越到中心列或溢出窗口右缘。历史：浮动锚点按中心列居中，
  // 卡片宽度是设计值；改成右栏内联后，宽度由右栏决定，判据也随之改为
  // 「落在右栏区间内」。
  let model = apply_shell(initial_model(), SetAiAnchor(AiDocked))
  let width = 1280.0
  let commands = shell_draw(model, width, 800.0)
  let chrome = shell_chrome_widths(model, width - ICONBAR_WIDTH)
  // 右栏：窗口右缘往左 chrome.right，左缘再往左一条发丝线
  let right_panel_right = width
  let right_panel_left = right_panel_right - chrome.right
  guard shell_find_text(commands, "描述你想要的应用") is Some(run) else {
    fail("docked AI composer missing")
  }
  if run.frame.origin.x < right_panel_left - 1.0 ||
    run.frame.origin.x + run.frame.size.width > right_panel_right + 1.0 {
    fail(
      "docked AI card escapes the right panel: x=" +
      run.frame.origin.x.to_string() +
      " panel=[" +
      right_panel_left.to_string() +
      "," +
      right_panel_right.to_string() +
      "]",
    )
  }
}

///|
test "design stage widgets render with the product (light) theme" {
  // 舞台控件是「导出应用的真实预览」：必须用产品主题（浅色）渲染。
  // 旧缺陷：控件吃 IDE 暗色主题——浅色拟真舞台上出现暗色按钮/亮色文字，
  // 设计所见 ≠ 运行所见。判据：舞台区里出现**深色**文字（产品主题的
  // foreground），暗色 IDE 文字（0.875）与按钮 on_primary（白）都不满足。
  let model = initial_model()
  // 给空文本标签填字——它是纯 @views.text，颜色 = 主题 foreground。
  model.program.controls[0] = { ..model.program.controls[0], text: "你好", }
  let width = 1280.0
  let commands = shell_draw(model, width, 800.0)
  let column_left = ICONBAR_WIDTH + 1.0 + LEFTBAR_WIDTH + 1.0
  let right_edge = column_left + shell_chrome_widths(model, width - ICONBAR_WIDTH).center
  let stage_top = TOPBAR_HEIGHT + ICONBAR_WIDTH
  let mut dark_texts = 0
  for run in shell_texts(commands) {
    let in_stage = run.frame.origin.x >= column_left &&
      run.frame.origin.x <= right_edge &&
      run.frame.origin.y >= stage_top
    if in_stage && run.text.contains("你好") {
      if run.color.r < 0.5 && run.color.g < 0.5 {
        dark_texts = dark_texts + 1
      } else {
        fail(
          "stage label text is not product-theme dark: r=" +
          run.color.r.to_string(),
        )
      }
    }
  }
  if dark_texts == 0 {
    fail("stage label text not found — probe control missing from the stage")
  }
}

///|
test "wrap_text_lines breaks latin text at word boundaries" {
  // 60pt ≈ 7 个 ASCII 字符（7.9/字）：每个词都必须完整，行宽都不得超出。
  let lines = wrap_text_lines("alpha beta gamma delta", 60.0)
  assert_true(lines.length() >= 3)
  for line in lines {
    assert_true(text_estimate_width(line) <= 60.0 + 0.001)
  }
  // 词不被切断
  assert_true(lines[0].contains("alpha"))
}

///|
test "wrap_text_lines breaks cjk text per character" {
  // 5 个全角字 = 65pt；40pt 一行放 3 个字
  let lines = wrap_text_lines("班级平均分", 40.0)
  assert_true(lines.length() == 2)
  assert_eq(lines[0], "班级平")
  assert_eq(lines[1], "均分")
}

///|
test "wrap_text_lines keeps a short text on one line" {
  assert_eq(wrap_text_lines("短句", 400.0).length(), 1)
  assert_eq(wrap_text_lines("short", 400.0).length(), 1)
}

///|
test "chip widths grow with their labels" {
  // 「写死宽度」缺陷族的守门断言：内容宽的芯片必须随文案变宽，
  // 且中英文都能装下自己的标签。
  assert_true(
    chip_label_width("确认") < chip_label_width("确认全部副作用"),
  )
  assert_true(
    topbar_chip_bound("Run", 0.0) < topbar_chip_bound("编译 MoonBit", 0.0),
  )
}

///|
/// 满幅设计画布（Figma 式）的两条契约：
/// ① 白色拟真窗口在窗格里**垂直居中**——信箱式留白不再偏一侧死黑；
/// ② 点阵晶格铺满窗格——舞台上方也要有点（旧版点阵只在舞台内部）。
test "design stage fills the pane with a centered stage and full lattice" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  // 舞台白底 = studio_stage_background 的实心圆角矩形；取最大的一块。
  let stage_bg = studio_stage_background()
  let mut stage : @core.Rect? = None
  for command in commands {
    match command {
      // 画布填充走 Brush 变体（paint_context 的 fill_rounded_rect）
      @core.FillRoundedRectBrush(rounded, @core.Brush::Solid(color)) =>
        if (color.r - stage_bg.r).abs() < 0.001 &&
          (color.g - stage_bg.g).abs() < 0.001 &&
          (color.b - stage_bg.b).abs() < 0.001 {
          match stage {
            None => stage = Some(rounded.rect)
            Some(existing) =>
              if rounded.rect.size.width > existing.size.width {
                stage = Some(rounded.rect)
              }
          }
        }
      _ => ()
    }
  }
  guard stage is Some(stage_rect) else { fail("design stage frame not found") }
  // 活动窗格的舞台区 = 编辑器底色（ide_editor_background）的大矩形
  // （中心列内、比舞台白框大）。舞台必须在该区内**垂直居中**——
  // 旧版信箱留白偏一侧的观感就是这条对称性被破坏。
  let editor_bg = ide_editor_background()
  let mut pane_rect : @core.Rect? = None
  for command in commands {
    match command {
      @core.FillRoundedRectBrush(rounded, @core.Brush::Solid(color)) =>
        if (color.r - editor_bg.r).abs() < 0.001 &&
          (color.g - editor_bg.g).abs() < 0.001 &&
          rounded.rect.size.width > 200.0 &&
          rounded.rect.size.width < 500.0 &&
          rounded.rect.origin.x > 250.0 &&
          rounded.rect.origin.x < 700.0 {
          pane_rect = Some(rounded.rect)
        }
      _ => ()
    }
  }
  guard pane_rect is Some(pane) else {
    fail("live pane editor background not found")
  }
  let top_gap = stage_rect.origin.y - pane.origin.y
  let bottom_gap = pane.origin.y +
    pane.size.height -
    (stage_rect.origin.y + stage_rect.size.height)
  if (top_gap - bottom_gap).abs() > 4.0 {
    fail(
      "stage is not vertically centred in the pane: top_gap=" +
      top_gap.to_string() +
      " bottom_gap=" +
      bottom_gap.to_string(),
    )
  }
  // 晶格点必须出现在舞台**上方**（旧版点阵只存在于舞台内部）
  let outline = studio_stage_outline()
  let mut dots_above = 0
  for command in commands {
    match command {
      @core.FillRoundedRectBrush(rounded, @core.Brush::Solid(color)) =>
        if (color.r - outline.r).abs() < 0.001 &&
          (color.g - outline.g).abs() < 0.001 &&
          (color.b - outline.b).abs() < 0.001 &&
          rounded.rect.size.width <= 3.0 &&
          rounded.rect.origin.y < stage_rect.origin.y - 4.0 &&
          rounded.rect.origin.y > pane.origin.y {
          dots_above = dots_above + 1
        }
      _ => ()
    }
  }
  if dots_above == 0 {
    fail("no lattice dots above the stage — canvas is not full-pane")
  }
}

///|
/// AI 卡常驻预算上限：瘦身后空闲卡（头 + 芯片行 + 单行输入）不得再回到
/// 旧版 ~190pt 的三层 chrome。预算涨回去，避让带就会重新吃掉工作区。
test "idle ai card stays compact" {
  let model = initial_model()
  let height = ai_card_height(model, 680.0)
  if height > 140.0 {
    fail(
      "idle AI card grew too tall: " +
      height.to_string() +
      " (single-row composer budget is ~102)",
    )
  }
}

///|
/// 画布上不允许常驻用法提示（旧版两条截断提示行是噪音，已删）。
test "blocks and design canvases have no permanent hint rows" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  assert_false(shell_has_text(commands, "拖动积木"))
  assert_false(shell_has_text(commands, "预留避让通道"))
}
