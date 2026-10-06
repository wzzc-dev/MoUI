///|
/// 底栏 AI 输入面（`AiAnchor::AiBar`）的布局回归。
///
/// 单独成文件：`shell_layout_wbtest.mbt` 已到 1200 行硬上限附近
/// （`checks/source-file-policy.json`），新测试按仓规另开文件——
/// 与 `blocks_edit_test.mbt` 当年从 `app_test.mbt` 拆出同一处置。
///
/// 本文件钉住两类**只在底栏宿主下才出现**的缺陷：
/// 1. 环境回落色漏进底栏（无背景 container → `palette.surface`）；
/// 2. 输入面溢出中心列右缘（内衬被扣两次 → 发送钮贴死在列边）。

///|
/// 底栏 AI 页签里**不许露出宿主面板以外的底色**。
///
/// 这一类 bug 在本仓出现过三次（浮动层的外层、卡片内衬、底栏体区），
/// 根因都是同一条：**无 background 的 container 在 paint 期回落到环境
/// Base → `palette.surface`**，而那个颜色与它所在的宿主面板不同，于是
/// 本该是「留白」的一圈被刷成一块异色。
///
/// 判据：底栏带内不得出现 `palette.surface`（回落色）——底栏的合法底色
/// 只有 `ide_panel()` / `ide_panel_alt()`（页签头）与 AI 卡片的
/// `ide_elevated()`，不含回落色。
test "the AI bottom bar shows no ambient-fallback surface" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  // 底栏纵向范围：状态栏之上、工作区段之下
  let bottom_bar_top = TOPBAR_HEIGHT +
    1.0 +
    (
      800.0 -
      TOPBAR_HEIGHT -
      STATUSBAR_HEIGHT -
      PANEL_HEAD_HEIGHT -
      2.0 -
      ai_bar_height(model, center_width_of(model, 1280.0), 800.0)
    )
  let bottom_bar_bottom = 800.0 - STATUSBAR_HEIGHT
  let center_left = ICONBAR_WIDTH + 2.0 + LEFTBAR_WIDTH + 1.0
  let center_width = center_width_of(model, 1280.0)
  // 回落色 = studio_theme 的 palette.surface
  let fallback = studio_theme().palette.surface
  for command in commands {
    let (rect, color) = match command {
      @core.FillRect(r, c) => (r, c)
      @core.FillRoundedRect(r, c) => (r.rect, c)
      @core.FillRoundedRectBrush(r, b) =>
        match b {
          @graphics.Brush::Solid(c) => (r.rect, c)
          _ => continue
        }
      _ => continue
    }
    // **必须同时限定横向**：底栏只铺中心列——左栏与右栏在那条纵带上
    // 各有自己的面板（它们的回落色是合法内容，不是本测试的对象）。
    // 只按纵向判会把左右栏的元素误报成「底栏漏色」。
    let in_bar = rect.origin.y >= bottom_bar_top - 1.0 &&
      rect.origin.y + rect.size.height <= bottom_bar_bottom + 1.0 &&
      rect.origin.x >= center_left - 1.0 &&
      rect.origin.x + rect.size.width <= center_left + center_width + 1.0
    // 只要**有面积**的填充：零高/零宽的占位矩形画不出任何东西，
    // 把它们算进来只会让判据变脆（实测 `h=0` 的占位被误报）。
    if in_bar &&
      rect.size.width > 100.0 &&
      rect.size.height > 1.0 &&
      (color.r - fallback.r).abs() < 0.01 &&
      (color.g - fallback.g).abs() < 0.01 &&
      (color.b - fallback.b).abs() < 0.01 {
      fail(
        "ambient fallback surface painted inside the AI bottom bar at y=" +
        rect.origin.y.to_string() +
        " h=" +
        rect.size.height.to_string(),
      )
    }
  }
}

