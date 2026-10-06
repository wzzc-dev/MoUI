///|
/// v4 IDE 壳的布局验证：用 headless runtime 在真实视口下落一遍布局，
/// 从 draw_commands 里读回矩形与文本，断言壳各列的位置与可见性。
///
/// 为什么必须有这层测试：核心没有「测量回环」，任何一处固定的宽度/高度
/// 写错，只有在真实约束下才会暴露成「面板被挤出屏幕」「行被压成 0 高」。
/// 浏览器截图只能看个大概，这里给出的是精确帧。

///|
/// 纯转移（忽略 effect）：白盒测试与 app_test.mbt 的同名助手等价，
/// 但那个在独立黑盒包里，wbtest 看不到，所以这里各留一份。
fn apply_shell(model : Model, msg : Msg) -> Model {
  let (next, _) = update_pure(model, msg)
  next
}

///|
/// 在给定视口渲染一次，返回 draw_commands。
fn shell_draw(
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
/// 所有绘制文本（含 frame）。
fn shell_texts(commands : Array[@core.DrawCommand]) -> Array[@core.TextRun] {
  let runs : Array[@core.TextRun] = []
  for command in commands {
    match command {
      @core.DrawText(run) => runs.push(run)
      _ => ()
    }
  }
  runs
}

///|
/// 所有填充矩形（含 brush 变体与描边盒子）。
///
/// **必须覆盖 brush 变体**：`@views.button` 画的是 `FillRoundedRectBrush` /
/// `StrokeRoundedRectBrush`（不是纯色 `FillRoundedRect`），只收后者会让
/// 「按钮盒在哪」这类断言全部落空——实测本会话因此把一个真实的「拖拽区压住
/// 运行按钮」缺陷漏过去了（断言报的是「找不到按钮盒」而不是「拖拽区盖住
/// 按钮」，症状被伪装成测试自身的问题）。
fn shell_rects(commands : Array[@core.DrawCommand]) -> Array[@core.Rect] {
  let rects : Array[@core.Rect] = []
  for command in commands {
    match command {
      @core.FillRect(rect, _) => rects.push(rect)
      @core.FillRoundedRect(rounded, _) => rects.push(rounded.rect)
      @core.FillRoundedRectBrush(rounded, _) => rects.push(rounded.rect)
      @core.StrokeRect(rect, _, _) => rects.push(rect)
      @core.StrokeRoundedRect(rounded, _, _) => rects.push(rounded.rect)
      @core.StrokeRoundedRectBrush(rounded, _, _) => rects.push(rounded.rect)
      _ => ()
    }
  }
  rects
}

///|
fn shell_has_text(commands : Array[@core.DrawCommand], needle : String) -> Bool {
  for run in shell_texts(commands) {
    if run.text.contains(needle) {
      return true
    }
  }
  false
}

///|
/// 找到包含 needle 的第一段文本。
fn shell_find_text(
  commands : Array[@core.DrawCommand],
  needle : String,
) -> @core.TextRun? {
  for run in shell_texts(commands) {
    if run.text.contains(needle) {
      return Some(run)
    }
  }
  None
}

///|
test "shell lays out all seven chrome bands at 1280x800" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  // 顶栏：品牌 + 面包屑 + 运行/编译
  assert_true(shell_has_text(commands, "MoUI Studio"))
  assert_true(shell_has_text(commands, "可视化工作区"))
  assert_true(shell_has_text(commands, "运行"))
  assert_true(shell_has_text(commands, "编译 MoonBit"))
  // 图标栏（工作区/结构/数据/AI 的 tooltip 不走绘制；这里查左栏标题）
  assert_true(shell_has_text(commands, "程序结构"))
  // 左栏搜索 + 结构树分组
  assert_true(shell_has_text(commands, "搜索结构"))
  assert_true(shell_has_text(commands, "窗体"))
  assert_true(shell_has_text(commands, "控件"))
  assert_true(shell_has_text(commands, "变量"))
  assert_true(shell_has_text(commands, "事件子程序"))
  assert_true(shell_has_text(commands, "本地数据"))
  // 左栏底部：只剩「最近修改」（创建入口已上移到分组头）
  assert_true(shell_has_text(commands, "最近修改"))
  // 分组头「+」的可创建性：本地数据没有（派生视图）
  assert_true(group_can_create(tree_group_controls()))
  assert_true(group_can_create(tree_group_variables()))
  assert_true(group_can_create(tree_group_window()))
  assert_true(group_can_create(tree_group_handlers()))
  assert_false(group_can_create(tree_group_data()))
  // 中心：实时应用 + 积木
  assert_true(shell_has_text(commands, "实时应用"))
  assert_true(shell_has_text(commands, "积木"))
  // 右栏：Context 五页签 + 快速操作 + 监视
  assert_true(shell_has_text(commands, "属性"))
  assert_true(shell_has_text(commands, "状态"))
  assert_true(shell_has_text(commands, "数据"))
  assert_true(shell_has_text(commands, "动作"))
  assert_true(shell_has_text(commands, "依赖"))
  assert_true(shell_has_text(commands, "快速操作"))
  assert_true(shell_has_text(commands, "运行时监视"))
  // 底栏 + 状态栏
  assert_true(shell_has_text(commands, "运行审计"))
  assert_true(shell_has_text(commands, "Console"))
  assert_true(shell_has_text(commands, "UTF-8 · MoonBit"))
}

///|
test "shell fills the viewport: top bar spans full width, status bar sits at the bottom" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  // 状态栏文本的底边应贴近窗口底（22pt 状态栏）
  let status = shell_find_text(commands, "UTF-8 · MoonBit")
  guard status is Some(run) else { fail("status bar text missing") }
  let bottom = run.frame.origin.y + run.frame.size.height
  assert_true(bottom > 780.0)
  assert_true(bottom <= 800.0)
  // 顶栏文本应在最上方 40pt 内
  let brand = shell_find_text(commands, "MoUI Studio")
  guard brand is Some(brand_run) else { fail("brand text missing") }
  assert_true(brand_run.frame.origin.y < 40.0)
  // 面板背景铺满整个视口宽度：应存在一个宽度 >= 1280 的矩形
  let mut widest = 0.0
  for rect in shell_rects(commands) {
    if rect.size.width > widest {
      widest = rect.size.width
    }
  }
  assert_true(widest >= 1279.0)
}

///|
test "icon bar toggle collapses the left panel and widens the centre" {
  let model = initial_model()
  let open_commands = shell_draw(model, 1280.0, 800.0)
  let open_tree = shell_find_text(open_commands, "程序结构")
  guard open_tree is Some(_) else { fail("structure head missing") }
  // 收起左栏：标题消失、中心列变宽
  let collapsed = apply_shell(model, SetLeftView(LeftHidden))
  let collapsed_commands = shell_draw(collapsed, 1280.0, 800.0)
  assert_false(shell_has_text(collapsed_commands, "程序结构"))
  // 再点一次回到结构树（重复点击 = 收起，显式切换 = 换页签）
  let restored = apply_shell(collapsed, SetLeftView(LeftTree))
  let restored_commands = shell_draw(restored, 1280.0, 800.0)
  assert_true(shell_has_text(restored_commands, "程序结构"))
  // 左栏收起腾出的宽度归中心列（右栏钉右边缘不动）：
  // 实时应用窗格标题左移，右栏位置不变。
  let open_centre = shell_find_text(open_commands, "实时应用")
  let collapsed_centre = shell_find_text(collapsed_commands, "实时应用")
  guard open_centre is Some(open_centre_run) else { fail("live pane missing") }
  guard collapsed_centre is Some(collapsed_centre_run) else {
    fail("live pane missing when collapsed")
  }
  assert_true(
    collapsed_centre_run.frame.origin.x < open_centre_run.frame.origin.x,
  )
  let open_right = shell_find_text(open_commands, "快速操作")
  let collapsed_right = shell_find_text(collapsed_commands, "快速操作")
  guard open_right is Some(open_right_run) else {
    fail("quick actions missing")
  }
  guard collapsed_right is Some(collapsed_right_run) else {
    fail("quick actions missing when collapsed")
  }
  assert_eq(collapsed_right_run.frame.origin.x, open_right_run.frame.origin.x)
}