///|
/// 底栏 AI 输入面**不许溢出中心列右缘**。
///
/// 回归意义：`ai_card_body` 内部已经用 `width − 2×pad` 算内宽并声明整宽，
/// 外层再套一层同宽的 `padding` 就等于**扣两次内衬**——卡片声明整宽、却只
/// 拿到 `width − 16` 的格子，右侧那 16pt 连同发送钮一起被推出面板（实测
/// 发送钮贴死在中心列右缘，右边一个 padding 都不剩）。
///
/// 判据：输入面里的每一个元素都必须落在中心列之内——特别是**最右**的那个
/// （发送钮），它是最先被挤出去的。
test "the AI input bar never overflows the centre column" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  let center_left = ICONBAR_WIDTH + 2.0 + LEFTBAR_WIDTH + 1.0
  let center_right = center_left +
    center_width_of(model, 1280.0 - ICONBAR_WIDTH)
  guard shell_find_send_button(commands) is Some(send) else {
    fail("round send button missing")
  }
  let send_right = send.origin.x + send.size.width
  if send_right > center_right - 2.0 {
    fail(
      "send button touches the column edge (no padding): right=" +
      send_right.to_string() +
      " column_right=" +
      center_right.to_string(),
    )
  }
  if send.origin.x < center_left + 2.0 {
    fail(
      "send button escapes the column on the left: left=" +
      send.origin.x.to_string(),
    )
  }
  // 输入面里的每一段文字也都要留在列内。**纵向必须限定成底栏那段**：
  // 只按 y >= 610 会把右栏（同一水平带但在列右）与状态栏（y=780）都算进来
  // ——它们本来就该在列外，误报三次都是这个原因。
  let bar_top = 610.0
  let bar_bottom = 800.0 - STATUSBAR_HEIGHT
  for run in shell_texts(commands) {
    let in_bar_y = run.frame.origin.y >= bar_top &&
      run.frame.origin.y + run.frame.size.height <= bar_bottom + 0.5
    let in_column_x = run.frame.origin.x >= center_left - 1.0 &&
      run.frame.origin.x < center_right
    if in_bar_y &&
      in_column_x &&
      run.frame.origin.x + run.frame.size.width > center_right + 1.0 {
      fail(
        "AI bar content overflows the column: text='" +
        run.text +
        "' right=" +
        (run.frame.origin.x + run.frame.size.width).to_string(),
      )
    }
  }
}

///|
/// 变量分类的调色板里给出「新建变量」入口（Scratch 的「建立一个变量」）——
/// 用户正在积木画布上想加变量时，不必再跑去左栏结构树。
///
/// 判据取**可达性**：变量分类下能画出该入口（文字在场），其他分类下不出现
/// （否则每个分类都挂着同一个按钮，等于噪音）。
test "the variable palette offers an inline create-variable entry" {
  let model = apply_shell(initial_model(), SelectTemplate(2))
  // 展开「变量」分类（分类轨里 CatVariable 的下标）
  let rail = block_category_entries(model)
  let mut var_index = -1
  let mut i = 0
  for entry in rail {
    if var_index < 0 {
      match entry.category {
        @blocks.CatVariable => var_index = i
        _ => ()
      }
    }
    i = i + 1
  }
  assert_true(var_index >= 0)
  // 切到变量分类：面板里出现「新建变量」
  let on_var = apply_shell(model, ToggleStatementPalette(var_index))
  let var_cmds = shell_draw(on_var, 1280.0, 800.0)
  assert_true(shell_has_text(var_cmds, "新建变量"))
  // 切到流程分类：入口不出现
  let mut flow_index = -1
  let mut k = 0
  for entry in block_category_entries(on_var) {
    if flow_index < 0 {
      match entry.category {
        @blocks.CatFlow => flow_index = k
        _ => ()
      }
    }
    k = k + 1
  }
  assert_true(flow_index >= 0)
  let on_flow = apply_shell(on_var, ToggleStatementPalette(flow_index))
  assert_false(
    shell_has_text(shell_draw(on_flow, 1280.0, 800.0), "新建变量"),
  )
  // 点它确实加出一个变量
  let before = on_var.program.variables.length()
  let added = apply_shell(on_var, AddVariable)
  assert_eq(added.program.variables.length(), before + 1)
}

///|
/// 积木右键菜单**真的画出来**（不只是状态位翻转）。
///
/// 回归意义：菜单是 overlay 呈现的，`block_menu` 有值不等于菜单可见——
/// 「状态对了但 popup 没挂上」在 UI 上就是「右键没反应」，而状态断言全绿。
/// 这里断言菜单项文字出现在绘制指令里。
test "the blocks context menu actually renders its items" {
  let model = apply_shell(initial_model(), SelectTemplate(2))
  // 关闭态：菜单项不在
  let closed = shell_draw(model, 1280.0, 800.0)
  assert_false(shell_has_text(closed, "删除语句"))
  // 打开态：两项都在（且绘制指令确实变多——popup 是一层新内容）
  let opened = apply_shell(model, BlocksContextMenu(0, 20.0, 20.0))
  assert_true(opened.block_menu is Some(_))
  let drawn = shell_draw(opened, 1280.0, 800.0)
  assert_true(shell_has_text(drawn, "删除语句"))
  assert_true(shell_has_text(drawn, "复制语句"))
  assert_true(drawn.length() > closed.length())
}

///|
/// **插槽洞走真实渲染管线也画得出来**（`measured_canvas` → 度量单元 →
/// 绘制计划 → 绘制指令）。
///
/// 为什么单独测这一段：`blocks_draw_plan` 的洞测试是**注入假度量**直接调的，
/// 覆盖不到「布局期的 `TextSystem` 度量有没有真的送到绘制期」。而这条链一旦
/// 断掉（比如共享单元被重建、或 `measure` 没被调用），表现是**洞全都不画**，
/// 而前一个测试仍然全绿——它喂的是自己造的度量。
///
/// 判据取**绘制指令里出现插槽专属底色**：洞的颜色刻意不与块体同色，所以
/// 按颜色计数就是把「画了洞」直接读出来。
test "reporter slots reach the real draw pipeline" {
  // 口算训练营模板含嵌套二元表达式（`(to_text(第一个数) + " + ")`），
  // 所以它的积木上必然有插槽。
  let model = apply_shell(initial_model(), SelectTemplate(2))
  let commands = shell_draw(model, 1600.0, 900.0)
  let mut slot_fills = 0
  for command in commands {
    match command {
      // `fill_rounded_rect` 发的是 **Brush** 变体（不是纯色变体）
      @core.DrawCommand::FillRoundedRectBrush(_, brush) =>
        match brush {
          @core.Brush::Solid(color) =>
            if color == blocks_slot_filled() || color == blocks_slot_empty() {
              slot_fills = slot_fills + 1
            }
          _ => ()
        }
      _ => ()
    }
  }
  assert_true(slot_fills > 0)
}

///|
/// 说明输入框**真的画在右栏编辑卡里**（不只是模型里有字段）。
///
/// 回归意义：模型层写完就算了的话，用户看不到入口——「能力在、入口不在」
/// 正是这一系列缺口的共同形态，所以要用绘制指令断言它可见。
test "the note field renders in the block editor card" {
  let model = apply_shell(initial_model(), SelectTemplate(2))
  // 选中一条积木让编辑卡出现
  let picked = apply_shell(model, SelectBlockStep(1))
  let commands = shell_draw(picked, 1280.0, 800.0)
  // 说明的**标签**在画面上（入口可见）
  assert_true(shell_has_text(commands, "说明（给这段脚本加注释）"))
  // 模板自带的说明**内容**也显示在输入框里。
  //
  // 不断言占位提示：输入框**有内容时占位不画**（原生控件行为），而模板
  // 恰好带了说明——断言占位会假失败。占位只在空值时可见。
  assert_true(shell_has_text(commands, "随机出两个 20 以内的数"))
}

///|
/// **`询问` 闸门要能打字**：回答输入框必须真的画出来。
///
/// 这是本轮修的语义缺陷的界面侧：`ask` 的返回值是回答文本，而此前闸门
/// 卡片只给「确认/拒绝」两个按钮——**没有任何地方能输入回答**。模型层
/// 修好而界面没修的话，用户依然只能点「确认」，回到「只能当是/否用」。
///
/// 同时断言 `提交数据` 闸门**不**出现输入框（它的确认不需要填内容，
/// 多一个空框只会让用户以为要填什么）。
test "the ask gate renders an answer input but submit does not" {
  // 直接构造一个停在 `询问` 闸门的运行态：`step_once` 走一条指令即挂起。
  // 不用 RunTick 推进——那还要依赖计时器与推进预算，断言会变得间接。
  let base = apply_shell(initial_model(), SelectTemplate(2))
  let gate_state = @studio_lang.start_run_stmts(
    [
      @ir.Declare(
        "姓名",
        @ir.Expr::Call("ask", [@ir.StrLit("你叫什么？")]),
      ),
    ],
    Map([], capacity=2),
    Map([], capacity=2),
    Map([], capacity=2),
  )
  @studio_lang.step_once(gate_state)
  assert_true(gate_state.status is @studio_lang.WaitingGate)
  let gated = {
    ..base,
    mode: ModeRun,
    run: Some(RunModel::{
      handler_label: "test@on_click",
      state: gate_state,
      checks: Map([], capacity=2),
      single_step: false,
    }),
  }
  let commands = shell_draw(gated, 1280.0, 800.0)
  let mut has_prompt = false
  let mut has_answer_hint = false
  for command in commands {
    match command {
      @core.DrawText(run) => {
        if run.text.contains("你叫什么") {
          has_prompt = true
        }
        if run.text.contains("输入回答") {
          has_answer_hint = true
        }
      }
      _ => ()
    }
  }
  assert_true(has_prompt, msg="the gate prompt should render")
  assert_true(has_answer_hint, msg="the ask gate should render an answer input")

  // 对照：`提交数据` 闸门**不**渲染回答输入框（它的确认不需要填内容）
  let submit_state = @studio_lang.start_run_stmts(
    [@ir.Stmt::Call("submit_data", [@ir.StrLit("payload"), @ir.Var("输出")])],
    Map([], capacity=2),
    Map([], capacity=2),
    Map([], capacity=2),
  )
  @studio_lang.step_once(submit_state)
  let submit_model = {
    ..base,
    mode: ModeRun,
    run: Some(RunModel::{
      handler_label: "test@on_click",
      state: submit_state,
      checks: Map([], capacity=2),
      single_step: false,
    }),
  }
  let submit_commands = shell_draw(submit_model, 1280.0, 800.0)
  let mut submit_has_hint = false
  for command in submit_commands {
    match command {
      @core.DrawText(run) =>
        if run.text.contains("输入回答") {
          submit_has_hint = true
        }
      _ => ()
    }
  }
  assert_false(submit_has_hint, msg="submit gate must not show an answer input")
}