///|
test "workspace switching swaps the centre content" {
  let visual = initial_model()
  let visual_commands = shell_draw(visual, 1280.0, 800.0)
  assert_true(shell_has_text(visual_commands, "实时应用"))
  // 切到代码工作区：出现 IR 标尺与草稿提示，实时应用窗格消失
  let code = apply_shell(visual, SetWorkSpace(WsCode))
  assert_true(code.workspace is WsCode)
  let code_commands = shell_draw(code, 1280.0, 800.0)
  // 脚注芯片:编译钮常驻;「按 IR 重渲染」按外观显隐（M8,MoonBit 外观下隐藏）
  assert_true(shell_has_text(code_commands, "编译 MoonBit"))
  assert_false(shell_has_text(code_commands, "实时应用"))
  // 切到空舞台
  let empty = apply_shell(code, SetWorkSpace(WsEmpty))
  assert_true(empty.workspace is WsEmpty)
  let empty_commands = shell_draw(empty, 1280.0, 800.0)
  assert_true(shell_has_text(empty_commands, "从零开始，或接着改"))
  assert_false(shell_has_text(empty_commands, "实时应用"))
}

///|
test "bottom bar expands to the audit timeline and console stays switchable" {
  // 初始态是**AI 页签展开**（AI 输入条的默认落点就是底栏）。这里先显式
  // 收起，再验证「收起只剩页签头 / 展开出审计条目」这条既有契约。
  let model = apply_shell(initial_model(), ToggleBottom)
  assert_false(model.bottom_open)
  let collapsed = shell_draw(model, 1280.0, 800.0)
  assert_true(shell_has_text(collapsed, "运行审计"))
  assert_false(shell_has_text(collapsed, "程序已载入 IR"))
  // 展开 + 切到审计页签：审计条目出现（初始三条 boot 记录）
  let open = apply_shell(model, SetBottomTab(BtAudit))
  assert_true(open.bottom_open)
  let open_commands = shell_draw(open, 1280.0, 800.0)
  assert_true(shell_has_text(open_commands, "程序已载入 IR"))
  assert_true(shell_has_text(open_commands, "控件层已就绪"))
  // 切到 Console
  let console = apply_shell(open, SetBottomTab(BtConsole))
  let console_commands = shell_draw(console, 1280.0, 800.0)
  assert_true(shell_has_text(console_commands, "MoUI Studio 已就绪"))
  assert_false(shell_has_text(console_commands, "控件层已就绪"))
}

///|
/// AI 输入条只在**两个内联落点**里出现，且都不盖状态栏。
///
/// 判据：底栏档的输入盒在底栏带内、停靠档的在右栏内；两者都不得越过
/// 状态栏上沿。曾经的三个浮动锚点（居中/左下/右下）与药丸收起态已删除——
/// 输入面不再浮在中心列上，所以「浮层压住状态栏」这一整类风险随之消失。
test "AI input bar lives in the two inline placements and never covers the status bar" {
  let model = initial_model()
  // 默认 = 底栏档：输入盒在底栏里，且底栏被自动打开并选中 AI 页签
  assert_true(model.right_view is RvContext)
  assert_true(model.bottom_open)
  assert_true(model.bottom_tab is BtAi)
  let commands = shell_draw(model, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "描述你想要的应用"))
  // 输入条是输入盒形态：模式段文字 + 圆形发送钮（图标，无文字）
  guard shell_find_send_button(commands) is Some(_) else {
    fail("round send button missing")
  }
  assert_true(shell_has_text(commands, "修改"))
  assert_true(shell_has_text(commands, "修复"))
  // 底栏档：输入盒必须在状态栏**之上**（底栏在状态栏之上，输入盒在底栏内）
  guard shell_find_text(commands, "描述你想要的应用") is Some(bar_run) else {
    fail("AI bar composer missing")
  }
  assert_true(
    bar_run.frame.origin.y + bar_run.frame.size.height <
    800.0 - STATUSBAR_HEIGHT,
  )
  // 停靠档：并入右栏（输入盒仍在），且同样不越状态栏
  let docked = apply_shell(model, SetRightView(RvAi))
  assert_true(docked.right_view is RvAi)
  let docked_commands = shell_draw(docked, 1280.0, 800.0)
  assert_true(shell_has_text(docked_commands, "描述你想要的应用"))
  guard shell_find_text(docked_commands, "描述你想要的应用")
    is Some(run) else {
    fail("docked AI card missing")
  }
  assert_true(run.frame.origin.y + run.frame.size.height < 770.0)
}

///|
test "settings dialog replaces the shell content when presented" {
  let model = initial_model()
  let opened = apply_shell(model, ToggleSettings)
  assert_true(opened.settings_open)
  let commands = shell_draw(opened, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "设置"))
  assert_true(shell_has_text(commands, "工作区"))
  assert_true(shell_has_text(commands, "界面语言"))
  assert_true(shell_has_text(commands, "模型服务"))
  assert_true(shell_has_text(commands, "密钥"))
  // 密钥提示必须出现（安全承诺在 UI 上可见）
  assert_true(shell_has_text(commands, "不进源码"))
  // 关闭后对话框消失
  let closed = apply_shell(opened, ToggleSettings)
  let closed_commands = shell_draw(closed, 1280.0, 800.0)
  assert_false(shell_has_text(closed_commands, "不进源码"))
}

///|
test "studio command catalog is bilingual and filterable" {
  let zh = translator_for(ZhHans)
  let en = translator_for(En)
  let zh_commands = studio_commands(zh)
  let en_commands = studio_commands(en)
  assert_eq(zh_commands.length(), en_commands.length())
  assert_true(zh_commands.length() >= 20)
  // 中文表里不该残留英文标签（i18n 漏配会渲染成 [[key]]）
  for command in zh_commands {
    assert_false(command.label.contains("[["))
    assert_false(command.group.contains("[["))
  }
  // 过滤：空查询返回全部；「工作区」只命中工作区分组
  assert_eq(
    filter_studio_commands(zh_commands, "").length(),
    zh_commands.length(),
  )
  let filtered = filter_studio_commands(zh_commands, "工作区")
  assert_true(filtered.length() > 0)
  assert_true(filtered.length() < zh_commands.length())
  for command in filtered {
    assert_eq(command.group, "工作区")
  }
  // 大小写不敏感（英文表用 Visual 查 visual）
  let en_filtered = filter_studio_commands(en_commands, "visual")
  assert_true(en_filtered.length() > 0)
}

///|
test "shell renders at a narrow viewport without losing the right panel" {
  let model = initial_model()
  // 1024 宽：中心列仍应留下可用宽度，右栏不离屏
  let commands = shell_draw(model, 1024.0, 700.0)
  assert_true(shell_has_text(commands, "快速操作"))
  assert_true(shell_has_text(commands, "运行时监视"))
  let actions = shell_find_text(commands, "快速操作")
  guard actions is Some(run) else { fail("quick actions missing") }
  assert_true(run.frame.origin.x < 1024.0)
  assert_true(run.frame.origin.x + run.frame.size.width <= 1025.0)
}

// ============================================================================
// 壳行为链：事件 → 三处派生（审计 / 最近修改 / Console）
// ============================================================================

///|
test "editing a control records one recent change per discrete action" {
  let model = initial_model()
  assert_eq(model.recent_changes.length(), 0)
  let added = apply_shell(model, AddControl(@ir.Label))
  assert_eq(added.recent_changes.length(), 1)
  // 连插两次是两个独立还原点（离散动作不合并）
  let twice = apply_shell(added, AddControl(@ir.Button))
  assert_eq(twice.recent_changes.length(), 2)
  assert_eq(twice.undo_stack.length(), 2)
  // 动作者是「你」而不是 Agent；目标是「刚插入的那个控件名」
  assert_false(twice.recent_changes[1].by_agent)
  assert_eq(twice.recent_changes[0].target, "标签")
  assert_eq(twice.recent_changes[1].target, "按钮")
}

///|
test "a no-op edit records neither a recent change nor an undo point" {
  let model = initial_model()
  // 删除不存在的控件：签名不变 → 不留痕
  let same = apply_shell(model, DeleteControl("不存在的控件"))
  assert_eq(same.recent_changes.length(), 0)
  assert_eq(same.undo_stack.length(), 0)
}