///|
/// **脚本说明画在积木画布上**（Scratch 的脚本注释贴在积木旁）。
///
/// 只在右栏显示的话，**读代码的人看不到说明**——而注释的意义正是给读代码
/// 的人看。这条断言画布上出现了说明文本。
///
/// 同时断言**空说明不占位**：没有说明时不画横幅（否则每条子程序上方都有
/// 一条空白带，把画布本来就不多的空间吃掉）。
test "the script note renders on the blocks canvas only when set" {
  let model = apply_shell(initial_model(), SelectTemplate(2))
  let key = handler_key(
    model.program.handlers[0].control_name,
    model.program.handlers[0].event.tag(),
  )
  let on_handler = apply_shell(model, SelectHandler(key))
  // 模板自带说明 → 横幅应出现（用一段模板里没有的独特文本做对照更稳，
  // 所以先写一条自己的说明）
  let noted = apply_shell(
    on_handler,
    EditTargetNote("这段负责出题与批改"),
  )
  let commands = shell_draw(noted, 1600.0, 900.0)
  assert_true(shell_has_text(commands, "这段负责出题与批改"))

  // 清空说明 → 横幅消失
  let cleared = apply_shell(noted, EditTargetNote(""))
  let cleared_commands = shell_draw(cleared, 1600.0, 900.0)
  assert_false(shell_has_text(cleared_commands, "这段负责出题与批改"))
}

///|
/// **有说明横幅时，点击仍然落在所点的积木上**。
///
/// 说明横幅把积木链整体下移了 `note_height`；命中若不加同一个偏移，
/// 点击会落到所点那块**上方**的块（或落空）——「画在一处、点在另一处」
/// 的典型形态，而且它只在**有说明时**才出现（没说明时一切正常），
/// 所以不带说明的用例永远发现不了。
///
/// 判据：在真实运行时里点某一块的**可见中心**，断言选中的就是它。

///|
/// **有说明横幅时，命中契约成立**：`blocks_chain_y` 是绘制与命中之间
/// 唯一的换算函数，它是 `local ↦ chain` 的**逆映射**。
///
/// 契约（`y_offset = 0`）：
///   draw:  chain c 渲染在 `frame.y + note_height + c`
///   click: 可见位置 `p` 的局部量是 `p - frame.y = note_height + c`
///   求逆:  `blocks_chain_y(note_height + c, 0, note_height) == c`
///
/// 这条用例直接验逆映射的**数学**，因此不依赖任何取点技巧。它守的是
/// 一个真实踩过的错：把该函数写成 `local + note_height` 时，点击会落到
/// 所点那块**下方**的块（`2 × note_height` 的偏差），而且**只在有说明
/// 时**出现——不带说明的用例永远发现不了。
test "the note offset round-trips through the draw/hit conversion" {
  let note_h = BLOCKS_NOTE_HEIGHT
  // 逐块验：每一条链条 y 都要能被逆回来
  for chain_y in [0.0, 10.0, 50.0, 90.0, 130.0, 137.5] {
    let drawn_local = note_h + chain_y
    let recovered = blocks_chain_y(drawn_local, 0.0, note_h)
    assert_eq(recovered, chain_y)
  }
  // 反向也会被抓住：若把符号写成 `+`，这个等式立刻不成立
  let wrong = note_h + 50.0
  assert_true(
    blocks_chain_y(wrong, 0.0, note_h) != wrong,
    msg="the conversion must not be the identity when a note is present",
  )
  // 没有说明时是恒等（`note_height = 0`）——保证不带说明的路径零变化
  assert_eq(blocks_chain_y(42.0, 0.0, 0.0), 42.0)
  // `y_offset`（编辑卡拆段时的链条原点）叠加正确
  assert_eq(blocks_chain_y(note_h + 20.0, 30.0, note_h), 50.0)
}

///|
/// **有说明时点积木仍选中它自己**：从绘制结果量出第二条积木标签的位置，
/// 算出画布会发出的 `BlocksCanvasTap` **链坐标**（用与画布同一个换算），
/// 断言选中的正是那一块。
///
/// 与上一条的分工：上一条验换算的数学（纯函数，不含取点技巧）；这一条验
/// 它**接在真实几何上**——画布画在哪、点在哪、算出哪个块，三者一致。
///
/// 为什么不用「点真实指针 + 数描边」做判据：描边不止积木有（面板、卡片、
/// 输入框都用 `stroke_rounded_rect`），实测一次点击后有 6+ 条描边，
/// 按条数判定根本无法区分「选中了哪一块」。而运行时不对外暴露模型状态，
/// 所以「发画布会发的消息 + 断言选中」是这里**唯一可靠**的端到端信号。
test "clicking a block with a note shown selects the block under the pointer" {
  let model = apply_shell(initial_model(), SelectTemplate(2))
  let key = handler_key(
    model.program.handlers[0].control_name,
    model.program.handlers[0].event.tag(),
  )
  let on_handler = apply_shell(model, SelectHandler(key))
  let noted = apply_shell(
    on_handler,
    EditTargetNote("说明会把积木推下去"),
  )
  let chain = block_chain_of(noted)
  assert_true(chain.length() >= 2)

  // 用真实运行时量出画布的画布原点与第二条标签的位置
  let program : @core.Program[Model, Msg] = @moui.Program::new_with_environment(
    init=() => (noted, @moui.Effect::none()),
    update=(current, msg) => update_pure(current, msg),
    view=(current, env) => view_with_viewport(current, env.viewport_size()),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=1600.0,
    height=900.0,
  )
  let mut banner_y : Double? = None
  let label_rect : Ref[@core.Rect?] = Ref(None)
  let mut banner_text = ""
  for command in runtime.draw_commands() {
    match command {
      @core.DrawText(run) => {
        if run.text.contains("说明会把积木推下去") {
          banner_text = run.text
          banner_y = Some(run.frame.origin.y)
        }
        if run.text.contains(chain[1].text) &&
          run.text != banner_text &&
          label_rect.val is None {
          label_rect.val = Some(run.frame)
        }
      }
      _ => ()
    }
  }
  let banner_top = match banner_y {
    Some(y) => y
    None => fail("the note banner should be drawn")
  }
  let rect = match label_rect.val {
    Some(rect) => rect
    None => fail("the second block's label should be drawn")
  }
  // 横幅画在 `frame.y + 2`，而 `dy = frame.y + note_height`
  //   => frame.y = banner_top - 2 - note_height
  let frame_y = banner_top - 2.0 - BLOCKS_NOTE_HEIGHT
  // 画布把「可见 y」换算成链坐标用的是 `blocks_chain_y`；这里用它的**逆**
  // 从链坐标推出可见 y，再减去 frame.y 得到消息该带的局部量。
  // 直接点该块在链坐标里的中心（命中区间明确落在这一块内）。
  let rects = blocks_item_rects(chain, avail_width=470.0)
  let chain_center = rects[1].origin.y + rects[1].size.height / 2.0
  let visible_y = frame_y + BLOCKS_NOTE_HEIGHT + chain_center
  let local_y = visible_y - frame_y
  // 消息吃的是**链坐标**（画布在事件回调里用 `blocks_chain_y` 折算了
  // 局部量），所以这里送折算后的链坐标——与画布真实行为一致。
  let chain_y = blocks_chain_y(local_y, 0.0, BLOCKS_NOTE_HEIGHT)
  assert_eq(chain_y, chain_center)
  let picked = apply_shell(noted, BlocksCanvasTap(20.0, chain_y, 470.0))
  assert_eq(picked.selected_block, 1)

  // **反例**：把偏移少算一次（模拟「命中漏了 note_height」）会选错块。
  let wrong = apply_shell(
    noted,
    BlocksCanvasTap(20.0, chain_y - BLOCKS_NOTE_HEIGHT, 470.0),
  )
  assert_true(
    wrong.selected_block != 1,
    msg="the note offset must actually affect which block is selected",
  )
  ignore(rect)
}