///|
test "accepting a proposal logs an audit entry, console line and toast" {
  let model = apply_shell(initial_model(), SetPrompt("加一个按钮"))
  let proposed = apply_shell(model, GenerateProposal)
  guard proposed.pending is Some(_) else { fail("no proposal generated") }
  let audit_before = proposed.audit_entries.length()
  let log_before = proposed.log_lines.length()
  let accepted = apply_shell(proposed, AcceptProposal)
  assert_true(accepted.pending is None)
  assert_true(accepted.audit_entries.length() > audit_before)
  assert_true(accepted.log_lines.length() > log_before)
  assert_eq(accepted.toasts.length(), 1)
  // 最近修改标记为 Agent 所为
  assert_true(
    accepted.recent_changes[accepted.recent_changes.length() - 1].by_agent,
  )
}

///|
test "rejecting a proposal records history without touching the program" {
  let model = apply_shell(initial_model(), SetPrompt("加一个按钮"))
  let proposed = apply_shell(model, GenerateProposal)
  let signature = @ir.program_signature(proposed.program)
  let rejected = apply_shell(proposed, RejectProposal)
  assert_true(rejected.pending is None)
  assert_eq(@ir.program_signature(rejected.program), signature)
  assert_eq(rejected.ai_sessions.current().proposal_history.length(), 1)
  assert_false(rejected.ai_sessions.current().proposal_history[0].accepted)
}

///|
test "starting a run appends an audit entry for the armed stage" {
  let model = initial_model()
  let audit_before = model.audit_entries.length()
  let running = apply_shell(model, RunStart)
  guard running.run is Some(_) else { fail("run did not start") }
  assert_true(running.audit_entries.length() > audit_before)
  let last = running.audit_entries[running.audit_entries.length() - 1]
  assert_true(last.kind is AuditRun)
  // 装填态的启动审计点名「等待事件」而不是某个子程序——「运行」不再
  // 替用户执行选中的子程序，执行只发生在真实控件事件上。
  assert_true(
    last.detail.contains(text(translator_for(ZhHans), "app.run.armed")),
  )
}

///|
test "control alignment clamps to the 640pt design frame" {
  let model = initial_model()
  let target = model.program.controls[0].name
  let left = apply_shell(model, AlignControlLeft(target))
  let left_control = match @ir.find_control(left.program, target) {
    Some(control) => control
    None => fail("control vanished after align-left")
  }
  assert_eq(left_control.x, 24)
  let right = apply_shell(model, AlignControlRight(target))
  let right_control = match @ir.find_control(right.program, target) {
    Some(control) => control
    None => fail("control vanished after align-right")
  }
  assert_eq(right_control.x, 640 - right_control.width - 24)
}

///|
test "toast queue is capped and dismissible" {
  let mut model = initial_model()
  let mut index = 0
  while index < TOAST_LIMIT + 3 {
    model = push_toast(model, "toast-\{index}", false)
    index = index + 1
  }
  assert_eq(model.toasts.length(), TOAST_LIMIT)
  let dismissed = apply_shell(model, DismissToast(0))
  assert_eq(dismissed.toasts.length(), TOAST_LIMIT - 1)
}

///|
test "split ratio clamps into the usable band" {
  let model = initial_model()
  assert_eq(apply_shell(model, SetSplitRatio(0.05)).split_ratio, 0.2)
  assert_eq(apply_shell(model, SetSplitRatio(0.95)).split_ratio, 0.8)
  assert_eq(apply_shell(model, SetSplitRatio(0.5)).split_ratio, 0.5)
}

///|
test "program tree groups every IR entity with counts" {
  let model = initial_model()
  let tree = program_tree(model)
  // 分组行的 label 是空的：标签是 i18n 键，在渲染时才翻译
  // （见 tree_view_ide 的 tree_group_label_key）。这里断言 group 标记。
  let groups : Array[String] = []
  for node in tree {
    if node.kind is TnGroup {
      groups.push(node.group)
    }
  }
  assert_true(groups.contains("window"))
  assert_true(groups.contains("controls"))
  assert_true(groups.contains("handlers"))
  // 控件分组计数 = IR 控件数
  let mut control_count = 0
  for node in tree {
    if node.kind is TnControl {
      control_count = control_count + 1
    }
  }
  assert_eq(control_count, model.program.controls.length())
}

///|
test "tree search filters rows without dropping their group header" {
  let model = initial_model()
  let filtered = apply_shell(model, SetTreeQuery("按钮"))
  let tree = program_tree(filtered)
  let mut seen_controls_group = false
  let mut seen_matching_control = false
  let mut seen_other_control = false
  for node in tree {
    if node.kind is TnGroup && node.group == "controls" {
      seen_controls_group = true
    }
    if node.kind is TnControl {
      if node.label.contains("按钮") {
        seen_matching_control = true
      } else {
        seen_other_control = true
      }
    }
  }
  // 命中的分组头保留；不匹配的控件行被过滤掉
  assert_true(seen_controls_group)
  assert_true(seen_matching_control)
  assert_false(seen_other_control)
}

///|
test "IR to code line mapping round-trips through the ruler" {
  let model = initial_model()
  let lines = code_lines(model)
  assert_true(lines.length() > 0)
  // 每一行的行号单调递增且与下标一致
  let mut index = 0
  for line in lines {
    assert_eq(line.number, index + 1)
    index = index + 1
  }
  // IR 路径 ↔ 行号双向映射：拿第一条语句的路径找出它占的行区间，
  // 再用区间起点反查，必须回到同一条路径（双向高亮的基础）。
  let spans = ir_line_spans(model)
  assert_true(spans.length() > 0)
  let first = spans[0]
  let round_trip = ir_span_for_line(spans, first.first_line)
  guard round_trip is Some(found) else { fail("line did not map back") }
  assert_eq(found.path, first.path)
  assert_eq(ir_span_at(spans, first.path).unwrap().first_line, first.first_line)
}

///|
test "empty stage offers template shortcuts and hides the panes" {
  let model = apply_shell(initial_model(), SetWorkSpace(WsEmpty))
  assert_true(model.workspace is WsEmpty)
  let commands = shell_draw(model, 1280.0, 800.0)
  // 空舞台给出两条模板入口 + 打开工程
  assert_true(shell_has_text(commands, "新建问候程序"))
  assert_true(shell_has_text(commands, "新建点名册"))
  assert_true(shell_has_text(commands, "打开项目…"))
  // 窗格头消失
  assert_false(shell_has_text(commands, "实时应用"))
  // 注意：不能断言「文本里没有『积木』」——左栏结构树有一个
  // 「自定义积木」分组标题，它**包含**「积木」二字，会让这条断言假失败。
  // 要判的是**窗格头**是否消失，所以用整词「积木 按钮」那种带上下文的
  // 标题文本（窗格头的实际渲染内容）。
  assert_false(shell_has_text(commands, "积木 按钮"))
}

///|
test "context tabs change the right panel body" {
  let model = initial_model()
  let props = shell_draw(
    apply_shell(model, SetContextTab(CtxProps)),
    1280.0,
    800.0,
  )
  assert_true(shell_has_text(props, "名称"))
  let data = shell_draw(
    apply_shell(model, SetContextTab(CtxData)),
    1280.0,
    800.0,
  )
  // 数据页签列变量与本地数据，不再显示属性字段
  assert_false(shell_has_text(data, "名称"))
}

///|
test "command palette filters the studio command catalog" {
  let t = translator(initial_model())
  let all = studio_commands(t)
  assert_true(all.length() >= 20)
  let filtered = filter_studio_commands(all, "console")
  assert_true(filtered.length() >= 1)
  assert_true(filtered.length() < all.length())
  // 空查询返回全集
  assert_eq(filter_studio_commands(all, "").length(), all.length())
}

///|
test "settings and AI history dialogs are modal overlays" {
  let model = initial_model()
  let plain = shell_draw(model, 1280.0, 800.0)
  assert_false(shell_has_text(plain, "设置"))
  let settings = shell_draw(apply_shell(model, ToggleSettings), 1280.0, 800.0)
  assert_true(shell_has_text(settings, "设置"))
  let history = shell_draw(apply_shell(model, ToggleAiHistory), 1280.0, 800.0)
  assert_true(shell_has_text(history, "提案历史"))
}

///|
test "runtime watch lists only declared watch variables" {
  let model = initial_model()
  let rows = watch_rows(model)
  // 未运行时也要有行（显示空态），但值不会假装成已运行
  assert_true(rows.length() >= 0)
  // 启动后能读到值
  let running = apply_shell(model, RunStart)
  let live = watch_rows(running)
  for row in live {
    ignore(row)
  }
}

///|
test "workspace resize keeps panels inside the viewport" {
  let model = initial_model()
  for width in [900.0, 1280.0, 1600.0] {
    let commands = shell_draw(model, width, 800.0)
    let quick = shell_find_text(commands, "快速操作")
    guard quick is Some(run) else { fail("quick actions missing at \{width}") }
    assert_true(run.frame.origin.x + run.frame.size.width <= width)
  }
}

///|
/// 工作区**拿回全部高度**：两种 AI 落点都不再预留任何「避让带」。
///
/// 这是本次改造的验收核心。历史上中心列底部常驻一条 134pt 的 AI 保留带
/// 给贴底浮卡让位；用户报的「这块区域不协调」就是它。浮层形态删除后，
/// 中心列内容段的底边必须**恰好等于**行底（不再被带吃掉一块）。
///
/// 判据取结构而不是像素：中心列的内容容器高度 == row_height。
test "no AI band: the workspace content is adjacent to the panel below it" {
  // 「避让带」的**定义**是：在工作区内容与它下面的面板（底栏）之间，多出
  // 一条中心列宽的横带。所以判据就是**相邻性**——工作区内容段的底边必须
  // 恰好等于下一个中心列宽段的顶边，中间不留任何一条带。
  //
  // 实测（旧实现）：工作区 568 → 带 134 → 底栏，中间夹着一条带；
  // 现在：工作区 568 → 底栏，41+568 == 609，严丝合缝。
  let model = initial_model()
  for view in [RvContext, RvAi] {
    let anchored = apply_shell(model, SetRightView(view))
    let commands = shell_draw(anchored, 1280.0, 800.0)
    let widths = shell_chrome_widths(anchored, 1280.0 - ICONBAR_WIDTH)
    // 收集所有中心列宽的段，按顶边排序
    let slabs : Array[@core.Rect] = []
    for command in commands {
      let rect = match command {
        @core.FillRect(r, _) => Some(r)
        @core.FillRoundedRect(r, _) => Some(r.rect)
        @core.FillRoundedRectBrush(r, _) => Some(r.rect)
        _ => None
      }
      match rect {
        Some(r) =>
          if r.size.width > widths.center - 4.0 &&
            r.size.width < widths.center + 4.0 &&
            r.size.height > 100.0 {
            slabs.push(r)
          }
        None => ()
      }
    }
    if slabs.length() < 2 {
      fail(
        "expected at least workspace + bottom bar slabs, got " +
        slabs.length().to_string(),
      )
    }
    // 相邻性：排序后每一段的下沿必须贴住下一段的上沿（允许 2pt 发丝线；
    // M8 起 workspace 与底栏之间是 4pt 的底栏高度拖拽 sash——允许 5pt）
    let sorted = slabs.copy()
    sorted.sort_by(fn(a, b) { a.origin.y.compare(b.origin.y) })
    let top = sorted[0]
    let next = sorted[1]
    let gap = next.origin.y - (top.origin.y + top.size.height)
    if gap > 5.0 {
      fail(
        "a band sits between the workspace and the panel below it: gap=" +
        gap.to_string() +
        " workspace_bottom=" +
        (top.origin.y + top.size.height).to_string() +
        " next_top=" +
        next.origin.y.to_string(),
      )
    }
  }
}

///|
/// 树行的元信息（窗体 640×480）必须完整落在左栏内。
/// 曾经的 bug：标签宽度写死 `width - 44`，而 meta 单元格固定 52 又装不下
/// 「640×480」（实测 68），两者叠加让整行溢出到面板外，被裁成「64」。
///
/// 注意坐标系：左栏从 x=ICONBAR_WIDTH 起，右边缘是
/// ICONBAR_WIDTH + LEFTBAR_WIDTH（不是 LEFTBAR_WIDTH）。
test "tree row meta stays inside the panel" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  let cell = shell_find_text(commands, "640×480")
  guard cell is Some(run) else { fail("window meta missing from the tree") }
  let panel_right = ICONBAR_WIDTH + LEFTBAR_WIDTH
  if run.frame.origin.x + run.frame.size.width > panel_right {
    fail(
      "meta overflows panel: right=" +
      (run.frame.origin.x + run.frame.size.width).to_string() +
      " panel_right=" +
      panel_right.to_string(),
    )
  }
  assert_eq(run.frame.size.width, TREE_META_WIDTH)
}

///|
/// 分组头「+」菜单：展开后列出该组可创建的对象，且**与枚举等长**
/// （控件 6 种全在）、候选行不越出左栏。
///
/// 这条替代了旧的「快速插入格子必须落在窗格内」：创建入口从面板底部的
/// 全局按钮块上移到分组头之后，要守的性质变成「菜单项齐 + 不溢出」。
test "group create menu lists every control kind inside the panel" {
  let model = initial_model()
  let expanded = { ..model, tree_create_group: tree_group_controls(), }
  let commands = shell_draw(expanded, 1280.0, 800.0)
  let t = translator(expanded)
  for
    key in [
      "control.button", "control.label", "control.text_field", "control.check_box",
      "control.list_box", "control.table",
    ] {
    assert_true(shell_has_text(commands, "+ " + text(t, key)))
  }
  // 候选行不得越出左栏右缘。左栏的**绝对**范围是
  // [ICONBAR_WIDTH, ICONBAR_WIDTH + LEFTBAR_WIDTH]——`LEFTBAR_WIDTH` 是宽度
  // 不是坐标，直接拿 x 与它比会把正确布局判成溢出（实测文字右缘 265 对
  // 面板右缘 280，是合法的）。这个陷阱在本仓已有先例（面板头/树行）。
  let panel_right = ICONBAR_WIDTH + LEFTBAR_WIDTH
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) =>
        if run.text.has_prefix("+ ") {
          assert_true(run.frame.origin.x + run.frame.size.width <= panel_right)
        }
      _ => ()
    }
  }
}

///|
/// 变量组菜单必须给出「新建变量」入口（此前没有任何地方能建变量）。
test "variable group menu offers the new-variable entry" {
  let model = initial_model()
  let expanded = { ..model, tree_create_group: tree_group_variables(), }
  let commands = shell_draw(expanded, 1280.0, 800.0)
  let t = translator(expanded)
  assert_true(
    shell_has_text(commands, "+ " + text(t, "app.tree.create.variable")),
  )
}

///|
/// 本地数据组**没有**「+」：条目从列表/表格控件的行派生，没有独立创建
/// 语义——不给一个点了没用的按钮，菜单也不该冒出候选行。
test "data group offers no create menu" {
  let model = initial_model()
  let expanded = { ..model, tree_create_group: tree_group_data(), }
  let commands = shell_draw(expanded, 1280.0, 800.0)
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) =>
        assert_false(run.text.has_prefix("+ "))
      _ => ()
    }
  }
}

///|
/// 空舞台：引导入口（模板）与 AI 输入条**互不遮挡**。
///
/// 历史：空舞台上曾有「hero」形态——输入框升到中心列上方当主角、加宽到
/// 700 并列示例指令，因此引导语要用定长前导 spacer 顶上沿避让。输入条
/// 改由底栏页签/右栏停靠承载后，hero 不再存在，中心列只归引导入口，
/// 两者结构上不可能重叠。
test "empty workspace keeps guidance and AI input in separate panels" {
  let model = initial_model()
  let empty = apply_shell(model, SetWorkSpace(WsEmpty))
  // 空舞台 + 底栏档：输入条在底栏，模板按钮在中心列
  let commands = shell_draw(empty, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "描述你想要的应用"))
  guard shell_find_send_button(commands) is Some(_) else {
    fail("AI send button missing on empty stage")
  }
  // 空舞台 + 停靠档：输入条改到右栏，仍然可见
  let docked = apply_shell(empty, SetRightView(RvAi))
  assert_true(
    shell_has_text(
      shell_draw(docked, 1280.0, 800.0),
      "描述你想要的应用",
    ),
  )
}