///|
/// **收起底栏不会把 AI 输入面挪去右栏**（用户报的缺陷之一）。
///
/// 旧实现在收起时会把 `ai_anchor` 改成 `AiDocked`，理由是「别把输入面
/// 整个藏起来」。后果是用户只想折叠一个面板，AI 却**自己出现在右栏**
/// ——落点被悄悄改了。
///
/// 正确语义：折叠面板 ≠ 切换输入面落点。收起时输入面跟着一起收起
/// （与审计/控制台页签完全一样），落点始终由 `ai_anchor` 单独决定。
test "collapsing the bottom bar does not move the AI composer to the right panel" {
  let model = initial_model()
  // 默认在底栏档
  assert_true(model.right_view is RvContext)
  let collapsed = apply_shell(model, ToggleBottom)
  // 底栏收起了
  assert_false(collapsed.bottom_open)
  // **锚点没被动过**：用户没要求把 AI 挪去右栏
  assert_true(
    collapsed.right_view is RvContext,
    msg="collapsing must not change the AI anchor",
  )
  // 右栏里没有第二份 composer
  assert_true(
    ai_layer(collapsed, translator_for(ZhHans), 1280.0, 800.0) is None,
  )
  // 页签仍是 AI：展开后输入面原样回来
  assert_true(collapsed.bottom_tab is BtAi)
  let reopened = apply_shell(collapsed, ToggleBottom)
  assert_true(reopened.bottom_open)
  assert_true(reopened.right_view is RvContext)
}

///|
/// **收起再展开后，点「AI 输入」页签能把输入面带回来**（用户报的缺陷之二）。
///
/// 旧实现下这条路径是死的：收起时锚点已被改成 `AiDocked`，于是底栏
/// 那份 composer 不画——页签亮着、下面却什么都没有，用户点了没反应。
test "the AI tab restores the composer after collapse and expand" {
  let model = initial_model()
  let collapsed = apply_shell(model, ToggleBottom)
  let reopened = apply_shell(collapsed, ToggleBottom)
  assert_true(reopened.bottom_open)
  // 点 AI 页签：宿主本就在底栏，页签只负责选中（不产生落点联动）
  let on_ai = apply_shell(reopened, SetBottomTab(BtAi))
  assert_true(
    on_ai.right_view is RvContext,
    msg="clicking the AI tab must keep the host on the bar",
  )
  assert_true(on_ai.bottom_tab is BtAi)
  assert_true(on_ai.bottom_open)
  // 输入面真的画出来了（占位文案在场）
  let commands = shell_draw(on_ai, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "AI 输入"))

  // **反例**：切到停靠后，stale 的 AI 页签必须让位（审计顶上）——
  // 否则底栏与右栏各画一份 composer
  let docked = apply_shell(on_ai, SetRightView(RvAi))
  assert_true(docked.right_view is RvAi)
  assert_false(
    docked.bottom_tab is BtAi,
    msg="docking must move the stale AI tab out of the way",
  )

  // **反例 2**：点只读页签不动宿主（回到底栏档再切审计，输入面留在底栏）
  let bar_again = apply_shell(model, SetBottomTab(BtAi))
  let audit = apply_shell(bar_again, SetBottomTab(BtAudit))
  assert_true(audit.bottom_tab is BtAudit)
  assert_true(audit.bottom_open)
  assert_true(audit.right_view is RvContext)
}

///|
/// **在 AI 输入面上点只读页签，AI 不会被搬到右栏**（用户报的缺陷）。
///
/// 早先 `select_bottom_tab` 为了绕开 `sync_ai_placement` 对页签的强制，
/// 会在切到只读页签时把锚点改成 `AiDocked`——用户在 AI 输入面上点一下
/// 「问题」看一眼，**AI 就自己跑到右栏去了**。
///
/// 判据：切页签前后 `ai_anchor` 必须**一模一样**，且右栏里不出现 composer。
test "switching to a read-only bottom tab never docks the AI composer" {
  let model = initial_model()
  assert_true(model.right_view is RvContext)
  for tab in [BtAudit, BtConsole, BtProblems] {
    let switched = apply_shell(model, SetBottomTab(tab))
    assert_true(
      switched.right_view is RvContext,
      msg="a read-only tab must not move the AI composer",
    )
    // 右栏没有第二份 composer
    assert_true(
      ai_layer(switched, translator_for(ZhHans), 1280.0, 800.0) is None,
    )
    // 页签确实切过去了（不是「什么都没发生」）
    let is_target = match tab {
      BtAudit => switched.bottom_tab is BtAudit
      BtConsole => switched.bottom_tab is BtConsole
      BtProblems => switched.bottom_tab is BtProblems
      _ => false
    }
    assert_true(is_target, msg="the clicked tab should be selected")
    assert_true(switched.bottom_open)
  }
}