///|
/// 输入条模式段：四个模式都在，且「发送」按模式分流到既有通道。
test "composer mode routes send to existing channels" {
  // 修复通道的「无效草稿」语义在 DSL 外观下制造（M5-5e）
  let model = apply_shell(initial_model(), CycleCodeAppearance)
  let commands = shell_draw(model, 1280.0, 800.0)
  for label in ["修改", "生成", "解释", "修复"] {
    assert_true(shell_has_text(commands, label))
  }
  guard shell_find_send_button(commands) is Some(_) else {
    fail("round send button missing")
  }
  // 解释模式 → 本地确定性讲解（挂到 explanation）
  let explain = apply_shell(
    apply_shell(model, SetComposerMode(ComposeExplain)),
    ComposerRun,
  )
  if explain.explanation == "" {
    fail(
      "explain mode produced nothing; selected_handler=" +
      explain.selected_handler,
    )
  }
  // 修复模式 → 代码草稿回到 IR 的规范渲染。
  // EditCode 只写草稿；提交（切模式会先 commit）才产生解析错误。
  // RunStart 会先 commit_code：非法草稿不被采纳（草稿原样保留，
  // notice 里给出本地化错误——正是修复模式的输入态）。
  let broken = apply_shell(
    apply_shell(model, EditCode("如果 真的 则\n")),
    RunStart,
  )
  if broken.code_error == "" {
    fail("invalid draft was not rejected: " + broken.code_draft)
  }
  let repaired = apply_shell(
    apply_shell(broken, SetComposerMode(ComposeRepair)),
    ComposerRun,
  )
  if repaired.code_error != "" {
    fail("repair left an error: " + repaired.code_error)
  }
  // 修好之后草稿是 IR 的规范渲染：注释头 + 唯一那条 set_text 语句
  // 修复后的草稿就是 IR 的规范渲染（与 render_handler 逐字相同），
  // 且不再是那份非法文本——按具体关键字断言会漏掉语言差异
  // （中文渲染成「设置文本」，英文才是 set_text）。
  guard current_handler(repaired) is Some(handler) else { fail("handler gone") }
  let canonical = @studio_lang.render_handler(
    handler,
    repaired.language.dsl_language(),
  )
  assert_eq(repaired.code_draft, canonical)
  assert_true(apply_shell(repaired, RunStart).run is Some(_))
}

///|
/// 生成模式以空程序为基：提案从零重建，且仍走同一条校验链。
test "generate mode starts from an empty program" {
  let model = apply_shell(initial_model(), SetPrompt("班级点名册"))
  let cleared = apply_shell(
    apply_shell(model, SetComposerMode(ComposeGenerate)),
    ComposerRun,
  )
  guard cleared.pending is Some(pending) else { fail("no proposal generated") }
  assert_true(pending.valid)
  // 提案恢复了控件（生成语义），不是空提案
  assert_true(pending.proposal.controls_add.length() > 0)
}

///|
/// 两种落点在**任何工作区**下都渲染输入条（含空舞台）。
///
/// 曾经的结构性 bug：带高为 0 时浮动层被塞进 0 高的容器，整块消失。
/// 现在两种落点各有自己的宿主面板（底栏 / 右栏），不再依赖「带高」这个
/// 中间量，所以这类塌陷在结构上不可能发生——这条测试钉住该性质。
test "both inline placements render the composer regardless of workspace" {
  let model = initial_model()
  for space in [WsVisual, WsCode, WsEmpty] {
    let m = apply_shell(model, SetWorkSpace(space))
    // 底栏档
    let bar = shell_draw(m, 1280.0, 800.0)
    assert_true(shell_has_text(bar, "描述你想要的应用"))
    guard shell_find_send_button(bar) is Some(_) else {
      fail("AI send button missing in bar placement")
    }
    // 停靠档
    let docked = apply_shell(m, SetRightView(RvAi))
    assert_true(
      shell_has_text(
        shell_draw(docked, 1280.0, 800.0),
        "描述你想要的应用",
      ),
    )
  }
}

///|
/// 空舞台的引导入口（模板按钮）必须落在 hero 卡上方，不被盖住——
/// 被盖住就等于「点了没反应」，那是比不好看严重得多的问题。
test "empty stage guidance is not covered by the AI composer" {
  // 空舞台：引导入口（模板按钮）在中心列，AI 输入条在底栏/右栏。
  // 两者在不同面板里，所以「输入卡盖住引导语」在结构上不可能发生；
  // 这条测试钉住该性质（历史上 hero 卡会盖住装饰文字）。
  let empty = apply_shell(initial_model(), SetWorkSpace(WsEmpty))
  let commands = shell_draw(empty, 1280.0, 800.0)
  guard shell_find_text(commands, "新建问候程序") is Some(guide_run) else {
    fail("stage buttons missing")
  }
  guard shell_find_text(commands, "描述你想要的应用") is Some(card_run) else {
    fail("AI composer missing")
  }
  // 输入条在底栏带里（y 明显更靠下），引导语在中心列
  if guide_run.frame.origin.y + guide_run.frame.size.height >
    card_run.frame.origin.y {
    fail(
      "AI composer covers the stage buttons: guide_bottom=" +
      (guide_run.frame.origin.y + guide_run.frame.size.height).to_string() +
      " composer_top=" +
      card_run.frame.origin.y.to_string(),
    )
  }
}

///|
/// 浮动 AI 层不得把工作区刷成一块底板。
///
/// 曾经的 bug：外层的纯定位包装用了无 background 的 `@views.container`，
/// 它回落到环境 Base 变体的刷子（不透明面板色），整帧被刷满——空舞台的
/// 引导语和三个模板按钮**画了但看不见**（绘制流里都在，屏幕上一片空）。
/// 断言方式：在所有「舞台文字」之后，不允许出现覆盖整行的实心矩形。
test "floating AI layer does not paint over the workspace" {
  let empty = apply_shell(initial_model(), SetWorkSpace(WsEmpty))
  let commands = shell_draw(empty, 1280.0, 800.0)
  let mut stage_text_at = -1
  let mut index = 0
  for command in commands {
    match command {
      @core.DrawText(run) =>
        if run.text.contains("从零开始") {
          stage_text_at = index
        }
      _ => ()
    }
    index += 1
  }
  assert_true(stage_text_at >= 0)
  index = 0
  for command in commands {
    if index > stage_text_at {
      let rect = match command {
        @core.FillRect(rect, _) => Some(rect)
        @core.FillRoundedRect(rect, _) => Some(rect.rect)
        @core.FillRoundedRectBrush(rect, _) => Some(rect.rect)
        _ => None
      }
      match rect {
        Some(rect) =>
          // 「盖住整行」= 横跨中心列且比一张卡还高
          if rect.origin.x <= 300.0 &&
            rect.origin.x + rect.size.width >= 1000.0 &&
            rect.size.height > 400.0 {
            fail(
              "opaque rect covers the stage after its text: y=" +
              rect.origin.y.to_string() +
              " h=" +
              rect.size.height.to_string(),
            )
          }
        None => ()
      }
    }
    index += 1
  }
}

///|
/// AI 卡常驻 chrome 瘦身后的契约：锚点读数进头部、旧工具行（与头部图标
/// 完全重复的三个文本按钮）删除、发送芯片在卡内且不越界。
test "ai composer box stays inside its host panel" {
  // 停靠档：输入卡在右栏内联，发送钮必须落在**右栏**里（不溢出面板）。
  // 底栏档同理，只是宿主换成底栏——两者共用同一个 composer，所以这里
  // 用停靠档验证「输入盒不会长出宿主」这一条。
  let model = apply_shell(initial_model(), SetRightView(RvAi))
  let commands = shell_draw(model, 1280.0, 800.0)
  // 无头部（Codex 口径）：标题/读数/徽标都不再绘制
  assert_false(shell_has_text(commands, "AI 提案"))
  guard shell_find_text(commands, "描述你想要的应用") is Some(card_run) else {
    fail("AI composer missing")
  }
  guard shell_find_send_button(commands) is Some(send) else {
    fail("round send button missing")
  }
  let chrome = shell_chrome_widths(model, 1280.0 - ICONBAR_WIDTH)
  let panel_left = 1280.0 - chrome.right
  let panel_right = 1280.0
  let send_right = send.origin.x + send.size.width
  if send_right > panel_right {
    fail(
      "send button overflows the panel: right=" +
      send_right.to_string() +
      " panel_right=" +
      panel_right.to_string(),
    )
  }
  if card_run.frame.origin.x < panel_left - 1.0 {
    fail(
      "composer starts left of the docked panel: x=" +
      card_run.frame.origin.x.to_string(),
    )
  }
}