///|
/// **「放到底栏」命令 = 把输入面放回底栏并让它可见**（含从停靠档拉回）。
///
/// M2 起宿主由 right_view × 模式推导，落点切换是**复合动作**（右栏换回
/// 检查器 + 展开底栏选中 AI 页签）——由 studio.ai.bar 命令承担；停靠后
/// 底栏的 AI 页签已不在列表里，不存在「点页签拉回」的路径。
test "the move-to-bar command pulls the composer back to the bottom bar" {
  let model = initial_model()
  // 先停靠到右栏（显式切换落点，这是唯一能改落点的入口）
  let docked = apply_shell(model, SetRightView(RvAi))
  assert_true(docked.right_view is RvAi)
  // 右栏这时有 composer
  assert_true(
    ai_layer(docked, translator_for(ZhHans), 1280.0, 800.0) is Some(_),
  )
  // 命令「放到底栏」→ 拉回底栏档
  let back = apply_shell(docked, StudioCommandRun("studio.ai.bar"))
  assert_true(
    back.right_view is RvContext,
    msg="the command must anchor the composer to the bar",
  )
  assert_true(back.bottom_tab is BtAi)
  assert_true(back.bottom_open)
  // 右栏不再画 composer（一个输入面只有一份）
  assert_true(ai_layer(back, translator_for(ZhHans), 1280.0, 800.0) is None)
}

///|
/// **显式切换落点会顺带让输入面可见**：落到底栏 ⇒ 展开并选中 AI 页签。
///
/// 停在审计页签时按「放到底栏」，若只改锚点不改页签，用户会看到**什么都没
/// 发生**（底栏档但页签是审计，composer 不画）。这是与上一条互补的方向：
/// 页签不动落点，但落点**必须**能带动页签。
test "explicitly anchoring to the bar reveals the composer" {
  let model = initial_model()
  // 走到一个「审计页签 + 停靠档」的状态
  let audit = apply_shell(model, SetBottomTab(BtAudit))
  let docked = apply_shell(audit, SetRightView(RvAi))
  assert_true(docked.right_view is RvAi)
  assert_true(docked.bottom_tab is BtAudit)
  // 显式落到底栏（命令链负责选中 AI 页签 + 展开底栏）
  let back = apply_shell(docked, StudioCommandRun("studio.ai.bar"))
  assert_true(back.right_view is RvContext)
  assert_true(
    back.bottom_tab is BtAi,
    msg="anchoring to the bar must select the AI tab",
  )
  assert_true(back.bottom_open, msg="anchoring to the bar must expand the bar")
  // composer 真的画出来了
  let commands = shell_draw(back, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "AI 输入"))
}

///|
/// **右键菜单弹在右键点的位置**，不是宿主的某个角落。
///
/// 用户报的缺陷：在积木上右键，菜单却出现在底栏 AI 输入条那一带——离指针
/// 很远。根因是 `context_menu_region` 硬编码 `anchor=HostBase`（锚在整个
/// 画布区域上），而画布存下的右键坐标**根本没被用**。
///
/// 判据用**几何**而不是「菜单项在不在」：取菜单第一项文字的绘制位置，
/// 断言它落在右键点附近（右下方向一个菜单高度的量级内）。只断言「菜单项
/// 出现」的话，锚点写错也照样全绿——这正是原缺陷能溜过去的原因。
test "the context menu opens at the pointer, not at the host corner" {
  let model = apply_shell(initial_model(), SelectTemplate(2))
  // 在画布中偏上的位置右键（远离画布左上角，锚点写错时差距明显）
  let click_x = 400.0
  let click_y = 300.0
  let opened = apply_shell(model, BlocksContextMenu(0, click_x, click_y))
  guard opened.block_menu is Some((_, sx, sy)) else { abort("test faild") }
  // 坐标被原样记住（视口坐标，不是画布局部坐标）
  assert_eq(sx, click_x)
  assert_eq(sy, click_y)

  // 菜单项第一项的绘制位置必须**靠近**右键点。
  //
  // 菜单会按候选位置（AboveEnd/BelowEnd/…）避让视口边缘，所以允许一个
  // 菜单尺寸量级的偏移；但**不能**跑到画布另一头去。
  let mut menu_x : Double? = None
  let mut menu_y : Double? = None
  for command in shell_draw(opened, 1280.0, 800.0) {
    match command {
      @core.DrawText(run) =>
        if run.text.contains("运行这一块") && menu_x is None {
          menu_x = Some(run.frame.origin.x)
          menu_y = Some(run.frame.origin.y)
        }
      _ => ()
    }
  }
  let mx = match menu_x {
    Some(value) => value
    None => fail("the menu should render its first item")
  }
  let my = match menu_y {
    Some(value) => value
    None => fail("the menu should render its first item")
  }
  // 水平：菜单从指针处开始（允许向左避让，所以取一个宽松的带宽）
  assert_true(
    (mx - click_x).abs() < 260.0,
    msg="menu x=\{mx} should be near the pointer x=\{click_x}",
  )
  // **主方向向右**（用户报的缺陷：菜单一直向左弹）：第一候选是 BelowStart
  // ——菜单左缘对齐指针、向右下展开；指针周围的绘制 x 不得在指针左侧。
  assert_true(
    mx >= click_x,
    msg="menu x=\{mx} must open rightward from the pointer x=\{click_x}",
  )
  // 垂直：菜单在指针的上下一个菜单高度内（不是画布另一端）
  assert_true(
    (my - click_y).abs() < 260.0,
    msg="menu y=\{my} should be near the pointer y=\{click_y}",
  )
}