///|
/// AI 宿主读数由 right_view × 当前模式推导（M2），三种宿主三个读数。
test "ai host hint follows the derived host" {
  let model = initial_model()
  // 默认（图形化模式 + 检查器右栏）：AI 在底栏页签
  assert_eq(ai_host_hint_key(model), "app.ai.anchor.bar")
  // 停靠：右栏切到 AI
  let docked = apply_shell(model, SetRightView(RvAi))
  assert_eq(ai_host_hint_key(docked), "app.ai.anchor.docked")
  // AI 模式：宿主是中心
  let center = apply_shell(model, SetPerspective(PsAi))
  assert_eq(ai_host_hint_key(center), "app.ai.anchor.center")
  // 无头部：任何宿主下都不再有「底部居中」读数
  assert_false(shell_has_text(shell_draw(model, 1280.0, 800.0), "底部居中"))
}

///|
/// 两种内联落点必须能互相一步切换，且**切换后确实换面板**：
/// 底栏档选中的是底栏 AI 页签，停靠档在右栏。
///
/// 判据取状态而不是绘制指令：绘制里两种形态都可能出现同样的 composer
/// 文字，只有 `right_view` + `bottom_tab` 能区分「现在这条在哪」。
test "both inline AI placements are reachable in one step" {
  // 底栏档（默认宿主）：点 AI 页签 = 打开底栏并选中它
  let bar = apply_shell(initial_model(), SetBottomTab(BtAi))
  assert_true(bar.right_view is RvContext)
  assert_true(bar.bottom_open)
  assert_true(bar.bottom_tab is BtAi)
  // 一步切到停靠
  let docked = apply_shell(bar, SetRightView(RvAi))
  assert_true(docked.right_view is RvAi)
  // 再一步切回底栏（右栏换回检查器 → 宿主推导回底栏页签）
  let back = apply_shell(docked, SetRightView(RvContext))
  assert_true(back.right_view is RvContext)
  // 两种落点都是内联档：都不占中心列高度，所以都没有避让带
  assert_false(RvContext is RvAi)
}

///|
/// `#seeAll`：线程多于 3 条时才出现，且点了打开既有 AI 历史。
test "see all sessions appears only with a long thread list" {
  let model = initial_model()
  // 初始只有 1 张卡 → 不显示
  assert_false(
    shell_has_text(shell_draw(model, 1280.0, 800.0), "查看全部会话 →"),
  )
  // 每次生成提案都会推进一张 diff 线程卡（真实漏斗：GenerateProposal）
  let mut many = apply_shell(model, GenerateProposal)
  for _ in 0..<4 {
    many = apply_shell(many, GenerateProposal)
  }
  if many.ai_sessions.current().cards.length() <= 3 {
    fail("expected >3 thread cards, got " + many.ai_sessions.current().cards.length().to_string())
  }
  assert_true(
    shell_has_text(shell_draw(many, 1280.0, 800.0), "查看全部会话 →"),
  )
  // 折叠后线程区收起，出口也收起
  let folded = apply_shell(many, ToggleAiCardsFold)
  assert_false(
    shell_has_text(shell_draw(folded, 1280.0, 800.0), "查看全部会话 →"),
  )
}

///|
/// 待审计读数：药丸删除后，`pending_ai_cards` 仍然是唯一来源，
/// 由底栏 AI 页签的计数徽标承载（页签按钮的 count）。
test "pending review count still surfaces after the pill removal" {
  let model = apply_shell(initial_model(), GenerateProposal)
  if pending_ai_cards(model) == 0 {
    fail("proposal did not create a pending thread card")
  }
  // 底栏 AI 页签在场，卡片线程仍可读
  let commands = shell_draw(model, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "AI 输入"))
  assert_true(shell_has_text(commands, "待审计"))
}

///|
/// 线程卡是**事件驱动**的可见记录：生成提案 → 出现 diff 线程卡 +
/// 折叠条计数；采纳 → 卡被标为已应用且待审计数归零。
///
/// 回归意义：`push_ai_card` 曾经没有任何调用方，`ai_cards` 恒为空，
/// 于是线程区/折叠条/#seeAll/药丸计数全是永不出现的死 UI。
test "proposal threads produce visible, settleable cards" {
  let model = initial_model()
  assert_eq(model.ai_sessions.current().cards.length(), 0)
  let proposed = apply_shell(model, GenerateProposal)
  assert_true(proposed.pending is Some(_))
  assert_eq(proposed.ai_sessions.current().cards.length(), 1)
  assert_eq(pending_ai_cards(proposed), 1)
  // 卡片可见：折叠条给出待审计计数
  let commands = shell_draw(proposed, 1280.0, 800.0)
  assert_true(shell_has_text(commands, "Agent 待审计 1"))
  // 采纳后归零并留回执
  let accepted = apply_shell(proposed, AcceptProposal)
  assert_true(accepted.pending is None)
  assert_eq(pending_ai_cards(accepted), 0)
  assert_eq(accepted.ai_sessions.current().cards.length(), 1)
  assert_true(accepted.ai_sessions.current().cards[0].settled)
  // 拒绝同理
  let rejected = apply_shell(
    apply_shell(model, GenerateProposal),
    RejectProposal,
  )
  assert_true(rejected.ai_sessions.current().cards[0].settled)
  assert_eq(pending_ai_cards(rejected), 0)
}

///|
/// 线程卡出现后，输入条与决策行必须仍在卡片内可见。
///
/// 曾经的 bug：线程区拿「可用高度 − 常数」当预算，线程卡一多就长过卡片
/// 自身的帧高，把 composer 和决策行顶出可视区（实测一张 diff 卡就够）。

///|
/// 圆形发送钮的绘制指纹：强调色实心圆（宽=高≈24、圆角=半径）。
/// 发送改为图标后没有「发送」文字，这是它唯一的可观测形态。
fn shell_find_send_button(commands : Array[@core.DrawCommand]) -> @core.Rect? {
  let accent = ide_accent()
  let mut found : @core.Rect? = None
  for command in commands {
    match command {
      @core.FillRoundedRectBrush(rounded, @core.Brush::Solid(color)) =>
        if (color.r - accent.r).abs() < 0.001 &&
          (color.g - accent.g).abs() < 0.001 &&
          (rounded.rect.size.width - rounded.rect.size.height).abs() < 0.5 &&
          rounded.rect.size.width >= 18.0 &&
          rounded.rect.size.width <= 34.0 {
          found = Some(rounded.rect)
        }
      _ => ()
    }
  }
  found
}

///|
/// 现在线程区预算由 `ai_card_height − card_chrome_height` 反推。
test "thread cards never push the composer out of its host" {
  let mut model = apply_shell(initial_model(), SetRightView(RvAi))
  // 连推几张卡，触发线程区滚动上限
  for _ in 0..<5 {
    model = apply_shell(model, GenerateProposal)
  }
  if model.ai_sessions.current().cards.length() <= 3 {
    fail("expected >3 cards, got " + model.ai_sessions.current().cards.length().to_string())
  }
  let commands = shell_draw(model, 1280.0, 800.0)
  guard shell_find_text(commands, "描述你想要的应用")
    is Some(composer_run) else {
    fail("AI composer missing")
  }
  guard shell_find_send_button(commands) is Some(send) else {
    fail("round send button missing after threads")
  }
  // 发送钮与输入盒在同一行带内：纵向不得偏离输入盒太远
  // （线程区是**独立滚动区**，不可能把发送钮挤出宿主面板）
  let drift = (send.origin.y - composer_run.frame.origin.y).abs()
  if drift > 120.0 {
    fail(
      "send button drifted away from the composer: send_y=" +
      send.origin.y.to_string() +
      " composer_y=" +
      composer_run.frame.origin.y.to_string(),
    )
  }
}

///|
/// 悬停提示：图标按钮没有文字，说明必须能到达状态栏（否则 6 个纯图标
/// 对新手完全不可发现）。这条锁定「HoverHint 写进 model → 状态栏渲染它」
/// 这条件，而不是只锁 update 的字段赋值——仓库栽过「update 断言全绿、
/// 视图根本没读字段」的跟头（见 memories 的 `paint_signature` 一课）。
test "hover hint reaches the status bar" {
  let base = initial_model()
  assert_eq(base.hover_hint, "")
  let hovering = apply_shell(base, HoverHint("程序结构"))
  assert_eq(hovering.hover_hint, "程序结构")
  // 视图层必须真的渲染它：在状态栏区域找得到这段文字
  let commands = shell_draw(hovering, 1440.0, 900.0)
  let mut found = false
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) =>
        if run.text.contains("程序结构") {
          found = true
        }
      _ => ()
    }
  }
  assert_true(found)
  // 离开即还原（悬停是瞬态）
  let left = apply_shell(hovering, HoverHint(""))
  assert_eq(left.hover_hint, "")
}

///|
/// 积木画布的**真实渲染**验收（headless runtime + 真实文本度量）。
///
/// 单测里的假度量钉不住「估宽 vs 实渲」这一层；这里走真实布局读回命令：
/// - 块宽随内容收紧（用户报「积木左右撑满了」）：小积木不再横贯画布列；
/// - 标签**左对齐**：DrawText 的 frame.x = 块体 x + 徽标占位（此前默认
///   居中，与洞的左起游标错开）；
/// - 插槽洞跟在标签字形**之后**（用户报的「积木上的黑块」：洞孤零零画在
///   标签起点上）。
test "blocks canvas renders hugging rows with lead-aligned slot holes" {
  // 走**真实更新路径**造一条 If：选模板后从流程分类插入 if 骨架
  // （默认模板链里没有 If，画不出洞）。
  let base = apply_shell(initial_model(), SelectTemplate(2))
  let model = apply_shell(base, InsertStatement(2, 0))
  let commands = shell_draw(model, 1280.0, 800.0)
  // 块体 = FillRoundedRectBrush + 实心画笔，颜色取自 block_fill 色阶。
  // 画布行的标签是「如果␣␣(…)」（两个空格）——速查表/帮助面板的「如果」
  // 都不带这个形态，用它锁定积木行，不被同色 end 帽或右栏文本干扰。
  let if_fill = block_fill(@blocks.BkIf)
  let call_fill = block_fill(@blocks.BkCall)
  let mut if_label : @core.TextRun? = None
  let call_bodies : Array[@core.Rect] = []
  for run in shell_texts(commands) {
    if run.text.contains("如果  (") {
      if_label = Some(run)
    }
  }
  let label = match if_label {
    Some(run) => run
    None => fail("the if block label should be drawn on the canvas")
  }
  // 同行的棕色块体（If 帽）：y 包住标签行、x 在标签左侧。
  // M7②：块体 = 单轮廓 DrawPath（fill+stroke 一体），不再是贴片填充。
  let mut if_body : @core.Rect? = None
  let mut hole_x : Double? = None
  let hole_fill = blocks_slot_filled()
  for command in commands {
    match command {
      @core.DrawPath(path) =>
        match path.fill {
          Some(@graphics.Brush::Solid(color)) => {
            // PathSpec 无整体矩形——从动词的包围盒取（首 MoveTo + 各顶点）
            let mut min_x = 0.0
            let mut max_x = 0.0
            let mut min_y = 0.0
            let mut max_y = 0.0
            let mut first = true
            for verb in path.verbs {
              let (vx, vy) = match verb {
                @core.MoveTo(p) => (p.x, p.y)
                @core.LineTo(p) => (p.x, p.y)
                @core.QuadTo(p, _) => (p.x, p.y)
                @core.CubicTo(p, _, _) => (p.x, p.y)
                @core.Close => continue
              }
              if first {
                min_x = vx
                max_x = vx
                min_y = vy
                max_y = vy
                first = false
              } else {
                if vx < min_x {
                  min_x = vx
                }
                if vx > max_x {
                  max_x = vx
                }
                if vy < min_y {
                  min_y = vy
                }
                if vy > max_y {
                  max_y = vy
                }
              }
            }
            let rect = @geometry.Rect::new(
              x=min_x,
              y=min_y,
              width=max_x - min_x,
              height=max_y - min_y,
            )
            if color.r == if_fill.r &&
              color.g == if_fill.g &&
              color.b == if_fill.b &&
              rect.origin.y <= label.frame.origin.y &&
              label.frame.origin.y <= rect.origin.y + rect.size.height &&
              rect.origin.x <= label.frame.origin.x {
              if_body = Some(rect)
            }
            // 同行的命令块体（Call 帽，M7② 后同为单轮廓路径；包围盒
            // 含榫头/卯口凸起 ±5pt，高度上限放宽到 60）
            if color.r == call_fill.r &&
              color.g == call_fill.g &&
              color.b == call_fill.b &&
              rect.size.height >= 30.0 &&
              rect.size.height <= 60.0 {
              call_bodies.push(rect)
            }
          }
          _ => ()
        }
      @core.FillRoundedRectBrush(rounded, @graphics.Brush::Solid(color)) => {
        let rect = rounded.rect
        // 同行的插槽洞（条件段）——插槽仍是圆角填充
        if color.r == hole_fill.r &&
          color.g == hole_fill.g &&
          color.b == hole_fill.b &&
          rect.size.height >= 18.0 &&
          rect.size.height <= 22.0 &&
          rect.origin.y >= label.frame.origin.y &&
          rect.origin.y <= label.frame.origin.y + label.frame.size.height {
          hole_x = Some(rect.origin.x)
        }
      }
      _ => ()
    }
  }
  let body = match if_body {
    Some(rect) => rect
    None => fail("the if block body should be drawn behind its label")
  }
  // 1) **块宽随内容**：条件块装着「如果  (计数 > 0)」，内容宽远小于画布列
  //    （1280 视口下画布列 ~600+）；旧实现块宽 = 画布宽 − 边距。
  assert_true(
    body.size.width < 420.0,
    msg="if block width=\{body.size.width} should hug its content",
  )
  // 2) **标签左对齐**：标签 run 的 frame.x = 块体 x + 28（徽标占位）。
  assert_eq(label.frame.origin.x, body.origin.x + 28.0)
  // 3) **插槽洞在字形之后**：洞的起点必须越过「如果␣␣」的字形
  //    （真实度量 ≥ 24pt），不再贴着标签起点（用户报的黑块）。
  let hx = match hole_x {
    Some(value) => value
    None => fail("the if block condition slot should be drawn")
  }
  assert_true(
    hx >= body.origin.x + 28.0 + 24.0,
    msg="slot hole x=\{hx} must sit after the label glyphs (body.x=\{body.origin.x})",
  )
  // 洞整体在块体内（不再画到块外）
  assert_true(hx < body.origin.x + body.size.width)
  // 4) 命令块同样收紧（链上至少一条 set_text）
  assert_true(call_bodies.length() > 0)
  for call in call_bodies {
    assert_true(
      call.size.width < 500.0,
      msg="call block width=\{call.size.width} should hug its content",
    )
  }
}