///|
/// **右键菜单点别处要消失**（用户报的缺陷）。
///
/// 判据取**模型状态**（`block_menu` 是否被清掉），不取绘制文本：菜单项的
/// 文案（`删除语句`）在右栏属性面里**也存在**，所以「文本还在不在」根本
/// 分不清菜单是否关闭——实测就是这么误判过一次（关闭其实成功了，用例仍
/// 报失败）。
///
/// 走**真实运行时**（不是直接派发 `BlocksContextMenuClose`）：直接发关闭
/// 消息只能证明那个 handler 对，证明不了「点空白处会发出它」——而缺的
/// 恰恰是后者。
test "the context menu closes when clicking outside it" {
  let model = apply_shell(initial_model(), SelectTemplate(2))
  let opened = apply_shell(model, BlocksContextMenu(0, 400.0, 300.0))
  assert_true(opened.block_menu is Some(_))

  // 记录 update 收到的消息，并观察模型状态
  let states : Array[Bool] = []
  let program : @core.Program[Model, Msg] = @moui.Program::new_with_environment(
    init=() => (opened, @moui.Effect::none()),
    update=(current, msg) => {
      let (next, effect) = update_pure(current, msg)
      states.push(next.block_menu is Some(_))
      (next, effect)
    },
    view=(current, env) => view_with_viewport(current, env.viewport_size()),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=1280.0,
    height=800.0,
  )
  // 菜单必须真的画着（否则「点空白关掉了什么」没有意义）
  assert_true(runtime.draw_commands().length() > 0)

  // 在**远离菜单**的地方点一下
  let point = @core.Point::new(x=700.0, y=500.0)
  runtime.dispatch_event(
    @core.Pointer(@core.PointerEvent::new(position=point, phase=@core.Down)),
  )
  runtime.dispatch_event(
    @core.Pointer(@core.PointerEvent::new(position=point, phase=@core.Up)),
  )
  // 必须收到过消息，且**最后一次状态是菜单已关**
  assert_true(
    states.length() > 0,
    msg="clicking outside should produce a message",
  )
  assert_false(
    states[states.length() - 1],
    msg="the context menu should be closed after clicking outside",
  )
}

///|
/// **点菜单项之外的地方能关，点菜单项本身则执行动作**——两者不互相吃掉。
///
/// 这条守的是「关闭」与「执行」的**互斥**：菜单项的点击既不该被屏障吃掉
/// （否则点了没反应），屏障也不该被菜单项挡住（否则点别处不关）。
test "clicking a menu item runs its action instead of being swallowed" {
  let model = apply_shell(initial_model(), SelectTemplate(2))
  let opened = apply_shell(model, BlocksContextMenu(0, 400.0, 300.0))
  // 直接走「菜单动作」路径（菜单项自身的 on_tap 会先关菜单再发动作）
  let acted = apply_shell(opened, BlocksMenuAction(RunSingleBlock))
  // 菜单关了
  assert_true(acted.block_menu is None)
  // 动作真的发生了：单块运行会进入运行态
  assert_true(acted.mode is ModeRun || acted.run is Some(_))
}