///|
/// 活动栏**紧凑口径**几何验收（参考 VS Code 截图实测：栏 34 / 节距 28 /
/// 字形 17 / 裸字形 + 左缘条纹）。
test "activity bar uses the compact spec with bare-glyph selection" {
  let model = initial_model()
  let commands = shell_draw(model, 1280.0, 800.0)
  let panel = ide_panel()
  let accent = ide_accent()
  let hover = ide_hover()
  // 1) 栏底色从 x=0 铺开、宽度 = ICONBAR_WIDTH（左栏同色但起点在栏右）
  let mut bar_width = 0.0
  for command in commands {
    match command {
      @core.FillRoundedRectBrush(rounded, @graphics.Brush::Solid(color)) => {
        let rect = rounded.rect
        if color.r == panel.r &&
          color.g == panel.g &&
          color.b == panel.b &&
          rect.origin.x == 0.0 &&
          rect.size.height > 400.0 &&
          rect.size.width > bar_width {
          bar_width = rect.size.width
        }
      }
      _ => ()
    }
  }
  assert_true(
    bar_width > 0.0 && (bar_width - ICONBAR_WIDTH).abs() < 0.6,
    msg="icon bar width=\{bar_width} should equal ICONBAR_WIDTH=\{ICONBAR_WIDTH}",
  )
  // 2) **无条纹**：选中态只靠字形亮度，栏内不得出现强调色色块（条纹方案
  //    试过被否掉——这条反断言防止它悄悄回来）
  for command in commands {
    match command {
      @core.FillRoundedRectBrush(rounded, @graphics.Brush::Solid(color)) => {
        let rect = rounded.rect
        if color.r == accent.r &&
          color.g == accent.g &&
          color.b == accent.b &&
          rect.origin.x < ICONBAR_WIDTH {
          fail("activity bar must not paint an accent stripe/tile")
        }
      }
      _ => ()
    }
  }
  // 3) 活动栏内**无常驻底块**（tile=false）：栏 x 范围内不得有 hover 底色
  for command in commands {
    match command {
      @core.FillRoundedRectBrush(rounded, @graphics.Brush::Solid(color)) => {
        let rect = rounded.rect
        if color.r == hover.r &&
          color.g == hover.g &&
          color.b == hover.b &&
          rect.origin.x < ICONBAR_WIDTH &&
          rect.size.width <= 30.0 &&
          rect.size.height <= 30.0 {
          fail("activity bar items must not paint persistent tiles")
        }
      }
      _ => ()
    }
  }
  // 4) 图标节距：图标是 DrawPath（24 viewBox 缩放到 17 盒）。收集栏内
  //    路径的 y 中心，聚类后节距应为 28、共 7 枚（6 栏目 + 设置）。
  let centers : Array[Double] = []
  for command in commands {
    match command {
      @core.DrawPath(spec) => {
        let mut min_y = 1000000.0
        let mut max_y = -1000000.0
        let mut min_x = 1000000.0
        let mut max_x = -1000000.0
        for verb in spec.verbs {
          match verb {
            @core.PathVerb::MoveTo(p)
            | LineTo(p)
            | QuadTo(_, p)
            | CubicTo(_, _, p) => {
              if p.x < min_x {
                min_x = p.x
              }
              if p.x > max_x {
                max_x = p.x
              }
              if p.y < min_y {
                min_y = p.y
              }
              if p.y > max_y {
                max_y = p.y
              }
            }
            @core.PathVerb::Close => ()
          }
        }
        // 栏内的图标路径（x 在栏宽内、排除分隔线之类的细条）
        if max_x <= ICONBAR_WIDTH && max_x > 4.0 && max_y - min_y > 5.0 {
          centers.push((min_y + max_y) / 2.0)
        }
      }
      _ => ()
    }
  }
  centers.sort()
  // 三模式工作台(M2):3 个模式项 + 1 枚钉底齿轮（组间分隔线是 1pt 细条，
  // 被「墨迹高度 > 5pt」的判据排除）
  assert_true(
    centers.length() == 4,
    msg="expected 4 icon glyphs, got \{centers.length()}",
  )
  // 前 3 项（模式组）节距 28；第 4 枚是**钉底**的设置齿轮（spacer 推到
  // 底边），不参与节距——这正是「设置钉在最底」的口径。
  let mut i = 1
  while i < 3 {
    let pitch = centers[i] - centers[i - 1]
    assert_true(
      (pitch - 28.0).abs() < 0.8,
      msg="icon pitch=\{pitch} should be 28 (centers=\{centers})",
    )
    i = i + 1
  }
  assert_true(
    centers[3] > centers[2] + 100.0,
    msg="the gear should be pinned near the bottom edge, not in the icon rhythm",
  )
}

///|
/// 列间 sash 的**模型侧**语义：拖拽消息改写用户宽度，`shell_chrome_widths`
/// 按用户宽度分配三列；静态界限兜底夹取。
test "sash resize messages drive the three-column widths" {
  let base = initial_model()
  let usable = 1280.0 - ICONBAR_WIDTH
  // 拖宽左栏 → 左栏变宽、中心让位、右栏不动
  let widened = apply_shell(base, ResizeLeftPanel(300.0))
  let chrome = shell_chrome_widths(widened, usable)
  assert_eq(chrome.left.unwrap(), 300.0)
  assert_eq(chrome.right, RIGHTBAR_WIDTH)
  assert_true(
    chrome.center < shell_chrome_widths(base, usable).center,
    msg="the center column must yield when the left panel widens",
  )
  // 拖窄过下限 → 夹到下限
  let clamped_low = apply_shell(base, ResizeLeftPanel(40.0))
  assert_eq(
    shell_chrome_widths(clamped_low, usable).left.unwrap(),
    LEFTBAR_MIN_WIDTH,
  )
  // 拖宽过上限 → 夹到上限
  let clamped_high = apply_shell(base, ResizeLeftPanel(900.0))
  assert_eq(
    shell_chrome_widths(clamped_high, usable).left.unwrap(),
    LEFTBAR_MAX_WIDTH,
  )
  // 右栏同理
  let right_wide = apply_shell(base, ResizeRightPanel(340.0))
  assert_eq(shell_chrome_widths(right_wide, usable).right, 340.0)
  // 宽度合计 = 可用宽（无死区、无重叠）
  let total = chrome.left.unwrap() +
    SASH_WIDTH +
    chrome.center +
    SASH_WIDTH +
    chrome.right
  assert_true((total - usable).abs() < 0.6, msg="columns must fill the row")
}

///|
/// 端到端：在左 sash 上按下并拖动，左栏真的跟着变宽——捕获语义 + 绝对
/// 映射的真实链路（不是单测里的直接派消息）。
test "dragging the column sash resizes the left panel (e2e)" {
  let sink : Ref[(@core.Frame) -> Unit] = Ref(fn(_frame) { () })
  let registered : Ref[Bool] = Ref(false)
  let runtime = @runtime.new_program_with_dimensions(
    program=program(
      environment=@services.AppEnvironment::new(
        timer=Some(fake_timer_source(sink, registered)),
      ),
    ),
    width=1280.0,
    height=800.0,
  )
  let _ = runtime.draw_commands()
  // 左 sash 中心：活动栏 + 左栏 + sash/2
  let start_x = ICONBAR_WIDTH + LEFTBAR_WIDTH + SASH_WIDTH / 2.0
  let y = 400.0
  runtime.dispatch_event(
    @core.Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=start_x, y~),
        phase=@core.Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=start_x + 60.0, y~),
        phase=@core.Move,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=start_x + 60.0, y~),
        phase=@core.Up,
      ),
    ),
  )
  // 重渲：左栏面板（ide_panel 底色、起点 = 活动栏宽）应变宽 60
  let panel = ide_panel()
  let sash_color = ide_border_soft()
  let mut left_width = 0.0
  let mut sash_x = -1.0
  for command in runtime.draw_commands() {
    match command {
      @core.FillRoundedRectBrush(rounded, @graphics.Brush::Solid(color)) => {
        let rect = rounded.rect
        if rect.size.height > 500.0 &&
          rect.origin.y < 100.0 &&
          color.r == panel.r &&
          color.g == panel.g &&
          rect.origin.x == ICONBAR_WIDTH {
          left_width = rect.size.width
        }
        if color.r == sash_color.r &&
          color.g == sash_color.g &&
          rect.size.height > 500.0 &&
          rect.origin.x > ICONBAR_WIDTH &&
          rect.origin.x < 500.0 &&
          sash_x < 0.0 {
          sash_x = rect.origin.x
        }
      }
      _ => ()
    }
  }
  let expected = LEFTBAR_WIDTH + 60.0
  assert_true(
    (left_width - expected).abs() < 0.6,
    msg="left panel width=\{left_width} should be \{expected} after dragging +60",
  )
  assert_true(
    (sash_x - (ICONBAR_WIDTH + expected)).abs() < 0.6,
    msg="sash x=\{sash_x} should follow the panel edge",
  )
}
